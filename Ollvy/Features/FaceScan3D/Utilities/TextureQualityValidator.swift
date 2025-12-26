//
//  TextureQualityValidator.swift
//  Ollvy
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
        /// RELAXED: Lowered from 150 to 80 to reduce false "too blurry" rejections
        /// The previous threshold was too strict for typical phone camera captures
        /// Skin texture typically has lower sharpness than test patterns
        /// Typical values: 50-100 = slightly soft, 100-200 = good, 200+ = very sharp
        public var minimumLaplacianVariance: Float = 80.0

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

        // DIAGNOSTIC: Log variance to help tune threshold
        let qualityLevel: String
        if laplacianVariance < 50 {
            qualityLevel = "very blurry"
        } else if laplacianVariance < 80 {
            qualityLevel = "slightly blurry"
        } else if laplacianVariance < 150 {
            qualityLevel = "acceptable"
        } else if laplacianVariance < 250 {
            qualityLevel = "good"
        } else {
            qualityLevel = "excellent"
        }

        AppLogger.metrics.debug("📊 Texture sharpness: variance=\(String(format: "%.1f", laplacianVariance)) (\(qualityLevel)), threshold=\(self.configuration.minimumLaplacianVariance)")
        if isBlurry {
            AppLogger.metrics.warning("⚠️ Texture marked as blurry (variance \(String(format: "%.1f", laplacianVariance)) < threshold \(self.configuration.minimumLaplacianVariance))")
        }

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
            AppLogger.metrics.error("❌ TextureQualityValidator: Failed to extract pixel data from texture (\(width)x\(height))")
            return 0
        }

        // Validate pixel data has content
        let totalPixels = width * height
        if pixelData.count != totalPixels * 4 {
            AppLogger.metrics.error("❌ TextureQualityValidator: Pixel data size mismatch - expected \(totalPixels * 4), got \(pixelData.count)")
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

        // Validate image dimensions
        guard width > 0 && height > 0 else {
            AppLogger.metrics.error("❌ extractPixelData: Invalid image dimensions \(width)x\(height)")
            return nil
        }

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        // Use sRGB color space for consistent results
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

        // Try multiple bitmap info configurations for compatibility
        // RGBA format with non-premultiplied alpha (most common from UIImage)
        let bitmapInfoOptions: [UInt32] = [
            CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue,
            CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue,
            CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue,
            CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ]

        var context: CGContext?
        for bitmapInfo in bitmapInfoOptions {
            context = CGContext(
                data: &pixelData,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
            if context != nil {
                break
            }
        }

        guard let ctx = context else {
            AppLogger.metrics.error("❌ extractPixelData: Failed to create CGContext for \(width)x\(height) image (tried \(bitmapInfoOptions.count) formats)")
            return nil
        }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Verify that pixel data actually has content (not all zeros)
        var hasContent = false
        let sampleCount = min(1000, pixelData.count / 4)
        let stride = max(1, pixelData.count / (sampleCount * 4))

        for i in Swift.stride(from: 0, to: pixelData.count, by: stride * 4) {
            if pixelData[i] != 0 || pixelData[i + 1] != 0 || pixelData[i + 2] != 0 {
                hasContent = true
                break
            }
        }

        if !hasContent {
            AppLogger.metrics.warning("⚠️ extractPixelData: Pixel data appears to be all zeros (empty texture)")
        }

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
