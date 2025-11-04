//
//  AdvancedMemoryMonitor.swift
//  Tavi
//
//  Enhanced memory monitoring with proactive cleanup and pressure handling
//  Created on 2025-11-04.
//

import Foundation
import UIKit
import os.log

/// Advanced memory monitoring with proactive management and pressure levels
@MainActor
public final class AdvancedMemoryMonitor: ObservableObject {

    // MARK: - Types

    /// Memory pressure levels
    public enum MemoryPressure: Int, Comparable {
        case normal = 0
        case moderate = 1
        case high = 2
        case critical = 3

        public static func < (lhs: MemoryPressure, rhs: MemoryPressure) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var description: String {
            switch self {
            case .normal: return "Normal"
            case .moderate: return "Moderate"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }
    }

    /// Memory statistics
    public struct MemoryStats {
        public let usedMB: Double
        public let availableMB: Double
        public let totalMB: Double
        public let pressure: MemoryPressure

        public var usagePercentage: Double {
            (usedMB / totalMB) * 100
        }

        public var formattedUsed: String {
            String(format: "%.1f MB", usedMB)
        }

        public var formattedTotal: String {
            String(format: "%.1f MB", totalMB)
        }
    }

    // MARK: - Published Properties

    @Published public private(set) var currentPressure: MemoryPressure = .normal
    @Published public private(set) var currentStats: MemoryStats?
    @Published public private(set) var isMonitoring: Bool = false

    // MARK: - Properties

    public static let shared = AdvancedMemoryMonitor()

    /// Memory warning notification
    public static let memoryWarningNotification = Notification.Name("TaviAdvancedMemoryWarning")

    /// Memory pressure changed notification
    public static let memoryPressureChangedNotification = Notification.Name("TaviMemoryPressureChanged")

    private var memoryWarningObserver: NSObjectProtocol?
    private var monitoringTimer: Timer?
    private let logger = Logger(subsystem: "com.tavi.app", category: "AdvancedMemoryMonitor")

    /// Registered cleanup handlers
    private var cleanupHandlers: [String: (MemoryPressure) -> Void] = [:]

    // MARK: - Configuration

    /// Memory thresholds (in MB)
    private struct Thresholds {
        static let moderatePressure: Double = 150.0  // When usage > total - 150MB
        static let highPressure: Double = 100.0       // When usage > total - 100MB
        static let criticalPressure: Double = 50.0    // When usage > total - 50MB

        static let monitoringInterval: TimeInterval = 2.0  // Check every 2 seconds
        static let warningThreshold: Double = 300.0        // Warn when < 300MB available
    }

    // MARK: - Initialization

    private init() {}

    deinit {
        // Cannot call MainActor-isolated method from deinit
        // Cleanup will be handled by Timer invalidation and notification removal
        monitoringTimer?.invalidate()
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Start monitoring memory with proactive management
    public func startMonitoring() {
        guard !isMonitoring else { return }

        logger.info("🔍 Starting advanced memory monitoring")
        isMonitoring = true

        // Observe system memory warnings
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSystemMemoryWarning()
            }
        }

        // Start periodic monitoring
        monitoringTimer = Timer.scheduledTimer(
            withTimeInterval: Thresholds.monitoringInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkMemoryPressure()
            }
        }
        monitoringTimer?.tolerance = 0.5

        // Initial check
        checkMemoryPressure()

        logger.info("✅ Advanced memory monitoring started")
    }

    /// Stop monitoring
    public func stopMonitoring() {
        guard isMonitoring else { return }

        logger.info("Stopping advanced memory monitoring")
        isMonitoring = false

        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
            memoryWarningObserver = nil
        }

        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    /// Register cleanup handler for specific component
    public func registerCleanupHandler(
        id: String,
        handler: @escaping (MemoryPressure) -> Void
    ) {
        cleanupHandlers[id] = handler
        logger.info("Registered cleanup handler: \(id)")
    }

    /// Unregister cleanup handler
    public func unregisterCleanupHandler(id: String) {
        cleanupHandlers.removeValue(forKey: id)
        logger.info("Unregistered cleanup handler: \(id)")
    }

    /// Get current memory statistics
    public func getMemoryStats() -> MemoryStats? {
        let used = getUsedMemoryMB()
        let total = getTotalMemoryMB()
        let available = total - used

        let pressure = calculateMemoryPressure(availableMB: available, totalMB: total)

        return MemoryStats(
            usedMB: used,
            availableMB: available,
            totalMB: total,
            pressure: pressure
        )
    }

    /// Force memory cleanup at specified pressure level
    public func forceCleanup(atPressure pressure: MemoryPressure) {
        logger.warning("⚠️ Forcing cleanup at \(pressure.description) pressure")
        performCleanup(forPressure: pressure)
    }

    // MARK: - Private Methods

    private func checkMemoryPressure() {
        guard let stats = getMemoryStats() else { return }

        currentStats = stats

        // Check if pressure level changed
        if stats.pressure != currentPressure {
            let oldPressure = currentPressure
            currentPressure = stats.pressure

            logger.info("📊 Memory pressure: \(oldPressure.description) → \(stats.pressure.description)")
            logger.info("   Used: \(stats.formattedUsed) / \(stats.formattedTotal) (\(String(format: "%.1f", stats.usagePercentage))%)")

            // Notify pressure change
            NotificationCenter.default.post(
                name: Self.memoryPressureChangedNotification,
                object: stats.pressure
            )

            // Perform cleanup if pressure increased
            if stats.pressure > oldPressure {
                performCleanup(forPressure: stats.pressure)
            }
        }

        // Proactive warning if available memory is low (even at normal pressure)
        if stats.availableMB < Thresholds.warningThreshold && currentPressure == .normal {
            logger.warning("⚠️ Low available memory: \(stats.formattedUsed) / \(stats.formattedTotal)")
            logger.warning("   Consider reducing memory usage proactively")
        }
    }

    private func handleSystemMemoryWarning() {
        logger.error("❌ SYSTEM MEMORY WARNING - Critical cleanup required")

        // Force critical pressure
        currentPressure = .critical

        // Perform aggressive cleanup
        performCleanup(forPressure: .critical)

        // Notify system memory warning
        NotificationCenter.default.post(
            name: Self.memoryWarningNotification,
            object: nil
        )

        // Log final stats
        if let stats = getMemoryStats() {
            logger.info("After cleanup: \(stats.formattedUsed) / \(stats.formattedTotal)")
        }
    }

    private func performCleanup(forPressure pressure: MemoryPressure) {
        logger.info("🧹 Performing cleanup for \(pressure.description) pressure")

        // Call registered cleanup handlers
        for (id, handler) in cleanupHandlers {
            logger.debug("  Calling cleanup handler: \(id)")
            handler(pressure)
        }

        // System-level cleanup
        performSystemCleanup(forPressure: pressure)

        logger.info("✅ Cleanup completed")
    }

    private func performSystemCleanup(forPressure pressure: MemoryPressure) {
        switch pressure {
        case .normal:
            // No cleanup needed
            break

        case .moderate:
            // Clear URL cache
            URLCache.shared.removeAllCachedResponses()
            logger.debug("  Cleared URL cache")

        case .high:
            // Clear URL cache + reduce texture quality
            URLCache.shared.removeAllCachedResponses()

            if UserDefaults.standard.bool(forKey: "enableHighResCapture") {
                UserDefaults.standard.set(false, forKey: "enableHighResCapture")
                logger.info("  Disabled high-resolution capture (4K → 2K)")
            }

        case .critical:
            // Aggressive cleanup
            URLCache.shared.removeAllCachedResponses()
            UserDefaults.standard.set(false, forKey: "enableHighResCapture")

            // Clear temporary files
            clearTemporaryFiles()

            // Force autoreleasepool drain
            autoreleasepool {
                // Temporary objects will be released
            }

            logger.warning("  Critical cleanup: All caches cleared, quality reduced")
        }
    }

    private func clearTemporaryFiles() {
        let tmpDirectory = FileManager.default.temporaryDirectory

        do {
            let tmpFiles = try FileManager.default.contentsOfDirectory(
                at: tmpDirectory,
                includingPropertiesForKeys: nil
            )

            var deletedCount = 0
            var freedSize: UInt64 = 0

            for file in tmpFiles {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let fileSize = attributes[.size] as? UInt64 {
                    try? FileManager.default.removeItem(at: file)
                    deletedCount += 1
                    freedSize += fileSize
                }
            }

            let freedMB = Double(freedSize) / 1_048_576.0
            logger.info("  Cleared \(deletedCount) temp files (\(String(format: "%.2f", freedMB)) MB)")
        } catch {
            logger.error("  Failed to clear temp files: \(error.localizedDescription)")
        }
    }

    private func calculateMemoryPressure(availableMB: Double, totalMB: Double) -> MemoryPressure {
        if availableMB < Thresholds.criticalPressure {
            return .critical
        } else if availableMB < Thresholds.highPressure {
            return .high
        } else if availableMB < Thresholds.moderatePressure {
            return .moderate
        } else {
            return .normal
        }
    }

    private func getUsedMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1_048_576.0
        }

        return 0
    }

    private func getTotalMemoryMB() -> Double {
        // Get physical memory
        return Double(ProcessInfo.processInfo.physicalMemory) / 1_048_576.0
    }
}
