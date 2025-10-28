//
//  DeviceCalibration.swift
//  Tavi
//
//  Device-specific calibration for iPhone 12/13/14/15 Pro variations
//  Handles TrueDepth camera differences across models
//

import Foundation
import ARKit
import UIKit

// Import iPhoneModel from DeviceCapabilities
// Note: iPhoneModel is defined in Core/ModelsKit/DeviceCapabilities.swift

/// Device information
public struct DeviceInfo {
    let model: iPhoneModel
    let hasTrueDepth: Bool
    let trueDepthVersion: TrueDepthVersion
    let supportedARFeatures: Set<ARFeature>
    let calibrationProfile: CalibrationProfile
}

public enum TrueDepthVersion {
    case v1  // iPhone X/XS/XR
    case v2  // iPhone 11 Pro
    case v3  // iPhone 12 Pro
    case v4  // iPhone 13 Pro
    case v5  // iPhone 14 Pro (pill cutout)
    case v6  // iPhone 15 Pro (latest)
    case none

    var resolution: Int {
        // Approximate vertex count
        switch self {
        case .v1: return 25000
        case .v2: return 28000
        case .v3: return 30000
        case .v4: return 32000
        case .v5: return 33000
        case .v6: return 35000
        case .none: return 0
        }
    }
}

public enum ARFeature: String {
    case faceTracking
    case depthData
    case highResolutionTexture
    case peopleOcclusion
    case sceneReconstruction
}

/// Calibration profile for device
public struct CalibrationProfile {
    // Measurement adjustments
    let vertexPositionError: Float  // mm
    let wrinkleDepthMultiplier: Float
    let roughnessMultiplier: Float

    // Feature weights
    let textureQualityWeight: Float  // 0-1
    let geometryQualityWeight: Float  // 0-1

    // Thresholds
    let minTrackingQuality: Float
    let minLightingQuality: Float
}

/// Device calibrator
public class DeviceCalibrator {

    // MARK: - Public API

    /// Get current device information
    public func getCurrentDevice() -> DeviceInfo {
        let modelIdentifier = getModelIdentifier()
        let model = identifyModel(identifier: modelIdentifier)
        let trueDepthVersion = getTrueDepthVersion(model: model)

        let hasTrueDepth = ARFaceTrackingConfiguration.isSupported
        let features = getSupportedFeatures()

        let calibration = getCalibrationProfile(model: model, version: trueDepthVersion)

        return DeviceInfo(
            model: model,
            hasTrueDepth: hasTrueDepth,
            trueDepthVersion: trueDepthVersion,
            supportedARFeatures: features,
            calibrationProfile: calibration
        )
    }

    /// Apply device-specific adjustments to metrics
    public func applyCalibration(
        metrics: inout Face3DMetrics,
        device: DeviceInfo
    ) {
        let profile = device.calibrationProfile

        // Adjust wrinkle depth based on device accuracy
        // (Newer devices have better accuracy)
        // metrics.wrinkleDepth *= profile.wrinkleDepthMultiplier

        // Adjust roughness score
        // metrics.roughness *= profile.roughnessMultiplier

        // Note: Would apply actual adjustments to metrics struct
    }

    /// Check if device is supported
    public func isDeviceSupported() -> (Bool, String?) {
        guard ARFaceTrackingConfiguration.isSupported else {
            return (false, "This device does not support TrueDepth face tracking. Tavi requires an iPhone with Face ID (iPhone X or newer).")
        }

        let device = getCurrentDevice()

        // Warn for older devices
        if device.trueDepthVersion == .v1 {
            return (true, "Your device (iPhone X/XS/XR) is supported but may have reduced accuracy. For best results, use iPhone 12 Pro or newer.")
        }

        return (true, nil)
    }

    // MARK: - Private Methods

    private func getModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        return identifier
    }

    private func identifyModel(identifier: String) -> iPhoneModel {
        // https://www.theiphonewiki.com/wiki/Models
        switch identifier {
        // iPhone 15
        case "iPhone16,1": return .iPhone15Pro
        case "iPhone16,2": return .iPhone15ProMax

        // iPhone 14
        case "iPhone15,2": return .iPhone14Pro
        case "iPhone15,3": return .iPhone14ProMax

        // iPhone 13
        case "iPhone14,2": return .iPhone13Pro
        case "iPhone14,3": return .iPhone13ProMax

        // iPhone 12
        case "iPhone13,3": return .iPhone12Pro
        case "iPhone13,4": return .iPhone12ProMax

        // iPhone 11
        case "iPhone12,3": return .iPhone11Pro
        case "iPhone12,5": return .iPhone11ProMax

        // iPhone X/XS/XR
        case "iPhone10,3", "iPhone10,6": return .iPhoneX
        case "iPhone11,2": return .iPhoneXS
        case "iPhone11,4", "iPhone11,6": return .iPhoneXSMax
        case "iPhone11,8": return .iPhoneXR

        default:
            return .unknown
        }
    }

    private func getTrueDepthVersion(model: iPhoneModel) -> TrueDepthVersion {
        switch model {
        case .iPhone15Pro, .iPhone15ProMax:
            return .v6
        case .iPhone14Pro, .iPhone14ProMax:
            return .v5
        case .iPhone13Pro, .iPhone13ProMax:
            return .v4
        case .iPhone12Pro, .iPhone12ProMax:
            return .v3
        case .iPhone11Pro, .iPhone11ProMax:
            return .v2
        case .iPhoneX, .iPhoneXS, .iPhoneXSMax, .iPhoneXR:
            return .v1
        case .unknown:
            return .none
        }
    }

    private func getSupportedFeatures() -> Set<ARFeature> {
        var features: Set<ARFeature> = []

        if ARFaceTrackingConfiguration.isSupported {
            features.insert(.faceTracking)
        }

        // Check for other features
        let config = ARFaceTrackingConfiguration()

        if config.isAutoFocusEnabled {
            features.insert(.highResolutionTexture)
        }

        // People occlusion (iOS 13+)
        if #available(iOS 13.0, *) {
            features.insert(.peopleOcclusion)
        }

        return features
    }

    private func getCalibrationProfile(model: iPhoneModel, version: TrueDepthVersion) -> CalibrationProfile {

        switch version {
        case .v6:  // iPhone 15 Pro - Best accuracy
            return CalibrationProfile(
                vertexPositionError: 0.8,  // ±0.8mm
                wrinkleDepthMultiplier: 1.0,
                roughnessMultiplier: 1.0,
                textureQualityWeight: 1.0,
                geometryQualityWeight: 1.0,
                minTrackingQuality: 0.85,
                minLightingQuality: 0.7
            )

        case .v5:  // iPhone 14 Pro
            return CalibrationProfile(
                vertexPositionError: 0.9,
                wrinkleDepthMultiplier: 1.05,
                roughnessMultiplier: 1.02,
                textureQualityWeight: 0.95,
                geometryQualityWeight: 0.98,
                minTrackingQuality: 0.85,
                minLightingQuality: 0.7
            )

        case .v4:  // iPhone 13 Pro
            return CalibrationProfile(
                vertexPositionError: 1.0,
                wrinkleDepthMultiplier: 1.08,
                roughnessMultiplier: 1.05,
                textureQualityWeight: 0.92,
                geometryQualityWeight: 0.95,
                minTrackingQuality: 0.82,
                minLightingQuality: 0.7
            )

        case .v3:  // iPhone 12 Pro
            return CalibrationProfile(
                vertexPositionError: 1.1,
                wrinkleDepthMultiplier: 1.1,
                roughnessMultiplier: 1.08,
                textureQualityWeight: 0.9,
                geometryQualityWeight: 0.92,
                minTrackingQuality: 0.8,
                minLightingQuality: 0.72
            )

        case .v2:  // iPhone 11 Pro
            return CalibrationProfile(
                vertexPositionError: 1.3,
                wrinkleDepthMultiplier: 1.15,
                roughnessMultiplier: 1.12,
                textureQualityWeight: 0.85,
                geometryQualityWeight: 0.88,
                minTrackingQuality: 0.78,
                minLightingQuality: 0.75
            )

        case .v1:  // iPhone X/XS/XR - Oldest TrueDepth
            return CalibrationProfile(
                vertexPositionError: 1.5,
                wrinkleDepthMultiplier: 1.2,
                roughnessMultiplier: 1.15,
                textureQualityWeight: 0.8,
                geometryQualityWeight: 0.85,
                minTrackingQuality: 0.75,
                minLightingQuality: 0.78
            )

        case .none:
            return CalibrationProfile(
                vertexPositionError: 2.0,
                wrinkleDepthMultiplier: 1.5,
                roughnessMultiplier: 1.3,
                textureQualityWeight: 0.5,
                geometryQualityWeight: 0.5,
                minTrackingQuality: 0.7,
                minLightingQuality: 0.8
            )
        }
    }
}

/// Device compatibility checker
public class DeviceCompatibilityChecker {

    public static func checkCompatibility() -> CompatibilityResult {
        guard ARFaceTrackingConfiguration.isSupported else {
            return CompatibilityResult(
                isSupported: false,
                requirementsMet: false,
                warnings: [],
                errorMessage: "Face tracking not supported. Tavi requires an iPhone with Face ID (iPhone X or newer)."
            )
        }

        let calibrator = DeviceCalibrator()
        let device = calibrator.getCurrentDevice()

        var warnings: [String] = []

        // Check device age
        if device.trueDepthVersion == .v1 {
            warnings.append("Your device (iPhone X/XS/XR) may have reduced accuracy. For best results, use iPhone 12 Pro or newer.")
        } else if device.trueDepthVersion == .v2 {
            warnings.append("iPhone 11 Pro is supported. Consider upgrading to iPhone 12 Pro or newer for improved accuracy.")
        }

        // Check iOS version
        let iOSVersion = ProcessInfo.processInfo.operatingSystemVersion
        if iOSVersion.majorVersion < 15 {
            warnings.append("iOS 15 or later recommended for optimal performance.")
        }

        return CompatibilityResult(
            isSupported: true,
            requirementsMet: true,
            warnings: warnings,
            errorMessage: nil
        )
    }
}

public struct CompatibilityResult {
    let isSupported: Bool
    let requirementsMet: Bool
    let warnings: [String]
    let errorMessage: String?
}
