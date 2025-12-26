//
//  PerformanceAnalyzer.swift
//  Ollvy
//
//  Comprehensive performance analysis and optimization toolkit
//  Created on 2025-11-04.
//

import Foundation
import os.log

/// Performance analyzer for identifying and optimizing sequential bottlenecks
public final class PerformanceAnalyzer {

    // MARK: - Types

    /// Performance measurement result
    public struct Measurement: Sendable {
        public let operation: String
        public let duration: TimeInterval
        public let timestamp: Date
        public let threadInfo: String

        public var formattedDuration: String {
            if duration < 0.001 {
                return String(format: "%.3f ms", duration * 1000)
            } else if duration < 1.0 {
                return String(format: "%.1f ms", duration * 1000)
            } else {
                return String(format: "%.2f s", duration)
            }
        }
    }

    /// Sequential operation detected
    public struct SequentialOperation: Sendable {
        public let location: String
        public let operationCount: Int
        public let totalDuration: TimeInterval
        public let canParallelize: Bool
        public let estimatedSpeedup: Double

        public var parallelizationOpportunity: String {
            if !canParallelize {
                return "Cannot parallelize (dependencies exist)"
            } else if estimatedSpeedup > 3.0 {
                return "🔴 High Priority (>\(String(format: "%.1f", estimatedSpeedup))x speedup)"
            } else if estimatedSpeedup > 2.0 {
                return "🟡 Medium Priority (\(String(format: "%.1f", estimatedSpeedup))x speedup)"
            } else {
                return "🟢 Low Priority (\(String(format: "%.1f", estimatedSpeedup))x speedup)"
            }
        }
    }

    // MARK: - Properties

    public static let shared = PerformanceAnalyzer()

    private let logger = Logger(subsystem: "com.ollvy.app", category: "PerformanceAnalyzer")
    private let queue = DispatchQueue(label: "com.ollvy.performance", qos: .utility)

    // Thread-safe measurement storage
    private var measurements: [Measurement] = []
    private let measurementLock = NSLock()

    private var isProfilingEnabled = false

    // MARK: - Public API

    /// Enable performance profiling
    public func enableProfiling() {
        isProfilingEnabled = true
        logger.info("📊 Performance profiling enabled")
    }

    /// Disable performance profiling
    public func disableProfiling() {
        isProfilingEnabled = false
        logger.info("📊 Performance profiling disabled")
    }

    /// Measure execution time of an operation
    public func measure<T>(
        operation: String,
        execute: () throws -> T
    ) rethrows -> T {
        let startTime = Date()
        let threadInfo = Thread.current.isMainThread ? "Main" : "Background"

        defer {
            if isProfilingEnabled {
                let duration = Date().timeIntervalSince(startTime)
                recordMeasurement(
                    operation: operation,
                    duration: duration,
                    threadInfo: threadInfo
                )
            }
        }

        return try execute()
    }

    /// Measure async operation
    public func measureAsync<T>(
        operation: String,
        execute: () async throws -> T
    ) async rethrows -> T {
        let startTime = Date()
        // In async contexts, Thread.current is unavailable in Swift 6
        // Use "Async" to indicate this runs in Swift concurrency context
        let threadInfo = "Async"

        defer {
            if isProfilingEnabled {
                let duration = Date().timeIntervalSince(startTime)
                recordMeasurement(
                    operation: operation,
                    duration: duration,
                    threadInfo: threadInfo
                )
            }
        }

        return try await execute()
    }

    /// Get all measurements
    public func getMeasurements() -> [Measurement] {
        measurementLock.lock()
        defer { measurementLock.unlock() }
        return measurements
    }

    /// Clear all measurements
    public func clearMeasurements() {
        measurementLock.lock()
        defer { measurementLock.unlock() }
        measurements.removeAll()
        logger.info("🧹 Cleared performance measurements")
    }

    /// Analyze measurements for sequential operations
    public func analyzeSequentialOperations() -> [SequentialOperation] {
        let allMeasurements = getMeasurements()

        // Group by operation prefix to find loops
        var operationGroups: [String: [Measurement]] = [:]

        for measurement in allMeasurements {
            // Extract base operation name (before iteration number)
            let baseName = extractBaseName(from: measurement.operation)
            operationGroups[baseName, default: []].append(measurement)
        }

        // Identify sequential patterns
        var sequential: [SequentialOperation] = []

        for (baseName, group) in operationGroups where group.count > 1 {
            let totalDuration = group.reduce(0) { $0 + $1.duration }
            _ = totalDuration / Double(group.count) // avgDuration for potential future use

            // Check if operations can be parallelized
            let canParallelize = checkParallelizability(group)

            // Estimate speedup (based on available cores)
            let coreCount = Double(ProcessInfo.processInfo.activeProcessorCount)
            let estimatedSpeedup = canParallelize ?
                min(Double(group.count), coreCount) : 1.0

            sequential.append(SequentialOperation(
                location: baseName,
                operationCount: group.count,
                totalDuration: totalDuration,
                canParallelize: canParallelize,
                estimatedSpeedup: estimatedSpeedup
            ))
        }

        // Sort by potential speedup
        return sequential.sorted { $0.estimatedSpeedup > $1.estimatedSpeedup }
    }

    /// Generate performance report
    public func generateReport() -> String {
        let measurements = getMeasurements()
        let sequential = analyzeSequentialOperations()

        var report = "# Performance Analysis Report\n\n"

        // Summary
        report += "## Summary\n"
        report += "- Total Operations: \(measurements.count)\n"
        report += "- Total Time: \(formatDuration(measurements.reduce(0) { $0 + $1.duration }))\n"
        report += "- Sequential Opportunities: \(sequential.count)\n\n"

        // Sequential Operations
        if !sequential.isEmpty {
            report += "## Sequential Operations (Parallelization Opportunities)\n\n"

            for op in sequential {
                report += "### \(op.location)\n"
                report += "- Operations: \(op.operationCount)\n"
                report += "- Total Duration: \(formatDuration(op.totalDuration))\n"
                report += "- \(op.parallelizationOpportunity)\n\n"
            }
        }

        // Slowest Operations
        let slowest = measurements.sorted { $0.duration > $1.duration }.prefix(10)
        if !slowest.isEmpty {
            report += "## Slowest Operations\n\n"

            for (index, measurement) in slowest.enumerated() {
                report += "\(index + 1). \(measurement.operation): \(measurement.formattedDuration)\n"
            }
            report += "\n"
        }

        return report
    }

    // MARK: - Private Methods

    private func recordMeasurement(
        operation: String,
        duration: TimeInterval,
        threadInfo: String
    ) {
        let measurement = Measurement(
            operation: operation,
            duration: duration,
            timestamp: Date(),
            threadInfo: threadInfo
        )

        measurementLock.lock()
        measurements.append(measurement)
        measurementLock.unlock()

        if duration > 0.1 {  // Log slow operations
            logger.debug("⏱️ \(operation): \(measurement.formattedDuration) (\(threadInfo))")
        }
    }

    private func extractBaseName(from operation: String) -> String {
        // Remove iteration numbers like "[0]", "[1]", etc.
        let pattern = #"\[\d+\]"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(operation.startIndex..., in: operation)
            return regex.stringByReplacingMatches(
                in: operation,
                range: range,
                withTemplate: ""
            )
        }
        return operation
    }

    private func checkParallelizability(_ measurements: [Measurement]) -> Bool {
        // Check if measurements are on main thread (likely dependent)
        let mainThreadCount = measurements.filter { $0.threadInfo == "Main" }.count

        // If most operations are on background threads, already parallelized
        if mainThreadCount < measurements.count / 2 {
            return false
        }

        // Check timing overlaps (if overlapping, already parallel)
        let sorted = measurements.sorted { $0.timestamp < $1.timestamp }
        for i in 0..<(sorted.count - 1) {
            let current = sorted[i]
            let next = sorted[i + 1]

            let currentEnd = current.timestamp.addingTimeInterval(current.duration)
            if next.timestamp < currentEnd {
                // Operations overlap - already parallel
                return false
            }
        }

        // Operations are sequential and on main thread - can parallelize
        return true
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 0.001 {
            return String(format: "%.3f ms", duration * 1000)
        } else if duration < 1.0 {
            return String(format: "%.1f ms", duration * 1000)
        } else {
            return String(format: "%.2f s", duration)
        }
    }
}

// MARK: - Parallel Execution Helpers

/// Helper for executing parallel operations with proper error handling
public final class ParallelExecutor {

    /// Execute tasks in parallel with TaskGroup
    public static func executeInParallel<T: Sendable>(
        tasks: [(String, () async throws -> T)],
        maxConcurrency: Int? = nil
    ) async throws -> [T] {
        let concurrency = maxConcurrency ?? ProcessInfo.processInfo.activeProcessorCount

        return try await withThrowingTaskGroup(of: (Int, T).self) { group in
            var results: [T?] = Array(repeating: nil, count: tasks.count)

            // Add tasks with index tracking
            for (index, (name, task)) in tasks.enumerated() {
                group.addTask {
                    let result = try await PerformanceAnalyzer.shared.measureAsync(
                        operation: name,
                        execute: task
                    )
                    return (index, result)
                }

                // Limit concurrent tasks
                if index >= concurrency {
                    if let (completedIndex, result) = try await group.next() {
                        results[completedIndex] = result
                    }
                }
            }

            // Collect remaining results
            for try await (index, result) in group {
                results[index] = result
            }

            return results.compactMap { $0 }
        }
    }

    /// Execute tasks in parallel chunks (for very large datasets)
    public static func executeInChunks<T: Sendable>(
        items: [T],
        chunkSize: Int = 100,
        operation: @escaping (T) async throws -> Void
    ) async throws {
        let chunks = items.chunked(into: chunkSize)

        for (chunkIndex, chunk) in chunks.enumerated() {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for (itemIndex, item) in chunk.enumerated() {
                    group.addTask {
                        try await PerformanceAnalyzer.shared.measureAsync(
                            operation: "Chunk[\(chunkIndex)]Item[\(itemIndex)]",
                            execute: { try await operation(item) }
                        )
                    }
                }

                try await group.waitForAll()
            }
        }
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
