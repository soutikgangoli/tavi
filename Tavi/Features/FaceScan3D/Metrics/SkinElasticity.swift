//
//  SkinElasticity.swift
//  Tavi
//
//  Skin elasticity estimation from temporal wrinkle recovery
//  HIGH VALUE metric for aging analysis
//

import Foundation
import simd

/// Skin elasticity analysis result
public struct ElasticityAnalysis {
    let overallScore: Float  // 0-100, higher = better elasticity
    let elasticityLevel: ElasticityLevel
    let recoveryRate: Float  // How fast wrinkles recover (0-1)
    let regionalElasticity: [FaceRegion: Float]
}

public enum ElasticityLevel: String {
    case excellent = "Excellent"
    case good = "Good"
    case moderate = "Moderate"
    case poor = "Poor"
}

/// Skin elasticity analyzer
public class SkinElasticityAnalyzer {

    // MARK: - Properties

    private let temporalWindow: TimeInterval = 30 * 24 * 3600  // 30 days

    // MARK: - Public API

    /// Estimate elasticity from temporal wrinkle data
    public func estimateElasticity(
        historicalScans: [HistoricalScan],
        currentWrinkleDepth: Float
    ) -> ElasticityAnalysis {

        guard historicalScans.count >= 2 else {
            // Not enough data, return moderate estimate
            return ElasticityAnalysis(
                overallScore: 60,
                elasticityLevel: .moderate,
                recoveryRate: 0.5,
                regionalElasticity: [:]
            )
        }

        // Calculate recovery rate from wrinkle depth changes
        let recoveryRate = calculateRecoveryRate(scans: historicalScans)

        // Estimate overall elasticity score
        let score = elasticityScore(from: recoveryRate, currentDepth: currentWrinkleDepth)

        // Classify level
        let level = classifyElasticity(score: score)

        // Regional analysis
        let regional = estimateRegionalElasticity(scans: historicalScans)

        return ElasticityAnalysis(
            overallScore: score,
            elasticityLevel: level,
            recoveryRate: recoveryRate,
            regionalElasticity: regional
        )
    }

    // MARK: - Private Methods

    private func calculateRecoveryRate(scans: [HistoricalScan]) -> Float {
        // Analyze how quickly wrinkle depth changes over time
        // Higher variation = better elasticity (skin bounces back)

        var depthChanges: [Float] = []

        for i in 1..<scans.count {
            let timeDelta = scans[i].timestamp - scans[i-1].timestamp
            let depthDelta = abs(scans[i].wrinkleDepth - scans[i-1].wrinkleDepth)

            // Normalize by time
            let rate = depthDelta / Float(timeDelta / 3600)  // per hour
            depthChanges.append(rate)
        }

        // Average recovery rate
        let avgRate = depthChanges.reduce(0, +) / Float(max(depthChanges.count, 1))

        // Normalize to 0-1 (higher = better elasticity)
        return min(1.0, avgRate * 10)
    }

    private func elasticityScore(from recoveryRate: Float, currentDepth: Float) -> Float {
        // Combine recovery rate with absolute wrinkle depth
        // Better elasticity = faster recovery + shallower wrinkles

        let recoveryComponent = recoveryRate * 60  // 0-60 points
        let depthComponent = (1.0 - min(currentDepth / 2.0, 1.0)) * 40  // 0-40 points

        return recoveryComponent + depthComponent
    }

    private func classifyElasticity(score: Float) -> ElasticityLevel {
        if score >= 80 {
            return .excellent
        } else if score >= 65 {
            return .good
        } else if score >= 50 {
            return .moderate
        } else {
            return .poor
        }
    }

    private func estimateRegionalElasticity(scans: [HistoricalScan]) -> [FaceRegion: Float] {
        // Would analyze regional changes over time
        // For now, return empty (requires region-specific wrinkle tracking)
        return [:]
    }
}

/// Historical scan data for temporal analysis
public struct HistoricalScan {
    let timestamp: TimeInterval
    let wrinkleDepth: Float
    let wrinkleCount: Int
}

/// Face regions for analysis
public enum FaceRegion: String, CaseIterable {
    case forehead = "Forehead"
    case eyes = "Eye Area"
    case cheeks = "Cheeks"
    case mouth = "Mouth"
    case chin = "Chin"
}
