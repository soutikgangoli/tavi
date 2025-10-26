//
//  FaceLandmarksOverlay.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

// MARK: - Face Landmarks Overlay

public struct FaceLandmarksOverlay: View {
    let faceResults: [FaceDetectionResult]
    let imageSize: CGSize
    let viewSize: CGSize
    let isMirrored: Bool
    let showDebugInfo: Bool

    public init(
        faceResults: [FaceDetectionResult],
        imageSize: CGSize,
        viewSize: CGSize,
        isMirrored: Bool = false,
        showDebugInfo: Bool = true
    ) {
        self.faceResults = faceResults
        self.imageSize = imageSize
        self.viewSize = viewSize
        self.isMirrored = isMirrored
        self.showDebugInfo = showDebugInfo
    }

    public var body: some View {
        ZStack {
            ForEach(Array(faceResults.enumerated()), id: \.offset) { index, result in
                FaceDetectionView(
                    result: result,
                    imageSize: imageSize,
                    viewSize: viewSize,
                    isMirrored: isMirrored,
                    showDebugInfo: showDebugInfo
                )
            }
        }
    }
}

// MARK: - Individual Face Detection View

struct FaceDetectionView: View {
    let result: FaceDetectionResult
    let imageSize: CGSize
    let viewSize: CGSize
    let isMirrored: Bool
    let showDebugInfo: Bool

    var body: some View {
        ZStack {
            // Bounding box
            BoundingBoxView(
                boundingBox: result.boundingBox,
                imageSize: imageSize,
                viewSize: viewSize,
                isMirrored: isMirrored,
                confidence: result.confidence
            )

            // Landmarks
            LandmarksView(
                landmarks: result.landmarks,
                imageSize: imageSize,
                viewSize: viewSize,
                isMirrored: isMirrored
            )

            // Debug info
            if showDebugInfo {
                DebugInfoView(
                    result: result,
                    imageSize: imageSize,
                    viewSize: viewSize,
                    isMirrored: isMirrored
                )
            }
        }
    }
}

// MARK: - Bounding Box View

struct BoundingBoxView: View {
    let boundingBox: CGRect
    let imageSize: CGSize
    let viewSize: CGSize
    let isMirrored: Bool
    let confidence: Float

    var body: some View {
        let convertedBox = FaceDetector.convertBoundingBox(
            boundingBox,
            imageSize: imageSize,
            viewSize: viewSize,
            isMirrored: isMirrored
        )

        Rectangle()
            .stroke(Color.green, lineWidth: 2)
            .frame(width: convertedBox.width, height: convertedBox.height)
            .position(x: convertedBox.midX, y: convertedBox.midY)
            .overlay(
                Text(String(format: "%.0f%%", confidence * 100))
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(.green.opacity(0.8))
                    .cornerRadius(4)
                    .position(x: convertedBox.minX + 30, y: convertedBox.minY - 10)
            )
    }
}

// MARK: - Landmarks View

struct LandmarksView: View {
    let landmarks: FaceLandmarks
    let imageSize: CGSize
    let viewSize: CGSize
    let isMirrored: Bool

    var body: some View {
        ZStack {
            // Face contour (yellow)
            LandmarkPath(
                points: landmarks.faceContour,
                imageSize: imageSize,
                viewSize: viewSize,
                isMirrored: isMirrored,
                color: .yellow,
                lineWidth: 2,
                closed: false
            )

            // Left eye (cyan)
            LandmarkPath(
                points: landmarks.leftEye,
                imageSize: imageSize,
                viewSize: viewSize,
                isMirrored: isMirrored,
                color: .cyan,
                lineWidth: 1.5,
                closed: true
            )

            // Right eye (cyan)
            LandmarkPath(
                points: landmarks.rightEye,
                imageSize: imageSize,
                viewSize: viewSize,
                isMirrored: isMirrored,
                color: .cyan,
                lineWidth: 1.5,
                closed: true
            )

            // Left eyebrow (blue)
            LandmarkPath(
                points: landmarks.leftEyebrow,
                imageSize: imageSize,
                viewSize: viewSize,
                isMirrored: isMirrored,
                color: .blue,
                lineWidth: 1.5,
                closed: false
            )

            // Right eyebrow (blue)
            LandmarkPath(
                points: landmarks.rightEyebrow,
                imageSize: imageSize,
                viewSize: viewSize,
                isMirrored: isMirrored,
                color: .blue,
                lineWidth: 1.5,
                closed: false
            )

            // Nose (orange)
            LandmarkPath(
                points: landmarks.nose,
                imageSize: imageSize,
                viewSize: viewSize,
                isMirrored: isMirrored,
                color: .orange,
                lineWidth: 1.5,
                closed: false
            )

            // Nose crest (red)
            LandmarkPath(
                points: landmarks.noseCrest,
                imageSize: imageSize,
                viewSize: viewSize,
                isMirrored: isMirrored,
                color: .red,
                lineWidth: 1.5,
                closed: false
            )

            // Outer lips (pink)
            LandmarkPath(
                points: landmarks.outerLips,
                imageSize: imageSize,
                viewSize: viewSize,
                isMirrored: isMirrored,
                color: .pink,
                lineWidth: 1.5,
                closed: true
            )

            // Inner lips (purple)
            LandmarkPath(
                points: landmarks.innerLips,
                imageSize: imageSize,
                viewSize: viewSize,
                isMirrored: isMirrored,
                color: .purple,
                lineWidth: 1.5,
                closed: true
            )

            // Median line (white)
            LandmarkPath(
                points: landmarks.medianLine,
                imageSize: imageSize,
                viewSize: viewSize,
                isMirrored: isMirrored,
                color: .white,
                lineWidth: 1,
                closed: false
            )

            // Pupils (bright green circles)
            if let leftPupil = landmarks.leftPupil {
                LandmarkPoint(
                    point: leftPupil,
                    imageSize: imageSize,
                    viewSize: viewSize,
                    isMirrored: isMirrored,
                    color: .green,
                    size: 6
                )
            }

            if let rightPupil = landmarks.rightPupil {
                LandmarkPoint(
                    point: rightPupil,
                    imageSize: imageSize,
                    viewSize: viewSize,
                    isMirrored: isMirrored,
                    color: .green,
                    size: 6
                )
            }

            // Eye angle line (for debugging alignment)
            if let leftPupil = landmarks.leftPupil,
               let rightPupil = landmarks.rightPupil {
                EyeAngleLine(
                    leftPupil: leftPupil,
                    rightPupil: rightPupil,
                    imageSize: imageSize,
                    viewSize: viewSize,
                    isMirrored: isMirrored
                )
            }
        }
    }
}

// MARK: - Landmark Path

struct LandmarkPath: View {
    let points: [CGPoint]
    let imageSize: CGSize
    let viewSize: CGSize
    let isMirrored: Bool
    let color: Color
    let lineWidth: CGFloat
    let closed: Bool

    var body: some View {
        if !points.isEmpty {
            Path { path in
                let convertedPoints = points.map { point in
                    FaceDetector.convertFromNormalizedCoordinates(
                        point,
                        imageSize: imageSize,
                        viewSize: viewSize,
                        isMirrored: isMirrored
                    )
                }

                path.move(to: convertedPoints[0])
                for point in convertedPoints.dropFirst() {
                    path.addLine(to: point)
                }

                if closed {
                    path.closeSubpath()
                }
            }
            .stroke(color, lineWidth: lineWidth)
        }
    }
}

// MARK: - Landmark Point

struct LandmarkPoint: View {
    let point: CGPoint
    let imageSize: CGSize
    let viewSize: CGSize
    let isMirrored: Bool
    let color: Color
    let size: CGFloat

    var body: some View {
        let convertedPoint = FaceDetector.convertFromNormalizedCoordinates(
            point,
            imageSize: imageSize,
            viewSize: viewSize,
            isMirrored: isMirrored
        )

        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .position(convertedPoint)
    }
}

// MARK: - Eye Angle Line

struct EyeAngleLine: View {
    let leftPupil: CGPoint
    let rightPupil: CGPoint
    let imageSize: CGSize
    let viewSize: CGSize
    let isMirrored: Bool

    var body: some View {
        let leftConverted = FaceDetector.convertFromNormalizedCoordinates(
            leftPupil,
            imageSize: imageSize,
            viewSize: viewSize,
            isMirrored: isMirrored
        )

        let rightConverted = FaceDetector.convertFromNormalizedCoordinates(
            rightPupil,
            imageSize: imageSize,
            viewSize: viewSize,
            isMirrored: isMirrored
        )

        Path { path in
            path.move(to: leftConverted)
            path.addLine(to: rightConverted)
        }
        .stroke(Color.green.opacity(0.8), lineWidth: 2)
    }
}

// MARK: - Debug Info View

struct DebugInfoView: View {
    let result: FaceDetectionResult
    let imageSize: CGSize
    let viewSize: CGSize
    let isMirrored: Bool

    var body: some View {
        let convertedBox = FaceDetector.convertBoundingBox(
            result.boundingBox,
            imageSize: imageSize,
            viewSize: viewSize,
            isMirrored: isMirrored
        )

        VStack(alignment: .leading, spacing: 4) {
            if let roll = result.roll {
                Text("Roll: \(String(format: "%.1f°", roll * 180 / .pi))")
            }
            if let yaw = result.yaw {
                Text("Yaw: \(String(format: "%.1f°", yaw * 180 / .pi))")
            }
            if let pitch = result.pitch {
                Text("Pitch: \(String(format: "%.1f°", pitch * 180 / .pi))")
            }
            if let eyeAngle = result.landmarks.eyeAngle() {
                Text("Eye Angle: \(String(format: "%.1f°", eyeAngle * 180 / .pi))")
            }
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.white)
        .padding(6)
        .background(.black.opacity(0.7))
        .cornerRadius(6)
        .position(x: convertedBox.maxX - 50, y: convertedBox.minY - 40)
    }
}

// MARK: - Landmark Legend

public struct LandmarkLegend: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Landmarks")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            LegendItem(color: .green, label: "Bounding Box")
            LegendItem(color: .yellow, label: "Face Contour")
            LegendItem(color: .cyan, label: "Eyes")
            LegendItem(color: .blue, label: "Eyebrows")
            LegendItem(color: .orange, label: "Nose")
            LegendItem(color: .red, label: "Nose Crest")
            LegendItem(color: .pink, label: "Outer Lips")
            LegendItem(color: .purple, label: "Inner Lips")
            LegendItem(color: .white, label: "Median")
            LegendItem(color: .green, label: "Pupils/Angle", isCircle: true)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    var isCircle: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if isCircle {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            } else {
                Rectangle()
                    .fill(color)
                    .frame(width: 16, height: 2)
            }

            Text(label)
                .font(.caption2)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            LandmarkLegend()
                .padding()
        }
    }
}
