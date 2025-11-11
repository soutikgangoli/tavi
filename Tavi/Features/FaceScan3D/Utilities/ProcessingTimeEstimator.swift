//
//  ProcessingTimeEstimator.swift
//  Tavi
//
//  Device-aware processing time estimation for 3D face scans
//  Provides accurate time estimates based on device capabilities
//

import Foundation

/// Processing step in the scan pipeline
public enum ProcessingPhase: Int, CaseIterable {
    case meshMerge = 1
    case textureBake = 2
    case metricsAnalysis = 3
    case emotionalMetrics = 4
    case gamification = 5
    case coreDataSave = 6

    var description: String {
        switch self {
        case .meshMerge: return "Merging your 3D face scan... ✨"
        case .textureBake: return "Creating your skin texture map... 🎨"
        case .metricsAnalysis: return "Analyzing your skin... 🔬"
        case .emotionalMetrics: return "Calculating your Skin Health Index... 🌟"
        case .gamification: return "Updating your progress... 🎉"
        case .coreDataSave: return "Saving your results... 💾"
        }
    }

    /// Cycling messages for each phase (returns different message each time)
    func getCyclingMessage(index: Int) -> String {
        switch self {
        case .meshMerge:
            let messages = [
                "Merging 50+ captures into your 3D model",
                "Aligning facial geometry with precision",
                "Reconstructing your face in 3D space",
                "Combining multiple angles for accuracy",
                "Calculating spatial relationships between vertices",
                "Blending depth information from each pose",
                "Optimizing mesh topology for smooth surfaces",
                "Correcting for micro-movements during capture",
                "Building a unified coordinate system",
                "Removing duplicate vertices and artifacts",
                "Averaging overlapping regions for consistency",
                "Computing surface normals and curvature"
            ]
            return messages[index % messages.count]
        case .textureBake:
            let messages = [
                "Processing 4K resolution skin texture",
                "Mapping skin details onto your 3D model",
                "Blending texture samples for clarity",
                "Creating photorealistic skin representation",
                "Analyzing color information from multiple angles",
                "Correcting for lighting variations across captures",
                "Stitching together texture patches seamlessly",
                "Reducing shadows and specular highlights",
                "Normalizing color temperature across the face",
                "Enhancing fine details like pores and texture",
                "Applying anti-aliasing for smooth edges",
                "Generating UV coordinates for optimal mapping"
            ]
            return messages[index % messages.count]
        case .metricsAnalysis:
            let messages = [
                "Analyzing 50,000+ data points across your face",
                "Measuring pore size and distribution patterns",
                "Detecting fine lines and texture variations",
                "Evaluating skin tone uniformity and pigmentation",
                "Assessing hydration levels and skin quality",
                "Mapping facial contours and symmetry",
                "Quantifying surface roughness at microscale",
                "Identifying areas of redness or inflammation",
                "Measuring skin elasticity and firmness",
                "Detecting sun damage and hyperpigmentation",
                "Analyzing sebum distribution and shine",
                "Evaluating collagen density indicators",
                "Measuring wrinkle depth and distribution",
                "Assessing overall skin clarity and radiance",
                "Computing texture entropy across regions"
            ]
            return messages[index % messages.count]
        case .emotionalMetrics:
            let messages = [
                "Computing your personalized Skin Health Index",
                "Comparing with your previous scan results",
                "Calculating improvement percentage",
                "Generating personalized recommendations",
                "Identifying your strongest skin attributes",
                "Detecting patterns in your skin's progress",
                "Weighting metrics by clinical importance",
                "Factoring in environmental and lifestyle data",
                "Computing age-adjusted baseline comparisons",
                "Translating technical metrics to friendly scores",
                "Highlighting areas showing improvement"
            ]
            return messages[index % messages.count]
        case .gamification:
            let messages = [
                "Updating achievements and milestones",
                "Checking for new unlocks and rewards",
                "Calculating your consistency streak",
                "Updating your progress towards goals"
            ]
            return messages[index % messages.count]
        case .coreDataSave:
            let messages = [
                "Encrypting and saving your results securely",
                "Writing scan data to device storage",
                "Creating timestamped history entry",
                "Backing up metrics for future comparison"
            ]
            return messages[index % messages.count]
        }
    }

    /// Detailed explanation with interesting facts
    var detailedDescription: String {
        // Default message (will be overridden by cycling)
        return getCyclingMessage(index: 0)
    }

    /// Quality explanation - why this step takes time (nil if step is fast)
    var qualityExplanation: String? {
        switch self {
        case .meshMerge:
            return "Taking time to ensure millimeter-accurate results"
        case .textureBake:
            return "Ensuring every detail is captured clearly"
        case .metricsAnalysis:
            return "Performing clinical-grade skin analysis"
        case .emotionalMetrics:
            return "Calculating your unique skin profile"
        case .gamification, .coreDataSave:
            return nil  // These are fast, no explanation needed
        }
    }
}

/// Device performance tier for time estimation
public enum DevicePerformanceTier: CustomStringConvertible {
    case flagship      // iPhone 15 Pro - fastest
    case high          // iPhone 14 Pro, 13 Pro
    case standard      // iPhone 12 Pro
    case legacy        // iPhone 11 Pro, X/XS/XR

    public var description: String {
        return deviceDescription
    }

    /// Performance multiplier relative to baseline (iPhone 15 Pro = 1.0)
    var performanceMultiplier: Double {
        switch self {
        case .flagship: return 1.0
        case .high: return 1.15
        case .standard: return 1.35
        case .legacy: return 1.65
        }
    }

    /// User-friendly device description
    var deviceDescription: String {
        switch self {
        case .flagship: return "Latest iPhone"
        case .high: return "Recent iPhone"
        case .standard: return "iPhone 12 Pro"
        case .legacy: return "Older iPhone"
        }
    }

    /// Warning message for longer processing times
    var processingWarning: String? {
        switch self {
        case .flagship, .high:
            return nil
        case .standard:
            return "Processing may take 3-4 minutes on iPhone 12 Pro"
        case .legacy:
            return "Processing may take 4-5 minutes on older devices"
        }
    }
}

/// Accurate time estimation for processing steps based on device capabilities
public class ProcessingTimeEstimator {

    // MARK: - Baseline Times (iPhone 15 Pro performance)

    /// Baseline processing times in seconds for each phase (iPhone 15 Pro)
    private let baselineTimes: [ProcessingPhase: Int] = [
        .meshMerge: 25,           // Mesh merging (30s timeout, expect ~25s)
        .textureBake: 20,         // Texture baking (30s timeout, expect ~20s)
        .metricsAnalysis: 60,     // Metrics computation (150s timeout, expect ~60s)
        .emotionalMetrics: 8,     // Emotional metrics calculation
        .gamification: 5,         // Gamification updates
        .coreDataSave: 4          // Core Data save
    ]

    private let deviceCalibrator = DeviceCalibrator()
    private var currentDevice: DeviceInfo?
    private var performanceTier: DevicePerformanceTier

    // MARK: - Initialization

    public init() {
        self.currentDevice = deviceCalibrator.getCurrentDevice()
        self.performanceTier = Self.determinePerformanceTier(device: currentDevice)
    }

    // MARK: - Public API

    /// Get estimated time remaining from a specific processing step
    /// - Parameters:
    ///   - currentPhase: The current processing phase
    ///   - includeCurrentPhase: Whether to include the current phase in the estimate
    /// - Returns: Estimated seconds remaining
    public func estimateTimeRemaining(
        from currentPhase: ProcessingPhase,
        includeCurrentPhase: Bool = true
    ) -> Int {
        var totalSeconds = 0

        let startPhase = includeCurrentPhase ? currentPhase.rawValue : currentPhase.rawValue + 1

        for phase in ProcessingPhase.allCases where phase.rawValue >= startPhase {
            let baseTime = baselineTimes[phase] ?? 0
            let adjustedTime = Double(baseTime) * performanceTier.performanceMultiplier
            totalSeconds += Int(adjustedTime.rounded())
        }

        return totalSeconds
    }

    /// Get estimated time for a specific phase
    /// - Parameter phase: The processing phase
    /// - Returns: Estimated seconds for this phase
    public func estimatePhaseTime(_ phase: ProcessingPhase) -> Int {
        let baseTime = baselineTimes[phase] ?? 0
        let adjustedTime = Double(baseTime) * performanceTier.performanceMultiplier
        return Int(adjustedTime.rounded())
    }

    /// Get total estimated processing time for entire pipeline
    /// - Returns: Total estimated seconds
    public func estimateTotalTime() -> Int {
        return estimateTimeRemaining(from: .meshMerge, includeCurrentPhase: true)
    }

    /// Get device performance tier
    public func getPerformanceTier() -> DevicePerformanceTier {
        return performanceTier
    }

    /// Get device-specific processing warning message
    public func getProcessingWarning() -> String? {
        return performanceTier.processingWarning
    }

    /// Get device-adjusted timeout value
    /// - Parameter baseTimeout: Base timeout value for flagship devices
    /// - Returns: Adjusted timeout scaled by device performance
    public func getDeviceAdjustedTimeout(_ baseTimeout: TimeInterval) -> TimeInterval {
        return baseTimeout * performanceTier.performanceMultiplier
    }

    /// Get user-friendly time range description
    /// - Returns: Human-readable time estimate (e.g., "2-3 minutes")
    public func getTimeRangeDescription() -> String {
        let totalSeconds = estimateTotalTime()
        let minutes = totalSeconds / 60

        // Add ±15% range for variability
        let minMinutes = max(1, Int(Double(minutes) * 0.85))
        let maxMinutes = Int(Double(minutes) * 1.15)

        if minMinutes == maxMinutes {
            return "\(minMinutes) minute\(minMinutes == 1 ? "" : "s")"
        } else {
            return "\(minMinutes)-\(maxMinutes) minutes"
        }
    }

    // MARK: - Device Performance Detection

    private static func determinePerformanceTier(device: DeviceInfo?) -> DevicePerformanceTier {
        guard let device = device else {
            return .standard // Default to standard if unknown
        }

        switch device.trueDepthVersion {
        case .v6:  // iPhone 15 Pro
            return .flagship

        case .v5, .v4:  // iPhone 14 Pro, 13 Pro
            return .high

        case .v3:  // iPhone 12 Pro
            return .standard

        case .v2, .v1:  // iPhone 11 Pro, X/XS/XR
            return .legacy

        case .none:
            return .legacy
        }
    }
}

// MARK: - Time Formatting Helpers

extension ProcessingTimeEstimator {

    /// Format seconds into human-readable time (e.g., "2:30" or "45 sec")
    public static func formatTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) sec"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }

    /// Format seconds with approximate language (e.g., "About 2 minutes")
    public static func formatApproximateTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "Less than a minute"
        } else if seconds < 90 {
            return "About 1 minute"
        } else {
            let minutes = (seconds + 30) / 60  // Round to nearest minute
            return "About \(minutes) minutes"
        }
    }
}
