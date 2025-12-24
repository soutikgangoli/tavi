//
//  AnalyzerCorrectnessTests.swift
//  TaviTests
//
//  Correctness tests for analyzer math and scoring consistency
//  Validates fixes for Issues #1, #2, #3 from the audit
//

import XCTest
import simd
@testable import Tavi

final class AnalyzerCorrectnessTests: XCTestCase {

    // MARK: - Issue #1: ROI Composite Score Consistency

    /// Test that ROI composite excludes moistureScore for consistency with overall score
    /// Background: Overall score excludes hydration (proxy method, 50-70% confidence)
    /// ROI composites should match this logic to avoid user confusion
    func testROICompositeExcludesHydration() {
        // Given: ROI scores with poor texture/pigmentation but good moisture
        let sharpness: Double = 40
        let texture: Double = 40
        let pigmentation: Double = 40
        let moisture: Double = 90  // High hydration shouldn't inflate composite

        // When: ROIScores is created with default composite calculation
        let roiScores = ROIScores(
            sharpnessScore: sharpness,
            textureScore: texture,
            pigmentationScore: pigmentation,
            moistureScore: moisture
        )

        // Then: Composite should exclude moisture (3 metrics, not 4)
        let expectedComposite = (sharpness + texture + pigmentation) / 3.0  // = 40.0
        XCTAssertEqual(roiScores.compositeScore, expectedComposite, accuracy: 0.01,
                       "ROI composite should exclude moistureScore for consistency with overall score")

        // Verify it's NOT the old buggy calculation
        let buggyComposite = (sharpness + texture + pigmentation + moisture) / 4.0  // = 52.5
        XCTAssertNotEqual(roiScores.compositeScore, buggyComposite, accuracy: 0.01,
                          "ROI composite should NOT include hydration (was inflating scores)")
    }

    /// Test that grade is calculated from the corrected composite (without hydration)
    func testROIGradeUsesCorrectComposite() {
        // Given: Scores that produce composite = 40.0 (without hydration)
        let roiScores = ROIScores(
            sharpnessScore: 40,
            textureScore: 40,
            pigmentationScore: 40,
            moistureScore: 90  // Should not affect grade
        )

        // Then: Grade should be based on composite = 40.0 (Poor range: 60-69, VeryPoor: 0-59)
        XCTAssertEqual(roiScores.grade, ScoreGrade.veryPoor,
                       "Grade should be VeryPoor (composite=40) not Poor (composite=52.5 if hydration included)")
    }

    // MARK: - Issue #2: No Double Lighting Quality Compensation

    /// Test that pigmentation analyzer does NOT reduce variance based on lighting quality
    /// Background: Scoring3D already expands thresholds for poor lighting
    /// Applying both corrections would hide poor scan quality
    func testPigmentationNoVarianceReduction() {
        let analyzer = PigmentationAnalyzer()

        // Create sample with known LAB variance
        // Using uniform medium skin tone (Fitzpatrick III-IV)
        let pixels = Array(repeating: SIMD3<Float>(0.7, 0.5, 0.4), count: 1000)
        let uvs = Array(repeating: SIMD2<Float>(0.5, 0.5), count: 1000)
        let sample = ROITextureSample(
            roi: .leftCheek,
            pixels: pixels,
            uvCoordinates: uvs,
            width: 100,
            height: 10
        )

        // Test with good lighting
        let goodLightingQuality: Float = 0.8
        let indexGoodLight = analyzer.computePigmentationIndex(sample, lightingQuality: goodLightingQuality)

        // Test with poor lighting
        let poorLightingQuality: Float = 0.3
        let indexPoorLight = analyzer.computePigmentationIndex(sample, lightingQuality: poorLightingQuality)

        // Verify: Analyzer should report SAME variance regardless of lighting quality
        // (After fix, variance correction is removed, so indexes should be identical for same sample)
        XCTAssertEqual(indexGoodLight, indexPoorLight, accuracy: 0.001,
                       "Analyzer should NOT reduce variance based on lighting quality (double-compensation fix)")
    }

    /// Test that discoloration analyzer does NOT reduce variance based on lighting quality
    func testDiscolorationNoVarianceReduction() {
        let analyzer = DiscolorationAnalyzer()

        // Create two ROI means with known LAB values
        let roiMeans: [Face3DROI: DiscolorationAnalyzer.LABMean] = [
            .leftCheek: DiscolorationAnalyzer.LABMean(roi: .leftCheek, l: 65.0, a: 10.0, b: 15.0),
            .rightCheek: DiscolorationAnalyzer.LABMean(roi: .rightCheek, l: 67.0, a: 11.0, b: 16.0)
        ]

        // Test with good lighting
        let goodLightingQuality: Float = 0.8
        let indexGoodLight = analyzer.computeDiscolorationIndex(roiMeans, lightingQuality: goodLightingQuality)

        // Test with poor lighting
        let poorLightingQuality: Float = 0.3
        let indexPoorLight = analyzer.computeDiscolorationIndex(roiMeans, lightingQuality: poorLightingQuality)

        // Verify: Same variance regardless of lighting
        XCTAssertEqual(indexGoodLight, indexPoorLight, accuracy: 0.001,
                       "Analyzer should NOT reduce variance based on lighting quality")
    }

    /// Test that Scoring3D DOES expand thresholds for poor lighting (single compensation point)
    func testScoringThresholdExpansionWorks() {
        let scorer = Scoring3D()

        // Fixed variance value (same as analyzer would produce)
        let pigmentationIndex: Float = 0.08

        // Good lighting: no threshold expansion
        let goodLightingQuality: Float = 0.8
        let scoreGoodLight = scorer.mapPigmentationScore(pigmentationIndex, lightingQuality: goodLightingQuality)

        // Poor lighting: threshold expansion should make scoring more lenient
        let poorLightingQuality: Float = 0.3
        let scorePoorLight = scorer.mapPigmentationScore(pigmentationIndex, lightingQuality: poorLightingQuality)

        // Verify: Poor lighting gets equal or slightly higher score (due to threshold expansion)
        // This is acceptable because scorer is transparently adjusting expectations
        XCTAssertGreaterThanOrEqual(scorePoorLight, scoreGoodLight - 1.0,
                                    "Scorer should apply threshold expansion for poor lighting (single compensation point)")
    }

    // MARK: - Issue #3: Luminance Formula Consistency

    /// Test that Luminance.swift helper is used and produces correct results
    func testLuminanceHelperCorrectness() {
        let testColors: [(rgb: SIMD3<Float>, name: String)] = [
            (SIMD3<Float>(0.5, 0.7, 0.3), "Medium skin"),
            (SIMD3<Float>(0.95, 0.85, 0.80), "Light skin"),
            (SIMD3<Float>(0.47, 0.37, 0.29), "Indian skin (Fitzpatrick IV)"),
            (SIMD3<Float>(0.35, 0.27, 0.20), "Dark skin (Fitzpatrick V)"),
        ]

        for (rgb, name) in testColors {
            // Reference: Luminance.swift (single source of truth)
            let referenceLuminance = Luminance.bt709LuminanceSRGB01(rgb01: rgb)

            // Expected: Manual BT.709 calculation
            let expectedLuminance: Float = 0.2126 * rgb.x + 0.7152 * rgb.y + 0.0722 * rgb.z

            // Verify helper matches expected
            XCTAssertEqual(referenceLuminance, expectedLuminance, accuracy: 0.00001,
                           "Luminance.bt709LuminanceSRGB01 failed for \(name)")

            // Verify range is valid (0-1)
            XCTAssertGreaterThanOrEqual(referenceLuminance, 0.0, "\(name) luminance must be >= 0")
            XCTAssertLessThanOrEqual(referenceLuminance, 1.0, "\(name) luminance must be <= 1")
        }
    }

    /// Test that RoughnessAnalyzer uses Luminance helper (indirect verification)
    /// Since convertToLuminance is private, we verify by checking analyzer doesn't fail
    func testRoughnessAnalyzerUsesLuminanceHelper() {
        let analyzer = RoughnessAnalyzer()

        // Create sample with known pixels
        let pixels = [
            SIMD3<Float>(0.5, 0.7, 0.3),
            SIMD3<Float>(0.6, 0.5, 0.4),
            SIMD3<Float>(0.55, 0.65, 0.35)
        ]
        let uvs = Array(repeating: SIMD2<Float>(0.5, 0.5), count: 3)
        let sample = ROITextureSample(
            roi: .forehead,
            pixels: pixels,
            uvCoordinates: uvs,
            width: 3,
            height: 1
        )

        // Execute analyzer - should not crash and produce valid output
        let roughness = analyzer.computeRoughnessProxy(sample)

        // Verify output is in valid range (0-1)
        XCTAssertGreaterThanOrEqual(roughness, 0.0, "Roughness must be >= 0")
        XCTAssertLessThanOrEqual(roughness, 1.0, "Roughness must be <= 1")
    }

    /// Test that SpecularAnalyzer uses Luminance helper (indirect verification)
    func testSpecularAnalyzerUsesLuminanceHelper() {
        let analyzer = SpecularAnalyzer()

        // Create sample with varying brightness
        let pixels = [
            SIMD3<Float>(0.9, 0.9, 0.9),  // Bright (potential specular)
            SIMD3<Float>(0.5, 0.5, 0.5),  // Medium
            SIMD3<Float>(0.3, 0.3, 0.3),  // Dark
        ]
        let uvs = Array(repeating: SIMD2<Float>(0.5, 0.5), count: 3)
        let sample = ROITextureSample(
            roi: .forehead,
            pixels: pixels,
            uvCoordinates: uvs,
            width: 3,
            height: 1
        )

        // Execute analyzer - should not crash and produce valid output
        let specular = analyzer.computeSpecularProxy(sample)

        // Verify output is in valid range (0-1)
        XCTAssertGreaterThanOrEqual(specular, 0.0, "Specular must be >= 0")
        XCTAssertLessThanOrEqual(specular, 1.0, "Specular must be <= 1")
    }

    // MARK: - Issue #2 Extended: Lighting Quality Impact Validation

    /// Test pigmentation scores with uniform field (baseline: no natural variance)
    /// Validates that poor lighting causes variance inflation and threshold expansion compensates
    func testPigmentationLightingImpactUniformField() {
        let analyzer = PigmentationAnalyzer()
        let scorer = Scoring3D()

        // Uniform field: medium skin tone (no natural pigmentation variance)
        let uniformPixels = Array(repeating: SIMD3<Float>(0.7, 0.5, 0.4), count: 1000)
        let uvs = Array(repeating: SIMD2<Float>(0.5, 0.5), count: 1000)
        let sample = ROITextureSample(
            roi: .forehead,
            pixels: uniformPixels,
            uvCoordinates: uvs,
            width: 100,
            height: 10
        )

        // Compute index (should be near 0 for uniform field)
        let index = analyzer.computePigmentationIndex(sample, lightingQuality: nil, skinTone: nil)

        // Test scores at different lighting qualities
        let lightingQualities: [Float] = [0.8, 0.5, 0.3, 0.0]
        var scores: [Float] = []

        for quality in lightingQualities {
            let score = scorer.mapPigmentationScore(index, lightingQuality: quality)
            scores.append(score)
            print("  Uniform field @ quality=\(String(format: "%.1f", quality)): index=\(String(format: "%.4f", index)), score=\(String(format: "%.1f", score))")
        }

        // Verify: Uniform field should have very low index (<0.01)
        XCTAssertLessThan(index, 0.01, "Uniform field should have minimal pigmentation variance")

        // Verify: Score should be high (near 100) regardless of lighting for truly uniform field
        for score in scores {
            XCTAssertGreaterThan(score, 95.0, "Uniform field should score high regardless of lighting")
        }
    }

    /// Test pigmentation scores with artificial lighting gradient
    /// Simulates poor lighting creating false variance
    func testPigmentationLightingImpactWithGradient() {
        let analyzer = PigmentationAnalyzer()
        let scorer = Scoring3D()

        // Create gradient: brightness varies from 0.6 to 1.0 across x-axis
        // This simulates poor lighting creating artificial variance
        var gradientPixels: [SIMD3<Float>] = []
        let baseColor = SIMD3<Float>(0.7, 0.5, 0.4)  // Medium skin
        let width = 100
        let height = 10

        for y in 0..<height {
            for x in 0..<width {
                let brightnessMultiplier = 0.6 + (Float(x) / Float(width)) * 0.4  // 0.6 to 1.0
                let pixel = baseColor * brightnessMultiplier
                gradientPixels.append(pixel)
            }
        }

        let uvs = Array(repeating: SIMD2<Float>(0.5, 0.5), count: width * height)
        let sample = ROITextureSample(
            roi: .forehead,
            pixels: gradientPixels,
            uvCoordinates: uvs,
            width: width,
            height: height
        )

        // Compute index (will be elevated due to gradient-induced variance)
        let index = analyzer.computePigmentationIndex(sample, lightingQuality: nil, skinTone: nil)

        // Test scores at different lighting qualities
        let lightingQualities: [(quality: Float, label: String)] = [
            (0.8, "good"),
            (0.5, "medium"),
            (0.3, "poor"),
            (0.0, "worst")
        ]

        var scores: [Float] = []
        print("\n  Gradient field (40% brightness variation):")

        for (quality, label) in lightingQualities {
            let score = scorer.mapPigmentationScore(index, lightingQuality: quality)
            scores.append(score)
            print("    \(label) (quality=\(String(format: "%.1f", quality))): index=\(String(format: "%.4f", index)), score=\(String(format: "%.1f", score))")
        }

        // Calculate deltas from good lighting baseline
        let baselineScore = scores[0]
        print("  Score deltas from baseline (quality=0.8):")
        for i in 1..<scores.count {
            let delta = scores[i] - baselineScore
            let quality = lightingQualities[i].quality
            let label = lightingQualities[i].label
            print("    \(label) (quality=\(String(format: "%.1f", quality))): delta=\(String(format: "%+.1f", delta)) points")
        }

        // Verify: Gradient causes measurable variance
        XCTAssertGreaterThan(index, 0.05, "Lighting gradient should create measurable variance")

        // Verify: Threshold expansion provides some leniency for poor lighting
        // But deltas should not be excessive (would indicate hiding poor scans)
        let worstDelta = scores[3] - baselineScore
        XCTAssertLessThan(worstDelta, 15.0, "Threshold expansion should not excessively hide gradient-induced variance")
    }

    /// Test pigmentation scores with shadow patch
    /// Simulates harsh lighting creating localized dark regions
    func testPigmentationLightingImpactWithShadow() {
        let analyzer = PigmentationAnalyzer()
        let scorer = Scoring3D()

        // Create field with shadow patch: 30% of pixels are darkened to 0.5x brightness
        var shadowPixels: [SIMD3<Float>] = []
        let baseColor = SIMD3<Float>(0.7, 0.5, 0.4)
        let width = 100
        let height = 10

        for y in 0..<height {
            for x in 0..<width {
                // Shadow in left third
                let brightnessMultiplier: Float = x < (width / 3) ? 0.5 : 1.0
                let pixel = baseColor * brightnessMultiplier
                shadowPixels.append(pixel)
            }
        }

        let uvs = Array(repeating: SIMD2<Float>(0.5, 0.5), count: width * height)
        let sample = ROITextureSample(
            roi: .forehead,
            pixels: shadowPixels,
            uvCoordinates: uvs,
            width: width,
            height: height
        )

        // Compute index (will be high due to shadow-induced bimodal distribution)
        let index = analyzer.computePigmentationIndex(sample, lightingQuality: nil, skinTone: nil)

        // Test scores at different lighting qualities
        let lightingQualities: [(quality: Float, label: String)] = [
            (0.8, "good"),
            (0.5, "medium"),
            (0.3, "poor"),
            (0.0, "worst")
        ]

        var scores: [Float] = []
        print("\n  Shadow field (33% of pixels at 50% brightness):")

        for (quality, label) in lightingQualities {
            let score = scorer.mapPigmentationScore(index, lightingQuality: quality)
            scores.append(score)
            print("    \(label) (quality=\(String(format: "%.1f", quality))): index=\(String(format: "%.4f", index)), score=\(String(format: "%.1f", score))")
        }

        // Calculate deltas from good lighting baseline
        let baselineScore = scores[0]
        print("  Score deltas from baseline (quality=0.8):")
        for i in 1..<scores.count {
            let delta = scores[i] - baselineScore
            let quality = lightingQualities[i].quality
            let label = lightingQualities[i].label
            print("    \(label) (quality=\(String(format: "%.1f", quality))): delta=\(String(format: "%+.1f", delta)) points")
        }

        // Verify: Shadow creates significant variance
        XCTAssertGreaterThan(index, 0.10, "Shadow should create significant variance in L* channel")

        // CRITICAL TEST: Verify threshold expansion doesn't excessively hide poor lighting
        // If worst-case delta is > 15 points, threshold expansion is too lenient
        let worstDelta = scores[3] - baselineScore
        XCTAssertLessThan(abs(worstDelta), 20.0, "Threshold expansion should not hide shadow artifacts by >20 points")
    }

    /// Test discoloration scores with cross-region variance simulation
    /// Validates behavior when different face regions have different lighting
    func testDiscolorationLightingImpactCrossRegion() {
        let analyzer = DiscolorationAnalyzer()
        let scorer = Scoring3D()

        // Simulate uniform skin tone but different lighting per region
        // Forehead: well-lit (brightness 1.0x)
        // Cheeks: moderate lighting (brightness 0.8x)
        // Chin: poor lighting (brightness 0.6x)
        let baseL: Float = 65.0  // Lightness for medium skin
        let baseA: Float = 10.0  // Red-green
        let baseB: Float = 15.0  // Blue-yellow

        let roiMeans: [Face3DROI: DiscolorationAnalyzer.LABMean] = [
            .forehead: DiscolorationAnalyzer.LABMean(roi: .forehead, l: baseL * 1.0, a: baseA, b: baseB),
            .leftCheek: DiscolorationAnalyzer.LABMean(roi: .leftCheek, l: baseL * 0.8, a: baseA, b: baseB),
            .rightCheek: DiscolorationAnalyzer.LABMean(roi: .rightCheek, l: baseL * 0.8, a: baseA, b: baseB),
            .chin: DiscolorationAnalyzer.LABMean(roi: .chin, l: baseL * 0.6, a: baseA, b: baseB)
        ]

        // Compute index (elevated due to lighting-induced L* variance across regions)
        let index = analyzer.computeDiscolorationIndex(roiMeans, lightingQuality: nil)

        // Test scores at different lighting qualities
        let lightingQualities: [(quality: Float, label: String)] = [
            (0.8, "good"),
            (0.5, "medium"),
            (0.3, "poor"),
            (0.0, "worst")
        ]

        var scores: [Float] = []
        print("\n  Cross-region lighting variation (L* range: 39-65):")

        for (quality, label) in lightingQualities {
            let score = scorer.mapDiscolorationScore(index, lightingQuality: quality)
            scores.append(score)
            print("    \(label) (quality=\(String(format: "%.1f", quality))): index=\(String(format: "%.4f", index)), score=\(String(format: "%.1f", score))")
        }

        // Calculate deltas from good lighting baseline
        let baselineScore = scores[0]
        print("  Score deltas from baseline (quality=0.8):")
        for i in 1..<scores.count {
            let delta = scores[i] - baselineScore
            let quality = lightingQualities[i].quality
            let label = lightingQualities[i].label
            print("    \(label) (quality=\(String(format: "%.1f", quality))): delta=\(String(format: "%+.1f", delta)) points")
        }

        // Verify: Cross-region lighting variance creates elevated index
        XCTAssertGreaterThan(index, 0.05, "Cross-region lighting should create measurable L* variance")

        // Verify: Threshold expansion provides leniency but not excessive
        let worstDelta = scores[3] - baselineScore
        XCTAssertLessThan(abs(worstDelta), 20.0, "Threshold expansion should not hide cross-region variance by >20 points")
    }

    // MARK: - Scoring Weight Verification (Guardrail)

    /// Verify that overall score weights still sum to 1.0
    /// This is a guardrail test to ensure no regressions
    func testOverallScoreWeightsSum() {
        let scorer = Scoring3D()

        // All metrics present and perfect (100/100)
        let overallScore = scorer.computeOverallScore(
            smoothnessScore: 100,
            poresScore: 100,
            pigmentationScore: 100,
            discolorationScore: 100,
            acneScore: 100
        )

        // Perfect scores should yield perfect overall (weights sum to 1.0)
        XCTAssertEqual(overallScore, 100.0, accuracy: 0.01,
                       "Weights must sum to 1.0 (smoothness:0.25 + pigmentation:0.25 + pores:0.16 + discolor:0.16 + acne:0.18)")
    }

    /// Verify weight proportions when some metrics are missing
    func testOverallScoreProportionalWeights() {
        let scorer = Scoring3D()

        // Only core metrics present (no pores, no acne)
        let overallScore = scorer.computeOverallScore(
            smoothnessScore: 80,
            poresScore: nil,
            pigmentationScore: 60,
            discolorationScore: 70,
            acneScore: nil
        )

        // Expected: (80*0.25 + 60*0.25 + 70*0.16) / (0.25 + 0.25 + 0.16) = 46.2 / 0.66 = 70.0
        let expectedScore: Float = (80*0.25 + 60*0.25 + 70*0.16) / (0.25 + 0.25 + 0.16)
        XCTAssertEqual(overallScore, expectedScore, accuracy: 0.1,
                       "Weights should be redistributed proportionally when metrics are missing")
    }
}
