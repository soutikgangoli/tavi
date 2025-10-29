//
//  ScanError.swift
//  Tavi
//
//  Created on October 29, 2025.
//

import Foundation

/// Errors that can occur during the face scanning and processing pipeline
enum ScanError: Error, LocalizedError, Identifiable {
    // MARK: - Capture Errors

    /// Failed to initialize ARKit face tracking session
    case arSessionFailed(underlying: Error?)

    /// Camera permission denied or TrueDepth camera unavailable
    case cameraUnavailable

    /// TrueDepth camera not supported on this device
    case trueDepthUnsupported

    /// No face detected in camera frame
    case faceNotDetected

    /// Multiple faces detected (scan requires one face)
    case multipleFacesDetected

    /// Scan was cancelled by user
    case cancelled

    // MARK: - Quality Errors

    /// Lighting is too low for quality scan
    case lightingTooLow(current: Float, required: Float)

    /// Lighting is too high (overexposed)
    case lightingTooHigh(current: Float, max: Float)

    /// Image is too blurry
    case blurryImage(score: Float)

    /// Face is partially occluded
    case occludedFace(regions: [String])

    /// Invalid facial expression detected
    case invalidExpression(issues: [String])

    // MARK: - Processing Errors

    /// Failed to merge captured face meshes into a single unified mesh
    case mergeFailed(reason: String? = nil)

    /// Failed to bake texture from captured sequence onto the merged mesh
    case bakeFailed(reason: String? = nil)

    /// Failed to compute clinical metrics from the processed mesh data
    case metricsFailed(analyzer: String? = nil, reason: String? = nil)

    /// Processing operation timed out
    case processingTimeout(operation: String, seconds: Double)

    /// Invalid or corrupted scan data
    case invalidData(field: String)

    // MARK: - Storage Errors

    /// Failed to save to Core Data
    case coreDataSaveFailed(underlying: Error)

    /// Insufficient device storage
    case insufficientStorage(required: Int64, available: Int64)

    /// Corrupted data in storage
    case corruptedData(entity: String)

    // MARK: - Generic

    /// Generic processing error with underlying cause
    case processingError(String)

    // MARK: - Identifiable

    var id: String {
        switch self {
        case .arSessionFailed: return "ar_session_failed"
        case .cameraUnavailable: return "camera_unavailable"
        case .trueDepthUnsupported: return "truedepth_unsupported"
        case .faceNotDetected: return "face_not_detected"
        case .multipleFacesDetected: return "multiple_faces"
        case .cancelled: return "cancelled"
        case .lightingTooLow: return "lighting_too_low"
        case .lightingTooHigh: return "lighting_too_high"
        case .blurryImage: return "blurry_image"
        case .occludedFace: return "occluded_face"
        case .invalidExpression: return "invalid_expression"
        case .mergeFailed: return "merge_failed"
        case .bakeFailed: return "bake_failed"
        case .metricsFailed: return "metrics_failed"
        case .processingTimeout: return "processing_timeout"
        case .invalidData: return "invalid_data"
        case .coreDataSaveFailed: return "save_failed"
        case .insufficientStorage: return "insufficient_storage"
        case .corruptedData: return "corrupted_data"
        case .processingError: return "processing_error"
        }
    }

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        // Capture Errors
        case .arSessionFailed:
            return "Failed to start face tracking. Please restart the app and try again."
        case .cameraUnavailable:
            return "Camera access is required for face scanning. Please enable camera permissions in Settings."
        case .trueDepthUnsupported:
            return "This device doesn't support TrueDepth scanning. Face ID compatible iPhone required."
        case .faceNotDetected:
            return "No face detected. Please position your face in the frame."
        case .multipleFacesDetected:
            return "Multiple faces detected. Please scan one person at a time."
        case .cancelled:
            return "Scan was cancelled."

        // Quality Errors
        case .lightingTooLow(let current, let required):
            return "Lighting too low (\(Int(current*100))%). Move to brighter area (need \(Int(required*100))%)."
        case .lightingTooHigh(let current, let max):
            return "Too bright (\(Int(current*100))%). Reduce lighting or move away from bright light (max \(Int(max*100))%)."
        case .blurryImage(let score):
            return "Image is blurry (score: \(String(format: "%.1f", score))). Hold device steady."
        case .occludedFace(let regions):
            return "Face partially covered (\(regions.joined(separator: ", "))). Remove hands/hair from face."
        case .invalidExpression(let issues):
            return "Invalid expression: \(issues.joined(separator: ", ")). Please maintain neutral expression."

        // Processing Errors
        case .mergeFailed(let reason):
            let base = "Failed to merge face scans."
            return reason.map { "\(base) \($0)" } ?? base
        case .bakeFailed(let reason):
            let base = "Failed to process skin texture."
            return reason.map { "\(base) \($0)" } ?? base
        case .metricsFailed(let analyzer, let reason):
            var parts = ["Failed to analyze skin metrics."]
            if let analyzer = analyzer { parts.append("Analyzer: \(analyzer)") }
            if let reason = reason { parts.append(reason) }
            return parts.joined(separator: " ")
        case .processingTimeout(let operation, let seconds):
            return "Processing timed out after \(Int(seconds))s during: \(operation)."
        case .invalidData(let field):
            return "Invalid scan data: \(field) is missing or corrupted."

        // Storage Errors
        case .coreDataSaveFailed(let error):
            return "Failed to save scan: \(error.localizedDescription)"
        case .insufficientStorage(let required, let available):
            let reqMB = Double(required) / 1_000_000
            let availMB = Double(available) / 1_000_000
            return "Insufficient storage. Need \(String(format: "%.1f", reqMB))MB but only \(String(format: "%.1f", availMB))MB available."
        case .corruptedData(let entity):
            return "Data corrupted: \(entity). Please try scanning again."

        // Generic
        case .processingError(let message):
            return "Processing error: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        // Capture Errors
        case .arSessionFailed:
            return "Restart the app and ensure your device supports Face ID."
        case .cameraUnavailable:
            return "Go to Settings > Tavi > Camera and enable camera access."
        case .trueDepthUnsupported:
            return "This app requires an iPhone with Face ID (iPhone X or newer, excluding SE models)."
        case .faceNotDetected:
            return "Position your face in the center of the frame and ensure good lighting."
        case .multipleFacesDetected:
            return "Make sure only one person is visible in the camera frame."
        case .cancelled:
            return "You can start a new scan anytime from the home screen."

        // Quality Errors
        case .lightingTooLow:
            return "Move to a brighter room or turn on more lights. Natural daylight works best."
        case .lightingTooHigh:
            return "Move away from direct sunlight or bright lights. Indirect lighting works best."
        case .blurryImage:
            return "Hold your device steady with both hands. Rest your elbows on a table if needed."
        case .occludedFace:
            return "Remove hands, hair, or other objects from your face before scanning."
        case .invalidExpression:
            return "Keep a neutral, relaxed expression. No smiling, frowning, or talking."

        // Processing Errors
        case .mergeFailed, .bakeFailed, .metricsFailed:
            return "Try scanning in a well-lit area with neutral expression. If problem persists, restart the app."
        case .processingTimeout:
            return "Close other apps to free up resources, then try again."
        case .invalidData:
            return "This may be a temporary issue. Please try scanning again."

        // Storage Errors
        case .coreDataSaveFailed:
            return "Ensure the app has sufficient storage permissions. Restart the app if problem persists."
        case .insufficientStorage:
            return "Delete old photos or apps to free up space, then try again."
        case .corruptedData:
            return "Your scan history may be corrupted. Try restarting the app."

        // Generic
        case .processingError:
            return "If this problem persists, try restarting the app."
        }
    }

    // MARK: - Error Classification

    /// Whether this error is recoverable (user can retry)
    var isRecoverable: Bool {
        switch self {
        case .trueDepthUnsupported, .coreDataSaveFailed, .corruptedData:
            return false
        case .cancelled:
            return true  // Technically recoverable (just scan again)
        default:
            return true
        }
    }

    /// Whether this error should block the scan from starting
    var isBlockingError: Bool {
        switch self {
        case .trueDepthUnsupported, .cameraUnavailable, .multipleFacesDetected:
            return true
        default:
            return false
        }
    }
}
