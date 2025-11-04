//
//  PigmentationAnalyzer.swift
//  Tavi
//
//  Compute pigmentation variance in CIELAB color space
//  Created on 2025-10-27.
//

import Foundation
import UIKit
import Accelerate
import simd

/// Analyzes pigmentation variance using CIELAB color space
public class PigmentationAnalyzer {

    // MARK: - Configuration

    public struct Configuration {
        /// Normalization factor for variance
        public var varianceNormalization: Float = 100.0

        /// Weight for A* channel variance
        public var aChannelWeight: Float = 0.5

        /// Weight for B* channel variance
        public var bChannelWeight: Float = 0.5

        public init() {}
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Main API

    /// Compute pigmentation index from ROI texture sample
    /// Returns 0-1 score (higher = more pigmentation variation)
    /// - Parameters:
    ///   - sample: ROI texture sample with pixel colors
    ///   - lightingQuality: Optional lighting quality score (0-1). If provided and < 0.7, applies correction for lighting artifacts
    public func computePigmentationIndex(_ sample: ROITextureSample, lightingQuality: Float? = nil) -> Float {
        // Convert RGB to CIELAB
        let labColors = convertToLAB(sample.pixels)

        guard !labColors.isEmpty else { return 0 }

        // Extract A* and B* channels
        let aChannel = labColors.map { $0.y }
        let bChannel = labColors.map { $0.z }

        // Compute variance for each channel
        let varianceA = computeVariance(aChannel)
        let varianceB = computeVariance(bChannel)

        // Combine variances with weights
        var combinedVariance = varianceA * configuration.aChannelWeight +
                              varianceB * configuration.bChannelWeight

        // LIGHTING QUALITY CORRECTION:
        // Poor lighting can artificially inflate color variance due to:
        // 1. Uneven illumination creating false color gradients
        // 2. Shadows introducing spurious color shifts
        // 3. Color temperature variations across the face
        // Apply correction factor to compensate for lighting-induced variance
        if let quality = lightingQuality, quality < 0.7 {
            // Calculate correction factor:
            // - At quality = 0.7: correction = 1.0 (no adjustment)
            // - At quality = 0.5: correction = 0.94 (reduce variance by 6%)
            // - At quality = 0.3: correction = 0.88 (reduce variance by 12%)
            // - At quality = 0.0: correction = 0.79 (reduce variance by 21%)
            // Max 21% reduction to avoid over-correction
            let qualityDeficit = 0.7 - quality  // 0 to 0.7
            let correctionFactor = 1.0 - (qualityDeficit * 0.3)  // 1.0 to 0.79

            combinedVariance *= correctionFactor

            AppLogger.metrics.debug("🔦 Lighting quality correction applied: quality=\(String(format: "%.2f", quality)), correction=\(String(format: "%.3f", correctionFactor))")
        }

        // Normalize to 0-1 range
        let pigmentationIndex = min(sqrt(combinedVariance) / configuration.varianceNormalization, 1.0)

        return pigmentationIndex
    }

    // MARK: - CIELAB Conversion

    /// Convert RGB to CIELAB color space
    /// Returns SIMD3<Float> where x=L*, y=A*, z=B*
    private func convertToLAB(_ pixels: [SIMD3<Float>]) -> [SIMD3<Float>] {
        var labColors: [SIMD3<Float>] = []

        for pixel in pixels {
            // Step 1: RGB to XYZ
            let xyz = rgbToXYZ(pixel)

            // Step 2: XYZ to LAB
            let lab = xyzToLAB(xyz)

            labColors.append(lab)
        }

        return labColors
    }

    /// Convert sRGB to XYZ color space
    private func rgbToXYZ(_ rgb: SIMD3<Float>) -> SIMD3<Float> {
        // Convert sRGB to linear RGB
        let r = sRGBToLinear(rgb.x)
        let g = sRGBToLinear(rgb.y)
        let b = sRGBToLinear(rgb.z)

        // sRGB to XYZ conversion matrix (D65 illuminant)
        let x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b
        let y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
        let z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b

        return SIMD3<Float>(Float(x), Float(y), Float(z))
    }

    /// Convert XYZ to CIELAB color space
    private func xyzToLAB(_ xyz: SIMD3<Float>) -> SIMD3<Float> {
        // Reference white point (D65)
        let xn: Float = 0.95047
        let yn: Float = 1.00000
        let zn: Float = 1.08883

        // Normalize by reference white
        let xNorm = xyz.x / xn
        let yNorm = xyz.y / yn
        let zNorm = xyz.z / zn

        // Apply LAB function
        let fx = labFunction(xNorm)
        let fy = labFunction(yNorm)
        let fz = labFunction(zNorm)

        // Calculate L*, A*, B*
        let l = 116.0 * fy - 16.0
        let a = 500.0 * (fx - fy)
        let b = 200.0 * (fy - fz)

        return SIMD3<Float>(l, a, b)
    }

    /// LAB conversion function
    private func labFunction(_ t: Float) -> Float {
        let delta: Float = 6.0 / 29.0

        if t > delta * delta * delta {
            return pow(t, 1.0 / 3.0)
        } else {
            return (t / (3.0 * delta * delta)) + (4.0 / 29.0)
        }
    }

    /// Convert sRGB to linear RGB
    private func sRGBToLinear(_ value: Float) -> Float {
        if value <= 0.04045 {
            return value / 12.92
        } else {
            return pow((value + 0.055) / 1.055, 2.4)
        }
    }

    // MARK: - Variance Computation

    /// Compute variance of a data array
    private func computeVariance(_ data: [Float]) -> Float {
        guard !data.isEmpty else { return 0 }

        // Compute mean
        var mean: Float = 0
        vDSP_meanv(data, 1, &mean, vDSP_Length(data.count))

        // Compute variance
        var variance: Float = 0
        for value in data {
            let diff = value - mean
            variance += diff * diff
        }
        variance /= Float(data.count)

        return variance
    }

    // MARK: - Additional Metrics

    /// Compute standard deviation in LAB space
    public func computeLABStandardDeviation(_ sample: ROITextureSample) -> SIMD3<Float> {
        let labColors = convertToLAB(sample.pixels)

        guard !labColors.isEmpty else { return SIMD3<Float>(0, 0, 0) }

        // Compute mean for each channel
        var lSum: Float = 0
        var aSum: Float = 0
        var bSum: Float = 0

        for lab in labColors {
            lSum += lab.x
            aSum += lab.y
            bSum += lab.z
        }

        let count = Float(labColors.count)
        let lMean = lSum / count
        let aMean = aSum / count
        let bMean = bSum / count

        // Compute variance for each channel
        var lVar: Float = 0
        var aVar: Float = 0
        var bVar: Float = 0

        for lab in labColors {
            lVar += (lab.x - lMean) * (lab.x - lMean)
            aVar += (lab.y - aMean) * (lab.y - aMean)
            bVar += (lab.z - bMean) * (lab.z - bMean)
        }

        lVar /= count
        aVar /= count
        bVar /= count

        // Return standard deviations
        return SIMD3<Float>(sqrt(lVar), sqrt(aVar), sqrt(bVar))
    }

    /// Compute average CIELAB L* value (lightness)
    public func computeAverageLightness(_ sample: ROITextureSample) -> Float {
        let labColors = convertToLAB(sample.pixels)

        guard !labColors.isEmpty else { return 0 }

        var lSum: Float = 0
        for lab in labColors {
            lSum += lab.x
        }

        return lSum / Float(labColors.count)
    }
}
