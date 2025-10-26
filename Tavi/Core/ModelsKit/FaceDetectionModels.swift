//
//  FaceDetectionModels.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import CoreGraphics
import Vision

// MARK: - Face Detection Result

public struct FaceDetectionResult {
    /// Normalized bounding box (0-1 coordinate space)
    public let boundingBox: CGRect

    /// All detected facial landmarks
    public let landmarks: FaceLandmarks

    /// Confidence score (0-1)
    public let confidence: Float

    /// Roll angle in degrees (-180 to 180)
    public let roll: CGFloat?

    /// Yaw angle in degrees (-90 to 90)
    public let yaw: CGFloat?

    /// Pitch angle in degrees (-90 to 90)
    public let pitch: CGFloat?

    public init(
        boundingBox: CGRect,
        landmarks: FaceLandmarks,
        confidence: Float,
        roll: CGFloat? = nil,
        yaw: CGFloat? = nil,
        pitch: CGFloat? = nil
    ) {
        self.boundingBox = boundingBox
        self.landmarks = landmarks
        self.confidence = confidence
        self.roll = roll
        self.yaw = yaw
        self.pitch = pitch
    }
}

// MARK: - Face Landmarks

public struct FaceLandmarks {
    /// All detected landmark regions
    public let allPoints: [CGPoint]

    // Specific facial features
    public let leftEye: [CGPoint]
    public let rightEye: [CGPoint]
    public let leftEyebrow: [CGPoint]
    public let rightEyebrow: [CGPoint]
    public let nose: [CGPoint]
    public let noseCrest: [CGPoint]
    public let medianLine: [CGPoint]
    public let outerLips: [CGPoint]
    public let innerLips: [CGPoint]
    public let leftPupil: CGPoint?
    public let rightPupil: CGPoint?
    public let faceContour: [CGPoint]

    public init(
        allPoints: [CGPoint],
        leftEye: [CGPoint],
        rightEye: [CGPoint],
        leftEyebrow: [CGPoint],
        rightEyebrow: [CGPoint],
        nose: [CGPoint],
        noseCrest: [CGPoint],
        medianLine: [CGPoint],
        outerLips: [CGPoint],
        innerLips: [CGPoint],
        leftPupil: CGPoint?,
        rightPupil: CGPoint?,
        faceContour: [CGPoint]
    ) {
        self.allPoints = allPoints
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.leftEyebrow = leftEyebrow
        self.rightEyebrow = rightEyebrow
        self.nose = nose
        self.noseCrest = noseCrest
        self.medianLine = medianLine
        self.outerLips = outerLips
        self.innerLips = innerLips
        self.leftPupil = leftPupil
        self.rightPupil = rightPupil
        self.faceContour = faceContour
    }

    /// Calculate the angle between the eyes (for alignment)
    public func eyeAngle() -> CGFloat? {
        guard let leftPupil = leftPupil,
              let rightPupil = rightPupil else {
            // Fallback to eye centers if pupils not available
            guard !leftEye.isEmpty, !rightEye.isEmpty else { return nil }
            let leftCenter = averagePoint(leftEye)
            let rightCenter = averagePoint(rightEye)
            return angleBetweenPoints(leftCenter, rightCenter)
        }

        return angleBetweenPoints(leftPupil, rightPupil)
    }

    /// Calculate center point between eyes
    public func eyeCenter() -> CGPoint? {
        guard let leftPupil = leftPupil,
              let rightPupil = rightPupil else {
            guard !leftEye.isEmpty, !rightEye.isEmpty else { return nil }
            let leftCenter = averagePoint(leftEye)
            let rightCenter = averagePoint(rightEye)
            return CGPoint(
                x: (leftCenter.x + rightCenter.x) / 2,
                y: (leftCenter.y + rightCenter.y) / 2
            )
        }

        return CGPoint(
            x: (leftPupil.x + rightPupil.x) / 2,
            y: (leftPupil.y + rightPupil.y) / 2
        )
    }

    /// Calculate distance between eyes
    public func eyeDistance() -> CGFloat? {
        guard let leftPupil = leftPupil,
              let rightPupil = rightPupil else {
            guard !leftEye.isEmpty, !rightEye.isEmpty else { return nil }
            let leftCenter = averagePoint(leftEye)
            let rightCenter = averagePoint(rightEye)
            return distance(leftCenter, rightCenter)
        }

        return distance(leftPupil, rightPupil)
    }

    // MARK: - Helper Methods

    private func averagePoint(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    private func angleBetweenPoints(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let deltaY = p2.y - p1.y
        let deltaX = p2.x - p1.x
        return atan2(deltaY, deltaX)
    }

    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - Aligned Face

public struct AlignedFace {
    /// The aligned and cropped face image
    public let image: CGImage

    /// Original detection result
    public let detectionResult: FaceDetectionResult

    /// Rotation angle applied (in radians)
    public let rotationAngle: CGFloat

    /// Scale factor applied
    public let scaleFactor: CGFloat

    public init(
        image: CGImage,
        detectionResult: FaceDetectionResult,
        rotationAngle: CGFloat,
        scaleFactor: CGFloat
    ) {
        self.image = image
        self.detectionResult = detectionResult
        self.rotationAngle = rotationAngle
        self.scaleFactor = scaleFactor
    }
}
