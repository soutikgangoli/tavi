//
//  DiscolorationAnalyzer.swift
//  Tavi
//
//  Compute discoloration/unevenness via cross-ROI LAB variance
//  Created on 2025-10-27.
//

import Foundation
import simd

/// Analyzes skin tone unevenness across face regions
public class DiscolorationAnalyzer {

    // MARK: - Configuration

    public struct Configuration {
        /// Weight for L* (lightness) channel in variance computation
        public var lightnessWeight: Float = 0.6

        /// Weight for A* (green-red) channel in variance computation
        public var aChannelWeight: Float = 0.4

        /// Normalization factor to scale variance to 0-1 range
        /// FIXED: Aligned with PigmentationAnalyzer (was 50.0, now 100.0)
        /// This ensures consistent scoring between discoloration and pigmentation metrics
        public var varianceNormalization: Float = 100.0

        public init() {}
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - LAB Mean

    /// Mean LAB color for a region
    public struct LABMean {
        public let roi: Face3DROI
        public let l: Float  // Lightness (0-100)
        public let a: Float  // Green-red (-128 to 127)
        public let b: Float  // Blue-yellow (-128 to 127)

        public init(roi: Face3DROI, l: Float, a: Float, b: Float) {
            self.roi = roi
            self.l = l
            self.a = a
            self.b = b
        }
    }

    // MARK: - Main API

    /// Compute discoloration index from ROI LAB means
    /// Returns 0-1 score where higher = more uneven skin tone across face
    /// - Parameters:
    ///   - roiMeans: Dictionary of LAB mean colors per face region
    ///   - lightingQuality: Optional lighting quality score (0-1). If provided and < 0.7, applies correction for lighting artifacts
    public func computeDiscolorationIndex(_ roiMeans: [Face3DROI: LABMean], lightingQuality: Float? = nil) -> Float {
        guard roiMeans.count >= 2 else {
            // Need at least 2 ROIs to compute variance
            return 0
        }

        // Extract L* and A* values
        let lValues = roiMeans.values.map { $0.l }
        let aValues = roiMeans.values.map { $0.a }

        // Compute variance for each channel
        let lVariance = computeVariance(lValues)
        let aVariance = computeVariance(aValues)

        // Weighted combination
        var combinedVariance = lVariance * configuration.lightnessWeight +
                               aVariance * configuration.aChannelWeight

        // REMOVED: Variance correction to fix double-compensation bug
        // Poor lighting is now handled ONLY via threshold expansion in Scoring3D
        // See PigmentationAnalyzer.swift for full explanation
        // This prevents score inflation for poor-quality scans

        // Normalize to 0-1 range
        let discolorationIndex = min(
            sqrt(combinedVariance) / configuration.varianceNormalization,
            1.0
        )

        return discolorationIndex
    }

    /// Compute LAB mean for a texture sample
    public func computeLABMean(_ sample: ROITextureSample) -> LABMean {
        guard !sample.pixels.isEmpty else {
            return LABMean(roi: sample.roi, l: 0, a: 0, b: 0)
        }

        // Convert all pixels to LAB
        var lSum: Float = 0
        var aSum: Float = 0
        var bSum: Float = 0

        for pixel in sample.pixels {
            let lab = rgbToLAB(pixel)
            lSum += lab.x
            aSum += lab.y
            bSum += lab.z
        }

        let count = Float(sample.pixels.count)

        return LABMean(
            roi: sample.roi,
            l: lSum / count,
            a: aSum / count,
            b: bSum / count
        )
    }

    // MARK: - Helpers

    private func computeVariance(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }

        // Compute mean
        let mean = values.reduce(0, +) / Float(values.count)

        // Compute variance: σ² = mean((x - μ)²)
        var sumSquaredDiff: Float = 0
        for value in values {
            let diff = value - mean
            sumSquaredDiff += diff * diff
        }

        return sumSquaredDiff / Float(values.count)
    }

    // MARK: - Color Conversion

    private func rgbToLAB(_ rgb: SIMD3<Float>) -> SIMD3<Float> {
        // Step 1: sRGB to linear RGB
        let r = sRGBToLinear(rgb.x)
        let g = sRGBToLinear(rgb.y)
        let b = sRGBToLinear(rgb.z)

        // Step 2: Linear RGB to XYZ (D65 illuminant)
        let x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b
        let y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
        let z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b

        // Step 3: XYZ to LAB
        return xyzToLAB(SIMD3<Float>(Float(x), Float(y), Float(z)))
    }

    private func sRGBToLinear(_ channel: Float) -> Float {
        if channel <= 0.04045 {
            return channel / 12.92
        } else {
            return pow((channel + 0.055) / 1.055, 2.4)
        }
    }

    private func xyzToLAB(_ xyz: SIMD3<Float>) -> SIMD3<Float> {
        // Reference white (D65)
        let xn: Float = 0.95047
        let yn: Float = 1.00000
        let zn: Float = 1.08883

        let fx = labFunction(xyz.x / xn)
        let fy = labFunction(xyz.y / yn)
        let fz = labFunction(xyz.z / zn)

        let l = 116.0 * fy - 16.0
        let a = 500.0 * (fx - fy)
        let b = 200.0 * (fy - fz)

        return SIMD3<Float>(l, a, b)
    }

    private func labFunction(_ t: Float) -> Float {
        let delta: Float = 6.0 / 29.0
        let deltaCubed = delta * delta * delta

        if t > deltaCubed {
            return pow(t, 1.0 / 3.0)
        } else {
            return t / (3.0 * delta * delta) + 4.0 / 29.0
        }
    }
}
