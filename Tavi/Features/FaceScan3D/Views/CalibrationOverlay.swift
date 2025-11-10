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
                VStack(spacing: 12) {
                    Spacer()

                    // CRITICAL: Block button if lighting quality is poor
                    let lightingIsGood = viewModel.calibrationManager.calibrationState.hasGoodLightingQuality

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
                        .background(lightingIsGood ? Color.blue : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!lightingIsGood)
                    .opacity(lightingIsGood ? 1.0 : 0.6)

                    // Show specific lighting issue if blocking
                    if !lightingIsGood {
                        Text(viewModel.calibrationManager.calibrationState.lightingIssueMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }

                    Spacer()
                        .frame(height: 60)
                }
            }

            // Completion message
            // Show completion message when all required poses have been captured
            if !viewModel.isGuidanceActive && viewModel.capturedPoses.count == GuidanceStep.allCases.count {
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
            return .green
        case .slightlyLeft, .slightlyRight:
            return .yellow
        case .farLeft, .farRight:
            return .red
        }
    }

    var body: some View {
        VStack {
            // Top indicators
            HStack(spacing: 20) {
                // Direction indicator
                StatusBadge(
                    icon: "arrow.triangle.turn.up.right.diamond.fill",
                    status: calibrationState.centerPosition == .center ? .good : (calibrationState.centerPosition == .slightlyLeft || calibrationState.centerPosition == .slightlyRight ? .warning : .error),
                    label: "Direction"
                )

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

                // Stability + Focus indicator (combines movement stability and image sharpness)
                StatusBadge(
                    icon: "hand.raised.fill",
                    status: {
                        // Check both stability (movement) and sharpness (blur)
                        let isStable = calibrationState.stability.isValid
                        let isSharp = calibrationManager.qualityWarning == nil || (!calibrationManager.qualityWarning!.contains("blur") && !calibrationManager.qualityWarning!.contains("steady") && !calibrationManager.qualityWarning!.contains("focus"))
                        
                        if isStable && isSharp {
                            return .good
                        } else if isStable || isSharp {
                            return .warning  // One is good, one needs work
                        } else {
                            return .error  // Both need work
                        }
                    }(),
                    label: "Stability"
                )
            }
            .padding(.top, 60)
            .padding(.horizontal)

            // Center position indicator (below Direction badge)
            HStack(spacing: 8) {
                let centerStatus = calibrationState.centerPosition
                Text(centerStatus.displayText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(centerStatusColor(centerStatus).opacity(0.3))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(centerStatusColor(centerStatus), lineWidth: 1)
                    )
            }
            .padding(.top, 8)

            Spacer()

            // Guidance message with detailed lighting info
            VStack(spacing: 8) {
                if let message = calibrationState.primaryMessage {
                    Text(message)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                }

                // Show detailed lighting issue if present
                if !calibrationState.lighting.isValid, let detail = calibrationState.lightingDetail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
            .padding(.bottom, 120)
        }
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

                // Stability + Focus indicator (combines movement stability and image sharpness)
                StatusBadge(
                    icon: "hand.raised.fill",
                    status: {
                        // Check both stability (movement) and sharpness (blur)
                        let isStable = calibrationState.stability.isValid
                        let isSharp = qualityWarning == nil || (!qualityWarning!.contains("blur") && !qualityWarning!.contains("steady") && !qualityWarning!.contains("focus"))
                        
                        if isStable && isSharp {
                            return .good
                        } else if isStable || isSharp {
                            return .warning  // One is good, one needs work
                        } else {
                            return .error  // Both need work
                        }
                    }(),
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
                                // Image quality warnings (blur, exposure) - PRIORITY when pose is correct
                                // Show helpful tips based on warning type
                                VStack(spacing: 4) {
                                    Text(warning)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .multilineTextAlignment(.center)
                                    
                                    // Add helpful tips for blur/sharpness issues
                                    if warning.contains("blur") || warning.contains("steady") || warning.contains("focus") {
                                        Text("💡 Tip: Hold phone very still, wait 2-3 seconds for focus")
                                            .font(.caption2)
                                            .foregroundStyle(.orange.opacity(0.8))
                                            .multilineTextAlignment(.center)
                                    } else if warning.contains("exposure") || warning.contains("bright") || warning.contains("dark") {
                                        Text("💡 Tip: Move to better lighting or adjust position")
                                            .font(.caption2)
                                            .foregroundStyle(.orange.opacity(0.8))
                                            .multilineTextAlignment(.center)
                                    }
                                }
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
                    Text("✓ Calibrated: \(viewModel.calibrationManager.calibrationState.isCalibrated ? "Yes" : "No")")
                        .font(.caption2)
                        .foregroundStyle(viewModel.calibrationManager.calibrationState.isCalibrated ? .green : .red)
                    Text("✓ Pose Valid: \(viewModel.calibrationManager.isPoseCorrect ? "Yes" : "No")")
                        .font(.caption2)
                        .foregroundStyle(viewModel.calibrationManager.isPoseCorrect ? .green : .red)
                }

                Divider()
                    .frame(height: 60)
                    .background(.white.opacity(0.3))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Face Angles")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.7))
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
                    .background(.white.opacity(0.3))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Quality")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.7))
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

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        CalibrationOverlay(viewModel: FaceScan3DViewModel())
    }
}
