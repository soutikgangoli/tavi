//
//  FaceGuidanceView.swift
//  Ollvy
//
//  Created on 2025-10-27.
//

import SwiftUI

/// Real-time guidance overlay that helps users position their face correctly
public struct FaceGuidanceView: View {
    let faceResult: FaceDetectionResult?
    let imageSize: CGSize
    let viewSize: CGSize
    let lightingStatus: CalibrationStatus?

    public init(
        faceResult: FaceDetectionResult?,
        imageSize: CGSize,
        viewSize: CGSize,
        lightingStatus: CalibrationStatus?
    ) {
        self.faceResult = faceResult
        self.imageSize = imageSize
        self.viewSize = viewSize
        self.lightingStatus = lightingStatus
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Main guidance cards
            VStack(spacing: 8) {
                // Face detection status
                GuidanceCard(
                    icon: faceDetectionIcon,
                    message: faceDetectionMessage,
                    status: faceDetectionStatus
                )

                // Distance guidance
                if let faceResult = faceResult {
                    GuidanceCard(
                        icon: distanceIcon(for: faceResult),
                        message: distanceMessage(for: faceResult),
                        status: distanceStatus(for: faceResult)
                    )

                    // Face angle guidance
                    GuidanceCard(
                        icon: angleIcon(for: faceResult),
                        message: angleMessage(for: faceResult),
                        status: angleStatus(for: faceResult)
                    )

                    // Face position guidance
                    GuidanceCard(
                        icon: positionIcon(for: faceResult),
                        message: positionMessage(for: faceResult),
                        status: positionStatus(for: faceResult)
                    )
                }

                // Lighting guidance
                if let lightingStatus = lightingStatus {
                    GuidanceCard(
                        icon: lightingIcon(for: lightingStatus),
                        message: lightingMessage(for: lightingStatus),
                        status: lightingGuidanceStatus(for: lightingStatus)
                    )
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding()
        }
    }

    // MARK: - Face Detection

    private var faceDetectionIcon: String {
        faceResult != nil ? "face.smiling.fill" : "face.dashed"
    }

    private var faceDetectionMessage: String {
        faceResult != nil ? "Face detected" : "No face detected"
    }

    private var faceDetectionStatus: GuidanceStatus {
        faceResult != nil ? .good : .warning
    }

    // MARK: - Distance Guidance

    private func distanceIcon(for face: FaceDetectionResult) -> String {
        guard let boundingBox = face.boundingBox else { return "exclamationmark.triangle" }
        let faceSize = boundingBox.width * boundingBox.height

        if faceSize < 0.15 {
            return "arrow.down.forward.and.arrow.up.backward"
        } else if faceSize > 0.4 {
            return "arrow.up.backward.and.arrow.down.forward"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private func distanceMessage(for face: FaceDetectionResult) -> String {
        guard let boundingBox = face.boundingBox else { return "Face bounds unavailable" }
        let faceSize = boundingBox.width * boundingBox.height

        if faceSize < 0.15 {
            return "Move closer to camera"
        } else if faceSize > 0.4 {
            return "Move away from camera"
        } else {
            return "Distance is perfect"
        }
    }

    private func distanceStatus(for face: FaceDetectionResult) -> GuidanceStatus {
        guard let boundingBox = face.boundingBox else { return .error }
        let faceSize = boundingBox.width * boundingBox.height

        if faceSize < 0.15 || faceSize > 0.4 {
            return .warning
        } else {
            return .good
        }
    }

    // MARK: - Angle Guidance

    private func angleIcon(for face: FaceDetectionResult) -> String {
        if !isFaceStraight(face) {
            return "rotate.3d"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private func angleMessage(for face: FaceDetectionResult) -> String {
        let yaw = abs(face.yaw ?? 0)
        let pitch = abs(face.pitch ?? 0)
        let roll = abs(face.roll ?? 0)

        if yaw > 15 {
            return yaw > 0 ? "Turn face to the left" : "Turn face to the right"
        } else if pitch > 15 {
            return pitch > 0 ? "Look down slightly" : "Look up slightly"
        } else if roll > 15 {
            return "Keep head straight"
        } else {
            return "Face angle is perfect"
        }
    }

    private func angleStatus(for face: FaceDetectionResult) -> GuidanceStatus {
        isFaceStraight(face) ? .good : .warning
    }

    private func isFaceStraight(_ face: FaceDetectionResult) -> Bool {
        let yawThreshold: CGFloat = 15
        let pitchThreshold: CGFloat = 15
        let rollThreshold: CGFloat = 15

        let yaw = abs(face.yaw ?? 0)
        let pitch = abs(face.pitch ?? 0)
        let roll = abs(face.roll ?? 0)

        return yaw < yawThreshold && pitch < pitchThreshold && roll < rollThreshold
    }

    // MARK: - Position Guidance

    private func positionIcon(for face: FaceDetectionResult) -> String {
        if !isFaceCentered(face) {
            return "square.dashed"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private func positionMessage(for face: FaceDetectionResult) -> String {
        guard let boundingBox = face.boundingBox else { return "Face bounds unavailable" }
        let centerX = boundingBox.midX
        let centerY = boundingBox.midY

        if centerX < 0.35 {
            return "Move right to center"
        } else if centerX > 0.65 {
            return "Move left to center"
        } else if centerY < 0.35 {
            return "Move down to center"
        } else if centerY > 0.65 {
            return "Move up to center"
        } else {
            return "Face centered perfectly"
        }
    }

    private func positionStatus(for face: FaceDetectionResult) -> GuidanceStatus {
        isFaceCentered(face) ? .good : .warning
    }

    private func isFaceCentered(_ face: FaceDetectionResult) -> Bool {
        guard let boundingBox = face.boundingBox else { return false }
        let centerX = boundingBox.midX
        let centerY = boundingBox.midY

        // Check if face is within central 60% of frame
        return centerX >= 0.35 && centerX <= 0.65 &&
               centerY >= 0.35 && centerY <= 0.65
    }

    // MARK: - Lighting Guidance

    private func lightingIcon(for status: CalibrationStatus) -> String {
        switch status {
        case .tooLow:
            return "lightbulb.slash"
        case .clipped:
            return "sun.max.fill"
        case .good:
            return "checkmark.circle.fill"
        }
    }

    private func lightingMessage(for status: CalibrationStatus) -> String {
        switch status {
        case .tooLow:
            return "Lighting too dark or too bright"
        case .clipped:
            return "Reduce bright light sources"
        case .good:
            return "Lighting is perfect"
        }
    }

    private func lightingGuidanceStatus(for status: CalibrationStatus) -> GuidanceStatus {
        status == .good ? .good : .warning
    }
}

// MARK: - Guidance Card

struct GuidanceCard: View {
    let icon: String
    let message: String
    let status: GuidanceStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(status.color)
                .frame(width: 24)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)

            Spacer()

            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(status.backgroundColor)
        .cornerRadius(10)
    }
}

// MARK: - Guidance Status

enum GuidanceStatus {
    case good
    case warning
    case error

    var color: Color {
        switch self {
        case .good: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }

    var backgroundColor: Color {
        switch self {
        case .good: return .green.opacity(0.15)
        case .warning: return .orange.opacity(0.15)
        case .error: return .red.opacity(0.15)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        FaceGuidanceView(
            faceResult: FaceDetectionResult(
                faceFound: true,
                boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4),
                confidence: 0.99,
                landmarks: FaceLandmarks(
                    leftEye: CGPoint(x: 0.45, y: 0.48),
                    rightEye: CGPoint(x: 0.55, y: 0.48),
                    nose: CGPoint(x: 0.5, y: 0.55),
                    mouth: CGPoint(x: 0.5, y: 0.62),
                    allPoints: [],
                    leftEyebrow: [],
                    rightEyebrow: [],
                    noseCrest: [],
                    medianLine: [],
                    outerLips: [],
                    innerLips: [],
                    leftPupil: nil,
                    rightPupil: nil,
                    faceContour: []
                ),
                yaw: 10,
                pitch: -5,
                roll: 5
            ),
            imageSize: CGSize(width: 1920, height: 1080),
            viewSize: CGSize(width: 390, height: 844),
            lightingStatus: .good
        )
    }
}
