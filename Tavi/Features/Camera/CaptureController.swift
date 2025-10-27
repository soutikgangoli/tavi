//
//  CaptureController.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import CoreGraphics
import UIKit
import Combine

@MainActor
public class CaptureController: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var progress: CaptureProgress = .idle
    @Published public private(set) var lastResult: CaptureResult?

    // MARK: - Private Properties

    private let configuration: CaptureConfiguration
    private let faceDetector: FaceDetector
    private let roiBuilder: ROIBuilder
    private var capturedFrames: [CapturedFrame] = []
    private var isCapturing = false

    // MARK: - Initialization

    public init(
        configuration: CaptureConfiguration = .default,
        faceDetector: FaceDetector = FaceDetector(),
        roiBuilder: ROIBuilder = ROIBuilder()
    ) {
        self.configuration = configuration
        self.faceDetector = faceDetector
        self.roiBuilder = roiBuilder
    }

    // MARK: - Capture Control

    /// Start multi-frame capture
    public func startCapture(
        frameProvider: @escaping () async -> CVPixelBuffer?
    ) async throws -> CaptureResult {
        guard !isCapturing else {
            throw CaptureError.noFaceDetected // Return existing error
        }

        isCapturing = true
        capturedFrames = []
        progress = .idle

        let startTime = Date()

        defer {
            isCapturing = false
        }

        // Phase 1: Capture frames
        try await captureFrames(frameProvider: frameProvider)

        // Phase 2: Process blur scores
        try await processBlurScores()

        // Phase 3: Filter sharp frames
        let sharpFrames = filterSharpFrames()

        guard sharpFrames.count >= configuration.minimumSharpFrames else {
            progress = .failed(CaptureError.insufficientSharpFrames(
                captured: sharpFrames.count,
                required: configuration.minimumSharpFrames
            ))
            throw CaptureError.insufficientSharpFrames(
                captured: sharpFrames.count,
                required: configuration.minimumSharpFrames
            )
        }

        // Phase 4: Align frames
        progress = .aligning(frame: 0, total: sharpFrames.count)
        let alignedFrames = try await alignFrames(sharpFrames)

        // Phase 5: Median combine
        progress = .combining
        let combinedImage = try medianCombineFrames(alignedFrames)

        // Phase 6: Extract ROIs
        progress = .extractingROIs

        // Use reference frame (first sharp frame) for face detection and ROI computation
        let referenceFrame = sharpFrames[0]
        let imageSize = CGSize(width: referenceFrame.image.width, height: referenceFrame.image.height)
        let roiSet = try roiBuilder.computeROIs(for: referenceFrame.faceResult, imageSize: imageSize)
        let roiImages = try roiBuilder.extractROIImages(from: combinedImage, using: roiSet)

        let captureTime = Date().timeIntervalSince(startTime)
        let averageBlurScore = sharpFrames.map { $0.blurScore }.reduce(0.0, +) / Double(sharpFrames.count)

        let result = CaptureResult(
            combinedImage: combinedImage,
            frames: sharpFrames,
            alignedFrames: alignedFrames,
            roiImages: roiImages,
            faceResult: referenceFrame.faceResult,
            roiSet: roiSet,
            totalFramesCaptured: capturedFrames.count,
            sharpFramesUsed: sharpFrames.count,
            captureTime: captureTime,
            averageBlurScore: averageBlurScore
        )

        progress = .completed(result)
        lastResult = result

        return result
    }

    /// Cancel ongoing capture
    public func cancelCapture() {
        isCapturing = false
        capturedFrames = []
        progress = .idle
    }

    // MARK: - Private Capture Methods

    private func captureFrames(frameProvider: @escaping () async -> CVPixelBuffer?) async throws {
        let frameInterval = configuration.captureDuration / Double(configuration.frameCount)

        for frameIndex in 0..<configuration.frameCount {
            guard isCapturing else { break }

            progress = .capturing(frame: frameIndex + 1, total: configuration.frameCount)

            // Get frame from provider
            guard let pixelBuffer = await frameProvider() else {
                continue
            }

            // Detect face
            let faces = try await faceDetector.detectFaces(in: pixelBuffer, orientation: .up)

            guard let face = faces.first else {
                // No face detected, skip this frame
                continue
            }

            // Convert to CGImage
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                continue
            }

            // Create captured frame (blur score computed later)
            let frame = CapturedFrame(
                image: cgImage,
                faceResult: face,
                timestamp: Date(),
                blurScore: 0, // Computed in next phase
                isSharp: false
            )

            capturedFrames.append(frame)

            // Wait for next frame interval
            if frameIndex < configuration.frameCount - 1 {
                try await Task.sleep(nanoseconds: UInt64(frameInterval * 1_000_000_000))
            }
        }

        guard !capturedFrames.isEmpty else {
            throw CaptureError.noFaceDetected
        }
    }

    private func processBlurScores() async throws {
        for (index, frame) in capturedFrames.enumerated() {
            progress = .processingBlur(frame: index + 1, total: capturedFrames.count)

            let blurScore = await Task.detached(priority: .userInitiated) {
                ImageProcessing.computeBlurScore(for: frame.image)
            }.value

            let isSharp = blurScore >= configuration.blurThreshold

            // Update frame with blur score
            capturedFrames[index] = CapturedFrame(
                image: frame.image,
                faceResult: frame.faceResult,
                timestamp: frame.timestamp,
                blurScore: blurScore,
                isSharp: isSharp
            )
        }
    }

    private func filterSharpFrames() -> [CapturedFrame] {
        return capturedFrames.filter { $0.isSharp }
    }

    private func alignFrames(_ frames: [CapturedFrame]) async throws -> [AlignedFrame] {
        guard !frames.isEmpty else {
            throw CaptureError.alignmentFailed
        }

        var alignedFrames: [AlignedFrame] = []

        for (index, frame) in frames.enumerated() {
            progress = .aligning(frame: index + 1, total: frames.count)

            do {
                let alignedImage = try ImageProcessing.alignImage(
                    frame.image,
                    landmarks: frame.faceResult.landmarks,
                    targetSize: configuration.alignedImageSize
                )

                let aligned = AlignedFrame(
                    image: alignedImage,
                    originalFrame: frame,
                    transform: .identity // Actual transform computed in alignImage
                )

                alignedFrames.append(aligned)
            } catch {
                // Skip frames that fail to align
                print("Failed to align frame \(index): \(error)")
                continue
            }
        }

        guard !alignedFrames.isEmpty else {
            throw CaptureError.alignmentFailed
        }

        return alignedFrames
    }

    private func medianCombineFrames(_ frames: [AlignedFrame]) throws -> CGImage {
        let images = frames.map { $0.image }

        do {
            return try ImageProcessing.medianCombine(images: images)
        } catch {
            throw CaptureError.combiningFailed
        }
    }

    // MARK: - Public Helper Methods

    /// Get capture statistics from last result
    public func getStatistics() -> String? {
        guard let result = lastResult else { return nil }

        return """
        Capture Statistics:
        - Total frames: \(result.totalFramesCaptured)
        - Sharp frames: \(result.sharpFramesUsed)
        - Capture time: \(String(format: "%.2f", result.captureTime))s
        - Avg blur score: \(String(format: "%.1f", result.averageBlurScore))
        - ROIs extracted: \(result.roiImages.count)
        """
    }
}
