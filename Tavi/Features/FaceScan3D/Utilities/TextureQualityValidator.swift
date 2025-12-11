//
//  TextureQualityValidator.swift
//  Tavi
//
//  Validates texture quality for 3D face metrics computation
//  Created on 2025-10-27.
//

import Foundation
import UIKit
import CoreGraphics
import Accelerate

/// Validates texture quality before metrics computation
public class TextureQualityValidator {

    // MARK: - Configuration

    public struct Configuration {
        /// Minimum pixel count for ROI to be considered valid
        public var minimumROIPixelCount: Int = 100

        /// Minimum Laplacian variance for texture sharpness
        /// STRICT: Increased to 150 to ensure accurate skin analysis
        /// Below this threshold, texture is considered too blurry for reliable metrics
        public var minimumLaplacianVariance: Float = 150.0

        /// Maximum percentage of low-confidence ROIs allowed
        public var maximumLowConfidenceRatio: Float = 0.4

        public init() {}
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Quality Validation

    /// Validate texture quality
    public func validateTexture(_ texture: CGImage) -> TextureQualityResult {
        // Check blur using Laplacian variance
        let laplacianVariance = computeLaplacianVariance(texture)
        let isBlurry = laplacianVariance < configuration.minimumLaplacianVariance

        return TextureQualityResult(
            isValid: !isBlurry,
            laplacianVariance: laplacianVariance,
            minimumThreshold: configuration.minimumLaplacianVariance,
            reason: isBlurry ? "Texture too blurry - retake scan" : nil
        )
    }

    /// Validate ROI sample pixel count
    public func validateROISample(_ sample: ROITextureSample) -> ROIConfidence {
        let hasEnoughPixels = sample.pixelCount >= configuration.minimumROIPixelCount

        return ROIConfidence(
            roi: sample.roi,
            isValid: hasEnoughPixels,
            pixelCount: sample.pixelCount,
            minimumRequired: configuration.minimumROIPixelCount,
            confidenceLevel: computeConfidenceLevel(pixelCount: sample.pixelCount)
        )
    }

    /// Validate all ROI samples
    public func validateROISamples(_ samples: [Face3DROI: ROITextureSample]) -> [Face3DROI: ROIConfidence] {
        var confidences: [Face3DROI: ROIConfidence] = [:]

        for (roi, sample) in samples {
            confidences[roi] = validateROISample(sample)
        }

        return confidences
    }

    /// Check if global metrics can be computed reliably
    public func canComputeGlobalMetrics(_ confidences: [Face3DROI: ROIConfidence]) -> GlobalMetricsValidity {
        let totalROIs = confidences.count
        let lowConfidenceROIs = confidences.values.filter { !$0.isValid }.count

        let lowConfidenceRatio = totalROIs > 0 ? Float(lowConfidenceROIs) / Float(totalROIs) : 0

        let isValid = lowConfidenceRatio <= configuration.maximumLowConfidenceRatio

        return GlobalMetricsValidity(
            isValid: isValid,
            totalROIs: totalROIs,
            lowConfidenceROIs: lowConfidenceROIs,
            lowConfidenceRatio: lowConfidenceRatio,
            maximumAllowedRatio: configuration.maximumLowConfidenceRatio,
            reason: isValid ? nil : "Too many ROIs have low confidence (\(lowConfidenceROIs)/\(totalROIs))"
        )
    }

    // MARK: - Laplacian Variance Computation

    private func computeLaplacianVariance(_ texture: CGImage) -> Float {
        let width = texture.width
        let height = texture.height

        // Extract pixel data
        guard let pixelData = extractPixelData(from: texture) else {
            return 0
        }

        // Convert to grayscale
        var grayscale = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                let r = Float(pixelData[idx]) / 255.0
                let g = Float(pixelData[idx + 1]) / 255.0
                let b = Float(pixelData[idx + 2]) / 255.0

                // FIXED: Standardized on BT.709 (sRGB) for consistency
                grayscale[y * width + x] = 0.2126 * r + 0.7152 * g + 0.0722 * b
            }
        }

        // Apply Laplacian operator (detects edges/sharpness)
        var laplacian = [Float](repeating: 0, count: width * height)

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let idx = y * width + x

                // Laplacian kernel:
                //  0  -1   0
                // -1   4  -1
                //  0  -1   0

                let center = grayscale[idx]
                let top = grayscale[(y - 1) * width + x]
                let bottom = grayscale[(y + 1) * width + x]
                let left = grayscale[y * width + (x - 1)]
                let right = grayscale[y * width + (x + 1)]

                laplacian[idx] = 4 * center - top - bottom - left - right
            }
        }

        // Compute variance of Laplacian
        var mean: Float = 0
        vDSP_meanv(laplacian, 1, &mean, vDSP_Length(laplacian.count))

        var variance: Float = 0
        for value in laplacian {
            let diff = value - mean
            variance += diff * diff
        }
        variance /= Float(laplacian.count)

        return variance
    }

    private func extractPixelData(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return pixelData
    }

    // MARK: - Confidence Level

    private func computeConfidenceLevel(pixelCount: Int) -> ConfidenceLevel {
        let ratio = Float(pixelCount) / Float(configuration.minimumROIPixelCount)

        if ratio >= 2.0 {
            return .high
        } else if ratio >= 1.0 {
            return .medium
        } else if ratio >= 0.5 {
            return .low
        } else {
            return .veryLow
        }
    }
}

// MARK: - Quality Results

/// Result of texture quality validation
public struct TextureQualityResult {
    public let isValid: Bool
    public let laplacianVariance: Float
    public let minimumThreshold: Float
    public let reason: String?

    public var qualityDescription: String {
        if isValid {
            return "Good quality (variance: \(String(format: "%.1f", laplacianVariance)))"
        } else {
            return reason ?? "Poor quality"
        }
    }
}

/// Confidence level for an ROI
public struct ROIConfidence {
    public let roi: Face3DROI
    public let isValid: Bool
    public let pixelCount: Int
    public let minimumRequired: Int
    public let confidenceLevel: ConfidenceLevel

    public var shouldIncludeInGlobalMetrics: Bool {
        return isValid
    }
}

/// Validity of global metrics computation
public struct GlobalMetricsValidity {
    public let isValid: Bool
    public let totalROIs: Int
    public let lowConfidenceROIs: Int
    public let lowConfidenceRatio: Float
    public let maximumAllowedRatio: Float
    public let reason: String?
}

/// Confidence level enum
public enum ConfidenceLevel: String, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case veryLow = "VeryLow"
}
