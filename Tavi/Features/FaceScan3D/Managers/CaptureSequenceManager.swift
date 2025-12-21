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

    /// Whether all captures (including async texture capture) are fully complete
    /// Used by processing pipeline to wait for capture to finish
    @Published public var isCaptureFullyComplete: Bool = false

    // MARK: - Private Properties

    private var holdStableTimer: Timer?
    private var countdownToleranceFrames: Int = 0
    private let textureCapture = TextureCapture()
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    /// Task for delayed step transition (cancellable)
    private var stepTransitionTask: Task<Void, Never>?

    /// Flag to prevent operations during cleanup
    private var isCleaningUp: Bool = false

    // MARK: - Initialization

    public init() {
        hapticFeedback.prepare()
    }

    deinit {
        holdStableTimer?.invalidate()
        holdStableTimer = nil
        stepTransitionTask?.cancel()
        stepTransitionTask = nil
    }

    // MARK: - Public Methods

    /// Start a new capture sequence
    public func startCaptureSequence() {
        AppLogger.faceScan.info("📋 Starting new capture sequence")

        // Reset cleanup flag when starting fresh
        self.isCleaningUp = false

        // Always initialize sequence first
        self.currentSequence = CaptureSequence()

        // Defer @Published property updates to avoid "Publishing changes from within view updates"
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Start guidance
            self.isGuidanceActive = true
            self.currentGuidanceStep = .lookStraight
            self.capturedPoses = [:]
            self.countdownTimer = 0
            self.guidanceFeedback = nil
            self.isCaptureFullyComplete = false
        }

        AppLogger.faceScan.info("✅ Sequence initialized")
    }

    /// Stop guidance mode
    public func stopGuidance() {
        // CRITICAL: Set cleanup flag FIRST to prevent any pending operations
        self.isCleaningUp = true
        self.shouldTriggerCapture = false

        // Invalidate timer and cancel tasks synchronously
        self.holdStableTimer?.invalidate()
        self.holdStableTimer = nil
        self.stepTransitionTask?.cancel()
        self.stepTransitionTask = nil

        // Defer @Published property updates to avoid "Publishing changes from within view updates"
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isGuidanceActive = false
            self.capturedPoses = [:]
            self.countdownTimer = 0
            self.guidanceFeedback = nil
            self.isCaptureFullyComplete = false
            self.isCaptureInProgress = false
        }
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

        // CRITICAL FIX: Defer @Published property updates to next run loop iteration
        // This prevents "Publishing changes from within view updates" warnings
        // Using DispatchQueue.main.async to truly defer (Task @MainActor may execute immediately)
        DispatchQueue.main.async { [weak self, feedback] in
            guard let self else { return }
            // Store current angles for debug display
            self.currentYaw = yaw
            self.currentPitch = pitch
            self.currentRoll = roll
            self.guidanceFeedback = feedback
        }

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
            AppLogger.faceScan.debug("🔍 COUNTDOWN CHECK [Frame \(frameCount)]: isPoseValid=\(isPoseValid), isCalibrated=\(isCalibrated), qualityGood=\(qualityGood), isCaptureInProgress=\(self.isCaptureInProgress), countdownTimer=\(self.countdownTimer), holdStableTimer=\(self.holdStableTimer != nil ? "exists" : "nil")")
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
                AppLogger.faceScan.debug("✅✅✅ ALL CONDITIONS MET - STARTING COUNTDOWN!")
                #endif
                AppLogger.faceScan.info("✅ All conditions met - starting countdown")
                startCaptureCountdown(faceAnchor: faceAnchor, yaw: yaw, pitch: pitch, roll: roll)
            } else {
                #if DEBUG
                if frameCount % 30 == 0 {
                    AppLogger.faceScan.debug("⚠️ Countdown blocked: countdownTimer=\(self.countdownTimer), holdStableTimer=\(self.holdStableTimer != nil ? "exists" : "nil")")
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
        guard let sequence = self.currentSequence else {
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

        sequence.addCapture(capture)

        let captureCount = sequence.captures.count
        AppLogger.faceScan.info("✅ Added capture to sequence. Total: \(captureCount)")

        return true
    }

    /// Capture texture sample from current frame
    public func captureTextureSample(
        faceAnchor: ARFaceAnchor,
        frame: ARFrame,
        lightEstimation: LightEstimation?
    ) {
        guard let sequence = self.currentSequence else {
            return
        }

        // OPTIMIZATION FIX: No fallback needed - trust pre-capture validation
        // If CalibrationManager validated quality before countdown, capture will succeed
        if let sample = self.textureCapture.captureSample(
            step: self.currentGuidanceStep.shortName,
            faceAnchor: faceAnchor,
            frame: frame,
            lightEstimation: lightEstimation
        ) {
            sequence.addTextureSample(sample)
            #if DEBUG
            AppLogger.faceScan.info("✅ Added texture sample (sharpness: \(sample.focusSharpness), exposure: \(sample.exposureScore)). Total: \(sequence.textureSamples.count)")
            #endif
        } else {
            #if DEBUG
            AppLogger.faceScan.error("❌ Failed to extract camera image for texture sample - step '\(self.currentGuidanceStep.shortName)'")
            #endif
        }
    }

    /// Capture pose with multi-frame support
    /// OPTIMIZATION: Captures pose data immediately for instant UI transition,
    /// then performs expensive image processing asynchronously
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

        // Create captured pose data
        let poseData = CapturedPoseData(
            step: self.currentGuidanceStep,
            geometry: geometry,
            yaw: yaw,
            pitch: pitch,
            roll: roll
        )

        // CRITICAL: Store step BEFORE updating capturedPoses
        // This is needed because updating capturedPoses triggers SwiftUI onChange
        // which may change state before we finish this method
        let capturedStep = self.currentGuidanceStep
        let activePoses = GuidanceStep.activePoses
        let isLastPose = activePoses.firstIndex(of: capturedStep).map { $0 + 1 >= activePoses.count } ?? true

        // Defer @Published property updates to avoid "Publishing changes from within view updates"
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isCaptureInProgress = true
            // Update capturedPoses - this triggers SwiftUI onChange and view transition
            self.capturedPoses[capturedStep] = poseData
            // For the last pose, immediately signal completion state
            // The View's onChange will pick this up and transition to processing screen
            if isLastPose {
                self.guidanceFeedback = "Processing..."
            }
        }

        if isLastPose {
            AppLogger.faceScan.info("✅ All \(activePoses.count) active pose(s) captured! UI transitioning immediately...")
        }

        // Capture frames SYNCHRONOUSLY (they're fast - just storing geometry)
        // Only texture capture is expensive and happens after
        let userEnabledHighQuality = UserDefaults.standard.object(forKey: AppDefaultsKey.enableHighResCapture) != nil
            && UserDefaults.standard.bool(forKey: AppDefaultsKey.enableHighResCapture)
        let framesToCapture = userEnabledHighQuality ? ScanConfiguration.framesPerPoseBest : ScanConfiguration.framesPerPoseRecommended
        var captureSuccess = 0
        for _ in 0..<framesToCapture {
            let success = captureStep(geometry: geometry, lightEstimation: lightEstimation)
            if success {
                captureSuccess += 1
            }
        }

        // Capture texture sample synchronously too (it uses the current frame)
        if captureSuccess > 0 {
            captureTextureSample(faceAnchor: faceAnchor, frame: frame, lightEstimation: lightEstimation)
            AppLogger.faceScan.info("📸 Captured \(captureSuccess)/\(framesToCapture) frames")
        }

        // Mark capture as complete for the last pose
        // CRITICAL: Keep isCaptureInProgress = true to prevent another countdown from starting
        // The view will transition, and cleanup will happen when the view disappears
        if isLastPose {
            // Don't set isCaptureInProgress = false here!
            // Keep it true to block any further capture attempts
            // Defer @Published property update to avoid "Publishing changes from within view updates"
            DispatchQueue.main.async { [weak self] in
                self?.isCaptureFullyComplete = true
            }
            AppLogger.faceScan.info("✅ All captures including textures complete - ready for processing")
        } else {
            // Handle step transition (only for non-last poses)
            if let currentIndex = activePoses.firstIndex(of: capturedStep),
               currentIndex + 1 < activePoses.count {
                let nextStep = activePoses[currentIndex + 1]

                // Cancel any pending transition task
                self.stepTransitionTask?.cancel()

                self.stepTransitionTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(ScanConfiguration.resultsDisplayDelay * 1_000_000_000))

                    guard !Task.isCancelled else { return }
                    guard let self = self, !self.isCleaningUp else { return }

                    self.currentGuidanceStep = nextStep
                    self.isCaptureInProgress = false
                    self.guidanceFeedback = nil
                    AppLogger.faceScan.info("➡️ Moved to next step: \(nextStep.shortName)")
                }
            }
        }
    }

    /// Wait for any pending async capture to complete
    /// Note: With synchronous capture, this is now a no-op but kept for API compatibility
    public func waitForCaptureCompletion() async {
        // Capture is now synchronous, so nothing to wait for
    }

    /// Complete the sequence
    public func completeSequence() {
        self.currentSequence?.complete()
        AppLogger.faceScan.info("✅ Sequence complete")

        // Defer @Published property updates to avoid "Publishing changes from within view updates"
        DispatchQueue.main.async { [weak self] in
            self?.isGuidanceActive = false
        }
    }

    // MARK: - Private Methods

    private func startCaptureCountdown(faceAnchor: ARFaceAnchor, yaw: Float, pitch: Float, roll: Float) {
        // OPTIMIZATION: 0.5 second countdown for snappy capture while allowing stabilization
        AppLogger.faceScan.info("Starting capture countdown (0.5s)")
        self.countdownTimer = 1

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] timer in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                // Check if cleanup is in progress or countdown was cancelled
                if self.isCleaningUp || self.holdStableTimer == nil {
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
                self.countdownToleranceFrames = 0

                // Defer @Published property updates to avoid "Publishing changes from within view updates"
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.countdownTimer = 0
                    self.guidanceFeedback = nil
                }
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
