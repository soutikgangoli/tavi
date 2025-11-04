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
    @AppStorage("debugModeEnabled") private var debugModeEnabled: Bool = false

    public var body: some View {
        ZStack {
            // Pre-calibration indicators
            if !viewModel.calibrationState.isCalibrated && !viewModel.isGuidanceActive {
                CalibrationStatusView(calibrationState: viewModel.calibrationState)
            }

            // Guidance mode
            if viewModel.isGuidanceActive {
                GuidanceView(
                    currentStep: viewModel.currentGuidanceStep,
                    capturedPoses: viewModel.capturedPoses,
                    countdownTimer: viewModel.countdownTimer,
                    calibrationState: viewModel.calibrationState,
                    guidanceFeedback: viewModel.guidanceFeedback,
                    qualityWarning: viewModel.qualityWarning,
                    isPoseCorrect: viewModel.isPoseCorrect
                )
            }

            // Start guidance button (when calibrated)
            if viewModel.calibrationState.isCalibrated && !viewModel.isGuidanceActive {
                VStack {
                    Spacer()

                    Button {
                        viewModel.startGuidance()
                    } label: {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Start Scanning")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(.blue)
                        .cornerRadius(12)
                    }
                    .padding(.bottom, 60)
                }
            }

            // Completion message
            // TESTING MODE: Show completion after 1 capture instead of all 7
            // TODO: Change back to == GuidanceStep.allCases.count for production
            if !viewModel.isGuidanceActive && viewModel.capturedPoses.count >= 1 && viewModel.capturedPoses.count > 0 {
                VStack {
                    Spacer()

                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)

                        Text("Scan Complete!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("Captured \(viewModel.capturedPoses.count) poses")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))

                        Button("Scan Again") {
                            viewModel.resetCalibration()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.2))
                        .cornerRadius(8)
                        .padding(.top, 8)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding()

                    Spacer()
                }
            }

            // Debug info overlay - shows detailed scan information (only in debug builds)
            #if DEBUG
            if debugModeEnabled {
                VStack {
                    Spacer()
                    CalibrationDebugInfoView(viewModel: viewModel)
                }
            }
            #endif
        }
    }
}

// MARK: - Calibration Status View

struct CalibrationStatusView: View {
    let calibrationState: CalibrationState

    var body: some View {
        VStack {
            // Top indicators
            HStack(spacing: 20) {
                // Lighting indicator
                StatusBadge(
                    icon: "sun.max.fill",
                    status: calibrationState.lighting.isValid ? .good : (calibrationState.lighting == .tooDark ? .warning : .error),
                    label: "Lighting"
                )

                // Distance indicator
                StatusBadge(
                    icon: "arrow.left.and.right",
                    status: calibrationState.distance.isValid ? .good : .warning,
                    label: "Distance"
                )

                // Stability indicator
                StatusBadge(
                    icon: "hand.raised.fill",
                    status: calibrationState.stability.isValid ? .good : .warning,
                    label: "Stability"
                )
            }
            .padding(.top, 60)
            .padding(.horizontal)

            Spacer()

            // Guidance message
            if let message = calibrationState.primaryMessage {
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding(.bottom, 120)
            }
        }
    }
}

// MARK: - Guidance View

struct GuidanceView: View {
    let currentStep: GuidanceStep
    let capturedPoses: [GuidanceStep: CapturedPoseData]
    let countdownTimer: Int
    let calibrationState: CalibrationState
    let guidanceFeedback: String?
    let qualityWarning: String?
    let isPoseCorrect: Bool

    var body: some View {
        VStack {
            // Calibration status badges - ALWAYS visible during guidance
            HStack(spacing: 16) {
                // Direction/Pose indicator - FIRST for visibility
                // Green = correct, Yellow = close (has feedback), Red = wrong
                StatusBadge(
                    icon: "arrow.triangle.turn.up.right.diamond.fill",
                    status: isPoseCorrect ? .good : (guidanceFeedback != nil ? .warning : .error),
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
                    icon: "arrow.left.and.right",
                    status: calibrationState.distance.isValid ? .good : .warning,
                    label: "Distance"
                )

                // Stability indicator
                StatusBadge(
                    icon: "hand.raised.fill",
                    status: calibrationState.stability.isValid ? .good : .warning,
                    label: "Stable"
                )
            }
            .padding(.top, 20)
            .padding(.horizontal)

            // Progress indicators
            HStack(spacing: 12) {
                ForEach(GuidanceStep.allCases, id: \.rawValue) { step in
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

            // Countdown timer - FIXED FRAME to prevent bouncing
            ZStack {
                // Always reserve space for countdown (prevents layout shifts)
                Text("0")
                    .font(.system(size: 100, weight: .bold, design: .rounded))
                    .foregroundStyle(.clear)

                if countdownTimer > 0 {
                    Text("\(countdownTimer)")
                        .font(.system(size: 100, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 8)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(height: 120)  // Fixed height

            // Bottom instruction box - COMPACT and positioned lower
            VStack {
                Spacer()

                VStack(spacing: 8) {
                    // Instruction title - SMALLER font
                    Text(currentStep.instruction)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    #if DEBUG
                    // DEBUG: Show why countdown not starting when everything appears green
                    if countdownTimer == 0 && isPoseCorrect && calibrationState.isCalibrated {
                        Text("⚠️ DEBUG: All conditions green but no countdown - check quality/busy state")
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }
                    #endif

                    // Warnings and feedback - FIXED HEIGHT container
                    ZStack {
                        // Reserve space for feedback to prevent layout shifts
                        Text("\n")
                            .font(.caption)
                            .opacity(0)

                        // Actual feedback content
                        Group {
                            if !calibrationState.isCalibrated {
                                // Calibration warnings (lighting, distance, stability)
                                // Show specific issue preventing countdown
                                if let message = calibrationState.primaryMessage {
                                    VStack(spacing: 2) {
                                        Text(message)
                                            .font(.caption)
                                            .foregroundStyle(.yellow)
                                            .multilineTextAlignment(.center)
                                        Text("(Countdown will start when ready)")
                                            .font(.caption2)
                                            .foregroundStyle(.yellow.opacity(0.8))
                                    }
                                }
                            } else if let warning = qualityWarning {
                                // Image quality warnings (blur, exposure)
                                Text(warning)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .multilineTextAlignment(.center)
                            } else if countdownTimer == 0 {
                                // Show real-time guidance feedback when not counting down
                                if let feedback = guidanceFeedback {
                                    Text(feedback)
                                        .font(.caption)
                                        .foregroundStyle(.cyan)
                                        .multilineTextAlignment(.center)
                                } else if !isPoseCorrect {
                                    // Pose incorrect but no specific feedback (might be in dead zone)
                                    Text("Adjust pose to match target direction")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .multilineTextAlignment(.center)
                                } else if calibrationState.distance.isValid && !calibrationState.distance.isOptimal {
                                    // Subtle hint for non-optimal distance
                                    VStack(spacing: 2) {
                                        Text("Hold this position")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                        Text(calibrationState.distance.message)
                                            .font(.caption2)
                                            .foregroundStyle(.yellow.opacity(0.7))
                                    }
                                } else {
                                    Text("Hold this position")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                    .frame(minHeight: 32)  // Reduced from 44
                }
                .padding(.horizontal, 20)  // Reduced from 32
                .padding(.vertical, 12)  // Reduced from 20
                .frame(maxWidth: 320)  // Limited width instead of full width
                .background(.ultraThinMaterial)
                .cornerRadius(16)  // Slightly smaller radius
                .shadow(color: .black.opacity(0.2), radius: 10, y: -5)
                .padding(.bottom, 30)  // Lower position (was 40, now 30)
            }
            .animation(.easeInOut(duration: 0.2), value: guidanceFeedback)
            .animation(.easeInOut(duration: 0.2), value: qualityWarning)
            .animation(.easeInOut(duration: 0.2), value: countdownTimer)
        }
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
            return .green
        case .warning:
            return .yellow
        case .error:
            return .red
        }
    }
}

struct StatusBadge: View {
    let icon: String
    let status: BadgeStatus
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(status.color.opacity(0.3))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(status.color)
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let step: GuidanceStep
    let isCurrent: Bool
    let isCaptured: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isCaptured ? Color.green : (isCurrent ? Color.blue : Color.gray.opacity(0.3)))
                    .frame(width: 32, height: 32)

                if isCaptured {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                } else if isCurrent {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 28, height: 28)
                }
            }

            Text(step.shortName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(isCurrent ? .white : .gray)
        }
    }
}

// MARK: - Calibration Debug Info View

#if DEBUG
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
                        .foregroundStyle(.white.opacity(0.7))
                    Text("✓ Calibrated: \(viewModel.calibrationState.isCalibrated ? "Yes" : "No")")
                        .font(.caption2)
                        .foregroundStyle(viewModel.calibrationState.isCalibrated ? .green : .red)
                    Text("✓ Pose Valid: \(viewModel.isPoseCorrect ? "Yes" : "No")")
                        .font(.caption2)
                        .foregroundStyle(viewModel.isPoseCorrect ? .green : .red)
                }

                Divider()
                    .frame(height: 40)
                    .background(.white.opacity(0.3))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Quality")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Lighting: \(viewModel.calibrationState.lighting.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(viewModel.calibrationState.lighting.isValid ? .green : .orange)
                    Text("Distance: \(viewModel.calibrationState.distance.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(viewModel.calibrationState.distance.isValid ? .green : .orange)
                }

                Divider()
                    .frame(height: 40)
                    .background(.white.opacity(0.3))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan State")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Guidance: \(viewModel.isGuidanceActive ? "Active" : "Inactive")")
                        .font(.caption2)
                        .foregroundStyle(viewModel.isGuidanceActive ? .green : .gray)
                    Text("Captured: \(viewModel.capturedPoses.count)/\(GuidanceStep.allCases.count)")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                }
            }

            if let warning = viewModel.qualityWarning {
                Divider()
                    .background(.white.opacity(0.3))
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
        .padding(12)
        .background(.black.opacity(0.7))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
#endif

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        CalibrationOverlay(viewModel: FaceScan3DViewModel())
    }
}
