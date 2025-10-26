//
//  ImageProcessing.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import CoreGraphics
import UIKit
import Accelerate

public class ImageProcessing {

    // MARK: - Blur Detection (Laplacian Variance)

    /// Compute blur score using Laplacian variance
    /// Higher values = sharper image, Lower values = blurrier image
    /// Typical threshold: 100.0 (images below this are considered blurry)
    public static func computeBlurScore(for image: CGImage) -> Double {
        guard let pixelBuffer = pixelBuffer(from: image) else {
            return 0.0
        }

        return computeBlurScore(for: pixelBuffer)
    }

    /// Compute blur score from pixel buffer
    public static func computeBlurScore(for pixelBuffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return 0.0
        }

        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        // Convert to grayscale for Laplacian computation
        var grayscale = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            let rowBase = buffer.advanced(by: y * bytesPerRow)
            for x in 0..<width {
                let pixelOffset = x * 4 // BGRA format
                let b = Double(rowBase[pixelOffset])
                let g = Double(rowBase[pixelOffset + 1])
                let r = Double(rowBase[pixelOffset + 2])

                // Rec. 709 luma
                let gray = UInt8(0.2126 * r + 0.7152 * g + 0.0722 * b)
                grayscale[y * width + x] = gray
            }
        }

        // Compute Laplacian using 3x3 kernel:
        // [ 0  1  0 ]
        // [ 1 -4  1 ]
        // [ 0  1  0 ]
        var laplacian = [Double](repeating: 0, count: width * height)

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = Double(grayscale[y * width + x])
                let top = Double(grayscale[(y - 1) * width + x])
                let bottom = Double(grayscale[(y + 1) * width + x])
                let left = Double(grayscale[y * width + (x - 1)])
                let right = Double(grayscale[y * width + (x + 1)])

                let value = -4 * center + top + bottom + left + right
                laplacian[y * width + x] = value
            }
        }

        // Compute variance of Laplacian
        let mean = laplacian.reduce(0.0, +) / Double(laplacian.count)
        let variance = laplacian.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(laplacian.count)

        return variance
    }

    // MARK: - Frame Alignment

    /// Align image based on eye landmarks
    public static func alignImage(
        _ image: CGImage,
        landmarks: FaceLandmarks,
        targetSize: CGSize
    ) throws -> CGImage {
        guard let leftPupil = landmarks.leftPupil,
              let rightPupil = landmarks.rightPupil else {
            throw ImageProcessingError.insufficientLandmarks
        }

        // Calculate eye angle and center
        let eyeAngle = -atan2(rightPupil.y - leftPupil.y, rightPupil.x - leftPupil.x)
        let eyeCenter = CGPoint(
            x: (leftPupil.x + rightPupil.x) / 2,
            y: (leftPupil.y + rightPupil.y) / 2
        )

        // Eye center in image coordinates (Vision uses normalized coords)
        let imageSize = CGSize(width: image.width, height: image.height)
        let eyeCenterImage = CGPoint(
            x: eyeCenter.x * imageSize.width,
            y: (1 - eyeCenter.y) * imageSize.height
        )

        // Calculate scale to fit target size
        let dx = rightPupil.x - leftPupil.x
        let dy = rightPupil.y - leftPupil.y
        let eyeDistance = sqrt(dx * dx + dy * dy) * imageSize.width
        let desiredEyeDistance = targetSize.width * 0.35
        let scaleFactor = desiredEyeDistance / eyeDistance

        // Create transformation
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: -eyeCenterImage.x, y: -eyeCenterImage.y)
        transform = transform.rotated(by: eyeAngle)
        transform = transform.scaledBy(x: scaleFactor, y: scaleFactor)
        transform = transform.translatedBy(x: targetSize.width / 2, y: targetSize.height / 2)

        // Apply transformation
        guard let colorSpace = image.colorSpace,
              let context = CGContext(
                  data: nil,
                  width: Int(targetSize.width),
                  height: Int(targetSize.height),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw ImageProcessingError.transformationFailed
        }

        context.concatenate(transform)
        context.draw(image, in: CGRect(origin: .zero, size: imageSize))

        guard let alignedImage = context.makeImage() else {
            throw ImageProcessingError.transformationFailed
        }

        return alignedImage
    }

    // MARK: - Median Combining

    /// Combine multiple aligned images using median filter to reduce noise
    public static func medianCombine(images: [CGImage]) throws -> CGImage {
        guard !images.isEmpty else {
            throw ImageProcessingError.noImagesToCombine
        }

        guard images.count > 1 else {
            return images[0]
        }

        // Verify all images have same dimensions
        let width = images[0].width
        let height = images[0].height

        for image in images {
            guard image.width == width && image.height == height else {
                throw ImageProcessingError.imageSizeMismatch
            }
        }

        // Convert all images to pixel buffers
        var pixelBuffers: [[UInt8]] = []
        for image in images {
            guard let buffer = pixelData(from: image) else {
                throw ImageProcessingError.pixelDataExtractionFailed
            }
            pixelBuffers.append(buffer)
        }

        let pixelCount = width * height * 4 // BGRA

        // Compute median for each pixel component
        var medianBuffer = [UInt8](repeating: 0, count: pixelCount)

        for i in 0..<pixelCount {
            var values = pixelBuffers.map { $0[i] }
            values.sort()
            medianBuffer[i] = values[values.count / 2]
        }

        // Create CGImage from median buffer
        guard let colorSpace = images[0].colorSpace,
              let provider = CGDataProvider(data: Data(medianBuffer) as CFData),
              let resultImage = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: width * 4,
                  space: colorSpace,
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ) else {
            throw ImageProcessingError.imageCreationFailed
        }

        return resultImage
    }

    // MARK: - Helper Methods

    private static func pixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        let width = image.width
        let height = image.height

        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }

    private static func pixelData(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let colorSpace = image.colorSpace,
              let context = CGContext(
                  data: &pixelData,
                  width: width,
                  height: height,
                  bitsPerComponent: bitsPerComponent,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return pixelData
    }
}

// MARK: - Error Types

public enum ImageProcessingError: LocalizedError {
    case insufficientLandmarks
    case transformationFailed
    case noImagesToCombine
    case imageSizeMismatch
    case pixelDataExtractionFailed
    case imageCreationFailed

    public var errorDescription: String? {
        switch self {
        case .insufficientLandmarks:
            return "Insufficient landmarks for alignment"
        case .transformationFailed:
            return "Failed to apply transformation"
        case .noImagesToCombine:
            return "No images provided for combining"
        case .imageSizeMismatch:
            return "Images have different dimensions"
        case .pixelDataExtractionFailed:
            return "Failed to extract pixel data"
        case .imageCreationFailed:
            return "Failed to create combined image"
        }
    }
}
