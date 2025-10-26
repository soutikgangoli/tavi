//
//  ROIModels.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import CoreGraphics

// MARK: - ROI Type

public enum ROIType: String, CaseIterable {
    case leftCheek = "Left Cheek"
    case rightCheek = "Right Cheek"
    case foreheadCenter = "Forehead Center"
    case chinCenter = "Chin Center"

    public var displayName: String {
        return self.rawValue
    }

    public var identifier: String {
        switch self {
        case .leftCheek: return "left_cheek"
        case .rightCheek: return "right_cheek"
        case .foreheadCenter: return "forehead_center"
        case .chinCenter: return "chin_center"
        }
    }
}

// MARK: - Face ROI

public struct FaceROI {
    /// Type of region
    public let type: ROIType

    /// Normalized rectangle (0-1 coordinate space relative to face bounds)
    public let normalizedRect: CGRect

    /// Rectangle in image coordinates
    public let imageRect: CGRect

    /// Scale factor relative to inter-pupil distance
    public let scaleFactorIPD: CGFloat

    /// Confidence score (0-1) - based on landmark quality
    public let confidence: Float

    public init(
        type: ROIType,
        normalizedRect: CGRect,
        imageRect: CGRect,
        scaleFactorIPD: CGFloat,
        confidence: Float
    ) {
        self.type = type
        self.normalizedRect = normalizedRect
        self.imageRect = imageRect
        self.scaleFactorIPD = scaleFactorIPD
        self.confidence = confidence
    }
}

// MARK: - Face ROI Set

public struct FaceROISet {
    /// All computed ROIs for a face
    public let rois: [ROIType: FaceROI]

    /// Face detection result used for computation
    public let faceResult: FaceDetectionResult

    /// Inter-pupil distance in pixels
    public let interPupilDistance: CGFloat

    /// Face bounding box in image coordinates
    public let faceBounds: CGRect

    public init(
        rois: [ROIType: FaceROI],
        faceResult: FaceDetectionResult,
        interPupilDistance: CGFloat,
        faceBounds: CGRect
    ) {
        self.rois = rois
        self.faceResult = faceResult
        self.interPupilDistance = interPupilDistance
        self.faceBounds = faceBounds
    }

    // Convenience accessors
    public var leftCheek: FaceROI? { rois[.leftCheek] }
    public var rightCheek: FaceROI? { rois[.rightCheek] }
    public var foreheadCenter: FaceROI? { rois[.foreheadCenter] }
    public var chinCenter: FaceROI? { rois[.chinCenter] }

    /// Get all ROIs as an array
    public var allROIs: [FaceROI] {
        return Array(rois.values)
    }
}

// MARK: - Extracted ROI Image

public struct ExtractedROIImage {
    /// Type of region
    public let type: ROIType

    /// Extracted image
    public let image: CGImage

    /// Original ROI definition
    public let roi: FaceROI

    /// Size of extracted image
    public var size: CGSize {
        CGSize(width: image.width, height: image.height)
    }

    public init(type: ROIType, image: CGImage, roi: FaceROI) {
        self.type = type
        self.image = image
        self.roi = roi
    }
}

// MARK: - ROI Configuration

public struct ROIConfiguration {
    /// Size of ROI relative to IPD (inter-pupil distance)
    /// Default: 1.5 (ROI width/height = 1.5 * IPD)
    public let sizeRelativeToIPD: CGFloat

    /// Minimum ROI size in pixels
    public let minimumSize: CGSize

    /// Maximum ROI size in pixels
    public let maximumSize: CGSize

    /// Padding around computed center point (as fraction of ROI size)
    public let padding: CGFloat

    public init(
        sizeRelativeToIPD: CGFloat = 1.5,
        minimumSize: CGSize = CGSize(width: 50, height: 50),
        maximumSize: CGSize = CGSize(width: 300, height: 300),
        padding: CGFloat = 0.1
    ) {
        self.sizeRelativeToIPD = sizeRelativeToIPD
        self.minimumSize = minimumSize
        self.maximumSize = maximumSize
        self.padding = padding
    }

    public static let `default` = ROIConfiguration()

    /// Configuration for high-resolution ROI extraction
    public static let highResolution = ROIConfiguration(
        sizeRelativeToIPD: 2.0,
        minimumSize: CGSize(width: 100, height: 100),
        maximumSize: CGSize(width: 512, height: 512),
        padding: 0.15
    )

    /// Configuration for compact ROIs
    public static let compact = ROIConfiguration(
        sizeRelativeToIPD: 1.0,
        minimumSize: CGSize(width: 40, height: 40),
        maximumSize: CGSize(width: 200, height: 200),
        padding: 0.05
    )
}
