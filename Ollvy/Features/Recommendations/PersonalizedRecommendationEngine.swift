//
//  PersonalizedRecommendationEngine.swift
//  Ollvy
//
//  Personalized recommendation engine with severity-based prioritization
//  CRITICAL FOR CONSUMER HAPPINESS
//

import Foundation

/// Personalized recommendations based on profile + metrics
public struct PersonalizedRecommendations {
    let highPriority: [Recommendation]
    let mediumPriority: [Recommendation]
    let lowPriority: [Recommendation]
    let seasonalAdjustments: [SeasonalAdjustment]
    let lifestyleImpact: LifestyleImpact
}

/// Single recommendation
public struct Recommendation {
    let id: UUID
    let area: String  // e.g., "Hydration", "Wrinkles"
    let concern: SkinConcern?
    let priority: Priority
    let severity: Severity
    let suggestion: String
    let expectedImpact: String
    let timeframe: String
    let productRecommendations: [ProductRecommendation]
    let lifestyleTips: [String]
    let citationKeys: [CitationKey]  // Scientific references for this recommendation
}

public enum Priority: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

public enum Severity: String {
    case critical = "Critical"
    case moderate = "Moderate"
    case minor = "Minor"
}

/// Product recommendation
public struct ProductRecommendation {
    let category: ProductCategory
    let ingredients: [String]
    let usage: String  // "Morning", "Night", "2x daily"
    let exampleProducts: [String]  // Brand names (if partnering)
}

/// Seasonal adjustment
public struct SeasonalAdjustment {
    let season: Season
    let adjustments: [String]
}

public enum Season {
    case spring, summer, fall, winter

    static func current() -> Season {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .fall
        default: return .winter
        }
    }
}

/// Lifestyle impact analysis
public struct LifestyleImpact {
    let positiveFactors: [String]
    let negativeFactors: [String]
    let suggestions: [String]
}

/// Personalized recommendation engine
public class PersonalizedRecommendationEngine {

    // MARK: - Public API

    /// Generate personalized recommendations
    public func generateRecommendations(
        profile: UserProfile,
        metrics: InterpretedResults,
        scanQuality: ScanQuality
    ) -> PersonalizedRecommendations {

        var highPriority: [Recommendation] = []
        var mediumPriority: [Recommendation] = []
        var lowPriority: [Recommendation] = []

        // Analyze each metric
        for metricInterp in metrics.detailedMetrics {
            let recommendations = analyzeMetric(
                metric: metricInterp,
                profile: profile,
                concerns: profile.skinConcerns,
                goals: profile.skinGoals
            )

            // Sort by priority
            for rec in recommendations {
                switch rec.priority {
                case .high:
                    highPriority.append(rec)
                case .medium:
                    mediumPriority.append(rec)
                case .low:
                    lowPriority.append(rec)
                }
            }
        }

        // Add age-specific recommendations
        if let age = profile.age {
            highPriority.append(contentsOf: getAgeSpecificRecommendations(age: age))
        }

        // Seasonal adjustments
        let seasonalAdj = getSeasonalAdjustments(season: Season.current(), profile: profile)

        // Lifestyle impact
        let lifestyleImpact = analyzeLifestyleImpact(factors: profile.lifestyleFactors)

        return PersonalizedRecommendations(
            highPriority: highPriority,
            mediumPriority: mediumPriority,
            lowPriority: lowPriority,
            seasonalAdjustments: seasonalAdj,
            lifestyleImpact: lifestyleImpact
        )
    }

    // MARK: - Metric Analysis

    private func analyzeMetric(
        metric: MetricInterpretation,
        profile: UserProfile,
        concerns: Set<SkinConcern>,
        goals: Set<SkinGoal>
    ) -> [Recommendation] {

        var recommendations: [Recommendation] = []

        // Determine priority based on score + user concerns
        let priority = determinePriority(score: metric.score, concerns: concerns, metricName: metric.name)
        let severity = determineSeverity(score: metric.score)

        switch metric.name {
        case "Skin Texture":
            if metric.score < 70 {
                recommendations.append(createTextureRecommendation(
                    score: metric.score,
                    priority: priority,
                    severity: severity,
                    profile: profile
                ))
            }

        case "Wrinkles":
            if metric.score < 75 || concerns.contains(.wrinkles) {
                recommendations.append(createWrinkleRecommendation(
                    score: metric.score,
                    priority: priority,
                    severity: severity,
                    profile: profile
                ))
            }

        case "Hydration":
            if metric.score < 65 {
                recommendations.append(createHydrationRecommendation(
                    score: metric.score,
                    priority: priority,
                    severity: severity,
                    profile: profile
                ))
            }

        case "Pore Visibility":
            if metric.score < 70 || concerns.contains(.largePores) {
                recommendations.append(createPoreRecommendation(
                    score: metric.score,
                    priority: priority,
                    severity: severity,
                    profile: profile
                ))
            }

        case "Pigmentation":
            if metric.score < 75 || concerns.contains(.darkSpots) {
                recommendations.append(createPigmentationRecommendation(
                    score: metric.score,
                    priority: priority,
                    severity: severity,
                    profile: profile
                ))
            }

        default:
            break
        }

        return recommendations
    }

    // MARK: - Priority & Severity

    private func determinePriority(score: Float, concerns: Set<SkinConcern>, metricName: String) -> Priority {
        // If user has this as a concern, bump priority
        let isConcern = concerns.contains { concern in
            metricName.lowercased().contains(concern.rawValue.lowercased())
        }

        if score < 50 || isConcern {
            return .high
        } else if score < 70 {
            return .medium
        } else {
            return .low
        }
    }

    private func determineSeverity(score: Float) -> Severity {
        if score < 40 {
            return .critical
        } else if score < 60 {
            return .moderate
        } else {
            return .minor
        }
    }

    // MARK: - Specific Recommendations

    private func createTextureRecommendation(
        score: Float,
        priority: Priority,
        severity: Severity,
        profile: UserProfile
    ) -> Recommendation {

        let suggestion: String
        let timeframe: String

        if score < 50 {
            suggestion = "Start a comprehensive exfoliation routine with AHAs/BHAs 3x weekly, plus daily retinol"
            timeframe = "4-6 weeks"
        } else {
            suggestion = "Add gentle exfoliation 2x weekly and consider a retinol product"
            timeframe = "6-8 weeks"
        }

        return Recommendation(
            id: UUID(),
            area: "Skin Texture",
            concern: .dryness,
            priority: priority,
            severity: severity,
            suggestion: suggestion,
            expectedImpact: "Smoother, more refined skin texture",
            timeframe: timeframe,
            productRecommendations: [
                ProductRecommendation(
                    category: .exfoliant,
                    ingredients: ["Glycolic Acid", "Lactic Acid", "Salicylic Acid"],
                    usage: "Night, 2-3x weekly",
                    exampleProducts: ["Paula's Choice 2% BHA", "The Ordinary AHA 30% + BHA 2%"]
                ),
                ProductRecommendation(
                    category: .retinol,
                    ingredients: ["Retinol", "Retinaldehyde"],
                    usage: "Night, start 2x weekly",
                    exampleProducts: ["CeraVe Resurfacing Retinol", "The Ordinary Retinol 0.5%"]
                )
            ],
            lifestyleTips: [
                "Drink 8 glasses of water daily",
                "Use a gentle cleanser (avoid harsh scrubs)",
                "Always apply SPF 30+ in the morning"
            ],
            citationKeys: [.texture]
        )
    }

    private func createWrinkleRecommendation(
        score: Float,
        priority: Priority,
        severity: Severity,
        profile: UserProfile
    ) -> Recommendation {

        let isOver40 = (profile.age ?? 30) >= 40

        let suggestion = isOver40
            ? "Consider professional treatments from dermatologist + peptide serum + SPF 50+"
            : "Start retinol products + vitamin C serum + daily SPF 30+"

        let timeframe = isOver40 ? "8-12 weeks" : "6-10 weeks"

        return Recommendation(
            id: UUID(),
            area: "Wrinkles & Fine Lines",
            concern: .wrinkles,
            priority: priority,
            severity: severity,
            suggestion: suggestion,
            expectedImpact: "Reduced wrinkle appearance and smoothed fine lines",
            timeframe: timeframe,
            productRecommendations: [
                ProductRecommendation(
                    category: .retinol,
                    ingredients: ["Retinol", "Peptides"],
                    usage: "Night only",
                    exampleProducts: ["Differin Gel", "The Ordinary Retinol 1%"]
                ),
                ProductRecommendation(
                    category: .serum,
                    ingredients: ["Peptides", "Niacinamide"],
                    usage: "Morning and night",
                    exampleProducts: ["The Ordinary Buffet", "Olay Regenerist Serum"]
                ),
                ProductRecommendation(
                    category: .eyeCream,
                    ingredients: ["Caffeine", "Retinol", "Peptides"],
                    usage: "Morning and night",
                    exampleProducts: ["CeraVe Eye Repair Cream", "RoC Retinol Correxion Eye Cream"]
                )
            ],
            lifestyleTips: [
                "Get 7-8 hours of sleep (skin repairs at night)",
                "Avoid smoking (accelerates wrinkles)",
                "Manage stress (cortisol ages skin)",
                "Sleep on your back (reduces face compression)"
            ],
            citationKeys: [.wrinkles]
        )
    }

    private func createHydrationRecommendation(
        score: Float,
        priority: Priority,
        severity: Severity,
        profile: UserProfile
    ) -> Recommendation {

        return Recommendation(
            id: UUID(),
            area: "Hydration",
            concern: .dryness,
            priority: priority,
            severity: severity,
            suggestion: "Layer hyaluronic acid serum + rich moisturizer, increase water intake to 8 glasses/day",
            expectedImpact: "Plumper, more supple skin with reduced fine lines",
            timeframe: "2-4 weeks",
            productRecommendations: [
                ProductRecommendation(
                    category: .serum,
                    ingredients: ["Hyaluronic Acid", "Glycerin"],
                    usage: "Morning and night (on damp skin)",
                    exampleProducts: ["The Ordinary Hyaluronic Acid 2% + B5", "Neutrogena Hydro Boost Serum"]
                ),
                ProductRecommendation(
                    category: .moisturizer,
                    ingredients: ["Ceramides", "Squalane", "Shea Butter"],
                    usage: "Morning and night",
                    exampleProducts: ["CeraVe Moisturizing Cream", "La Roche-Posay Toleriane Double Repair"]
                )
            ],
            lifestyleTips: [
                "Drink 8+ glasses of water daily",
                "Use a humidifier (especially in winter)",
                "Avoid hot showers (strip natural oils)",
                "Limit caffeine and alcohol (dehydrating)"
            ],
            citationKeys: [.hydration]
        )
    }

    private func createPoreRecommendation(
        score: Float,
        priority: Priority,
        severity: Severity,
        profile: UserProfile
    ) -> Recommendation {

        return Recommendation(
            id: UUID(),
            area: "Pore Visibility",
            concern: .largePores,
            priority: priority,
            severity: severity,
            suggestion: "Use salicylic acid cleanser + niacinamide serum to minimize pore appearance",
            expectedImpact: "Reduced pore visibility and smoother texture",
            timeframe: "4-6 weeks",
            productRecommendations: [
                ProductRecommendation(
                    category: .cleanser,
                    ingredients: ["Salicylic Acid (BHA)"],
                    usage: "Morning and/or night",
                    exampleProducts: ["CeraVe SA Cleanser", "Paula's Choice Pore Normalizing Cleanser"]
                ),
                ProductRecommendation(
                    category: .serum,
                    ingredients: ["Niacinamide", "Zinc"],
                    usage: "Morning and night",
                    exampleProducts: ["The Ordinary Niacinamide 10% + Zinc 1%", "Paula's Choice 10% Niacinamide"]
                )
            ],
            lifestyleTips: [
                "Always remove makeup before bed",
                "Exfoliate 2-3x weekly (prevents clogging)",
                "Avoid touching your face",
                "Keep hair products away from face"
            ],
            citationKeys: [.pores]
        )
    }

    private func createPigmentationRecommendation(
        score: Float,
        priority: Priority,
        severity: Severity,
        profile: UserProfile
    ) -> Recommendation {

        return Recommendation(
            id: UUID(),
            area: "Pigmentation & Dark Spots",
            concern: .darkSpots,
            priority: priority,
            severity: severity,
            suggestion: "Daily SPF 50+ (most important!) + vitamin C serum + niacinamide for dark spot fading",
            expectedImpact: "More even skin tone and faded dark spots",
            timeframe: "8-12 weeks",
            productRecommendations: [
                ProductRecommendation(
                    category: .sunscreen,
                    ingredients: ["Zinc Oxide", "Titanium Dioxide", "SPF 50+"],
                    usage: "Every morning (reapply every 2 hours)",
                    exampleProducts: ["La Roche-Posay Anthelios", "EltaMD UV Clear SPF 46"]
                ),
                ProductRecommendation(
                    category: .vitaminC,
                    ingredients: ["L-Ascorbic Acid", "Vitamin C"],
                    usage: "Morning (before SPF)",
                    exampleProducts: ["Timeless Vitamin C + E Serum", "SkinCeuticals C E Ferulic"]
                ),
                ProductRecommendation(
                    category: .serum,
                    ingredients: ["Niacinamide", "Tranexamic Acid", "Alpha Arbutin"],
                    usage: "Night",
                    exampleProducts: ["The Ordinary Alpha Arbutin 2%", "Paula's Choice Discoloration Repair"]
                )
            ],
            lifestyleTips: [
                "NEVER skip SPF (sun exposure worsens dark spots)",
                "Wear a hat outdoors",
                "Avoid tanning beds completely",
                "Be patient - pigmentation takes months to fade"
            ],
            citationKeys: [.pigmentation, .sunDamage]
        )
    }

    // MARK: - Age-Specific Recommendations

    private func getAgeSpecificRecommendations(age: Int) -> [Recommendation] {
        var recommendations: [Recommendation] = []

        if age >= 25 && age < 35 {
            recommendations.append(Recommendation(
                id: UUID(),
                area: "Prevention (Age 25-35)",
                concern: nil,
                priority: .medium,
                severity: .minor,
                suggestion: "Start preventative anti-aging routine: Daily SPF + retinol 2-3x weekly",
                expectedImpact: "Prevent early signs of aging",
                timeframe: "Ongoing",
                productRecommendations: [],
                lifestyleTips: ["SPF is the #1 anti-aging tool", "Start retinol early for prevention"],
                citationKeys: [.sunDamage, .wrinkles]
            ))
        } else if age >= 35 && age < 50 {
            recommendations.append(Recommendation(
                id: UUID(),
                area: "Active Treatment (Age 35-50)",
                concern: .wrinkles,
                priority: .high,
                severity: .moderate,
                suggestion: "Consider professional skincare products recommended by your dermatologist + peptides + antioxidants",
                expectedImpact: "Combat visible signs of aging",
                timeframe: "8-12 weeks",
                productRecommendations: [],
                lifestyleTips: ["Consider professional in-office treatments recommended by your dermatologist", "Consistent routine is key"],
                citationKeys: [.wrinkles, .sunDamage]
            ))
        } else if age >= 50 {
            recommendations.append(Recommendation(
                id: UUID(),
                area: "Intensive Care (Age 50+)",
                concern: .sagging,
                priority: .high,
                severity: .moderate,
                suggestion: "Comprehensive anti-aging: Professional treatments + growth factors + dermatologist consultation",
                expectedImpact: "Maintain skin quality and firmness",
                timeframe: "Ongoing",
                productRecommendations: [],
                lifestyleTips: ["Consider dermatologist consultation", "Explore professional in-office treatments"],
                citationKeys: [.wrinkles, .sunDamage]
            ))
        }

        return recommendations
    }

    // MARK: - Seasonal Adjustments

    private func getSeasonalAdjustments(season: Season, profile: UserProfile) -> [SeasonalAdjustment] {
        switch season {
        case .winter:
            return [SeasonalAdjustment(
                season: .winter,
                adjustments: [
                    "Switch to heavier moisturizer (dry winter air)",
                    "Use humidifier indoors",
                    "Don't skip SPF (UV reflects off snow!)",
                    "Add facial oil for extra barrier protection"
                ]
            )]

        case .spring:
            return [SeasonalAdjustment(
                season: .spring,
                adjustments: [
                    "Increase SPF to SPF 50 (stronger sun)",
                    "Add vitamin C for brightness",
                    "Spring cleaning: refresh your routine",
                    "Be cautious with new products (pollen allergies)"
                ]
            )]

        case .summer:
            return [SeasonalAdjustment(
                season: .summer,
                adjustments: [
                    "CRITICAL: Reapply SPF every 2 hours outdoors",
                    "Switch to lighter, gel-based moisturizer",
                    "Add antioxidant serum (combat UV damage)",
                    "Hydrate more (sweating = water loss)",
                    "Consider skipping retinol if very sunny (photosensitivity)"
                ]
            )]

        case .fall:
            return [SeasonalAdjustment(
                season: .fall,
                adjustments: [
                    "Great time to start/increase retinol (less sun)",
                    "Add chemical exfoliant (remove summer damage)",
                    "Gradually transition to richer moisturizer",
                    "Focus on repairing summer sun damage"
                ]
            )]
        }
    }

    // MARK: - Lifestyle Impact

    private func analyzeLifestyleImpact(factors: LifestyleFactors) -> LifestyleImpact {
        var positive: [String] = []
        var negative: [String] = []
        var suggestions: [String] = []

        // Water
        if factors.waterIntake == .good || factors.waterIntake == .excellent {
            positive.append("Good hydration")
        } else {
            negative.append("Low water intake")
            suggestions.append("Increase water to 8 glasses/day")
        }

        // Sleep
        if factors.sleepQuality == .good || factors.sleepQuality == .excellent {
            positive.append("Quality sleep")
        } else {
            negative.append("Poor sleep quality")
            suggestions.append("Aim for 7-8 hours of sleep (skin repairs at night)")
        }

        // Stress
        if factors.stressLevel == .high {
            negative.append("High stress levels")
            suggestions.append("Manage stress (cortisol damages collagen)")
        }

        // Sun
        if factors.sunExposure == .high {
            negative.append("High sun exposure")
            suggestions.append("CRITICAL: Daily SPF 50+ and sun protection")
        }

        // Smoking
        if factors.smokingStatus == .regular || factors.smokingStatus == .occasional {
            negative.append("Smoking (accelerates aging)")
            suggestions.append("Consider quitting smoking (dramatically improves skin)")
        }

        // Alcohol
        if factors.alcoholConsumption == .frequent {
            negative.append("Frequent alcohol (dehydrating)")
            suggestions.append("Reduce alcohol consumption")
        }

        // Exercise
        if factors.exerciseFrequency == .active || factors.exerciseFrequency == .moderate {
            positive.append("Regular exercise (improves circulation)")
        }

        return LifestyleImpact(
            positiveFactors: positive,
            negativeFactors: negative,
            suggestions: suggestions
        )
    }
}
