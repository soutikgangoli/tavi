//
//  FaceDetector.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Vision
import CoreImage
import CoreGraphics
import UIKit
import Accelerate

public class FaceDetector {

    // MARK: - Properties

    private let detectionQueue = DispatchQueue(label: "com.tavi.facedetection", qos: .userInitiated)
    private var faceDetectionRequest: VNDetectFaceLandmarksRequest?

    // MARK: - Initialization

    public init() {
        setupDetectionRequest()
    }

    private func setupDetectionRequest() {
        faceDetectionRequest = VNDetectFaceLandmarksRequest()
        faceDetectionRequest?.revision = VNDetectFaceLandmarksRequestRevision3
    }

    // MARK: - Face Detection

    /// Detect faces in a CVPixelBuffer
    public func detectFaces(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation = .up) async throws -> [FaceDetectionResult] {
        guard let request = faceDetectionRequest else {
            throw FaceDetectionError.requestNotInitialized
        }

        return try await withCheckedThrowingContinuation { continuation in
            detectionQueue.async {
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

                do {
                    try handler.perform([request])

                    guard let observations = request.results as? [VNFaceObservation] else {
                        continuation.resume(returning: [])
                        return
                    }

                    let results = observations.compactMap { self.processFaceObservation($0) }
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: FaceDetectionError.detectionFailed(error))
                }
            }
        }
    }

    /// Detect faces in a CGImage
    public func detectFaces(in image: CGImage, orientation: CGImagePropertyOrientation = .up) async throws -> [FaceDetectionResult] {
        guard let request = faceDetectionRequest else {
            throw FaceDetectionError.requestNotInitialized
        }

        return try await withCheckedThrowingContinuation { continuation in
            detectionQueue.async {
                let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])

                do {
                    try handler.perform([request])

                    guard let observations = request.results as? [VNFaceObservation] else {
                        continuation.resume(returning: [])
                        return
                    }

                    let results = observations.compactMap { self.processFaceObservation($0) }
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: FaceDetectionError.detectionFailed(error))
                }
            }
        }
    }

    // MARK: - Face Alignment

    /// Extract and align a face from a pixel buffer
    public func alignedFace(from pixelBuffer: CVPixelBuffer, faceResult: FaceDetectionResult, targetSize: CGSize = CGSize(width: 512, height: 512)) throws -> AlignedFace? {
        // Convert pixel buffer to CGImage
        guard let cgImage = cgImage(from: pixelBuffer) else {
            throw FaceDetectionError.imageConversionFailed
        }

        return try alignedFace(from: cgImage, faceResult: faceResult, targetSize: targetSize)
    }

    /// Extract and align a face from a CGImage
    public func alignedFace(from image: CGImage, faceResult: FaceDetectionResult, targetSize: CGSize = CGSize(width: 512, height: 512)) throws -> AlignedFace? {
        let imageSize = CGSize(width: image.width, height: image.height)

        // Get eye positions for alignment
        guard let eyeAngle = faceResult.landmarks.eyeAngle(),
              let eyeCenter = faceResult.landmarks.eyeCenter(),
              let eyeDistance = faceResult.landmarks.eyeDistance() else {
            throw FaceDetectionError.insufficientLandmarks
        }

        // Convert normalized coordinates to image coordinates
        let eyeCenterInImage = CGPoint(
            x: eyeCenter.x * imageSize.width,
            y: (1 - eyeCenter.y) * imageSize.height // Flip Y coordinate
        )

        // Calculate rotation angle to make eyes level (negate for correct rotation)
        let rotationAngle = -eyeAngle

        // Calculate scale to fit target size
        let desiredEyeDistance = targetSize.width * 0.35 // Eyes should be 35% of face width
        let scaleFactor = desiredEyeDistance / (eyeDistance * imageSize.width)

        // Create transformation matrix
        var transform = CGAffineTransform.identity

        // 1. Translate to origin
        transform = transform.translatedBy(x: -eyeCenterInImage.x, y: -eyeCenterInImage.y)

        // 2. Rotate around eyes
        transform = transform.rotated(by: rotationAngle)

        // 3. Scale
        transform = transform.scaledBy(x: scaleFactor, y: scaleFactor)

        // 4. Translate to center of target image
        transform = transform.translatedBy(x: targetSize.width / 2, y: targetSize.height / 2)

        // Create output image
        guard let colorSpace = image.colorSpace else {
            throw FaceDetectionError.imageConversionFailed
        }

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw FaceDetectionError.imageConversionFailed
        }

        // Apply transformation and draw
        context.concatenate(transform)
        context.draw(image, in: CGRect(origin: .zero, size: imageSize))

        guard let alignedImage = context.makeImage() else {
            throw FaceDetectionError.imageConversionFailed
        }

        return AlignedFace(
            image: alignedImage,
            detectionResult: faceResult,
            rotationAngle: rotationAngle,
            scaleFactor: scaleFactor
        )
    }

    // MARK: - Private Helper Methods

    private func processFaceObservation(_ observation: VNFaceObservation) -> FaceDetectionResult? {
        guard let landmarks = observation.landmarks else {
            return nil
        }

        let faceLandmarks = extractLandmarks(from: landmarks, boundingBox: observation.boundingBox)

        return FaceDetectionResult(
            boundingBox: observation.boundingBox,
            landmarks: faceLandmarks,
            confidence: observation.confidence,
            roll: observation.roll?.doubleValue.map { CGFloat($0) },
            yaw: observation.yaw?.doubleValue.map { CGFloat($0) },
            pitch: observation.pitch?.doubleValue.map { CGFloat($0) }
        )
    }

    private func extractLandmarks(from landmarks: VNFaceLandmarks2D, boundingBox: CGRect) -> FaceLandmarks {
        var allPoints: [CGPoint] = []

        // Helper to convert landmark region to absolute points
        func points(from region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            guard let region = region else { return [] }
            let normalizedPoints = region.normalizedPoints
            return normalizedPoints.map { point in
                CGPoint(
                    x: boundingBox.origin.x + point.x * boundingBox.width,
                    y: boundingBox.origin.y + point.y * boundingBox.height
                )
            }
        }

        let leftEye = points(from: landmarks.leftEye)
        let rightEye = points(from: landmarks.rightEye)
        let leftEyebrow = points(from: landmarks.leftEyebrow)
        let rightEyebrow = points(from: landmarks.rightEyebrow)
        let nose = points(from: landmarks.nose)
        let noseCrest = points(from: landmarks.noseCrest)
        let medianLine = points(from: landmarks.medianLine)
        let outerLips = points(from: landmarks.outerLips)
        let innerLips = points(from: landmarks.innerLips)
        let faceContour = points(from: landmarks.faceContour)

        // Extract pupils
        let leftPupil = landmarks.leftPupil.map { pupilRegion in
            let pupilPoints = points(from: pupilRegion)
            return pupilPoints.first ?? averagePoint(leftEye)
        }

        let rightPupil = landmarks.rightPupil.map { pupilRegion in
            let pupilPoints = points(from: pupilRegion)
            return pupilPoints.first ?? averagePoint(rightEye)
        }

        // Collect all points
        allPoints.append(contentsOf: leftEye)
        allPoints.append(contentsOf: rightEye)
        allPoints.append(contentsOf: leftEyebrow)
        allPoints.append(contentsOf: rightEyebrow)
        allPoints.append(contentsOf: nose)
        allPoints.append(contentsOf: noseCrest)
        allPoints.append(contentsOf: medianLine)
        allPoints.append(contentsOf: outerLips)
        allPoints.append(contentsOf: innerLips)
        allPoints.append(contentsOf: faceContour)

        return FaceLandmarks(
            allPoints: allPoints,
            leftEye: leftEye,
            rightEye: rightEye,
            leftEyebrow: leftEyebrow,
            rightEyebrow: rightEyebrow,
            nose: nose,
            noseCrest: noseCrest,
            medianLine: medianLine,
            outerLips: outerLips,
            innerLips: innerLips,
            leftPupil: leftPupil,
            rightPupil: rightPupil,
            faceContour: faceContour
        )
    }

    private func averagePoint(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    private func cgImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }

    // MARK: - Coordinate Conversion Helpers

    /// Convert normalized Vision coordinates to view coordinates
    public static func convertFromNormalizedCoordinates(
        _ point: CGPoint,
        imageSize: CGSize,
        viewSize: CGSize,
        isMirrored: Bool = false
    ) -> CGPoint {
        // Vision uses bottom-left origin, need to flip Y
        var convertedPoint = CGPoint(
            x: point.x * imageSize.width,
            y: (1 - point.y) * imageSize.height
        )

        // Mirror if needed (for front camera)
        if isMirrored {
            convertedPoint.x = imageSize.width - convertedPoint.x
        }

        // Scale to view size
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        let scale = min(scaleX, scaleY)

        let scaledSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        let offsetX = (viewSize.width - scaledSize.width) / 2
        let offsetY = (viewSize.height - scaledSize.height) / 2

        return CGPoint(
            x: convertedPoint.x * scale + offsetX,
            y: convertedPoint.y * scale + offsetY
        )
    }

    /// Convert normalized bounding box to view coordinates
    public static func convertBoundingBox(
        _ box: CGRect,
        imageSize: CGSize,
        viewSize: CGSize,
        isMirrored: Bool = false
    ) -> CGRect {
        // Convert bottom-left origin to top-left
        let flippedBox = CGRect(
            x: box.origin.x,
            y: 1 - box.origin.y - box.height,
            width: box.width,
            height: box.height
        )

        var convertedBox = CGRect(
            x: flippedBox.origin.x * imageSize.width,
            y: flippedBox.origin.y * imageSize.height,
            width: flippedBox.width * imageSize.width,
            height: flippedBox.height * imageSize.height
        )

        // Mirror if needed
        if isMirrored {
            convertedBox.origin.x = imageSize.width - convertedBox.origin.x - convertedBox.width
        }

        // Scale to view size
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        let scale = min(scaleX, scaleY)

        let scaledSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        let offsetX = (viewSize.width - scaledSize.width) / 2
        let offsetY = (viewSize.height - scaledSize.height) / 2

        return CGRect(
            x: convertedBox.origin.x * scale + offsetX,
            y: convertedBox.origin.y * scale + offsetY,
            width: convertedBox.width * scale,
            height: convertedBox.height * scale
        )
    }
}

// MARK: - Error Types

public enum FaceDetectionError: LocalizedError {
    case requestNotInitialized
    case detectionFailed(Error)
    case insufficientLandmarks
    case imageConversionFailed

    public var errorDescription: String? {
        switch self {
        case .requestNotInitialized:
            return "Face detection request not initialized"
        case .detectionFailed(let error):
            return "Face detection failed: \(error.localizedDescription)"
        case .insufficientLandmarks:
            return "Insufficient landmarks for alignment"
        case .imageConversionFailed:
            return "Failed to convert image format"
        }
    }
}
