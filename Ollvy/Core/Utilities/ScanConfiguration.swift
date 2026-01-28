//
//  ScanConfiguration.swift
//  Ollvy
//
//  Centralized configuration for all scan thresholds and constants
//  Fixes Issue #14: Eliminates magic numbers scattered throughout codebase
//

import Foundation
import SwiftUI

/// Centralized configuration for face scan quality thresholds
public struct ScanConfiguration {

    // MARK: - Lighting Calibration Thresholds

    /// Maximum allowed lighting change between calibration and capture
    /// Relaxed from 30% to 40% - allows minor natural lighting fluctuations
    public static let maxLightingChangeThreshold: Double = 0.40

    /// Maximum allowed color temperature change (15% threshold)
    public static let maxColorTemperatureChangeThreshold: Double = 0.15

    /// Minimum acceptable lighting level (0-1 scale)
    public static let minLightingLevel: Float = 0.3

    /// Maximum acceptable lighting level (0-1 scale)
    public static let maxLightingLevel: Float = 0.7

    // MARK: - Face Expression Thresholds

    /// Maximum jaw open blend shape for neutral expression
    /// Relaxed from 15% to 25% - allows natural slight mouth opening
    public static let maxJawOpenThreshold: Double = 0.25

    /// Maximum eye blink threshold for valid capture
    /// Relaxed from 0.2 to 0.35 - allows natural eye movement
    public static let maxEyeBlinkThreshold: Double = 0.35

    /// Maximum smile threshold for neutral expression
    /// Increased from 0.1 to 0.25 to avoid false positives when looking down
    /// (looking down naturally causes slight mouth curvature detected as "smile")
    public static let maxSmileThreshold: Double = 0.25

    /// Maximum mouth pucker threshold for neutral expression
    public static let maxMouthPuckerThreshold: Double = 0.2

    /// Maximum cheek puff threshold for neutral expression
    public static let maxCheekPuffThreshold: Double = 0.2

    /// Maximum eye wide threshold for neutral expression
    public static let maxEyeWideThreshold: Double = 0.3

    /// Maximum squint threshold for neutral expression
    public static let maxSquintThreshold: Double = 0.3

    /// Maximum brow movement threshold for neutral expression
    public static let maxBrowMovementThreshold: Double = 0.3

    // MARK: - Face Pose Thresholds

    /// Maximum yaw angle (head turn left/right) in radians
    public static let maxYawAngle: Float = 0.75  // ~43 degrees

    /// Maximum pitch angle (head tilt up/down) in radians
    public static let maxPitchAngle: Float = 0.5  // ~29 degrees

    /// Maximum roll angle (head tilt side) in radians
    public static let maxRollAngle: Float = 0.3  // ~17 degrees

    /// Tolerance for pose matching (how close to target pose)
    public static let poseMatchTolerance: Float = 0.1

    // MARK: - Image Quality Thresholds

    /// Minimum sharpness score (0-1) for acceptable capture
    public static let minSharpnessScore: Float = 0.5

    /// Maximum acceptable blur metric
    public static let maxBlurMetric: Float = 0.25

    /// Minimum acceptable exposure level
    public static let minExposureLevel: Float = 0.2

    /// Maximum acceptable exposure level (to detect overexposure)
    public static let maxExposureLevel: Float = 0.8

    /// Underexposure threshold (too dark)
    public static let underexposureThreshold: Float = 0.25

    /// Overexposure threshold (too bright)
    public static let overexposureThreshold: Float = 0.75

    /// Blink detection threshold (eyes closed)
    public static let blinkDetectionThreshold: Double = 0.7

    // MARK: - Capture Timing

    /// Time to hold pose stable before capture (seconds)
    public static let poseHoldDuration: TimeInterval = 1.0

    /// Countdown duration before starting guidance (seconds)
    public static let countdownDuration: Int = 3

    /// Frame rate for analysis (frames per second)
    public static let analysisFrameRate: Double = 30.0

    // MARK: - Face Detection

    /// Minimum face size relative to frame (0-1)
    public static let minFaceSizeRatio: Float = 0.3

    /// Maximum face size relative to frame (0-1)
    public static let maxFaceSizeRatio: Float = 0.75

    /// Face detection confidence threshold
    public static let faceDetectionConfidence: Float = 0.8

    // MARK: - Calibration Thresholds

    /// Minimum acceptable ambient lighting (lumens)
    /// Below this, scan quality suffers from underexposure
    public static let minAmbientLighting: CGFloat = 600.0

    /// Maximum acceptable ambient lighting (lumens)
    /// Above this, risk of overexposure and blown highlights
    public static let maxAmbientLighting: CGFloat = 2000.0

    /// Optimal lighting range start (lumens)
    /// Within optimal range, no warnings shown
    public static let optimalLightingMin: CGFloat = 800.0

    /// Optimal lighting range end (lumens)
    public static let optimalLightingMax: CGFloat = 1800.0

    // MARK: - Distance Calibration Thresholds

    /// Minimum acceptable distance (meters)
    /// Set to 0.35m to ensure stable ARKit tracking and good skin detail
    public static let minFaceDistance: Float = 0.35

    /// Close acceptable range start (meters)
    /// No longer used - removed "acceptable close" zone that caused stability issues
    public static let acceptableCloseDistance: Float = 0.35

    /// Optimal distance range start (meters)
    /// 0.35m ensures stable tracking while maintaining good skin detail
    public static let optimalDistanceMin: Float = 0.35

    /// Optimal distance range end (meters)
    /// 0.50m is the sweet spot for TrueDepth sensor accuracy
    public static let optimalDistanceMax: Float = 0.50

    /// Far acceptable range end (meters)
    /// Beyond 0.55m, skin detail starts to degrade
    public static let acceptableFarDistance: Float = 0.55

    /// Maximum usable distance (meters)
    /// Beyond this, insufficient detail for quality analysis
    public static let maxFaceDistance: Float = 0.60

    // MARK: - Pose Validation Thresholds (Balanced for usability + quality)

    /// Maximum yaw angle for "look straight" (degrees)
    /// Relaxed from ±5° to ±12° - still centered but easier to achieve
    /// ARKit 3D mesh quality is not significantly affected by small angle variations
    public static let maxCenterYawDegrees: Float = 12.0

    /// Maximum pitch angle for "look straight" (degrees)
    /// Relaxed from ±5° to ±12° - reduces "move chin up/down" frustration
    public static let maxCenterPitchDegrees: Float = 12.0

    /// Maximum roll angle for "look straight" (degrees)
    /// Relaxed from ±8° to ±15° for natural head tilt
    public static let maxCenterRollDegrees: Float = 15.0

    /// "Slightly left/right" detection threshold (degrees)
    /// Between center and full turn angles
    public static let slightTurnYawDegrees: Float = 10.0

    /// Minimum yaw for "turn left" pose (degrees)
    public static let minTurnLeftYawDegrees: Float = 15.0

    /// Maximum yaw for "turn left" pose (degrees)
    public static let maxTurnLeftYawDegrees: Float = 35.0

    /// Minimum yaw for "turn right" pose (degrees, negative)
    public static let minTurnRightYawDegrees: Float = -15.0

    /// Maximum yaw for "turn right" pose (degrees, negative)
    public static let maxTurnRightYawDegrees: Float = -35.0

    /// Maximum pitch/roll tolerance during turn poses (degrees)
    public static let turnPoseTolerancePitchRollDegrees: Float = 15.0

    /// Minimum pitch for "look up" pose (degrees, positive)
    public static let minLookUpPitchDegrees: Float = 10.0

    /// Maximum pitch for "look up" pose (degrees, positive)
    public static let maxLookUpPitchDegrees: Float = 22.0

    /// Minimum pitch for "look down" pose (degrees, negative)
    public static let minLookDownPitchDegrees: Float = -12.0

    /// Maximum pitch for "look down" pose (degrees, negative)
    public static let maxLookDownPitchDegrees: Float = -25.0

    /// Maximum yaw/roll tolerance during up/down poses (degrees)
    public static let upDownPoseToleranceYawRollDegrees: Float = 15.0

    /// Stability movement threshold (meters)
    /// Movement below this is considered stable
    /// Increased to 0.08m - allows natural micro-movements during pose adjustment
    /// The blur/sharpness check catches any actual quality issues from movement
    public static let stabilityMovementThreshold: Float = 0.08

    // MARK: - Mesh Processing

    /// Wrinkle depth scaling factor (empirical value needs validation)
    ///
    /// ⚠️ **VALIDATION REQUIRED**: This coefficient is based on empirical estimates and has NOT been
    /// validated against ground truth measurements. Clinical accuracy depends on proper calibration.
    ///
    /// **Action Required**:
    /// - Conduct validation study with calibrated depth measurement tools (e.g., optical profilometer)
    /// - Compare wrinkle depth measurements against known standards
    /// - Adjust this factor based on statistical analysis of measurement error
    /// - Document the validation methodology and results
    ///
    /// **Expected Range**: 15-25 micrometers (0.000015 - 0.000025)
    /// **Current Value**: 20 micrometers (0.00002)
    ///
    /// **Impact**: Incorrect scaling affects wrinkle/roughness measurements, which impacts:
    /// - Overall skin quality scores
    /// - Clinical metric accuracy
    /// - Longitudinal tracking precision
    public static let wrinkleDepthScalingFactor: Double = 0.000007  // 7 micrometers (adjusted: was 20µm producing 2.75mm depths, should be <1.0mm)

    /// Smoothing iterations for mesh processing
    public static let meshSmoothingIterations: Int = 3

    /// Vertex normal smoothing strength
    public static let normalSmoothingStrength: Float = 0.5

    // MARK: - Texture Processing

    /// Maximum texture resolution (width/height in pixels)
    public static let maxTextureResolution: Int = 4096

    /// Default texture resolution for processing
    public static let defaultTextureResolution: Int = 2048

    /// JPEG compression quality for image storage (0-1)
    public static let imageCompressionQuality: CGFloat = 0.8

    // MARK: - Async Operation Timeouts

    /// Timeout for mesh merge operation (seconds)
    /// Increased to 60s for iPhone 15 Pro to handle complex meshes
    public static let meshMergeTimeout: TimeInterval = 60.0

    /// Timeout for texture baking operation (seconds)
    /// Increased to 60s for iPhone 15 Pro to handle high-res textures
    /// Note: Use getTextureBakeTimeout() for resolution-aware timeout
    public static let textureBakeTimeout: TimeInterval = 60.0

    /// Base timeout for 2K texture baking (seconds)
    /// Baseline: iPhone 15 Pro with 2K textures completes in ~30s
    public static let textureBakeTimeout2K: TimeInterval = 60.0

    /// Scaling factor for 4K textures (4x pixel count = ~3x processing time)
    /// 4K = 16M pixels, 2K = 4M pixels
    public static let textureBake4KScaleFactor: Double = 3.0

    /// Get resolution-appropriate texture bake timeout
    /// - Returns: Timeout in seconds adjusted for current texture resolution
    /// Result: 60s for 2K, 180s for 4K
    public static func getTextureBakeTimeout() -> TimeInterval {
        // Check if user has explicitly set high-res preference
        let use4K: Bool
        if UserDefaults.standard.object(forKey: AppDefaultsKey.enableHighResCapture) != nil {
            use4K = UserDefaults.standard.bool(forKey: AppDefaultsKey.enableHighResCapture)
        } else {
            // Fall back to device default
            use4K = DeviceCapabilities.current.supports4KTextureDefault
        }

        let baseTimeout = textureBakeTimeout2K
        let scaleFactor = use4K ? textureBake4KScaleFactor : 1.0

        return baseTimeout * scaleFactor
    }

    /// Timeout for metrics computation (seconds)
    /// Increased to 240s (4 minutes) to accommodate full analysis pipeline on iPhone 15 Pro
    /// Breakdown: ROI processing ~60s + Parallel analysis ~90s + Glow/Sun damage ~20s + overhead = ~170s
    /// Setting to 240s for safety margin
    public static let metricsComputationTimeout: TimeInterval = 240.0

    /// Timeout for CoreData save operation (seconds)
    public static let coreDataSaveTimeout: TimeInterval = 20.0

    // MARK: - UI Animation

    /// Quick animation duration (seconds)
    public static let quickAnimationDuration: TimeInterval = 0.2

    /// Standard animation duration (seconds)
    public static let standardAnimationDuration: TimeInterval = 0.3

    /// Slow animation duration (seconds)
    public static let slowAnimationDuration: TimeInterval = 0.5

    // MARK: - Standard Animations

    /// Quick animation (0.2s ease-in-out)
    public static let quickAnimation: Animation = .easeInOut(duration: 0.2)

    /// Standard animation (0.3s ease-in-out)
    public static let standardAnimation: Animation = .easeInOut(duration: 0.3)

    /// Slow animation (0.5s ease-in-out)
    public static let slowAnimation: Animation = .easeInOut(duration: 0.5)

    /// Spring animation (bouncy)
    public static let springAnimation: Animation = .spring(response: 0.3, dampingFraction: 0.7)

    /// Smooth animation (ease-out for exits)
    public static let smoothAnimation: Animation = .easeOut(duration: 0.3)

    // MARK: - Performance Optimization

    /// Quality check interval in frames
    /// Only check every N frames to prevent FPS drops
    /// Reduced to 10 frames for faster response when conditions change
    /// At 60fps, 10 frames = ~6 quality checks per second
    public static let qualityCheckInterval: Int = 10

    /// Countdown tolerance frames
    /// Allow brief validation failures during countdown without canceling
    /// At 60fps, 15 frames = ~0.25 seconds of tolerance
    public static let countdownToleranceFrames: Int = 15

    /// Streaming mesh merger threshold (in number of vertices)
    /// Use streaming merger for meshes with more than this many vertices
    /// to avoid memory spikes
    public static let streamingMeshThreshold: Int = 50_000

    // MARK: - Texture Resolution

    /// Standard texture size (2K) - RECOMMENDED CONFIGURATION
    /// Per POSE_REQUIREMENTS_GUIDE.md "Recommended Configuration" tier
    /// Expected confidence: 83-85% overall system confidence
    /// Real-world viability: Excellent (home environment, manageable file sizes)
    /// Used by default for balanced quality/performance
    public static let standardTextureWidth: Int = 2048
    public static let standardTextureHeight: Int = 2048

    /// High resolution texture size (4K) - BEST CASE CONFIGURATION
    /// Per POSE_REQUIREMENTS_GUIDE.md "Best Case Scenario" tier
    /// Expected confidence: 90-92% overall system confidence
    /// Note: 16x file size vs 1K, slower processing, requires optimal conditions
    /// Use for: Pore analysis (4K critical), high accuracy
    public static let highResTextureWidth: Int = 4096
    public static let highResTextureHeight: Int = 4096
}

// MARK: - Texture Resolution

/// Texture resolution modes for device-based configuration
public enum TextureResolution {
    case standard2K  // 2048×2048
    case highRes4K   // 4096×4096

    public var width: Int {
        switch self {
        case .standard2K: return ScanConfiguration.standardTextureWidth
        case .highRes4K: return ScanConfiguration.highResTextureWidth
        }
    }

    public var height: Int {
        switch self {
        case .standard2K: return ScanConfiguration.standardTextureHeight
        case .highRes4K: return ScanConfiguration.highResTextureHeight
        }
    }
}

// MARK: - ScanConfiguration Multi-Frame Capture

extension ScanConfiguration {

    // MARK: - Multi-Frame Capture

    /// Number of frames to capture per pose - RECOMMENDED CONFIGURATION
    /// Per POSE_REQUIREMENTS_GUIDE.md "Recommended Configuration" tier
    /// 3 frames provides good averaging to reduce noise while maintaining speed
    /// Expected confidence boost: +8-12 percentage points vs single frame
    public static let framesPerPoseRecommended: Int = 3

    /// Number of frames to capture per pose - BEST CASE CONFIGURATION
    /// Per POSE_REQUIREMENTS_GUIDE.md "Best Case Scenario" tier
    /// 5 frames provides maximum averaging for high accuracy
    /// Expected confidence boost: +15-20 percentage points vs single frame
    /// Note: Slower capture, use for highest quality needs
    public static let framesPerPoseBest: Int = 5

    // MARK: - Exposure and Timing

    /// Ideal exposure value for image capture
    /// Range: 0.0 (black) to 1.0 (white), 0.5 = neutral
    public static let idealExposure: Float = 0.5

    /// Maximum acceptable exposure deviation from ideal
    /// Captures with exposure outside (ideal ± deviation) are rejected
    public static let maxExposureDeviation: Float = 0.3

    /// Delay before retrying calibration (seconds)
    /// After failed calibration, wait this long before allowing retry
    public static let calibrationRetryDelay: TimeInterval = 0.3

    /// Delay before showing results (seconds)
    /// Brief delay after processing completes to smooth transition
    public static let resultsDisplayDelay: TimeInterval = 0.5

    // MARK: - Automatic Retry Configuration

    /// Maximum number of automatic retry attempts for transient errors
    public static let maxAutoRetryAttempts: Int = 3

    /// Base delay for exponential backoff (seconds)
    /// Actual delay = baseDelay * (2 ^ attemptNumber)
    /// Example: 1.0s, 2.0s, 4.0s for 3 attempts
    public static let retryBaseDelay: TimeInterval = 1.0

    /// Maximum retry delay (seconds)
    /// Caps exponential backoff to prevent excessive wait times
    public static let maxRetryDelay: TimeInterval = 8.0

    /// Whether to show retry progress to user
    /// If true, display "Retrying automatically..." message
    public static let showRetryProgress: Bool = true

    // MARK: - Memory Management

    /// Maximum number of captured frames to keep in memory
    public static let maxCapturedFramesInMemory: Int = 7

    /// Thumbnail image size (width/height in points)
    public static let thumbnailSize: CGSize = CGSize(width: 200, height: 200)

    /// Heatmap image size (width/height in points)
    public static let heatmapSize: CGSize = CGSize(width: 300, height: 300)

    // MARK: - Score Thresholds

    /// Excellent score threshold (80+)
    public static let excellentScoreThreshold: Float = 80.0

    /// Good score threshold (60+)
    public static let goodScoreThreshold: Float = 60.0

    /// Fair score threshold (40+)
    public static let fairScoreThreshold: Float = 40.0

    // Below 40 is considered poor

    // MARK: - Helper Methods

    /// Check if lighting change is within acceptable range
    public static func isLightingChangeAcceptable(_ change: Double) -> Bool {
        return change <= maxLightingChangeThreshold
    }

    /// Check if color temperature change is within acceptable range
    public static func isColorTempChangeAcceptable(_ change: Double) -> Bool {
        return change <= maxColorTemperatureChangeThreshold
    }

    /// Check if face expression is neutral enough for capture
    public static func isExpressionNeutral(jawOpen: Double, eyeBlink: Double, smile: Double) -> Bool {
        return jawOpen <= maxJawOpenThreshold &&
               eyeBlink <= maxEyeBlinkThreshold &&
               smile <= maxSmileThreshold
    }

    /// Check if image quality is acceptable
    public static func isImageQualityAcceptable(sharpness: Float, blur: Float, exposure: Float) -> Bool {
        return sharpness >= minSharpnessScore &&
               blur <= maxBlurMetric &&
               exposure >= minExposureLevel &&
               exposure <= maxExposureLevel
    }
}
