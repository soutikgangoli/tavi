//
//  AppLogger.swift
//  Ollvy
//
//  Centralized logging utility using os.log
//  Fixes Issue #20: Replaces print statements with proper logging
//

import Foundation
import os.log

/// Centralized logging utility for the Ollvy app
public struct AppLogger {

    // MARK: - Subsystem

    private static let subsystem = "com.ollvy.app"

    // MARK: - Categories

    /// Logger for face scanning operations
    public static let faceScan = Logger(subsystem: subsystem, category: "FaceScan")

    /// Logger for metrics analysis
    public static let metrics = Logger(subsystem: subsystem, category: "Metrics")

    /// Logger for mesh processing
    public static let mesh = Logger(subsystem: subsystem, category: "Mesh")

    /// Logger for CoreData operations
    public static let storage = Logger(subsystem: subsystem, category: "Storage")

    /// Logger for networking
    public static let network = Logger(subsystem: subsystem, category: "Network")

    /// Logger for user interface
    public static let ui = Logger(subsystem: subsystem, category: "UI")

    /// Logger for gamification
    public static let gamification = Logger(subsystem: subsystem, category: "Gamification")

    /// Logger for authentication
    public static let auth = Logger(subsystem: subsystem, category: "Authentication")

    /// Logger for export operations
    public static let export = Logger(subsystem: subsystem, category: "Export")

    /// Logger for social sharing
    public static let social = Logger(subsystem: subsystem, category: "Social")

    /// Logger for general app operations
    public static let app = Logger(subsystem: subsystem, category: "App")

    /// Logger for memory management
    public static let memory = Logger(subsystem: subsystem, category: "Memory")

    // MARK: - Convenience Methods

    /// Log debug message
    public static func debug(_ message: String, category: Logger = AppLogger.app) {
        category.debug("\(message)")
    }

    /// Log info message
    public static func info(_ message: String, category: Logger = AppLogger.app) {
        category.info("\(message)")
    }

    /// Log warning message
    public static func warning(_ message: String, category: Logger = AppLogger.app) {
        category.warning("\(message)")
    }

    /// Log error message
    public static func error(_ message: String, category: Logger = AppLogger.app) {
        category.error("\(message)")
    }

    /// Log critical error message
    public static func critical(_ message: String, category: Logger = AppLogger.app) {
        category.critical("\(message)")
    }

    /// Log with fault level (for unexpected errors)
    public static func fault(_ message: String, category: Logger = AppLogger.app) {
        category.fault("\(message)")
    }
}

// MARK: - Extensions for Common Operations

extension AppLogger {

    /// Log face scan event
    public static func logScanEvent(_ event: String, details: String? = nil) {
        if let details = details {
            faceScan.info("\(event): \(details)")
        } else {
            faceScan.info("\(event)")
        }
    }

    /// Log metrics computation
    public static func logMetrics(_ message: String, level: LogLevel = .info) {
        switch level {
        case .debug:
            metrics.debug("\(message)")
        case .info:
            metrics.info("\(message)")
        case .warning:
            metrics.warning("\(message)")
        case .error:
            metrics.error("\(message)")
        }
    }

    /// Log mesh processing
    public static func logMesh(_ message: String, level: LogLevel = .info) {
        switch level {
        case .debug:
            mesh.debug("\(message)")
        case .info:
            mesh.info("\(message)")
        case .warning:
            mesh.warning("\(message)")
        case .error:
            mesh.error("\(message)")
        }
    }

    /// Log storage operation
    public static func logStorage(_ operation: String, success: Bool, error: Error? = nil) {
        if success {
            storage.info("✅ \(operation) succeeded")
        } else if let error = error {
            storage.error("❌ \(operation) failed: \(error.localizedDescription)")
        } else {
            storage.error("❌ \(operation) failed")
        }
    }
}

// MARK: - Log Level

public enum LogLevel {
    case debug
    case info
    case warning
    case error
}

// MARK: - Debug Print Function

/// Debug print function that logs to AppLogger
public func debugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let message = items.map { "\($0)" }.joined(separator: separator)
    AppLogger.debug(message)
}
