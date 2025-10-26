//
//  ROIBuilder.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import CoreGraphics
import UIKit
import CoreImage

public class ROIBuilder {

    // MARK: - Properties

    private let configuration: ROIConfiguration

    // MARK: - Initialization

    public init(configuration: ROIConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - ROI Computation

    /// Compute all ROIs for a detected face
    public func computeROIs(
        for faceResult: FaceDetectionResult,
        imageSize: CGSize
    ) throws -> FaceROISet {
        let landmarks = faceResult.landmarks

        // Ensure we have pupils for reliable measurements
        guard let leftPupil = landmarks.leftPupil,
              let rightPupil = landmarks.rightPupil else {
            throw ROIBuilderError.insufficientLandmarks
        }

        // Calculate inter-pupil distance in normalized coordinates
        let dx = rightPupil.x - leftPupil.x
        let dy = rightPupil.y - leftPupil.y
        let ipdNormalized = sqrt(dx * dx + dy * dy)

        // Convert to image coordinates
        let faceBounds = convertBoundingBox(faceResult.boundingBox, imageSize: imageSize)
        let ipdPixels = ipdNormalized * faceBounds.width

        // Compute each ROI
        var rois: [ROIType: FaceROI] = [:]

        // Left cheek
        if let leftCheekROI = computeLeftCheekROI(
            landmarks: landmarks,
            faceBounds: faceBounds,
            imageSize: imageSize,
            ipd: ipdPixels
        ) {
            rois[.leftCheek] = leftCheekROI
        }

        // Right cheek
        if let rightCheekROI = computeRightCheekROI(
            landmarks: landmarks,
            faceBounds: faceBounds,
            imageSize: imageSize,
            ipd: ipdPixels
        ) {
            rois[.rightCheek] = rightCheekROI
        }

        // Forehead center
        if let foreheadROI = computeForeheadCenterROI(
            landmarks: landmarks,
            faceBounds: faceBounds,
            imageSize: imageSize,
            ipd: ipdPixels
        ) {
            rois[.foreheadCenter] = foreheadROI
        }

        // Chin center
        if let chinROI = computeChinCenterROI(
            landmarks: landmarks,
            faceBounds: faceBounds,
            imageSize: imageSize,
            ipd: ipdPixels
        ) {
            rois[.chinCenter] = chinROI
        }

        guard !rois.isEmpty else {
            throw ROIBuilderError.roiComputationFailed
        }

        return FaceROISet(
            rois: rois,
            faceResult: faceResult,
            interPupilDistance: ipdPixels,
            faceBounds: faceBounds
        )
    }

    // MARK: - Individual ROI Computation

    private func computeLeftCheekROI(
        landmarks: FaceLandmarks,
        faceBounds: CGRect,
        imageSize: CGSize,
        ipd: CGFloat
    ) -> FaceROI? {
        // Left cheek is positioned between left eye and mouth, on the left side
        guard let leftPupil = landmarks.leftPupil,
              !landmarks.nose.isEmpty,
              !landmarks.outerLips.isEmpty else {
            return nil
        }

        // Calculate center point for left cheek
        // Position: Horizontally between left pupil and left face edge
        //           Vertically between eye and mouth
        let leftPupilImage = convertPoint(leftPupil, faceBounds: faceBounds)
        let mouthCenter = averagePoint(landmarks.outerLips.map { convertPoint($0, faceBounds: faceBounds) })

        // Move left from pupil by ~0.6 * IPD
        let centerX = leftPupilImage.x - (0.6 * ipd)

        // Position vertically between eye and mouth
        let centerY = leftPupilImage.y + (mouthCenter.y - leftPupilImage.y) * 0.4

        let center = CGPoint(x: centerX, y: centerY)

        return createROI(
            type: .leftCheek,
            center: center,
            ipd: ipd,
            faceBounds: faceBounds,
            imageSize: imageSize,
            confidence: landmarks.leftEye.isEmpty ? 0.7 : 0.95
        )
    }

    private func computeRightCheekROI(
        landmarks: FaceLandmarks,
        faceBounds: CGRect,
        imageSize: CGSize,
        ipd: CGFloat
    ) -> FaceROI? {
        // Right cheek is positioned between right eye and mouth, on the right side
        guard let rightPupil = landmarks.rightPupil,
              !landmarks.nose.isEmpty,
              !landmarks.outerLips.isEmpty else {
            return nil
        }

        // Calculate center point for right cheek
        let rightPupilImage = convertPoint(rightPupil, faceBounds: faceBounds)
        let mouthCenter = averagePoint(landmarks.outerLips.map { convertPoint($0, faceBounds: faceBounds) })

        // Move right from pupil by ~0.6 * IPD
        let centerX = rightPupilImage.x + (0.6 * ipd)

        // Position vertically between eye and mouth
        let centerY = rightPupilImage.y + (mouthCenter.y - rightPupilImage.y) * 0.4

        let center = CGPoint(x: centerX, y: centerY)

        return createROI(
            type: .rightCheek,
            center: center,
            ipd: ipd,
            faceBounds: faceBounds,
            imageSize: imageSize,
            confidence: landmarks.rightEye.isEmpty ? 0.7 : 0.95
        )
    }

    private func computeForeheadCenterROI(
        landmarks: FaceLandmarks,
        faceBounds: CGRect,
        imageSize: CGSize,
        ipd: CGFloat
    ) -> FaceROI? {
        // Forehead center is above the eyes, centered horizontally
        guard let leftPupil = landmarks.leftPupil,
              let rightPupil = landmarks.rightPupil else {
            return nil
        }

        let leftPupilImage = convertPoint(leftPupil, faceBounds: faceBounds)
        let rightPupilImage = convertPoint(rightPupil, faceBounds: faceBounds)

        // Center horizontally between pupils
        let centerX = (leftPupilImage.x + rightPupilImage.x) / 2

        // Position above eyes by ~1.2 * IPD
        let eyeLineY = (leftPupilImage.y + rightPupilImage.y) / 2
        let centerY = eyeLineY - (1.2 * ipd)

        let center = CGPoint(x: centerX, y: centerY)

        return createROI(
            type: .foreheadCenter,
            center: center,
            ipd: ipd,
            faceBounds: faceBounds,
            imageSize: imageSize,
            confidence: 0.9
        )
    }

    private func computeChinCenterROI(
        landmarks: FaceLandmarks,
        faceBounds: CGRect,
        imageSize: CGSize,
        ipd: CGFloat
    ) -> FaceROI? {
        // Chin center is below the mouth, centered horizontally
        guard let leftPupil = landmarks.leftPupil,
              let rightPupil = landmarks.rightPupil,
              !landmarks.outerLips.isEmpty else {
            return nil
        }

        let leftPupilImage = convertPoint(leftPupil, faceBounds: faceBounds)
        let rightPupilImage = convertPoint(rightPupil, faceBounds: faceBounds)

        // Center horizontally between pupils
        let centerX = (leftPupilImage.x + rightPupilImage.x) / 2

        // Get mouth bottom
        let mouthPoints = landmarks.outerLips.map { convertPoint($0, faceBounds: faceBounds) }
        let mouthBottom = mouthPoints.map { $0.y }.max() ?? 0

        // Position below mouth by ~0.8 * IPD
        let centerY = mouthBottom + (0.8 * ipd)

        let center = CGPoint(x: centerX, y: centerY)

        return createROI(
            type: .chinCenter,
            center: center,
            ipd: ipd,
            faceBounds: faceBounds,
            imageSize: imageSize,
            confidence: landmarks.outerLips.count > 10 ? 0.9 : 0.75
        )
    }

    // MARK: - ROI Creation Helper

    private func createROI(
        type: ROIType,
        center: CGPoint,
        ipd: CGFloat,
        faceBounds: CGRect,
        imageSize: CGSize,
        confidence: Float
    ) -> FaceROI {
        // Calculate ROI size based on IPD
        let baseSize = ipd * configuration.sizeRelativeToIPD
        let roiSize = CGSize(width: baseSize, height: baseSize)

        // Clamp to min/max sizes
        let clampedWidth = min(max(roiSize.width, configuration.minimumSize.width), configuration.maximumSize.width)
        let clampedHeight = min(max(roiSize.height, configuration.minimumSize.height), configuration.maximumSize.height)
        let finalSize = CGSize(width: clampedWidth, height: clampedHeight)

        // Apply padding
        let paddedWidth = finalSize.width * (1 + configuration.padding)
        let paddedHeight = finalSize.height * (1 + configuration.padding)

        // Create rectangle centered on point
        let imageRect = CGRect(
            x: center.x - paddedWidth / 2,
            y: center.y - paddedHeight / 2,
            width: paddedWidth,
            height: paddedHeight
        )

        // Ensure ROI is within image bounds
        let clampedRect = clampToImageBounds(imageRect, imageSize: imageSize)

        // Compute normalized rect (relative to face bounds)
        let normalizedRect = CGRect(
            x: (clampedRect.origin.x - faceBounds.origin.x) / faceBounds.width,
            y: (clampedRect.origin.y - faceBounds.origin.y) / faceBounds.height,
            width: clampedRect.width / faceBounds.width,
            height: clampedRect.height / faceBounds.height
        )

        return FaceROI(
            type: type,
            normalizedRect: normalizedRect,
            imageRect: clampedRect,
            scaleFactorIPD: configuration.sizeRelativeToIPD,
            confidence: confidence
        )
    }

    // MARK: - Image Extraction

    /// Extract ROI images from a face image
    public func extractROIImages(
        from faceImage: CGImage,
        using roiSet: FaceROISet
    ) throws -> [ExtractedROIImage] {
        var extractedImages: [ExtractedROIImage] = []

        for roi in roiSet.allROIs {
            if let extracted = try? extractSingleROI(from: faceImage, roi: roi) {
                extractedImages.append(extracted)
            }
        }

        guard !extractedImages.isEmpty else {
            throw ROIBuilderError.extractionFailed
        }

        return extractedImages
    }

    /// Extract a single ROI image
    private func extractSingleROI(
        from image: CGImage,
        roi: FaceROI
    ) throws -> ExtractedROIImage {
        // Ensure rect is within image bounds
        let imageSize = CGSize(width: image.width, height: image.height)
        let clampedRect = clampToImageBounds(roi.imageRect, imageSize: imageSize)

        // Convert to integer coordinates
        let intRect = CGRect(
            x: round(clampedRect.origin.x),
            y: round(clampedRect.origin.y),
            width: round(clampedRect.size.width),
            height: round(clampedRect.size.height)
        )

        guard let croppedImage = image.cropping(to: intRect) else {
            throw ROIBuilderError.extractionFailed
        }

        return ExtractedROIImage(
            type: roi.type,
            image: croppedImage,
            roi: roi
        )
    }

    /// Extract ROI images from a pixel buffer
    public func extractROIImages(
        from pixelBuffer: CVPixelBuffer,
        using roiSet: FaceROISet
    ) throws -> [ExtractedROIImage] {
        // Convert pixel buffer to CGImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw ROIBuilderError.imageConversionFailed
        }

        return try extractROIImages(from: cgImage, using: roiSet)
    }

    // MARK: - Helper Methods

    private func convertBoundingBox(_ box: CGRect, imageSize: CGSize) -> CGRect {
        // Vision uses bottom-left origin, convert to top-left
        return CGRect(
            x: box.origin.x * imageSize.width,
            y: (1 - box.origin.y - box.height) * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height
        )
    }

    private func convertPoint(_ point: CGPoint, faceBounds: CGRect) -> CGPoint {
        // Point is already in normalized coordinates relative to face bounds
        return CGPoint(
            x: faceBounds.origin.x + point.x * faceBounds.width,
            y: faceBounds.origin.y + point.y * faceBounds.height
        )
    }

    private func averagePoint(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    private func clampToImageBounds(_ rect: CGRect, imageSize: CGSize) -> CGRect {
        let x = max(0, min(rect.origin.x, imageSize.width - 1))
        let y = max(0, min(rect.origin.y, imageSize.height - 1))
        let maxWidth = imageSize.width - x
        let maxHeight = imageSize.height - y
        let width = max(1, min(rect.width, maxWidth))
        let height = max(1, min(rect.height, maxHeight))

        return CGRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - Coordinate Conversion for Visualization

    /// Convert ROI to view coordinates for SwiftUI overlay
    public static func convertROIToViewCoordinates(
        _ roi: FaceROI,
        imageSize: CGSize,
        viewSize: CGSize,
        isMirrored: Bool = false
    ) -> CGRect {
        var rect = roi.imageRect

        // Mirror if needed
        if isMirrored {
            rect.origin.x = imageSize.width - rect.origin.x - rect.width
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
            x: rect.origin.x * scale + offsetX,
            y: rect.origin.y * scale + offsetY,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }
}

// MARK: - Error Types

public enum ROIBuilderError: LocalizedError {
    case insufficientLandmarks
    case roiComputationFailed
    case extractionFailed
    case imageConversionFailed

    public var errorDescription: String? {
        switch self {
        case .insufficientLandmarks:
            return "Insufficient landmarks to compute ROIs"
        case .roiComputationFailed:
            return "Failed to compute ROIs"
        case .extractionFailed:
            return "Failed to extract ROI images"
        case .imageConversionFailed:
            return "Failed to convert image format"
        }
    }
}
