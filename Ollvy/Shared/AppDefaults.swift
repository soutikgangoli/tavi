//
//  AppDefaults.swift
//  Ollvy
//
//  Centralized UserDefaults keys for the entire app.
//  All UserDefaults and @AppStorage keys should be defined here.
//

import Foundation

/// Centralized UserDefaults keys - prevents typos and enables easy refactoring
/// Usage: @AppStorage(AppDefaultsKey.debugModeEnabled) var debugMode: Bool = false
/// Usage: UserDefaults.standard.bool(forKey: AppDefaultsKey.debugModeEnabled)
enum AppDefaultsKey {

    // MARK: - Debug & Development

    /// Enable debug mode features
    static let debugModeEnabled = "debugModeEnabled"

    /// Enable verbose logging output
    static let verboseLoggingEnabled = "verboseLoggingEnabled"

    // MARK: - Onboarding & First Run

    /// User has completed the onboarding flow
    static let hasCompletedOnboarding = "hasCompletedOnboarding"

    /// Skip onboarding (for testing)
    static let skipOnboarding = "skipOnboarding"

    /// User has viewed the metric help tooltip
    static let hasViewedMetricHelp = "hasViewedMetricHelp"

    // MARK: - Security

    /// Enable biometric (Face ID/Touch ID) lock
    static let biometricLockEnabled = "biometricLockEnabled"

    // MARK: - Capture Settings

    /// Enable high resolution capture mode
    static let enableHighResCapture = "enableHighResCapture"

    /// Enable face mesh visualization during scan
    static let enableFaceMesh = "enableFaceMesh"

    /// Use realtime processing during capture
    static let useRealtimeProcessing = "useRealtimeProcessing"

    /// Enable haptic feedback during capture
    static let enableHapticFeedback = "enableHapticFeedback"

    /// Lighting strictness level (0.0 - 1.0)
    static let lightingStrictness = "lightingStrictness"

    // MARK: - Feature Detection Settings

    /// Detect glasses during validation
    static let detectGlasses = "detectGlasses"

    /// Detect hands during validation
    static let detectHands = "detectHands"

    /// Detect hat/head covering during validation
    static let detectHat = "detectHat"

    /// Detect makeup during validation
    static let detectMakeup = "detectMakeup"

    /// Detect hair coverage on face during validation
    static let detectHairCoverage = "detectHairCoverage"

    /// Detect sunburn during analysis
    static let detectSunburn = "detectSunburn"

    /// Detect earrings during validation
    static let detectEarrings = "detectEarrings"

    /// Detect facial hair during validation
    static let detectFacialHair = "detectFacialHair"

    // MARK: - Notifications

    /// Enable scan reminder notifications
    static let scanRemindersEnabled = "scanRemindersEnabled"

    /// Enable challenge notifications
    static let challengeNotificationsEnabled = "challengeNotificationsEnabled"

    /// Enable achievement notifications
    static let achievementNotificationsEnabled = "achievementNotificationsEnabled"

    /// Enable progress report notifications
    static let progressReportsEnabled = "progressReportsEnabled"

    /// Time for scan reminders (stored as Date)
    static let scanReminderTime = "scanReminderTime"

    // MARK: - Analytics

    /// Analytics enabled flag
    static let analyticsEnabled = "analytics_enabled"

    /// Analytics events storage key
    static let analyticsEvents = "analytics_events"

    // MARK: - Processing Time Estimation

    /// Prefix for processing time keys (append metric name)
    static let processingTimePrefix = "ProcessingTime_"

    /// Scan count for processing time estimation
    static let processingTimeScanCount = "ProcessingTimeEstimator_ScanCount"

    // MARK: - Storage

    /// Last cleanup date for storage manager
    static let lastCleanupDate = "lastCleanupDate"

    /// Storage usage tracking
    static let storageUsageBytes = "storageUsageBytes"
}
