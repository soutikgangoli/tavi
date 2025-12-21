//
//  CalibrationOverlay.swift
//  Tavi
//
//  Calibration and guidance overlay for 3D face scanning
//  Created on 2025-10-27.
//

import SwiftUI

/// Calibration overlay showing lighting, distance, and guidance
public struct CalibrationOverlay: View {
    @ObservedObject var viewModel: FaceScan3DViewModel
    @AppStorage(AppDefaultsKey.debugModeEnabled) private var debugModeEnabled: Bool = false

    public var body: some View {
        ZStack {
            // Pre-calibration indicators
            // SWIFTUI REACTIVITY FIX: Pass calibrationManager (ObservableObject) not struct
            // This ensures SwiftUI observes changes through the objectWillChange chain
            if !viewModel.calibrationManager.calibrationState.isCalibrated && !viewModel.isGuidanceActive {
                CalibrationStatusView(calibrationManager: viewModel.calibrationManager)
            }

            // Guidance mode
            if viewModel.isGuidanceActive {
                GuidanceView(
                    currentStep: viewModel.currentGuidanceStep,
                    capturedPoses: viewModel.capturedPoses,
                    countdownTimer: viewModel.countdownTimer,
                    calibrationManager: viewModel.calibrationManager,
                    guidanceFeedback: viewModel.guidanceFeedback
                )
            }

            // Start guidance button (when calibrated)
            if viewModel.calibrationManager.calibrationState.isCalibrated && !viewModel.isGuidanceActive {
                VStack(spacing: 16) {
                    Spacer()

                    // CRITICAL: Block button if lighting quality is poor
                    let lightingIsGood = viewModel.calibrationManager.calibrationState.hasGoodLightingQuality

                    Button {
                        viewModel.startGuidance()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Start Scanning")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(lightingIsGood ? Color(red: 0.2, green: 0.85, blue: 0.5) : Color.gray.opacity(0.5))
                        )
                        .shadow(color: lightingIsGood ? Color(red: 0.2, green: 0.85, blue: 0.5).opacity(0.4) : .clear, radius: 12, y: 4)
                    }
                    .disabled(!lightingIsGood)
                    .opacity(lightingIsGood ? 1.0 : 0.6)

                    // Show specific lighting issue if blocking
                    if !lightingIsGood {
                        Text(viewModel.calibrationManager.calibrationState.lightingIssueMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                            )
                    }

                    Spacer()
                        .frame(height: 60)
                }
            }

            // Completion message
            // Show completion message when all required poses have been captured
            if !viewModel.isGuidanceActive && viewModel.capturedPoses.count == GuidanceStep.activePoses.count {
                VStack {
                    Spacer()

                    VStack(spacing: 16) {
                        // Success checkmark with glow
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.2, green: 0.85, blue: 0.5).opacity(0.2))
                                .frame(width: 80, height: 80)

                            Circle()
                                .stroke(Color(red: 0.2, green: 0.85, blue: 0.5), lineWidth: 3)
                                .frame(width: 70, height: 70)

                            Image(systemName: "checkmark")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.5))
                        }

                        Text("Scan Complete!")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Captured \(viewModel.capturedPoses.count) poses successfully")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))

                        Button {
                            viewModel.resetCalibration()
                        } label: {
                            Text("Scan Again")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.2))
                                )
                        }
                        .padding(.top, 8)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding()

                    Spacer()
                }
            }

            // Debug info overlay - shows detailed scan information when debug mode is enabled
            if debugModeEnabled {
                VStack {
                    Spacer()
                    CalibrationDebugInfoView(viewModel: viewModel)
                }
            }
        }
    }
}

// MARK: - Calibration Status View

struct CalibrationStatusView: View {
    @ObservedObject var calibrationManager: CalibrationManager

    // Convenience accessor for the state
    private var calibrationState: CalibrationState {
        calibrationManager.calibrationState
    }

    /// Get color for center position status
    private func centerStatusColor(_ position: CenterPosition) -> Color {
        switch position {
        case .center:
            return Color(red: 0.2, green: 0.85, blue: 0.5)
        case .slightlyLeft, .slightlyRight:
            return Color(red: 1.0, green: 0.8, blue: 0.2)
        case .farLeft, .farRight:
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        }
    }

    var body: some View {
        VStack {
            // Top indicators - cleaner horizontal layout
            HStack(spacing: 16) {
                // Direction indicator
                StatusBadge(
                    icon: "location.fill",
                    status: calibrationState.centerPosition == .center ? .good : (calibrationState.centerPosition == .slightlyLeft || calibrationState.centerPosition == .slightlyRight ? .warning : .error),
                    label: "Direction"
                )

                // Lighting indicator
                StatusBadge(
                    icon: "sun.max.fill",
                    status: calibrationState.lighting.isValid ? .good : (calibrationState.lighting == .tooDark ? .warning : .error),
                    label: "Light"
                )

                // Distance indicator
                StatusBadge(
                    icon: "ruler.fill",
                    status: calibrationState.distance.isValid ? .good : .warning,
                    label: "Distance"
                )

                // Stability + Focus indicator
                StatusBadge(
                    icon: "hand.raised.fill",
                    status: {
                        let isStable = calibrationState.stability.isValid
                        let isSharp: Bool
                        if let warning = calibrationManager.qualityWarning {
                            isSharp = !warning.contains("blur") && !warning.contains("steady") && !warning.contains("focus")
                        } else {
                            isSharp = true
                        }

                        if isStable && isSharp {
                            return .good
                        } else if isStable || isSharp {
                            return .warning
                        } else {
                            return .error
                        }
                    }(),
                    label: "Stable"
                )
            }
            .padding(.top, 70)
            .padding(.horizontal)

            // Simple position indicator - only show during calibration when not centered
            if calibrationState.centerPosition != .center {
                HStack(spacing: 8) {
                    Image(systemName: calibrationState.centerPosition == .slightlyLeft || calibrationState.centerPosition == .farLeft ? "arrow.left" : "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                    Text(calibrationState.centerPosition.displayText)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.white.opacity(0.2))
                )
                .padding(.top, 12)
            }

            Spacer()

            // Bottom instruction card - clean modern design
            VStack(spacing: 12) {
                if let message = calibrationState.primaryMessage {
                    Text(message)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }

                // Show helpful hint based on current state
                Text(getHelpfulHint())
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.bottom, 100)
        }
    }

    private func getHelpfulHint() -> String {
        if !calibrationState.lighting.isValid {
            return "Move to a well-lit area for best results"
        } else if !calibrationState.distance.isValid {
            return "Hold your phone about arm's length away"
        } else if !calibrationState.stability.isValid {
            return "Hold your phone steady"
        } else if calibrationState.centerPosition != .center {
            return "Turn your head to face the camera directly"
        }
        return "Looking good! Hold still..."
    }
}

// MARK: - Guidance View

struct GuidanceView: View {
    let currentStep: GuidanceStep
    let capturedPoses: [GuidanceStep: CapturedPoseData]
    let countdownTimer: Int
    @ObservedObject var calibrationManager: CalibrationManager
    let guidanceFeedback: String?

    // Convenience accessors from calibrationManager
    private var calibrationState: CalibrationState {
        calibrationManager.calibrationState
    }
    private var qualityWarning: String? {
        calibrationManager.qualityWarning
    }
    private var isPoseCorrect: Bool {
        calibrationManager.isPoseCorrect
    }

    // Modern color palette
    private let successColor = Color(red: 0.2, green: 0.85, blue: 0.5)
    private let warningColor = Color(red: 1.0, green: 0.8, blue: 0.2)
    private let hintColor = Color.white.opacity(0.7)

    var body: some View {
        VStack {
            // Calibration status badges - modern design
            HStack(spacing: 16) {
                StatusBadge(
                    icon: "location.fill",
                    status: isPoseCorrect ? .good : (guidanceFeedback != nil ? .warning : .error),
                    label: "Direction"
                )

                StatusBadge(
                    icon: "sun.max.fill",
                    status: calibrationState.lighting.isValid ? .good : (calibrationState.lighting == .tooDark ? .warning : .error),
                    label: "Light"
                )

                StatusBadge(
                    icon: "ruler.fill",
                    status: calibrationState.distance.isValid ? .good : .warning,
                    label: "Distance"
                )

                StatusBadge(
                    icon: "hand.raised.fill",
                    status: {
                        let isStable = calibrationState.stability.isValid
                        let isSharp: Bool
                        if let warning = qualityWarning {
                            isSharp = !warning.contains("blur") && !warning.contains("steady") && !warning.contains("focus")
                        } else {
                            isSharp = true
                        }

                        if isStable && isSharp {
                            return .good
                        } else if isStable || isSharp {
                            return .warning
                        } else {
                            return .error
                        }
                    }(),
                    label: "Stable"
                )
            }
            .padding(.top, 20)
            .padding(.horizontal)

            // Modern step progress indicator
            HStack(spacing: 10) {
                ForEach(GuidanceStep.activePoses, id: \.rawValue) { step in
                    StepIndicator(
                        step: step,
                        isCurrent: step == currentStep,
                        isCaptured: capturedPoses[step] != nil
                    )
                }
            }
            .padding(.top, 12)
            .padding(.horizontal)

            Spacer()

            // Countdown timer - clean modern design
            ZStack {
                if countdownTimer > 0 {
                    ZStack {
                        // Glowing ring behind countdown
                        Circle()
                            .stroke(successColor.opacity(0.3), lineWidth: 4)
                            .frame(width: 100, height: 100)

                        Circle()
                            .fill(successColor.opacity(0.15))
                            .frame(width: 90, height: 90)

                        Text("\(countdownTimer)")
                            .font(.system(size: 56, weight: .light, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 120)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: countdownTimer)

            // Bottom instruction card - modern clean design
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    // Main instruction
                    Text(currentStep.instruction)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    // Contextual feedback - clean and non-intrusive
                    Text(getFeedbackMessage())
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(getFeedbackColor())
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(minHeight: 36)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .frame(maxWidth: 360)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.bottom, 120)
            }
            .animation(.easeInOut(duration: 0.2), value: guidanceFeedback)
            .animation(.easeInOut(duration: 0.2), value: qualityWarning)
        }
    }

    private func getFeedbackMessage() -> String {
        if !calibrationState.isCalibrated {
            if let message = calibrationState.primaryMessage {
                return message
            }
        } else if let warning = qualityWarning {
            if warning.contains("blur") || warning.contains("steady") || warning.contains("focus") {
                return "Hold phone very still, wait for focus"
            } else if warning.contains("exposure") || warning.contains("bright") || warning.contains("dark") {
                return "Adjust lighting for best results"
            }
            return warning
        } else if countdownTimer == 0 {
            if let feedback = guidanceFeedback {
                return feedback
            } else if !isPoseCorrect {
                return "Adjust to match the target direction"
            } else {
                return "Perfect! Hold this position..."
            }
        }
        return "Capturing..."
    }

    private func getFeedbackColor() -> Color {
        // Always use white for better visibility on camera background
        if isPoseCorrect && countdownTimer == 0 {
            return successColor
        }
        return .white
    }
}

// MARK: - Status Badge

enum BadgeStatus {
    case good
    case warning
    case error

    var color: Color {
        switch self {
        case .good:
            return Color(red: 0.2, green: 0.85, blue: 0.5) // Vibrant green
        case .warning:
            return Color(red: 1.0, green: 0.8, blue: 0.2) // Warm yellow
        case .error:
            return Color(red: 1.0, green: 0.4, blue: 0.4) // Soft red
        }
    }

    var backgroundColor: Color {
        switch self {
        case .good:
            return Color(red: 0.2, green: 0.85, blue: 0.5).opacity(0.2)
        case .warning:
            return Color(red: 1.0, green: 0.8, blue: 0.2).opacity(0.2)
        case .error:
            return Color(red: 1.0, green: 0.4, blue: 0.4).opacity(0.2)
        }
    }
}

struct StatusBadge: View {
    let icon: String
    let status: BadgeStatus
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            // Modern pill badge with glassmorphism
            ZStack {
                // Outer glow
                Circle()
                    .fill(status.color.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .blur(radius: 4)

                // Glass background
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 46, height: 46)

                // Colored ring
                Circle()
                    .stroke(status.color, lineWidth: 2.5)
                    .frame(width: 46, height: 46)

                // Icon
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(status.color)
            }

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let step: GuidanceStep
    let isCurrent: Bool
    let isCaptured: Bool

    private let completedColor = Color(red: 0.2, green: 0.85, blue: 0.5)
    private let activeColor = Color(red: 0.4, green: 0.7, blue: 1.0)

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background circle
                Circle()
                    .fill(isCaptured ? completedColor.opacity(0.2) : (isCurrent ? activeColor.opacity(0.2) : Color.white.opacity(0.1)))
                    .frame(width: 28, height: 28)

                // Colored ring for current/captured
                if isCurrent || isCaptured {
                    Circle()
                        .stroke(isCaptured ? completedColor : activeColor, lineWidth: 2)
                        .frame(width: 28, height: 28)
                }

                // Inner content
                if isCaptured {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(completedColor)
                } else if isCurrent {
                    Circle()
                        .fill(activeColor)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }

            Text(step.shortName)
                .font(.system(size: 10, weight: isCurrent ? .semibold : .medium))
                .foregroundStyle(isCurrent || isCaptured ? .white : .white.opacity(0.7))
        }
    }
}

// MARK: - Calibration Debug Info View

struct CalibrationDebugInfoView: View {
    @ObservedObject var viewModel: FaceScan3DViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEBUG MODE")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.yellow)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calibration")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(Designs.Opacity.semiTransparent))
                    Text("✓ Calibrated: \(viewModel.calibrationManager.calibrationState.isCalibrated ? "Yes" : "No")")
                        .font(.caption2)
                        .foregroundStyle(viewModel.calibrationManager.calibrationState.isCalibrated ? .green : .red)
                    Text("✓ Pose Valid: \(viewModel.calibrationManager.isPoseCorrect ? "Yes" : "No")")
                        .font(.caption2)
                        .foregroundStyle(viewModel.calibrationManager.isPoseCorrect ? .green : .red)
                }

                Divider()
                    .frame(height: 60)
                    .background(.white.opacity(Designs.Opacity.medium))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Face Angles")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(Designs.Opacity.semiTransparent))
                    Text("Yaw: \(String(format: "%.1f", viewModel.currentYaw))°")
                        .font(.caption2)
                        .foregroundStyle(abs(viewModel.currentYaw) < 20 ? .green : .orange)
                    Text("Pitch: \(String(format: "%.1f", viewModel.currentPitch))°")
                        .font(.caption2)
                        .foregroundStyle((viewModel.currentPitch > -12 && viewModel.currentPitch < 20) ? .green : .orange)
                    Text("Roll: \(String(format: "%.1f", viewModel.currentRoll))°")
                        .font(.caption2)
                        .foregroundStyle(abs(viewModel.currentRoll) < 20 ? .green : .orange)
                }

                Divider()
                    .frame(height: 60)
                    .background(.white.opacity(Designs.Opacity.medium))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Quality")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(Designs.Opacity.semiTransparent))
                    Text("Lighting: \(viewModel.calibrationManager.calibrationState.lighting.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(viewModel.calibrationManager.calibrationState.lighting.isValid ? .green : .orange)
                    Text("Distance: \(viewModel.calibrationManager.calibrationState.distance.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(viewModel.calibrationManager.calibrationState.distance.isValid ? .green : .orange)
                }
            }

            if let warning = viewModel.calibrationManager.qualityWarning {
                Divider()
                    .background(.white.opacity(Designs.Opacity.medium))
                Text("⚠️ Warning: \(warning)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if let feedback = viewModel.guidanceFeedback {
                Text("💡 Feedback: \(feedback)")
                    .font(.caption2)
                    .foregroundStyle(.cyan)
            }
        }
                .padding(Designs.Spacing.small)
        .background(.black.opacity(Designs.Opacity.semiTransparent))
        .cornerRadius(Designs.Radius.medium)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        CalibrationOverlay(viewModel: FaceScan3DViewModel())
    }
}
