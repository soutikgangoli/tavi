//
//  MemoryManagementTests.swift
//  OllvyTests
//
//  Tests for advanced memory management system
//  Created on 2025-11-04.
//

import XCTest
@testable import Ollvy

@MainActor
final class MemoryManagementTests: XCTestCase {

    var monitor: AdvancedMemoryMonitor!
    var budgetManager: MemoryBudgetManager!
    var resourceManager: MemoryResourceManager!

    override func setUp() async throws {
        await super.setUp()
        monitor = AdvancedMemoryMonitor.shared
        budgetManager = MemoryBudgetManager.shared
        resourceManager = MemoryResourceManager.shared
    }

    override func tearDown() async throws {
        monitor.stopMonitoring()
        await super.tearDown()
    }

    // MARK: - Memory Monitor Tests

    func testMemoryMonitorStartStop() async throws {
        // Given: Monitor is stopped
        monitor.stopMonitoring()
        XCTAssertFalse(monitor.isMonitoring)

        // When: Start monitoring
        monitor.startMonitoring()

        // Then: Should be monitoring
        XCTAssertTrue(monitor.isMonitoring)

        // When: Stop monitoring
        monitor.stopMonitoring()

        // Then: Should stop
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testMemoryStatsRetrieval() async throws {
        // When: Get memory stats
        let stats = monitor.getMemoryStats()

        // Then: Stats should be valid
        XCTAssertNotNil(stats)
        XCTAssertGreaterThan(stats!.usedMB, 0)
        XCTAssertGreaterThan(stats!.totalMB, 0)
        XCTAssertLessThanOrEqual(stats!.usedMB, stats!.totalMB)
    }

    func testMemoryPressureCalculation() async throws {
        // Given: Get stats
        guard let stats = monitor.getMemoryStats() else {
            XCTFail("Failed to get memory stats")
            return
        }

        // Then: Pressure should be valid
        XCTAssertTrue([.normal, .moderate, .high, .critical].contains(stats.pressure))

        // Normal apps should be at normal or moderate pressure
        XCTAssertLessThanOrEqual(stats.pressure, .moderate,
                                 "Test app should not be at high/critical pressure")
    }

    func testCleanupHandlerRegistration() async throws {
        // Given: Cleanup handler
        var cleanupCalled = false
        monitor.registerCleanupHandler(id: "TestHandler") { _ in
            cleanupCalled = true
        }

        // When: Force cleanup
        monitor.forceCleanup(atPressure: .moderate)

        // Then: Handler should be called
        XCTAssertTrue(cleanupCalled)

        // Cleanup
        monitor.unregisterCleanupHandler(id: "TestHandler")
    }

    // MARK: - Budget Manager Tests

    func testBudgetAllocation() async throws {
        // Given: Fresh budget state
        budgetManager.resetComponent("General")

        // When: Request allocation within budget
        let success = budgetManager.requestAllocation(component: "General", sizeMB: 10.0)

        // Then: Should succeed
        XCTAssertTrue(success)

        // When: Get budget
        let budget = budgetManager.getBudget(for: "General")

        // Then: Should reflect allocation
        XCTAssertNotNil(budget)
        XCTAssertGreaterThanOrEqual(budget!.allocatedMB, 10.0)
    }

    func testBudgetOverflow() async throws {
        // Given: Fresh budget state
        budgetManager.resetComponent("General")

        guard let budget = budgetManager.getBudget(for: "General") else {
            XCTFail("No budget for General")
            return
        }

        // When: Request allocation exceeding budget
        let success = budgetManager.requestAllocation(
            component: "General",
            sizeMB: budget.maxMB + 10.0
        )

        // Then: Should fail (over budget)
        XCTAssertFalse(success)

        // Check budget is over
        let updatedBudget = budgetManager.getBudget(for: "General")!
        XCTAssertTrue(updatedBudget.isOverBudget)
    }

    func testBudgetRelease() async throws {
        // Given: Allocated budget
        budgetManager.resetComponent("General")
        budgetManager.requestAllocation(component: "General", sizeMB: 20.0)

        let beforeRelease = budgetManager.getBudget(for: "General")!.allocatedMB

        // When: Release allocation
        budgetManager.releaseAllocation(component: "General", sizeMB: 10.0)

        // Then: Should reduce allocation
        let afterRelease = budgetManager.getBudget(for: "General")!.allocatedMB
        XCTAssertEqual(afterRelease, beforeRelease - 10.0, accuracy: 0.1)
    }

    func testBudgetReset() async throws {
        // Given: Allocated budget
        budgetManager.resetComponent("General")
        budgetManager.requestAllocation(component: "General", sizeMB: 30.0)

        // When: Reset budget
        budgetManager.resetComponent("General")

        // Then: Should be zero
        let budget = budgetManager.getBudget(for: "General")!
        XCTAssertEqual(budget.allocatedMB, 0, accuracy: 0.1)
    }

    func testDeviceBudgetAdjustment() async throws {
        // Given: Initial budgets
        let initialTotal = budgetManager.totalBudgetMB

        // When: Adjust for device
        budgetManager.adjustForDevice()

        // Then: Budgets should be adjusted
        let adjustedTotal = budgetManager.totalBudgetMB

        // Should be different (multiplied by device factor)
        XCTAssertNotEqual(initialTotal, adjustedTotal, accuracy: 0.1)
    }

    // MARK: - Resource Manager Tests

    func testResourceRegistration() async throws {
        // Given: Test resource
        let testData = Data(repeating: 0, count: 1024 * 1024)  // 1 MB
        let resource = MemoryManagedResource.managedData(
            identifier: "TestData",
            data: testData,
            priority: .medium,
            loader: { testData }
        )

        // Then: Should be registered
        XCTAssertTrue(resourceManager.registeredResources.keys.contains("TestData"))

        // When: Access resource
        let accessed = resource.access()

        // Then: Should return data
        XCTAssertNotNil(accessed)
        XCTAssertEqual(accessed?.count, testData.count)
    }

    func testResourceRelease() async throws {
        // Given: Loaded resource
        let testData = Data(repeating: 0, count: 1024 * 1024)
        let resource = MemoryManagedResource.managedData(
            identifier: "TestData2",
            data: testData,
            priority: .low,
            loader: { testData }
        )

        XCTAssertTrue(resource.isLoaded)

        // When: Release resource
        resource.release()

        // Then: Should be unloaded
        XCTAssertFalse(resource.isLoaded)
        XCTAssertNil(resource.peek())
    }

    func testResourceReload() async throws {
        // Given: Released resource
        let testData = Data(repeating: 0, count: 1024 * 1024)
        let resource = MemoryManagedResource.managedData(
            identifier: "TestData3",
            data: testData,
            priority: .medium,
            loader: { testData }
        )

        resource.release()
        XCTAssertFalse(resource.isLoaded)

        // When: Access (should reload)
        let reloaded = resource.access()

        // Then: Should be loaded again
        XCTAssertTrue(resource.isLoaded)
        XCTAssertNotNil(reloaded)
    }

    func testResourcePriorityCleanup() async throws {
        // Given: Resources with different priorities
        let data = Data(repeating: 0, count: 1024)

        let lowPriority = MemoryManagedResource.managedData(
            identifier: "LowPriority",
            data: data,
            priority: .low,
            loader: { data }
        )

        let highPriority = MemoryManagedResource.managedData(
            identifier: "HighPriority",
            data: data,
            priority: .high,
            loader: { data }
        )

        // When: Release low priority
        resourceManager.releaseAll(upToPriority: .low)

        // Then: Low priority should be released, high priority kept
        XCTAssertFalse(lowPriority.isLoaded)
        XCTAssertTrue(highPriority.isLoaded)
    }

    // MARK: - Integration Tests

    func testMemoryPressureTriggersCleanup() async throws {
        // Given: Registered resource with low priority
        let data = Data(repeating: 0, count: 1024 * 1024)
        let resource = MemoryManagedResource.managedData(
            identifier: "IntegrationTest",
            data: data,
            priority: .low,
            loader: { data }
        )

        XCTAssertTrue(resource.isLoaded)

        // When: Simulate moderate pressure
        // (In real scenario, this would be triggered by actual memory pressure)
        resourceManager.releaseAll(upToPriority: .low)

        // Then: Low priority resources should be released
        XCTAssertFalse(resource.isLoaded)
    }

    func testBudgetEnforcementDuringAllocation() async throws {
        // Given: Component with limited budget
        budgetManager.resetComponent("ImageCache")

        guard let budget = budgetManager.getBudget(for: "ImageCache") else {
            XCTFail("No budget for ImageCache")
            return
        }

        // When: Allocate within budget
        let withinBudget = budgetManager.requestAllocation(
            component: "ImageCache",
            sizeMB: budget.maxMB / 2
        )

        // Then: Should succeed
        XCTAssertTrue(withinBudget)

        // When: Try to allocate beyond budget
        let exceedsBudget = budgetManager.requestAllocation(
            component: "ImageCache",
            sizeMB: budget.maxMB
        )

        // Then: Should fail
        XCTAssertFalse(exceedsBudget)
    }

    // MARK: - Performance Tests

    func testMemoryStatsPerformance() throws {
        measure {
            _ = monitor.getMemoryStats()
        }
    }

    func testResourceAccessPerformance() throws {
        let data = Data(repeating: 0, count: 1024 * 1024)
        let resource = MemoryManagedResource.managedData(
            identifier: "PerfTest",
            data: data,
            priority: .medium,
            loader: { data }
        )

        measure {
            _ = resource.access()
        }
    }
}
