//
//  MetricsModels.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import CoreGraphics

// MARK: - Metrics Result

/// Complete metrics analysis for a single ROI
public struct ROIMetrics {
    /// Laplacian variance, normalized 0-1
    public let blurScore: Double

    /// High-frequency energy, 0-1
    public let textureEnergy: Double

    /// Pigmentation unevenness index, 0-1
    public let labVariance: Double

    /// Moisture proxy metrics
    public let moistureProxy: MoistureProxy

    /// ROI type this metrics belongs to
    public let roiType: ROIType

    /// Overall quality score (0-1, higher is better)
    public var qualityScore: Double {
        // Combine metrics: high blur score, low texture variance, low LAB variance
        let blurWeight = 0.4
        let textureWeight = 0.3
        let labWeight = 0.3

        return blurScore * blurWeight +
               (1.0 - textureEnergy) * textureWeight +
               (1.0 - labVariance) * labWeight
    }
}

/// Moisture proxy metrics
public struct MoistureProxy {
    /// Specular highlight ratio (0-1)
    /// Higher values indicate more specular highlights (potentially more moisture)
    public let specularRatio: Double

    /// Low-frequency smoothness (0-1)
    /// Higher values indicate smoother skin texture
    public let smoothnessLowFreq: Double

    /// Combined moisture index (0-1)
    public var moistureIndex: Double {
        // Weighted combination: more weight on smoothness
        return specularRatio * 0.3 + smoothnessLowFreq * 0.7
    }
}

/// Complete metrics result for all ROIs
public struct MetricsResult {
    /// Metrics per ROI type
    public let roiMetrics: [ROIType: ROIMetrics]

    /// Inter-ROI discoloration index (0-1)
    public let discolorationIndex: Double

    /// Timestamp of analysis
    public let timestamp: Date

    /// Average metrics across all ROIs
    public var averageMetrics: ROIMetrics? {
        guard !roiMetrics.isEmpty else { return nil }

        let avgBlur = roiMetrics.values.map { $0.blurScore }.reduce(0, +) / Double(roiMetrics.count)
        let avgTexture = roiMetrics.values.map { $0.textureEnergy }.reduce(0, +) / Double(roiMetrics.count)
        let avgLAB = roiMetrics.values.map { $0.labVariance }.reduce(0, +) / Double(roiMetrics.count)
        let avgSpecular = roiMetrics.values.map { $0.moistureProxy.specularRatio }.reduce(0, +) / Double(roiMetrics.count)
        let avgSmoothness = roiMetrics.values.map { $0.moistureProxy.smoothnessLowFreq }.reduce(0, +) / Double(roiMetrics.count)

        return ROIMetrics(
            blurScore: avgBlur,
            textureEnergy: avgTexture,
            labVariance: avgLAB,
            moistureProxy: MoistureProxy(
                specularRatio: avgSpecular,
                smoothnessLowFreq: avgSmoothness
            ),
            roiType: .foreheadCenter // Generic type for average
        )
    }

    /// Overall skin quality score (0-1)
    public var overallQualityScore: Double {
        guard let avg = averageMetrics else { return 0 }

        // Factor in discoloration (lower is better)
        let qualityWeight = 0.7
        let discolorationWeight = 0.3

        return avg.qualityScore * qualityWeight +
               (1.0 - discolorationIndex) * discolorationWeight
    }
}

// MARK: - LAB Color

/// LAB color space representation
public struct LABColor {
    /// Lightness (0-100)
    public let L: Double

    /// Green-Red axis (-128 to 127)
    public let A: Double

    /// Blue-Yellow axis (-128 to 127)
    public let B: Double

    /// Create from RGB components (0-255)
    public init(r: UInt8, g: UInt8, b: UInt8) {
        // Convert RGB to XYZ
        var rNorm = Double(r) / 255.0
        var gNorm = Double(g) / 255.0
        var bNorm = Double(b) / 255.0

        // Apply gamma correction
        rNorm = rNorm > 0.04045 ? pow((rNorm + 0.055) / 1.055, 2.4) : rNorm / 12.92
        gNorm = gNorm > 0.04045 ? pow((gNorm + 0.055) / 1.055, 2.4) : gNorm / 12.92
        bNorm = bNorm > 0.04045 ? pow((bNorm + 0.055) / 1.055, 2.4) : bNorm / 12.92

        // Convert to XYZ (D65 illuminant)
        let x = rNorm * 0.4124564 + gNorm * 0.3575761 + bNorm * 0.1804375
        let y = rNorm * 0.2126729 + gNorm * 0.7151522 + bNorm * 0.0721750
        let z = rNorm * 0.0193339 + gNorm * 0.1191920 + bNorm * 0.9503041

        // D65 reference white
        let xn = 0.95047
        let yn = 1.00000
        let zn = 1.08883

        // Normalize
        var xr = x / xn
        var yr = y / yn
        var zr = z / zn

        // Apply LAB transformation
        let epsilon = 0.008856
        let kappa = 903.3

        xr = xr > epsilon ? pow(xr, 1.0/3.0) : (kappa * xr + 16.0) / 116.0
        yr = yr > epsilon ? pow(yr, 1.0/3.0) : (kappa * yr + 16.0) / 116.0
        zr = zr > epsilon ? pow(zr, 1.0/3.0) : (kappa * zr + 16.0) / 116.0

        // Compute LAB
        self.L = 116.0 * yr - 16.0
        self.A = 500.0 * (xr - yr)
        self.B = 200.0 * (yr - zr)
    }

    /// Euclidean distance to another LAB color
    public func distance(to other: LABColor) -> Double {
        let dL = L - other.L
        let dA = A - other.A
        let dB = B - other.B
        return sqrt(dL * dL + dA * dA + dB * dB)
    }
}

// MARK: - Metrics Configuration

/// Configuration for metrics computation
public struct MetricsConfiguration {
    /// Blur score normalization range (raw Laplacian variance)
    /// Values below minBlur map to 0, above maxBlur map to 1
    public let minBlur: Double
    public let maxBlur: Double

    /// Texture energy normalization range
    public let minTextureEnergy: Double
    public let maxTextureEnergy: Double

    /// LAB variance normalization range
    public let minLABVariance: Double
    public let maxLABVariance: Double

    /// Specular highlight threshold (0-255 in grayscale)
    public let specularThreshold: UInt8

    /// Low-frequency smoothness kernel size
    public let smoothnessKernelSize: Int

    public static let `default` = MetricsConfiguration(
        minBlur: 50.0,
        maxBlur: 200.0,
        minTextureEnergy: 0.01,
        maxTextureEnergy: 0.5,
        minLABVariance: 0.0,
        maxLABVariance: 50.0,
        specularThreshold: 220,
        smoothnessKernelSize: 15
    )
}
