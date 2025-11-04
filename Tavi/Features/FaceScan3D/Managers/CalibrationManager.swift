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

    // MARK: - Private Properties

    private var lastTransform: simd_float4x4?
    private var previousQualityWarning: String?
    private var baselineLighting: CGFloat?
    private var baselineColorTemperature: CGFloat?

    // Quality check throttling to prevent FPS drops
    private var qualityCheckFrameCounter: Int = 0
    private var lastQualityCheckResult: Bool = true

    // Reusable instances to avoid expensive allocations
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let edgeCaseDetector = EdgeCaseDetector()
    private let imageQualityAnalyzer = ImageQualityAnalyzer()

    // MARK: - Public Methods

    /// Update calibration state from ARKit data
    public func updateCalibration(faceAnchor: ARFaceAnchor, frame: ARFrame, lightEstimation: LightEstimation?) {
        // Update face detected
        calibrationState.faceDetected = true

        // Update lighting
        calibrationState.updateLighting(from: lightEstimation)

        // Update distance
        calibrationState.updateDistance(from: faceAnchor.transform)

        // Update stability
        if let lastTransform = lastTransform {
            let movement = calculateMovement(from: lastTransform, to: faceAnchor.transform)
            calibrationState.updateStability(movement: movement)
        }

        lastTransform = faceAnchor.transform
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
        if !checkLightingConsistency(lightEstimation: lightEstimation) {
            lastQualityCheckResult = false
            return false
        }

        // 2. Check for neutral expression
        if let blendShapes = blendShapes {
            if !checkNeutralExpression(blendShapes: blendShapes, currentStep: currentGuidanceStep) {
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
        if !checkExposure(image: image) {
            lastQualityCheckResult = false
            return false
        }

        // 4. Check for occlusions
        if calibrationState.faceDetected && !calibrationState.isCalibrated {
            AppLogger.faceScan.warning("❌ Quality check failed: Possible occlusion")
            qualityWarning = "Face partially covered - please remove hands/hair from face"
            lastQualityCheckResult = false
            return false
        }

        // All quality checks passed
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

    private func checkExposure(image: UIImage) -> Bool {
        let exposure = imageQualityAnalyzer.calculateExposure(image: image)

        if exposure < ScanConfiguration.underexposureThreshold {
            AppLogger.faceScan.warning("❌ Quality check failed: Underexposed")
            qualityWarning = "Too dark - move to better lighting"
            return false
        }

        if exposure > ScanConfiguration.overexposureThreshold {
            AppLogger.faceScan.warning("❌ Quality check failed: Overexposed")
            qualityWarning = "Too bright - reduce lighting or move away from bright light"
            return false
        }

        let exposureDeviation = abs(exposure - ScanConfiguration.idealExposure)
        if exposureDeviation > ScanConfiguration.maxExposureDeviation {
            AppLogger.faceScan.warning("❌ Quality check failed: Poor exposure")
            qualityWarning = "Adjust lighting for better exposure"
            return false
        }

        return true
    }
}

// MARK: - Haptic Settings (moved from ViewModel)

/// Shared settings for haptic feedback
@MainActor
public class HapticSettings: ObservableObject {
    @AppStorage("enableHapticFeedback") var isEnabled: Bool = true
    static let shared = HapticSettings()
}
