//
//  BiometricAuth.swift
//  Tavi
//
//  Biometric authentication utility (Face ID / Touch ID)
//  Fixes Issue #17: Adds privacy protection for sensitive skin photos
//

import Foundation
import LocalAuthentication

/// Biometric authentication manager
public class BiometricAuth {

    public static let shared = BiometricAuth()

    private init() {}

    // MARK: - Public API

    /// Check if biometric authentication is available
    /// - Returns: True if Face ID or Touch ID is available
    public func isBiometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?

        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Get the type of biometric authentication available
    /// - Returns: Biometric type (faceID, touchID, or none)
    public func biometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .none, .opticID:
            return .none
        @unknown default:
            return .none
        }
    }

    /// Authenticate user with biometrics
    /// - Parameter reason: Reason shown to user
    /// - Returns: True if authentication succeeded
    public func authenticate(reason: String = "Authenticate to view your scan results") async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?

        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            AppLogger.app.info("Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
            // Fallback to device passcode if biometrics not available
            return await authenticateWithPasscode(reason: reason)
        }

        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch let laError as LAError {
            AppLogger.app.info("Biometric authentication failed: \(laError.localizedDescription)")
            // Handle specific errors
            switch laError.code {
            case .userCancel, .appCancel, .systemCancel:
                // User cancelled or system cancelled
                return false
            case .userFallback:
                // User chose to use passcode instead
                return await authenticateWithPasscode(reason: reason)
            case .biometryNotAvailable, .biometryNotEnrolled:
                // Biometrics not set up, fallback to passcode
                return await authenticateWithPasscode(reason: reason)
            default:
                return false
            }
        } catch {
            AppLogger.app.error("Unexpected authentication error: \(error.localizedDescription)")
            return false
        }
    }

    /// Authenticate with device passcode as fallback
    /// - Parameter reason: Reason shown to user
    /// - Returns: True if authentication succeeded
    public func authenticateWithPasscode(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            AppLogger.app.info("Passcode authentication failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Settings

    /// Check if user has enabled biometric lock in settings
    public func isBiometricLockEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "biometricLockEnabled")
    }

    /// Enable or disable biometric lock
    public func setBiometricLock(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "biometricLockEnabled")
    }
}

// MARK: - Biometric Type

public enum BiometricType {
    case faceID
    case touchID
    case none

    public var displayName: String {
        switch self {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .none:
            return "Biometric Authentication"
        }
    }

    public var icon: String {
        switch self {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .none:
            return "lock"
        }
    }
}
