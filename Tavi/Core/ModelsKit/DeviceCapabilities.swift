//
//  DeviceCapabilities.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import UIKit
import AVFoundation

/// Device capability detection for optimized feature enablement
public class DeviceCapabilities {

    // MARK: - Singleton

    public static let current = DeviceCapabilities()

    // MARK: - Device Information

    /// Current device model identifier (e.g., "iPhone15,2")
    public let modelIdentifier: String

    /// User-friendly device name (e.g., "iPhone 15 Pro")
    public let deviceName: String

    /// Detected iPhone model
    public let iPhoneModel: iPhoneModel

    // MARK: - Capabilities

    /// Supports TrueDepth camera (face mesh overlay)
    public let supportsTrueDepth: Bool

    /// Supports 4K video capture
    public let supports4KVideo: Bool

    /// Has Neural Engine A16 or newer (real-time pipeline)
    public let supportsNeuralEngineA16Plus: Bool

    /// Recommended processing mode based on device capabilities
    public let recommendedProcessingMode: ProcessingMode

    /// Maximum recommended resolution for capture
    public let maxRecommendedResolution: CaptureResolution

    // MARK: - Initialization

    private init() {
        // Get device model identifier
        self.modelIdentifier = Self.getModelIdentifier()

        // Detect iPhone model
        self.iPhoneModel = Self.detectiPhoneModel(from: modelIdentifier)

        // Get user-friendly name
        self.deviceName = Self.getDeviceName(for: iPhoneModel)

        // Detect capabilities
        self.supportsTrueDepth = Self.detectTrueDepthSupport()
        self.supports4KVideo = Self.detect4KVideoSupport()
        self.supportsNeuralEngineA16Plus = Self.detectNeuralEngineA16Plus(model: iPhoneModel)

        // Determine recommended settings
        self.recommendedProcessingMode = Self.determineProcessingMode(
            neuralEngine: supportsNeuralEngineA16Plus,
            model: iPhoneModel
        )
        self.maxRecommendedResolution = Self.determineMaxResolution(
            supports4K: supports4KVideo,
            model: iPhoneModel
        )
    }

    // MARK: - Model Identifier

    private static func getModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        return identifier
    }

    // MARK: - iPhone Model Detection

    private static func detectiPhoneModel(from identifier: String) -> iPhoneModel {
        // iPhone 16 series (2024)
        if identifier.hasPrefix("iPhone17,") {
            if identifier == "iPhone17,1" { return .iPhone16Pro }
            if identifier == "iPhone17,2" { return .iPhone16ProMax }
            if identifier == "iPhone17,3" { return .iPhone16 }
            if identifier == "iPhone17,4" { return .iPhone16Plus }
            return .iPhone16Pro // Default to Pro for unknown 17,x
        }

        // iPhone 15 series (2023)
        if identifier.hasPrefix("iPhone15,") || identifier.hasPrefix("iPhone16,") {
            // iPhone 15 Pro models
            if identifier == "iPhone15,2" { return .iPhone15Pro }
            if identifier == "iPhone15,3" { return .iPhone15ProMax }

            // iPhone 15 standard models
            if identifier == "iPhone15,4" || identifier == "iPhone15,5" { return .iPhone15Plus }
            if identifier == "iPhone14,7" || identifier == "iPhone14,8" { return .iPhone15 }

            // iPhone 16 series (alternative identifiers)
            if identifier == "iPhone16,1" { return .iPhone15Pro }
            if identifier == "iPhone16,2" { return .iPhone15ProMax }

            return .iPhone15Pro // Default to Pro for unknown 15,x/16,x
        }

        // iPhone 14 series (2022)
        if identifier.hasPrefix("iPhone14,") {
            if identifier == "iPhone14,2" { return .iPhone14Pro }
            if identifier == "iPhone14,3" { return .iPhone14ProMax }
            if identifier == "iPhone14,4" { return .iPhone14 }
            if identifier == "iPhone14,5" { return .iPhone14Plus }
            return .iPhone14Pro // Default to Pro
        }

        // iPhone 13 series (2021) - A15
        if identifier.hasPrefix("iPhone13,") || identifier.hasPrefix("iPhone14,") {
            return .iPhone13Pro // Has A15, decent performance
        }

        // iPhone 12 series (2020) - A14
        if identifier.hasPrefix("iPhone12,") || identifier.hasPrefix("iPhone13,") {
            return .iPhone12Pro
        }

        // iPhone 11 and older (2019 and earlier)
        if identifier.hasPrefix("iPhone11,") {
            return .iPhone11Pro
        }

        // Simulator
        if identifier == "x86_64" || identifier == "arm64" || identifier.hasPrefix("iPhone") == false {
            return .simulator
        }

        // Unknown/newer device - assume latest capabilities
        return .unknown
    }

    private static func getDeviceName(for model: iPhoneModel) -> String {
        switch model {
        // iPhone 16 series
        case .iPhone16: return "iPhone 16"
        case .iPhone16Plus: return "iPhone 16 Plus"
        case .iPhone16Pro: return "iPhone 16 Pro"
        case .iPhone16ProMax: return "iPhone 16 Pro Max"

        // iPhone 15 series
        case .iPhone15: return "iPhone 15"
        case .iPhone15Plus: return "iPhone 15 Plus"
        case .iPhone15Pro: return "iPhone 15 Pro"
        case .iPhone15ProMax: return "iPhone 15 Pro Max"

        // iPhone 14 series
        case .iPhone14: return "iPhone 14"
        case .iPhone14Plus: return "iPhone 14 Plus"
        case .iPhone14Pro: return "iPhone 14 Pro"
        case .iPhone14ProMax: return "iPhone 14 Pro Max"

        // Older models
        case .iPhone13Pro: return "iPhone 13 Pro"
        case .iPhone13ProMax: return "iPhone 13 Pro Max"
        case .iPhone12Pro: return "iPhone 12 Pro"
        case .iPhone12ProMax: return "iPhone 12 Pro Max"
        case .iPhone11Pro: return "iPhone 11 Pro"
        case .iPhone11ProMax: return "iPhone 11 Pro Max"

        // Earlier TrueDepth models
        case .iPhoneX: return "iPhone X"
        case .iPhoneXS: return "iPhone XS"
        case .iPhoneXSMax: return "iPhone XS Max"
        case .iPhoneXR: return "iPhone XR"

        case .simulator: return "Simulator"
        case .unknown: return "Unknown iPhone"
        }
    }

    // MARK: - TrueDepth Detection

    private static func detectTrueDepthSupport() -> Bool {
        // Check if device has TrueDepth camera
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTrueDepthCamera],
            mediaType: .video,
            position: .front
        )

        return !discoverySession.devices.isEmpty
    }

    // MARK: - 4K Video Detection

    private static func detect4KVideoSupport() -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            return false
        }

        // Check if device supports 4K (3840x2160)
        for format in device.formats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            if dimensions.width >= 3840 && dimensions.height >= 2160 {
                return true
            }
        }

        return false
    }

    // MARK: - Neural Engine Detection

    private static func detectNeuralEngineA16Plus(model: iPhoneModel) -> Bool {
        switch model {
        // A18 chip (2024) - iPhone 16 series
        case .iPhone16, .iPhone16Plus, .iPhone16Pro, .iPhone16ProMax:
            return true

        // A17 Pro chip (2023) - iPhone 15 Pro
        case .iPhone15Pro, .iPhone15ProMax:
            return true

        // A16 chip (2022) - iPhone 14 Pro, iPhone 15/15 Plus
        case .iPhone14Pro, .iPhone14ProMax, .iPhone15, .iPhone15Plus:
            return true

        // A15 and older
        case .iPhone14, .iPhone14Plus, .iPhone13Pro, .iPhone13ProMax, .iPhone12Pro, .iPhone12ProMax, .iPhone11Pro, .iPhone11ProMax:
            return false

        // Earlier TrueDepth models (A12/A13)
        case .iPhoneX, .iPhoneXS, .iPhoneXSMax, .iPhoneXR:
            return false

        // Simulator - assume capable for testing
        case .simulator:
            return true

        // Unknown - conservative approach
        case .unknown:
            return false
        }
    }

    // MARK: - Processing Mode Determination

    private static func determineProcessingMode(neuralEngine: Bool, model: iPhoneModel) -> ProcessingMode {
        if neuralEngine {
            // A16+ devices can handle real-time processing
            return .realtime
        } else {
            // Older devices use deferred processing
            return .deferred
        }
    }

    // MARK: - Resolution Determination

    private static func determineMaxResolution(supports4K: Bool, model: iPhoneModel) -> CaptureResolution {
        // Pro models with 4K support
        if supports4K {
            switch model {
            case .iPhone15Pro, .iPhone15ProMax, .iPhone16Pro, .iPhone16ProMax:
                return .fourK  // Full 4K for latest Pro models

            case .iPhone14Pro, .iPhone14ProMax:
                return .fourK  // 4K for iPhone 14 Pro

            default:
                return .fullHD  // 4K available but recommend 1080p for battery/performance
            }
        }

        // Standard models or older devices
        switch model {
        case .iPhone15, .iPhone15Plus, .iPhone16, .iPhone16Plus:
            return .fullHD  // 1080p for standard models

        case .iPhone14, .iPhone14Plus:
            return .fullHD

        case .iPhone13Pro:
            return .fullHD

        default:
            return .hd720  // 720p for older devices
        }
    }

    // MARK: - Capability Queries

    /// Whether face mesh overlay should be enabled
    public var shouldEnableFaceMesh: Bool {
        return supportsTrueDepth
    }

    /// Whether high-res capture toggle should be shown
    public var shouldShowHighResCaptureToggle: Bool {
        return supports4KVideo
    }

    /// Whether to use real-time processing pipeline
    public var shouldUseRealtimePipeline: Bool {
        return supportsNeuralEngineA16Plus
    }

    /// Whether device is considered "high-end"
    public var isHighEndDevice: Bool {
        return supportsNeuralEngineA16Plus && supports4KVideo
    }

    /// Whether device is considered "low-end" (needs aggressive optimization)
    public var isLowEndDevice: Bool {
        switch iPhoneModel {
        case .iPhone11Pro, .iPhone12Pro, .unknown:
            return true
        default:
            return false
        }
    }

    // MARK: - Performance Recommendations

    /// Recommended frame rate for capture
    public var recommendedFrameRate: Int {
        if supportsNeuralEngineA16Plus {
            return 60  // High frame rate for smooth experience
        } else {
            return 30  // Standard frame rate for older devices
        }
    }

    /// Maximum concurrent frames for processing
    public var maxConcurrentFrames: Int {
        if supportsNeuralEngineA16Plus {
            return 5  // Can handle multiple frames simultaneously
        } else {
            return 3  // Conservative for older devices
        }
    }

    /// Whether to use hardware-accelerated image processing
    public var shouldUseHardwareAcceleration: Bool {
        // A16+ has better GPU/Neural Engine
        return supportsNeuralEngineA16Plus
    }

    // MARK: - Debug Description

    public var debugDescription: String {
        """
        Device Capabilities:
        - Model: \(deviceName) (\(modelIdentifier))
        - TrueDepth: \(supportsTrueDepth ? "✓" : "✗")
        - 4K Video: \(supports4KVideo ? "✓" : "✗")
        - Neural Engine A16+: \(supportsNeuralEngineA16Plus ? "✓" : "✗")
        - Processing Mode: \(recommendedProcessingMode)
        - Max Resolution: \(maxRecommendedResolution)
        - Frame Rate: \(recommendedFrameRate) fps
        - Concurrent Frames: \(maxConcurrentFrames)
        """
    }
}

// MARK: - Supporting Types

public enum iPhoneModel {
    // iPhone 16 series (2024) - A18
    case iPhone16
    case iPhone16Plus
    case iPhone16Pro
    case iPhone16ProMax

    // iPhone 15 series (2023) - A17 Pro / A16
    case iPhone15
    case iPhone15Plus
    case iPhone15Pro
    case iPhone15ProMax

    // iPhone 14 series (2022) - A16 / A15
    case iPhone14
    case iPhone14Plus
    case iPhone14Pro
    case iPhone14ProMax

    // iPhone 13 series (2021) - A15
    case iPhone13Pro
    case iPhone13ProMax

    // iPhone 12 series (2020) - A14
    case iPhone12Pro
    case iPhone12ProMax

    // iPhone 11 series (2019) - A13
    case iPhone11Pro
    case iPhone11ProMax

    // Earlier TrueDepth models
    case iPhoneX
    case iPhoneXS
    case iPhoneXSMax
    case iPhoneXR

    // Special cases
    case simulator
    case unknown

    public var chipName: String {
        switch self {
        case .iPhone16, .iPhone16Plus, .iPhone16Pro, .iPhone16ProMax:
            return "A18"
        case .iPhone15Pro, .iPhone15ProMax:
            return "A17 Pro"
        case .iPhone15, .iPhone15Plus:
            return "A16"
        case .iPhone14Pro, .iPhone14ProMax:
            return "A16"
        case .iPhone14, .iPhone14Plus:
            return "A15"
        case .iPhone13Pro, .iPhone13ProMax:
            return "A15"
        case .iPhone12Pro, .iPhone12ProMax:
            return "A14"
        case .iPhone11Pro, .iPhone11ProMax:
            return "A13"
        case .iPhoneX, .iPhoneXS, .iPhoneXSMax:
            return "A12"
        case .iPhoneXR:
            return "A12"
        case .simulator:
            return "Simulator"
        case .unknown:
            return "Unknown"
        }
    }

    public var displayName: String {
        switch self {
        case .iPhone16: return "iPhone 16"
        case .iPhone16Plus: return "iPhone 16 Plus"
        case .iPhone16Pro: return "iPhone 16 Pro"
        case .iPhone16ProMax: return "iPhone 16 Pro Max"
        case .iPhone15: return "iPhone 15"
        case .iPhone15Plus: return "iPhone 15 Plus"
        case .iPhone15Pro: return "iPhone 15 Pro"
        case .iPhone15ProMax: return "iPhone 15 Pro Max"
        case .iPhone14: return "iPhone 14"
        case .iPhone14Plus: return "iPhone 14 Plus"
        case .iPhone14Pro: return "iPhone 14 Pro"
        case .iPhone14ProMax: return "iPhone 14 Pro Max"
        case .iPhone13Pro: return "iPhone 13 Pro"
        case .iPhone13ProMax: return "iPhone 13 Pro Max"
        case .iPhone12Pro: return "iPhone 12 Pro"
        case .iPhone12ProMax: return "iPhone 12 Pro Max"
        case .iPhone11Pro: return "iPhone 11 Pro"
        case .iPhone11ProMax: return "iPhone 11 Pro Max"
        case .iPhoneX: return "iPhone X"
        case .iPhoneXS: return "iPhone XS"
        case .iPhoneXSMax: return "iPhone XS Max"
        case .iPhoneXR: return "iPhone XR"
        case .simulator: return "Simulator"
        case .unknown: return "Unknown iPhone"
        }
    }
}

public enum ProcessingMode: String, CustomStringConvertible {
    case realtime = "Real-time"
    case deferred = "Deferred"

    public var description: String { rawValue }
}

public enum CaptureResolution: String, CustomStringConvertible {
    case fourK = "4K (3840×2160)"
    case fullHD = "Full HD (1920×1080)"
    case hd720 = "HD (1280×720)"

    public var description: String { rawValue }

    public var dimensions: CGSize {
        switch self {
        case .fourK:
            return CGSize(width: 3840, height: 2160)
        case .fullHD:
            return CGSize(width: 1920, height: 1080)
        case .hd720:
            return CGSize(width: 1280, height: 720)
        }
    }
}

// MARK: - Capability-Aware Configuration

extension DeviceCapabilities {

    /// Get optimized capture configuration for current device
    public func getOptimizedCaptureConfig() -> CaptureConfig {
        return CaptureConfig(
            resolution: maxRecommendedResolution,
            frameRate: recommendedFrameRate,
            enableFaceMesh: shouldEnableFaceMesh,
            processingMode: recommendedProcessingMode,
            maxConcurrentFrames: maxConcurrentFrames,
            useHardwareAcceleration: shouldUseHardwareAcceleration
        )
    }
}

public struct CaptureConfig {
    public let resolution: CaptureResolution
    public let frameRate: Int
    public let enableFaceMesh: Bool
    public let processingMode: ProcessingMode
    public let maxConcurrentFrames: Int
    public let useHardwareAcceleration: Bool

    public var debugDescription: String {
        """
        Capture Configuration:
        - Resolution: \(resolution)
        - Frame Rate: \(frameRate) fps
        - Face Mesh: \(enableFaceMesh ? "Enabled" : "Disabled")
        - Processing: \(processingMode)
        - Max Concurrent: \(maxConcurrentFrames) frames
        - Hardware Accel: \(useHardwareAcceleration ? "Yes" : "No")
        """
    }
}
