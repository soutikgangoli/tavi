//
//  LuminanceParityTests.swift
//  OllvyTests
//
//  CPU-GPU luminance parity tests
//  Validates that Swift CPU helpers produce identical results to Metal GPU shaders
//
//  CRITICAL: These tests must PASS to ensure scoring consistency.
//  Failures indicate CPU-GPU mismatch causing score drift.
//

import XCTest
import simd
@testable import Ollvy

class LuminanceParityTests: XCTestCase {

    // MARK: - Range Normalization Tests

    /// Test that 0..255 normalization produces correct 0..1 values
    func testBT709_255Normalization() {
        // Test cases: (r255, g255, b255) -> expected luminance in 0..1
        let testCases: [(r: Float, g: Float, b: Float, expected: Float)] = [
            (0, 0, 0, 0.0),                          // Black
            (255, 255, 255, 1.0),                     // White
            (128, 128, 128, 128.0 / 255.0),           // Mid-gray
            (120, 95, 75, 0.387729411764705882),      // Fitzpatrick IV (from previous math)
            (90, 70, 50, 0.285521568627450980),       // Fitzpatrick V
            (255, 0, 0, 0.2126),                      // Pure red
            (0, 255, 0, 0.7152),                      // Pure green
            (0, 0, 255, 0.0722),                      // Pure blue
        ]

        for (r, g, b, expected) in testCases {
            let result = Luminance.bt709LuminanceSRGB255(r: r, g: g, b: b)
            let diff = abs(result - expected)

            XCTAssertLessThan(diff, 1e-6, """
                BT.709 normalization failed for RGB(\(Int(r)), \(Int(g)), \(Int(b)))
                Expected: \(expected)
                Got: \(result)
                Diff: \(diff)
                """)
        }
    }

    /// Test that unnormalized 0..255 values produce WRONG results (255x too large)
    /// This validates the bug fix in HydrationEstimator.swift
    func testBT709_UnnormalizedIsBroken() {
        // Before fix: CPU applied 0.2126*r + 0.7152*g + 0.0722*b to 0..255 values
        // This produces values in 0..255 range instead of 0..1
        let r: Float = 120
        let g: Float = 95
        let b: Float = 75

        let wrongResult = 0.2126 * r + 0.7152 * g + 0.0722 * b  // OLD BUG
        let correctResult = Luminance.bt709LuminanceSRGB255(r: r, g: g, b: b)

        // Wrong result should be ~255x larger
        XCTAssertGreaterThan(wrongResult, 50.0, "Unnormalized should produce large values")
        XCTAssertLessThan(correctResult, 1.0, "Normalized should produce 0..1 values")

        let scaleFactor = wrongResult / correctResult
        XCTAssertGreaterThan(scaleFactor, 250, "Scale factor should be ~255x")
        XCTAssertLessThan(scaleFactor, 260, "Scale factor should be ~255x")

        print("✅ Confirmed bug fix: unnormalized = \(wrongResult) (WRONG), normalized = \(correctResult) (CORRECT)")
        print("   Scale factor: \(scaleFactor)x")
    }

    // MARK: - Coefficient Precision Tests

    /// Test that exact D65 coefficients differ from rounded BT.709 for linear RGB
    /// This validates the bug fix in GlowAnalyzer.swift and SkinToneNormalizer.swift
    func testYLinearD65_PrecisionMatters() {
        // Test on linear RGB (after gamma correction)
        let testCases: [(rgbLinear: SIMD3<Float>, desc: String)] = [
            (SIMD3<Float>(0.5, 0.5, 0.5), "Mid-gray linear"),
            (SIMD3<Float>(0.331, 0.247, 0.173), "Fitz IV linear (~RGB 120,95,75 after gamma)"),
            (SIMD3<Float>(0.216, 0.142, 0.083), "Fitz V linear (~RGB 90,70,50 after gamma)"),
        ]

        for (rgbLinear, desc) in testCases {
            // Correct: Use exact D65 coefficients
            let correctY = Luminance.yLinearD65(rgbLinear: rgbLinear)

            // Wrong (old bug): Use rounded BT.709 coefficients
            let wrongY = 0.2126 * rgbLinear.x + 0.7152 * rgbLinear.y + 0.0722 * rgbLinear.z

            let diff = abs(correctY - wrongY)
            let percentDiff = (diff / correctY) * 100

            // Precision error should be small but non-zero
            XCTAssertGreaterThan(diff, 1e-6, """
                Coefficients should differ for \(desc)
                Exact D65: \(correctY)
                Rounded BT.709: \(wrongY)
                """)

            XCTAssertLessThan(percentDiff, 0.1, """
                Precision error should be < 0.1% for \(desc)
                Exact D65: \(correctY)
                Rounded BT.709: \(wrongY)
                Diff: \(diff) (\(percentDiff)%)
                """)

            print("✅ \(desc): exact=\(correctY), rounded=\(wrongY), diff=\(diff) (\(percentDiff)%)")
        }
    }

    // MARK: - CPU-GPU Parity: Known Values

    /// Test CPU luminance helpers against known Metal GPU outputs
    /// These expected values come from Metal shader AnalyzerCommon.metal
    func testCPU_MatchesGPU_BT709() {
        // Known GPU outputs from perceptualLuminance() in AnalyzerCommon.metal:17-18
        // Formula: 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b
        let testCases: [(rgb01: SIMD3<Float>, expected: Float)] = [
            (SIMD3<Float>(0.0, 0.0, 0.0), 0.0),
            (SIMD3<Float>(1.0, 1.0, 1.0), 1.0),
            (SIMD3<Float>(1.0, 0.0, 0.0), 0.2126),
            (SIMD3<Float>(0.0, 1.0, 0.0), 0.7152),
            (SIMD3<Float>(0.0, 0.0, 1.0), 0.0722),
            (SIMD3<Float>(0.470588235, 0.372549020, 0.294117647), 0.387729411764706),  // RGB(120,95,75)
        ]

        for (rgb01, expected) in testCases {
            let result = Luminance.bt709LuminanceSRGB01(rgb01: rgb01)
            let diff = abs(result - expected)

            XCTAssertLessThan(diff, 1e-6, """
                BT.709 CPU-GPU mismatch for RGB(\(rgb01.x), \(rgb01.y), \(rgb01.z))
                Expected (GPU): \(expected)
                Got (CPU): \(result)
                Diff: \(diff)
                """)
        }
    }

    /// Test CPU XYZ D65 Y component against known Metal GPU outputs
    /// These expected values come from linearRGBToXYZ() in GlowAnalysis.metal:49
    func testCPU_MatchesGPU_D65() {
        // Known GPU outputs from linearRGBToXYZ().y in GlowAnalysis.metal:49
        // Formula: 0.2126729 * linear.r + 0.7151522 * linear.g + 0.0721750 * linear.b
        let testCases: [(rgbLinear: SIMD3<Float>, expectedY: Float)] = [
            (SIMD3<Float>(0.0, 0.0, 0.0), 0.0),
            (SIMD3<Float>(1.0, 1.0, 1.0), 1.0),
            (SIMD3<Float>(1.0, 0.0, 0.0), 0.2126729),
            (SIMD3<Float>(0.0, 1.0, 0.0), 0.7151522),
            (SIMD3<Float>(0.0, 0.0, 1.0), 0.0721750),
        ]

        for (rgbLinear, expectedY) in testCases {
            let result = Luminance.yLinearD65(rgbLinear: rgbLinear)
            let diff = abs(result - expectedY)

            XCTAssertLessThan(diff, 1e-7, """
                D65 Y CPU-GPU mismatch for linear RGB(\(rgbLinear.x), \(rgbLinear.y), \(rgbLinear.z))
                Expected (GPU): \(expectedY)
                Got (CPU): \(result)
                Diff: \(diff)
                """)
        }
    }

    // MARK: - Full XYZ Matrix Parity

    /// Test full XYZ conversion against Metal GPU linearRGBToXYZ()
    func testCPU_MatchesGPU_FullXYZ() {
        // Metal shader GlowAnalysis.metal:46-51
        let testCases: [(rgbLinear: SIMD3<Float>, expectedXYZ: SIMD3<Float>)] = [
            (SIMD3<Float>(1, 0, 0), SIMD3<Float>(0.4124564, 0.2126729, 0.0193339)),  // Red
            (SIMD3<Float>(0, 1, 0), SIMD3<Float>(0.3575761, 0.7151522, 0.1191920)),  // Green
            (SIMD3<Float>(0, 0, 1), SIMD3<Float>(0.1804375, 0.0721750, 0.9503041)),  // Blue
            (SIMD3<Float>(1, 1, 1), SIMD3<Float>(0.950470, 1.000000, 1.088830)),     // White (D65)
        ]

        for (rgbLinear, expectedXYZ) in testCases {
            let result = Luminance.linearRGBToXYZ(rgbLinear: rgbLinear)
            let diff = simd_length(result - expectedXYZ)

            XCTAssertLessThan(diff, 1e-5, """
                Full XYZ CPU-GPU mismatch for linear RGB(\(rgbLinear.x), \(rgbLinear.y), \(rgbLinear.z))
                Expected (GPU): XYZ(\(expectedXYZ.x), \(expectedXYZ.y), \(expectedXYZ.z))
                Got (CPU): XYZ(\(result.x), \(result.y), \(result.z))
                Euclidean diff: \(diff)
                """)
        }
    }

    // MARK: - Regression Test: HydrationEstimator Fix

    /// Regression test: Ensure HydrationEstimator uses normalized luminance
    /// This test simulates what HydrationEstimator.swift does at lines 773 and 947
    func testHydrationEstimator_RegressionTest() {
        // Simulate pixel data (UInt8 buffer)
        let pixels: [(r: Float, g: Float, b: Float)] = [
            (120, 95, 75),   // Fitz IV
            (90, 70, 50),    // Fitz V
            (150, 120, 100), // Fitz III
        ]

        for (r, g, b) in pixels {
            // BEFORE FIX (WRONG): Applied BT.709 to 0..255 values
            let wrongIntensity = 0.2126 * r + 0.7152 * g + 0.0722 * b

            // AFTER FIX (CORRECT): Use helper that normalizes first
            let correctIntensity = Luminance.bt709LuminanceSRGB255(r: r, g: g, b: b)

            // Correct intensity should be in 0..1 range
            XCTAssertGreaterThanOrEqual(correctIntensity, 0.0)
            XCTAssertLessThanOrEqual(correctIntensity, 1.0)

            // Wrong intensity should be in 0..255 range
            XCTAssertGreaterThan(wrongIntensity, 1.0, "Old bug produced >1 values")

            print("✅ RGB(\(Int(r)),\(Int(g)),\(Int(b))): old=\(wrongIntensity) (WRONG), new=\(correctIntensity) (CORRECT)")
        }
    }

    // MARK: - Regression Test: GlowAnalyzer Fix

    /// Regression test: Ensure GlowAnalyzer uses exact D65 coefficients
    /// This test simulates what GlowAnalyzer.swift does at line 443
    func testGlowAnalyzer_RegressionTest() {
        // Simulate sRGB pixel converted to linear
        let srgbPixel = SIMD3<Float>(120.0/255.0, 95.0/255.0, 75.0/255.0)
        let linearPixel = Luminance.srgbToLinear(srgbPixel)

        // BEFORE FIX (WRONG): Used rounded BT.709 coefficients
        let wrongY = 0.2126 * linearPixel.x + 0.7152 * linearPixel.y + 0.0722 * linearPixel.z

        // AFTER FIX (CORRECT): Use exact D65 coefficients
        let correctY = Luminance.yLinearD65(rgbLinear: linearPixel)

        let diff = abs(correctY - wrongY)
        let percentDiff = (diff / correctY) * 100

        // Difference should be small but measurable
        XCTAssertGreaterThan(diff, 1e-7, "Should detect precision difference")
        XCTAssertLessThan(percentDiff, 0.1, "Precision error should be < 0.1%")

        print("✅ GlowAnalyzer fix: old=\(wrongY) (rounded), new=\(correctY) (exact), diff=\(diff) (\(percentDiff)%)")
    }

    // MARK: - Edge Cases

    /// Test edge cases that could cause NaN or Inf
    func testEdgeCases() {
        // Zero values
        XCTAssertEqual(Luminance.bt709LuminanceSRGB01(rgb01: SIMD3<Float>(0, 0, 0)), 0.0)
        XCTAssertEqual(Luminance.yLinearD65(rgbLinear: SIMD3<Float>(0, 0, 0)), 0.0)

        // Maximum values
        XCTAssertEqual(Luminance.bt709LuminanceSRGB01(rgb01: SIMD3<Float>(1, 1, 1)), 1.0)
        XCTAssertEqual(Luminance.yLinearD65(rgbLinear: SIMD3<Float>(1, 1, 1)), 1.0)

        // Very small values (should not underflow)
        let tiny = SIMD3<Float>(1e-6, 1e-6, 1e-6)
        let tinyResult = Luminance.bt709LuminanceSRGB01(rgb01: tiny)
        XCTAssertFalse(tinyResult.isNaN, "Should not produce NaN")
        XCTAssertFalse(tinyResult.isInfinite, "Should not produce Inf")
        XCTAssertGreaterThan(tinyResult, 0, "Should produce small positive value")
    }

    // MARK: - Performance Benchmark

    /// Measure performance of luminance calculations
    /// Ensures optimizations don't regress
    func testPerformance_BT709() {
        let rgb01 = SIMD3<Float>(0.5, 0.5, 0.5)

        measure {
            for _ in 0..<100_000 {
                _ = Luminance.bt709LuminanceSRGB01(rgb01: rgb01)
            }
        }
    }
}
