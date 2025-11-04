//
//  MemoryBudgetManager.swift
//  Tavi
//
//  Manages memory budgets for different components to prevent over-allocation
//  Created on 2025-11-04.
//

import Foundation
import os.log

/// Manages memory budgets and enforces allocation limits
@MainActor
public final class MemoryBudgetManager: ObservableObject {

    // MARK: - Types

    /// Component memory budget
    public struct Budget {
        public let component: String
        public let maxMB: Double
        public var allocatedMB: Double
        public let priority: Int  // Higher = more important

        public var remainingMB: Double {
            max(0, maxMB - allocatedMB)
        }

        public var utilizationPercentage: Double {
            (allocatedMB / maxMB) * 100
        }

        public var isOverBudget: Bool {
            allocatedMB > maxMB
        }
    }

    // MARK: - Published Properties

    @Published public private(set) var budgets: [String: Budget] = [:]
    @Published public private(set) var totalBudgetMB: Double = 0
    @Published public private(set) var totalAllocatedMB: Double = 0

    // MARK: - Properties

    public static let shared = MemoryBudgetManager()

    private let logger = Logger(subsystem: "com.tavi.app", category: "MemoryBudgetManager")

    // MARK: - Default Budgets

    private struct DefaultBudgets {
        static let faceScanCapture: Double = 50.0    // 50 MB for active capture
        static let meshMerging: Double = 100.0       // 100 MB for mesh merging
        static let textureBaking: Double = 150.0     // 150 MB for texture baking
        static let metricsComputation: Double = 50.0  // 50 MB for metrics
        static let coreDataCache: Double = 30.0      // 30 MB for Core Data cache
        static let imageCache: Double = 50.0         // 50 MB for image cache
        static let general: Double = 70.0            // 70 MB for general use
    }

    // MARK: - Initialization

    private init() {
        setupDefaultBudgets()
    }

    // MARK: - Public API

    /// Request memory allocation
    /// Returns true if allocation is within budget, false if over budget
    public func requestAllocation(
        component: String,
        sizeMB: Double
    ) -> Bool {
        guard var budget = budgets[component] else {
            logger.warning("⚠️ No budget defined for component: \(component)")
            // Allow allocation but warn
            return true
        }

        budget.allocatedMB += sizeMB
        budgets[component] = budget

        updateTotals()

        if budget.isOverBudget {
            logger.warning("❌ Budget exceeded for \(component): \(String(format: "%.2f", budget.allocatedMB)) / \(String(format: "%.2f", budget.maxMB)) MB")
            return false
        }

        logger.debug("✅ Allocated \(String(format: "%.2f", sizeMB)) MB to \(component)")
        return true
    }

    /// Release memory allocation
    public func releaseAllocation(
        component: String,
        sizeMB: Double
    ) {
        guard var budget = budgets[component] else { return }

        budget.allocatedMB = max(0, budget.allocatedMB - sizeMB)
        budgets[component] = budget

        updateTotals()

        logger.debug("♻️ Released \(String(format: "%.2f", sizeMB)) MB from \(component)")
    }

    /// Reset component allocation
    public func resetComponent(_ component: String) {
        guard var budget = budgets[component] else { return }

        let released = budget.allocatedMB
        budget.allocatedMB = 0
        budgets[component] = budget

        updateTotals()

        logger.info("🔄 Reset \(component) budget (\(String(format: "%.2f", released)) MB released)")
    }

    /// Get budget for component
    public func getBudget(for component: String) -> Budget? {
        return budgets[component]
    }

    /// Check if component can allocate more memory
    public func canAllocate(
        component: String,
        sizeMB: Double
    ) -> Bool {
        guard let budget = budgets[component] else { return true }
        return (budget.allocatedMB + sizeMB) <= budget.maxMB
    }

    /// Get components sorted by priority (highest first)
    public func getComponentsByPriority() -> [Budget] {
        budgets.values.sorted { $0.priority > $1.priority }
    }

    /// Get over-budget components
    public func getOverBudgetComponents() -> [Budget] {
        budgets.values.filter { $0.isOverBudget }
    }

    /// Adjust budgets based on device capabilities
    public func adjustForDevice() {
        let totalMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0

        let multiplier: Double
        if totalMemoryGB >= 6.0 {
            multiplier = 1.5  // High-end devices (6GB+)
        } else if totalMemoryGB >= 4.0 {
            multiplier = 1.0  // Mid-range devices (4-6GB)
        } else {
            multiplier = 0.7  // Low-end devices (<4GB)
        }

        logger.info("📱 Device memory: \(String(format: "%.2f", totalMemoryGB)) GB")
        logger.info("📊 Budget multiplier: \(String(format: "%.2f", multiplier))x")

        // Adjust all budgets
        for (component, budget) in budgets {
            var adjusted = budget
            adjusted.maxMB *= multiplier
            budgets[component] = adjusted
        }

        updateTotals()
        logger.info("✅ Budgets adjusted for device capabilities")
    }

    // MARK: - Private Methods

    private func setupDefaultBudgets() {
        budgets = [
            "FaceScanCapture": Budget(
                component: "FaceScanCapture",
                maxMB: DefaultBudgets.faceScanCapture,
                allocatedMB: 0,
                priority: 5
            ),
            "MeshMerging": Budget(
                component: "MeshMerging",
                maxMB: DefaultBudgets.meshMerging,
                allocatedMB: 0,
                priority: 4
            ),
            "TextureBaking": Budget(
                component: "TextureBaking",
                maxMB: DefaultBudgets.textureBaking,
                allocatedMB: 0,
                priority: 4
            ),
            "MetricsComputation": Budget(
                component: "MetricsComputation",
                maxMB: DefaultBudgets.metricsComputation,
                allocatedMB: 0,
                priority: 3
            ),
            "CoreDataCache": Budget(
                component: "CoreDataCache",
                maxMB: DefaultBudgets.coreDataCache,
                allocatedMB: 0,
                priority: 2
            ),
            "ImageCache": Budget(
                component: "ImageCache",
                maxMB: DefaultBudgets.imageCache,
                allocatedMB: 0,
                priority: 2
            ),
            "General": Budget(
                component: "General",
                maxMB: DefaultBudgets.general,
                allocatedMB: 0,
                priority: 1
            )
        ]

        updateTotals()
        adjustForDevice()
    }

    private func updateTotals() {
        totalBudgetMB = budgets.values.reduce(0) { $0 + $1.maxMB }
        totalAllocatedMB = budgets.values.reduce(0) { $0 + $1.allocatedMB }
    }
}

// MARK: - Budget Tracking

/// Property wrapper for automatic budget tracking
@propertyWrapper
public struct Budgeted<T> {
    private let component: String
    private let estimatedSizeMB: Double
    private var value: T?

    public var wrappedValue: T? {
        get { value }
        set {
            if let _ = newValue, value == nil {
                // Allocating
                Task { @MainActor in
                    _ = MemoryBudgetManager.shared.requestAllocation(
                        component: component,
                        sizeMB: estimatedSizeMB
                    )
                }
            } else if newValue == nil, let _ = value {
                // Releasing
                Task { @MainActor in
                    MemoryBudgetManager.shared.releaseAllocation(
                        component: component,
                        sizeMB: estimatedSizeMB
                    )
                }
            }
            value = newValue
        }
    }

    public init(
        component: String,
        estimatedSizeMB: Double
    ) {
        self.component = component
        self.estimatedSizeMB = estimatedSizeMB
        self.value = nil
    }
}
