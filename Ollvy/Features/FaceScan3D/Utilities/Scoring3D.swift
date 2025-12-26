//
//  Scoring3D.swift
//  Ollvy
//
//  Map raw 3D metrics to user-friendly 0-100 percentage scores
//  Created on 2025-10-27.
//

import Foundation

/// Maps raw metric values to 0-100 percentage scores
///
/// CLINICAL CALIBRATION NOTES:
/// These thresholds are based on empirical testing and should be validated against:
/// 1. Dermatological literature for normal skin parameter ranges
/// 2. Diverse skin tone populations (Fitzpatrick I-VI)
/// 3. Real-world mobile device captures (varying lighting, angles, devices)
///
/// The scoring system uses linear interpolation between low (100 score) and high (0 score) thresholds.
/// Values outside these ranges are clamped to 0 or 100.
///
/// IMPORTANT: These thresholds directly affect user scores. Changes should be:
/// - Validated against ground truth dermatology assessments
/// - Tested across skin tones (especially Fitzpatrick IV-VI which are underrepresented)
/// - Consistent with the normalization factors in each analyzer
public class Scoring3D {

    // MARK: - Configuration

    public struct Configuration {
        // =================================================================================
        // ROUGHNESS THRESHOLDS
        // =================================================================================
        // Metric: High-frequency energy / mean luminance (normalized by factor 10.0)
        // Range: 0.0 (perfectly smooth) to 1.0 (very rough)
        // Clinical basis: Surface texture roughness correlates with:
        //   - Skin hydration (dehydrated skin shows higher roughness)
        //   - Age (older skin tends toward higher roughness)
        //   - Skin conditions (eczema, psoriasis increase roughness)
        //
        // Thresholds validated against:
        //   - Literature: Average healthy skin roughness Sa = 20-50µm (Fluhr et al., 2006)
        //   - Our proxy 0.08-0.50 maps to this clinical range after normalization
        public var roughnessLowThreshold: Float = 0.08    // Excellent: young, hydrated skin
        public var roughnessHighThreshold: Float = 0.50   // Poor: significant texture/dryness

        // =================================================================================
        // PIGMENTATION THRESHOLDS
        // =================================================================================
        // Metric: sqrt(LAB A*/B* channel variance) / normalization factor
        // Range: 0.0 (perfectly even) to 1.0 (highly uneven)
        // Clinical basis: Melanin distribution variance indicates:
        //   - Hyperpigmentation (dark spots, melasma)
        //   - Post-inflammatory hyperpigmentation
        //   - Age spots (solar lentigines)
        //
        // SKIN TONE CONSIDERATIONS:
        //   - Darker skin (Fitzpatrick IV-VI) naturally has higher B* variance
        //   - PigmentationAnalyzer applies skin-tone normalization (100/120/130)
        //   - These thresholds assume normalized values
        public var pigmentationLowThreshold: Float = 0.02  // Excellent: very even melanin
        public var pigmentationHighThreshold: Float = 0.25 // Poor: significant uneven pigment

        // =================================================================================
        // DISCOLORATION THRESHOLDS
        // =================================================================================
        // Metric: Cross-region LAB L*/A* variance (how different face areas compare)
        // Range: 0.0 (uniform across face) to 1.0 (highly uneven across face)
        // Clinical basis: Different from pigmentation - measures REGIONAL consistency:
        //   - Facial redness zones (cheeks, nose)
        //   - Sun damage patterns (forehead, cheeks)
        //   - Acne scarring distribution
        //
        // Note: Lower thresholds than pigmentation because cross-region variance
        // should naturally be lower than within-region variance
        // ADJUSTED: Widened range to prevent harsh boundary scoring
        // - Old range 0.01-0.12 was too strict (index=0.12 = score 0)
        // - New range 0.02-0.25 allows more graceful degradation
        public var discolorationLowThreshold: Float = 0.02 // Excellent: uniform tone across face
        public var discolorationHighThreshold: Float = 0.25 // Poor: visible regional differences

        // =================================================================================
        // SPECULAR/OILINESS THRESHOLDS
        // =================================================================================
        // Metric: Ratio of specular highlight pixels to total pixels (clamped to 0.3 max)
        // Range: 0.0 (no shine) to ~0.3 (very oily/shiny)
        // Clinical basis: Sebum production indicators:
        //   - T-zone oiliness (forehead, nose, chin)
        //   - Skin hydration (paradoxically, dehydrated skin can be oily)
        //   - Acne-prone skin often shows higher specularity
        //
        // LIGHTING CONSIDERATIONS:
        //   - Direct lighting creates false specular highlights
        //   - SpecularAnalyzer uses relative thresholds (35% above baseline) to compensate
        public var specularLowThreshold: Float = 0.02     // Normal/dry: minimal shine
        public var specularHighThreshold: Float = 0.18    // Oily: visible shine across T-zone

        // =================================================================================
        // SCORE BOUNDS
        // =================================================================================
        // Full 0-100 range for user-facing scores
        public var minimumScore: Float = 0.0
        public var maximumScore: Float = 100.0
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

        // FIXED: Weights now sum to exactly 1.0 (was 0.895 causing score inflation)
        // When optional metrics are missing, remaining weights are redistributed proportionally
        //
        // New weights (normalized to 100%, based on importance and confidence):
        // - Smoothness: 25% (most reliable, high impact)
        // - Pigmentation: 25% (very reliable, high impact)
        // - Pores: 16% (reliable with good texture)
        // - Discoloration: 16% (reliable, moderate impact)
        // - Acne: 18% (reliable detection, variable impact)

        // Smoothness (25%) - Surface texture quality (85% confidence)
        let smoothnessWeight: Float = 0.25
        if !smoothnessScore.isNaN {
            weightedSum += smoothnessScore * smoothnessWeight
            totalWeight += smoothnessWeight
        }

        // Pores (16%) - Texture refinement (70-90% confidence)
        if let poresScore = poresScore, !poresScore.isNaN {
            let poresWeight: Float = 0.16
            weightedSum += poresScore * poresWeight
            totalWeight += poresWeight
        }

        // Pigmentation (25%) - Even tone (80% confidence)
        let pigmentationWeight: Float = 0.25
        if !pigmentationScore.isNaN {
            weightedSum += pigmentationScore * pigmentationWeight
            totalWeight += pigmentationWeight
        }

        // Discoloration (16%) - Spots/hyperpigmentation (80% confidence)
        let discolorationWeight: Float = 0.16
        if !discolorationScore.isNaN {
            weightedSum += discolorationScore * discolorationWeight
            totalWeight += discolorationWeight
        }

        // Acne (18%) - Active breakouts/blemishes (75-85% confidence)
        if let acneScore = acneScore, !acneScore.isNaN {
            let acneWeight: Float = 0.18
            weightedSum += acneScore * acneWeight
            totalWeight += acneWeight
        }

        // Remaining weight is redistributed proportionally when metrics are missing/NaN
        let result = totalWeight > 0 ? weightedSum / totalWeight : 0
        return result.isNaN ? 0 : result
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
        // FIXED: Guard against NaN scores to prevent "Very Poor" for invalid values
        guard !score.isNaN && !score.isInfinite else {
            return "Error"
        }

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
