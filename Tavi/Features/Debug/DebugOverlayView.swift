//
//  DebugOverlayView.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

/// Overlay for face detection and ROI visualization on debug screen
struct DebugOverlayView: View {

    let faces: [FaceDetectionResult]
    let roiSets: [FaceROISet]
    let imageSize: CGSize
    let showFaceBounds: Bool
    let showLandmarks: Bool
    let onROITap: ((FaceROISet, ROIType, CGPoint) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Face bounds and landmarks
                if showFaceBounds {
                    ForEach(Array(faces.enumerated()), id: \.offset) { _, face in
                        FaceBoundsView(
                            face: face,
                            imageSize: imageSize,
                            viewSize: geometry.size,
                            showLandmarks: showLandmarks
                        )
                    }
                }

                // ROI overlays
                ForEach(Array(roiSets.enumerated()), id: \.offset) { _, roiSet in
                    ROIOverlayDebugView(
                        roiSet: roiSet,
                        imageSize: imageSize,
                        viewSize: geometry.size,
                        onTap: { roiType, point in
                            onROITap?(roiSet, roiType, point)
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Face Bounds View

struct FaceBoundsView: View {

    let face: FaceDetectionResult
    let imageSize: CGSize
    let viewSize: CGSize
    let showLandmarks: Bool

    var body: some View {
        ZStack {
            // Bounding box
            let boundingRect = convertedBoundingBox

            Rectangle()
                .stroke(Color.green, lineWidth: 2)
                .frame(width: boundingRect.width, height: boundingRect.height)
                .position(x: boundingRect.midX, y: boundingRect.midY)

            // Confidence label
            Text(String(format: "%.0f%%", face.confidence * 100))
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.green)
                .padding(4)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .position(x: boundingRect.midX, y: boundingRect.minY - 12)

            // Landmarks
            if showLandmarks {
                landmarksView
            }
        }
    }

    private var convertedBoundingBox: CGRect {
        guard let boundingBox = face.boundingBox else { return .zero }
        return convertNormalizedRect(boundingBox, to: viewSize, from: imageSize)
    }

    @ViewBuilder
    private var landmarksView: some View {
        if let landmarks = face.landmarks {
            // Left eye
            if let leftEye = landmarks.leftEyebrow, !leftEye.isEmpty {
                LandmarkPointsView(
                    points: leftEye,
                    imageSize: imageSize,
                    viewSize: viewSize,
                    color: .cyan
                )
            }

            // Right eye
            if let rightEye = landmarks.rightEyebrow, !rightEye.isEmpty {
                LandmarkPointsView(
                    points: rightEye,
                    imageSize: imageSize,
                    viewSize: viewSize,
                    color: .cyan
                )
            }

            // Nose
            if let nose = landmarks.noseCrest, !nose.isEmpty {
                LandmarkPointsView(
                    points: nose,
                    imageSize: imageSize,
                    viewSize: viewSize,
                    color: .yellow
                )
            }

            // Mouth
            if let outerLips = landmarks.outerLips, !outerLips.isEmpty {
                LandmarkPointsView(
                    points: outerLips,
                    imageSize: imageSize,
                    viewSize: viewSize,
                    color: .red
                )
            }

            // Face outline
            if let faceContour = landmarks.faceContour, !faceContour.isEmpty {
                LandmarkPointsView(
                    points: faceContour,
                    imageSize: imageSize,
                    viewSize: viewSize,
                    color: .green
                )
            }
        }
    }

    private func convertNormalizedRect(_ rect: CGRect, to viewSize: CGSize, from imageSize: CGSize) -> CGRect {
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        let scale = min(scaleX, scaleY)

        let scaledImageWidth = imageSize.width * scale
        let scaledImageHeight = imageSize.height * scale

        let offsetX = (viewSize.width - scaledImageWidth) / 2
        let offsetY = (viewSize.height - scaledImageHeight) / 2

        // Vision framework uses bottom-left origin
        let x = rect.origin.x * scaledImageWidth + offsetX
        let y = (1 - rect.origin.y - rect.height) * scaledImageHeight + offsetY
        let width = rect.width * scaledImageWidth
        let height = rect.height * scaledImageHeight

        return CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Landmark Points View

struct LandmarkPointsView: View {

    let points: [CGPoint]
    let imageSize: CGSize
    let viewSize: CGSize
    let color: Color

    var body: some View {
        Path { path in
            let convertedPoints = points.map { convertPoint($0) }

            guard let firstPoint = convertedPoints.first else { return }

            path.move(to: firstPoint)
            for point in convertedPoints.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(color, lineWidth: 1.5)
    }

    private func convertPoint(_ point: CGPoint) -> CGPoint {
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        let scale = min(scaleX, scaleY)

        let scaledImageWidth = imageSize.width * scale
        let scaledImageHeight = imageSize.height * scale

        let offsetX = (viewSize.width - scaledImageWidth) / 2
        let offsetY = (viewSize.height - scaledImageHeight) / 2

        // Vision framework uses bottom-left origin
        let x = point.x * scaledImageWidth + offsetX
        let y = (1 - point.y) * scaledImageHeight + offsetY

        return CGPoint(x: x, y: y)
    }
}

// MARK: - ROI Overlay Debug View

struct ROIOverlayDebugView: View {

    let roiSet: FaceROISet
    let imageSize: CGSize
    let viewSize: CGSize
    let onTap: ((ROIType, CGPoint) -> Void)?

    var body: some View {
        ForEach(Array(roiSet.rois.keys), id: \.self) { roiType in
            if let roiData = roiSet.rois[roiType] {
                // Convert ROIData to ROIDisplayInfo
                let rect = CGRect(
                    x: CGFloat(roiData.bounds.minU) * imageSize.width,
                    y: CGFloat(roiData.bounds.minV) * imageSize.height,
                    width: CGFloat(roiData.bounds.maxU - roiData.bounds.minU) * imageSize.width,
                    height: CGFloat(roiData.bounds.maxV - roiData.bounds.minV) * imageSize.height
                )
                let roiDisplayInfo = ROIDisplayInfo(type: roiType, imageRect: rect, confidence: 1.0, scaleFactorIPD: 1.0)

                DebugROIRectangleView(
                    roi: roiDisplayInfo,
                    roiType: roiType,
                    imageSize: imageSize,
                    viewSize: viewSize,
                    onTap: onTap
                )
            }
        }
    }
}

struct DebugROIRectangleView: View {

    let roi: ROIDisplayInfo
    let roiType: ROIType
    let imageSize: CGSize
    let viewSize: CGSize
    let onTap: ((ROIType, CGPoint) -> Void)?

    var body: some View {
        let rect = convertedRect

        Rectangle()
            .stroke(colorForROI(roiType), lineWidth: 1.5)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .overlay(
                Text(roiType.displayName)
                    .font(.app(size: 8, weight: .bold))
                    .foregroundColor(colorForROI(roiType))
                    .padding(2)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .position(x: rect.midX, y: rect.minY - 8)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?(roiType, CGPoint(x: rect.midX, y: rect.midY))
            }
    }

    private var convertedRect: CGRect {
        // Use the imageRect from ROIDisplayInfo
        convertNormalizedRect(roi.imageRect, to: viewSize, from: imageSize)
    }

    private func colorForROI(_ type: ROIType) -> Color {
        switch type {
        case .leftCheek, .rightCheek:
            return .pink
        case .forehead:
            return .blue
        case .chin:
            return .orange
        case .noseBridge:
            return .green
        }
    }

    private func convertNormalizedRect(_ rect: CGRect, to viewSize: CGSize, from imageSize: CGSize) -> CGRect {
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        let scale = min(scaleX, scaleY)

        let scaledImageWidth = imageSize.width * scale
        let scaledImageHeight = imageSize.height * scale

        let offsetX = (viewSize.width - scaledImageWidth) / 2
        let offsetY = (viewSize.height - scaledImageHeight) / 2

        // Vision uses bottom-left origin
        let x = rect.origin.x * scaledImageWidth + offsetX
        let y = (1 - rect.origin.y - rect.height) * scaledImageHeight + offsetY
        let width = rect.width * scaledImageWidth
        let height = rect.height * scaledImageHeight

        return CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black

        // Simulated camera preview
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Text("Camera Preview")
                    .foregroundColor(.white)
            )

        // Overlay
        DebugOverlayView(
            faces: [],
            roiSets: [],
            imageSize: CGSize(width: 1920, height: 1080),
            showFaceBounds: true,
            showLandmarks: true,
            onROITap: nil
        )
    }
}
