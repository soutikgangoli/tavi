//
//  CalibrationManager.swift
//  Tavi
//
//  Handles calibration state, quality checks, and validation
//  Extracted from FaceScan3DViewModel to improve maintainability
//

import Foundation
import ARKit
import SwiftUI
import CoreImage

/// Manages calibration state and quality validation
@MainActor
public class CalibrationManager: ObservableObject {
    // MARK: - Published Properties

    /// Current calibration state
    @Published public var calibrationState: CalibrationState = CalibrationState()

    /// Quality warning message
    @Published public var qualityWarning: String?

    /// Whether current pose matches target direction
    @Published public var isPoseCorrect: Bool = false

    /// User chose to continue anyway despite warnings
    @Published public var continueAnywayOverride: Bool = false

    /// Current face angles for debug display (in degrees)
    @Published public var currentYaw: Float = 0
    @Published public var currentPitch: Float = 0
    @Published public var currentRoll: Float = 0

    // MARK: - Private Properties

    private var lastTransform: simd_float4x4?
    private var previousQualityWarning: String?
    private var baselineLighting: CGFloat?
    private var baselineColorTemperature: CGFloat?

    // Quality check throttling to prevent FPS drops
    private var qualityCheckFrameCounter: Int = 0
    private var lastQualityCheckResult: Bool = true

    // Debug logging throttle
    private var debugLogFrameCounter: Int = 0

    // Reusable instances to avoid expensive allocations
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let edgeCaseDetector = EdgeCaseDetector()
    private let imageQualityAnalyzer = ImageQualityAnalyzer()

    // MARK: - Public Methods

    /// Lightweight calibration update (no ARFrame retention, uses basic lighting estimation)
    /// Use this for real-time tracking updates to prevent ARFrame memory leaks
    public func updateCalibrationLightweight(faceAnchor: ARFaceAnchor, lightEstimation: LightEstimation?) {
        // CRITICAL FIX: Validate face is actually tracked with good confidence
        // ARKit provides face anchor even with poor tracking - we need to verify quality
        let isTracked = faceAnchor.isTracked

        // SWIFTUI REACTIVITY FIX: Work with a local copy, then reassign to trigger @Published
        // CalibrationState is a struct, so mutating properties doesn't trigger objectWillChange
        var state = calibrationState

        // Update face detected only if ARKit confirms good tracking
        state.faceDetected = isTracked

        // If face not properly tracked, set everything to invalid and return early
        guard isTracked else {
            state.lighting = .tooDark
            state.distance = .tooFar
            state.stability = .moving
            calibrationState = state  // Trigger @Published
            return
        }

        // Use basic ARKit lighting estimation (no frame analysis needed)
        state.updateLighting(from: lightEstimation)

        // Update distance
        state.updateDistance(from: faceAnchor.transform)

        // Throttled debug logging (every 30 frames ≈ 0.5s at 60fps)
        debugLogFrameCounter += 1
        if debugLogFrameCounter >= 30 {
            debugLogFrameCounter = 0
            if let light = lightEstimation {
                let distanceMeters = abs(faceAnchor.transform.columns.3.z)
                AppLogger.faceScan.debug("""
                    📊 Calibration State:
                      💡 Light: \(Int(light.ambientIntensity)) lumens -> \(state.lighting.rawValue)
                      📏 Distance: \(String(format: "%.2f", distanceMeters))m (\(Int(distanceMeters * 100))cm) -> \(state.distance.rawValue)
                      🎯 Tracked: \(isTracked)
                    """)
            }
        }

        // Update stability
        if let lastTransform = lastTransform {
            let movement = calculateMovement(from: lastTransform, to: faceAnchor.transform)
            state.updateStability(movement: movement)
        } else {
            // First frame - no previous transform to compare
            state.stability = .moving
        }

        // Update center position for UI indicator
        // CRITICAL: Use camera-relative angles, not world-space angles
        let eulerAngles = faceAnchor.eulerAnglesRelativeToCamera()
        let yawDegrees = eulerAngles.y * 180 / .pi
        let pitchDegrees = eulerAngles.x * 180 / .pi
        let rollDegrees = eulerAngles.z * 180 / .pi

        // DEBUG: Log yaw calculation (throttled with calibration logs)
        if debugLogFrameCounter == 0 {
            AppLogger.faceScan.debug("🧭 Yaw: \(String(format: "%.1f", yawDegrees))° → centerPosition: \(state.centerPosition.rawValue)")
        }

        state.updateCenterPosition(yaw: yawDegrees)

        // CRITICAL: Store angles for debug display
        state.currentYaw = yawDegrees
        state.currentPitch = pitchDegrees
        state.currentRoll = rollDegrees

        // CRITICAL: Also update @Published properties for SwiftUI reactivity
        self.currentYaw = yawDegrees
        self.currentPitch = pitchDegrees
        self.currentRoll = rollDegrees

        // DEBUG: Log @Published property updates (throttled with calibration logs)
        if debugLogFrameCounter == 0 {
            AppLogger.faceScan.debug("📐 @Published angles: Yaw=\(String(format: "%.1f", self.currentYaw))° Pitch=\(String(format: "%.1f", self.currentPitch))° Roll=\(String(format: "%.1f", self.currentRoll))°")
        }

        // CRITICAL: Update isPoseCorrect for Direction badge
        // During calibration, check if user is looking straight ahead (centered pose)
        let poseIsCorrect = abs(yawDegrees) <= ScanConfiguration.maxCenterYawDegrees &&
                            abs(pitchDegrees) <= ScanConfiguration.maxCenterPitchDegrees &&
                            abs(rollDegrees) <= ScanConfiguration.maxCenterRollDegrees

        if self.isPoseCorrect != poseIsCorrect {
            print("🎯 CalibrationManager: isPoseCorrect changed: \(self.isPoseCorrect) → \(poseIsCorrect) (yaw: \(String(format: "%.1f", yawDegrees))°, pitch: \(String(format: "%.1f", pitchDegrees))°, roll: \(String(format: "%.1f", rollDegrees))°)")
        }

        self.isPoseCorrect = poseIsCorrect

        // CRITICAL: Reassign to trigger @Published objectWillChange
        calibrationState = state

        lastTransform = faceAnchor.transform
    }

    /// Full calibration update with ARFrame (only use when actually capturing, not for real-time tracking)
    /// IMPORTANT: Only call this when necessary - ARFrame retention causes memory leaks
    public func updateCalibration(faceAnchor: ARFaceAnchor, frame: ARFrame, lightEstimation: LightEstimation?) {
        // SWIFTUI REACTIVITY FIX: Work with local copy, reassign to trigger @Published
        var state = calibrationState

        // Update face detected
        state.faceDetected = true

        // CRITICAL FIX: Run real quality analysis instead of just ARKit intensity check
        // PERFORMANCE: Throttle expensive sharpness analysis to every 30 frames (0.5s at 60fps) to reduce lag
        // Quality checks with image analysis are CPU-intensive and cause judder at higher frequencies
        qualityCheckFrameCounter += 1
        if qualityCheckFrameCounter >= ScanConfiguration.qualityCheckInterval {
            qualityCheckFrameCounter = 0
            updateRealLightingQuality(frame: frame, faceAnchor: faceAnchor, lightEstimation: lightEstimation)
            // Note: updateRealLightingQuality mutates calibrationState directly, so we need to refresh
            state = calibrationState
        } else {
            // Fallback to basic ARKit check between quality analyses
            state.updateLighting(from: lightEstimation)
        }

        // Update distance
        state.updateDistance(from: faceAnchor.transform)

        // Update stability
        if let lastTransform = lastTransform {
            let movement = calculateMovement(from: lastTransform, to: faceAnchor.transform)
            state.updateStability(movement: movement)
        }

        // CRITICAL: Reassign to trigger @Published
        calibrationState = state

        lastTransform = faceAnchor.transform
    }

    /// Perform comprehensive lighting quality analysis on actual camera image
    private func updateRealLightingQuality(frame: ARFrame, faceAnchor: ARFaceAnchor, lightEstimation: LightEstimation?) {
        let pixelBuffer = frame.capturedImage

        // Convert to UIImage for analysis
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            // Fallback to basic check if conversion fails
            calibrationState.updateLighting(from: lightEstimation)
            return
        }
        let texture = UIImage(cgImage: cgImage)

        // Run EdgeCaseDetector analysis with "Strict" mode
        let edgeCases = edgeCaseDetector.detectEdgeCases(
            texture: texture,
            faceAnchor: faceAnchor,
            strictness: .strict
        )

        // Update calibration state based on actual quality metrics
        if !edgeCases.shouldProceed {
            // BLOCKING issue detected - mark as bad lighting
            let issue = edgeCases.blockReason ?? "Poor lighting quality"

            // Determine specific lighting condition from the block reason
            if issue.lowercased().contains("dark") || issue.lowercased().contains("underexposed") {
                calibrationState.lighting = .tooDark
                calibrationState.lightingDetail = issue
            } else if issue.lowercased().contains("bright") || issue.lowercased().contains("overexposed") {
                calibrationState.lighting = .tooBright
                calibrationState.lightingDetail = issue
            } else {
                // Other quality issues (shadows, color cast, etc.)
                calibrationState.lighting = .poor
                calibrationState.lightingDetail = issue
            }
        } else if !edgeCases.warnings.isEmpty {
            // WARNING - not blocking but quality could be better
            calibrationState.lighting = .acceptable
            calibrationState.lightingDetail = edgeCases.warnings.first
        } else {
            // All checks passed
            calibrationState.lighting = .good
            calibrationState.lightingDetail = nil
        }
    }

    /// Reset calibration state
    public func reset() {
        calibrationState = CalibrationState()
        continueAnywayOverride = false
        qualityWarning = nil
        previousQualityWarning = nil
        baselineLighting = nil
        baselineColorTemperature = nil
        isPoseCorrect = false
        lastTransform = nil
    }

    /// Clear quality warning
    public func clearQualityWarning() {
        qualityWarning = nil
        previousQualityWarning = nil
    }

    /// Set quality warning with haptic feedback if it's a new/different warning
    public func setQualityWarning(_ warning: String) {
        // Only trigger haptic if this is a NEW warning (different from previous)
        if previousQualityWarning != warning {
            if HapticSettings.shared.isEnabled {
                HapticManager.shared.warning()
            }
            previousQualityWarning = warning
        }
        qualityWarning = warning
    }

    /// Perform pre-flight checks before starting scan
    /// Returns false if blocking issues detected
    public func performPreflightChecks(
        faceAnchor: ARFaceAnchor,
        frame: ARFrame,
        strictness: LightingStrictnessLevel
    ) -> Bool {
        let pixelBuffer = frame.capturedImage

        // Convert pixel buffer to UIImage for edge case detection
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return false
        }
        let texture = UIImage(cgImage: cgImage)

        // Run edge case detection with strictness level
        let edgeCases = edgeCaseDetector.detectEdgeCases(
            texture: texture,
            faceAnchor: faceAnchor,
            strictness: strictness
        )

        // Check for blocking issues (unless user overrode)
        if !edgeCases.shouldProceed && !continueAnywayOverride {
            return false
        }

        // Check for warning issues (don't block, but inform user)
        if !edgeCases.warnings.isEmpty {
            qualityWarning = edgeCases.warnings.first
        }

        return true
    }

    /// Check image quality from current frame with comprehensive validations
    public func checkImageQuality(
        frame: ARFrame,
        faceAnchor: ARFaceAnchor?,
        blendShapes: FaceBlendShapes?,
        lightEstimation: LightEstimation?,
        currentGuidanceStep: GuidanceStep
    ) -> Bool {
        // PERFORMANCE OPTIMIZATION: Throttle quality checks
        qualityCheckFrameCounter += 1
        if qualityCheckFrameCounter < ScanConfiguration.qualityCheckInterval {
            return lastQualityCheckResult
        }
        qualityCheckFrameCounter = 0

        // 1. Check lighting consistency
        let lightingOK = checkLightingConsistency(lightEstimation: lightEstimation)
        if !lightingOK {
            print("❌ QUALITY CHECK FAILED: Lighting inconsistency")
            AppLogger.faceScan.debug("❌ Quality check failed: Lighting inconsistency")
            lastQualityCheckResult = false
            return false
        }

        // 2. Check for neutral expression
        var expressionOK = true
        if let blendShapes = blendShapes {
            expressionOK = checkNeutralExpression(blendShapes: blendShapes, currentStep: currentGuidanceStep)
            if !expressionOK {
                print("❌ QUALITY CHECK FAILED: Non-neutral expression (smiling/frowning/blinking)")
                AppLogger.faceScan.debug("❌ Quality check failed: Non-neutral expression")
                lastQualityCheckResult = false
                return false
            }
        }

        // 3. Check exposure
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            qualityWarning = nil
            lastQualityCheckResult = true
            return true
        }

        let image = UIImage(cgImage: cgImage)
        
        // 3a. Check exposure
        let exposureOK = checkExposure(image: image)
        if !exposureOK {
            print("❌ QUALITY CHECK FAILED: Exposure issue (too bright/dark)")
            AppLogger.faceScan.debug("❌ Quality check failed: Exposure issue")
            lastQualityCheckResult = false
            return false
        }
        
        // 3b. Check sharpness (blur detection) - same check as TextureCapture uses
        let sharpnessOK = checkSharpness(image: image, lightEstimation: lightEstimation)
        if !sharpnessOK {
            print("❌ QUALITY CHECK FAILED: Image too blurry (sharpness below threshold)")
            AppLogger.faceScan.debug("❌ Quality check failed: Image too blurry")
            lastQualityCheckResult = false
            return false
        }

        // 4. Check for occlusions
        if calibrationState.faceDetected && !calibrationState.isCalibrated {
            print("❌ QUALITY CHECK FAILED: Possible occlusion (face detected but not calibrated)")
            AppLogger.faceScan.warning("❌ Quality check failed: Possible occlusion")
            qualityWarning = "Face partially covered - please remove hands/hair from face"
            lastQualityCheckResult = false
            return false
        }

        // All quality checks passed
        print("✅ QUALITY CHECK PASSED: Lighting=\(lightingOK), Expression=\(expressionOK), Exposure=\(exposureOK), Sharpness=\(sharpnessOK), Occlusion=clear")
        qualityWarning = nil
        lastQualityCheckResult = true
        return true
    }

    // MARK: - Private Methods

    private func calculateMovement(from oldTransform: simd_float4x4, to newTransform: simd_float4x4) -> Float {
        let oldPosition = oldTransform.columns.3
        let newPosition = newTransform.columns.3

        let dx = newPosition.x - oldPosition.x
        let dy = newPosition.y - oldPosition.y
        let dz = newPosition.z - oldPosition.z

        return sqrt(dx * dx + dy * dy + dz * dz)
    }

    private func checkLightingConsistency(lightEstimation: LightEstimation?) -> Bool {
        guard let baseline = baselineLighting,
              let current = lightEstimation?.ambientIntensity else {
            // Set baseline from first check
            if baselineLighting == nil, let current = lightEstimation?.ambientIntensity {
                baselineLighting = current
                baselineColorTemperature = lightEstimation?.ambientColorTemperature
                AppLogger.faceScan.info("✅ Baseline lighting set: \(Int(current)) lux")
            }
            return true
        }

        let lightingChange = abs(current - baseline) / baseline
        if !ScanConfiguration.isLightingChangeAcceptable(lightingChange) {
            AppLogger.faceScan.warning("❌ Quality check failed: Lighting consistency (\(Int(lightingChange * 100))% change)")
            qualityWarning = "Lighting changed - please maintain consistent lighting"
            return false
        }

        // Check color temperature consistency
        if let baselineTemp = baselineColorTemperature,
           let currentTemp = lightEstimation?.ambientColorTemperature {
            let tempChange = abs(currentTemp - baselineTemp) / baselineTemp
            if !ScanConfiguration.isColorTempChangeAcceptable(tempChange) {
                AppLogger.faceScan.warning("❌ Quality check failed: Color temperature consistency")
                qualityWarning = "Light color changed - please stay in same lighting"
                return false
            }
        }

        return true
    }

    private func checkNeutralExpression(blendShapes: FaceBlendShapes, currentStep: GuidanceStep) -> Bool {
        // Detect smiling - SKIP for lookDown
        if currentStep != .lookDown {
            let smileAmount = (blendShapes.mouthSmileLeft + blendShapes.mouthSmileRight) / 2.0
            if Double(smileAmount) > ScanConfiguration.maxSmileThreshold {
                setQualityWarning("Please keep a neutral expression (no smiling)")
                return false
            }
        }

        // Detect frowning
        let frownAmount = (blendShapes.mouthFrownLeft + blendShapes.mouthFrownRight) / 2.0
        if Double(frownAmount) > ScanConfiguration.maxSmileThreshold {
            setQualityWarning("Please relax your expression (no frowning)")
            return false
        }

        // Detect jaw movement
        if Double(blendShapes.jawOpen) > ScanConfiguration.maxJawOpenThreshold {
            setQualityWarning("Please keep your mouth closed")
            return false
        }

        // Detect lip puckering
        if Double(blendShapes.mouthPucker) > ScanConfiguration.maxMouthPuckerThreshold {
            setQualityWarning("Please relax your lips")
            return false
        }

        // Detect cheek puffing
        if Double(blendShapes.cheekPuff) > ScanConfiguration.maxCheekPuffThreshold {
            setQualityWarning("Please relax your cheeks")
            return false
        }

        // Detect eye blinking
        let blinkAmount = max(blendShapes.eyeBlinkLeft, blendShapes.eyeBlinkRight)
        if Double(blinkAmount) > ScanConfiguration.blinkDetectionThreshold {
            setQualityWarning("Please keep your eyes open")
            return false
        }

        // Detect eyes wide open
        let eyeWideAmount = max(blendShapes.eyeWideLeft, blendShapes.eyeWideRight)
        if Double(eyeWideAmount) > ScanConfiguration.maxEyeWideThreshold {
            setQualityWarning("Please relax your eyes")
            return false
        }

        // Detect eye squinting - SKIP for lookDown
        if currentStep != .lookDown {
            let squintAmount = max(blendShapes.eyeSquintLeft, blendShapes.eyeSquintRight)
            if Double(squintAmount) > ScanConfiguration.maxSquintThreshold {
                setQualityWarning("Please don't squint")
                return false
            }
        }

        // Detect raised eyebrows
        if Double(blendShapes.browInnerUp) > ScanConfiguration.maxBrowMovementThreshold {
            setQualityWarning("Please relax your eyebrows")
            return false
        }

        // Detect furrowed brows
        let browDownAmount = max(blendShapes.browDownLeft, blendShapes.browDownRight)
        if Double(browDownAmount) > ScanConfiguration.maxBrowMovementThreshold {
            setQualityWarning("Please relax your forehead")
            return false
        }

        return true
    }

    /// Check exposure - analyzes multiple regions and uses BEST result
    /// This ensures we catch the best exposed parts of the face
    private func checkExposure(image: UIImage) -> Bool {
        // Analyze multiple regions to find the BEST exposure (closest to ideal)
        let bestExposure = analyzeBestExposure(image: image)

        if bestExposure < ScanConfiguration.underexposureThreshold {
            AppLogger.faceScan.warning("❌ Quality check failed: Underexposed (best exposure: \(String(format: "%.3f", bestExposure)))")
            qualityWarning = "Too dark - move to better lighting"
            return false
        }

        if bestExposure > ScanConfiguration.overexposureThreshold {
            AppLogger.faceScan.warning("❌ Quality check failed: Overexposed (best exposure: \(String(format: "%.3f", bestExposure)))")
            qualityWarning = "Too bright - reduce lighting or move away from bright light"
            return false
        }

        let exposureDeviation = abs(bestExposure - ScanConfiguration.idealExposure)
        if exposureDeviation > ScanConfiguration.maxExposureDeviation {
            AppLogger.faceScan.warning("❌ Quality check failed: Poor exposure (best exposure: \(String(format: "%.3f", bestExposure)), deviation: \(String(format: "%.3f", exposureDeviation)))")
            qualityWarning = "Adjust lighting for better exposure"
            return false
        }

        return true
    }
    
    /// Check image sharpness (blur detection) - analyzes multiple regions and uses BEST result
    /// This ensures we catch the sharpest parts of the face, not just average quality
    private func checkSharpness(image: UIImage, lightEstimation: LightEstimation?) -> Bool {
        // Analyze multiple regions of the image to find the BEST sharpness
        let bestSharpness = analyzeBestSharpness(image: image)
        
        // ADAPTIVE SHARPNESS THRESHOLD: Adjust based on lighting conditions
        // VERY LENIENT: Significantly lowered thresholds to ensure captures work reliably
        // Real-world testing shows TrueDepth camera can achieve good results with lower thresholds
        var adaptiveSharpnessThreshold: Float = 40.0  // Base minimum (significantly lowered from 80)
        let minSharpnessOptimal: Float = 60.0  // Target for optimal lighting (lowered from 120)
        let minSharpnessPoorLight: Float = 30.0   // Minimum for poor lighting (lowered from 60)
        
        if let lighting = lightEstimation {
            let intensity = Float(lighting.ambientIntensity)
            // Scale threshold based on lighting: 1000+ lux = optimal, <500 lux = poor
            if intensity < 500 {
                adaptiveSharpnessThreshold = minSharpnessPoorLight
            } else if intensity > 1000 {
                adaptiveSharpnessThreshold = minSharpnessOptimal
            } else {
                // Linear interpolation between poor and optimal
                let ratio = (intensity - 500) / 500
                adaptiveSharpnessThreshold = minSharpnessPoorLight +
                    (minSharpnessOptimal - minSharpnessPoorLight) * ratio
            }
        }
        
        // Calculate how close we are to threshold for helpful feedback
        let sharpnessRatio = bestSharpness / adaptiveSharpnessThreshold
        let percentOfThreshold = Int(sharpnessRatio * 100)
        
        if bestSharpness < adaptiveSharpnessThreshold {
            // Provide specific, helpful guidance based on how close we are
            var guidanceMessage = "Hold phone steady"
            
            if percentOfThreshold < 50 {
                guidanceMessage = "Phone too blurry - hold very still, wait for focus"
            } else if percentOfThreshold < 75 {
                guidanceMessage = "Almost there - hold phone steady, wait 1-2 seconds"
            } else if percentOfThreshold < 90 {
                guidanceMessage = "Almost sharp - hold still for 1 more second"
            } else {
                guidanceMessage = "Hold steady - focus is almost ready"
            }
            
            AppLogger.faceScan.warning("❌ Quality check failed: Image too blurry (best sharpness: \(String(format: "%.1f", bestSharpness)), threshold: \(String(format: "%.1f", adaptiveSharpnessThreshold)), \(percentOfThreshold)% of threshold)")
            qualityWarning = guidanceMessage
            return false
        }
        
        // Success - clear any previous warnings
        if qualityWarning?.contains("blur") == true || qualityWarning?.contains("steady") == true {
            qualityWarning = nil
        }
        
        return true
    }
    
    /// Analyze multiple regions of the image and return the BEST sharpness value
    /// This checks center, face regions, and edge regions to find the sharpest area
    /// PERFORMANCE: Fast path only checks center region during guidance to prevent judder
    private func analyzeBestSharpness(image: UIImage, fastPath: Bool = true) -> Float {
        guard let cgImage = image.cgImage else { return 0 }
        
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        
        // PERFORMANCE OPTIMIZATION: Fast path only checks center region
        // This is sufficient for guidance mode and prevents judder
        // Full analysis is only needed during actual capture
        if fastPath {
            // Only check center region (nose/cheeks - usually sharpest)
            let centerRegion = CGRect(
                x: width * 0.25,
                y: height * 0.25,
                width: width * 0.5,
                height: height * 0.5
            )
            
            guard let croppedCGImage = cgImage.cropping(to: centerRegion) else {
                // Fallback to full image if cropping fails
                return imageQualityAnalyzer.calculateSharpness(image: image)
            }
            
            // UIImage(cgImage:) is non-optional, so create it directly
            let croppedImage = UIImage(cgImage: croppedCGImage)
            return imageQualityAnalyzer.calculateSharpness(image: croppedImage)
        }
        
        // Full analysis: check all regions (only used during actual capture)
        let regions: [(CGRect, String)] = [
            // Center region (nose/cheeks - usually sharpest)
            (CGRect(x: width * 0.25, y: height * 0.25, width: width * 0.5, height: height * 0.5), "center"),
            // Upper face (forehead/eyes)
            (CGRect(x: width * 0.2, y: height * 0.1, width: width * 0.6, height: height * 0.3), "upper"),
            // Lower face (mouth/chin)
            (CGRect(x: width * 0.2, y: height * 0.5, width: width * 0.6, height: height * 0.4), "lower"),
            // Left side (cheek)
            (CGRect(x: width * 0.1, y: height * 0.2, width: width * 0.4, height: height * 0.6), "left"),
            // Right side (cheek)
            (CGRect(x: width * 0.5, y: height * 0.2, width: width * 0.4, height: height * 0.6), "right"),
            // Full image (fallback)
            (CGRect(x: 0, y: 0, width: width, height: height), "full")
        ]
        
        var bestSharpness: Float = 0
        var bestRegion: String = "none"
        
        // Analyze each region and keep the BEST (highest) sharpness
        for (region, name) in regions {
            // Crop image to region
            guard let croppedCGImage = cgImage.cropping(to: region) else {
                continue
            }
            
            // UIImage(cgImage:) is non-optional, so create it directly
            let croppedImage = UIImage(cgImage: croppedCGImage)
            let regionSharpness = imageQualityAnalyzer.calculateSharpness(image: croppedImage)
            
            if regionSharpness > bestSharpness {
                bestSharpness = regionSharpness
                bestRegion = name
            }
        }
        
        if bestSharpness > 0 {
            AppLogger.faceScan.debug("📊 Best sharpness: \(String(format: "%.1f", bestSharpness)) from region: \(bestRegion)")
        }
        
        return bestSharpness
    }
    
    /// Analyze multiple regions of the image and return the BEST exposure value
    /// This checks different face regions to find the best exposed area
    private func analyzeBestExposure(image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 0.5 }
        
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let idealExposure: Float = 0.5
        
        // Define regions to analyze (focus on face areas)
        let regions: [(CGRect, String)] = [
            // Center region (nose/cheeks - usually best exposed)
            (CGRect(x: width * 0.25, y: height * 0.25, width: width * 0.5, height: height * 0.5), "center"),
            // Upper face (forehead/eyes)
            (CGRect(x: width * 0.2, y: height * 0.1, width: width * 0.6, height: height * 0.3), "upper"),
            // Lower face (mouth/chin)
            (CGRect(x: width * 0.2, y: height * 0.5, width: width * 0.6, height: height * 0.4), "lower"),
            // Full image (fallback)
            (CGRect(x: 0, y: 0, width: width, height: height), "full")
        ]
        
        var bestExposure: Float = 0.5
        var bestDeviation: Float = 1.0  // Start with worst possible
        var bestRegion: String = "none"
        
        // Analyze each region and keep the BEST (closest to ideal) exposure
        for (region, name) in regions {
            // Crop image to region
            guard let croppedCGImage = cgImage.cropping(to: region),
                  let croppedImage = UIImage(cgImage: croppedCGImage) as UIImage? else {
                continue
            }
            
            let regionExposure = imageQualityAnalyzer.calculateExposure(image: croppedImage)
            let deviation = abs(regionExposure - idealExposure)
            
            // Best exposure is the one closest to ideal (0.5)
            if deviation < bestDeviation {
                bestExposure = regionExposure
                bestDeviation = deviation
                bestRegion = name
            }
        }
        
        AppLogger.faceScan.debug("📊 Best exposure: \(String(format: "%.3f", bestExposure)) (deviation: \(String(format: "%.3f", bestDeviation))) from region: \(bestRegion)")
        
        return bestExposure
    }
}

// MARK: - Haptic Settings (moved from ViewModel)

/// Shared settings for haptic feedback
@MainActor
public class HapticSettings: ObservableObject {
    @AppStorage("enableHapticFeedback") var isEnabled: Bool = true
    static let shared = HapticSettings()
}
