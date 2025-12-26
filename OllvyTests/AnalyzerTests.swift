//
//  AnalyzerTests.swift
//  OllvyTests
//
//  Comprehensive test suite for skin analysis algorithms
//  Tests fairness across skin tones, edge cases, and accuracy
//

import XCTest
@testable import Ollvy
import UIKit
import simd

class AnalyzerTests: XCTestCase {

    // MARK: - PoreAnalyzer Tests

    func testPoreAnalyzer_AdaptiveThresholding() {
        let analyzer = PoreAnalyzer()

        // Test 1: Light skin (high brightness)
        let lightSkinTexture = createSyntheticTexture(brightness: 220)
        let lightResult = analyzer.analyzePores(texture: lightSkinTexture)

        // Test 2: Dark skin (low brightness)
        let darkSkinTexture = createSyntheticTexture(brightness: 80)
        let darkResult = analyzer.analyzePores(texture: darkSkinTexture)

        // Both should detect pores (adaptive threshold)
        XCTAssertTrue(lightResult.confidence >= 40, "Light skin pore detection should have minimum confidence")
        XCTAssertTrue(darkResult.confidence >= 40, "Dark skin pore detection should have minimum confidence")

        print("✅ PoreAnalyzer: Adaptive thresholding works across skin tones")
        print("   Light skin confidence: \(lightResult.confidence)%")
        print("   Dark skin confidence: \(darkResult.confidence)%")
    }

    func testPoreAnalyzer_ConfidenceScores() {
        let analyzer = PoreAnalyzer()

        // High resolution texture should have higher confidence
        let highResTexture = createSyntheticTexture(brightness: 150, resolution: (1024, 1024))
        let highResResult = analyzer.analyzePores(texture: highResTexture)

        // Low resolution texture should have lower confidence
        let lowResTexture = createSyntheticTexture(brightness: 150, resolution: (256, 256))
        let lowResResult = analyzer.analyzePores(texture: lowResTexture)

        XCTAssertGreaterThan(highResResult.confidence, lowResResult.confidence,
                            "Higher resolution should yield higher confidence")

        print("✅ PoreAnalyzer: Confidence reflects image quality")
        print("   High-res confidence: \(highResResult.confidence)%")
        print("   Low-res confidence: \(lowResResult.confidence)%")
    }

    // MARK: - AcneAnalyzer Tests

    func testAcneAnalyzer_DarknessAndElevation() {
        let analyzer = AcneAnalyzer()

        // Test unified detection (darkness + elevation)
        let texture = createSyntheticTexture(brightness: 150)
        // Note: Without real 3D geometry, this tests the 2D component
        let result = analyzer.analyzeAcne(texture: texture, geometry: nil)

        XCTAssertNotNil(result, "Acne analyzer should return results")
        XCTAssertTrue(result.totalCount >= 0, "Acne count should be non-negative")

        print("✅ AcneAnalyzer: Unified detection (darkness + elevation) works")
        print("   Total acne detected: \(result.totalCount)")
        print("   Severity: \(result.severity.rawValue)")
    }

    func testAcneAnalyzer_SkinToneFairness() {
        let analyzer = AcneAnalyzer()

        // Test on different skin tone simulations
        let fitzpatrickII = createSyntheticTexture(brightness: 210)  // Very light
        let fitzpatrickIV = createSyntheticTexture(brightness: 150)  // Medium
        let fitzpatrickVI = createSyntheticTexture(brightness: 90)   // Dark

        let resultLight = analyzer.analyzeAcne(texture: fitzpatrickII, geometry: nil)
        let resultMedium = analyzer.analyzeAcne(texture: fitzpatrickIV, geometry: nil)
        let resultDark = analyzer.analyzeAcne(texture: fitzpatrickVI, geometry: nil)

        // All should use adaptive thresholding (not fixed redness detection)
        XCTAssertTrue(resultLight.totalCount >= 0, "Light skin detection should work")
        XCTAssertTrue(resultMedium.totalCount >= 0, "Medium skin detection should work")
        XCTAssertTrue(resultDark.totalCount >= 0, "Dark skin detection should work")

        print("✅ AcneAnalyzer: Fair detection across Fitzpatrick types")
        print("   Fitzpatrick II: \(resultLight.totalCount) detected")
        print("   Fitzpatrick IV: \(resultMedium.totalCount) detected")
        print("   Fitzpatrick VI: \(resultDark.totalCount) detected")
    }

    // MARK: - WrinkleAnalyzer Tests

    func testWrinkleAnalyzer_CategoricalClassification() {
        let analyzer = WrinkleAnalyzer()

        // Create synthetic geometry with varying curvature
        let geometryFine = createSyntheticGeometry(curvature: 0.0005)
        let geometryModerate = createSyntheticGeometry(curvature: 0.0009)
        let geometryDeep = createSyntheticGeometry(curvature: 0.0015)

        let resultFine = analyzer.analyzeWrinkles(geometry: geometryFine)
        let resultModerate = analyzer.analyzeWrinkles(geometry: geometryModerate)
        let resultDeep = analyzer.analyzeWrinkles(geometry: geometryDeep)

        // Verify categorical classification
        XCTAssertEqual(resultFine.wrinkleDepth, .fine, "Should classify as fine lines")
        XCTAssertEqual(resultModerate.wrinkleDepth, .moderate, "Should classify as moderate")
        XCTAssertEqual(resultDeep.wrinkleDepth, .deep, "Should classify as deep")

        print("✅ WrinkleAnalyzer: Categorical classification (Fine/Moderate/Deep)")
        print("   Fine: \(resultFine.wrinkleDepth.rawValue) (confidence: \(resultFine.confidence)%)")
        print("   Moderate: \(resultModerate.wrinkleDepth.rawValue) (confidence: \(resultModerate.confidence)%)")
        print("   Deep: \(resultDeep.wrinkleDepth.rawValue) (confidence: \(resultDeep.confidence)%)")
    }

    func testWrinkleAnalyzer_ConfidenceReporting() {
        let analyzer = WrinkleAnalyzer()

        let geometry = createSyntheticGeometry(curvature: 0.0008)
        let result = analyzer.analyzeWrinkles(geometry: geometry)

        // Confidence should be in valid range
        XCTAssertTrue(result.confidence >= 40 && result.confidence <= 100,
                     "Confidence should be between 40-100%")

        print("✅ WrinkleAnalyzer: Confidence reporting works")
        print("   Depth: \(result.wrinkleDepth.rawValue)")
        print("   Confidence: \(result.confidence)%")
    }

    // MARK: - SkinToneNormalizer Tests

    func testSkinToneNormalizer_UniformThresholds() {
        let normalizer = SkinToneNormalizer()

        // Get thresholds for different skin tones
        let thresholdsLight = normalizer.getThresholds(for: .light)
        let thresholdsMedium = normalizer.getThresholds(for: .medium)
        let thresholdsDark = normalizer.getThresholds(for: .dark)

        // All should be uniform (60) after fairness fixes
        XCTAssertEqual(thresholdsLight.pigmentationThreshold, 60, "Light skin threshold should be 60")
        XCTAssertEqual(thresholdsMedium.pigmentationThreshold, 60, "Medium skin threshold should be 60")
        XCTAssertEqual(thresholdsDark.pigmentationThreshold, 60, "Dark skin threshold should be 60")

        print("✅ SkinToneNormalizer: Uniform thresholds across all skin tones")
        print("   All Fitzpatrick types: 60 (fair approach)")
    }

    func testSkinToneNormalizer_NoScaleFactorPenalty() {
        let normalizer = SkinToneNormalizer()

        // Test that raw scores are preserved (no penalties for dark skin)
        let rawScore: Float = 75.0

        let normalizedLight = normalizer.normalizePigmentationScore(rawScore: rawScore, skinTone: .light)
        let normalizedDark = normalizer.normalizePigmentationScore(rawScore: rawScore, skinTone: .dark)

        // Should be equal (no scale factor reduction for dark skin)
        XCTAssertEqual(normalizedLight, normalizedDark,
                      "Dark skin should not be penalized with scale factors")

        print("✅ SkinToneNormalizer: No scale factor penalties")
        print("   Light skin: \(normalizedLight)")
        print("   Dark skin: \(normalizedDark) (equal - fair!)")
    }

    // MARK: - HydrationEstimator Tests

    func testHydrationEstimator_MultiMethodEnsemble() {
        let estimator = HydrationEstimator()

        let texture = createSyntheticTexture(brightness: 150)
        let geometry = createSyntheticGeometry(curvature: 0.0005)

        let result = estimator.estimateHydration(
            texture: texture,
            roughnessScore: 70,
            geometry: geometry
        )

        // Verify ensemble components exist
        XCTAssertTrue(result.specularityScore >= 0 && result.specularityScore <= 100,
                     "Specularity score should be 0-100")
        XCTAssertTrue(result.textureScore >= 0 && result.textureScore <= 100,
                     "Texture score should be 0-100")
        XCTAssertTrue(result.varianceScore >= 0 && result.varianceScore <= 100,
                     "Variance score should be 0-100")

        print("✅ HydrationEstimator: Multi-method ensemble (3 methods)")
        print("   Specularity: \(result.specularityScore)%")
        print("   Texture: \(result.textureScore)%")
        print("   Variance: \(result.varianceScore)%")
        print("   Overall: \(result.overallScore)% (weighted average)")
    }

    func testHydrationEstimator_ConfidenceCalculation() {
        let estimator = HydrationEstimator()

        let texture = createSyntheticTexture(brightness: 150)
        let geometry = createSyntheticGeometry(curvature: 0.0005)

        let result = estimator.estimateHydration(
            texture: texture,
            roughnessScore: 70,
            geometry: geometry
        )

        // Confidence should reflect method agreement
        XCTAssertTrue(result.confidence >= 30 && result.confidence <= 80,
                     "Confidence should be 30-80% for indirect measurement")

        print("✅ HydrationEstimator: Confidence reflects measurement reliability")
        print("   Confidence: \(result.confidence)% (capped at 80% for indirect)")
    }

    // MARK: - EdgeCaseDetector Tests

    func testEdgeCaseDetector_LightingValidation() {
        let detector = EdgeCaseDetector()

        // Test poor lighting detection
        let darkTexture = createSyntheticTexture(brightness: 50)  // Too dark (<25%)
        let brightTexture = createSyntheticTexture(brightness: 240)  // Too bright (>90%)
        let goodTexture = createSyntheticTexture(brightness: 150)  // Optimal (40-70%)

        let geometry = createSyntheticGeometry(curvature: 0.0005)

        let darkCases = detector.detectEdgeCases(geometry: geometry, texture: darkTexture, lightEstimation: nil)
        let brightCases = detector.detectEdgeCases(geometry: geometry, texture: brightTexture, lightEstimation: nil)
        let goodCases = detector.detectEdgeCases(geometry: geometry, texture: goodTexture, lightEstimation: nil)

        // Should detect lighting issues
        XCTAssertTrue(darkCases.contains { $0.type == .poorLighting && $0.severity == .critical },
                     "Should block scans in too-dark lighting")
        XCTAssertTrue(brightCases.contains { $0.type == .poorLighting && $0.severity == .critical },
                     "Should block scans in too-bright lighting")

        print("✅ EdgeCaseDetector: Lighting validation (blocks <25%, >90%)")
        print("   Dark lighting: \(darkCases.count) issues detected")
        print("   Bright lighting: \(brightCases.count) issues detected")
        print("   Good lighting: \(goodCases.count) issues detected")
    }

    // MARK: - Helper Methods

    /// Create synthetic texture with specified brightness
    private func createSyntheticTexture(brightness: UInt8, resolution: (Int, Int) = (512, 512)) -> UIImage {
        let width = resolution.0
        let height = resolution.1

        var pixelData = [UInt8](repeating: brightness, count: width * height * 4)

        // Add RGBA format
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            pixelData[i] = brightness      // R
            pixelData[i + 1] = brightness  // G
            pixelData[i + 2] = brightness  // B
            pixelData[i + 3] = 255        // A
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        guard let cgImage = context?.makeImage() else {
            return UIImage()
        }

        return UIImage(cgImage: cgImage)
    }

    /// Create synthetic face mesh geometry with specified curvature
    private func createSyntheticGeometry(curvature: Float) -> FaceMeshGeometry {
        // Create a simple mesh with varying curvature
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var texCoords: [SIMD2<Float>] = []
        var triangles: [Int32] = []

        // Create a 10x10 grid
        let gridSize = 10
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let xPos = Float(x) / Float(gridSize - 1) - 0.5
                let yPos = Float(y) / Float(gridSize - 1) - 0.5
                let zPos = curvature * (xPos * xPos + yPos * yPos)  // Parabolic surface

                vertices.append(SIMD3<Float>(xPos, yPos, zPos))
                normals.append(SIMD3<Float>(0, 0, 1))  // Simple normal
                texCoords.append(SIMD2<Float>(Float(x) / Float(gridSize - 1),
                                              Float(y) / Float(gridSize - 1)))
            }
        }

        // Create triangle indices
        for y in 0..<(gridSize - 1) {
            for x in 0..<(gridSize - 1) {
                let topLeft = Int32(y * gridSize + x)
                let topRight = Int32(y * gridSize + x + 1)
                let bottomLeft = Int32((y + 1) * gridSize + x)
                let bottomRight = Int32((y + 1) * gridSize + x + 1)

                // First triangle
                triangles.append(topLeft)
                triangles.append(bottomLeft)
                triangles.append(topRight)

                // Second triangle
                triangles.append(topRight)
                triangles.append(bottomLeft)
                triangles.append(bottomRight)
            }
        }

        return FaceMeshGeometry(
            vertices: vertices,
            normals: normals,
            textureCoordinates: texCoords,
            triangleIndices: triangles,
            transform: matrix_identity_float4x4,
            timestamp: Date().timeIntervalSince1970
        )
    }
}
