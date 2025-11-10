//
//  SunDamageAnalyzer.swift
//  Tavi
//
//  IMPORTANT: Designed to work fairly across all skin tones (Fitzpatrick I-VI)
//  Uses relative metrics, NOT absolute thresholds
//
//  Sun damage indicators:
//  1. Hyperpigmentation (sun spots) - NORMALIZED by baseline skin tone
//  2. Photoaging (wrinkles from UV exposure)
//  3. Texture coarseness (leathery skin from sun)
//  4. Vascular damage (redness/broken capillaries)
//  5. Pore enlargement (collagen breakdown from UV)
//
//  Method: Composite score from existing analyses
//  Does NOT introduce new biases against dark skin
//

import Foundation
import UIKit

/// Sun damage analysis result
public struct SunDamageAnalysis: Codable, Sendable {
    /// Overall sun protection score (0-100, higher = better protected)
    public let protectionScore: Float

    /// Sun damage level classification
    public let damageLevel: SunDamageLevel

    /// Component scores (all 0-100, higher = less damage)
    public let pigmentationHealth: Float     // 30% weight - sun spots
    public let photoagingResistance: Float   // 25% weight - UV wrinkles
    public let textureHealth: Float          // 20% weight - skin coarseness
    public let vascularHealth: Float         // 15% weight - redness/vessels
    public let poreHealth: Float             // 10% weight - enlarged pores

    /// Raw damage indicators (0-1, higher = more damage)
    public let rawPigmentationDamage: Float
    public let rawPhotoagingDamage: Float
    public let rawTextureDamage: Float
    public let rawVascularDamage: Float
    public let rawPoreDamage: Float

    /// Confidence in assessment (0-100)
    public let confidence: Float

    /// Skin-tone-normalized assessment
    public let isNormalizedForSkinTone: Bool
    public let detectedSkinTone: SkinToneCategory

    /// User-friendly recommendations
    public let recommendations: [String]

    public init(
        protectionScore: Float,
        damageLevel: SunDamageLevel,
        pigmentationHealth: Float,
        photoagingResistance: Float,
        textureHealth: Float,
        vascularHealth: Float,
        poreHealth: Float,
        rawPigmentationDamage: Float,
        rawPhotoagingDamage: Float,
        rawTextureDamage: Float,
        rawVascularDamage: Float,
        rawPoreDamage: Float,
        confidence: Float,
        isNormalizedForSkinTone: Bool,
        detectedSkinTone: SkinToneCategory,
        recommendations: [String]
    ) {
        self.protectionScore = protectionScore
        self.damageLevel = damageLevel
        self.pigmentationHealth = pigmentationHealth
        self.photoagingResistance = photoagingResistance
        self.textureHealth = textureHealth
        self.vascularHealth = vascularHealth
        self.poreHealth = poreHealth
        self.rawPigmentationDamage = rawPigmentationDamage
        self.rawPhotoagingDamage = rawPhotoagingDamage
        self.rawTextureDamage = rawTextureDamage
        self.rawVascularDamage = rawVascularDamage
        self.rawPoreDamage = rawPoreDamage
        self.confidence = confidence
        self.isNormalizedForSkinTone = isNormalizedForSkinTone
        self.detectedSkinTone = detectedSkinTone
        self.recommendations = recommendations
    }
}

/// Sun damage severity levels
public enum SunDamageLevel: String, Codable, Sendable {
    case excellent = "Excellent Protection"     // 85-100
    case good = "Good Protection"                // 70-84
    case moderate = "Moderate Protection"        // 55-69
    case needsAttention = "Needs Attention"     // 40-54
    case highConcern = "High Concern"           // <40

    public var emoji: String {
        switch self {
        case .excellent: return "🛡️"
        case .good: return "☀️"
        case .moderate: return "🌤️"
        case .needsAttention: return "⚠️"
        case .highConcern: return "🔴"
        }
    }

    public var description: String {
        switch self {
        case .excellent:
            return "Your skin shows minimal signs of sun damage. Keep up the great sun protection!"
        case .good:
            return "Your skin is well protected. Continue your current sun care routine."
        case .moderate:
            return "Some sun damage detected. Consider boosting your sun protection."
        case .needsAttention:
            return "Noticeable sun damage present. Let's prioritize sun protection and repair."
        case .highConcern:
            return "Significant sun damage detected. Urgent attention to sun protection recommended."
        }
    }
}

/// Sun damage analyzer - skin-tone-fair implementation
public class SunDamageAnalyzer {

    // MARK: - Configuration

    /// Component weights (must sum to 1.0)
    private let weights: (
        pigmentation: Float,
        photoaging: Float,
        texture: Float,
        vascular: Float,
        pores: Float
    ) = (0.30, 0.25, 0.20, 0.15, 0.10)

    // MARK: - Public API

    /// Analyze sun damage using composite method
    /// IMPORTANT: Uses existing normalized metrics - fair for all skin tones
    public func analyzeSunDamage(
        from metrics: Face3DMetrics,
        skinTone: SkinToneCategory
    ) -> SunDamageAnalysis {

        AppLogger.metrics.info("☀️ Analyzing sun damage (skin-tone-fair algorithm)...")
        AppLogger.metrics.info("   Detected skin tone: \(skinTone)")

        // Component 1: Pigmentation damage (sun spots)
        // Already normalized by SkinToneNormalizer in Face3DMetricsAnalyzer
        let pigmentationHealth = metrics.globalPigmentationScore  // 0-100
        let rawPigmentationDamage = 1.0 - (pigmentationHealth / 100.0)  // Convert to 0-1 damage

        AppLogger.metrics.info("   1. Pigmentation health: \(String(format: "%.1f", pigmentationHealth))/100")
        AppLogger.metrics.info("      (Already normalized for \(skinTone))")

        // Component 2: Photoaging (wrinkles from UV)
        let photoagingResistance: Float
        if let wrinkles = metrics.wrinkleAnalysis {
            photoagingResistance = wrinkles.overallScore  // 0-100
        } else {
            // Fallback: use roughness as proxy (roughness correlates with photoaging)
            photoagingResistance = metrics.globalRoughnessScore
        }
        let rawPhotoagingDamage = 1.0 - (photoagingResistance / 100.0)

        AppLogger.metrics.info("   2. Photoaging resistance: \(String(format: "%.1f", photoagingResistance))/100")

        // Component 3: Texture coarseness (leathery skin from sun)
        let textureHealth = metrics.globalRoughnessScore  // 0-100 (higher = smoother)
        let rawTextureDamage = 1.0 - (textureHealth / 100.0)

        AppLogger.metrics.info("   3. Texture health: \(String(format: "%.1f", textureHealth))/100")

        // Component 4: Vascular damage (redness/broken vessels)
        let vascularHealth: Float
        if let redness = metrics.rednessAnalysis {
            vascularHealth = redness.overallScore  // 0-100 (higher = less red)
        } else {
            // Fallback: neutral score if redness analysis not available
            vascularHealth = 75.0
        }
        let rawVascularDamage = 1.0 - (vascularHealth / 100.0)

        AppLogger.metrics.info("   4. Vascular health: \(String(format: "%.1f", vascularHealth))/100")

        // Component 5: Pore health (enlarged pores from collagen breakdown)
        let poreHealth: Float
        if let pores = metrics.poreAnalysis {
            poreHealth = 100.0 - pores.visibility  // Invert: lower visibility = better
        } else {
            // Fallback: neutral score
            poreHealth = 75.0
        }
        let rawPoreDamage = 1.0 - (poreHealth / 100.0)

        AppLogger.metrics.info("   5. Pore health: \(String(format: "%.1f", poreHealth))/100")

        // Calculate weighted composite score
        let protectionScore = (
            pigmentationHealth * weights.pigmentation +
            photoagingResistance * weights.photoaging +
            textureHealth * weights.texture +
            vascularHealth * weights.vascular +
            poreHealth * weights.pores
        )

        // Classify damage level
        let damageLevel = classifyDamageLevel(score: protectionScore)

        // Calculate confidence
        let confidence = calculateConfidence(
            metrics: metrics,
            hasWrinkles: metrics.wrinkleAnalysis != nil,
            hasRedness: metrics.rednessAnalysis != nil,
            hasPores: metrics.poreAnalysis != nil
        )

        // Generate recommendations
        let recommendations = generateRecommendations(
            protectionScore: protectionScore,
            pigmentationHealth: pigmentationHealth,
            photoagingResistance: photoagingResistance,
            textureHealth: textureHealth,
            vascularHealth: vascularHealth,
            skinTone: skinTone
        )

        AppLogger.metrics.info("✅ Sun damage analysis complete:")
        AppLogger.metrics.info("   Protection score: \(String(format: "%.1f", protectionScore))/100 (\(damageLevel.rawValue))")
        AppLogger.metrics.info("   Confidence: \(String(format: "%.0f", confidence))%")
        AppLogger.metrics.info("   Normalized for skin tone: ✅ YES (fair for \(skinTone))")
        AppLogger.metrics.info("   Recommendations: \(recommendations.count)")

        return SunDamageAnalysis(
            protectionScore: protectionScore,
            damageLevel: damageLevel,
            pigmentationHealth: pigmentationHealth,
            photoagingResistance: photoagingResistance,
            textureHealth: textureHealth,
            vascularHealth: vascularHealth,
            poreHealth: poreHealth,
            rawPigmentationDamage: rawPigmentationDamage,
            rawPhotoagingDamage: rawPhotoagingDamage,
            rawTextureDamage: rawTextureDamage,
            rawVascularDamage: rawVascularDamage,
            rawPoreDamage: rawPoreDamage,
            confidence: confidence,
            isNormalizedForSkinTone: true,
            detectedSkinTone: skinTone,
            recommendations: recommendations
        )
    }

    // MARK: - Private Methods

    private func classifyDamageLevel(score: Float) -> SunDamageLevel {
        switch score {
        case 85...100:
            return .excellent
        case 70..<85:
            return .good
        case 55..<70:
            return .moderate
        case 40..<55:
            return .needsAttention
        default:
            return .highConcern
        }
    }

    private func calculateConfidence(
        metrics: Face3DMetrics,
        hasWrinkles: Bool,
        hasRedness: Bool,
        hasPores: Bool
    ) -> Float {
        var confidence: Float = 70.0  // Base confidence

        // Higher confidence if all component analyses are available
        if hasWrinkles { confidence += 10 }
        if hasRedness { confidence += 10 }
        if hasPores { confidence += 10 }

        // Higher confidence for high-quality scans
        if metrics.isHighQuality {
            confidence += 10
        }

        // Lower confidence if texture quality is poor
        if let quality = metrics.textureQuality, quality.contains("warning") || quality.contains("low") {
            confidence -= 20
        }

        return max(50, min(95, confidence))
    }

    private func generateRecommendations(
        protectionScore: Float,
        pigmentationHealth: Float,
        photoagingResistance: Float,
        textureHealth: Float,
        vascularHealth: Float,
        skinTone: SkinToneCategory
    ) -> [String] {
        var recommendations: [String] = []

        // Universal recommendation
        recommendations.append("Use broad-spectrum SPF 30+ sunscreen daily, even indoors")

        // Pigmentation-specific recommendations
        if pigmentationHealth < 70 {
            recommendations.append("Consider vitamin C serum to brighten and protect against further sun damage")
            if skinTone == .dark || skinTone == .veryDark {
                recommendations.append("For Indian/dark skin: Focus on evening skin tone with niacinamide or kojic acid")
            }
        }

        // Photoaging-specific recommendations
        if photoagingResistance < 70 {
            recommendations.append("Add retinol (start with 0.25%) to boost collagen and reduce fine lines")
            recommendations.append("Wear protective clothing and seek shade during peak sun hours (10am-4pm)")
        }

        // Texture-specific recommendations
        if textureHealth < 70 {
            recommendations.append("Use gentle exfoliation (AHA/BHA) to improve texture")
            recommendations.append("Stay hydrated and use a rich moisturizer to combat dryness")
        }

        // Vascular-specific recommendations
        if vascularHealth < 70 {
            recommendations.append("Consider products with niacinamide or azelaic acid to reduce redness")
        }

        // Skin-tone-specific sun protection advice
        if skinTone == .veryLight || skinTone == .light {
            recommendations.append("Light skin is more vulnerable to UV - reapply SPF every 2 hours")
        } else if skinTone == .dark || skinTone == .veryDark {
            recommendations.append("Dark skin has more natural protection but still needs SPF - don't skip it!")
        }

        // Limit to top 5 recommendations
        return Array(recommendations.prefix(5))
    }
}
