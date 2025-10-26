//
//  CaptureModels.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import CoreGraphics
import UIKit

// MARK: - Captured Frame

public struct CapturedFrame {
    /// Captured image
    public let image: CGImage

    /// Face detection result
    public let faceResult: FaceDetectionResult

    /// Timestamp of capture
    public let timestamp: Date

    /// Blur score (Laplacian variance)
    /// Higher = sharper, Lower = blurrier
    public let blurScore: Double

    /// Whether frame passed blur threshold
    public let isSharp: Bool

    public init(
        image: CGImage,
        faceResult: FaceDetectionResult,
        timestamp: Date,
        blurScore: Double,
        isSharp: Bool
    ) {
        self.image = image
        self.faceResult = faceResult
        self.timestamp = timestamp
        self.blurScore = blurScore
        self.isSharp = isSharp
    }
}

// MARK: - Aligned Frame

public struct AlignedFrame {
    /// Aligned image
    public let image: CGImage

    /// Original captured frame
    public let originalFrame: CapturedFrame

    /// Transformation applied
    public let transform: CGAffineTransform

    public init(
        image: CGImage,
        originalFrame: CapturedFrame,
        transform: CGAffineTransform
    ) {
        self.image = image
        self.originalFrame = originalFrame
        self.transform = transform
    }
}

// MARK: - Capture Result

public struct CaptureResult {
    /// Combined (median-filtered) face image
    public let combinedImage: CGImage

    /// Individual captured frames (sharp ones)
    public let frames: [CapturedFrame]

    /// Aligned frames used for combining
    public let alignedFrames: [AlignedFrame]

    /// Extracted ROI images from combined image
    public let roiImages: [ExtractedROIImage]

    /// Face detection result from reference frame
    public let faceResult: FaceDetectionResult

    /// ROI set from reference frame
    public let roiSet: FaceROISet

    /// Statistics
    public let totalFramesCaptured: Int
    public let sharpFramesUsed: Int
    public let captureTime: TimeInterval
    public let averageBlurScore: Double

    public init(
        combinedImage: CGImage,
        frames: [CapturedFrame],
        alignedFrames: [AlignedFrame],
        roiImages: [ExtractedROIImage],
        faceResult: FaceDetectionResult,
        roiSet: FaceROISet,
        totalFramesCaptured: Int,
        sharpFramesUsed: Int,
        captureTime: TimeInterval,
        averageBlurScore: Double
    ) {
        self.combinedImage = combinedImage
        self.frames = frames
        self.alignedFrames = alignedFrames
        self.roiImages = roiImages
        self.faceResult = faceResult
        self.roiSet = roiSet
        self.totalFramesCaptured = totalFramesCaptured
        self.sharpFramesUsed = sharpFramesUsed
        self.captureTime = captureTime
        self.averageBlurScore = averageBlurScore
    }
}

// MARK: - Capture Progress

public enum CaptureProgress {
    case idle
    case capturing(frame: Int, total: Int)
    case processingBlur(frame: Int, total: Int)
    case aligning(frame: Int, total: Int)
    case combining
    case extractingROIs
    case completed(CaptureResult)
    case failed(Error)

    public var isActive: Bool {
        switch self {
        case .idle, .completed, .failed:
            return false
        default:
            return true
        }
    }

    public var progressPercentage: Double {
        switch self {
        case .idle:
            return 0.0
        case .capturing(let frame, let total):
            return Double(frame) / Double(total) * 0.4 // 40% for capture
        case .processingBlur(let frame, let total):
            return 0.4 + (Double(frame) / Double(total) * 0.2) // 20% for blur detection
        case .aligning(let frame, let total):
            return 0.6 + (Double(frame) / Double(total) * 0.2) // 20% for alignment
        case .combining:
            return 0.8 // 80%
        case .extractingROIs:
            return 0.9 // 90%
        case .completed:
            return 1.0 // 100%
        case .failed:
            return 0.0
        }
    }

    public var description: String {
        switch self {
        case .idle:
            return "Ready to capture"
        case .capturing(let frame, let total):
            return "Capturing frame \(frame)/\(total)"
        case .processingBlur(let frame, let total):
            return "Analyzing sharpness \(frame)/\(total)"
        case .aligning(let frame, let total):
            return "Aligning frame \(frame)/\(total)"
        case .combining:
            return "Combining frames"
        case .extractingROIs:
            return "Extracting regions"
        case .completed:
            return "Capture complete"
        case .failed(let error):
            return "Failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Capture Configuration

public struct CaptureConfiguration {
    /// Number of frames to capture
    public let frameCount: Int

    /// Total capture duration in seconds
    public let captureDuration: TimeInterval

    /// Blur threshold (Laplacian variance)
    /// Frames below this are considered blurry and rejected
    public let blurThreshold: Double

    /// Minimum number of sharp frames required
    public let minimumSharpFrames: Int

    /// Size of aligned output images
    public let alignedImageSize: CGSize

    public init(
        frameCount: Int = 5,
        captureDuration: TimeInterval = 1.5,
        blurThreshold: Double = 100.0,
        minimumSharpFrames: Int = 3,
        alignedImageSize: CGSize = CGSize(width: 1024, height: 1024)
    ) {
        self.frameCount = frameCount
        self.captureDuration = captureDuration
        self.blurThreshold = blurThreshold
        self.minimumSharpFrames = minimumSharpFrames
        self.alignedImageSize = alignedImageSize
    }

    public static let `default` = CaptureConfiguration()

    /// High quality capture (more frames, stricter blur threshold)
    public static let highQuality = CaptureConfiguration(
        frameCount: 7,
        captureDuration: 2.0,
        blurThreshold: 150.0,
        minimumSharpFrames: 5,
        alignedImageSize: CGSize(width: 1536, height: 1536)
    )

    /// Fast capture (fewer frames, faster)
    public static let fast = CaptureConfiguration(
        frameCount: 3,
        captureDuration: 1.0,
        blurThreshold: 80.0,
        minimumSharpFrames: 2,
        alignedImageSize: CGSize(width: 768, height: 768)
    )
}

// MARK: - Capture Error

public enum CaptureError: LocalizedError {
    case noFaceDetected
    case insufficientSharpFrames(captured: Int, required: Int)
    case alignmentFailed
    case combiningFailed
    case roiExtractionFailed

    public var errorDescription: String? {
        switch self {
        case .noFaceDetected:
            return "No face detected in frame"
        case .insufficientSharpFrames(let captured, let required):
            return "Only \(captured) sharp frames captured, need \(required)"
        case .alignmentFailed:
            return "Failed to align frames"
        case .combiningFailed:
            return "Failed to combine frames"
        case .roiExtractionFailed:
            return "Failed to extract ROI images"
        }
    }
}
