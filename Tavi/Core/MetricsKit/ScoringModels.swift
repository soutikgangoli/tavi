//
//  ScoringModels.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation

// MARK: - Score Summary

/// Complete scoring summary with 0-100% scores for all metrics
public struct ScoreSummary {
    /// Per-ROI scores
    public let roiScores: [ROIType: ROIScores]

    /// Average scores across all ROIs
    public let averageScores: ROIScores

    /// Overall composite score (0-100%)
    public let overallScore: Double

    /// Timestamp of scoring
    public let timestamp: Date

    /// Overall quality grade
    public var grade: ScoreGrade {
        ScoreGrade.from(score: overallScore)
    }

    public init(
        roiScores: [ROIType: ROIScores],
        averageScores: ROIScores,
        overallScore: Double,
        timestamp: Date = Date()
    ) {
        self.roiScores = roiScores
        self.averageScores = averageScores
        self.overallScore = overallScore
        self.timestamp = timestamp
    }
}

// MARK: - ROI Scores

/// Individual scores for a single ROI (all 0-100%)
public struct ROIScores {
    /// Sharpness score (0-100%, higher is better)
    public let sharpnessScore: Double

    /// Texture quality score (0-100%, higher is smoother)
    public let textureScore: Double

    /// Pigmentation evenness score (0-100%, higher is more even)
    public let pigmentationScore: Double

    /// Moisture level score (0-100%, ~60% is ideal)
    public let moistureScore: Double

    /// ROI type this score belongs to
    public let roiType: ROIType?

    /// Composite quality score (0-100%)
    public var compositeScore: Double {
        // Weighted average of all scores
        let weights = ScoringConstants.compositeWeights

        return sharpnessScore * weights.sharpness +
               textureScore * weights.texture +
               pigmentationScore * weights.pigmentation +
               moistureScore * weights.moisture
    }

    /// Quality grade for this ROI
    public var grade: ScoreGrade {
        ScoreGrade.from(score: compositeScore)
    }

    public init(
        sharpnessScore: Double,
        textureScore: Double,
        pigmentationScore: Double,
        moistureScore: Double,
        roiType: ROIType? = nil
    ) {
        self.sharpnessScore = sharpnessScore
        self.textureScore = textureScore
        self.pigmentationScore = pigmentationScore
        self.moistureScore = moistureScore
        self.roiType = roiType
    }
}

// MARK: - Score Grade

/// Letter grade representation of scores (0-100%)
public enum ScoreGrade: String, CaseIterable {
    case excellent = "A"
    case good = "B"
    case fair = "C"
    case poor = "D"
    case veryPoor = "F"

    /// Create grade from 0-100% score
    public static func from(score: Double) -> ScoreGrade {
        switch score {
        case 90.0...100.0:
            return .excellent
        case 70.0..<90.0:
            return .good
        case 50.0..<70.0:
            return .fair
        case 30.0..<50.0:
            return .poor
        default:
            return .veryPoor
        }
    }

    /// Human-readable description
    public var description: String {
        switch self {
        case .excellent:
            return "Excellent"
        case .good:
            return "Good"
        case .fair:
            return "Fair"
        case .poor:
            return "Poor"
        case .veryPoor:
            return "Very Poor"
        }
    }

    /// Detailed interpretation
    public var interpretation: String {
        switch self {
        case .excellent:
            return "Outstanding skin quality with excellent clarity and uniformity"
        case .good:
            return "Good skin quality with minor areas for improvement"
        case .fair:
            return "Moderate skin quality - may benefit from targeted care"
        case .poor:
            return "Below average quality - recommend skincare attention"
        case .veryPoor:
            return "Significant concerns detected - consider professional consultation"
        }
    }

    /// Score range for this grade
    public var scoreRange: String {
        switch self {
        case .excellent:
            return "90-100%"
        case .good:
            return "70-89%"
        case .fair:
            return "50-69%"
        case .poor:
            return "30-49%"
        case .veryPoor:
            return "0-29%"
        }
    }
}

// MARK: - Scoring Constants

/// Configurable thresholds for metric-to-score conversion (all 0-1 → 0-100%)
public struct ScoringConstants {

    // MARK: - Sharpness Thresholds (blur score → 0-100%)

    /// Below this blur score maps to 0%
    public let sharpnessMin: Double

    /// Above this blur score maps to 100%
    public let sharpnessMax: Double

    // MARK: - Texture Thresholds (texture energy → 0-100%)

    /// Below this texture energy maps to 100% (inverted - lower is better)
    public let textureMin: Double

    /// Above this texture energy maps to 0% (inverted)
    public let textureMax: Double

    // MARK: - Pigmentation Thresholds (LAB variance → 0-100%)

    /// Below this LAB variance maps to 100% (inverted - lower is better)
    public let pigmentationMin: Double

    /// Above this LAB variance maps to 0% (inverted)
    public let pigmentationMax: Double

    // MARK: - Moisture Thresholds (moisture index → 0-100%)

    /// Ideal moisture index (maps to 100%)
    public let moistureIdeal: Double

    /// Moisture tolerance range (±tolerance around ideal still scores high)
    public let moistureTolerance: Double

    /// Minimum moisture (maps to 0% - very dry)
    public let moistureMin: Double

    /// Maximum moisture (maps to 0% - very oily)
    public let moistureMax: Double

    // MARK: - Discoloration Thresholds (discoloration index → 0-100%)

    /// Below this discoloration maps to 100% (inverted)
    public let discolorationMin: Double

    /// Above this discoloration maps to 0% (inverted)
    public let discolorationMax: Double

    // MARK: - Composite Weights

    /// Weights for combining individual scores
    public struct CompositeWeights {
        public let sharpness: Double
        public let texture: Double
        public let pigmentation: Double
        public let moisture: Double

        public init(sharpness: Double, texture: Double, pigmentation: Double, moisture: Double) {
            // Ensure weights sum to 1.0
            let sum = sharpness + texture + pigmentation + moisture
            self.sharpness = sharpness / sum
            self.texture = texture / sum
            self.pigmentation = pigmentation / sum
            self.moisture = moisture / sum
        }
    }

    public let compositeWeights: CompositeWeights

    // MARK: - Overall Score Weights

    /// Weight for average ROI quality in overall score
    public let overallROIWeight: Double

    /// Weight for discoloration in overall score
    public let overallDiscolorationWeight: Double

    // MARK: - Initialization

    public init(
        sharpnessMin: Double = 0.3,
        sharpnessMax: Double = 0.9,
        textureMin: Double = 0.1,
        textureMax: Double = 0.7,
        pigmentationMin: Double = 0.1,
        pigmentationMax: Double = 0.6,
        moistureIdeal: Double = 0.6,
        moistureTolerance: Double = 0.15,
        moistureMin: Double = 0.0,
        moistureMax: Double = 1.0,
        discolorationMin: Double = 0.1,
        discolorationMax: Double = 0.6,
        compositeWeights: CompositeWeights = CompositeWeights(
            sharpness: 0.35,
            texture: 0.25,
            pigmentation: 0.25,
            moisture: 0.15
        ),
        overallROIWeight: Double = 0.75,
        overallDiscolorationWeight: Double = 0.25
    ) {
        self.sharpnessMin = sharpnessMin
        self.sharpnessMax = sharpnessMax
        self.textureMin = textureMin
        self.textureMax = textureMax
        self.pigmentationMin = pigmentationMin
        self.pigmentationMax = pigmentationMax
        self.moistureIdeal = moistureIdeal
        self.moistureTolerance = moistureTolerance
        self.moistureMin = moistureMin
        self.moistureMax = moistureMax
        self.discolorationMin = discolorationMin
        self.discolorationMax = discolorationMax
        self.compositeWeights = compositeWeights

        // Normalize overall weights
        let sum = overallROIWeight + overallDiscolorationWeight
        self.overallROIWeight = overallROIWeight / sum
        self.overallDiscolorationWeight = overallDiscolorationWeight / sum
    }

    // MARK: - Presets

    /// Default scoring constants
    public static let `default` = ScoringConstants()

    /// Strict scoring (harder to get high scores)
    public static let strict = ScoringConstants(
        sharpnessMin: 0.4,
        sharpnessMax: 0.95,
        textureMin: 0.05,
        textureMax: 0.6,
        pigmentationMin: 0.05,
        pigmentationMax: 0.5,
        moistureIdeal: 0.6,
        moistureTolerance: 0.1,
        discolorationMin: 0.05,
        discolorationMax: 0.5
    )

    /// Lenient scoring (easier to get high scores)
    public static let lenient = ScoringConstants(
        sharpnessMin: 0.2,
        sharpnessMax: 0.85,
        textureMin: 0.15,
        textureMax: 0.8,
        pigmentationMin: 0.15,
        pigmentationMax: 0.7,
        moistureIdeal: 0.6,
        moistureTolerance: 0.2,
        discolorationMin: 0.15,
        discolorationMax: 0.7
    )
}

// MARK: - Score Change

/// Represents change in scores over time
public struct ScoreChange {
    public let current: ScoreSummary
    public let previous: ScoreSummary

    /// Overall score change (percentage points)
    public var overallChange: Double {
        current.overallScore - previous.overallScore
    }

    /// Change interpretation
    public var interpretation: String {
        let change = overallChange

        if abs(change) < 5.0 {
            return "No significant change"
        } else if change > 20.0 {
            return "Significant improvement"
        } else if change > 5.0 {
            return "Improved"
        } else if change < -20.0 {
            return "Significant decline"
        } else {
            return "Declined"
        }
    }

    /// Per-metric changes (percentage points)
    public func averageScoreChanges() -> (
        sharpness: Double,
        texture: Double,
        pigmentation: Double,
        moisture: Double
    ) {
        let curr = current.averageScores
        let prev = previous.averageScores

        return (
            sharpness: curr.sharpnessScore - prev.sharpnessScore,
            texture: curr.textureScore - prev.textureScore,
            pigmentation: curr.pigmentationScore - prev.pigmentationScore,
            moisture: curr.moistureScore - prev.moistureScore
        )
    }

    public init(current: ScoreSummary, previous: ScoreSummary) {
        self.current = current
        self.previous = previous
    }
}
