//
//  EmotionalMetricsTests.swift
//  OllvyTests
//
//  Unit tests for emotional metrics and glow score calculation
//  Created on 2025-10-29.
//

import XCTest
@testable import Ollvy

class EmotionalMetricsTests: XCTestCase {

    // MARK: - Glow Score Calculation Tests

    func testGlowScore_ExcellentSkin() {
        // Perfect scores should yield glow score near 100
        let metrics = createMockMetrics(
            roughness: 95,
            pigmentation: 95,
            discoloration: 95,
            specular: 90
        )

        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        XCTAssertGreaterThanOrEqual(emotional.glowScore, 90, "Excellent skin should have glow score >= 90")
        XCTAssertLessThanOrEqual(emotional.glowScore, 100, "Glow score should not exceed 100")
    }

    func testGlowScore_PoorSkin() {
        // Poor scores should yield lower glow score
        let metrics = createMockMetrics(
            roughness: 30,
            pigmentation: 30,
            discoloration: 30,
            specular: 30
        )

        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        XCTAssertLessThan(emotional.glowScore, 50, "Poor skin should have glow score < 50")
        XCTAssertGreaterThanOrEqual(emotional.glowScore, 0, "Glow score should not be negative")
    }

    func testGlowScore_RangeConstraints() {
        // Test edge cases for range constraints
        let metrics = createMockMetrics(
            roughness: 150,  // Over 100 (should clamp)
            pigmentation: -10,  // Negative (should clamp)
            discoloration: 50,
            specular: 50
        )

        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        XCTAssertTrue(emotional.glowScore >= 0 && emotional.glowScore <= 100,
                     "Glow score must be in range 0-100, got \(emotional.glowScore)")
    }

    func testGlowScore_WeightedFormula() {
        // Verify weighted formula: 40% smoothness + 30% evenness + 20% discoloration + 10% specular
        let metrics = createMockMetrics(
            roughness: 80,      // 40% weight = 32
            pigmentation: 60,   // 30% weight = 18
            discoloration: 70,  // 20% weight = 14
            specular: 50        // 10% weight = 5
        )
        // Expected: 32 + 18 + 14 + 5 = 69

        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        // Allow ±2 points for rounding
        XCTAssertTrue(abs(emotional.glowScore - 69) <= 2,
                     "Glow score should be ~69, got \(emotional.glowScore)")
    }

    func testGlowScore_HandlesNilSpecular() {
        // When specular is nil, should still calculate glow score
        let metrics = createMockMetrics(
            roughness: 70,
            pigmentation: 70,
            discoloration: 70,
            specular: nil  // Missing specular data
        )

        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        XCTAssertTrue(emotional.glowScore >= 0 && emotional.glowScore <= 100,
                     "Should handle nil specular gracefully")
    }

    // MARK: - Primary Insight Tests

    func testPrimaryInsight_ExcellentScore() {
        let metrics = createMockMetrics(roughness: 95, pigmentation: 95, discoloration: 95, specular: 95)
        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        XCTAssertTrue(emotional.primaryInsight.contains("INCREDIBLE") ||
                     emotional.primaryInsight.contains("amazing"),
                     "Score 90+ should show enthusiastic message")
    }

    func testPrimaryInsight_PoorScore() {
        let metrics = createMockMetrics(roughness: 30, pigmentation: 30, discoloration: 30, specular: 30)
        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        XCTAssertTrue(emotional.primaryInsight.contains("plan") ||
                     emotional.primaryInsight.contains("boost"),
                     "Low score should show encouraging message")
    }

    // MARK: - Sub-Score Tests

    func testSubScores_Radiance() {
        let metrics = createMockMetrics(
            roughness: 80,
            pigmentation: 90,  // High evenness = high radiance
            discoloration: 70,
            specular: 80       // High shine = high radiance
        )

        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        // Radiance = 60% evenness + 40% shine = 0.6*90 + 0.4*80 = 54 + 32 = 86
        XCTAssertTrue(abs(emotional.radiance - 86) <= 2,
                     "Radiance should be ~86, got \(emotional.radiance)")
    }

    func testSubScores_Smoothness() {
        let metrics = createMockMetrics(
            roughness: 85,  // Direct mapping to smoothness
            pigmentation: 60,
            discoloration: 70,
            specular: 50
        )

        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        XCTAssertEqual(emotional.smoothness, 85, "Smoothness should equal roughness score")
    }

    func testSubScores_Evenness() {
        let metrics = createMockMetrics(
            roughness: 70,
            pigmentation: 88,  // Direct mapping to evenness
            discoloration: 60,
            specular: 50
        )

        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        XCTAssertEqual(emotional.evenness, 88, "Evenness should equal pigmentation score")
    }

    func testSubScores_Youthfulness() {
        let metrics = createMockMetrics(
            roughness: 92,  // Smoothness correlates with youthfulness
            pigmentation: 70,
            discoloration: 70,
            specular: 50
        )

        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        XCTAssertEqual(emotional.youthfulness, 92,
                      "Youthfulness should correlate with smoothness")
    }

    func testSubScores_Freshness() {
        let metrics = createMockMetrics(
            roughness: 80,      // 50% weight
            pigmentation: 90,   // 50% weight
            discoloration: 60,
            specular: 50
        )

        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        // Freshness = 50% evenness + 50% smoothness = 0.5*90 + 0.5*80 = 85
        XCTAssertTrue(abs(emotional.freshness - 85) <= 2,
                     "Freshness should be ~85, got \(emotional.freshness)")
    }

    // MARK: - Improvement Detection Tests

    func testImprovements_NoProgressNoImprovements() {
        let current = createMockMetrics(roughness: 70, pigmentation: 70, discoloration: 70, specular: 70)
        let previous = createMockMetrics(roughness: 70, pigmentation: 70, discoloration: 70, specular: 70)

        let emotional = EmotionalMetricsGenerator.generate(from: current, previousMetrics: previous)

        XCTAssertTrue(emotional.improvements.isEmpty,
                     "No changes should result in no improvements")
    }

    func testImprovements_SignificantProgress() {
        let current = createMockMetrics(roughness: 85, pigmentation: 80, discoloration: 75, specular: 70)
        let previous = createMockMetrics(roughness: 70, pigmentation: 65, discoloration: 60, specular: 65)

        let emotional = EmotionalMetricsGenerator.generate(from: current, previousMetrics: previous)

        XCTAssertFalse(emotional.improvements.isEmpty,
                      "Should detect improvements when scores increase by 5+")
        XCTAssertTrue(emotional.improvements.count >= 2,
                     "Should detect multiple improvements")
    }

    func testImprovements_MinorProgressIgnored() {
        let current = createMockMetrics(roughness: 72, pigmentation: 71, discoloration: 70, specular: 70)
        let previous = createMockMetrics(roughness: 70, pigmentation: 70, discoloration: 70, specular: 70)

        let emotional = EmotionalMetricsGenerator.generate(from: current, previousMetrics: previous)

        XCTAssertTrue(emotional.improvements.isEmpty,
                     "Changes < 5 points should not be reported as improvements")
    }

    // MARK: - Concern Identification Tests

    func testConcerns_ExcellentSkinNoConcerns() {
        let metrics = createMockMetrics(roughness: 90, pigmentation: 90, discoloration: 90, specular: 85)
        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        XCTAssertTrue(emotional.concerns.isEmpty || emotional.concerns.count <= 1,
                     "Excellent skin should have minimal concerns")
    }

    func testConcerns_PoorTextureIdentified() {
        let metrics = createMockMetrics(roughness: 40, pigmentation: 80, discoloration: 80, specular: 70)
        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        XCTAssertTrue(emotional.concerns.contains { $0.title.contains("texture") },
                     "Poor roughness score should identify texture concern")
    }

    func testConcerns_UnevenToneIdentified() {
        let metrics = createMockMetrics(roughness: 80, pigmentation: 45, discoloration: 80, specular: 70)
        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        XCTAssertTrue(emotional.concerns.contains { $0.title.contains("tone") },
                     "Poor pigmentation score should identify tone concern")
    }

    func testConcerns_DiscolorationIdentified() {
        let metrics = createMockMetrics(roughness: 80, pigmentation: 80, discoloration: 35, specular: 70)
        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        XCTAssertTrue(emotional.concerns.contains { $0.title.contains("spots") || $0.title.contains("hyperpigmentation") },
                     "Poor discoloration score should identify dark spots concern")
    }

    func testConcerns_SeverityLevels() {
        // Moderate concern (score < 40)
        let moderateMetrics = createMockMetrics(roughness: 35, pigmentation: 80, discoloration: 80, specular: 70)
        let moderateEmotional = EmotionalMetricsGenerator.generate(from: moderateMetrics)
        let moderateConcerns = moderateEmotional.concerns.filter { $0.severity == .moderate }

        // Mild concern (score 40-60)
        let mildMetrics = createMockMetrics(roughness: 55, pigmentation: 80, discoloration: 80, specular: 70)
        let mildEmotional = EmotionalMetricsGenerator.generate(from: mildMetrics)
        let mildConcerns = mildEmotional.concerns.filter { $0.severity == .mild }

        XCTAssertTrue(moderateConcerns.count > 0, "Score < 40 should trigger moderate severity")
        XCTAssertTrue(mildConcerns.count > 0, "Score 40-60 should trigger mild severity")
    }

    // MARK: - Next Steps Tests

    func testNextSteps_AlwaysIncludesSPF() {
        let metrics = createMockMetrics(roughness: 70, pigmentation: 70, discoloration: 70, specular: 70)
        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        XCTAssertTrue(emotional.nextSteps.contains { $0.action.contains("SPF") || $0.action.contains("sunscreen") },
                     "Next steps should always include SPF recommendation")
    }

    func testNextSteps_PrioritizesTextureFixes() {
        let metrics = createMockMetrics(roughness: 40, pigmentation: 80, discoloration: 80, specular: 70)
        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        XCTAssertTrue(emotional.nextSteps.contains { $0.action.contains("exfoliat") || $0.action.contains("AHA") || $0.action.contains("BHA") },
                     "Poor texture should suggest exfoliation")
    }

    func testNextSteps_LimitedToManageable() {
        let metrics = createMockMetrics(roughness: 30, pigmentation: 30, discoloration: 30, specular: 30)
        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        XCTAssertLessThanOrEqual(emotional.nextSteps.count, 5,
                                "Should limit next steps to avoid overwhelming user")
    }

    // MARK: - Celebration Message Tests

    func testCelebration_FirstScanPositive() {
        let metrics = createMockMetrics(roughness: 85, pigmentation: 85, discoloration: 80, specular: 75)
        let emotional = EmotionalMetricsGenerator.generate(from: metrics, previousMetrics: nil)

        XCTAssertTrue(emotional.celebration.contains("baseline") || emotional.celebration.contains("starting point"),
                     "First scan should establish baseline")
    }

    func testCelebration_SignificantImprovement() {
        let current = createMockMetrics(roughness: 85, pigmentation: 85, discoloration: 80, specular: 75)
        let previous = createMockMetrics(roughness: 65, pigmentation: 65, discoloration: 60, specular: 60)

        let emotional = EmotionalMetricsGenerator.generate(from: current, previousMetrics: previous)

        // Glow score jumped from ~63 to ~82 (19 points)
        XCTAssertTrue(emotional.celebration.contains("jump") || emotional.celebration.contains("progress") || emotional.celebration.contains("WOW"),
                     "Large improvement should trigger enthusiastic celebration")
    }

    func testCelebration_NoChange() {
        let current = createMockMetrics(roughness: 75, pigmentation: 75, discoloration: 70, specular: 70)
        let previous = createMockMetrics(roughness: 75, pigmentation: 75, discoloration: 70, specular: 70)

        let emotional = EmotionalMetricsGenerator.generate(from: current, previousMetrics: previous)

        XCTAssertTrue(emotional.celebration.contains("maintain") || emotional.celebration.contains("Keep it up"),
                     "No change should encourage maintenance")
    }

    // MARK: - Helper Methods

    private func createMockMetrics(
        roughness: Float,
        pigmentation: Float,
        discoloration: Float,
        specular: Float?
    ) -> Face3DMetrics {
        return Face3DMetrics(
            roiMetrics: [:],
            globalRoughnessProxy: 0.5,
            globalPigmentationIndex: 0.5,
            globalDiscolorationIndex: 0.5,
            globalSpecularProxy: specular.map { $0 / 100.0 },
            globalAverageLuminance: 0.5,
            globalRoughnessScore: roughness,
            globalPigmentationScore: pigmentation,
            globalDiscolorationScore: discoloration,
            globalSpecularScore: specular,
            overallScore: (roughness + pigmentation + discoloration) / 3.0,
            scoreInterpretation: "Test",
            vertexCount: 1000,
            triangleCount: 2000,
            textureResolution: CGSize(width: 1024, height: 1024),
            processingTime: 1.0
        )
    }

    // MARK: - Glow vs Radiance Differentiation Tests (NEW)

    func testGlowAndRadiance_AreDifferent() {
        // Verify that glow (health index) and radiance (luminosity) measure different things
        let metrics = createMockMetrics(
            roughness: 80,      // High smoothness
            pigmentation: 50,   // Poor evenness
            discoloration: 60,  // Moderate discoloration
            specular: 90        // High specular (shiny)
        )

        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        // Glow uses 4 factors (smoothness, evenness, discoloration, specular)
        // Radiance should primarily use brightness + specular

        // They should produce different scores because:
        // - Glow considers texture (smoothness) and tone (evenness, discoloration)
        // - Radiance only considers light reflection

        XCTAssertNotEqual(emotional.glowScore, emotional.radiance,
                         "Glow (health index) and radiance (luminosity) should measure different things")
    }

    func testGlowFormula_Uses4Factors() {
        // Glow should use: 40% smoothness + 30% evenness + 20% discoloration + 10% specular
        let metrics = createMockMetrics(
            roughness: 100,     // Perfect smoothness (40 points)
            pigmentation: 100,  // Perfect evenness (30 points)
            discoloration: 100, // Perfect discoloration (20 points)
            specular: 100       // Perfect specular (10 points)
        )

        let emotional = EmotionalMetricsGenerator.generate(from: metrics)

        // Should be ~100 (all factors perfect)
        XCTAssertEqual(emotional.glowScore, 100, "Perfect scores should yield glow score of 100")
    }

    func testRadiance_FocusesOnLuminosity() {
        // Radiance should focus on brightness, not texture
        // Case 1: Bright skin with poor texture
        let brightDullTexture = createMockMetrics(
            roughness: 40,      // Poor smoothness
            pigmentation: 90,   // Great evenness (bright)
            discoloration: 50,  // Poor discoloration
            specular: 90        // High specular (shiny)
        )

        let emotional1 = EmotionalMetricsGenerator.generate(from: brightDullTexture)

        // Radiance should be relatively high (focuses on brightness + specular)
        // Glow should be moderate (considers texture too)
        XCTAssertGreaterThan(emotional1.radiance, emotional1.glowScore,
                            "Bright skin should have higher radiance than glow when texture is poor")
    }

    func testGlow_ConsidersOverallHealth() {
        // Glow should consider all health factors
        // Case: Dull skin but great texture
        let dullGreatTexture = createMockMetrics(
            roughness: 90,      // Great smoothness
            pigmentation: 40,   // Poor evenness (dull)
            discoloration: 90,  // Great discoloration
            specular: 40        // Low specular (matte)
        )

        let emotional2 = EmotionalMetricsGenerator.generate(from: dullGreatTexture)

        // Glow should be moderate (considers texture + tone)
        // Radiance should be low (dull skin)
        XCTAssertGreaterThan(emotional2.glowScore, emotional2.radiance,
                            "Smooth skin should have higher glow than radiance when brightness is low")
    }
}
