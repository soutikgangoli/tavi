//
//  ScanQualityMetrics.swift
//  Ollvy
//
//  Scan quality assessment with per-metric confidence
//  Created on 2025-12-25.
//

import Foundation
import simd
import UIKit

/// Comprehensive scan quality metrics
public struct ScanQualityMetrics: Codable {
    /// Exposure quality (0-1, higher = better)
    public let exposure: Float

    /// Clipping quality (0-1, higher = less clipping)
    public let clipping: Float

    /// Blur/sharpness quality (0-1, higher = sharper)
    public let sharpness: Float

    /// Lighting directionality (0-1, higher = more uniform, less shadowing)
    public let uniformity: Float

    /// Color cast quality (0-1, higher = more neutral)
    public let colorCast: Float

    /// Overall quality composite (weighted average)
    public var overall: Float {
        return exposure * 0.25 +
               clipping * 0.20 +
               sharpness * 0.15 +
               uniformity * 0.25 +
               colorCast * 0.15
    }

    /// Whether scan meets minimum quality thresholds
    public var isAcceptable: Bool {
        return exposure > 0.5 &&
               clipping > 0.7 &&
               sharpness > 0.5 &&
               uniformity > 0.5 &&
               colorCast > 0.5 &&
               overall > 0.6
    }

    public init(exposure: Float, clipping: Float, sharpness: Float, uniformity: Float, colorCast: Float) {
        self.exposure = exposure
        self.clipping = clipping
        self.sharpness = sharpness
        self.uniformity = uniformity
        self.colorCast = colorCast
    }
}

/// Per-metric confidence levels
public struct MetricConfidence: Codable {
    /// Metric identifier
    public let metric: SkinMetricType

    /// Raw metric index value (before scoring)
    public let rawIndex: Float

    /// Mapped score (0-100)
    public let score: Float

    /// Confidence level (0-1)
    public let confidence: Float

    /// Whether metric should be displayed
    public var shouldDisplay: Bool {
        return confidence >= 0.25
    }

    /// Confidence tier for UI rendering
    public var tier: ConfidenceTier {
        if confidence >= 0.75 { return .high }
        else if confidence >= 0.50 { return .moderate }
        else if confidence >= 0.25 { return .low }
        else { return .unreliable }
    }

    public init(metric: SkinMetricType, rawIndex: Float, score: Float, confidence: Float) {
        self.metric = metric
        self.rawIndex = rawIndex
        self.score = score
        self.confidence = confidence
    }
}

/// Confidence tier for UI display
public enum ConfidenceTier: String, Codable {
    case high        // > 0.75: Show normally
    case moderate    // 0.50-0.75: Show with warning icon
    case low         // 0.25-0.50: Gray out, show "?"
    case unreliable  // < 0.25: Hide completely
}

/// Skin metric types for confidence assessment
public enum SkinMetricType: String, Codable {
    case pigmentation
    case discoloration
    case redness
    case specular
    case hydration
    case texture
    case roughness
    case pores
    case acne
    case wrinkles
    case smoothness
}

/// Compute per-metric confidence from scan quality
public func computeMetricConfidence(
    metric: SkinMetricType,
    scanQuality: ScanQualityMetrics
) -> Float {

    switch metric {
    case .pigmentation, .discoloration:
        // Color variance metrics: require good exposure and color cast
        // Moderate sensitivity to uniformity (shadows affect but don't invalidate)
        return min(
            scanQuality.exposure * 0.4 +
            scanQuality.colorCast * 0.4 +
            scanQuality.uniformity * 0.2,
            1.0
        )

    case .redness:
        // Very sensitive to color cast and exposure
        // Uniformity less critical (regional redness is real)
        return min(
            scanQuality.exposure * 0.3 +
            scanQuality.colorCast * 0.5 +
            scanQuality.uniformity * 0.2,
            1.0
        )

    case .specular, .hydration:
        // Specular/oiliness VERY sensitive to lighting uniformity
        // Hydration is proxy-based, already low confidence
        if metric == .specular {
            // Specular requires excellent uniformity (no shadows/highlights)
            return scanQuality.uniformity > 0.7 ? scanQuality.uniformity : 0.0
        } else {
            // Hydration proxy: reduce by overall quality
            return scanQuality.overall * 0.6
        }

    case .texture, .roughness, .pores:
        // Texture metrics: require sharpness and moderate uniformity
        // Less sensitive to color cast
        return min(
            scanQuality.sharpness * 0.5 +
            scanQuality.uniformity * 0.3 +
            scanQuality.exposure * 0.2,
            1.0
        )

    case .acne, .wrinkles:
        // 3D relief detection: requires uniformity (shadows for depth) AND sharpness
        // But TOO uniform is bad (need subtle shadows)
        // Gate if uniformity too low (harsh shadows) or too high (flat lighting)
        let uniformityOK = scanQuality.uniformity >= 0.6 && scanQuality.uniformity <= 0.9
        if !uniformityOK {
            return 0.0
        }
        return min(
            scanQuality.sharpness * 0.5 +
            scanQuality.uniformity * 0.3 +
            scanQuality.exposure * 0.2,
            1.0
        )

    case .smoothness:
        // Moderate sensitivity to all factors
        return scanQuality.overall * 0.85
    }
}
