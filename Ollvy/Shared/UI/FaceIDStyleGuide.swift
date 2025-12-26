//
//  FaceIDStyleGuide.swift
//  Ollvy
//
//  Apple Face ID-style clean interface
//  Created on 2025-10-27.
//

import SwiftUI

/// Clean Apple Face ID-style face scanning guide
public struct FaceIDStyleGuide: View {
    let faceResult: FaceDetectionResult?
    let lightingStatus: CalibrationStatus?
    var onAutoCapture: (() -> Void)?

    @State private var holdTimer: Int = 0
    @State private var isHolding = false
    @State private var hasTriggeredCapture = false
    @State private var timerActive = false

    // Timer publisher for countdown - properly handles SwiftUI lifecycle
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    public init(
        faceResult: FaceDetectionResult? = nil,
        lightingStatus: CalibrationStatus? = nil,
        onAutoCapture: (() -> Void)? = nil
    ) {
        self.faceResult = faceResult
        self.lightingStatus = lightingStatus
        self.onAutoCapture = onAutoCapture
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Top status indicators (filled circles)
                VStack {
                    HStack(spacing: 16) {
                        // Face detected indicator
                        StatusIndicator(
                            state: faceResult != nil ? .perfect : .empty,
                            label: "Face"
                        )

                        // Distance indicator
                        StatusIndicator(
                            state: getDistanceState(faceResult),
                            label: "Distance"
                        )

                        // Position indicator
                        StatusIndicator(
                            state: getPositionState(faceResult),
                            label: "Position"
                        )

                        // Angle indicator
                        StatusIndicator(
                            state: getAngleState(faceResult),
                            label: "Angle"
                        )

                        // Lighting indicator
                        StatusIndicator(
                            state: getLightingState(lightingStatus),
                            label: "Light"
                        )
                    }
                    .padding(.top, 60)
                    .padding(.horizontal)

                    Spacer()
                }

                // Face outline guide (larger oval)
                FaceOutlineView(
                    faceDetected: faceResult != nil,
                    allChecksPassed: allChecksPassed,
                    holdTimer: holdTimer,
                    screenSize: geometry.size
                )

                // Simple guidance message at bottom
                VStack {
                    Spacer()

                    if let message = simpleGuidanceMessage {
                        Text(message)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .padding(.bottom, 150)
                    }
                }
            }
            .onChange(of: allChecksPassed) { _, newValue in
                if newValue {
                    startHoldTimer()
                } else {
                    resetHoldTimer()
                }
            }
            .onChange(of: holdTimer) { _, newValue in
                // Auto-capture when countdown reaches 0
                if allChecksPassed && newValue == 0 && !hasTriggeredCapture {
                    hasTriggeredCapture = true
                    onAutoCapture?()
                }
            }
            // FIXED: Use onReceive with Timer.publish instead of Timer.scheduledTimer
            // This properly handles SwiftUI view lifecycle and avoids "Publishing changes" warnings
            .onReceive(timer) { _ in
                guard timerActive else { return }
                guard allChecksPassed else {
                    resetHoldTimer()
                    return
                }
                if holdTimer > 0 {
                    holdTimer -= 1
                }
            }
        }
    }

    // MARK: - All Checks Passed

    private var allChecksPassed: Bool {
        guard let face = faceResult else { return false }
        return isDistanceGood(face) &&
               isFaceCentered(face) &&
               isFaceStraight(face) &&
               lightingStatus == .good
    }

    // MARK: - Simple Guidance Message

    private var simpleGuidanceMessage: String? {
        // Priority order: Face > Distance > Position > Eyes > Mouth > Angle > Lighting

        guard let face = faceResult else {
            return "Face outside the frame"
        }

        if !isDistanceGood(face) {
            guard let boundingBox = face.boundingBox else { return "Face outside the frame" }
            let faceSize = boundingBox.width * boundingBox.height
            return faceSize < 0.15 ? "Face too far" : "Face too close"
        }

        if !isFaceCentered(face) {
            return "Center your face"
        }

        // Check if eyes are closed (using landmarks if available)
        if let landmarks = face.landmarks,
           let leftEye = landmarks.leftEyebrow,
           let rightEye = landmarks.rightEyebrow {
            if areEyesClosed(leftEye: leftEye, rightEye: rightEye) {
                return "Eyes are closed"
            }
        }

        // Check if mouth is open (using landmarks if available)
        if let landmarks = face.landmarks,
           let outerLips = landmarks.outerLips,
           let innerLips = landmarks.innerLips {
            if isMouthOpen(outerLips: outerLips, innerLips: innerLips) {
                return "Please close your mouth"
            }
        }

        if !isFaceStraight(face) {
            return "Keep your face straight"
        }

        if lightingStatus != .good {
            return lightingStatus == .tooLow ? "Need more light" : "Lighting issue"
        }

        return holdTimer > 0 ? "Great! Please look at the camera" : "Perfect! Hold still..."
    }

    // MARK: - Validation Helpers

    private func isDistanceGood(_ face: FaceDetectionResult) -> Bool {
        guard let boundingBox = face.boundingBox else { return false }
        let faceSize = boundingBox.width * boundingBox.height
        return faceSize >= 0.15 && faceSize <= 0.4
    }

    private func isFaceStraight(_ face: FaceDetectionResult) -> Bool {
        let yaw = abs(face.yaw ?? 0)
        let pitch = abs(face.pitch ?? 0)
        let roll = abs(face.roll ?? 0)
        return yaw < 10 && pitch < 10 && roll < 8
    }

    private func isFaceCentered(_ face: FaceDetectionResult) -> Bool {
        guard let boundingBox = face.boundingBox else { return false }
        let centerX = boundingBox.midX
        let centerY = boundingBox.midY
        return centerX >= 0.4 && centerX <= 0.6 &&
               centerY >= 0.4 && centerY <= 0.6
    }

    private func areEyesClosed(leftEye: [CGPoint], rightEye: [CGPoint]) -> Bool {
        // Check eye aspect ratio - if eyes are closed, the height will be very small
        guard leftEye.count >= 6, rightEye.count >= 6 else { return false }

        let leftEyeHeight = abs(leftEye[1].y - leftEye[5].y)
        let leftEyeWidth = abs(leftEye[0].x - leftEye[3].x)
        let leftRatio = leftEyeHeight / max(leftEyeWidth, 0.001)

        let rightEyeHeight = abs(rightEye[1].y - rightEye[5].y)
        let rightEyeWidth = abs(rightEye[0].x - rightEye[3].x)
        let rightRatio = rightEyeHeight / max(rightEyeWidth, 0.001)

        // If aspect ratio is very small, eyes are likely closed
        return (leftRatio + rightRatio) / 2 < 0.15
    }

    private func isMouthOpen(outerLips: [CGPoint], innerLips: [CGPoint]) -> Bool {
        // Check vertical distance between top and bottom of mouth
        guard outerLips.count >= 8, innerLips.count >= 6 else { return false }

        // Calculate mouth opening (distance between top and bottom lip)
        let mouthHeight = abs(outerLips[3].y - outerLips[7].y)
        let mouthWidth = abs(outerLips[0].x - outerLips[6].x)
        let mouthRatio = mouthHeight / max(mouthWidth, 0.001)

        // If ratio is above threshold, mouth is open
        return mouthRatio > 0.25
    }

    // MARK: - State Getters for Indicators

    private func getDistanceState(_ face: FaceDetectionResult?) -> IndicatorState {
        guard let face = face, let boundingBox = face.boundingBox else { return .empty }
        let faceSize = boundingBox.width * boundingBox.height

        if faceSize >= 0.15 && faceSize <= 0.4 {
            return .perfect
        } else if faceSize >= 0.12 && faceSize <= 0.45 {
            return .okay
        } else {
            return .empty
        }
    }

    private func getPositionState(_ face: FaceDetectionResult?) -> IndicatorState {
        guard let face = face, let boundingBox = face.boundingBox else { return .empty }
        let centerX = boundingBox.midX
        let centerY = boundingBox.midY

        // Perfect: centered
        if centerX >= 0.4 && centerX <= 0.6 && centerY >= 0.4 && centerY <= 0.6 {
            return .perfect
        }
        // Okay: close to center
        else if centerX >= 0.35 && centerX <= 0.65 && centerY >= 0.35 && centerY <= 0.65 {
            return .okay
        }
        else {
            return .empty
        }
    }

    private func getAngleState(_ face: FaceDetectionResult?) -> IndicatorState {
        guard let face = face else { return .empty }
        let yaw = abs(face.yaw ?? 0)
        let pitch = abs(face.pitch ?? 0)
        let roll = abs(face.roll ?? 0)

        // Perfect: very straight
        if yaw < 10 && pitch < 10 && roll < 8 {
            return .perfect
        }
        // Okay: slightly tilted
        else if yaw < 15 && pitch < 15 && roll < 12 {
            return .okay
        }
        else {
            return .empty
        }
    }

    private func getLightingState(_ status: CalibrationStatus?) -> IndicatorState {
        guard let status = status else { return .empty }

        switch status {
        case .good:
            return .perfect
        case .clipped:
            return .okay
        case .tooLow:
            return .empty
        }
    }

    // MARK: - Timer Functions

    private func startHoldTimer() {
        isHolding = true
        holdTimer = 5
        hasTriggeredCapture = false
        timerActive = true
    }

    private func resetHoldTimer() {
        timerActive = false
        isHolding = false
        holdTimer = 0
        hasTriggeredCapture = false
    }
}

// MARK: - Indicator State

enum IndicatorState {
    case empty      // Not passing - gray/empty
    case okay       // Acceptable but not perfect - yellow
    case perfect    // Perfect - green
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let state: IndicatorState
    let label: String

    private var fillColor: Color {
        switch state {
        case .empty:
            return Designs.Status.inactive.opacity(Designs.Opacity.medium)
        case .okay:
            return Designs.Status.warning
        case .perfect:
            return Designs.Status.active
        }
    }

    private var labelColor: Color {
        switch state {
        case .empty:
            return Designs.Status.inactive
        case .okay:
            return Designs.Status.warning
        case .perfect:
            return Designs.Status.active
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(fillColor)
                .frame(width: Designs.Sizes.iconSmall, height: Designs.Sizes.iconSmall)

            Text(label)
                .font(.app(size: 10, weight: .medium))
                .foregroundStyle(labelColor)
        }
    }
}

// MARK: - Face Outline View

struct FaceOutlineView: View {
    let faceDetected: Bool
    let allChecksPassed: Bool
    let holdTimer: Int
    let screenSize: CGSize

    private var outlineSize: CGSize {
        // Make the oval much larger - about 70% of screen width
        let width = screenSize.width * 0.75
        let height = width * 1.35
        return CGSize(width: width, height: height)
    }

    var body: some View {
        ZStack {
            // Animated rays/rings for success state
            if allChecksPassed {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Designs.Status.active.opacity(Designs.Opacity.medium), Designs.Status.active.opacity(0)],
                            startPoint: .center,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: outlineSize.width * 1.2, height: outlineSize.height * 1.2)
                    .opacity(0.6)
                    .scaleEffect(1.0)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                        value: allChecksPassed
                    )
            }

            // Main oval face outline
            Ellipse()
                .stroke(
                    allChecksPassed ?
                        LinearGradient(
                            colors: [Designs.Status.active, Designs.Status.active.opacity(Designs.Opacity.semiTransparent)],
                            startPoint: .top,
                            endPoint: .bottom
                        ) :
                        LinearGradient(
                            colors: [Color.white.opacity(faceDetected ? 0.8 : 0.4), Color.white.opacity(faceDetected ? 0.6 : 0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                    style: StrokeStyle(
                        lineWidth: allChecksPassed ? 5 : 3,
                        lineCap: .round,
                        dash: faceDetected ? [] : [15, 15]
                    )
                )
                .frame(width: outlineSize.width, height: outlineSize.height)
                .shadow(
                    color: (allChecksPassed ? Designs.Status.active : Color.white).opacity(allChecksPassed ? Designs.Opacity.semiOpaque : Designs.Opacity.light),
                    radius: allChecksPassed ? 12 : 4
                )

            // Countdown timer when holding
            if allChecksPassed && holdTimer > 0 {
                Text("\(holdTimer)")
                    .font(AppFont.scoreDisplayLarge)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        FaceIDStyleGuide(
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
                yaw: 8,
                pitch: -3,
                roll: 5
            ),
            lightingStatus: .good
        )
    }
}
