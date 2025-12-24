//
//  ScanStateManager.swift
//  Tavi
//
//  Manages scan state and progress tracking
//  Extracted from FaceScan3DViewModel for better maintainability
//

import Foundation
import Combine
import SwiftUI

/// Manages the state and progress of face scanning sessions
@MainActor
public class ScanStateManager: ObservableObject {

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

    /// Whether current pose matches target direction
    @Published public var isPoseCorrect: Bool = false

    /// Current capture sequence
    @Published public var currentSequence: CaptureSequence?

    // MARK: - Private Properties

    private var countdownToleranceFrames: Int = 0
    private let maxToleranceFrames = 3
    private var countdownTimerInstance: Timer?

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Starts the scanning guidance flow
    public func startGuidance() {
        isGuidanceActive = true
        currentGuidanceStep = .lookStraight
        capturedPoses.removeAll()
        guidanceFeedback = "Look straight at the camera"
    }

    /// Stops the scanning guidance
    public func stopGuidance() {
        isGuidanceActive = false
        stopCountdown()
        capturedPoses.removeAll()
        guidanceFeedback = nil
    }

    /// Moves to the next guidance step
    public func moveToNextStep() {
        guard let nextStep = currentGuidanceStep.next else {
            // Completed all steps
            completeGuidance()
            return
        }

        currentGuidanceStep = nextStep
        guidanceFeedback = guidanceFeedbackMessage(for: nextStep)
        isPoseCorrect = false
    }

    /// Marks current pose as captured
    public func capturePose(data: CapturedPoseData) {
        capturedPoses[currentGuidanceStep] = data

        // Provide haptic feedback
        HapticManager.shared.success()

        // Move to next step after brief delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            moveToNextStep()
        }
    }

    /// Starts countdown for pose capture
    public func startCountdown() {
        guard countdownTimer == 0 else { return }

        countdownTimer = 3
        countdownToleranceFrames = 0

        // Use Timer for countdown
        self.countdownTimerInstance = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }

            Task { @MainActor in
                self.countdownTimer -= 1

                if self.countdownTimer <= 0 {
                    timer.invalidate()
                    self.triggerCapture()
                }
            }
        }
    }

    /// Stops the countdown
    public func stopCountdown() {
        countdownTimerInstance?.invalidate()
        countdownTimerInstance = nil
        countdownTimer = 0
        countdownToleranceFrames = 0
    }

    /// Updates pose correctness based on validation
    public func updatePoseCorrectness(isCorrect: Bool) {
        if isPoseCorrect != isCorrect {
            isPoseCorrect = isCorrect

            if isCorrect {
                HapticManager.shared.light()
            }
        }

        // Handle countdown tolerance
        if countdownTimer > 0 {
            if isCorrect {
                countdownToleranceFrames = 0
            } else {
                countdownToleranceFrames += 1

                if countdownToleranceFrames > maxToleranceFrames {
                    stopCountdown()
                    guidanceFeedback = "Position lost. Please reposition."
                }
            }
        } else if isCorrect && !isCaptureInProgress {
            // Auto-start countdown when pose is correct
            startCountdown()
        }
    }

    /// Checks if all active poses have been captured
    public func isSequenceComplete() -> Bool {
        return capturedPoses.count == GuidanceStep.activePoses.count
    }

    /// Gets completion percentage
    public func completionPercentage() -> Double {
        let captured = Double(capturedPoses.count)
        let total = Double(GuidanceStep.activePoses.count)
        return (captured / total) * 100
    }

    // MARK: - Private Methods

    private func completeGuidance() {
        isGuidanceActive = false
        guidanceFeedback = "Scan complete! Processing..."

        // Notify completion
        NotificationCenter.default.post(name: .scanGuidanceCompleted, object: nil)
    }

    private func triggerCapture() {
        isCaptureInProgress = true

        // Notify for capture
        NotificationCenter.default.post(
            name: .capturePoseTriggered,
            object: nil,
            userInfo: ["step": currentGuidanceStep]
        )

        // Reset after brief delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            isCaptureInProgress = false
        }
    }

    private func guidanceFeedbackMessage(for step: GuidanceStep) -> String {
        switch step {
        case .lookStraight:
            return "Look straight at the camera"
        case .lookUp:
            return "Tilt your head up slightly"
        case .lookDown:
            return "Tilt your head down slightly"
        case .turnLeft:
            return "Turn your head to the left"
        case .turnRight:
            return "Turn your head to the right"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let scanGuidanceCompleted = Notification.Name("scanGuidanceCompleted")
    static let capturePoseTriggered = Notification.Name("capturePoseTriggered")
}
