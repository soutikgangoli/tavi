//
//  DebugSettings.swift
//  Tavi
//
//  Centralized debug settings for controlling log verbosity
//  Created on 2025-01-10.
//

import Foundation

/// Centralized debug settings manager
public struct DebugSettings {

    /// Check if debug mode is enabled in Settings
    public static var isDebugModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: "debugModeEnabled")
    }

    /// Check if verbose logging is enabled (logs every 10-30 frames)
    public static var isVerboseLoggingEnabled: Bool {
        // Only enable verbose logging if both debug mode AND verbose flag are on
        isDebugModeEnabled && UserDefaults.standard.bool(forKey: "verboseLoggingEnabled")
    }

    /// Enable/disable verbose logging
    public static func setVerboseLogging(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "verboseLoggingEnabled")
    }

    /// Frame frequency for periodic logging (log every N frames)
    public static var logFrequency: Int {
        isVerboseLoggingEnabled ? 10 : 30  // More frequent when verbose is on
    }
}
