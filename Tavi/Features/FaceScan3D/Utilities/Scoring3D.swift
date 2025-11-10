//
//  Scoring3D.swift
//  Tavi
//
//  Map raw 3D metrics to user-friendly 0-100 percentage scores
//  Created on 2025-10-27.
//

import Foundation

/// Maps raw metric values to 0-100 percentage scores
public class Scoring3D {

    // MARK: - Configuration

    public struct Configuration {
        // Roughness thresholds - RECALIBRATED for real-world conditions
        // Old: 0.10-0.35, New: 0.08-0.50 (relaxed by 43% for realistic lighting)
        public var roughnessLowThreshold: Float = 0.08    // Excellent skin
        public var roughnessHighThreshold: Float = 0.50   // Significant texture issues

        // Pigmentation thresholds - RECALIBRATED
        // Old: 0.03-0.15, New: 0.02-0.25 (relaxed by 67% to account for lighting variance)
        public var pigmentationLowThreshold: Float = 0.02  // Very even tone
        public var pigmentationHighThreshold: Float = 0.25 // Noticeable pigmentation

        // Discoloration thresholds - RECALIBRATED
        // Old: 0.01-0.06, New: 0.01-0.12 (doubled range for realistic assessment)
        public var discolorationLowThreshold: Float = 0.01 // Minimal discoloration
        public var discolorationHighThreshold: Float = 0.12 // Significant discoloration

        // Specular/Oiliness thresholds - RECALIBRATED
        // Old: 0.02-0.12, New: 0.02-0.18 (relaxed by 50%)
        public var specularLowThreshold: Float = 0.02     // Normal/dry skin
        public var specularHighThreshold: Float = 0.18    // Very oily skin

        // Score bounds (percentage scale) - FULL 0-100 RANGE
        public var minimumScore: Float = 0.0
        public var maximumScore: Float = 100.0

        // Low/high score mappings - EXPANDED TO FULL RANGE
        // Old: 20-90 (compressed range), New: 0-100 (full range)
        public var lowScoreValue: Float = 0.0     // Score for high threshold (worst)
        public var highScoreValue: Float = 100.0  // Score for low threshold (best)

        public init() {}
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Score Mapping

    /// Map roughness proxy (0-1) to percentage score (0-100)
    /// Lower roughness = better score (higher percentage)
    public func mapRoughnessScore(_ roughnessProxy: Float) -> Float {
        return mapMetricToScore(
            value: roughnessProxy,
            lowThreshold: configuration.roughnessLowThreshold,
            highThreshold: configuration.roughnessHighThreshold,
            inverted: true  // Lower is better
        )
    }

    /// Map pigmentation index (0-1) to percentage score (0-100)
    /// Lower pigmentation variance = better score (higher percentage)
    /// - Parameters:
    ///   - pigmentationIndex: Variance-based index (0-1)
    ///   - lightingQuality: Optional lighting quality (0-1). If < 0.7, relaxes thresholds to be more forgiving
    public func mapPigmentationScore(_ pigmentationIndex: Float, lightingQuality: Float? = nil) -> Float {
        // ADAPTIVE THRESHOLDS:
        // Poor lighting quality can inflate variance even after correction.
        // Make scoring more forgiving by expanding the acceptable range.
        let effectiveLowThreshold: Float
        let effectiveHighThreshold: Float

        if let quality = lightingQuality, quality < 0.7 {
            // Relax thresholds proportionally to lighting quality deficit
            // - At quality = 0.7: no adjustment
            // - At quality = 0.5: expand range by 14%
            // - At quality = 0.3: expand range by 29%
            // - At quality = 0.0: expand range by 50%
            let qualityDeficit = 0.7 - quality  // 0 to 0.7
            let expansionFactor = 1.0 + (qualityDeficit * 0.7)  // 1.0 to 1.49

            effectiveLowThreshold = configuration.pigmentationLowThreshold
            effectiveHighThreshold = configuration.pigmentationHighThreshold * expansionFactor

            AppLogger.metrics.debug("🔦 Pigmentation scoring adjustment: quality=\(String(format: "%.2f", quality)), threshold expansion=\(String(format: "%.2f", expansionFactor))x")
        } else {
            effectiveLowThreshold = configuration.pigmentationLowThreshold
            effectiveHighThreshold = configuration.pigmentationHighThreshold
        }

        return mapMetricToScore(
            value: pigmentationIndex,
            lowThreshold: effectiveLowThreshold,
            highThreshold: effectiveHighThreshold,
            inverted: true  // Lower is better
        )
    }

    /// Map discoloration index (0-1) to percentage score (0-100)
    /// Lower discoloration = better score (higher percentage)
    /// - Parameters:
    ///   - discolorationIndex: Cross-region variance index (0-1)
    ///   - lightingQuality: Optional lighting quality (0-1). If < 0.7, relaxes thresholds to be more forgiving
    public func mapDiscolorationScore(_ discolorationIndex: Float, lightingQuality: Float? = nil) -> Float {
        // ADAPTIVE THRESHOLDS:
        // Similar to pigmentation, poor lighting creates artificial cross-region variance
        let effectiveLowThreshold: Float
        let effectiveHighThreshold: Float

        if let quality = lightingQuality, quality < 0.7 {
            // Same expansion formula as pigmentation
            let qualityDeficit = 0.7 - quality
            let expansionFactor = 1.0 + (qualityDeficit * 0.7)

            effectiveLowThreshold = configuration.discolorationLowThreshold
            effectiveHighThreshold = configuration.discolorationHighThreshold * expansionFactor

            AppLogger.metrics.debug("🔦 Discoloration scoring adjustment: quality=\(String(format: "%.2f", quality)), threshold expansion=\(String(format: "%.2f", expansionFactor))x")
        } else {
            effectiveLowThreshold = configuration.discolorationLowThreshold
            effectiveHighThreshold = configuration.discolorationHighThreshold
        }

        return mapMetricToScore(
            value: discolorationIndex,
            lowThreshold: effectiveLowThreshold,
            highThreshold: effectiveHighThreshold,
            inverted: true  // Lower is better
        )
    }

    /// Map specular proxy (0-1) to percentage score (0-100)
    /// Lower oiliness = better score (higher percentage)
    public func mapSpecularScore(_ specularProxy: Float) -> Float {
        return mapMetricToScore(
            value: specularProxy,
            lowThreshold: configuration.specularLowThreshold,
            highThreshold: configuration.specularHighThreshold,
            inverted: true  // Lower is better
        )
    }

    // MARK: - Generic Mapping

    /// Map metric value to 0-100 percentage score with linear interpolation
    /// - Parameters:
    ///   - value: Raw metric value (0-1 range)
    ///   - lowThreshold: Value that maps to lowScoreValue
    ///   - highThreshold: Value that maps to highScoreValue
    ///   - inverted: If true, lower values get higher scores (better)
    private func mapMetricToScore(
        value: Float,
        lowThreshold: Float,
        highThreshold: Float,
        inverted: Bool
    ) -> Float {

        // Clamp value to valid range
        let clampedValue = max(0, min(1, value))

        // Linear interpolation between thresholds
        let normalizedValue: Float

        if clampedValue <= lowThreshold {
            // Below low threshold -> best score
            normalizedValue = 0.0
        } else if clampedValue >= highThreshold {
            // Above high threshold -> worst score
            normalizedValue = 1.0
        } else {
            // Linear interpolation between thresholds
            normalizedValue = (clampedValue - lowThreshold) / (highThreshold - lowThreshold)
        }

        // Map to score range
        let score: Float
        if inverted {
            // Lower metric = higher score (better)
            score = configuration.highScoreValue - normalizedValue * (configuration.highScoreValue - configuration.lowScoreValue)
        } else {
            // Higher metric = higher score (better)
            score = configuration.lowScoreValue + normalizedValue * (configuration.highScoreValue - configuration.lowScoreValue)
        }

        // Clamp to bounds
        return max(configuration.minimumScore, min(configuration.maximumScore, score))
    }

    // MARK: - Helper Functions

    /// Map any metric value to 0-100 percentage score with linear interpolation
    /// - Parameters:
    ///   - value: Current metric value
    ///   - low: Value that maps to 0%
    ///   - high: Value that maps to 100%
    /// - Returns: Percentage score (0-100) as Int
    public func percentageScore(from value: Float, low: Float, high: Float) -> Int {
        // Clamp value to [low, high] range
        let clampedValue = max(low, min(high, value))

        // Linear mapping to 0-100
        let percentage: Float
        if high - low > 0 {
            percentage = ((clampedValue - low) / (high - low)) * 100.0
        } else {
            percentage = 0.0
        }

        // Return as integer, clamped to [0, 100]
        return Int(max(0, min(100, percentage.rounded())))
    }

    // MARK: - Composite Scores

    /// Compute overall skin health score (weighted average of 5 high-confidence metrics)
    /// This represents skin quality based on reliable measurements only
    /// Excludes: Elasticity (requires 2+ scans), Hydration (proxy method), Oil Control (disabled), Redness (measurement limitations)
    public func computeOverallScore(
        smoothnessScore: Float,
        poresScore: Float?,
        pigmentationScore: Float,
        discolorationScore: Float,
        acneScore: Float?
    ) -> Float {

        var totalWeight: Float = 0
        var weightedSum: Float = 0

        // New weights (normalized to 100%, based on importance and confidence):
        // - Smoothness: 22.4% (most reliable, high impact)
        // - Pigmentation: 22.4% (very reliable, high impact)
        // - Pores: 14.9% (reliable with good texture)
        // - Discoloration: 14.9% (reliable, moderate impact)
        // - Acne: 14.9% (reliable detection, variable impact)

        // Smoothness (22.4%) - Surface texture quality (85% confidence)
        let smoothnessWeight: Float = 0.224
        weightedSum += smoothnessScore * smoothnessWeight
        totalWeight += smoothnessWeight

        // Pores (14.9%) - Texture refinement (70-90% confidence)
        if let poresScore = poresScore {
            let poresWeight: Float = 0.149
            weightedSum += poresScore * poresWeight
            totalWeight += poresWeight
        }

        // Pigmentation (22.4%) - Even tone (80% confidence)
        let pigmentationWeight: Float = 0.224
        weightedSum += pigmentationScore * pigmentationWeight
        totalWeight += pigmentationWeight

        // Discoloration (14.9%) - Spots/hyperpigmentation (80% confidence)
        let discolorationWeight: Float = 0.149
        weightedSum += discolorationScore * discolorationWeight
        totalWeight += discolorationWeight

        // Acne (14.9%) - Active breakouts/blemishes (75-85% confidence)
        if let acneScore = acneScore {
            let acneWeight: Float = 0.149
            weightedSum += acneScore * acneWeight
            totalWeight += acneWeight
        }

        // Remaining 11% is redistributed proportionally when optional metrics are missing
        return totalWeight > 0 ? weightedSum / totalWeight : 0
    }

    /// Legacy method for backward compatibility
    /// @deprecated Use computeOverallScore with 9 metrics instead
    public func computeOverallScoreLegacy(
        roughnessScore: Float,
        pigmentationScore: Float,
        discolorationScore: Float,
        specularScore: Float?
    ) -> Float {
        // Map to new method (use old 4-metric formula)
        var totalWeight: Float = 0
        var weightedSum: Float = 0

        // Roughness (25%)
        let roughnessWeight: Float = 0.25
        weightedSum += roughnessScore * roughnessWeight
        totalWeight += roughnessWeight

        // Pigmentation (30%)
        let pigmentationWeight: Float = 0.30
        weightedSum += pigmentationScore * pigmentationWeight
        totalWeight += pigmentationWeight

        // Discoloration (25%)
        let discolorationWeight: Float = 0.25
        weightedSum += discolorationScore * discolorationWeight
        totalWeight += discolorationWeight

        // Specular (20%, if available)
        if let specularScore = specularScore {
            let specularWeight: Float = 0.20
            weightedSum += specularScore * specularWeight
            totalWeight += specularWeight
        }

        return totalWeight > 0 ? weightedSum / totalWeight : 0
    }

    // MARK: - Score Interpretation

    /// Get textual interpretation of percentage score
    public func interpretScore(_ score: Float) -> String {
        switch score {
        case 90.0...100.0:
            return "Excellent"
        case 70.0..<90.0:
            return "Very Good"
        case 50.0..<70.0:
            return "Good"
        case 30.0..<50.0:
            return "Fair"
        case 10.0..<30.0:
            return "Poor"
        default:
            return "Very Poor"
        }
    }

    /// Get color for score visualization
    public func colorForScore(_ score: Float) -> ScoreColor {
        switch score {
        case 80.0...100.0:
            return .excellent  // Green
        case 60.0..<80.0:
            return .good       // Light green
        case 40.0..<60.0:
            return .fair       // Yellow
        case 20.0..<40.0:
            return .poor       // Orange
        default:
            return .veryPoor   // Red
        }
    }
}

// MARK: - Score Color

public enum ScoreColor {
    case excellent  // 80-100%
    case good       // 60-80%
    case fair       // 40-60%
    case poor       // 20-40%
    case veryPoor   // 0-20%
}
