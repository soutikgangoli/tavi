//
//  ResultsInterpretation.swift
//  Tavi
//
//  Consumer-friendly interpretation of technical metrics
//  Translates scores to meaningful language and actionable recommendations
//

import Foundation

/// Consumer-friendly result interpretation
public struct InterpretedResults {
    public let overallHealthScore: Float  // 0-100
    public let overallRating: HealthRating
    public let summary: String
    public let detailedMetrics: [MetricInterpretation]
    public let recommendations: [ResultsRecommendation]
    public let percentileRankings: [String: Int]  // Metric -> percentile (0-100)

    public init(overallHealthScore: Float, overallRating: HealthRating, summary: String, detailedMetrics: [MetricInterpretation], recommendations: [ResultsRecommendation], percentileRankings: [String: Int]) {
        self.overallHealthScore = overallHealthScore
        self.overallRating = overallRating
        self.summary = summary
        self.detailedMetrics = detailedMetrics
        self.recommendations = recommendations
        self.percentileRankings = percentileRankings
    }
}

public enum HealthRating: String {
    case excellent = "Excellent"
    case veryGood = "Very Good"
    case good = "Good"
    case fair = "Fair"
    case needsAttention = "Needs Attention"

    public var color: String {
        switch self {
        case .excellent: return "green"
        case .veryGood: return "lightGreen"
        case .good: return "yellow"
        case .fair: return "orange"
        case .needsAttention: return "red"
        }
    }

    public var emoji: String {
        switch self {
        case .excellent: return "⭐"
        case .veryGood: return "✨"
        case .good: return "👍"
        case .fair: return "⚠️"
        case .needsAttention: return "🔴"
        }
    }
}

/// Individual metric interpretation
public struct MetricInterpretation {
    public let name: String
    public let score: Float
    public let rating: HealthRating
    public let percentile: Int
    public let description: String
    public let trend: String?  // "improving", "stable", "declining"

    public init(name: String, score: Float, rating: HealthRating, percentile: Int, description: String, trend: String?) {
        self.name = name
        self.score = score
        self.rating = rating
        self.percentile = percentile
        self.description = description
        self.trend = trend
    }
}

/// Actionable recommendation
public struct ResultsRecommendation {
    public let priority: ResultsPriority
    public let area: String
    public let suggestion: String
    public let expectedImpact: String

    public init(priority: ResultsPriority, area: String, suggestion: String, expectedImpact: String) {
        self.priority = priority
        self.area = area
        self.suggestion = suggestion
        self.expectedImpact = expectedImpact
    }
}

public enum ResultsPriority: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

/// Results interpreter
class ResultsInterpretation {

    // MARK: - Public API

    /// Interpret raw metrics into consumer-friendly format
    func interpret(
        roughness: Float,
        wrinkles: WrinkleAnalysis,
        hydration: HydrationEstimate,
        pores: PoreAnalysis,
        pigmentation: PigmentationAnalysis,
        temporalComparison: TemporalComparison?
    ) -> InterpretedResults {

        var detailedMetrics: [MetricInterpretation] = []
        var recommendations: [ResultsRecommendation] = []

        // Interpret Texture/Roughness
        let roughnessMetric = interpretRoughness(roughness, temporal: temporalComparison)
        detailedMetrics.append(roughnessMetric)
        if roughness > 70 {
            recommendations.append(ResultsRecommendation(
                priority: .high,
                area: "Texture",
                suggestion: "Use exfoliating products 2-3x per week",
                expectedImpact: "Smoother skin texture"
            ))
        }

        // Interpret Wrinkles
        let wrinkleMetric = interpretWrinkles(wrinkles, temporal: temporalComparison)
        detailedMetrics.append(wrinkleMetric)
        if wrinkles.overallScore < 60 {
            recommendations.append(ResultsRecommendation(
                priority: .medium,
                area: "Wrinkles",
                suggestion: "Consider retinol or anti-aging serum",
                expectedImpact: "Reduced wrinkle depth"
            ))
        }

        // Interpret Hydration
        let hydrationMetric = interpretHydration(hydration, temporal: temporalComparison)
        detailedMetrics.append(hydrationMetric)
        if hydration.overallScore < 60 {
            recommendations.append(ResultsRecommendation(
                priority: .high,
                area: "Hydration",
                suggestion: "Increase water intake and use hydrating moisturizer",
                expectedImpact: "Improved skin moisture"
            ))
        }

        // Interpret Pores
        let poresMetric = interpretPores(pores, temporal: temporalComparison)
        detailedMetrics.append(poresMetric)

        // Interpret Pigmentation
        let pigmentationMetric = interpretPigmentation(pigmentation, temporal: temporalComparison)
        detailedMetrics.append(pigmentationMetric)
        if pigmentation.evenness < 70 {
            recommendations.append(ResultsRecommendation(
                priority: .medium,
                area: "Pigmentation",
                suggestion: "Use SPF daily and consider vitamin C serum",
                expectedImpact: "More even skin tone"
            ))
        }

        // Calculate overall score
        let scores = detailedMetrics.map { $0.score }
        let overallScore = scores.reduce(0, +) / Float(scores.count)
        let overallRating = ratingFromScore(overallScore)

        // Generate summary
        let summary = generateSummary(
            overallRating: overallRating,
            overallScore: overallScore,
            topIssues: recommendations.prefix(2).map { $0.area }
        )

        // Mock percentile rankings (would be based on population data)
        let percentiles: [String: Int] = [
            "Texture": mockPercentile(roughness),
            "Wrinkles": mockPercentile(wrinkles.overallScore),
            "Hydration": mockPercentile(hydration.overallScore),
            "Pores": mockPercentile(100 - pores.visibility),
            "Pigmentation": mockPercentile(pigmentation.evenness)
        ]

        return InterpretedResults(
            overallHealthScore: overallScore,
            overallRating: overallRating,
            summary: summary,
            detailedMetrics: detailedMetrics,
            recommendations: recommendations,
            percentileRankings: percentiles
        )
    }

    // MARK: - Private Methods

    private func interpretRoughness(_ score: Float, temporal: TemporalComparison?) -> MetricInterpretation {
        let invertedScore = 100 - score  // Lower roughness = better
        let rating = ratingFromScore(invertedScore)

        let description: String
        if invertedScore >= 80 {
            description = "Your skin texture is very smooth with minimal roughness"
        } else if invertedScore >= 60 {
            description = "Your skin texture is good with some minor irregularities"
        } else if invertedScore >= 40 {
            description = "Your skin shows moderate roughness"
        } else {
            description = "Your skin has significant roughness that may benefit from treatment"
        }

        let trend = temporal?.changesSinceLastScan["roughness"].flatMap { interpretTrend($0) }

        return MetricInterpretation(
            name: "Skin Texture",
            score: invertedScore,
            rating: rating,
            percentile: mockPercentile(invertedScore),
            description: description,
            trend: trend
        )
    }

    private func interpretWrinkles(_ analysis: WrinkleAnalysis, temporal: TemporalComparison?) -> MetricInterpretation {
        let rating = ratingFromScore(analysis.overallScore)

        let description = "Wrinkle depth: \(analysis.wrinkleDepth). Detected \(analysis.wrinkleCount) wrinkle regions"

        let trend = temporal?.changesSinceLastScan["wrinkles"].flatMap { interpretTrend($0) }

        return MetricInterpretation(
            name: "Wrinkles",
            score: analysis.overallScore,
            rating: rating,
            percentile: mockPercentile(analysis.overallScore),
            description: description,
            trend: trend
        )
    }

    private func interpretHydration(_ estimate: HydrationEstimate, temporal: TemporalComparison?) -> MetricInterpretation {
        let rating = ratingFromScore(estimate.overallScore)

        let description = "Your skin appears \(estimate.level.rawValue.lowercased())"

        let trend = temporal?.changesSinceLastScan["hydration"].flatMap { interpretTrend($0) }

        return MetricInterpretation(
            name: "Hydration",
            score: estimate.overallScore,
            rating: rating,
            percentile: mockPercentile(estimate.overallScore),
            description: description,
            trend: trend
        )
    }

    private func interpretPores(_ analysis: PoreAnalysis, temporal: TemporalComparison?) -> MetricInterpretation {
        let invertedScore = 100 - analysis.visibility  // Lower visibility = better
        let rating = ratingFromScore(invertedScore)

        let description: String
        if analysis.visibility < 30 {
            description = "Pores are minimal and barely visible"
        } else if analysis.visibility < 60 {
            description = "Pores are moderately visible"
        } else {
            description = "Pores are highly visible"
        }

        let trend = temporal?.changesSinceLastScan["pores"].flatMap { interpretTrend(-$0) }  // Invert for visibility

        return MetricInterpretation(
            name: "Pore Visibility",
            score: invertedScore,
            rating: rating,
            percentile: mockPercentile(invertedScore),
            description: description,
            trend: trend
        )
    }

    private func interpretPigmentation(_ analysis: PigmentationAnalysis, temporal: TemporalComparison?) -> MetricInterpretation {
        let rating = ratingFromScore(analysis.evenness)

        let description = "Skin tone evenness: \(String(format: "%.0f", analysis.evenness))%. \(analysis.darkSpots) dark spots detected"

        let trend = temporal?.changesSinceLastScan["pigmentation"].flatMap { interpretTrend($0) }

        return MetricInterpretation(
            name: "Pigmentation",
            score: analysis.evenness,
            rating: rating,
            percentile: mockPercentile(analysis.evenness),
            description: description,
            trend: trend
        )
    }

    private func ratingFromScore(_ score: Float) -> HealthRating {
        if score >= 85 {
            return .excellent
        } else if score >= 75 {
            return .veryGood
        } else if score >= 60 {
            return .good
        } else if score >= 45 {
            return .fair
        } else {
            return .needsAttention
        }
    }

    private func interpretTrend(_ percentChange: Float) -> String {
        if percentChange > 5 {
            return "improving"
        } else if percentChange < -5 {
            return "declining"
        } else {
            return "stable"
        }
    }

    private func generateSummary(overallRating: HealthRating, overallScore: Float, topIssues: [String]) -> String {
        var summary = "Your skin health is \(overallRating.rawValue) with an overall score of \(String(format: "%.0f", overallScore))/100."

        if !topIssues.isEmpty {
            summary += " Focus areas: \(topIssues.joined(separator: ", "))."
        }

        return summary
    }

    private func mockPercentile(_ score: Float) -> Int {
        // Mock: convert score to percentile (would use real population data)
        return Int(score)
    }
}
