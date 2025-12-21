//
//  AsyncTimeout.swift
//  Tavi
//
//  Utility for adding timeout protection to async operations
//  Fixes Issue #12: Prevents indefinite hangs in processing pipeline
//

import Foundation

/// Error thrown when an async operation times out
public enum TimeoutError: LocalizedError {
    case timedOut(operation: String, duration: TimeInterval)

    public var errorDescription: String? {
        switch self {
        case .timedOut(let operation, let duration):
            return "Operation '\(operation)' timed out after \(duration) seconds"
        }
    }

    public var failureReason: String? {
        switch self {
        case .timedOut:
            return "The operation took too long to complete"
        }
    }

    public var recoverySuggestion: String? {
        return "Please try again. If the problem persists, check your device performance and available memory."
    }
}

/// Execute an async operation with a timeout
/// - Parameters:
///   - seconds: Timeout duration in seconds
///   - operation: The async operation name (for error messages)
///   - work: The async work to perform
/// - Returns: The result of the async work
/// - Throws: CancellationError if cancelled, TimeoutError if the operation exceeds the timeout, or any error thrown by the work
public func withTimeout<T>(
    seconds: TimeInterval,
    operation: String = "operation",
    _ work: @escaping @Sendable () async throws -> T
) async throws -> T {
    // CRITICAL FIX: Check cancellation IMMEDIATELY before creating any tasks
    // This allows the caller to cancel and have withTimeout exit right away
    // without waiting for the TaskGroup to be set up or any work to start
    try Task.checkCancellation()
    
    let startTime = Date()
    AppLogger.app.debug("⏱️ withTimeout: Starting '\(operation)' with \(seconds)s timeout")

    let result: T = try await withThrowingTaskGroup(of: T.self) { group in
        // Add the actual work task
        group.addTask {
            // Check cancellation at start of work task
            try Task.checkCancellation()
            
            AppLogger.app.debug("⏱️ withTimeout: Work task started for '\(operation)'")
            let workResult = try await work()
            
            // Check cancellation after work completes
            try Task.checkCancellation()
            
            let elapsed = Date().timeIntervalSince(startTime)
            AppLogger.app.debug("⏱️ withTimeout: Work task completed for '\(operation)' in \(elapsed)s")
            return workResult
        }

        // Add the timeout task
        group.addTask {
            // Check cancellation before starting timeout
            try Task.checkCancellation()
            
            AppLogger.app.debug("⏱️ withTimeout: Timeout task started for '\(operation)'")
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            
            // Check cancellation after sleep (sleep throws CancellationError if cancelled)
            try Task.checkCancellation()
            
            let elapsed = Date().timeIntervalSince(startTime)
            AppLogger.app.debug("⏱️ withTimeout: Timeout task firing for '\(operation)' at \(elapsed)s")
            throw TimeoutError.timedOut(operation: operation, duration: seconds)
        }

        // Wait for the first task to complete
        AppLogger.app.debug("⏱️ withTimeout: Waiting for first task to complete for '\(operation)'")
        
        do {
            guard let result = try await group.next() else {
                let elapsed = Date().timeIntervalSince(startTime)
                AppLogger.app.debug("⏱️ withTimeout: No result from group.next() for '\(operation)' at \(elapsed)s")
                throw TimeoutError.timedOut(operation: operation, duration: seconds)
            }

            let elapsed = Date().timeIntervalSince(startTime)
            AppLogger.app.debug("⏱️ withTimeout: Got result from first task for '\(operation)' at \(elapsed)s")

            // Cancel remaining tasks
            group.cancelAll()
            AppLogger.app.debug("⏱️ withTimeout: Cancelled remaining tasks for '\(operation)'")

            return result
        } catch is CancellationError {
            // CRITICAL: Propagate cancellation immediately without waiting
            AppLogger.app.info("⏱️ withTimeout: '\(operation)' cancelled - exiting immediately")
            group.cancelAll()
            throw CancellationError()
        }
    }

    // Final cancellation check before returning
    try Task.checkCancellation()

    let totalElapsed = Date().timeIntervalSince(startTime)
    AppLogger.app.debug("⏱️ withTimeout: Returning result for '\(operation)' after \(totalElapsed)s")
    return result
}

/// Execute an async operation with a timeout, returning nil on timeout instead of throwing
/// - Parameters:
///   - seconds: Timeout duration in seconds
///   - operation: The async operation name (for logging)
///   - work: The async work to perform
/// - Returns: The result of the async work, or nil if it times out
public func withTimeoutOptional<T>(
    seconds: TimeInterval,
    operation: String = "operation",
    _ work: @escaping @Sendable () async throws -> T
) async -> T? {
    do {
        return try await withTimeout(seconds: seconds, operation: operation, work)
    } catch is TimeoutError {
        AppLogger.app.info("⏱️ Timeout: \(operation) exceeded \(seconds) seconds")
        return nil
    } catch {
        AppLogger.app.error("❌ Error in \(operation): \(error.localizedDescription)")
        return nil
    }
}

// MARK: - Convenience Extensions

extension Task where Success == Never, Failure == Never {
    /// Sleep for a given number of seconds
    public static func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
