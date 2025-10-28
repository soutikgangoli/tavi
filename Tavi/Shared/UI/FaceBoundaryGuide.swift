//
//  FaceBoundaryGuide.swift
//  Tavi
//
//  Face ID-style boundary guide with single error message
//  Created on 2025-10-27.
//

import SwiftUI

/// Face ID-style circular boundary guide
public struct FaceBoundaryGuide: View {
    let faceResult: FaceDetectionResult?
    let imageSize: CGSize
    let viewSize: CGSize
    let lightingStatus: CalibrationStatus?

    // Circle parameters
    private let circleSize: CGFloat = 280
    private let lineWidth: CGFloat = 4

    public var body: some View {
        ZStack {
            // Semi-transparent overlay with hole for face
            Color.black.opacity(0.4)
                .overlay(
                    Circle()
                        .frame(width: circleSize, height: circleSize)
                        .blendMode(.destinationOut)
                )
                .ignoresSafeArea()

            // Circular boundary guide
            Circle()
                .stroke(boundaryColor, lineWidth: lineWidth)
                .frame(width: circleSize, height: circleSize)
                .shadow(color: boundaryColor.opacity(0.5), radius: 8)

            // Face detection fill (shows when face is detected and positioned)
            if let faceResult = faceResult, isFaceInBoundary(faceResult) {
                Circle()
                    .trim(from: 0, to: completionProgress(for: faceResult))
                    .stroke(
                        Color.green,
                        style: StrokeStyle(lineWidth: lineWidth + 2, lineCap: .round)
                    )
                    .frame(width: circleSize, height: circleSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: completionProgress(for: faceResult))
            }

            // Single error message at bottom
            VStack {
                Spacer()

                if let errorMessage = primaryGuidanceMessage {
                    HStack(spacing: 12) {
                        Image(systemName: errorMessage.icon)
                            .font(.title3)
                            .foregroundStyle(errorMessage.color)

                        Text(errorMessage.text)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: primaryGuidanceMessage?.text)
    }

    // MARK: - Boundary Color

    private var boundaryColor: Color {
        if let faceResult = faceResult {
            return allChecksPassed(faceResult) ? .green : .white
        }
        return .white.opacity(0.6)
    }

    // MARK: - Completion Progress

    private func completionProgress(for face: FaceDetectionResult) -> CGFloat {
        var progress: CGFloat = 0

        // Each check adds 25% to progress
        if isDistanceGood(face) { progress += 0.25 }
        if isFaceStraight(face) { progress += 0.25 }
        if isFaceCentered(face) { progress += 0.25 }
        if isLightingGood() { progress += 0.25 }

        return progress
    }

    // MARK: - All Checks

    private func allChecksPassed(_ face: FaceDetectionResult) -> Bool {
        return isDistanceGood(face) &&
               isFaceStraight(face) &&
               isFaceCentered(face) &&
               isLightingGood()
    }

    // MARK: - Primary Guidance (One Error at a Time)

    private var primaryGuidanceMessage: GuidanceMessage? {
        // Priority order: Face Detection > Distance > Centering > Angle > Lighting

        // 1. No face detected
        guard let face = faceResult else {
            return GuidanceMessage(
                icon: "face.dashed",
                text: "Position your face in the circle",
                color: .white
            )
        }

        // 2. Distance check
        if !isDistanceGood(face) {
            guard let boundingBox = face.boundingBox else { return nil }
            let faceSize = boundingBox.width * boundingBox.height
            if faceSize < 0.15 {
                return GuidanceMessage(
                    icon: "arrow.down.forward.and.arrow.up.backward",
                    text: "A bit closer please",
                    color: .orange
                )
            } else {
                return GuidanceMessage(
                    icon: "arrow.up.backward.and.arrow.down.forward",
                    text: "A bit farther please",
                    color: .orange
                )
            }
        }

        // 3. Centering check
        if !isFaceCentered(face) {
            guard let boundingBox = face.boundingBox else { return nil }
            let centerX = boundingBox.midX
            let centerY = boundingBox.midY

            if centerX < 0.4 {
                return GuidanceMessage(icon: "arrow.right", text: "Slide right a bit", color: .orange)
            } else if centerX > 0.6 {
                return GuidanceMessage(icon: "arrow.left", text: "Slide left a bit", color: .orange)
            } else if centerY < 0.4 {
                return GuidanceMessage(icon: "arrow.down", text: "Lower slightly", color: .orange)
            } else {
                return GuidanceMessage(icon: "arrow.up", text: "Raise slightly", color: .orange)
            }
        }

        // 4. Angle check - STRICT validation
        if !isFaceStraight(face) {
            let yaw = face.yaw ?? 0
            let pitch = face.pitch ?? 0
            let roll = face.roll ?? 0

            // Check pitch first (most important for face scanning)
            if abs(pitch) > 10 {
                return GuidanceMessage(
                    icon: "arrow.up.and.down",
                    text: pitch > 0 ? "Chin up a little" : "Chin down a little",
                    color: .orange
                )
            } else if abs(yaw) > 10 {
                return GuidanceMessage(
                    icon: "arrow.left.and.right",
                    text: "Face forward please",
                    color: .orange
                )
            } else if abs(roll) > 8 {
                return GuidanceMessage(
                    icon: "rotate.3d",
                    text: "Hold head level",
                    color: .orange
                )
            }
        }

        // 5. Lighting check
        if !isLightingGood() {
            if let status = lightingStatus {
                switch status {
                case .tooLow:
                    return GuidanceMessage(
                        icon: "lightbulb.slash",
                        text: "Need more light",
                        color: .orange
                    )
                case .clipped:
                    return GuidanceMessage(
                        icon: "sun.max.fill",
                        text: "A bit too bright",
                        color: .orange
                    )
                default:
                    break
                }
            }
        }

        // All good!
        return GuidanceMessage(
            icon: "checkmark.circle.fill",
            text: "Perfect! Ready to capture",
            color: .green
        )
    }

    // MARK: - Validation Helpers

    private func isDistanceGood(_ face: FaceDetectionResult) -> Bool {
        guard let boundingBox = face.boundingBox else { return false }
        let faceSize = boundingBox.width * boundingBox.height
        return faceSize >= 0.15 && faceSize <= 0.4
    }

    private func isFaceStraight(_ face: FaceDetectionResult) -> Bool {
        // STRICT thresholds for face straightness (in degrees)
        let yawThreshold: CGFloat = 10      // Left/right turn (was 15)
        let pitchThreshold: CGFloat = 10    // Up/down tilt (was 15)
        let rollThreshold: CGFloat = 8      // Head tilt sideways (was 15)

        let yaw = abs(face.yaw ?? 0)
        let pitch = abs(face.pitch ?? 0)
        let roll = abs(face.roll ?? 0)

        return yaw < yawThreshold && pitch < pitchThreshold && roll < rollThreshold
    }

    private func isFaceCentered(_ face: FaceDetectionResult) -> Bool {
        guard let boundingBox = face.boundingBox else { return false }
        let centerX = boundingBox.midX
        let centerY = boundingBox.midY

        return centerX >= 0.4 && centerX <= 0.6 &&
               centerY >= 0.4 && centerY <= 0.6
    }

    private func isFaceInBoundary(_ face: FaceDetectionResult) -> Bool {
        // Face is in boundary if it's somewhat centered
        guard let boundingBox = face.boundingBox else { return false }
        let centerX = boundingBox.midX
        let centerY = boundingBox.midY

        return centerX >= 0.3 && centerX <= 0.7 &&
               centerY >= 0.3 && centerY <= 0.7
    }

    private func isLightingGood() -> Bool {
        return lightingStatus == .good
    }
}

// MARK: - Guidance Message

struct GuidanceMessage: Equatable {
    let icon: String
    let text: String
    let color: Color
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()

        FaceBoundaryGuide(
            faceResult: FaceDetectionResult(
                faceFound: true,
                boundingBox: CGRect(x: 0.4, y: 0.4, width: 0.3, height: 0.3),
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
