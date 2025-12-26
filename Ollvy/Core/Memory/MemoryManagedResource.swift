//
//  MemoryManagedResource.swift
//  Ollvy
//
//  Smart container for large memory resources with automatic cleanup
//  Created on 2025-11-04.
//

import Foundation
import CoreGraphics
import os.log

// MARK: - Types

/// Resource priority (determines cleanup order)
public enum MemoryResourcePriority: Int, Comparable {
    case low = 0        // Released first (e.g., cached preview images)
    case medium = 1     // Released on moderate pressure (e.g., intermediate data)
    case high = 2       // Released on high pressure (e.g., original captures)
    case critical = 3   // Only released on critical pressure (e.g., active scan data)

    public static func < (lhs: MemoryResourcePriority, rhs: MemoryResourcePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Container for large memory resources that can be automatically released under pressure
@MainActor
public final class MemoryManagedResource<T> {

    // MARK: - Properties

    private var resource: T?
    private let loader: () -> T?
    public let estimatedSizeMB: Double
    public let priority: MemoryResourcePriority
    public let identifier: String
    private var accessCount: Int = 0
    private var lastAccessTime: Date = Date()

    private let logger = Logger(subsystem: "com.ollvy.app", category: "MemoryManagedResource")

    // MARK: - Initialization

    /// Create a memory-managed resource
    /// - Parameters:
    ///   - identifier: Unique identifier for logging
    ///   - estimatedSizeMB: Estimated memory size in MB
    ///   - priority: Release priority (higher = keep longer)
    ///   - loader: Closure to recreate resource if released
    ///   - resource: Initial resource value
    public init(
        identifier: String,
        estimatedSizeMB: Double,
        priority: MemoryResourcePriority,
        loader: @escaping () -> T?,
        resource: T
    ) {
        self.identifier = identifier
        self.estimatedSizeMB = estimatedSizeMB
        self.priority = priority
        self.loader = loader
        self.resource = resource

        // Register with memory manager
        MemoryResourceManager.shared.register(self)

        logger.debug("📦 Created managed resource: \(self.identifier) (\(String(format: "%.2f", self.estimatedSizeMB)) MB, \(String(describing: self.priority)))")
    }

    deinit {
        let id = identifier
        Task { @MainActor in
            MemoryResourceManager.shared.unregister(id)
        }
    }

    // MARK: - Public API

    /// Access the resource (loads if released)
    public func access() -> T? {
        accessCount += 1
        lastAccessTime = Date()

        if resource == nil {
            logger.info("🔄 Reloading released resource: \(self.identifier)")
            resource = loader()
        }

        return resource
    }

    /// Get resource without reloading (returns nil if released)
    public func peek() -> T? {
        return resource
    }

    /// Check if resource is currently loaded
    public var isLoaded: Bool {
        resource != nil
    }

    /// Manually release resource (can be reloaded later)
    public func release() {
        guard resource != nil else { return }

        logger.debug("🗑️ Releasing resource: \(self.identifier) (\(String(format: "%.2f", self.estimatedSizeMB)) MB)")
        resource = nil
    }

    /// Force reload resource
    public func reload() {
        resource = loader()
    }

    // MARK: - Internal

    public func shouldRelease(forPressure pressure: AdvancedMemoryMonitor.MemoryPressure) -> Bool {
        guard resource != nil else { return false }

        switch pressure {
        case .normal:
            return false

        case .moderate:
            // Release low priority resources that haven't been accessed recently
            if priority == .low {
                let timeSinceAccess = Date().timeIntervalSince(lastAccessTime)
                return timeSinceAccess > 60.0  // 1 minute
            }
            return false

        case .high:
            // Release low and medium priority
            return priority <= .medium

        case .critical:
            // Release everything except critical
            return priority < .critical
        }
    }

    public var metadata: ResourceMetadata {
        ResourceMetadata(
            identifier: identifier,
            estimatedSizeMB: estimatedSizeMB,
            priority: priority,
            isLoaded: isLoaded,
            accessCount: accessCount,
            lastAccessTime: lastAccessTime
        )
    }
}

// MARK: - Resource Metadata

public struct ResourceMetadata {
    public let identifier: String
    public let estimatedSizeMB: Double
    public let priority: MemoryResourcePriority
    public let isLoaded: Bool
    public let accessCount: Int
    public let lastAccessTime: Date

    public var timeSinceLastAccess: TimeInterval {
        Date().timeIntervalSince(lastAccessTime)
    }
}

// MARK: - Memory Resource Manager

/// Centralized manager for all memory-managed resources
@MainActor
public final class MemoryResourceManager: ObservableObject {

    public static let shared = MemoryResourceManager()

    @Published public private(set) var registeredResources: [String: any AnyMemoryManagedResource] = [:]
    @Published public private(set) var totalManagedMemoryMB: Double = 0

    private var pressureObserver: NSObjectProtocol?
    private let logger = Logger(subsystem: "com.ollvy.app", category: "MemoryResourceManager")

    private init() {
        // Observe memory pressure changes
        // FIXED: Use DispatchQueue.main.async instead of Task { @MainActor } to ensure
        // state updates are deferred to next run loop, avoiding "Publishing changes" warnings
        pressureObserver = NotificationCenter.default.addObserver(
            forName: AdvancedMemoryMonitor.memoryPressureChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            DispatchQueue.main.async {
                if let pressure = notification.object as? AdvancedMemoryMonitor.MemoryPressure {
                    self?.handlePressureChange(pressure)
                }
            }
        }
    }

    deinit {
        if let observer = pressureObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    public func register<T>(_ resource: MemoryManagedResource<T>) {
        let id = resource.identifier
        registeredResources[id] = resource
        updateTotalMemory()
        logger.debug("Registered resource: \(id)")
    }

    public func unregister(_ identifier: String) {
        registeredResources.removeValue(forKey: identifier)
        updateTotalMemory()
        logger.debug("Unregistered resource: \(identifier)")
    }

    public func getAllMetadata() -> [ResourceMetadata] {
        registeredResources.values.compactMap { $0.metadata }
    }

    public func getLoadedMemoryMB() -> Double {
        registeredResources.values
            .filter { $0.isLoaded }
            .reduce(0) { total, resource in total + resource.estimatedSizeMB }
    }

    public func releaseAll(upToPriority priority: MemoryResourcePriority) {
        logger.warning("🧹 Releasing all resources up to priority \(String(describing: priority))")

        var releasedCount = 0
        var releasedMB = 0.0

        for resource in registeredResources.values {
            if resource.priority <= priority && resource.isLoaded {
                resource.release()
                releasedCount += 1
                releasedMB += resource.estimatedSizeMB
            }
        }

        logger.info("Released \(releasedCount) resources (\(String(format: "%.2f", releasedMB)) MB)")
        updateTotalMemory()
    }

    // MARK: - Private Methods

    private func handlePressureChange(_ pressure: AdvancedMemoryMonitor.MemoryPressure) {
        logger.info("📊 Memory pressure: \(pressure.description) - Evaluating resources")

        var releasedCount = 0
        var releasedMB = 0.0

        for resource in registeredResources.values {
            if resource.shouldRelease(forPressure: pressure) {
                resource.release()
                releasedCount += 1
                releasedMB += resource.estimatedSizeMB
            }
        }

        if releasedCount > 0 {
            logger.info("✅ Released \(releasedCount) resources (\(String(format: "%.2f", releasedMB)) MB)")
            updateTotalMemory()
        }
    }

    private func updateTotalMemory() {
        totalManagedMemoryMB = registeredResources.values.reduce(0) { total, resource in total + resource.estimatedSizeMB }
    }
}

// MARK: - Protocol for Type Erasure

@MainActor
public protocol AnyMemoryManagedResource {
    var identifier: String { get }
    var estimatedSizeMB: Double { get }
    var priority: MemoryResourcePriority { get }
    var isLoaded: Bool { get }
    var metadata: ResourceMetadata { get }

    func release()
    func shouldRelease(forPressure: AdvancedMemoryMonitor.MemoryPressure) -> Bool
}

extension MemoryManagedResource: AnyMemoryManagedResource {
    // Properties already declared in the class conform to protocol requirements
    // No redeclaration needed - Swift will use the existing public properties
}

// MARK: - Convenience Extensions

extension MemoryManagedResource where T == CGImage {
    /// Create managed resource for CGImage
    public static func managedImage(
        identifier: String,
        image: CGImage,
        priority: MemoryResourcePriority = .medium
    ) -> MemoryManagedResource<CGImage> {
        let sizeMB = Double(image.width * image.height * image.bitsPerPixel / 8) / 1_048_576.0

        return MemoryManagedResource(
            identifier: identifier,
            estimatedSizeMB: sizeMB,
            priority: priority,
            loader: { nil },  // Images can't be reliably recreated
            resource: image
        )
    }
}

extension MemoryManagedResource where T == Data {
    /// Create managed resource for Data
    public static func managedData(
        identifier: String,
        data: Data,
        priority: MemoryResourcePriority = .medium,
        loader: @escaping () -> Data?
    ) -> MemoryManagedResource<Data> {
        let sizeMB = Double(data.count) / 1_048_576.0

        return MemoryManagedResource(
            identifier: identifier,
            estimatedSizeMB: sizeMB,
            priority: priority,
            loader: loader,
            resource: data
        )
    }
}
