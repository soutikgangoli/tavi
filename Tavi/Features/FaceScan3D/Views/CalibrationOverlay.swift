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
                    calibrationState: viewModel.calibrationState
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
            if !viewModel.isGuidanceActive && viewModel.capturedPoses.count == GuidanceStep.allCases.count && viewModel.capturedPoses.count > 0 {
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

    var body: some View {
        VStack {
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
            .padding(.top, 60)
            .padding(.horizontal)

            Spacer()

            // Countdown timer
            if countdownTimer > 0 {
                Text("\(countdownTimer)")
                    .font(.system(size: 100, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 8)
            }

            // Instruction message
            VStack(spacing: 8) {
                Text(currentStep.instruction)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // Calibration warnings during guidance
                if !calibrationState.isCalibrated {
                    if let message = calibrationState.primaryMessage {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.yellow)
                            .padding(.top, 4)
                    }
                } else if countdownTimer == 0 {
                    Text("Hold this position")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding(.bottom, 120)
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

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        CalibrationOverlay(viewModel: FaceScan3DViewModel())
    }
}
