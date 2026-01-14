//
//  ResultsInterpretation.swift
//  Ollvy
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

    /// Factory method to create InterpretedResults from Face3DMetrics
    public static func from(metrics: Face3DMetrics) -> InterpretedResults {
        // Use the overall score from Face3DMetrics
        let overallScore = metrics.overallScore

        // Determine rating based on score
        let rating: HealthRating
        switch overallScore {
        case 90...100:
            rating = .excellent
        case 80..<90:
            rating = .veryGood
        case 70..<80:
            rating = .good
        case 60..<70:
            rating = .fair
        default:
            rating = .needsAttention
        }

        // Generate summary
        let summary = generateSummary(score: overallScore, rating: rating)

        // Create detailed metrics for each analyzed component
        var detailedMetrics: [MetricInterpretation] = []

        // Smoothness/Roughness
        detailedMetrics.append(MetricInterpretation(
            name: "Skin Smoothness",
            score: metrics.globalRoughnessScore,
            rating: ratingForScore(metrics.globalRoughnessScore),
            percentile: Int(metrics.globalRoughnessScore),
            description: "Overall skin texture and surface smoothness",
            trend: nil
        ))

        // Pigmentation
        detailedMetrics.append(MetricInterpretation(
            name: "Skin Tone Evenness",
            score: metrics.globalPigmentationScore,
            rating: ratingForScore(metrics.globalPigmentationScore),
            percentile: Int(metrics.globalPigmentationScore),
            description: "Uniformity of skin tone and pigmentation",
            trend: nil
        ))

        // Discoloration
        detailedMetrics.append(MetricInterpretation(
            name: "Discoloration",
            score: metrics.globalDiscolorationScore,
            rating: ratingForScore(metrics.globalDiscolorationScore),
            percentile: Int(metrics.globalDiscolorationScore),
            description: "Dark spots and hyperpigmentation",
            trend: nil
        ))

        // Add wrinkle analysis if available
        if let wrinkles = metrics.wrinkleAnalysis {
            detailedMetrics.append(MetricInterpretation(
                name: "Wrinkles & Fine Lines",
                score: wrinkles.overallScore,
                rating: ratingForScore(wrinkles.overallScore),
                percentile: Int(wrinkles.overallScore),
                description: "Wrinkle depth and fine line visibility",
                trend: nil
            ))
        }

        // Add pore analysis if available
        if let pores = metrics.poreAnalysis {
            let poreScore = 100 - pores.visibility // Invert so higher is better
            detailedMetrics.append(MetricInterpretation(
                name: "Pore Visibility",
                score: poreScore,
                rating: ratingForScore(poreScore),
                percentile: Int(poreScore),
                description: "Size and visibility of skin pores",
                trend: nil
            ))
        }

        // Generate recommendations based on weak areas
        let recommendations = generateRecommendations(metrics: metrics)

        // Calculate percentile rankings (simplified - using scores as percentiles)
        var percentileRankings: [String: Int] = [:]
        percentileRankings["Overall"] = Int(overallScore)
        percentileRankings["Smoothness"] = Int(metrics.globalRoughnessScore)
        percentileRankings["Pigmentation"] = Int(metrics.globalPigmentationScore)
        percentileRankings["Discoloration"] = Int(metrics.globalDiscolorationScore)

        return InterpretedResults(
            overallHealthScore: overallScore,
            overallRating: rating,
            summary: summary,
            detailedMetrics: detailedMetrics,
            recommendations: recommendations,
            percentileRankings: percentileRankings
        )
    }

    // MARK: - Helper Methods

    private static func generateSummary(score: Float, rating: HealthRating) -> String {
        switch rating {
        case .excellent:
            return "Your skin is in excellent condition! Keep up your current routine."
        case .veryGood:
            return "Your skin is looking very good with just minor areas for improvement."
        case .good:
            return "Your skin is in good condition with some areas that could benefit from targeted care."
        case .fair:
            return "Your skin shows moderate concerns that can be addressed with a consistent skincare routine."
        case .needsAttention:
            return "Your skin needs attention in several areas. A dedicated skincare routine will help improve these concerns."
        }
    }

    private static func ratingForScore(_ score: Float) -> HealthRating {
        switch score {
        case 90...100: return .excellent
        case 80..<90: return .veryGood
        case 70..<80: return .good
        case 60..<70: return .fair
        default: return .needsAttention
        }
    }

    private static func generateRecommendations(metrics: Face3DMetrics) -> [ResultsRecommendation] {
        var recommendations: [ResultsRecommendation] = []

        // Roughness recommendations
        if metrics.globalRoughnessScore < 70 {
            recommendations.append(ResultsRecommendation(
                priority: .high,
                area: "Skin Texture",
                suggestion: "Use a gentle exfoliating product 2-3 times per week to improve smoothness",
                expectedImpact: "Smoother, more refined skin texture within 2-4 weeks"
            ))
        }

        // Pigmentation recommendations
        if metrics.globalPigmentationScore < 70 {
            recommendations.append(ResultsRecommendation(
                priority: .high,
                area: "Skin Tone",
                suggestion: "Apply Vitamin C serum daily and use SPF 30+ sunscreen",
                expectedImpact: "More even skin tone within 4-6 weeks"
            ))
        }

        // Discoloration recommendations
        if metrics.globalDiscolorationScore < 70 {
            recommendations.append(ResultsRecommendation(
                priority: .medium,
                area: "Dark Spots",
                suggestion: "Use brightening serum with niacinamide or alpha arbutin",
                expectedImpact: "Reduced hyperpigmentation within 6-8 weeks"
            ))
        }

        // Wrinkle recommendations
        if let wrinkles = metrics.wrinkleAnalysis, wrinkles.overallScore < 70 {
            recommendations.append(ResultsRecommendation(
                priority: .medium,
                area: "Anti-Aging",
                suggestion: "Incorporate retinol serum 3-4 nights per week",
                expectedImpact: "Reduced fine lines and wrinkles within 8-12 weeks"
            ))
        }

        // Pore recommendations
        if let pores = metrics.poreAnalysis, pores.visibility > 30 {
            recommendations.append(ResultsRecommendation(
                priority: .low,
                area: "Pore Refinement",
                suggestion: "Use niacinamide serum and clay mask weekly",
                expectedImpact: "Minimized pore appearance within 3-4 weeks"
            ))
        }

        // Always recommend sun protection
        recommendations.append(ResultsRecommendation(
            priority: .high,
            area: "Sun Protection",
            suggestion: "Apply broad-spectrum SPF 30+ sunscreen every morning",
            expectedImpact: "Prevention of new damage and photoaging"
        ))

        return recommendations
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
        var summary = "Your skin analysis is \(overallRating.rawValue) with an overall score of \(String(format: "%.0f", overallScore))/100."

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
