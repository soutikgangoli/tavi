//
//  Face3DMetricsTests.swift
//  OllvyTests
//
//  Unit tests for 3D face metrics analyzers
//  Created on 2025-10-27.
//

import XCTest
@testable import Ollvy

class Face3DMetricsTests: XCTestCase {

    // MARK: - Roughness Analyzer Tests

    func testRoughnessAnalyzer_SyntheticHighFrequency() {
        // Create synthetic texture with known high-frequency content
        let analyzer = RoughnessAnalyzer()

        // Generate checkerboard pattern (high frequency)
        let size = 64
        var pixels: [SIMD3<Float>] = []

        for y in 0..<size {
            for x in 0..<size {
                let isWhite = (x + y) % 2 == 0
                let value: Float = isWhite ? 1.0 : 0.0
                pixels.append(SIMD3<Float>(value, value, value))
            }
        }

        let sample = ROITextureSample(
            roi: .forehead,
            pixels: pixels,
            uvCoordinates: [],
            width: size,
            height: size
        )

        let roughness = analyzer.computeRoughnessProxy(sample)

        // Checkerboard should have high roughness
        XCTAssertGreaterThan(roughness, 0.3, "Checkerboard pattern should have high roughness")
    }

    func testRoughnessAnalyzer_SyntheticSmooth() {
        // Create smooth gradient texture
        let analyzer = RoughnessAnalyzer()

        let size = 64
        var pixels: [SIMD3<Float>] = []

        for y in 0..<size {
            for x in 0..<size {
                let value = Float(x) / Float(size)  // Linear gradient
                pixels.append(SIMD3<Float>(value, value, value))
            }
        }

        let sample = ROITextureSample(
            roi: .forehead,
            pixels: pixels,
            uvCoordinates: [],
            width: size,
            height: size
        )

        let roughness = analyzer.computeRoughnessProxy(sample)

        // Smooth gradient should have low roughness
        XCTAssertLessThan(roughness, 0.1, "Smooth gradient should have low roughness")
    }

    // MARK: - Pigmentation Analyzer Tests

    func testPigmentationAnalyzer_ConstantColor() {
        // Constant color should have near-zero pigmentation variance
        let analyzer = PigmentationAnalyzer()

        // Generate constant color texture
        let size = 64
        let constantColor = SIMD3<Float>(0.5, 0.3, 0.2)
        let pixels = [SIMD3<Float>](repeating: constantColor, count: size * size)

        let sample = ROITextureSample(
            roi: .forehead,
            pixels: pixels,
            uvCoordinates: [],
            width: size,
            height: size
        )

        let pigmentation = analyzer.computePigmentationIndex(sample)

        // Constant color should have very low pigmentation index
        XCTAssertLessThan(pigmentation, 0.05, "Constant color should have near-zero pigmentation variance")
    }

    func testPigmentationAnalyzer_VariedColors() {
        // Varied colors should have higher pigmentation variance
        let analyzer = PigmentationAnalyzer()

        let size = 64
        var pixels: [SIMD3<Float>] = []

        for y in 0..<size {
            for x in 0..<size {
                // Create color variation
                let r = Float(x) / Float(size)
                let g = Float(y) / Float(size)
                let b: Float = 0.5
                pixels.append(SIMD3<Float>(r, g, b))
            }
        }

        let sample = ROITextureSample(
            roi: .forehead,
            pixels: pixels,
            uvCoordinates: [],
            width: size,
            height: size
        )

        let pigmentation = analyzer.computePigmentationIndex(sample)

        // Varied colors should have measurable pigmentation
        XCTAssertGreaterThan(pigmentation, 0.05, "Varied colors should have measurable pigmentation variance")
    }

    // MARK: - Discoloration Analyzer Tests

    func testDiscolorationAnalyzer_IdenticalROIs() {
        // Two ROIs with identical LAB means should have zero discoloration
        let analyzer = DiscolorationAnalyzer()

        let labMean1 = DiscolorationAnalyzer.LABMean(roi: .forehead, l: 70.0, a: 10.0, b: 15.0)
        let labMean2 = DiscolorationAnalyzer.LABMean(roi: .leftCheek, l: 70.0, a: 10.0, b: 15.0)

        let roiMeans: [FaceROI: DiscolorationAnalyzer.LABMean] = [
            .forehead: labMean1,
            .leftCheek: labMean2
        ]

        let discoloration = analyzer.computeDiscolorationIndex(roiMeans)

        // Identical ROIs should have zero discoloration
        XCTAssertLessThan(discoloration, 0.01, "Identical ROIs should have near-zero discoloration")
    }

    func testDiscolorationAnalyzer_DifferentROIs() {
        // Two ROIs with different LAB means should have measurable discoloration
        let analyzer = DiscolorationAnalyzer()

        let labMean1 = DiscolorationAnalyzer.LABMean(roi: .forehead, l: 70.0, a: 10.0, b: 15.0)
        let labMean2 = DiscolorationAnalyzer.LABMean(roi: .leftCheek, l: 60.0, a: 15.0, b: 20.0)

        let roiMeans: [FaceROI: DiscolorationAnalyzer.LABMean] = [
            .forehead: labMean1,
            .leftCheek: labMean2
        ]

        let discoloration = analyzer.computeDiscolorationIndex(roiMeans)

        // Different ROIs should have measurable discoloration
        XCTAssertGreaterThan(discoloration, 0.01, "Different ROIs should have measurable discoloration")
    }

    func testDiscolorationAnalyzer_LargerDelta() {
        // Larger delta should produce higher discoloration index
        let analyzer = DiscolorationAnalyzer()

        // Small delta
        let smallDelta: [FaceROI: DiscolorationAnalyzer.LABMean] = [
            .forehead: DiscolorationAnalyzer.LABMean(roi: .forehead, l: 70.0, a: 10.0, b: 15.0),
            .leftCheek: DiscolorationAnalyzer.LABMean(roi: .leftCheek, l: 72.0, a: 11.0, b: 16.0)
        ]

        // Large delta
        let largeDelta: [FaceROI: DiscolorationAnalyzer.LABMean] = [
            .forehead: DiscolorationAnalyzer.LABMean(roi: .forehead, l: 70.0, a: 10.0, b: 15.0),
            .leftCheek: DiscolorationAnalyzer.LABMean(roi: .leftCheek, l: 50.0, a: 20.0, b: 30.0)
        ]

        let smallDiscoloration = analyzer.computeDiscolorationIndex(smallDelta)
        let largeDiscoloration = analyzer.computeDiscolorationIndex(largeDelta)

        XCTAssertLessThan(smallDiscoloration, largeDiscoloration, "Larger delta should produce higher discoloration")
    }

    // MARK: - Scoring Tests (0-100% scale)

    func testScoring_LowRoughnessMapsToHighScore() {
        let scoring = Scoring3D()

        let lowRoughness: Float = 0.05
        let score = scoring.mapRoughnessScore(lowRoughness)

        // Low roughness (smooth) should map to high percentage score
        XCTAssertGreaterThan(score, 80.0, "Low roughness should map to high smoothness percentage (>80%)")
    }

    func testScoring_HighRoughnessMapsToLowScore() {
        let scoring = Scoring3D()

        let highRoughness: Float = 0.40
        let score = scoring.mapRoughnessScore(highRoughness)

        // High roughness should map to low percentage score
        XCTAssertLessThan(score, 30.0, "High roughness should map to low smoothness percentage (<30%)")
    }

    func testScoring_ScoreInterpretation() {
        let scoring = Scoring3D()

        XCTAssertEqual(scoring.interpretScore(95.0), "Excellent")
        XCTAssertEqual(scoring.interpretScore(80.0), "Very Good")
        XCTAssertEqual(scoring.interpretScore(60.0), "Good")
        XCTAssertEqual(scoring.interpretScore(40.0), "Fair")
        XCTAssertEqual(scoring.interpretScore(20.0), "Poor")
        XCTAssertEqual(scoring.interpretScore(5.0), "Very Poor")
    }

    func testScoring_PercentageScoreHelper() {
        let scoring = Scoring3D()

        // Test percentageScore helper function
        XCTAssertEqual(scoring.percentageScore(from: 0.5, low: 0.0, high: 1.0), 50)
        XCTAssertEqual(scoring.percentageScore(from: 0.0, low: 0.0, high: 1.0), 0)
        XCTAssertEqual(scoring.percentageScore(from: 1.0, low: 0.0, high: 1.0), 100)
        XCTAssertEqual(scoring.percentageScore(from: 0.25, low: 0.0, high: 1.0), 25)

        // Test clamping
        XCTAssertEqual(scoring.percentageScore(from: -0.5, low: 0.0, high: 1.0), 0)
        XCTAssertEqual(scoring.percentageScore(from: 1.5, low: 0.0, high: 1.0), 100)
    }

    // MARK: - Texture Quality Validator Tests

    func testTextureQualityValidator_ROIConfidence() {
        let validator = TextureQualityValidator()

        // High pixel count
        let highPixelSample = ROITextureSample(
            roi: .forehead,
            pixels: [SIMD3<Float>](repeating: SIMD3<Float>(0.5, 0.5, 0.5), count: 500),
            uvCoordinates: [],
            width: 50,
            height: 10
        )

        let highConfidence = validator.validateROISample(highPixelSample)
        XCTAssertTrue(highConfidence.isValid, "High pixel count should be valid")

        // Low pixel count
        let lowPixelSample = ROITextureSample(
            roi: .forehead,
            pixels: [SIMD3<Float>](repeating: SIMD3<Float>(0.5, 0.5, 0.5), count: 50),
            uvCoordinates: [],
            width: 10,
            height: 5
        )

        let lowConfidence = validator.validateROISample(lowPixelSample)
        XCTAssertFalse(lowConfidence.isValid, "Low pixel count should be invalid")
    }

    func testTextureQualityValidator_GlobalValidity() {
        let validator = TextureQualityValidator()

        // All valid ROIs
        let allValid: [FaceROI: ROIConfidence] = [
            .forehead: ROIConfidence(roi: .forehead, isValid: true, pixelCount: 500, minimumRequired: 100, confidenceLevel: .high),
            .leftCheek: ROIConfidence(roi: .leftCheek, isValid: true, pixelCount: 500, minimumRequired: 100, confidenceLevel: .high)
        ]

        let validResult = validator.canComputeGlobalMetrics(allValid)
        XCTAssertTrue(validResult.isValid, "All valid ROIs should allow global metrics")

        // Mostly invalid ROIs
        let mostlyInvalid: [FaceROI: ROIConfidence] = [
            .forehead: ROIConfidence(roi: .forehead, isValid: false, pixelCount: 50, minimumRequired: 100, confidenceLevel: .low),
            .leftCheek: ROIConfidence(roi: .leftCheek, isValid: false, pixelCount: 50, minimumRequired: 100, confidenceLevel: .low),
            .rightCheek: ROIConfidence(roi: .rightCheek, isValid: true, pixelCount: 500, minimumRequired: 100, confidenceLevel: .high)
        ]

        let invalidResult = validator.canComputeGlobalMetrics(mostlyInvalid)
        XCTAssertFalse(invalidResult.isValid, "Too many low confidence ROIs should fail global metrics")
    }

    // MARK: - Specular Analyzer Tests

    func testSpecularAnalyzer_MatteSurface() {
        // Matte surface (uniform brightness) should have low specular ratio
        let analyzer = SpecularAnalyzer()

        let size = 64
        let pixels = [SIMD3<Float>](repeating: SIMD3<Float>(0.5, 0.5, 0.5), count: size * size)

        let sample = ROITextureSample(
            roi: .forehead,
            pixels: pixels,
            uvCoordinates: [],
            width: size,
            height: size
        )

        let specular = analyzer.computeSpecularProxy(sample)

        XCTAssertLessThan(specular, 0.1, "Matte surface should have low specular ratio")
    }

    func testSpecularAnalyzer_HighlightedSurface() {
        // Surface with bright spots should have higher specular ratio
        let analyzer = SpecularAnalyzer()

        let size = 64
        var pixels: [SIMD3<Float>] = []

        for y in 0..<size {
            for x in 0..<size {
                // Add some bright spots (simulating highlights)
                if (x % 10 == 0 && y % 10 == 0) {
                    pixels.append(SIMD3<Float>(1.0, 1.0, 1.0))  // Bright
                } else {
                    pixels.append(SIMD3<Float>(0.5, 0.5, 0.5))  // Normal
                }
            }
        }

        let sample = ROITextureSample(
            roi: .forehead,
            pixels: pixels,
            uvCoordinates: [],
            width: size,
            height: size
        )

        let specular = analyzer.computeSpecularProxy(sample)

        XCTAssertGreaterThan(specular, 0.05, "Surface with highlights should have measurable specular ratio")
    }
}
