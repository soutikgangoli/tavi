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
/// - Throws: TimeoutError if the operation exceeds the timeout, or any error thrown by the work
public func withTimeout<T>(
    seconds: TimeInterval,
    operation: String = "operation",
    _ work: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the actual work task
        group.addTask {
            try await work()
        }

        // Add the timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError.timedOut(operation: operation, duration: seconds)
        }

        // Wait for the first task to complete
        guard let result = try await group.next() else {
            throw TimeoutError.timedOut(operation: operation, duration: seconds)
        }

        // Cancel remaining tasks
        group.cancelAll()

        return result
    }
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
        print("⏱️ Timeout: \(operation) exceeded \(seconds) seconds")
        return nil
    } catch {
        print("❌ Error in \(operation): \(error.localizedDescription)")
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
