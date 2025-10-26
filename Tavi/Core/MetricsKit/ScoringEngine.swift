//
//  ScoringEngine.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation

/// Converts raw metrics (0-1) to interpretable scores (0-100%) using linear ramps
public class ScoringEngine {

    private let constants: ScoringConstants

    public init(constants: ScoringConstants = .default) {
        self.constants = constants
    }

    // MARK: - Main Scoring Method

    /// Convert metrics result to score summary
    public func computeScores(from metrics: MetricsResult) -> ScoreSummary {
        // Compute per-ROI scores
        var roiScores: [ROIType: ROIScores] = [:]

        for (roiType, roiMetrics) in metrics.roiMetrics {
            let scores = computeROIScores(from: roiMetrics)
            roiScores[roiType] = scores
        }

        // Compute average scores
        let averageScores = computeAverageScores(roiScores: roiScores)

        // Compute discoloration score
        let discolorationScore = scoreDiscoloration(metrics.discolorationIndex)

        // Compute overall score
        let overallScore = computeOverallScore(
            averageComposite: averageScores.compositeScore,
            discolorationScore: discolorationScore
        )

        return ScoreSummary(
            roiScores: roiScores,
            averageScores: averageScores,
            overallScore: overallScore,
            timestamp: Date()
        )
    }

    // MARK: - Individual Metric Scoring (0-1 → 0-100%)

    /// Score sharpness: linear ramp from min to max
    /// Higher blur score → higher sharpness score
    public func scoreSharpness(_ blurScore: Double) -> Double {
        return linearRamp(
            value: blurScore,
            min: constants.sharpnessMin,
            max: constants.sharpnessMax
        )
    }

    /// Score texture quality: inverted linear ramp
    /// Lower texture energy → higher texture score (smoother = better)
    public func scoreTexture(_ textureEnergy: Double) -> Double {
        return invertedLinearRamp(
            value: textureEnergy,
            min: constants.textureMin,
            max: constants.textureMax
        )
    }

    /// Score pigmentation evenness: inverted linear ramp
    /// Lower LAB variance → higher pigmentation score (more even = better)
    public func scorePigmentation(_ labVariance: Double) -> Double {
        return invertedLinearRamp(
            value: labVariance,
            min: constants.pigmentationMin,
            max: constants.pigmentationMax
        )
    }

    /// Score moisture level: peak at ideal with tolerance
    /// Ideal moisture → 100%, far from ideal → 0%
    public func scoreMoisture(_ moistureIndex: Double) -> Double {
        return peakRamp(
            value: moistureIndex,
            ideal: constants.moistureIdeal,
            tolerance: constants.moistureTolerance,
            min: constants.moistureMin,
            max: constants.moistureMax
        )
    }

    /// Score skin tone uniformity: inverted linear ramp
    /// Lower discoloration → higher score (more uniform = better)
    public func scoreDiscoloration(_ discolorationIndex: Double) -> Double {
        return invertedLinearRamp(
            value: discolorationIndex,
            min: constants.discolorationMin,
            max: constants.discolorationMax
        )
    }

    // MARK: - ROI Scoring

    /// Compute all scores for a single ROI
    private func computeROIScores(from metrics: ROIMetrics) -> ROIScores {
        let sharpness = scoreSharpness(metrics.blurScore)
        let texture = scoreTexture(metrics.textureEnergy)
        let pigmentation = scorePigmentation(metrics.labVariance)
        let moisture = scoreMoisture(metrics.moistureProxy.moistureIndex)

        return ROIScores(
            sharpnessScore: sharpness,
            textureScore: texture,
            pigmentationScore: pigmentation,
            moistureScore: moisture,
            roiType: metrics.roiType
        )
    }

    /// Compute average scores across all ROIs
    private func computeAverageScores(roiScores: [ROIType: ROIScores]) -> ROIScores {
        guard !roiScores.isEmpty else {
            return ROIScores(
                sharpnessScore: 0,
                textureScore: 0,
                pigmentationScore: 0,
                moistureScore: 0,
                roiType: nil
            )
        }

        let scores = Array(roiScores.values)

        let avgSharpness = scores.map { $0.sharpnessScore }.reduce(0, +) / Double(scores.count)
        let avgTexture = scores.map { $0.textureScore }.reduce(0, +) / Double(scores.count)
        let avgPigmentation = scores.map { $0.pigmentationScore }.reduce(0, +) / Double(scores.count)
        let avgMoisture = scores.map { $0.moistureScore }.reduce(0, +) / Double(scores.count)

        return ROIScores(
            sharpnessScore: avgSharpness,
            textureScore: avgTexture,
            pigmentationScore: avgPigmentation,
            moistureScore: avgMoisture,
            roiType: nil
        )
    }

    /// Compute overall score from composite and discoloration
    private func computeOverallScore(
        averageComposite: Double,
        discolorationScore: Double
    ) -> Double {
        let weighted = averageComposite * constants.overallROIWeight +
                      discolorationScore * constants.overallDiscolorationWeight

        return clamp(weighted, min: 0.0, max: 100.0)
    }

    // MARK: - Ramp Functions (0-1 input → 0-100% output)

    /// Linear ramp: maps [min, max] → [0%, 100%]
    /// - value < min → 0%
    /// - value > max → 100%
    /// - value in between → linear interpolation
    private func linearRamp(value: Double, min: Double, max: Double) -> Double {
        guard max > min else { return 0.0 }

        let normalized = (value - min) / (max - min)
        let clamped = clamp(normalized, min: 0.0, max: 1.0)

        return clamped * 100.0  // Convert to percentage
    }

    /// Inverted linear ramp: maps [min, max] → [100%, 0%]
    /// - value < min → 100%
    /// - value > max → 0%
    /// - value in between → linear interpolation (inverted)
    private func invertedLinearRamp(value: Double, min: Double, max: Double) -> Double {
        guard max > min else { return 100.0 }

        let normalized = (value - min) / (max - min)
        let clamped = clamp(normalized, min: 0.0, max: 1.0)

        return (1.0 - clamped) * 100.0  // Invert and convert to percentage
    }

    /// Peak ramp: maximum at ideal, decreases away from ideal
    /// - value == ideal → 100%
    /// - value within tolerance → high score (linear decline)
    /// - value outside [min, max] → 0%
    private func peakRamp(
        value: Double,
        ideal: Double,
        tolerance: Double,
        min: Double,
        max: Double
    ) -> Double {
        // Clamp to valid range
        if value < min || value > max {
            return 0.0
        }

        let distance = abs(value - ideal)

        // Within tolerance: full or high score
        if distance <= tolerance {
            // Linear decline within tolerance zone
            let normalizedDistance = distance / tolerance
            return (1.0 - normalizedDistance * 0.1) * 100.0  // 90-100% within tolerance
        }

        // Outside tolerance: linear decline to 0
        if value < ideal {
            // Below ideal
            let range = ideal - tolerance - min
            if range <= 0 { return 0.0 }

            let distanceFromLowerBound = value - min
            let normalized = distanceFromLowerBound / range

            return clamp(normalized, min: 0.0, max: 1.0) * 90.0  // 0-90% below tolerance
        } else {
            // Above ideal
            let range = max - (ideal + tolerance)
            if range <= 0 { return 0.0 }

            let distanceFromUpperBound = max - value
            let normalized = distanceFromUpperBound / range

            return clamp(normalized, min: 0.0, max: 1.0) * 90.0  // 0-90% above tolerance
        }
    }

    /// Clamp value to [min, max]
    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        return Swift.min(Swift.max(value, min), max)
    }

    // MARK: - Batch Scoring

    /// Compute scores for multiple metrics results
    public func computeScores(from metricsResults: [MetricsResult]) -> [ScoreSummary] {
        return metricsResults.map { computeScores(from: $0) }
    }

    // MARK: - Score Interpretation

    /// Get human-readable interpretation for a score
    public func interpretScore(_ score: Double) -> String {
        let grade = ScoreGrade.from(score: score)
        return grade.interpretation
    }

    /// Get detailed breakdown of scoring
    public func scoringBreakdown(for metrics: MetricsResult) -> String {
        let scores = computeScores(from: metrics)

        var breakdown = "Scoring Breakdown:\n\n"

        breakdown += "Average Scores:\n"
        breakdown += "  Sharpness: \(String(format: "%.1f%%", scores.averageScores.sharpnessScore))\n"
        breakdown += "  Texture: \(String(format: "%.1f%%", scores.averageScores.textureScore))\n"
        breakdown += "  Pigmentation: \(String(format: "%.1f%%", scores.averageScores.pigmentationScore))\n"
        breakdown += "  Moisture: \(String(format: "%.1f%%", scores.averageScores.moistureScore))\n"
        breakdown += "  Composite: \(String(format: "%.1f%%", scores.averageScores.compositeScore))\n\n"

        let discolorationScore = scoreDiscoloration(metrics.discolorationIndex)
        breakdown += "Discoloration Score: \(String(format: "%.1f%%", discolorationScore))\n\n"

        breakdown += "Overall Score: \(String(format: "%.1f%%", scores.overallScore))\n"
        breakdown += "Grade: \(scores.grade.rawValue) (\(scores.grade.description))\n"

        return breakdown
    }
}

// MARK: - Convenience Extensions

extension MetricsResult {
    /// Compute scores using default engine
    public func scores(using engine: ScoringEngine = ScoringEngine()) -> ScoreSummary {
        return engine.computeScores(from: self)
    }
}

extension ROIMetrics {
    /// Compute scores for this ROI using default engine
    public func scores(using engine: ScoringEngine = ScoringEngine()) -> ROIScores {
        let sharpness = engine.scoreSharpness(blurScore)
        let texture = engine.scoreTexture(textureEnergy)
        let pigmentation = engine.scorePigmentation(labVariance)
        let moisture = engine.scoreMoisture(moistureProxy.moistureIndex)

        return ROIScores(
            sharpnessScore: sharpness,
            textureScore: texture,
            pigmentationScore: pigmentation,
            moistureScore: moisture,
            roiType: roiType
        )
    }
}
