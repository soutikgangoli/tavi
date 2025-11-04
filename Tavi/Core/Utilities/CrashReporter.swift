//
//  CrashReporter.swift
//  Tavi
//
//  Crash reporting and error tracking utility
//  Created on 2025-10-29.
//
//  🔧 SETUP INSTRUCTIONS:
//  =====================
//
//  Before releasing to production, configure Sentry crash reporting:
//
//  1. Sign up at https://sentry.io (free tier available)
//  2. Create a new iOS project in Sentry dashboard
//  3. Copy your DSN (looks like: https://abc123@o123456.ingest.sentry.io/123456)
//  4. Add to Info.plist:
//     - Key: SENTRY_DSN
//     - Type: String
//     - Value: <your DSN from step 3>
//
//  OR for development testing, add to Xcode scheme environment variables:
//     - Name: SENTRY_DSN
//     - Value: <your DSN>
//
//  5. Build and test - check Xcode console for "📊 CrashReporter: Production mode - Sentry enabled"
//  6. Verify in Sentry dashboard that events are received
//
//  Without configuration, crash reporting will be disabled (logged in console).
//

import Foundation
#if canImport(Sentry)
import Sentry
#endif

/// Crash reporting manager for production monitoring
///
/// Uses Sentry for crash and error tracking:
/// - Automatic crash detection
/// - Non-fatal error logging
/// - Performance monitoring (20% sample rate)
/// - Release tracking
/// - User context and breadcrumbs
/// - Session tracking
///
/// Configuration is done via Info.plist (SENTRY_DSN key) or environment variable.
/// See file header for detailed setup instructions.
class CrashReporter {
    static let shared = CrashReporter()

    private var isEnabled = true
    private let logger = Logger(subsystem: "com.tavi.app", category: "CrashReporter")

    private init() {}

    // MARK: - Configuration

    /// Configure crash reporting (call from app launch)
    func configure() {
        #if canImport(Sentry)
        configureSentry()
        #else
        print("📊 CrashReporter: Sentry SDK not available - using local logging only")
        print("   To enable Sentry: Add package dependency https://github.com/getsentry/sentry-cocoa.git")
        isEnabled = true
        #endif
    }

    #if canImport(Sentry)
    private func configureSentry() {
        // Get Sentry DSN from environment variable or Info.plist
        let dsn = getSentryDSN()

        #if DEBUG
        print("📊 CrashReporter: Development mode - crashes logged locally")

        if dsn.isEmpty {
            print("⚠️ Sentry DSN not configured. Crash reporting disabled in DEBUG mode.")
            print("   To enable:")
            print("   1. Sign up at https://sentry.io")
            print("   2. Create a new iOS project")
            print("   3. Add SENTRY_DSN to environment variables or Info.plist")
            isEnabled = false
            return
        }

        isEnabled = true

        // Initialize Sentry in debug mode (only for testing)
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = "development"
            options.debug = true
            options.enableAutoSessionTracking = true
            options.sessionTrackingIntervalMillis = 5000

            // Disable in debug to avoid noise, unless testing
            options.enabled = ProcessInfo.processInfo.environment["SENTRY_ENABLED"] == "true"
        }
        #else
        // PRODUCTION BUILD

        if dsn.isEmpty {
            print("❌ CRITICAL: Sentry DSN not configured in PRODUCTION build!")
            print("   Crash reporting is DISABLED. This should not happen in production.")
            print("   Add SENTRY_DSN to Info.plist before releasing to App Store.")
            isEnabled = false
            return
        }

        print("📊 CrashReporter: Production mode - Sentry enabled")
        print("   DSN: \(dsn.prefix(20))...")
        isEnabled = true

        // Initialize Sentry for production
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = "production"
            options.debug = false

            // Enable performance monitoring
            options.enableAutoPerformanceTracing = true
            options.tracesSampleRate = 0.2  // 20% of transactions

            // Enable session tracking
            options.enableAutoSessionTracking = true

            // Attach stack traces to errors
            options.attachStacktrace = true

            // Set release version
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                options.releaseName = "\(version) (\(build))"
            }

            // Before send callback - filter out low priority errors
            options.beforeSend = { event in
                // Filter out cancellation errors (user-initiated)
                if let exceptions = event.exceptions,
                   exceptions.contains(where: { $0.type?.contains("CancellationError") ?? false }) {
                    return nil
                }
                return event
            }
        }
        #endif
    }

    /// Get Sentry DSN from environment or Info.plist
    /// Priority: Environment variable > Info.plist > Empty string
    private func getSentryDSN() -> String {
        // 1. Try environment variable (for development/testing)
        if let envDSN = ProcessInfo.processInfo.environment["SENTRY_DSN"], !envDSN.isEmpty {
            return envDSN
        }

        // 2. Try Info.plist (for production builds)
        if let plistDSN = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String, !plistDSN.isEmpty {
            return plistDSN
        }

        // 3. No DSN configured
        return ""
    }
    #endif

    // MARK: - Error Logging

    /// Log a non-fatal error with context
    /// - Parameters:
    ///   - error: The error to log
    ///   - context: Additional context (e.g., operation name, user action)
    func logError(_ error: Error, context: [String: Any] = [:]) {
        guard isEnabled else { return }

        let errorInfo = formatError(error, context: context)
        logger.error("🔴 Error: \(errorInfo)")

        // Send to Sentry
        #if canImport(Sentry)
        SentrySDK.capture(error: error) { scope in
            // Add context as tags and extras
            for (key, value) in context {
                if let stringValue = value as? String, stringValue.count < 200 {
                    scope.setTag(value: stringValue, key: key)
                } else {
                    // Convert Any to a Sentry-compatible value (must be NSObject for Objective-C bridge)
                    scope.setExtra(value: self.toNSObject(value), key: key)
                }
            }

            // Add error-specific context
            if let scanError = error as? ScanError {
                scope.setTag(value: scanError.id, key: "scan_error_type")
                scope.setTag(value: String(scanError.isRecoverable), key: "is_recoverable")
                scope.setTag(value: String(scanError.isBlockingError), key: "is_blocking")
                scope.setLevel(.error)
            }
        }
        #endif
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

        // Send to Sentry as breadcrumb or message
        #if canImport(Sentry)
        if level == .debug || level == .info {
            // Low priority - just breadcrumb
            let crumb = Breadcrumb(level: level.toSentryLevel(), category: "app.message")
            crumb.message = message
            SentrySDK.addBreadcrumb(crumb)
        } else {
            // Warning/error/critical - send as event
            let event = Event(level: level.toSentryLevel())
            event.message = SentryMessage(formatted: message)

            for (key, value) in metadata {
                // Convert Any to a compatible value (must be NSObject for Objective-C bridge)
                event.extra?[key] = self.toNSObject(value)
            }

            SentrySDK.capture(event: event)
        }
        #endif
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

        // Set Sentry user context
        #if canImport(Sentry)
        let user = User(userId: userID)
        for (key, value) in metadata {
            // Convert Any to a compatible value (must be NSObject for Objective-C bridge)
            user.data?[key] = self.toNSObject(value)
        }
        SentrySDK.setUser(user)
        #endif
    }

    /// Clear user context (e.g., on logout)
    func clearUserContext() {
        guard isEnabled else { return }

        logger.info("👤 User context cleared")

        // Clear Sentry user context
        #if canImport(Sentry)
        SentrySDK.setUser(nil)
        #endif
    }

    // MARK: - Custom Keys (Breadcrumbs)

    /// Log a custom key-value pair (breadcrumb)
    /// Useful for tracking user flow leading up to crash
    /// - Parameters:
    ///   - key: Key name
    ///   - value: Value (will be converted to string)
    func setCustomKey(_ key: String, value: Any) {
        guard isEnabled else { return }

        logger.debug("🔑 Custom key: \(key) = \(String(describing: value))")

        // Set as Sentry tag or context
        #if canImport(Sentry)
        SentrySDK.configureScope { scope in
            if let stringValue = value as? String, stringValue.count < 200 {
                scope.setTag(value: stringValue, key: key)
            } else {
                // Convert Any to a compatible dictionary value (must be NSObject for Objective-C bridge)
                let contextDict: [String: Any] = [key: self.toNSObject(value)]
                scope.setContext(value: contextDict, key: "custom_keys")
            }
        }
        #endif
    }

    /// Log a user action breadcrumb
    /// - Parameter action: Description of user action
    func logUserAction(_ action: String) {
        setCustomKey("last_action", value: action)
        logger.info("👆 User action: \(action)")

        // Add Sentry breadcrumb
        #if canImport(Sentry)
        let crumb = Breadcrumb(level: .info, category: "user.action")
        crumb.message = action
        crumb.type = "user"
        SentrySDK.addBreadcrumb(crumb)
        #endif
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

    // MARK: - Helper Methods

    /// Convert Any value to NSObject for Sentry SDK
    private func toNSObject(_ value: Any) -> NSObject {
        if let str = value as? String {
            return str as NSString
        } else if let num = value as? NSNumber {
            return num
        } else if let bool = value as? Bool {
            return NSNumber(value: bool)
        } else {
            return String(describing: value) as NSString
        }
    }

    // MARK: - Types

    enum LogLevel: Int {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4

        #if canImport(Sentry)
        func toSentryLevel() -> SentryLevel {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .warning
            case .error: return .error
            case .critical: return .fatal
            }
        }
        #endif
    }
}

// MARK: - Logger Extension

import OSLog

private extension Logger {
    static let crashReporter = Logger(subsystem: "com.tavi.app", category: "CrashReporter")
}
