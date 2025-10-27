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
        // Roughness thresholds
        public var roughnessLowThreshold: Float = 0.10    // Maps to 20%
        public var roughnessHighThreshold: Float = 0.35   // Maps to 90%

        // Pigmentation thresholds
        public var pigmentationLowThreshold: Float = 0.03  // Maps to 20%
        public var pigmentationHighThreshold: Float = 0.15 // Maps to 90%

        // Discoloration thresholds
        public var discolorationLowThreshold: Float = 0.01 // Maps to 20%
        public var discolorationHighThreshold: Float = 0.06 // Maps to 90%

        // Specular/Oiliness thresholds
        public var specularLowThreshold: Float = 0.02     // Maps to 20%
        public var specularHighThreshold: Float = 0.12    // Maps to 90%

        // Score bounds (percentage scale)
        public var minimumScore: Float = 0.0
        public var maximumScore: Float = 100.0

        // Low/high score mappings (percentage scale)
        public var lowScoreValue: Float = 20.0    // Score for low threshold
        public var highScoreValue: Float = 90.0   // Score for high threshold

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
    public func mapPigmentationScore(_ pigmentationIndex: Float) -> Float {
        return mapMetricToScore(
            value: pigmentationIndex,
            lowThreshold: configuration.pigmentationLowThreshold,
            highThreshold: configuration.pigmentationHighThreshold,
            inverted: true  // Lower is better
        )
    }

    /// Map discoloration index (0-1) to percentage score (0-100)
    /// Lower discoloration = better score (higher percentage)
    public func mapDiscolorationScore(_ discolorationIndex: Float) -> Float {
        return mapMetricToScore(
            value: discolorationIndex,
            lowThreshold: configuration.discolorationLowThreshold,
            highThreshold: configuration.discolorationHighThreshold,
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

    /// Compute overall skin quality score (weighted average)
    public func computeOverallScore(
        roughnessScore: Float,
        pigmentationScore: Float,
        discolorationScore: Float,
        specularScore: Float?
    ) -> Float {

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
