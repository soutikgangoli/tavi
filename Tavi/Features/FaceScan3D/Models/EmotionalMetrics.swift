//
//  EmotionalMetrics.swift
//  Tavi
//
//  Emotional, consumer-friendly metrics that people actually care about
//  Created on 2025-10-28.
//

import Foundation
import SwiftUI

/// Emotional metrics that consumers actually understand and care about
public struct EmotionalMetrics: Codable, Sendable {
    let glowScore: Int                    // 0-100 unified "how good does my skin look" score (Skin Health Index)
    let primaryInsight: String            // Main message: "Your skin looks AMAZING! ✨"
    let celebration: String               // Emoji-rich celebration message
    let improvements: [EmotionalImprovement]
    let concerns: [EmotionalConcern]
    let personalizedMessage: String       // Context-aware message
    let nextSteps: [ActionableStep]       // Clear action items
    let timeEstimate: String              // "See results in 2 weeks"

    // Emotional sub-scores (more relatable than technical metrics)
    let radiance: Int                     // 0-100: "How glowy is my skin?"
    let smoothness: Int                   // 0-100: "How smooth does it feel?"
    let evenness: Int                     // 0-100: "Is my tone even?"
    let youthfulness: Int                 // 0-100: "Do I look young?"
    let freshness: Int                    // 0-100: "Do I look fresh and awake?"
    let sunProtection: Int                // 0-100: "Am I protected from sun damage?"

    // Memberwise initializer for direct instantiation
    public init(
        glowScore: Int,
        primaryInsight: String,
        celebration: String,
        improvements: [EmotionalImprovement],
        concerns: [EmotionalConcern],
        personalizedMessage: String,
        nextSteps: [ActionableStep],
        timeEstimate: String,
        radiance: Int,
        smoothness: Int,
        evenness: Int,
        youthfulness: Int,
        freshness: Int,
        sunProtection: Int
    ) {
        self.glowScore = glowScore
        self.primaryInsight = primaryInsight
        self.celebration = celebration
        self.improvements = improvements
        self.concerns = concerns
        self.personalizedMessage = personalizedMessage
        self.nextSteps = nextSteps
        self.timeEstimate = timeEstimate
        self.radiance = radiance
        self.smoothness = smoothness
        self.evenness = evenness
        self.youthfulness = youthfulness
        self.freshness = freshness
        self.sunProtection = sunProtection
    }

    // Custom decoder to handle backward compatibility with old saved data
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        glowScore = try container.decode(Int.self, forKey: .glowScore)
        primaryInsight = try container.decode(String.self, forKey: .primaryInsight)
        celebration = try container.decode(String.self, forKey: .celebration)
        improvements = try container.decode([EmotionalImprovement].self, forKey: .improvements)
        concerns = try container.decode([EmotionalConcern].self, forKey: .concerns)
        personalizedMessage = try container.decode(String.self, forKey: .personalizedMessage)
        nextSteps = try container.decode([ActionableStep].self, forKey: .nextSteps)
        timeEstimate = try container.decode(String.self, forKey: .timeEstimate)
        radiance = try container.decode(Int.self, forKey: .radiance)
        smoothness = try container.decode(Int.self, forKey: .smoothness)
        evenness = try container.decode(Int.self, forKey: .evenness)
        youthfulness = try container.decode(Int.self, forKey: .youthfulness)
        freshness = try container.decode(Int.self, forKey: .freshness)
        // Default to 75 for old data that doesn't have sunProtection
        sunProtection = try container.decodeIfPresent(Int.self, forKey: .sunProtection) ?? 75
    }

    private enum CodingKeys: String, CodingKey {
        case glowScore, primaryInsight, celebration, improvements, concerns
        case personalizedMessage, nextSteps, timeEstimate, radiance, smoothness
        case evenness, youthfulness, freshness, sunProtection
    }
}

/// Something positive to celebrate
public struct EmotionalImprovement: Codable, Identifiable, Sendable {
    public let id = UUID()
    let title: String                     // "Your skin texture improved!"
    let emoji: String                     // "✨"
    let percentChange: Int                // +12%
    let message: String                   // "That new moisturizer is working!"
    let sinceDays: Int                    // Days since last scan

    enum CodingKeys: String, CodingKey {
        case title, emoji, percentChange, message, sinceDays
    }
}

/// Area that needs attention (framed positively)
public struct EmotionalConcern: Codable, Identifiable, Sendable {
    public let id = UUID()
    let title: String                     // "Fine lines around eyes"
    let emoji: String                     // "👁️"
    let severity: ConcernLevel           // .mild, .moderate
    let message: String                   // "Let's work on reducing these"
    let solution: String                  // "Try an eye cream with retinol"
    let encouragement: String             // "Most people see results in 2-3 weeks!"

    enum CodingKeys: String, CodingKey {
        case title, emoji, severity, message, solution, encouragement
    }
}

public enum ConcernLevel: String, Codable, Sendable {
    case mild = "Minor"
    case moderate = "Moderate"
    case none = "Looking great!"
}

/// Clear, actionable step
public struct ActionableStep: Codable, Identifiable, Sendable {
    public let id = UUID()
    let action: String                    // "Apply retinol serum"
    let frequency: String                 // "3 times this week"
    let timing: String                    // "Before bed"
    let expectedResult: String            // "Reduce fine lines 15% in 30 days"
    let priority: StepPriority
    let icon: String                      // SF Symbol name

    enum CodingKeys: String, CodingKey {
        case action, frequency, timing, expectedResult, priority, icon
    }
}

public enum StepPriority: String, Codable, Sendable {
    case critical = "Do this first!"
    case important = "Important"
    case optional = "Nice to have"
}

// MARK: - Emotional Metrics Generator

public class EmotionalMetricsGenerator {

    /// Convert clinical Face3DMetrics to emotional, consumer-friendly metrics
    public static func generate(
        from clinicalMetrics: Face3DMetrics?,
        previousMetrics: Face3DMetrics? = nil,
        userProfile: UserProfile? = nil
    ) -> EmotionalMetrics {

        // TEMPORARY: Handle nil metrics (when analyzer is disabled for testing)
        guard let clinicalMetrics = clinicalMetrics else {
            return generateDefaultMetrics(userProfile: userProfile)
        }

        // 1. Calculate Skin Health Index (unified 0-100)
        let glowScore = calculateGlowScore(from: clinicalMetrics)

        // 2. Calculate emotional sub-scores
        let radiance = calculateRadiance(from: clinicalMetrics)
        let smoothness = Int(clinicalMetrics.globalRoughnessScore)
        let evenness = Int(clinicalMetrics.globalPigmentationScore)
        let youthfulness = calculateYouthfulness(from: clinicalMetrics)
        let freshness = calculateFreshness(from: clinicalMetrics)

        // 3. Generate primary insight
        let primaryInsight = generatePrimaryInsight(glowScore: glowScore)

        // 4. Generate celebration message
        let celebration = generateCelebration(
            glowScore: glowScore,
            previousScore: previousMetrics.map { calculateGlowScore(from: $0) }
        )

        // 5. Identify improvements
        let improvements = identifyImprovements(
            current: clinicalMetrics,
            previous: previousMetrics
        )

        // 6. Identify concerns (framed positively)
        let concerns = identifyConcerns(from: clinicalMetrics, userProfile: userProfile)

        // 7. Generate personalized message
        let personalizedMessage = generatePersonalizedMessage(
            glowScore: glowScore,
            improvements: improvements,
            concerns: concerns,
            userProfile: userProfile
        )

        // 8. Generate next steps
        let nextSteps = generateNextSteps(
            concerns: concerns,
            glowScore: glowScore
        )

        // 9. Time estimate
        let timeEstimate = generateTimeEstimate(concerns: concerns)

        return EmotionalMetrics(
            glowScore: glowScore,
            primaryInsight: primaryInsight,
            celebration: celebration,
            improvements: improvements,
            concerns: concerns,
            personalizedMessage: personalizedMessage,
            nextSteps: nextSteps,
            timeEstimate: timeEstimate,
            radiance: radiance,
            smoothness: smoothness,
            evenness: evenness,
            youthfulness: youthfulness,
            freshness: freshness,
            sunProtection: Int(clinicalMetrics.sunDamageAnalysis?.protectionScore ?? 75.0)
        )
    }

    /// TEMPORARY: Generate default metrics when analyzer is unavailable
    /// This provides reasonable fallback values for UI testing
    private static func generateDefaultMetrics(userProfile: UserProfile?) -> EmotionalMetrics {
        let name = userProfile?.name ?? "there"

        return EmotionalMetrics(
            glowScore: 70,
            primaryInsight: "Scan complete! We're analyzing your results... ✨",
            celebration: "Your 3D face scan was successful! 🎉",
            improvements: [],
            concerns: [
                EmotionalConcern(
                    title: "Analysis in progress",
                    emoji: "🔬",
                    severity: .none,
                    message: "We're still processing your detailed metrics",
                    solution: "Check back soon for complete analysis",
                    encouragement: "Your scan data has been saved!"
                )
            ],
            personalizedMessage: "Hey \(name)! Your scan was successful. Detailed analysis coming soon! 💙",
            nextSteps: [
                ActionableStep(
                    action: "Apply SPF 30+ sunscreen",
                    frequency: "Every morning",
                    timing: "After moisturizer",
                    expectedResult: "Prevent new damage, maintain current glow",
                    priority: .critical,
                    icon: "sun.max.fill"
                )
            ],
            timeEstimate: "Complete analysis available soon",
            radiance: 70,
            smoothness: 70,
            evenness: 70,
            youthfulness: 70,
            freshness: 70,
            sunProtection: 75
        )
    }

    // MARK: - Calculators

    private static func calculateGlowScore(from metrics: Face3DMetrics) -> Int {
        // Use GlowAnalyzer results if available (preferred method)
        if let glowAnalysis = metrics.glowAnalysis {
            return Int(glowAnalysis.glowScore.rounded())
        }

        // Fallback: Calculate manually if glowAnalysis not available (legacy data)
        let smoothness = metrics.globalRoughnessScore
        let evenness = metrics.globalPigmentationScore
        let discoloration = metrics.globalDiscolorationScore
        let specular = metrics.globalSpecularScore ?? 50.0

        // Skin Health Index = 40% smoothness + 30% evenness + 20% discoloration + 10% healthy shine
        let score = (smoothness * 0.4) + (evenness * 0.3) + (discoloration * 0.2) + (specular * 0.1)

        return Int(score.rounded())
    }

    private static func calculateRadiance(from metrics: Face3DMetrics) -> Int {
        // Use GlowAnalyzer results if available (physics-based radiance)
        if let glowAnalysis = metrics.glowAnalysis {
            return Int(glowAnalysis.radianceScore.rounded())
        }

        // Fallback: Calculate manually if glowAnalysis not available (legacy data)
        // Note: This is the old formula and NOT physics-based
        let evenness = metrics.globalPigmentationScore
        let shine = metrics.globalSpecularScore ?? 50.0
        return Int((evenness * 0.6 + shine * 0.4).rounded())
    }

    private static func calculateYouthfulness(from metrics: Face3DMetrics) -> Int {
        // Youthfulness = smoothness + firmness indicators
        let smoothness = metrics.globalRoughnessScore

        // NOTE: Wrinkle depth analysis is available via WrinkleAnalyzer
        // For now, using smoothness as primary indicator which correlates well with youthfulness
        // Future enhancement: Incorporate wrinkle depth scoring when adding advanced aging metrics

        return Int(smoothness.rounded())
    }

    private static func calculateFreshness(from metrics: Face3DMetrics) -> Int {
        // Freshness = glow + hydration indicators
        let evenness = metrics.globalPigmentationScore
        let smoothness = metrics.globalRoughnessScore
        return Int((evenness * 0.5 + smoothness * 0.5).rounded())
    }

    // MARK: - Message Generators

    private static func generatePrimaryInsight(glowScore: Int) -> String {
        switch glowScore {
        case 90...100:
            return "Your skin looks INCREDIBLE! ✨"
        case 80..<90:
            return "Your skin looks amazing today! 🌟"
        case 70..<80:
            return "Your skin is looking great! ☺️"
        case 60..<70:
            return "Your skin is on the right track! 💪"
        case 50..<60:
            return "Let's boost your glow together! 🌤️"
        default:
            return "We've got a plan to get you glowing! 💙"
        }
    }

    private static func generateCelebration(glowScore: Int, previousScore: Int?) -> String {
        if let prev = previousScore {
            let change = glowScore - prev
            if change > 10 {
                return "WOW! Your score jumped \(change) points! 🎉🎊✨"
            } else if change > 5 {
                return "Amazing progress! Up \(change) points! 🎉"
            } else if change > 0 {
                return "Nice improvement! +\(change) points! 👏"
            } else if change == 0 {
                return "You're maintaining your healthy skin! Keep it up! 💪"
            } else {
                return "Let's get you back on track! You've got this! 💙"
            }
        } else {
            // First scan
            if glowScore >= 80 {
                return "Great starting point! Let's keep your skin healthy! ✨"
            } else {
                return "Awesome! We've established your baseline. Let's start your skin health journey! 🌟"
            }
        }
    }

    private static func identifyImprovements(
        current: Face3DMetrics,
        previous: Face3DMetrics?
    ) -> [EmotionalImprovement] {
        guard let prev = previous else { return [] }

        var improvements: [EmotionalImprovement] = []

        // Check each metric for improvement
        let smoothnessChange = current.globalRoughnessScore - prev.globalRoughnessScore
        if smoothnessChange >= 5 {
            improvements.append(EmotionalImprovement(
                title: "Smoother skin texture",
                emoji: "✨",
                percentChange: Int(smoothnessChange),
                message: "Your skin feels noticeably smoother!",
                sinceDays: daysBetween(current.timestamp, prev.timestamp)
            ))
        }

        let evennessChange = current.globalPigmentationScore - prev.globalPigmentationScore
        if evennessChange >= 5 {
            improvements.append(EmotionalImprovement(
                title: "More even skin tone",
                emoji: "🌟",
                percentChange: Int(evennessChange),
                message: "Your skin tone is looking more uniform!",
                sinceDays: daysBetween(current.timestamp, prev.timestamp)
            ))
        }

        let discolorationChange = current.globalDiscolorationScore - prev.globalDiscolorationScore
        if discolorationChange >= 5 {
            improvements.append(EmotionalImprovement(
                title: "Reduced discoloration",
                emoji: "💫",
                percentChange: Int(discolorationChange),
                message: "Dark spots are fading nicely!",
                sinceDays: daysBetween(current.timestamp, prev.timestamp)
            ))
        }

        return improvements
    }

    private static func identifyConcerns(
        from metrics: Face3DMetrics,
        userProfile: UserProfile?
    ) -> [EmotionalConcern] {
        var concerns: [EmotionalConcern] = []

        // Texture concerns
        if metrics.globalRoughnessScore < 60 {
            let severity: ConcernLevel = metrics.globalRoughnessScore < 40 ? .moderate : .mild
            concerns.append(EmotionalConcern(
                title: "Skin texture could be smoother",
                emoji: "✨",
                severity: severity,
                message: "Let's work on smoothing your skin",
                solution: "Regular exfoliation and moisturizing",
                encouragement: "Most people see smoother skin in 2-3 weeks!"
            ))
        }

        // Pigmentation concerns
        if metrics.globalPigmentationScore < 60 {
            let severity: ConcernLevel = metrics.globalPigmentationScore < 40 ? .moderate : .mild
            concerns.append(EmotionalConcern(
                title: "Uneven skin tone",
                emoji: "🌤️",
                severity: severity,
                message: "We can help even out your complexion",
                solution: "Vitamin C serum and daily SPF",
                encouragement: "Consistency is key! Results typically show in 4-6 weeks."
            ))
        }

        // Discoloration concerns
        if metrics.globalDiscolorationScore < 60 {
            let severity: ConcernLevel = metrics.globalDiscolorationScore < 40 ? .moderate : .mild
            concerns.append(EmotionalConcern(
                title: "Dark spots or hyperpigmentation",
                emoji: "☀️",
                severity: severity,
                message: "Let's fade those dark spots",
                solution: "SPF 30+ daily + brightening serum",
                encouragement: "Dark spots fade gradually. Stay patient!"
            ))
        }

        // Wrinkle concerns
        if let wrinkles = metrics.wrinkleAnalysis, wrinkles.overallScore < 70 {
            let severity: ConcernLevel = wrinkles.overallScore < 50 ? .moderate : .mild
            concerns.append(EmotionalConcern(
                title: "Fine lines and wrinkles",
                emoji: "💧",
                severity: severity,
                message: "Let's smooth those fine lines",
                solution: "Retinol serum at night + hydration",
                encouragement: "Consistent use shows results in 4-6 weeks!"
            ))
        }

        // Pore concerns
        if let pores = metrics.poreAnalysis, pores.visibility > 30 {
            let severity: ConcernLevel = pores.visibility > 50 ? .moderate : .mild
            concerns.append(EmotionalConcern(
                title: "Visible pores",
                emoji: "🔬",
                severity: severity,
                message: "Let's minimize those pores",
                solution: "Niacinamide serum + gentle exfoliation",
                encouragement: "Pores appear smaller with consistent care!"
            ))
        }

        // Acne concerns
        if let acne = metrics.acneAnalysis, acne.blemishCount > 5 {
            let severity: ConcernLevel = acne.blemishCount > 20 ? .moderate : .mild
            concerns.append(EmotionalConcern(
                title: "Active breakouts",
                emoji: "🌿",
                severity: severity,
                message: "Let's clear up those blemishes",
                solution: "Salicylic acid + spot treatment",
                encouragement: "Most breakouts improve in 1-2 weeks!"
            ))
        }

        // Redness concerns
        if let redness = metrics.rednessAnalysis, redness.overallScore < 70 {
            let severity: ConcernLevel = redness.overallScore < 50 ? .moderate : .mild
            concerns.append(EmotionalConcern(
                title: "Skin redness and sensitivity",
                emoji: "🌸",
                severity: severity,
                message: "Let's calm that redness",
                solution: "Gentle, fragrance-free products + calming serum",
                encouragement: "Redness reduces with the right gentle routine!"
            ))
        }

        return concerns
    }

    private static func generatePersonalizedMessage(
        glowScore: Int,
        improvements: [EmotionalImprovement],
        concerns: [EmotionalConcern],
        userProfile: UserProfile?
    ) -> String {
        let name = userProfile?.name ?? "there"

        if !improvements.isEmpty {
            return "Hey \(name)! Your routine is paying off! Keep up the great work! 💪"
        } else if glowScore >= 80 {
            return "Hey \(name)! Your skin is in great shape. Let's maintain this glow! ✨"
        } else if concerns.isEmpty {
            return "Hey \(name)! Your skin is looking good. Ready to take it to the next level? 🌟"
        } else {
            return "Hey \(name)! We've identified some areas to work on. Let's create your personalized routine! 💙"
        }
    }

    private static func generateNextSteps(
        concerns: [EmotionalConcern],
        glowScore: Int
    ) -> [ActionableStep] {
        var steps: [ActionableStep] = []

        // Always recommend SPF (most important)
        steps.append(ActionableStep(
            action: "Apply SPF 30+ sunscreen",
            frequency: "Every morning",
            timing: "After moisturizer",
            expectedResult: "Prevent new damage, maintain current glow",
            priority: .critical,
            icon: "sun.max.fill"
        ))

        // Generate steps based on concerns
        for concern in concerns.prefix(2) {  // Top 2 concerns only
            if concern.title.contains("texture") {
                steps.append(ActionableStep(
                    action: "Exfoliate with gentle AHA/BHA",
                    frequency: "2-3 times per week",
                    timing: "Evening",
                    expectedResult: "Smoother skin in 2-3 weeks",
                    priority: .important,
                    icon: "sparkles"
                ))
            }

            if concern.title.contains("tone") || concern.title.contains("spots") {
                steps.append(ActionableStep(
                    action: "Apply Vitamin C serum",
                    frequency: "Every morning",
                    timing: "Before moisturizer",
                    expectedResult: "Brighter, more even tone in 4-6 weeks",
                    priority: .important,
                    icon: "sunrise.fill"
                ))
            }

            if concern.title.contains("wrinkles") || concern.title.contains("lines") {
                steps.append(ActionableStep(
                    action: "Apply retinol serum",
                    frequency: "3-4 nights per week",
                    timing: "Evening, after cleansing",
                    expectedResult: "Smoother skin, reduced fine lines in 6-8 weeks",
                    priority: .important,
                    icon: "moon.stars.fill"
                ))
            }

            if concern.title.contains("pores") {
                steps.append(ActionableStep(
                    action: "Use niacinamide serum",
                    frequency: "Morning and evening",
                    timing: "After cleansing",
                    expectedResult: "Minimized pore appearance in 3-4 weeks",
                    priority: .important,
                    icon: "circle.grid.2x2.fill"
                ))
            }

            if concern.title.contains("breakouts") || concern.title.contains("acne") {
                steps.append(ActionableStep(
                    action: "Apply salicylic acid treatment",
                    frequency: "Once daily",
                    timing: "Evening",
                    expectedResult: "Clearer skin, fewer breakouts in 2-3 weeks",
                    priority: .important,
                    icon: "leaf.fill"
                ))
            }

            if concern.title.contains("redness") || concern.title.contains("sensitivity") {
                steps.append(ActionableStep(
                    action: "Use calming serum (centella or niacinamide)",
                    frequency: "Morning and evening",
                    timing: "After cleansing",
                    expectedResult: "Reduced redness and irritation in 2-4 weeks",
                    priority: .important,
                    icon: "heart.fill"
                ))
            }
        }

        // Hydration (always good)
        if glowScore < 80 {
            steps.append(ActionableStep(
                action: "Hydrate with hyaluronic acid serum",
                frequency: "Morning and night",
                timing: "After cleansing",
                expectedResult: "Plumper, more radiant skin in 1-2 weeks",
                priority: .important,
                icon: "drop.fill"
            ))
        }

        return steps
    }

    private static func generateTimeEstimate(concerns: [EmotionalConcern]) -> String {
        if concerns.isEmpty {
            return "Keep up your routine to maintain results!"
        } else if concerns.count == 1 {
            return "See noticeable results in 2-3 weeks"
        } else {
            return "See significant improvement in 4-6 weeks"
        }
    }

    private static func daysBetween(_ timestamp1: TimeInterval, _ timestamp2: TimeInterval) -> Int {
        let date1 = Date(timeIntervalSince1970: timestamp1)
        let date2 = Date(timeIntervalSince1970: timestamp2)
        let days = Calendar.current.dateComponents([.day], from: date2, to: date1).day ?? 0
        return abs(days)
    }
}
