//
//  ARKitErrorAnalyzer.swift
//  Tavi
//
//  Comprehensive ARKit error analysis with recovery guidance
//  Provides user-friendly error messages and actionable recovery steps
//

import Foundation
import ARKit

/// Type of ARKit failure that occurred
public enum ARKitFailureType: CustomStringConvertible {
    case trackingLost              // Face tracking temporarily lost
    case multipleFaces             // Multiple faces detected
    case poorLighting              // Insufficient lighting
    case cameraOccluded            // Camera blocked/obscured
    case configurationFailed       // AR configuration error
    case sensorFailed              // Hardware sensor issue
    case permissionDenied          // Camera permission issue
    case insufficientFeatures      // Not enough facial features detected
    case deviceNotSupported        // Device doesn't support face tracking
    case sessionInterrupted        // Session interrupted by system
    case unknown                   // Unknown error

    public var description: String {
        switch self {
        case .trackingLost: return "trackingLost"
        case .multipleFaces: return "multipleFaces"
        case .poorLighting: return "poorLighting"
        case .cameraOccluded: return "cameraOccluded"
        case .configurationFailed: return "configurationFailed"
        case .sensorFailed: return "sensorFailed"
        case .permissionDenied: return "permissionDenied"
        case .insufficientFeatures: return "insufficientFeatures"
        case .deviceNotSupported: return "deviceNotSupported"
        case .sessionInterrupted: return "sessionInterrupted"
        case .unknown: return "unknown"
        }
    }

    /// Whether this error is recoverable without restarting
    public var isRecoverable: Bool {
        switch self {
        case .trackingLost, .multipleFaces, .poorLighting, .cameraOccluded,
             .insufficientFeatures, .sessionInterrupted:
            return true
        case .configurationFailed, .sensorFailed, .permissionDenied,
             .deviceNotSupported, .unknown:
            return false
        }
    }

    /// Whether to preserve partial capture data
    public var shouldPreserveData: Bool {
        switch self {
        case .trackingLost, .multipleFaces, .poorLighting, .cameraOccluded,
             .insufficientFeatures, .sessionInterrupted:
            return true  // Recoverable - keep data
        case .configurationFailed, .sensorFailed, .permissionDenied,
             .deviceNotSupported, .unknown:
            return false  // Fatal - discard data
        }
    }

    /// Time to wait before auto-recovery attempt (seconds)
    public var autoRecoveryDelay: TimeInterval? {
        switch self {
        case .trackingLost:
            return 1.0  // Quick retry for tracking loss
        case .sessionInterrupted:
            return 0.5  // Fast retry after interruption
        case .multipleFaces, .poorLighting, .cameraOccluded, .insufficientFeatures:
            return 2.0  // Give user time to fix issue
        default:
            return nil  // No auto-recovery
        }
    }
}

/// Detailed error information with recovery guidance
public struct ARKitErrorInfo {
    public let type: ARKitFailureType
    public let title: String
    public let message: String
    public let recoverySteps: [String]
    public let icon: String  // SF Symbol name
    public let shouldRetry: Bool
    public let shouldShowContinue: Bool  // Allow continuing with partial data

    /// Create error info
    public init(
        type: ARKitFailureType,
        title: String,
        message: String,
        recoverySteps: [String],
        icon: String,
        shouldRetry: Bool = true,
        shouldShowContinue: Bool = false
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.recoverySteps = recoverySteps
        self.icon = icon
        self.shouldRetry = shouldRetry
        self.shouldShowContinue = shouldShowContinue
    }
}

/// Analyzes ARKit errors and provides recovery guidance
public class ARKitErrorAnalyzer {

    // MARK: - Public API

    /// Analyze an ARKit error and provide detailed information
    /// - Parameters:
    ///   - error: The error from ARKit
    ///   - hadPartialCaptures: Whether user has already captured some poses
    /// - Returns: Detailed error information with recovery guidance
    public static func analyze(
        error: Error,
        hadPartialCaptures: Bool = false
    ) -> ARKitErrorInfo {
        // Try to cast to ARError first
        if let arError = error as? ARError {
            return analyzeARError(arError, hadPartialCaptures: hadPartialCaptures)
        }

        // Fallback to NSError analysis
        let nsError = error as NSError

        // Check domain and code
        if nsError.domain == "ARKit" {
            return analyzeCustomARError(nsError, hadPartialCaptures: hadPartialCaptures)
        }

        // Unknown error
        return unknownError(error, hadPartialCaptures: hadPartialCaptures)
    }

    /// Analyze tracking quality to detect potential issues before failure
    /// - Parameters:
    ///   - trackingState: Current AR tracking state
    ///   - faceAnchor: Current face anchor (if any)
    /// - Returns: Warning message if tracking quality is poor, nil otherwise
    public static func analyzeTrackingQuality(
        trackingState: ARCamera.TrackingState,
        faceAnchor: ARFaceAnchor?
    ) -> String? {
        switch trackingState {
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                return "Move more slowly"
            case .insufficientFeatures:
                return "Improve lighting"
            case .initializing:
                return "Initializing tracking..."
            case .relocalizing:
                return "Re-establishing tracking..."
            @unknown default:
                return "Tracking limited"
            }

        case .notAvailable:
            return "Tracking unavailable"

        case .normal:
            // Check if face anchor confidence is low
            if let anchor = faceAnchor, anchor.isTracked == false {
                return "Keep face visible"
            }
            return nil

        @unknown default:
            return "Unknown tracking state"
        }
    }

    // MARK: - Private Analysis Methods

    private static func analyzeARError(
        _ arError: ARError,
        hadPartialCaptures: Bool
    ) -> ARKitErrorInfo {
        switch arError.code {
        case .cameraUnauthorized:
            return ARKitErrorInfo(
                type: .permissionDenied,
                title: "Camera Access Required",
                message: "Tavi needs camera access to scan your face.",
                recoverySteps: [
                    "Open Settings app",
                    "Go to Tavi > Camera",
                    "Enable Camera access",
                    "Return to Tavi and try again"
                ],
                icon: "camera.fill",
                shouldRetry: false
            )

        case .sensorUnavailable:
            return ARKitErrorInfo(
                type: .sensorFailed,
                title: "Camera Sensor Unavailable",
                message: "The TrueDepth camera is not available.",
                recoverySteps: [
                    "Ensure no other app is using the camera",
                    "Restart the app",
                    "If problem persists, restart your device"
                ],
                icon: "exclamationmark.triangle.fill",
                shouldRetry: true
            )

        case .sensorFailed:
            return ARKitErrorInfo(
                type: .sensorFailed,
                title: "Camera Sensor Error",
                message: "The TrueDepth camera encountered an error.",
                recoverySteps: [
                    "Clean the camera lens",
                    "Close other apps using the camera",
                    "Restart the app"
                ],
                icon: "exclamationmark.triangle.fill",
                shouldRetry: true
            )

        case .worldTrackingFailed:
            return ARKitErrorInfo(
                type: .trackingLost,
                title: "Face Tracking Lost",
                message: "Face tracking was lost during the scan.",
                recoverySteps: [
                    "Keep your face centered in the camera",
                    "Move more slowly during turns",
                    "Ensure good lighting",
                    hadPartialCaptures ? "Continue from where you left off" : "Start the scan again"
                ],
                icon: "face.dashed",
                shouldRetry: true,
                shouldShowContinue: hadPartialCaptures
            )

        case .unsupportedConfiguration:
            return ARKitErrorInfo(
                type: .deviceNotSupported,
                title: "Device Not Supported",
                message: "Your device does not support face tracking.",
                recoverySteps: [
                    "Tavi requires an iPhone with Face ID",
                    "Supported: iPhone X or newer"
                ],
                icon: "iphone.slash",
                shouldRetry: false
            )

        case .invalidConfiguration:
            return ARKitErrorInfo(
                type: .configurationFailed,
                title: "Configuration Error",
                message: "Face tracking could not be configured properly.",
                recoverySteps: [
                    "Restart the app",
                    "Ensure no other apps are using ARKit",
                    "If problem persists, restart your device"
                ],
                icon: "gear.badge.xmark",
                shouldRetry: true
            )

        case .insufficientFeatures:
            return ARKitErrorInfo(
                type: .insufficientFeatures,
                title: "Insufficient Facial Features",
                message: "Not enough facial features detected.",
                recoverySteps: [
                    "Improve lighting conditions",
                    "Remove any face coverings",
                    "Keep your face fully visible",
                    "Try again"
                ],
                icon: "lightbulb.fill",
                shouldRetry: true,
                shouldShowContinue: hadPartialCaptures
            )

        case .fileIOFailed, .microphoneUnauthorized, .requestFailed,
             .invalidReferenceImage, .invalidReferenceObject, .invalidWorldMap,
             .invalidCollaborationData, .locationUnauthorized:
            // These shouldn't happen in face tracking, but handle anyway
            return ARKitErrorInfo(
                type: .unknown,
                title: "Unexpected Error",
                message: "An unexpected error occurred: \(arError.localizedDescription)",
                recoverySteps: [
                    "Try restarting the scan",
                    "If problem persists, restart the app"
                ],
                icon: "exclamationmark.circle.fill",
                shouldRetry: true
            )

        default:
            return unknownError(arError, hadPartialCaptures: hadPartialCaptures)
        }
    }

    private static func analyzeCustomARError(
        _ error: NSError,
        hadPartialCaptures: Bool
    ) -> ARKitErrorInfo {
        let description = error.localizedDescription.lowercased()

        // Check error description for common patterns
        if description.contains("not supported") {
            return ARKitErrorInfo(
                type: .deviceNotSupported,
                title: "Device Not Supported",
                message: error.localizedDescription,
                recoverySteps: [
                    "Tavi requires an iPhone with Face ID",
                    "Supported: iPhone X or newer"
                ],
                icon: "iphone.slash",
                shouldRetry: false
            )
        }

        if description.contains("metal") {
            return ARKitErrorInfo(
                type: .deviceNotSupported,
                title: "Graphics Hardware Error",
                message: "Your device does not support the required graphics features.",
                recoverySteps: [
                    "Ensure your iOS is up to date",
                    "Try restarting your device"
                ],
                icon: "exclamationmark.triangle.fill",
                shouldRetry: false
            )
        }

        return unknownError(error, hadPartialCaptures: hadPartialCaptures)
    }

    private static func unknownError(
        _ error: Error,
        hadPartialCaptures: Bool
    ) -> ARKitErrorInfo {
        return ARKitErrorInfo(
            type: .unknown,
            title: "Scan Error",
            message: "An error occurred: \(error.localizedDescription)",
            recoverySteps: [
                "Try scanning again",
                "Ensure good lighting",
                "Keep your face visible",
                hadPartialCaptures ? "Your progress has been saved" : "Close other apps if needed"
            ],
            icon: "exclamationmark.circle.fill",
            shouldRetry: true,
            shouldShowContinue: hadPartialCaptures
        )
    }

    // MARK: - Interruption Analysis

    /// Analyze a session interruption
    /// - Returns: Error info for the interruption
    public static func analyzeInterruption() -> ARKitErrorInfo {
        return ARKitErrorInfo(
            type: .sessionInterrupted,
            title: "Scan Paused",
            message: "The scan was paused (incoming call, app switch, etc.)",
            recoverySteps: [
                "The scan will resume automatically",
                "Or tap Continue to resume manually"
            ],
            icon: "pause.circle.fill",
            shouldRetry: true,
            shouldShowContinue: true
        )
    }

    /// Analyze multiple faces detected
    /// - Returns: Error info for multiple faces
    public static func analyzeMultipleFaces() -> ARKitErrorInfo {
        return ARKitErrorInfo(
            type: .multipleFaces,
            title: "Multiple Faces Detected",
            message: "Only one face should be visible during the scan.",
            recoverySteps: [
                "Ensure you're alone in the frame",
                "Ask others to move out of view",
                "Try scanning again"
            ],
            icon: "person.2.slash",
            shouldRetry: true,
            shouldShowContinue: true
        )
    }

    /// Analyze poor lighting conditions
    /// - Returns: Error info for poor lighting
    public static func analyzePoorLighting() -> ARKitErrorInfo {
        return ARKitErrorInfo(
            type: .poorLighting,
            title: "Poor Lighting",
            message: "The lighting is too dark for accurate face scanning.",
            recoverySteps: [
                "Move to a well-lit area",
                "Avoid backlighting (light behind you)",
                "Use natural or bright indoor light",
                "Try scanning again"
            ],
            icon: "lightbulb.slash.fill",
            shouldRetry: true,
            shouldShowContinue: true
        )
    }
}
