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
        self.holdStableTimer?.invalidate()
        self.holdStableTimer = nil
    }

    /// Reset sequence
    public func resetSequence() {
        self.currentSequence = nil
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
        let yaw = faceAnchor.transform.eulerAngles.y * 180 / .pi
        let pitch = faceAnchor.transform.eulerAngles.x * 180 / .pi
        let roll = faceAnchor.transform.eulerAngles.z * 180 / .pi

        // Check if pose matches current step
        let isPoseValid = self.currentGuidanceStep.isPoseValid(yaw: yaw, pitch: pitch, roll: roll)

        // Update pose correctness
        let wasPoseCorrect = isPoseCorrect
        isPoseCorrect = isPoseValid

        // Get real-time guidance feedback
        let feedback = self.currentGuidanceStep.getGuidanceFeedback(yaw: yaw, pitch: pitch, roll: roll)
        self.guidanceFeedback = feedback

        // HAPTIC FEEDBACK: Provide haptic when positioning becomes correct
        if isPoseValid && !wasPoseCorrect && isCalibrated && qualityGood {
            if HapticSettings.shared.isEnabled {
                HapticManager.shared.success()
            }
        }

        // Debug logging
        if frameCount % 30 == 0 {
            let _ = abs(faceAnchor.transform.columns.3.z)  // Distance - calculated for potential debugging
            AppLogger.faceScan.debug("Pose check - Step: \(self.currentGuidanceStep.shortName), Yaw: \(String(format: "%.1f", yaw))°, Valid: \(isPoseValid)")
        }

        // Start countdown if conditions are met
        if isPoseValid && isCalibrated && qualityGood && !self.isCaptureInProgress {
            if self.countdownTimer == 0 && self.holdStableTimer == nil {
                startCaptureCountdown(faceAnchor: faceAnchor, yaw: yaw, pitch: pitch, roll: roll)
            }
            self.countdownToleranceFrames = 0
        } else {
            // Handle countdown cancellation with tolerance
            handleCountdownTolerance(isPoseValid: isPoseValid)
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
            AppLogger.faceScan.info("✅ Added texture sample. Total: \(self.currentSequence!.textureSamples.count)")
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
        var captureSuccess = 0
        for _ in 0..<3 {
            let success = captureStep(geometry: geometry, lightEstimation: lightEstimation)
            if success {
                captureSuccess += 1
            }
        }

        if captureSuccess > 0 {
            // Capture texture sample
            captureTextureSample(faceAnchor: faceAnchor, frame: frame, lightEstimation: lightEstimation)
            AppLogger.faceScan.info("📸 Captured \(captureSuccess)/3 frames")
        }

        // TESTING MODE: Complete after first capture
        AppLogger.faceScan.info("🧪 TESTING MODE: Completing scan after first capture")

        DispatchQueue.main.asyncAfter(deadline: .now() + ScanConfiguration.calibrationRetryDelay) { [weak self] in
            self?.isCaptureInProgress = false
            self?.guidanceFeedback = "Testing mode - scan complete!"
        }

        // Production code (7-pose workflow) commented out:
        /*
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
            AppLogger.faceScan.info("✅ All 7 poses captured! Waiting for View to call finalizeCapture()")
            self.isCaptureInProgress = false
            self.guidanceFeedback = "All poses captured!"
        }
        */
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
                } else {
                    // Capture!
                    AppLogger.faceScan.info("📸 Countdown complete - CAPTURING!")
                    timer.invalidate()
                    self.holdStableTimer = nil
                    self.countdownTimer = 0

                    // Haptic feedback
                    if HapticSettings.shared.isEnabled {
                        HapticManager.shared.medium()
                    }

                    // Trigger capture (will be called by ViewModel with current data)
                }
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        self.holdStableTimer = timer
    }

    private func handleCountdownTolerance(isPoseValid: Bool) {
        if self.holdStableTimer != nil {
            if !isPoseValid {
                self.countdownToleranceFrames += 1

                if self.countdownToleranceFrames < ScanConfiguration.countdownToleranceFrames {
                    // Still within tolerance
                    return
                }

                // Exceeded tolerance - cancel countdown
                AppLogger.faceScan.warning("🚫 Countdown cancelled - pose changed")
                self.holdStableTimer?.invalidate()
                self.holdStableTimer = nil
                self.countdownTimer = 0
                self.countdownToleranceFrames = 0
                self.guidanceFeedback = nil
            } else {
                // Pose valid again - reset tolerance
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
