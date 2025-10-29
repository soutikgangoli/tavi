//
//  CrashReporter.swift
//  Tavi
//
//  Crash reporting and error tracking utility
//  Created on 2025-10-29.
//

import Foundation

/// Crash reporting manager for production monitoring
///
/// To enable Firebase Crashlytics:
/// 1. Add Firebase SDK via SPM: https://github.com/firebase/firebase-ios-sdk
/// 2. Add GoogleService-Info.plist to project
/// 3. Uncomment Firebase imports below
/// 4. Call configure() in TaviApp.init()
///
/// For now, this provides local logging until Firebase is set up.
class CrashReporter {
    static let shared = CrashReporter()

    private var isEnabled = true
    private let logger = Logger(subsystem: "com.tavi.app", category: "CrashReporter")

    private init() {}

    // MARK: - Configuration

    /// Configure crash reporting (call from app launch)
    func configure() {
        #if DEBUG
        print("📊 CrashReporter: Development mode - crashes logged locally")
        isEnabled = true
        #else
        print("📊 CrashReporter: Production mode - Firebase not yet configured")
        isEnabled = true

        // TODO: Uncomment when Firebase is added via SPM
        // import FirebaseCore
        // import FirebaseCrashlytics
        // FirebaseApp.configure()
        // Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
    }

    // MARK: - Error Logging

    /// Log a non-fatal error with context
    /// - Parameters:
    ///   - error: The error to log
    ///   - context: Additional context (e.g., operation name, user action)
    func logError(_ error: Error, context: [String: Any] = [:]) {
        guard isEnabled else { return }

        let errorInfo = formatError(error, context: context)
        logger.error("🔴 Error: \(errorInfo)")

        // TODO: Send to Firebase Crashlytics
        // Crashlytics.crashlytics().record(error: error)
        // Crashlytics.crashlytics().setCustomKeysAndValues(context)
    }

    /// Log a non-fatal message (for tracking issues that aren't exceptions)
    /// - Parameters:
    ///   - message: Description of the issue
    ///   - level: Severity level
    ///   - metadata: Additional metadata
    func logMessage(
        _ message: String,
        level: LogLevel = .warning,
        metadata: [String: Any] = [:]
    ) {
        guard isEnabled else { return }

        let formattedMessage = formatMessage(message, level: level, metadata: metadata)

        switch level {
        case .debug:
            logger.debug("\(formattedMessage)")
        case .info:
            logger.info("\(formattedMessage)")
        case .warning:
            logger.warning("⚠️ \(formattedMessage)")
        case .error:
            logger.error("🔴 \(formattedMessage)")
        case .critical:
            logger.critical("‼️ \(formattedMessage)")
        }

        // TODO: Send to Firebase Crashlytics as non-fatal
        // let error = NSError(
        //     domain: "com.tavi.nonfatal",
        //     code: level.rawValue,
        //     userInfo: [NSLocalizedDescriptionKey: message]
        // )
        // Crashlytics.crashlytics().record(error: error)
    }

    /// Log a scan-specific error
    /// - Parameters:
    ///   - scanError: The scan error
    ///   - operation: What operation failed (e.g., "mesh_merge", "texture_bake")
    ///   - metrics: Optional metrics at time of failure
    func logScanError(
        _ scanError: ScanError,
        operation: String,
        metrics: [String: Any] = [:]
    ) {
        var context = metrics
        context["operation"] = operation
        context["error_type"] = String(describing: type(of: scanError))
        context["recoverable"] = scanError.isRecoverable

        logError(scanError, context: context)
    }

    // MARK: - User Context

    /// Set user context for crash reports (anonymized)
    /// - Parameters:
    ///   - userID: Anonymous user identifier (UUID, not email/name)
    ///   - metadata: Additional user metadata
    func setUserContext(userID: String, metadata: [String: Any] = [:]) {
        guard isEnabled else { return }

        logger.info("👤 User context set: \(userID)")

        // TODO: Set Firebase user ID
        // Crashlytics.crashlytics().setUserID(userID)
        // Crashlytics.crashlytics().setCustomKeysAndValues(metadata)
    }

    /// Clear user context (e.g., on logout)
    func clearUserContext() {
        guard isEnabled else { return }

        logger.info("👤 User context cleared")

        // TODO: Clear Firebase user ID
        // Crashlytics.crashlytics().setUserID(nil)
    }

    // MARK: - Custom Keys (Breadcrumbs)

    /// Log a custom key-value pair (breadcrumb)
    /// Useful for tracking user flow leading up to crash
    /// - Parameters:
    ///   - key: Key name
    ///   - value: Value (will be converted to string)
    func setCustomKey(_ key: String, value: Any) {
        guard isEnabled else { return }

        logger.debug("🔑 Custom key: \(key) = \(value)")

        // TODO: Set Firebase custom key
        // Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    /// Log a user action breadcrumb
    /// - Parameter action: Description of user action
    func logUserAction(_ action: String) {
        setCustomKey("last_action", value: action)
        logger.info("👆 User action: \(action)")
    }

    // MARK: - Formatting Helpers

    private func formatError(_ error: Error, context: [String: Any]) -> String {
        var parts: [String] = []

        // Error description
        if let scanError = error as? ScanError {
            parts.append("[\(scanError.id)]")
            if let desc = scanError.errorDescription {
                parts.append(desc)
            }
            if let recovery = scanError.recoverySuggestion {
                parts.append("Recovery: \(recovery)")
            }
        } else {
            parts.append(error.localizedDescription)
        }

        // Context
        if !context.isEmpty {
            let contextStr = context.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            parts.append("Context: \(contextStr)")
        }

        return parts.joined(separator: " | ")
    }

    private func formatMessage(
        _ message: String,
        level: LogLevel,
        metadata: [String: Any]
    ) -> String {
        var parts = [message]

        if !metadata.isEmpty {
            let metaStr = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            parts.append("[\(metaStr)]")
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Types

    enum LogLevel: Int {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4
    }
}

// MARK: - Logger Extension

import OSLog

private extension Logger {
    static let crashReporter = Logger(subsystem: "com.tavi.app", category: "CrashReporter")
}
