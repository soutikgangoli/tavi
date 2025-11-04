//
//  ARKitErrorRecoveryView.swift
//  Tavi
//
//  Error recovery view with specific guidance and recovery options
//  Shows user-friendly error messages with actionable steps
//

import SwiftUI

/// Error recovery view with detailed guidance
public struct ARKitErrorRecoveryView: View {
    let errorInfo: ARKitErrorInfo
    let partialCaptureCount: Int
    let onRetry: () -> Void
    let onContinue: (() -> Void)?
    let onDismiss: () -> Void

    public init(
        errorInfo: ARKitErrorInfo,
        partialCaptureCount: Int = 0,
        onRetry: @escaping () -> Void,
        onContinue: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.errorInfo = errorInfo
        self.partialCaptureCount = partialCaptureCount
        self.onRetry = onRetry
        self.onContinue = onContinue
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // Error card
            VStack(spacing: 0) {
                // Header with icon
                VStack(spacing: 16) {
                    // Error icon
                    ZStack {
                        Circle()
                            .fill(iconBackgroundColor)
                            .frame(width: 80, height: 80)

                        Image(systemName: errorInfo.icon)
                            .font(.system(size: 36))
                            .foregroundColor(iconColor)
                    }

                    // Title
                    Text(errorInfo.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    // Message
                    Text(errorInfo.message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)

                // Partial capture indicator
                if partialCaptureCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("\(partialCaptureCount) pose\(partialCaptureCount == 1 ? "" : "s") captured")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 24)
                }

                // Recovery steps
                if !errorInfo.recoverySteps.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to fix:")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.bottom, 4)

                        ForEach(Array(errorInfo.recoverySteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1).")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                    .frame(width: 20, alignment: .trailing)

                                Text(step)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 24)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }

                // Action buttons
                VStack(spacing: 12) {
                    // Retry button (primary)
                    if errorInfo.shouldRetry {
                        Button(action: onRetry) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text(partialCaptureCount > 0 ? "Resume Scan" : "Try Again")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }

                    // Continue button (if partial captures exist)
                    if errorInfo.shouldShowContinue, let continueAction = onContinue, partialCaptureCount > 0 {
                        Button(action: continueAction) {
                            HStack {
                                Image(systemName: "arrow.forward")
                                Text("Continue Anyway")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(uiColor: .systemGray5))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }
                    }

                    // Cancel button
                    Button(action: onDismiss) {
                        Text("Cancel Scan")
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: 400)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Computed Properties

    private var iconColor: Color {
        switch errorInfo.type {
        case .trackingLost, .insufficientFeatures, .sessionInterrupted:
            return .orange
        case .multipleFaces, .poorLighting, .cameraOccluded:
            return .yellow
        case .configurationFailed, .sensorFailed, .permissionDenied, .deviceNotSupported:
            return .red
        case .unknown:
            return .gray
        }
    }

    private var iconBackgroundColor: Color {
        switch errorInfo.type {
        case .trackingLost, .insufficientFeatures, .sessionInterrupted:
            return Color.orange.opacity(0.15)
        case .multipleFaces, .poorLighting, .cameraOccluded:
            return Color.yellow.opacity(0.15)
        case .configurationFailed, .sensorFailed, .permissionDenied, .deviceNotSupported:
            return Color.red.opacity(0.15)
        case .unknown:
            return Color.gray.opacity(0.15)
        }
    }
}

// MARK: - Preview

#Preview("Tracking Lost") {
    ARKitErrorRecoveryView(
        errorInfo: ARKitErrorInfo(
            type: .trackingLost,
            title: "Face Tracking Lost",
            message: "Face tracking was lost during the scan.",
            recoverySteps: [
                "Keep your face centered in the camera",
                "Move more slowly during turns",
                "Ensure good lighting",
                "Continue from where you left off"
            ],
            icon: "face.dashed",
            shouldRetry: true,
            shouldShowContinue: true
        ),
        partialCaptureCount: 3,
        onRetry: {},
        onContinue: {},
        onDismiss: {}
    )
}

#Preview("Camera Permission") {
    ARKitErrorRecoveryView(
        errorInfo: ARKitErrorInfo(
            type: .permissionDenied,
            title: "Camera Access Required",
            message: "Tavi needs camera access to scan your face.",
            recoverySteps: [
                "Open Settings app",
                "Go to Tavi > Camera",
                "Enable Camera access",
                "Return to Tavi and try again"
            ],
            icon: "camera.fill",
            shouldRetry: false
        ),
        onRetry: {},
        onDismiss: {}
    )
}

#Preview("Multiple Faces") {
    ARKitErrorRecoveryView(
        errorInfo: ARKitErrorInfo(
            type: .multipleFaces,
            title: "Multiple Faces Detected",
            message: "Only one face should be visible during the scan.",
            recoverySteps: [
                "Ensure you're alone in the frame",
                "Ask others to move out of view",
                "Try scanning again"
            ],
            icon: "person.2.slash",
            shouldRetry: true,
            shouldShowContinue: true
        ),
        partialCaptureCount: 2,
        onRetry: {},
        onContinue: {},
        onDismiss: {}
    )
}
