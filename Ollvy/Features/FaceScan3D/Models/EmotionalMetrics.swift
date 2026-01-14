//
//  EmotionalMetrics.swift
//  Ollvy
//
//  Emotional, consumer-friendly metrics that people actually care about
//  Created on 2025-10-28.
//

import Foundation
import SwiftUI

/// Trend data for a single metric over time
public struct MetricTrend: Codable, Sendable {
    let change: Float              // % change from last scan (positive = improvement)
    let direction: TrendDirection  // .improving, .stable, .declining
    let daysSinceLast: Int         // Days since last scan

    public enum TrendDirection: String, Codable, Sendable {
        case improving = "improving"
        case stable = "stable"
        case declining = "declining"
    }
}

/// Emotional metrics that consumers actually understand and care about
public struct EmotionalMetrics: Codable, Sendable {
    let skinHealthScore: Int              // 0-100 unified "how good does my skin look" score (Skin Analysis Index)
    let primaryInsight: String            // Main message: "Your skin looks AMAZING! ✨"
    let celebration: String               // Emoji-rich celebration message
    let improvements: [EmotionalImprovement]
    let concerns: [EmotionalConcern]
    let personalizedMessage: String       // Context-aware message
    let nextSteps: [ActionableStep]       // Clear action items
    let timeEstimate: String              // "See results in 2 weeks"

    // Emotional sub-scores (more relatable than technical metrics)
    let radiance: Int                     // 0-100: "How glowy is my skin?"
    let smoothness: Int                   // 0-100: "How smooth does it feel?" (Texture)
    let evenness: Int                     // 0-100: "Is my tone even?"
    let youthfulness: Int                 // 0-100: "Do I look young?" (Lines & Wrinkles)
    let freshness: Int                    // 0-100: "Do I look fresh and awake?" (Hydration proxy)

    // New: Real analyzer scores (nil if analyzer didn't run - no fake 75 fallbacks)
    let acneScore: Int?                   // 0-100: Acne/blemish clarity (from acneAnalysis)
    let blemishCount: Int?                // Exact number of detected blemishes (from acneAnalysis)
    let rednessScore: Int?                // 0-100: Redness control (from rednessAnalysis)
    let oilControlScore: Int?             // 0-100: Oil/shine control (from globalSpecularScore)
    let poreScore: Int?                   // 0-100: Pore visibility (from poreAnalysis)

    // Skin type classification
    let skinType: String?                 // "Oily", "Dry", "Combination", "Normal"
    let skinTypeConfidence: Int?          // 0-100: Classification confidence

    // Under-eye darkness (dark circles)
    let underEyeScore: Int?               // 0-100: Higher = less darkness
    let underEyeSeverity: String?         // "None", "Mild", "Moderate", "Severe"

    // Lip health
    let lipHealthScore: Int?              // 0-100: Lip texture/hydration
    let lipHydrationLevel: String?        // "Well Hydrated", "Normal", "Dry", "Very Dry"

    // Elasticity (requires 2+ scans for accurate temporal analysis)
    let elasticityScore: Int?             // 0-100: Skin firmness
    let elasticityLevel: String?          // "Excellent", "Good", "Moderate", "Poor"
    let elasticityConfidence: Int?        // 0-100: Measurement confidence
    let elasticityIsTemporal: Bool        // true = real data (2+ scans), false = proxy estimate

    // Multi-scan tracking
    let scanNumber: Int                   // Which scan this is (1, 2, 3...)
    let trends: [String: MetricTrend]?    // Per-metric trends from previous scan

    // Memberwise initializer for direct instantiation
    public init(
        skinHealthScore: Int,
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
        acneScore: Int?,
        blemishCount: Int? = nil,
        rednessScore: Int?,
        oilControlScore: Int?,
        poreScore: Int?,
        skinType: String? = nil,
        skinTypeConfidence: Int? = nil,
        underEyeScore: Int? = nil,
        underEyeSeverity: String? = nil,
        lipHealthScore: Int? = nil,
        lipHydrationLevel: String? = nil,
        elasticityScore: Int? = nil,
        elasticityLevel: String? = nil,
        elasticityConfidence: Int? = nil,
        elasticityIsTemporal: Bool = false,
        scanNumber: Int = 1,
        trends: [String: MetricTrend]? = nil
    ) {
        self.skinHealthScore = skinHealthScore
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
        self.acneScore = acneScore
        self.blemishCount = blemishCount
        self.rednessScore = rednessScore
        self.oilControlScore = oilControlScore
        self.poreScore = poreScore
        self.skinType = skinType
        self.skinTypeConfidence = skinTypeConfidence
        self.underEyeScore = underEyeScore
        self.underEyeSeverity = underEyeSeverity
        self.lipHealthScore = lipHealthScore
        self.lipHydrationLevel = lipHydrationLevel
        self.elasticityScore = elasticityScore
        self.elasticityLevel = elasticityLevel
        self.elasticityConfidence = elasticityConfidence
        self.elasticityIsTemporal = elasticityIsTemporal
        self.scanNumber = scanNumber
        self.trends = trends
    }

    // Custom decoder to handle backward compatibility with old saved data
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Support both old "glowScore" and new "skinHealthScore" for backward compatibility
        skinHealthScore = try container.decodeIfPresent(Int.self, forKey: .skinHealthScore) ?? 
                         (try? container.decode(Int.self, forKey: .glowScore)) ?? 75
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
        // nil if old data doesn't have these fields (no fake 75 fallbacks)
        acneScore = try container.decodeIfPresent(Int.self, forKey: .acneScore)
        blemishCount = try container.decodeIfPresent(Int.self, forKey: .blemishCount)
        rednessScore = try container.decodeIfPresent(Int.self, forKey: .rednessScore)
        oilControlScore = try container.decodeIfPresent(Int.self, forKey: .oilControlScore)
        poreScore = try container.decodeIfPresent(Int.self, forKey: .poreScore)
        // New properties (optional for backward compatibility)
        skinType = try container.decodeIfPresent(String.self, forKey: .skinType)
        skinTypeConfidence = try container.decodeIfPresent(Int.self, forKey: .skinTypeConfidence)
        underEyeScore = try container.decodeIfPresent(Int.self, forKey: .underEyeScore)
        underEyeSeverity = try container.decodeIfPresent(String.self, forKey: .underEyeSeverity)
        lipHealthScore = try container.decodeIfPresent(Int.self, forKey: .lipHealthScore)
        lipHydrationLevel = try container.decodeIfPresent(String.self, forKey: .lipHydrationLevel)
        elasticityScore = try container.decodeIfPresent(Int.self, forKey: .elasticityScore)
        elasticityLevel = try container.decodeIfPresent(String.self, forKey: .elasticityLevel)
        elasticityConfidence = try container.decodeIfPresent(Int.self, forKey: .elasticityConfidence)
        elasticityIsTemporal = try container.decodeIfPresent(Bool.self, forKey: .elasticityIsTemporal) ?? false
        scanNumber = try container.decodeIfPresent(Int.self, forKey: .scanNumber) ?? 1
        trends = try container.decodeIfPresent([String: MetricTrend].self, forKey: .trends)
    }
    
    // Custom encoder to always save with new "skinHealthScore" key
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(skinHealthScore, forKey: .skinHealthScore)
        try container.encode(primaryInsight, forKey: .primaryInsight)
        try container.encode(celebration, forKey: .celebration)
        try container.encode(improvements, forKey: .improvements)
        try container.encode(concerns, forKey: .concerns)
        try container.encode(personalizedMessage, forKey: .personalizedMessage)
        try container.encode(nextSteps, forKey: .nextSteps)
        try container.encode(timeEstimate, forKey: .timeEstimate)
        try container.encode(radiance, forKey: .radiance)
        try container.encode(smoothness, forKey: .smoothness)
        try container.encode(evenness, forKey: .evenness)
        try container.encode(youthfulness, forKey: .youthfulness)
        try container.encode(freshness, forKey: .freshness)
        try container.encodeIfPresent(acneScore, forKey: .acneScore)
        try container.encodeIfPresent(blemishCount, forKey: .blemishCount)
        try container.encodeIfPresent(rednessScore, forKey: .rednessScore)
        try container.encodeIfPresent(oilControlScore, forKey: .oilControlScore)
        try container.encodeIfPresent(poreScore, forKey: .poreScore)
        // New properties
        try container.encodeIfPresent(skinType, forKey: .skinType)
        try container.encodeIfPresent(skinTypeConfidence, forKey: .skinTypeConfidence)
        try container.encodeIfPresent(underEyeScore, forKey: .underEyeScore)
        try container.encodeIfPresent(underEyeSeverity, forKey: .underEyeSeverity)
        try container.encodeIfPresent(lipHealthScore, forKey: .lipHealthScore)
        try container.encodeIfPresent(lipHydrationLevel, forKey: .lipHydrationLevel)
        try container.encodeIfPresent(elasticityScore, forKey: .elasticityScore)
        try container.encodeIfPresent(elasticityLevel, forKey: .elasticityLevel)
        try container.encodeIfPresent(elasticityConfidence, forKey: .elasticityConfidence)
        try container.encode(elasticityIsTemporal, forKey: .elasticityIsTemporal)
        try container.encode(scanNumber, forKey: .scanNumber)
        try container.encodeIfPresent(trends, forKey: .trends)
    }

    private enum CodingKeys: String, CodingKey {
        case glowScore, skinHealthScore  // Support both for backward compatibility
        case primaryInsight, celebration, improvements, concerns
        case personalizedMessage, nextSteps, timeEstimate, radiance, smoothness
        case evenness, youthfulness, freshness
        case acneScore, blemishCount, rednessScore, oilControlScore, poreScore
        case skinType, skinTypeConfidence
        case underEyeScore, underEyeSeverity
        case lipHealthScore, lipHydrationLevel
        case elasticityScore, elasticityLevel, elasticityConfidence, elasticityIsTemporal
        case scanNumber, trends
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
    /// - Parameters:
    ///   - clinicalMetrics: The clinical Face3DMetrics from the analyzer
    ///   - previousMetrics: Optional previous scan metrics for comparison
    ///   - userProfile: Optional user profile for personalization
    ///   - scanNumber: The scan number (1 for first scan, 2 for second, etc.) from TemporalTracker
    ///   - trends: Per-metric trends from TemporalTracker (nil if first scan or insufficient data)
    public static func generate(
        from clinicalMetrics: Face3DMetrics?,
        previousMetrics: Face3DMetrics? = nil,
        userProfile: UserProfile? = nil,
        scanNumber: Int = 1,
        trends: [String: MetricTrend]? = nil
    ) -> EmotionalMetrics? {

        // Return nil if metrics are unavailable - UI will handle error state
        guard let clinicalMetrics = clinicalMetrics else {
            return nil
        }

        // 1. Calculate Skin Analysis Index (unified 0-100)
        let skinHealthScore = calculateSkinHealthScore(from: clinicalMetrics)

        // 2. Calculate emotional sub-scores
        let radiance = calculateRadiance(from: clinicalMetrics)
        var smoothness = Int(clinicalMetrics.globalRoughnessScore)
        let evenness = Int(clinicalMetrics.globalPigmentationScore)
        var youthfulness = calculateYouthfulness(from: clinicalMetrics)
        let freshness = calculateFreshness(from: clinicalMetrics)

        // SAFETY CHECK: Detect suspicious zero values for young skin
        // Zero smoothness doesn't make sense unless the scan genuinely failed
        if smoothness == 0 {
            AppLogger.metrics.warning("⚠️ ZERO SMOOTHNESS DETECTED! This indicates a processing failure.")

            // Check if we have valid wrinkle data to infer smoothness
            if let wrinkles = clinicalMetrics.wrinkleAnalysis, wrinkles.overallScore > 0 {
                // If wrinkle analysis shows good results (few wrinkles), use that as proxy for smoothness
                smoothness = Int(wrinkles.overallScore.rounded())
                AppLogger.metrics.info("✅ Recovered smoothness from wrinkle analysis: \(smoothness)")
            } else if evenness > 50 {
                // If pigmentation analysis succeeded, infer that roughness analysis should have worked
                // Use evenness as proxy (if pigmentation is good, smoothness is likely similar)
                smoothness = Int((Double(evenness) * 0.8).rounded())  // Slightly lower as conservative estimate
                AppLogger.metrics.info("✅ Inferred smoothness from evenness: \(smoothness)")
            } else {
                // Last resort: Use reasonable default for general population
                smoothness = 60
                AppLogger.metrics.info("ℹ️ Using default smoothness value: \(smoothness)")
            }
        }

        // Fix youthfulness if it inherited zero from smoothness
        if youthfulness == 0 && smoothness > 0 {
            youthfulness = smoothness
            AppLogger.metrics.info("✅ Recalculated youthfulness after smoothness recovery: \(youthfulness)")
        }

        // 3. Generate primary insight (now metric-specific)
        let primaryInsight = generatePrimaryInsight(skinHealthScore: skinHealthScore, metrics: clinicalMetrics)

        // 4. Generate celebration message
        let celebration = generateCelebration(
            skinHealthScore: skinHealthScore,
            previousScore: previousMetrics.map { calculateSkinHealthScore(from: $0) }
        )

        // 5. Identify improvements
        let improvements = identifyImprovements(
            current: clinicalMetrics,
            previous: previousMetrics
        )

        // 6. Identify concerns (framed positively, now with specific solutions)
        let concerns = identifyConcerns(from: clinicalMetrics, userProfile: userProfile)

        // 7. Generate personalized message (now metric-specific)
        let personalizedMessage = generatePersonalizedMessage(
            skinHealthScore: skinHealthScore,
            metrics: clinicalMetrics,
            improvements: improvements,
            concerns: concerns,
            userProfile: userProfile
        )

        // 8. Generate next steps (now score-specific)
        let nextSteps = generateNextSteps(
            concerns: concerns,
            metrics: clinicalMetrics,
            skinHealthScore: skinHealthScore,
            userProfile: userProfile
        )

        // 9. Time estimate
        let timeEstimate = generateTimeEstimate(concerns: concerns)

        // 10. Extract real analyzer scores (nil if analyzer didn't run - no fake 75 fallbacks)
        let acneScore: Int? = clinicalMetrics.acneAnalysis.map { Int($0.overallScore) }
        let blemishCount: Int? = clinicalMetrics.acneAnalysis?.blemishCount
        let rednessScore: Int? = clinicalMetrics.rednessAnalysis.map { Int($0.overallScore) }
        let oilControlScore: Int? = clinicalMetrics.globalSpecularScore.map { Int($0) }
        let poreScore: Int? = clinicalMetrics.poreAnalysis.map { Int($0.visibilityScore) }

        // 11. Extract skin type classification
        let skinType: String? = clinicalMetrics.skinTypeAnalysis?.skinType.rawValue
        let skinTypeConfidence: Int? = clinicalMetrics.skinTypeAnalysis.map { Int($0.confidence * 100) }

        // 12. Extract under-eye darkness (dark circles)
        let underEyeScore: Int? = clinicalMetrics.regionalAnalysis?.underEyeDarkness.map { Int($0.score) }
        let underEyeSeverity: String? = clinicalMetrics.regionalAnalysis?.underEyeDarkness?.severity.rawValue

        // 13. Extract lip health
        let lipHealthScore: Int? = clinicalMetrics.regionalAnalysis?.lipAnalysis.map { Int($0.textureScore) }
        let lipHydrationLevel: String? = clinicalMetrics.regionalAnalysis?.lipAnalysis?.hydrationLevel.rawValue

        // 14. Extract elasticity (requires 2+ scans for accurate temporal analysis)
        let elasticityScore: Int? = clinicalMetrics.elasticityAnalysis.map { Int($0.overallScore) }
        let elasticityLevel: String? = clinicalMetrics.elasticityAnalysis?.elasticityLevel.rawValue
        let elasticityConfidence: Int? = clinicalMetrics.elasticityAnalysis.map { Int($0.confidence) }
        let elasticityIsTemporal: Bool = clinicalMetrics.elasticityAnalysis?.isTemporal ?? false

        // 15. Multi-scan tracking (scan number and trends from TemporalTracker)
        // These are now passed in as parameters from MetricsOrchestrator

        return EmotionalMetrics(
            skinHealthScore: skinHealthScore,
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
            acneScore: acneScore,
            blemishCount: blemishCount,
            rednessScore: rednessScore,
            oilControlScore: oilControlScore,
            poreScore: poreScore,
            skinType: skinType,
            skinTypeConfidence: skinTypeConfidence,
            underEyeScore: underEyeScore,
            underEyeSeverity: underEyeSeverity,
            lipHealthScore: lipHealthScore,
            lipHydrationLevel: lipHydrationLevel,
            elasticityScore: elasticityScore,
            elasticityLevel: elasticityLevel,
            elasticityConfidence: elasticityConfidence,
            elasticityIsTemporal: elasticityIsTemporal,
            scanNumber: scanNumber,
            trends: trends
        )
    }


    // MARK: - Calculators

    private static func calculateSkinHealthScore(from metrics: Face3DMetrics) -> Int {
        // Use GlowAnalyzer results if available (preferred method)
        if let glowAnalysis = metrics.glowAnalysis {
            return Int(glowAnalysis.skinHealthScore.rounded())
        }

        // Fallback: Calculate manually if glowAnalysis not available (legacy data)
        let smoothness = metrics.globalRoughnessScore
        let evenness = metrics.globalPigmentationScore
        let discoloration = metrics.globalDiscolorationScore
        let specular = metrics.globalSpecularScore ?? 50.0

        // Skin Analysis Index = 40% smoothness + 30% evenness + 20% discoloration + 10% healthy shine
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

        // ENHANCED: Use wrinkle analysis if available for more accurate firmness/aging assessment
        if let wrinkles = metrics.wrinkleAnalysis {
            // DETAILED WRINKLE LOGGING
            AppLogger.metrics.info("🔍 Wrinkle Analysis Details:")
            AppLogger.metrics.info("   Overall Score: \(String(format: "%.1f", Double(wrinkles.overallScore)))/100")
            AppLogger.metrics.info("   Wrinkle Count: \(wrinkles.wrinkleCount)")
            AppLogger.metrics.info("   Depth Category: \(wrinkles.wrinkleDepth.rawValue)")
            AppLogger.metrics.info("   Confidence: \(String(format: "%.1f", Double(wrinkles.confidence)))%")

            // Log individual wrinkle regions
            if !wrinkles.wrinkleRegions.isEmpty {
                AppLogger.metrics.info("   Detected Wrinkle Regions:")
                for region in wrinkles.wrinkleRegions {
                    let depthMM = region.depth * 1000  // Convert meters to mm
                    let lengthMM = region.length * 1000
                    AppLogger.metrics.info("      • \(region.location): depth=\(String(format: "%.2f", Double(depthMM)))mm, length=\(String(format: "%.1f", Double(lengthMM)))mm, severity=\(region.severity.rawValue)")
                }

                // Calculate average depth
                let avgDepth = wrinkles.wrinkleRegions.map { $0.depth }.reduce(0, +) / Float(wrinkles.wrinkleRegions.count)
                let avgDepthMM = avgDepth * 1000
                AppLogger.metrics.info("   Average Wrinkle Depth: \(String(format: "%.2f", Double(avgDepthMM)))mm")

                // VALIDATION: Check if wrinkles are suspiciously deep
                if avgDepthMM > 2.0 {
                    AppLogger.metrics.warning("   ⚠️ WARNING: Average wrinkle depth >\(String(format: "%.1f", Double(avgDepthMM)))mm is unusually deep!")
                    AppLogger.metrics.warning("   → For young skin, depth should typically be <1.0mm")
                    AppLogger.metrics.warning("   → This may indicate mesh quality issues or incorrect scaling")
                }
            }

            // Wrinkle score calculation:
            // - Fewer wrinkles = higher score (more youthful)
            // - Shallower wrinkles = higher score (better firmness)
            let wrinkleScore = wrinkles.overallScore

            // Combine wrinkles (60%) + smoothness (40%)
            // Wrinkles are better indicators of aging/firmness than surface smoothness alone
            let combinedScore = (wrinkleScore * 0.6) + (smoothness * 0.4)

            AppLogger.metrics.info("📊 Youthfulness Calculation:")
            AppLogger.metrics.info("   Wrinkle Score: \(String(format: "%.1f", Double(wrinkleScore)))/100 (60% weight)")
            AppLogger.metrics.info("   Smoothness: \(String(format: "%.1f", Double(smoothness)))/100 (40% weight)")
            AppLogger.metrics.info("   Combined (Firmness): \(String(format: "%.1f", Double(combinedScore)))/100")

            return Int(combinedScore.rounded())
        }

        // Fallback: Use smoothness only if wrinkle data unavailable
        AppLogger.metrics.debug("ℹ️ Youthfulness: Using smoothness only (no wrinkle data): \(String(format: "%.1f", Double(smoothness)))")
        return Int(smoothness.rounded())
    }

    private static func calculateFreshness(from metrics: Face3DMetrics) -> Int {
        // Use real hydration estimator if available
        if let hydration = metrics.hydrationEstimate {
            AppLogger.metrics.debug("ℹ️ Freshness: Using real hydration estimate: \(String(format: "%.1f", Double(hydration.overallScore)))")
            return Int(hydration.overallScore.rounded())
        }

        // Fallback to proxy only if hydration estimate unavailable (backward compatibility)
        AppLogger.metrics.debug("⚠️ Freshness: Hydration estimate unavailable, using proxy")
        let evenness = metrics.globalPigmentationScore
        let smoothness = metrics.globalRoughnessScore
        return Int((evenness * 0.5 + smoothness * 0.5).rounded())
    }

    // MARK: - Message Generators

    private static func generatePrimaryInsight(skinHealthScore: Int, metrics: Face3DMetrics) -> String {
        // Get top and lowest metrics for specific insights
        let topMetric = getTopMetric(metrics)
        let lowestMetric = getLowestMetric(metrics)
        let topConcerns = getTopConcerns(metrics, limit: 2)
        
        switch skinHealthScore {
        case 90...100:
            return "Your skin health score is \(skinHealthScore)/100. Your \(topMetric) is particularly strong. Keep doing what you're doing."
        case 80..<90:
            return "Your skin health score is \(skinHealthScore)/100. Your \(topMetric) is strong. Focus on improving \(lowestMetric) to reach the next level."
        case 70..<80:
            return "Your skin health score is \(skinHealthScore)/100. Prioritize \(topConcerns.joined(separator: " and ")) for noticeable improvement."
        case 60..<70:
            let primaryConcern = topConcerns.first ?? "your main concern"
            return "Your skin health score is \(skinHealthScore)/100. Focus on \(primaryConcern) first. Small consistent changes will show results in 3-4 weeks."
        case 50..<60:
            return "Your skin health score is \(skinHealthScore)/100. Let's build a targeted routine. Start with the most critical issue below and track progress weekly."
        default:
            return "Your skin health score is \(skinHealthScore)/100. We've identified specific areas to address. Follow the action plan below to see improvement."
        }
    }
    
    // Helper: Get top performing metric
    private static func getTopMetric(_ metrics: Face3DMetrics) -> String {
        let metrics: [(String, Float)] = [
            ("texture", metrics.globalRoughnessScore),
            ("tone evenness", metrics.globalPigmentationScore),
            ("uniformity", metrics.globalDiscolorationScore),
            ("pores", metrics.poreAnalysis?.visibilityScore ?? 0),
            ("acne clarity", metrics.acneAnalysis?.overallScore ?? 0)
        ]
        return metrics.max(by: { $0.1 < $1.1 })?.0 ?? "overall skin health"
    }
    
    // Helper: Get lowest performing metric
    private static func getLowestMetric(_ metrics: Face3DMetrics) -> String {
        let metrics: [(String, Float)] = [
            ("texture", metrics.globalRoughnessScore),
            ("tone evenness", metrics.globalPigmentationScore),
            ("uniformity", metrics.globalDiscolorationScore),
            ("pores", 100 - (metrics.poreAnalysis?.visibilityScore ?? 50)), // Invert pore visibility
            ("acne clarity", metrics.acneAnalysis?.overallScore ?? 75)
        ]
        return metrics.min(by: { $0.1 < $1.1 })?.0 ?? "overall skin health"
    }
    
    // Helper: Get top concerns
    private static func getTopConcerns(_ metrics: Face3DMetrics, limit: Int) -> [String] {
        var concerns: [String] = []
        
        if metrics.globalRoughnessScore < 60 {
            concerns.append("texture")
        }
        if metrics.globalPigmentationScore < 60 {
            concerns.append("tone evenness")
        }
        if metrics.globalDiscolorationScore < 60 {
            concerns.append("discoloration")
        }
        if let pores = metrics.poreAnalysis, pores.visibility > 50 {
            concerns.append("pore visibility")
        }
        if let acne = metrics.acneAnalysis, acne.overallScore < 70 {
            concerns.append("acne")
        }
        
        return Array(concerns.prefix(limit))
    }

    private static func generateCelebration(skinHealthScore: Int, previousScore: Int?) -> String {
        if let prev = previousScore {
            let change = skinHealthScore - prev
            if change > 10 {
                return "Your skin health score improved from \(prev) to \(skinHealthScore) (+\(change) points). Your routine is working!"
            } else if change > 5 {
                return "Your skin health score improved from \(prev) to \(skinHealthScore) (+\(change) points). Keep up the consistent care!"
            } else if change > 0 {
                return "Your skin health score improved from \(prev) to \(skinHealthScore) (+\(change) points). Small progress adds up!"
            } else if change == 0 {
                return "Your skin health score is \(skinHealthScore)/100, same as last time. Consistency is key - keep maintaining your routine!"
            } else {
                let decline = abs(change)
                return "Your skin health score decreased from \(prev) to \(skinHealthScore) (-\(decline) points). Review the recommendations below to get back on track."
            }
        } else {
            // First scan
            if skinHealthScore >= 80 {
                return "Your baseline skin health score is \(skinHealthScore)/100. Great starting point! Track changes over time to see your progress."
            } else {
                return "Your baseline skin health score is \(skinHealthScore)/100. This is your starting point. Follow the recommendations to improve."
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
            let score = Int(metrics.globalRoughnessScore)
            let textureIssue = getSpecificTextureIssue(metrics)
            let solution = getSpecificTextureSolution(score: metrics.globalRoughnessScore, profile: userProfile)
            _ = getRealisticTimeframe(score: metrics.globalRoughnessScore) // timeframe for future use

            concerns.append(EmotionalConcern(
                title: "Skin texture could be smoother",
                emoji: "✨",
                severity: severity,
                message: "Your texture score is \(score)/100. This indicates \(textureIssue).",
                solution: solution,
                encouragement: "With a consistent skincare routine, you may see improvement over time."
            ))
        }

        // Pigmentation concerns
        if metrics.globalPigmentationScore < 60 {
            let severity: ConcernLevel = metrics.globalPigmentationScore < 40 ? .moderate : .mild
            let score = Int(metrics.globalPigmentationScore)
            let solution = getSpecificPigmentationSolution(score: metrics.globalPigmentationScore, profile: userProfile)
            _ = getRealisticTimeframe(score: metrics.globalPigmentationScore) // timeframe for future use

            concerns.append(EmotionalConcern(
                title: "Uneven skin tone",
                emoji: "🌤️",
                severity: severity,
                message: "Your tone evenness score is \(score)/100. This indicates noticeable color variation across your face.",
                solution: solution,
                encouragement: "With a consistent skincare routine, you may see improvement over time."
            ))
        }

        // Discoloration concerns
        if metrics.globalDiscolorationScore < 60 {
            let severity: ConcernLevel = metrics.globalDiscolorationScore < 40 ? .moderate : .mild
            let score = Int(metrics.globalDiscolorationScore)
            let solution = getSpecificDiscolorationSolution(score: metrics.globalDiscolorationScore, profile: userProfile)
            _ = getRealisticTimeframe(score: metrics.globalDiscolorationScore) // timeframe for future use

            concerns.append(EmotionalConcern(
                title: "Dark spots or hyperpigmentation",
                emoji: "☀️",
                severity: severity,
                message: "Your discoloration score is \(score)/100. This indicates visible dark spots or patchy pigmentation.",
                solution: solution,
                encouragement: "With a consistent skincare routine, you may see fading over time. SPF is essential to prevent new spots."
            ))
        }

        // Wrinkle concerns
        if let wrinkles = metrics.wrinkleAnalysis, wrinkles.overallScore < 70 {
            let severity: ConcernLevel = wrinkles.overallScore < 50 ? .moderate : .mild
            let score = Int(wrinkles.overallScore)
            let wrinkleCount = wrinkles.wrinkleCount
            let solution = getSpecificWrinkleSolution(score: wrinkles.overallScore, count: wrinkleCount, profile: userProfile)
            _ = getRealisticTimeframe(score: wrinkles.overallScore) // timeframe for future use

            concerns.append(EmotionalConcern(
                title: "Fine lines and wrinkles",
                emoji: "💧",
                severity: severity,
                message: "Your wrinkle score is \(score)/100. We detected \(wrinkleCount) wrinkles with \(wrinkles.wrinkleDepth.rawValue) depth.",
                solution: solution,
                encouragement: "With a consistent skincare routine, you may see improvement over time."
            ))
        }

        // Pore concerns
        if let pores = metrics.poreAnalysis, pores.visibility > 30 {
            let severity: ConcernLevel = pores.visibility > 50 ? .moderate : .mild
            let visibility = Int(pores.visibility)
            let solution = getSpecificPoreSolution(visibility: pores.visibility, profile: userProfile)
            _ = getRealisticTimeframe(score: 100 - pores.visibility) // timeframe for future use (inverted for calculation)

            concerns.append(EmotionalConcern(
                title: "Visible pores",
                emoji: "🔬",
                severity: severity,
                message: "Your pore visibility is \(visibility)/100. This indicates enlarged pores that may benefit from targeted care.",
                solution: solution,
                encouragement: "With a consistent skincare routine, you may see improvement over time."
            ))
        }

        // Acne concerns
        if let acne = metrics.acneAnalysis, acne.blemishCount > 5 {
            let severity: ConcernLevel = acne.blemishCount > 20 ? .moderate : .mild
            let score = Int(acne.overallScore)
            let count = acne.blemishCount
            let solution = getSpecificAcneSolution(score: acne.overallScore, count: count, profile: userProfile)
            _ = count > 20 ? "2-3" : "1-2" // timeframe for future use

            concerns.append(EmotionalConcern(
                title: "Active breakouts",
                emoji: "🌿",
                severity: severity,
                message: "Your acne clarity score is \(score)/100. We detected \(count) active blemishes (\(acne.severity.rawValue) severity).",
                solution: solution,
                encouragement: "With a consistent skincare routine, you may see improvement over time."
            ))
        }

        // Redness concerns
        if let redness = metrics.rednessAnalysis, redness.overallScore < 70 {
            let severity: ConcernLevel = redness.overallScore < 50 ? .moderate : .mild
            let score = Int(redness.overallScore)
            let solution = getSpecificRednessSolution(score: redness.overallScore, level: redness.rednessLevel, profile: userProfile)
            let timeframe = getRealisticTimeframe(score: redness.overallScore)
            
            concerns.append(EmotionalConcern(
                title: "Skin redness and sensitivity",
                emoji: "🌸",
                severity: severity,
                message: "Your redness control score is \(score)/100. This indicates \(redness.rednessLevel.rawValue) redness that needs calming treatment.",
                solution: solution,
                encouragement: "With consistent gentle treatment, you should see improvement in \(timeframe) weeks."
            ))
        }

        return concerns
    }

    private static func generatePersonalizedMessage(
        skinHealthScore: Int,
        metrics: Face3DMetrics,
        improvements: [EmotionalImprovement],
        concerns: [EmotionalConcern],
        userProfile: UserProfile?
    ) -> String {
        let name = userProfile?.name ?? "there"

        if !improvements.isEmpty {
            let topImprovement = improvements.max(by: { $0.percentChange < $1.percentChange })
            if let improvement = topImprovement {
                return "\(name), your \(improvement.title.lowercased()) improved by \(improvement.percentChange) points! Your routine is working - keep it up."
            }
            return "\(name), your routine is paying off! Keep up the consistent care."
        } else if skinHealthScore >= 80 {
            let topMetric = getTopMetric(metrics)
            return "\(name), your skin health score is \(skinHealthScore)/100. Your \(topMetric) is particularly strong. Maintain your current routine."
        } else if concerns.isEmpty {
            return "\(name), your skin health score is \(skinHealthScore)/100. You're doing well. Focus on the recommendations below to reach the next level."
        } else {
            let primaryConcern = concerns.first?.title.lowercased() ?? "main concern"
            return "\(name), your skin health score is \(skinHealthScore)/100. We've identified \(primaryConcern) as the priority. Follow the action plan below."
        }
    }

    private static func generateNextSteps(
        concerns: [EmotionalConcern],
        metrics: Face3DMetrics,
        skinHealthScore: Int,
        userProfile: UserProfile?
    ) -> [ActionableStep] {
        var steps: [ActionableStep] = []

        // Always recommend SPF (most important)
        steps.append(ActionableStep(
            action: "Apply SPF 30+ sunscreen",
            frequency: "Every morning",
            timing: "After moisturizer",
            expectedResult: "Prevent new UV damage and maintain your current skin health score",
            priority: .critical,
            icon: "sun.max.fill"
        ))

        // Generate steps based on concerns with specific actions
        for concern in concerns.prefix(2) {  // Top 2 concerns only
            if concern.title.contains("texture") {
                let action = getSpecificExfoliationAction(score: metrics.globalRoughnessScore, profile: userProfile)
                let frequency = getSpecificFrequency(score: metrics.globalRoughnessScore, isExfoliation: true)
                let timeframe = getRealisticTimeframe(score: metrics.globalRoughnessScore)
                let expectedImprovement = getExpectedImprovement(score: metrics.globalRoughnessScore)
                
                steps.append(ActionableStep(
                    action: action,
                    frequency: frequency,
                    timing: "Evening, after cleansing, before moisturizer",
                    expectedResult: "\(expectedImprovement)% smoother texture in \(timeframe) weeks",
                    priority: .important,
                    icon: "sparkles"
                ))
            }

            if concern.title.contains("tone") || concern.title.contains("spots") {
                let action = getSpecificPigmentationAction(score: metrics.globalPigmentationScore, profile: userProfile)
                let timeframe = getRealisticTimeframe(score: metrics.globalPigmentationScore)
                let expectedImprovement = getExpectedImprovement(score: metrics.globalPigmentationScore)
                
                steps.append(ActionableStep(
                    action: action,
                    frequency: "Every morning",
                    timing: "Before moisturizer, after cleansing",
                    expectedResult: "\(expectedImprovement)% more even tone in \(timeframe) weeks",
                    priority: .important,
                    icon: "sunrise.fill"
                ))
            }

            if concern.title.contains("wrinkles") || concern.title.contains("lines") {
                let action = getSpecificWrinkleAction(score: metrics.wrinkleAnalysis?.overallScore ?? 70, profile: userProfile)
                let frequency = getSpecificFrequency(score: metrics.wrinkleAnalysis?.overallScore ?? 70, isExfoliation: false)
                let timeframe = getRealisticTimeframe(score: metrics.wrinkleAnalysis?.overallScore ?? 70)
                
                steps.append(ActionableStep(
                    action: action,
                    frequency: frequency,
                    timing: "Evening, after cleansing, before moisturizer",
                    expectedResult: "Reduced fine lines and improved firmness in \(timeframe) weeks",
                    priority: .important,
                    icon: "moon.stars.fill"
                ))
            }

            if concern.title.contains("pores") {
                let action = getSpecificPoreAction(visibility: metrics.poreAnalysis?.visibility ?? 50, profile: userProfile)
                let timeframe = getRealisticTimeframe(score: 100 - (metrics.poreAnalysis?.visibility ?? 50))
                
                steps.append(ActionableStep(
                    action: action,
                    frequency: "Morning and evening",
                    timing: "After cleansing, before other serums",
                    expectedResult: "Minimized pore appearance in \(timeframe) weeks",
                    priority: .important,
                    icon: "circle.grid.2x2.fill"
                ))
            }

            if concern.title.contains("breakouts") || concern.title.contains("acne") {
                let action = getSpecificAcneAction(score: metrics.acneAnalysis?.overallScore ?? 70, count: metrics.acneAnalysis?.blemishCount ?? 0, profile: userProfile)
                let timeframe = metrics.acneAnalysis?.blemishCount ?? 0 > 20 ? "2-3" : "1-2"
                
                steps.append(ActionableStep(
                    action: action,
                    frequency: "Once daily",
                    timing: "Evening, after cleansing",
                    expectedResult: "Clearer skin, fewer breakouts in \(timeframe) weeks",
                    priority: .important,
                    icon: "leaf.fill"
                ))
            }

            if concern.title.contains("redness") || concern.title.contains("sensitivity") {
                let action = getSpecificRednessAction(score: metrics.rednessAnalysis?.overallScore ?? 70, profile: userProfile)
                let timeframe = getRealisticTimeframe(score: metrics.rednessAnalysis?.overallScore ?? 70)
                
                steps.append(ActionableStep(
                    action: action,
                    frequency: "Morning and evening",
                    timing: "After cleansing, before other products",
                    expectedResult: "Reduced redness and irritation in \(timeframe) weeks",
                    priority: .important,
                    icon: "heart.fill"
                ))
            }
        }

        // Hydration (always good if score is low)
        if skinHealthScore < 80 {
            let hydrationScore = metrics.hydrationEstimate?.overallScore ?? 70
            let action = getSpecificHydrationAction(score: hydrationScore, profile: userProfile)
            let timeframe = getRealisticTimeframe(score: hydrationScore)
            
            steps.append(ActionableStep(
                action: action,
                frequency: "Morning and night",
                timing: "After cleansing, before other serums",
                expectedResult: "Improved hydration and plumpness in \(timeframe) weeks",
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
    
    // MARK: - Helper Functions for Specific Solutions
    
    private static func getSpecificTextureIssue(_ metrics: Face3DMetrics) -> String {
        if let pores = metrics.poreAnalysis, pores.visibility > 50 {
            return "enlarged pores and surface roughness"
        } else if metrics.globalRoughnessScore < 40 {
            return "significant texture irregularities that need targeted treatment"
        } else {
            return "mild texture concerns that can improve with consistent care"
        }
    }
    
    private static func getSpecificTextureSolution(score: Float, profile: UserProfile?) -> String {
        let isSensitive = profile?.skinType == .sensitive
        if score < 40 {
            return isSensitive
                ? "Start with a 2% salicylic acid cleanser daily (gentle for sensitive skin), add a 5% lactic acid serum 2x weekly at night, and use a ceramide moisturizer daily"
                : "Start with a 2% salicylic acid cleanser daily, add a 5% glycolic acid toner 3x weekly at night, and use a retinol serum 2x weekly. Moisturize with ceramides daily"
        } else if score < 60 {
            return isSensitive
                ? "Use a 5% lactic acid serum 2-3x weekly at night (gentler than glycolic), followed by a ceramide moisturizer. Add a niacinamide serum in the morning"
                : "Use a gentle AHA exfoliant (lactic acid 5-10%) 2-3x weekly at night, followed by a ceramide moisturizer. Add a niacinamide serum in the morning"
        } else {
            return "Maintain with a gentle exfoliant 1-2x weekly and consistent moisturizing. Consider adding a peptide serum for texture refinement"
        }
    }
    
    private static func getSpecificPigmentationSolution(score: Float, profile: UserProfile?) -> String {
        let isSensitive = profile?.skinType == .sensitive
        if score < 40 {
            return isSensitive
                ? "Apply vitamin C serum every morning (start a few times weekly), use SPF 50+ daily, and add a niacinamide serum at night"
                : "Apply vitamin C serum every morning, use SPF 50+ daily, and consider brightening products recommended by your dermatologist"
        } else if score < 60 {
            return isSensitive
                ? "Apply vitamin C serum every morning, use SPF 30+ daily, and add a niacinamide serum at night"
                : "Apply vitamin C serum every morning, use SPF 30+ daily, and add a brightening serum with arbutin or kojic acid"
        } else {
            return "Maintain with vitamin C serum every morning and daily SPF 30+. Consider adding a gentle brightening serum"
        }
    }
    
    private static func getSpecificDiscolorationSolution(score: Float, profile: UserProfile?) -> String {
        let isSensitive = profile?.skinType == .sensitive
        if score < 40 {
            return isSensitive
                ? "Apply SPF 50+ daily (most important), use a niacinamide serum morning and night, and add a gentle brightening serum with arbutin"
                : "Apply SPF 50+ daily (most important), use brightening products recommended by your dermatologist, and add a vitamin C serum in the morning"
        } else if score < 60 {
            return isSensitive
                ? "Apply SPF 30+ daily, use a niacinamide serum, and add a gentle brightening serum"
                : "Apply SPF 30+ daily, use a brightening serum with arbutin or kojic acid, and add vitamin C in the morning"
        } else {
            return "Maintain with daily SPF 30+ and a gentle brightening serum. SPF prevents new spots from forming"
        }
    }
    
    private static func getSpecificWrinkleSolution(score: Float, count: Int, profile: UserProfile?) -> String {
        let age = profile?.age ?? 30
        let isSensitive = profile?.skinType == .sensitive

        if age >= 40 {
            return isSensitive
                ? "Consider professional treatments from dermatologist, use a peptide serum daily, and apply SPF 50+ every morning"
                : "Consider professional treatments from dermatologist, use a peptide serum daily, and apply SPF 50+ every morning"
        } else if score < 50 {
            return isSensitive
                ? "Start with retinol products a few times weekly at night, use a peptide serum daily, and apply SPF 30+ every morning"
                : "Start with retinol products as recommended at night, use a peptide serum daily, and apply SPF 30+ every morning"
        } else {
            return isSensitive
                ? "Use retinol products a few times weekly at night, add a peptide serum, and apply SPF 30+ daily"
                : "Use retinol products as recommended at night, add a peptide serum, and apply SPF 30+ daily"
        }
    }
    
    private static func getSpecificPoreSolution(visibility: Float, profile: UserProfile?) -> String {
        let isSensitive = profile?.skinType == .sensitive
        if visibility > 60 {
            return isSensitive
                ? "Use salicylic acid cleanser daily, apply niacinamide serum morning and evening, and use a gentle clay mask once weekly"
                : "Use salicylic acid cleanser daily, apply niacinamide serum morning and evening, and use a BHA toner a few times weekly"
        } else if visibility > 40 {
            return isSensitive
                ? "Use a gentle salicylic acid cleanser a few times weekly, apply niacinamide serum daily, and use a gentle exfoliant once weekly"
                : "Use salicylic acid cleanser daily, apply niacinamide serum daily, and use a BHA toner a couple times weekly"
        } else {
            return "Maintain with niacinamide serum daily and gentle exfoliation 1-2x weekly"
        }
    }
    
    private static func getSpecificAcneSolution(score: Float, count: Int, profile: UserProfile?) -> String {
        let isSensitive = profile?.skinType == .sensitive
        if count > 20 {
            return isSensitive
                ? "Use salicylic acid cleanser daily, apply benzoyl peroxide spot treatment at night (2.5% or lower), and use a niacinamide serum to reduce inflammation"
                : "Use salicylic acid cleanser daily, apply acne treatment products at night, and consider professional treatments from your dermatologist"
        } else if count > 10 {
            return isSensitive
                ? "Use salicylic acid cleanser daily, apply benzoyl peroxide spot treatment (2.5% or lower), and use a niacinamide serum"
                : "Use salicylic acid cleanser daily, apply acne treatment products as recommended, and use a niacinamide serum"
        } else {
            return isSensitive
                ? "Use a gentle salicylic acid cleanser a few times weekly and apply benzoyl peroxide spot treatment (2.5% or lower) as needed"
                : "Use salicylic acid cleanser daily and apply acne spot treatment as needed"
        }
    }
    
    private static func getSpecificRednessSolution(score: Float, level: RednessLevel, profile: UserProfile?) -> String {
        let isSensitive = profile?.skinType == .sensitive
        if score < 50 {
            return isSensitive
                ? "Use fragrance-free, gentle cleanser, apply 5% niacinamide serum twice daily, use a centella asiatica serum, and avoid harsh exfoliants"
                : "Use gentle, fragrance-free products, apply 10% niacinamide serum twice daily, use a centella asiatica or azelaic acid serum, and avoid harsh exfoliants"
        } else {
            return isSensitive
                ? "Use gentle, fragrance-free products, apply 5% niacinamide serum daily, and use a calming serum with centella or aloe"
                : "Use gentle products, apply 10% niacinamide serum daily, and use a calming serum with centella or azelaic acid"
        }
    }
    
    private static func getSpecificExfoliationAction(score: Float, profile: UserProfile?) -> String {
        let isSensitive = profile?.skinType == .sensitive
        if score < 40 {
            return isSensitive
                ? "Start with 2% salicylic acid cleanser daily (gentle for sensitive skin)"
                : "Use 5% glycolic acid toner 3x weekly + 2% salicylic acid spot treatment"
        } else if score < 60 {
            return isSensitive
                ? "Use 5% lactic acid serum 2-3x weekly (gentler than glycolic)"
                : "Apply 7% glycolic acid toner 2-3x weekly"
        } else {
            return "Maintain with gentle 5% lactic acid 1-2x weekly"
        }
    }
    
    private static func getSpecificPigmentationAction(score: Float, profile: UserProfile?) -> String {
        let isSensitive = profile?.skinType == .sensitive
        if score < 40 {
            return isSensitive
                ? "Apply 10% L-ascorbic acid vitamin C serum (start 3x weekly, build to daily)"
                : "Apply 15-20% L-ascorbic acid vitamin C serum every morning"
        } else if score < 60 {
            return isSensitive
                ? "Apply 10% vitamin C serum every morning"
                : "Apply 15% vitamin C serum every morning"
        } else {
            return "Apply 10-15% vitamin C serum every morning"
        }
    }
    
    private static func getSpecificWrinkleAction(score: Float, profile: UserProfile?) -> String {
        let age = profile?.age ?? 30
        let isSensitive = profile?.skinType == .sensitive
        
        if age >= 40 {
            return "Consider consulting a dermatologist about advanced skincare options for your concerns"
        } else if score < 50 {
            return isSensitive
                ? "Start with 0.25% retinol serum 2x weekly at night"
                : "Start with 0.5% retinol serum 3-4x weekly at night"
        } else {
            return isSensitive
                ? "Use 0.25% retinol serum 2-3x weekly at night"
                : "Use 0.5% retinol serum 3x weekly at night"
        }
    }
    
    private static func getSpecificPoreAction(visibility: Float, profile: UserProfile?) -> String {
        let isSensitive = profile?.skinType == .sensitive
        if visibility > 60 {
            return isSensitive
                ? "Use 2% salicylic acid cleanser daily + 5% niacinamide serum"
                : "Use 2% salicylic acid cleanser daily + 10% niacinamide serum"
        } else if visibility > 40 {
            return isSensitive
                ? "Use gentle salicylic acid cleanser 3-4x weekly + 5% niacinamide serum"
                : "Use 2% salicylic acid cleanser daily + 10% niacinamide serum"
        } else {
            return "Use 5% niacinamide serum daily"
        }
    }
    
    private static func getSpecificAcneAction(score: Float, count: Int, profile: UserProfile?) -> String {
        let isSensitive = profile?.skinType == .sensitive
        if count > 20 {
            return isSensitive
                ? "Use 2% salicylic acid cleanser daily + 2.5% benzoyl peroxide spot treatment"
                : "Use 2% salicylic acid cleanser daily + 5% benzoyl peroxide treatment"
        } else if count > 10 {
            return isSensitive
                ? "Use 2% salicylic acid cleanser daily + 2.5% benzoyl peroxide spot treatment"
                : "Use 2% salicylic acid cleanser daily + 5% salicylic acid treatment"
        } else {
            return isSensitive
                ? "Use gentle salicylic acid cleanser 3-4x weekly + spot treatment as needed"
                : "Use 2% salicylic acid cleanser daily + spot treatment"
        }
    }
    
    private static func getSpecificRednessAction(score: Float, profile: UserProfile?) -> String {
        let isSensitive = profile?.skinType == .sensitive
        if score < 50 {
            return isSensitive
                ? "Use fragrance-free cleanser + 5% niacinamide serum twice daily + centella asiatica serum"
                : "Use gentle products + 10% niacinamide serum twice daily + centella or azelaic acid serum"
        } else {
            return isSensitive
                ? "Use gentle, fragrance-free products + 5% niacinamide serum daily"
                : "Use gentle products + 10% niacinamide serum daily"
        }
    }
    
    private static func getSpecificHydrationAction(score: Float, profile: UserProfile?) -> String {
        let isSensitive = profile?.skinType == .sensitive
        if score < 50 {
            return isSensitive
                ? "Apply hyaluronic acid serum (2-3% concentration) morning and night on damp skin, followed by a ceramide moisturizer"
                : "Apply hyaluronic acid serum (5% concentration) morning and night on damp skin, followed by a ceramide or peptide moisturizer"
        } else if score < 70 {
            return isSensitive
                ? "Apply hyaluronic acid serum morning and night on damp skin, followed by moisturizer"
                : "Apply hyaluronic acid serum morning and night on damp skin, followed by moisturizer"
        } else {
            return "Maintain with hyaluronic acid serum as needed, always apply on damp skin"
        }
    }
    
    private static func getSpecificFrequency(score: Float, isExfoliation: Bool) -> String {
        if isExfoliation {
            if score < 40 {
                return "3-4 times per week"
            } else if score < 60 {
                return "2-3 times per week"
            } else {
                return "1-2 times per week"
            }
        } else {
            if score < 50 {
                return "3-4 nights per week"
            } else if score < 70 {
                return "2-3 nights per week"
            } else {
                return "1-2 nights per week"
            }
        }
    }
    
    private static func getExpectedImprovement(score: Float) -> String {
        if score < 40 {
            return "15-20"
        } else if score < 60 {
            return "10-15"
        } else {
            return "5-10"
        }
    }
    
    private static func getRealisticTimeframe(score: Float) -> String {
        if score < 40 {
            return "4-6"
        } else if score < 60 {
            return "3-4"
        } else {
            return "2-3"
        }
    }
}
