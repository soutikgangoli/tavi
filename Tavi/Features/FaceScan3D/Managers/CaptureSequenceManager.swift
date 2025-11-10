//
//  CaptureSequenceManager.swift
//  Tavi
//
//  Handles capture sequence management, pose guidance, and countdown logic
//  Extracted from FaceScan3DViewModel to improve maintainability
//

import Foundation
import ARKit
import SwiftUI
import Combine

/// Manages capture sequences, guidance steps, and pose validation
@MainActor
public class CaptureSequenceManager: ObservableObject {
    // MARK: - Published Properties

    /// Current guidance step
    @Published public var currentGuidanceStep: GuidanceStep = .lookStraight

    /// Whether guidance mode is active
    @Published public var isGuidanceActive: Bool = false

    /// Captured poses for each step
    @Published public var capturedPoses: [GuidanceStep: CapturedPoseData] = [:]

    /// Countdown timer (0 = not counting)
    @Published public var countdownTimer: Int = 0

    /// Whether capture is in progress
    @Published public var isCaptureInProgress: Bool = false

    /// Real-time guidance feedback for current pose
    @Published public var guidanceFeedback: String?

    /// Current capture sequence
    @Published public var currentSequence: CaptureSequence?

    /// Flag indicating capture should be triggered (countdown completed)
    @Published public var shouldTriggerCapture: Bool = false

    /// Current face angles for debug display (in degrees)
    @Published public var currentYaw: Float = 0
    @Published public var currentPitch: Float = 0
    @Published public var currentRoll: Float = 0

    // MARK: - Private Properties

    private var holdStableTimer: Timer?
    private var countdownToleranceFrames: Int = 0
    private let textureCapture = TextureCapture()
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    // MARK: - Initialization

    public init() {
        hapticFeedback.prepare()
    }

    deinit {
        holdStableTimer?.invalidate()
        holdStableTimer = nil
    }

    // MARK: - Public Methods

    /// Start a new capture sequence
    public func startCaptureSequence() {
        AppLogger.faceScan.info("📋 Starting new capture sequence")

        // Always initialize sequence first
        self.currentSequence = CaptureSequence()

        // Start guidance
        self.isGuidanceActive = true
        self.currentGuidanceStep = .lookStraight
        self.capturedPoses = [:]
        self.countdownTimer = 0
        self.guidanceFeedback = nil

        AppLogger.faceScan.info("✅ Sequence initialized")
    }

    /// Stop guidance mode
    public func stopGuidance() {
        self.isGuidanceActive = false
        self.capturedPoses = [:]
        self.countdownTimer = 0
        self.guidanceFeedback = nil
        self.shouldTriggerCapture = false
        self.holdStableTimer?.invalidate()
        self.holdStableTimer = nil
    }

    /// Reset sequence
    public func resetSequence() {
        self.currentSequence = nil
        self.shouldTriggerCapture = false
        stopGuidance()
        AppLogger.faceScan.info("✅ Sequence reset")
    }

    /// Check guidance pose and initiate capture countdown if valid
    public func checkGuidancePoseAndCapture(
        faceAnchor: ARFaceAnchor,
        frame: ARFrame,
        isPoseCorrect: inout Bool,
        isCalibrated: Bool,
        qualityGood: Bool,
        frameCount: Int
    ) -> String? {
        // Skip if already captured this step
        if self.capturedPoses[self.currentGuidanceStep] != nil {
            return nil
        }

        // Extract rotation angles
        // CRITICAL: Use camera-relative angles for accurate pose validation
        let eulerAngles = faceAnchor.eulerAnglesRelativeToCamera()
        let yaw = eulerAngles.y * 180 / .pi
        let pitch = eulerAngles.x * 180 / .pi
        let roll = eulerAngles.z * 180 / .pi

        // Store current angles for debug display
        self.currentYaw = yaw
        self.currentPitch = pitch
        self.currentRoll = roll

        // Check if pose matches current step
        let isPoseValid = self.currentGuidanceStep.isPoseValid(yaw: yaw, pitch: pitch, roll: roll)

        // Update pose correctness
        let wasPoseCorrect = isPoseCorrect
        isPoseCorrect = isPoseValid

        // Get real-time guidance feedback
        var feedback = self.currentGuidanceStep.getGuidanceFeedback(yaw: yaw, pitch: pitch, roll: roll)
        
        // ENHANCED: If pose is valid but quality is poor (blur/sharpness), prioritize quality guidance
        // This helps users understand why countdown isn't starting even when pose looks correct
        // Quality warnings are more important when pose is already correct
        if isPoseValid && feedback == nil {
            // Pose is correct - no pose feedback needed
            // Quality warnings will be shown via qualityWarning in the UI
            feedback = nil
        } else if !isPoseValid {
            // Pose needs adjustment - show pose guidance
            // Quality warnings are secondary when pose is wrong
        }
        
        self.guidanceFeedback = feedback

        // HAPTIC FEEDBACK: Provide haptic when positioning becomes correct
        if isPoseValid && !wasPoseCorrect && isCalibrated && qualityGood {
            if HapticSettings.shared.isEnabled {
                HapticManager.shared.success()
            }
        }

        // OPTIMIZATION: Debug logging only in debug builds to reduce overhead
        #if DEBUG
        // Debug logging - shows angles and feedback EVERY 10 frames for troubleshooting
        if frameCount % 10 == 0 {
            let feedbackStr = feedback ?? "✓ Good"
            AppLogger.faceScan.info("""
                📐 Pose check - Step: \(self.currentGuidanceStep.shortName)
                  Yaw: \(String(format: "%.1f", yaw))° (+ = left, - = right) | Valid: ±20°
                  Pitch: \(String(format: "%.1f", pitch))° (+ = up, - = down) | Valid: -12° to +20°
                  Roll: \(String(format: "%.1f", roll))° (+ = tilt left, - = tilt right) | Valid: ±20°
                  Result: \(isPoseValid ? "✅ VALID" : "❌ INVALID")
                  Feedback: "\(feedbackStr)"
                """)
        }

        // Start countdown if conditions are met
        // Log condition check every 30 frames to avoid spam but still be visible
        if frameCount % 30 == 0 {
            print("🔍 COUNTDOWN CHECK [Frame \(frameCount)]: isPoseValid=\(isPoseValid), isCalibrated=\(isCalibrated), qualityGood=\(qualityGood), isCaptureInProgress=\(self.isCaptureInProgress), countdownTimer=\(self.countdownTimer), holdStableTimer=\(self.holdStableTimer != nil ? "exists" : "nil")")
        }
        #endif

        // PERFORMANCE: Reset any stuck timers if conditions are good
        if isPoseValid && isCalibrated && qualityGood && !self.isCaptureInProgress {
            // If timer exists but countdown is 0, something is stuck - reset it
            if self.holdStableTimer != nil && self.countdownTimer == 0 {
                #if DEBUG
                AppLogger.faceScan.warning("⚠️ Resetting stuck countdown timer")
                #endif
                self.holdStableTimer?.invalidate()
                self.holdStableTimer = nil
            }

            if self.countdownTimer == 0 && self.holdStableTimer == nil {
                #if DEBUG
                print("✅✅✅ ALL CONDITIONS MET - STARTING COUNTDOWN!")
                #endif
                AppLogger.faceScan.info("✅ All conditions met - starting countdown")
                startCaptureCountdown(faceAnchor: faceAnchor, yaw: yaw, pitch: pitch, roll: roll)
            } else {
                #if DEBUG
                if frameCount % 30 == 0 {
                    print("⚠️ Countdown blocked: countdownTimer=\(self.countdownTimer), holdStableTimer=\(self.holdStableTimer != nil ? "exists" : "nil")")
                }
                #endif
            }
            self.countdownToleranceFrames = 0
        } else {
            // OPTIMIZATION: Debug logging only in debug builds
            #if DEBUG
            // DEBUG: Log why countdown isn't starting (throttled to every 30 frames)
            if frameCount % 30 == 0 {
                var reasons: [String] = []
                if !isPoseValid { reasons.append("pose invalid (yaw=\(String(format: "%.1f", yaw))°, pitch=\(String(format: "%.1f", pitch))°, roll=\(String(format: "%.1f", roll))°)") }
                if !isCalibrated { reasons.append("not calibrated") }
                if !qualityGood { reasons.append("quality poor") }
                if self.isCaptureInProgress { reasons.append("capture in progress") }
                if self.countdownTimer > 0 { reasons.append("countdown already running") }
                if self.holdStableTimer != nil { reasons.append("timer exists") }

                print("⏸️ COUNTDOWN NOT STARTING: \(reasons.joined(separator: ", "))")
                AppLogger.faceScan.warning("⏸️ Countdown NOT starting: \(reasons.joined(separator: ", "))")
            }
            #endif

            // Handle countdown cancellation with tolerance
            // IMPORTANT: Cancel countdown if EITHER pose is invalid OR quality is bad
            let shouldCancelCountdown = !isPoseValid || !qualityGood
            handleCountdownTolerance(shouldCancel: shouldCancelCountdown, isPoseValid: isPoseValid, qualityGood: qualityGood)
        }

        return feedback
    }

    /// Capture current frame mesh
    public func captureStep(
        geometry: FaceMeshGeometry,
        lightEstimation: LightEstimation
    ) -> Bool {
        guard self.currentSequence != nil else {
            AppLogger.faceScan.error("❌ captureStep failed: No sequence")
            return false
        }

        // Extract rotation angles
        let transform = geometry.transform
        let yaw = transform.eulerAngles.y * 180 / .pi
        let pitch = transform.eulerAngles.x * 180 / .pi
        let roll = transform.eulerAngles.z * 180 / .pi

        // Create capture
        let capture = MeshCapture(
            step: self.currentGuidanceStep,
            geometry: geometry,
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            lightEstimation: lightEstimation
        )

        self.currentSequence!.addCapture(capture)

        let captureCount = self.currentSequence!.captures.count
        AppLogger.faceScan.info("✅ Added capture to sequence. Total: \(captureCount)")

        return true
    }

    /// Capture texture sample from current frame
    public func captureTextureSample(
        faceAnchor: ARFaceAnchor,
        frame: ARFrame,
        lightEstimation: LightEstimation?
    ) {
        guard self.currentSequence != nil else {
            return
        }

        if let sample = self.textureCapture.captureSample(
            step: self.currentGuidanceStep.shortName,
            faceAnchor: faceAnchor,
            frame: frame,
            lightEstimation: lightEstimation
        ) {
            self.currentSequence!.addTextureSample(sample)
            #if DEBUG
            AppLogger.faceScan.info("✅ Added texture sample (sharpness: \(sample.focusSharpness), exposure: \(sample.exposureScore)). Total: \(self.currentSequence!.textureSamples.count)")
            #endif
        } else {
            // Texture capture failed quality checks (blur or exposure)
            // FALLBACK: Accept the sample anyway with lower quality flag to prevent bake failure
            let fallbackSample = self.textureCapture.captureSampleWithLoweredThreshold(
                step: self.currentGuidanceStep.shortName,
                faceAnchor: faceAnchor,
                frame: frame,
                lightEstimation: lightEstimation
            )

            if let fallbackSample = fallbackSample {
                self.currentSequence!.addTextureSample(fallbackSample)
                #if DEBUG
                AppLogger.faceScan.warning("⚠️ Texture sample accepted with lowered threshold (sharpness: \(fallbackSample.focusSharpness), exposure: \(fallbackSample.exposureScore)). Total: \(self.currentSequence!.textureSamples.count)")
                #endif
            } else {
                #if DEBUG
                AppLogger.faceScan.error("❌ CRITICAL: Failed to capture texture sample even with lowered threshold for step '\(self.currentGuidanceStep.shortName)'")
                #endif
            }
        }
    }

    /// Capture pose with multi-frame support
    public func capturePose(
        faceAnchor: ARFaceAnchor,
        frame: ARFrame,
        geometry: FaceMeshGeometry,
        lightEstimation: LightEstimation,
        yaw: Float,
        pitch: Float,
        roll: Float
    ) {
        AppLogger.faceScan.info("🎯 Capturing pose: \(self.currentGuidanceStep.shortName)")

        self.isCaptureInProgress = true

        // Create captured pose data
        let poseData = CapturedPoseData(
            step: self.currentGuidanceStep,
            geometry: geometry,
            yaw: yaw,
            pitch: pitch,
            roll: roll
        )

        self.capturedPoses[self.currentGuidanceStep] = poseData

        // Capture multiple frames for better quality
        // Dynamically select frames based on High Quality Mode setting
        // Recommended (OFF): 3 frames (83-85% confidence)
        // Best Case (ON): 5 frames (90-92% confidence)
        let enableHighRes = UserDefaults.standard.bool(forKey: "enableHighResCapture")
        let framesToCapture = enableHighRes ? ScanConfiguration.framesPerPoseBest : ScanConfiguration.framesPerPoseRecommended
        var captureSuccess = 0
        for _ in 0..<framesToCapture {
            let success = captureStep(geometry: geometry, lightEstimation: lightEstimation)
            if success {
                captureSuccess += 1
            }
        }

        if captureSuccess > 0 {
            // Capture texture sample
            captureTextureSample(faceAnchor: faceAnchor, frame: frame, lightEstimation: lightEstimation)
            AppLogger.faceScan.info("📸 Captured \(captureSuccess)/\(framesToCapture) frames")
        }

        // Move to next step or finish
        let currentStep = self.currentGuidanceStep
        if let nextStepIndex = GuidanceStep.allCases.firstIndex(of: currentStep).map({ $0 + 1 }),
           nextStepIndex < GuidanceStep.allCases.count {
            // Move to next step
            DispatchQueue.main.asyncAfter(deadline: .now() + ScanConfiguration.resultsDisplayDelay) { [weak self] in
                self?.currentGuidanceStep = GuidanceStep.allCases[nextStepIndex]
                self?.isCaptureInProgress = false
                self?.guidanceFeedback = nil
                AppLogger.faceScan.info("➡️ Moved to next step: \(GuidanceStep.allCases[nextStepIndex].shortName)")
            }
        } else {
            // All steps captured - keep guidance active until View calls finalizeCapture()
            AppLogger.faceScan.info("✅ All \(GuidanceStep.allCases.count) poses captured! Waiting for View to call finalizeCapture()")
            self.isCaptureInProgress = false
            self.guidanceFeedback = "All poses captured!"
        }
    }

    /// Complete the sequence
    public func completeSequence() {
        self.currentSequence?.complete()
        self.isGuidanceActive = false
        AppLogger.faceScan.info("✅ Sequence complete")
    }

    // MARK: - Private Methods

    private func startCaptureCountdown(faceAnchor: ARFaceAnchor, yaw: Float, pitch: Float, roll: Float) {
        AppLogger.faceScan.info("Starting capture countdown from 3")
        self.countdownTimer = 3

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                // Check if countdown was cancelled externally
                if self.holdStableTimer == nil {
                    timer.invalidate()
                    return
                }

                // Verify face anchor still exists
                // Note: In production, we'd validate pose hasn't changed

                if self.countdownTimer > 1 {
                    self.countdownTimer -= 1
                    self.guidanceFeedback = "Hold still! \(self.countdownTimer)..."
                } else if self.countdownTimer == 1 {
                    // Countdown reached 1 - trigger capture on next tick (when it reaches 0)
                    self.countdownTimer = 0
                    timer.invalidate()
                    self.holdStableTimer = nil

                    // Haptic feedback
                    if HapticSettings.shared.isEnabled {
                        HapticManager.shared.medium()
                    }

                    AppLogger.faceScan.info("📸 Countdown complete - ready to capture!")
                    self.guidanceFeedback = "Capturing..."

                    // Set flag to trigger capture
                    self.shouldTriggerCapture = true
                }
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        self.holdStableTimer = timer
    }

    private func handleCountdownTolerance(shouldCancel: Bool, isPoseValid: Bool, qualityGood: Bool) {
        if self.holdStableTimer != nil {
            if shouldCancel {
                self.countdownToleranceFrames += 1

                if self.countdownToleranceFrames < ScanConfiguration.countdownToleranceFrames {
                    // Still within tolerance
                    return
                }

                // Exceeded tolerance - cancel countdown
                let reason = !isPoseValid ? "pose changed" : "quality degraded"
                AppLogger.faceScan.warning("🚫 Countdown cancelled - \(reason)")
                self.holdStableTimer?.invalidate()
                self.holdStableTimer = nil
                self.countdownTimer = 0
                self.countdownToleranceFrames = 0
                self.guidanceFeedback = nil
            } else {
                // Pose and quality both valid again - reset tolerance
                self.countdownToleranceFrames = 0
            }
        }
    }

    // MARK: - Multi-Frame Capture Callbacks

    /// Called when multi-frame capture starts
    public func onMultiFrameCaptureStarted() {
        AppLogger.faceScan.info("📸 Multi-frame capture started")
        isCaptureInProgress = true
    }

    /// Called when a frame is captured during multi-frame capture
    public func onFrameCaptured(frameCount: Int, targetCount: Int, confidence: Float) {
        AppLogger.faceScan.debug("📷 Frame captured: \(frameCount)/\(targetCount) (confidence: \(String(format: "%.2f", confidence)))")
    }

    /// Called when multi-frame capture reaches target frame count
    public func onMultiFrameCaptureReachedTarget() {
        AppLogger.faceScan.info("✓ Multi-frame capture reached target")
    }

    /// Called when multi-frame capture completes
    public func onMultiFrameCaptureCompleted(frameCount: Int) {
        AppLogger.faceScan.info("✅ Multi-frame capture completed with \(frameCount) frames")
        isCaptureInProgress = false
    }
}
