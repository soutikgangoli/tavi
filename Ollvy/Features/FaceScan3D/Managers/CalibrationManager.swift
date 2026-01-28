//
//  CalibrationManager.swift
//  Ollvy
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
    private nonisolated let edgeCaseDetector = EdgeCaseDetector()
    private let imageQualityAnalyzer = ImageQualityAnalyzer()

    // Flag to signal cancellation to async Tasks
    private var isCancelled: Bool = false

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
            // CRITICAL FIX: Defer @Published update using Task to break out of view update cycle
            let invalidState = state
            Task { @MainActor [weak self] in
                self?.calibrationState = invalidState
            }
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

        // CRITICAL: Store angles for debug display (non-published struct property)
        state.currentYaw = yawDegrees
        state.currentPitch = pitchDegrees
        state.currentRoll = rollDegrees

        // CRITICAL: Update isPoseCorrect for Direction badge
        // During calibration, check if user is looking straight ahead (centered pose)
        let poseIsCorrect = abs(yawDegrees) <= ScanConfiguration.maxCenterYawDegrees &&
                            abs(pitchDegrees) <= ScanConfiguration.maxCenterPitchDegrees &&
                            abs(rollDegrees) <= ScanConfiguration.maxCenterRollDegrees

        // Store transform before deferring
        lastTransform = faceAnchor.transform

        // CRITICAL FIX: Defer @Published property updates using Task to break out of view update cycle
        let finalState = state
        let poseChanged = self.isPoseCorrect != poseIsCorrect
        let shouldLogAngles = debugLogFrameCounter == 0

        Task { @MainActor [weak self] in
            guard let self else { return }

            // Update @Published angle properties for SwiftUI reactivity
            self.currentYaw = yawDegrees
            self.currentPitch = pitchDegrees
            self.currentRoll = rollDegrees

            // DEBUG: Log @Published property updates (throttled with calibration logs)
            if shouldLogAngles {
                AppLogger.faceScan.debug("📐 @Published angles: Yaw=\(String(format: "%.1f", self.currentYaw))° Pitch=\(String(format: "%.1f", self.currentPitch))° Roll=\(String(format: "%.1f", self.currentRoll))°")
            }

            if poseChanged {
                AppLogger.faceScan.debug("🎯 CalibrationManager: isPoseCorrect changed: \(self.isPoseCorrect) → \(poseIsCorrect) (yaw: \(String(format: "%.1f", yawDegrees))°, pitch: \(String(format: "%.1f", pitchDegrees))°, roll: \(String(format: "%.1f", rollDegrees))°)")
            }

            self.isPoseCorrect = poseIsCorrect

            // CRITICAL: Reassign to trigger @Published objectWillChange
            self.calibrationState = finalState
        }
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
        // Defer @Published property update using asyncAfter to break out of view update cycle
        Task { @MainActor [weak self] in
            self?.calibrationState = state
        }

        lastTransform = faceAnchor.transform
    }

    /// Perform comprehensive lighting quality analysis on actual camera image
    /// OPTIMIZATION: Now runs asynchronously on background thread to prevent main thread blocking
    private func updateRealLightingQuality(frame: ARFrame, faceAnchor: ARFaceAnchor, lightEstimation: LightEstimation?) {
        let pixelBuffer = frame.capturedImage

        // Capture cancellation flag before entering async context
        let wasCancelledAtStart = self.isCancelled

        // OPTIMIZATION: Move expensive image processing off main thread
        Task.detached(priority: .userInitiated) { [weak self, pixelBuffer, faceAnchor, wasCancelledAtStart] in
            // Early exit if already cancelled at Task creation time
            guard !wasCancelledAtStart else { return }
            guard let self = self else { return }

            // Convert to UIImage for analysis (off main thread)
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            guard let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                // Fallback to basic check if conversion fails - use asyncAfter to defer
                Task { @MainActor [weak self] in
                    guard let self = self, !self.isCancelled else { return }
                    self.calibrationState.updateLighting(from: lightEstimation)
                }
                return
            }
            let texture = UIImage(cgImage: cgImage)

            // Check cancellation before expensive edge case detection
            let isCancelledNow = await MainActor.run { self.isCancelled }
            guard !isCancelledNow else { return }

            // Run EdgeCaseDetector analysis with "Strict" mode (expensive - off main thread)
            let edgeCases = self.edgeCaseDetector.detectEdgeCases(
                texture: texture,
                faceAnchor: faceAnchor,
                strictness: .strict
            )

            // CRITICAL FIX: Extract Sendable values from edgeCases BEFORE the closure
            // to avoid capturing non-Sendable type EdgeCaseAnalysis in @Sendable closure
            let shouldProceed = edgeCases.shouldProceed
            let blockReason = edgeCases.blockReason
            let warnings = edgeCases.warnings
            let firstWarning = warnings.first

            // Update calibration state on main thread - use asyncAfter to defer
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Skip update if cancelled (session is stopping)
                guard !self.isCancelled else { return }

                // Update calibration state based on actual quality metrics
                if !shouldProceed {
                    // BLOCKING issue detected - mark as bad lighting
                    let issue = blockReason ?? "Poor lighting quality"

                    // Determine specific lighting condition from the block reason
                    if issue.lowercased().contains("dark") || issue.lowercased().contains("underexposed") {
                        self.calibrationState.lighting = .tooDark
                        self.calibrationState.lightingDetail = issue
                    } else if issue.lowercased().contains("bright") || issue.lowercased().contains("overexposed") {
                        self.calibrationState.lighting = .tooBright
                        self.calibrationState.lightingDetail = issue
                    } else {
                        // Other quality issues (shadows, color cast, etc.)
                        self.calibrationState.lighting = .poor
                        self.calibrationState.lightingDetail = issue
                    }
                } else if !warnings.isEmpty {
                    // WARNING - not blocking but quality could be better
                    self.calibrationState.lighting = .acceptable
                    self.calibrationState.lightingDetail = firstWarning
                } else {
                    // All checks passed
                    self.calibrationState.lighting = .good
                    self.calibrationState.lightingDetail = nil
                }
            }
        }
    }

    /// Reset calibration state
    public func reset() {
        // CRITICAL: Set cancellation flag FIRST to stop any in-flight async Tasks
        isCancelled = true

        previousQualityWarning = nil
        baselineLighting = nil
        baselineColorTemperature = nil
        lastTransform = nil
        qualityCheckFrameCounter = 0
        debugLogFrameCounter = 0

        // Defer @Published property updates using asyncAfter to avoid "Publishing changes from within view updates"
        // asyncAfter defers execution to after the current SwiftUI view update cycle completes
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.calibrationState = CalibrationState()
            self.continueAnywayOverride = false
            self.qualityWarning = nil
            self.isPoseCorrect = false

            // CRITICAL FIX: Reset cancellation flag AFTER a short delay
            // This gives in-flight Tasks time to see the cancelled state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.isCancelled = false
            }
        }
    }

    /// Clear quality warning
    public func clearQualityWarning() {
        previousQualityWarning = nil
        // Defer @Published property update using asyncAfter to avoid "Publishing changes from within view updates"
        Task { @MainActor [weak self] in
            self?.qualityWarning = nil
        }
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
        // Defer @Published property update using asyncAfter to break out of view update cycle
        Task { @MainActor [weak self] in
            self?.qualityWarning = warning
        }
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
            let warning = edgeCases.warnings.first
            // Defer @Published property update using asyncAfter to break out of view update cycle
            Task { @MainActor [weak self] in
                self?.qualityWarning = warning
            }
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
            AppLogger.faceScan.debug("❌ QUALITY CHECK FAILED: Lighting inconsistency")
            lastQualityCheckResult = false
            return false
        }

        // 2. Check for neutral expression
        var expressionOK = true
        if let blendShapes = blendShapes {
            expressionOK = checkNeutralExpression(blendShapes: blendShapes, currentStep: currentGuidanceStep)
            if !expressionOK {
                AppLogger.faceScan.debug("❌ QUALITY CHECK FAILED: Non-neutral expression (smiling/frowning/blinking)")
                lastQualityCheckResult = false
                return false
            }
        }

        // 3. Check exposure
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            // Defer @Published property update using asyncAfter to break out of view update cycle
            Task { @MainActor [weak self] in
                self?.qualityWarning = nil
            }
            lastQualityCheckResult = true
            return true
        }

        let image = UIImage(cgImage: cgImage)
        
        // 3a. Check exposure
        let exposureOK = checkExposure(image: image)
        if !exposureOK {
            AppLogger.faceScan.debug("❌ QUALITY CHECK FAILED: Exposure issue (too bright/dark)")
            lastQualityCheckResult = false
            return false
        }

        // 3b. Check sharpness (blur detection) - same check as TextureCapture uses
        let sharpnessOK = checkSharpness(image: image, lightEstimation: lightEstimation)
        if !sharpnessOK {
            AppLogger.faceScan.debug("❌ QUALITY CHECK FAILED: Image too blurry (sharpness below threshold)")
            lastQualityCheckResult = false
            return false
        }

        // Occlusion check removed - too many false positives
        // ARKit face tracking already handles partial occlusions well

        // All quality checks passed
        AppLogger.faceScan.debug("✅ QUALITY CHECK PASSED: Lighting=\(lightingOK), Expression=\(expressionOK), Exposure=\(exposureOK), Sharpness=\(sharpnessOK)")
        // Defer @Published property update using asyncAfter to break out of view update cycle
        Task { @MainActor [weak self] in
            self?.qualityWarning = nil
        }
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

        // SIMPLIFIED: Only warn for MAJOR lighting changes (50%+)
        // Small variations are normal and don't significantly affect quality
        let lightingChange = abs(current - baseline) / baseline
        if lightingChange > 0.50 {  // Only catch major changes
            AppLogger.faceScan.warning("❌ Major lighting change detected (\(Int(lightingChange * 100))%)")
            // Defer @Published property update using asyncAfter to break out of view update cycle
            Task { @MainActor [weak self] in
                self?.qualityWarning = "Lighting changed significantly"
            }
            return false
        }

        // Color temperature check removed - too sensitive and rarely affects scan quality
        return true
    }

    private func checkNeutralExpression(blendShapes: FaceBlendShapes, currentStep: GuidanceStep) -> Bool {
        // SIMPLIFIED EXPRESSION CHECKS - Only check for major issues that affect scan quality
        // Removed overly strict checks that create frustrating UX

        // 1. Eye blink detection - CRITICAL (can't scan closed eyes)
        let blinkAmount = max(blendShapes.eyeBlinkLeft, blendShapes.eyeBlinkRight)
        if Double(blinkAmount) > ScanConfiguration.blinkDetectionThreshold {
            setQualityWarning("Keep your eyes open")
            return false
        }

        // 2. Jaw significantly open - affects face shape
        if Double(blendShapes.jawOpen) > 0.3 {  // More lenient threshold
            setQualityWarning("Close your mouth slightly")
            return false
        }

        // 3. Extreme smile only - very obvious smiling affects face shape
        let smileAmount = (blendShapes.mouthSmileLeft + blendShapes.mouthSmileRight) / 2.0
        if Double(smileAmount) > 0.4 {  // Only catch big smiles, not neutral face variations
            setQualityWarning("Relax into a neutral expression")
            return false
        }

        // All other expression checks removed - they were too strict and created
        // frustrating UX without significantly improving scan quality

        return true
    }

    /// Check exposure - SIMPLIFIED to only catch extreme issues
    /// The camera auto-adjusts exposure well, so we only warn for major problems
    private func checkExposure(image: UIImage) -> Bool {
        let bestExposure = analyzeBestExposure(image: image)

        // Only warn for EXTREME underexposure (very dark)
        if bestExposure < 0.15 {
            AppLogger.faceScan.warning("❌ Very dark image (exposure: \(String(format: "%.3f", bestExposure)))")
            // Defer @Published property update using asyncAfter to break out of view update cycle
            Task { @MainActor [weak self] in
                self?.qualityWarning = "Too dark - find better lighting"
            }
            return false
        }

        // Only warn for EXTREME overexposure (very bright/washed out)
        if bestExposure > 0.85 {
            AppLogger.faceScan.warning("❌ Overexposed image (exposure: \(String(format: "%.3f", bestExposure)))")
            // Defer @Published property update using asyncAfter to break out of view update cycle
            Task { @MainActor [weak self] in
                self?.qualityWarning = "Too bright - avoid direct light"
            }
            return false
        }

        // Removed the "deviation from ideal" check - too strict for real-world conditions
        return true
    }
    
    /// Check image sharpness (blur detection) - analyzes multiple regions and uses BEST result
    /// SIMPLIFIED: Only warn for VERY blurry images that would significantly affect scan quality
    private func checkSharpness(image: UIImage, lightEstimation: LightEstimation?) -> Bool {
        // Analyze center region for sharpness
        let bestSharpness = analyzeBestSharpness(image: image)

        // VERY LENIENT THRESHOLD - only catch obviously blurry images
        // Modern TrueDepth cameras auto-focus well, so we rarely need to warn
        let sharpnessThreshold: Float = 25.0  // Very low - only catch major blur

        if bestSharpness < sharpnessThreshold {
            // Only show warning for significantly blurry images
            AppLogger.faceScan.warning("❌ Image blur detected (sharpness: \(String(format: "%.1f", bestSharpness)))")
            // Defer @Published property update using asyncAfter to break out of view update cycle
            Task { @MainActor [weak self] in
                self?.qualityWarning = "Hold phone steady"
            }
            return false
        }

        // Clear blur-related warnings on success
        if qualityWarning?.contains("steady") == true || qualityWarning?.contains("blur") == true {
            // Defer @Published property update using asyncAfter to break out of view update cycle
            Task { @MainActor [weak self] in
                self?.qualityWarning = nil
            }
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
            guard let croppedCGImage = cgImage.cropping(to: region) else {
                continue
            }

            let croppedImage = UIImage(cgImage: croppedCGImage)
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
    @AppStorage(AppDefaultsKey.enableHapticFeedback) var isEnabled: Bool = true
    static let shared = HapticSettings()
}
