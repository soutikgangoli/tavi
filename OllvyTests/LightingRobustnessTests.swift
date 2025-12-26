//
//  LightingRobustnessTests.swift
//  OllvyTests
//
//  Tests for lighting robustness improvements
//  Created on 2025-12-25.
//

import XCTest
import simd
@testable import Ollvy

final class LightingRobustnessTests: XCTestCase {

    // MARK: - Synthetic Image Generation

    /// Create synthetic UIImage from pixel array
    private func createImage(width: Int, height: Int, pixels: [SIMD3<Float>]) -> UIImage {
        precondition(pixels.count == width * height, "Pixel count must match width × height")

        var rgbData = [UInt8]()
        rgbData.reserveCapacity(width * height * 4)

        for pixel in pixels {
            let r = UInt8(min(255, max(0, pixel.x * 255)))
            let g = UInt8(min(255, max(0, pixel.y * 255)))
            let b = UInt8(min(255, max(0, pixel.z * 255)))
            rgbData.append(contentsOf: [r, g, b, 255])
        }

        let dataProvider = CGDataProvider(data: Data(rgbData) as CFData)!
        let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!

        return UIImage(cgImage: cgImage)
    }

    // MARK: - Test: Uniform Lighting

    func testUniformLighting() {
        print("\n=== Test: Uniform Lighting ===")

        // Create uniform gray field (50% brightness)
        let width = 200
        let height = 200
        let uniformColor = SIMD3<Float>(0.5, 0.5, 0.5)
        let pixels = Array(repeating: uniformColor, count: width * height)

        let image = createImage(width: width, height: height, pixels: pixels)

        let analyzer = LightingQualityAnalyzer()
        let (brightness, quality, scanQuality) = analyzer.detectLightingConditions(
            texture: image,
            whiteBalanceGains: nil,
            whiteBalanceTemperature: nil,
            strictness: .strict
        )

        print("Brightness: \(String(format: "%.3f", brightness))")
        print("Quality: \(quality)")
        print("Scan Quality: exposure=\(String(format: "%.2f", scanQuality.exposure)) clipping=\(String(format: "%.2f", scanQuality.clipping)) sharp=\(String(format: "%.2f", scanQuality.sharpness)) uniform=\(String(format: "%.2f", scanQuality.uniformity)) cast=\(String(format: "%.2f", scanQuality.colorCast))")

        // Assertions
        XCTAssertEqual(brightness, 0.5, accuracy: 0.05, "Uniform field should have brightness ≈ 0.5")
        XCTAssertEqual(quality, .optimal, "Uniform field with 50% brightness should be optimal")
        XCTAssertGreaterThan(scanQuality.uniformity, 0.9, "Uniform field should have high uniformity")
        XCTAssertGreaterThan(scanQuality.colorCast, 0.9, "Neutral gray should have low color cast")
    }

    // MARK: - Test: Left-Right Gradient Shadow

    func testLeftRightGradientShadow() {
        print("\n=== Test: Left-Right Gradient Shadow ===")

        let width = 200
        let height = 200
        var pixels: [SIMD3<Float>] = []

        // Create gradient: left side 0.3, right side 0.7
        for y in 0..<height {
            for x in 0..<width {
                let brightness = 0.3 + (Float(x) / Float(width)) * 0.4  // 0.3 to 0.7
                pixels.append(SIMD3<Float>(brightness, brightness, brightness))
            }
        }

        let image = createImage(width: width, height: height, pixels: pixels)

        let analyzer = LightingQualityAnalyzer()
        let (brightness, quality, scanQuality) = analyzer.detectLightingConditions(
            texture: image,
            whiteBalanceGains: nil,
            whiteBalanceTemperature: nil,
            strictness: .strict
        )

        print("Brightness: \(String(format: "%.3f", brightness))")
        print("Quality: \(quality)")
        print("Scan Quality: exposure=\(String(format: "%.2f", scanQuality.exposure)) clipping=\(String(format: "%.2f", scanQuality.clipping)) sharp=\(String(format: "%.2f", scanQuality.sharpness)) uniform=\(String(format: "%.2f", scanQuality.uniformity)) cast=\(String(format: "%.2f", scanQuality.colorCast))")

        // Assertions
        XCTAssertEqual(brightness, 0.5, accuracy: 0.1, "Mean brightness should be ~0.5")
        XCTAssertLessThan(scanQuality.uniformity, 0.5, "Gradient should have low uniformity")
        XCTAssert(quality == .suboptimalDark || quality == .suboptimalBright, "Gradient should be flagged as suboptimal")

        // Check directionality detection
        print("✓ Gradient detected via uniformity score: \(String(format: "%.2f", scanQuality.uniformity))")
    }

    // MARK: - Test: Top-Bottom Shadow

    func testTopBottomShadow() {
        print("\n=== Test: Top-Bottom Shadow ===")

        let width = 200
        let height = 200
        var pixels: [SIMD3<Float>] = []

        // Create gradient: top 0.7, bottom 0.3
        for y in 0..<height {
            for x in 0..<width {
                let brightness = 0.7 - (Float(y) / Float(height)) * 0.4  // 0.7 to 0.3
                pixels.append(SIMD3<Float>(brightness, brightness, brightness))
            }
        }

        let image = createImage(width: width, height: height, pixels: pixels)

        let analyzer = LightingQualityAnalyzer()
        let (_, quality, scanQuality) = analyzer.detectLightingConditions(
            texture: image,
            whiteBalanceGains: nil,
            whiteBalanceTemperature: nil,
            strictness: .strict
        )

        print("Quality: \(quality)")
        print("Uniformity: \(String(format: "%.2f", scanQuality.uniformity))")

        XCTAssertLessThan(scanQuality.uniformity, 0.5, "Vertical gradient should have low uniformity")
    }

    // MARK: - Test: Warm Color Cast

    func testWarmColorCast() {
        print("\n=== Test: Warm Color Cast ===")

        let width = 200
        let height = 200
        // Warm cast: more red/yellow, less blue
        let warmColor = SIMD3<Float>(0.7, 0.6, 0.4)  // Warm tungsten lighting
        let pixels = Array(repeating: warmColor, count: width * height)

        let image = createImage(width: width, height: height, pixels: pixels)

        let analyzer = LightingQualityAnalyzer()
        let (_, quality, scanQuality) = analyzer.detectLightingConditions(
            texture: image,
            whiteBalanceGains: nil,
            whiteBalanceTemperature: nil,
            strictness: .strict
        )

        print("Quality: \(quality)")
        print("Color Cast Score: \(String(format: "%.2f", scanQuality.colorCast))")

        // Warm cast should be detected
        XCTAssertLessThan(scanQuality.colorCast, 0.85, "Warm cast should reduce color cast score")
        print("✓ Warm cast detected: color cast score = \(String(format: "%.2f", scanQuality.colorCast))")
    }

    // MARK: - Test: Cool Color Cast

    func testCoolColorCast() {
        print("\n=== Test: Cool Color Cast ===")

        let width = 200
        let height = 200
        // Cool cast: less red, more blue
        let coolColor = SIMD3<Float>(0.45, 0.55, 0.70)  // Cool daylight
        let pixels = Array(repeating: coolColor, count: width * height)

        let image = createImage(width: width, height: height, pixels: pixels)

        let analyzer = LightingQualityAnalyzer()
        let (_, quality, scanQuality) = analyzer.detectLightingConditions(
            texture: image,
            whiteBalanceGains: nil,
            whiteBalanceTemperature: nil,
            strictness: .strict
        )

        print("Quality: \(quality)")
        print("Color Cast Score: \(String(format: "%.2f", scanQuality.colorCast))")

        // Cool cast should be detected
        XCTAssertLessThan(scanQuality.colorCast, 0.85, "Cool cast should reduce color cast score")
        print("✓ Cool cast detected: color cast score = \(String(format: "%.2f", scanQuality.colorCast))")
    }

    // MARK: - Test: Blur Detection

    func testBlurDetection() {
        print("\n=== Test: Blur Detection ===")

        let width = 200
        let height = 200
        var pixels: [SIMD3<Float>] = []

        // Create blurry image: very low frequency variation
        for y in 0..<height {
            for x in 0..<width {
                // Large-scale gradient (blurry)
                let brightness = 0.5 + 0.1 * sin(Float(x) / 50.0) * cos(Float(y) / 50.0)
                pixels.append(SIMD3<Float>(brightness, brightness, brightness))
            }
        }

        let blurryImage = createImage(width: width, height: height, pixels: pixels)

        // Create sharp image: high frequency variation
        pixels.removeAll()
        for y in 0..<height {
            for x in 0..<width {
                // High frequency detail (sharp)
                let brightness = 0.5 + 0.05 * sin(Float(x) / 2.0) * cos(Float(y) / 2.0)
                pixels.append(SIMD3<Float>(brightness, brightness, brightness))
            }
        }

        let sharpImage = createImage(width: width, height: height, pixels: pixels)

        let analyzer = LightingQualityAnalyzer()

        let (_, _, blurryScan) = analyzer.detectLightingConditions(
            texture: blurryImage,
            whiteBalanceGains: nil,
            whiteBalanceTemperature: nil,
            strictness: .strict
        )

        let (_, _, sharpScan) = analyzer.detectLightingConditions(
            texture: sharpImage,
            whiteBalanceGains: nil,
            whiteBalanceTemperature: nil,
            strictness: .strict
        )

        print("Blurry sharpness: \(String(format: "%.2f", blurryScan.sharpness))")
        print("Sharp sharpness: \(String(format: "%.2f", sharpScan.sharpness))")

        XCTAssertLessThan(blurryScan.sharpness, sharpScan.sharpness, "Sharp image should have higher sharpness score")
        XCTAssertLessThan(blurryScan.sharpness, 0.7, "Blurry image should have low sharpness")
        print("✓ Blur detected: blurry=\(String(format: "%.2f", blurryScan.sharpness)) vs sharp=\(String(format: "%.2f", sharpScan.sharpness))")
    }

    // MARK: - Test: Percentile Range vs Max-Min

    func testPercentileRangeRobustness() {
        print("\n=== Test: Percentile Range Robustness ===")

        let width = 200
        let height = 200
        var pixels: [SIMD3<Float>] = []

        // Create mostly uniform field with a few outliers
        for y in 0..<height {
            for x in 0..<width {
                if x == 10 && y == 10 {
                    // Single very bright pixel
                    pixels.append(SIMD3<Float>(1.0, 1.0, 1.0))
                } else if x == 50 && y == 50 {
                    // Single very dark pixel
                    pixels.append(SIMD3<Float>(0.0, 0.0, 0.0))
                } else {
                    // Mostly uniform
                    pixels.append(SIMD3<Float>(0.5, 0.5, 0.5))
                }
            }
        }

        let image = createImage(width: width, height: height, pixels: pixels)

        let analyzer = LightingQualityAnalyzer()
        let (_, quality, scanQuality) = analyzer.detectLightingConditions(
            texture: image,
            whiteBalanceGains: nil,
            whiteBalanceTemperature: nil,
            strictness: .strict
        )

        print("Quality: \(quality)")
        print("Uniformity: \(String(format: "%.2f", scanQuality.uniformity))")

        // With percentile range, should NOT be fooled by outliers
        // Old max-min would show range=1.0, new P95-P05 should show ~0.0
        XCTAssertEqual(quality, .optimal, "Percentile range should ignore outliers")
        XCTAssertGreaterThan(scanQuality.uniformity, 0.9, "Should detect uniformity despite outliers")
        print("✓ Percentile range robust to outliers")
    }

    // MARK: - Test: Metric Confidence Gating

    func testMetricConfidenceGating() {
        print("\n=== Test: Metric Confidence Gating ===")

        // Test pigmentation confidence with various quality levels

        // Good quality
        let goodQuality = ScanQualityMetrics(
            exposure: 0.9,
            clipping: 0.95,
            sharpness: 0.85,
            uniformity: 0.90,
            colorCast: 0.92
        )

        let pigmentationConf = computeMetricConfidence(metric: .pigmentation, scanQuality: goodQuality)
        let specularConf = computeMetricConfidence(metric: .specular, scanQuality: goodQuality)
        let textureConf = computeMetricConfidence(metric: .texture, scanQuality: goodQuality)

        print("Good quality - Pigmentation conf: \(String(format: "%.2f", pigmentationConf))")
        print("Good quality - Specular conf: \(String(format: "%.2f", specularConf))")
        print("Good quality - Texture conf: \(String(format: "%.2f", textureConf))")

        XCTAssertGreaterThan(pigmentationConf, 0.75, "Pigmentation should have high confidence with good quality")
        XCTAssertGreaterThan(specularConf, 0.75, "Specular should have high confidence with good uniformity")
        XCTAssertGreaterThan(textureConf, 0.75, "Texture should have high confidence with good sharpness")

        // Poor uniformity (shadows)
        let shadowQuality = ScanQualityMetrics(
            exposure: 0.9,
            clipping: 0.95,
            sharpness: 0.85,
            uniformity: 0.40,  // Poor uniformity
            colorCast: 0.92
        )

        let shadowSpecularConf = computeMetricConfidence(metric: .specular, scanQuality: shadowQuality)
        let shadowPigmentationConf = computeMetricConfidence(metric: .pigmentation, scanQuality: shadowQuality)

        print("Shadow quality - Specular conf: \(String(format: "%.2f", shadowSpecularConf))")
        print("Shadow quality - Pigmentation conf: \(String(format: "%.2f", shadowPigmentationConf))")

        XCTAssertEqual(shadowSpecularConf, 0.0, "Specular should be gated with poor uniformity")
        XCTAssertGreaterThan(shadowPigmentationConf, 0.5, "Pigmentation should still work with moderate uniformity")

        // Poor color cast
        let castQuality = ScanQualityMetrics(
            exposure: 0.9,
            clipping: 0.95,
            sharpness: 0.85,
            uniformity: 0.90,
            colorCast: 0.40  // Poor color cast
        )

        let castPigmentationConf = computeMetricConfidence(metric: .pigmentation, scanQuality: castQuality)
        let castTextureConf = computeMetricConfidence(metric: .texture, scanQuality: castQuality)

        print("Cast quality - Pigmentation conf: \(String(format: "%.2f", castPigmentationConf))")
        print("Cast quality - Texture conf: \(String(format: "%.2f", castTextureConf))")

        XCTAssertLessThan(castPigmentationConf, 0.65, "Pigmentation should have low confidence with color cast")
        XCTAssertGreaterThan(castTextureConf, 0.7, "Texture should be less affected by color cast")

        print("✓ Metric confidence gating working correctly")
    }

    // MARK: - Test: Confidence Tiers

    func testConfidenceTiers() {
        print("\n=== Test: Confidence Tiers ===")

        let highConf = MetricConfidence(metric: .pigmentation, rawIndex: 0.05, score: 85, confidence: 0.90)
        let moderateConf = MetricConfidence(metric: .texture, rawIndex: 0.10, score: 70, confidence: 0.65)
        let lowConf = MetricConfidence(metric: .specular, rawIndex: 0.08, score: 60, confidence: 0.35)
        let unreliableConf = MetricConfidence(metric: .hydration, rawIndex: 0.15, score: 50, confidence: 0.15)

        XCTAssertEqual(highConf.tier, .high)
        XCTAssertEqual(moderateConf.tier, .moderate)
        XCTAssertEqual(lowConf.tier, .low)
        XCTAssertEqual(unreliableConf.tier, .unreliable)

        XCTAssertTrue(highConf.shouldDisplay)
        XCTAssertTrue(moderateConf.shouldDisplay)
        XCTAssertTrue(lowConf.shouldDisplay)
        XCTAssertFalse(unreliableConf.shouldDisplay)

        print("✓ Confidence tiers: high=\(highConf.tier) moderate=\(moderateConf.tier) low=\(lowConf.tier) unreliable=\(unreliableConf.tier)")
    }

    // MARK: - Test: White Balance Gains Integration

    func testWhiteBalanceGainsIntegration() {
        print("\n=== Test: White Balance Gains Integration ===")

        let width = 200
        let height = 200
        let pixels = Array(repeating: SIMD3<Float>(0.5, 0.5, 0.5), count: width * height)
        let image = createImage(width: width, height: height, pixels: pixels)

        let analyzer = LightingQualityAnalyzer()

        // Test with neutral D65 gains
        let neutralGains = AVCaptureDevice.WhiteBalanceGains(
            redGain: 1.8,
            greenGain: 1.0,
            blueGain: 1.6
        )

        let (_, _, neutralScan) = analyzer.detectLightingConditions(
            texture: image,
            whiteBalanceGains: neutralGains,
            whiteBalanceTemperature: nil,
            strictness: .strict
        )

        // Test with warm gains (tungsten)
        let warmGains = AVCaptureDevice.WhiteBalanceGains(
            redGain: 1.2,
            greenGain: 1.0,
            blueGain: 2.8
        )

        let (_, _, warmScan) = analyzer.detectLightingConditions(
            texture: image,
            whiteBalanceGains: warmGains,
            whiteBalanceTemperature: nil,
            strictness: .strict
        )

        print("Neutral WB color cast: \(String(format: "%.2f", neutralScan.colorCast))")
        print("Warm WB color cast: \(String(format: "%.2f", warmScan.colorCast))")

        XCTAssertGreaterThan(neutralScan.colorCast, warmScan.colorCast, "Neutral WB should have better color cast score")
        print("✓ White balance gains correctly influence color cast detection")
    }

    // MARK: - REGRESSION TESTS (Constraint #6)

    /// Test that lighting analysis does NOT increase clipping/oversaturation
    func testNoClippingIncrease() {
        print("\n=== Regression Test: No Clipping Increase ===")

        let width = 200
        let height = 200

        // Create image with some bright pixels (0.9) but NO clipping
        let pixels = Array(repeating: SIMD3<Float>(0.9, 0.9, 0.9), count: width * height)
        let image = createImage(width: width, height: height, pixels: pixels)

        let analyzer = LightingQualityAnalyzer()
        let (_, _, scanQuality) = analyzer.detectLightingConditions(
            texture: image,
            whiteBalanceGains: nil,
            whiteBalanceTemperature: nil,
            strictness: .strict
        )

        // Verify clipping score is high (no clipping introduced)
        // clipping score 0-1, higher = less clipping
        print("Clipping score: \(String(format: "%.2f", scanQuality.clipping))")
        print("Overexposure ratio: \(String(format: "%.2f", 1.0 - scanQuality.clipping))")

        // Since pixels are 0.9 (below 0.95 threshold), clipping should be minimal
        XCTAssertGreaterThan(scanQuality.clipping, 0.9, "Analysis should not introduce clipping for 0.9 brightness pixels")
        print("✓ No clipping increase detected")
    }

    /// Test that bad lighting LOWERS confidence instead of inflating scores
    func testNoMetricInflationInBadLighting() {
        print("\n=== Regression Test: No Metric Inflation in Bad Lighting ===")

        let width = 200
        let height = 200

        // Scenario 1: Good uniform lighting
        let goodPixels = Array(repeating: SIMD3<Float>(0.5, 0.5, 0.5), count: width * height)
        let goodImage = createImage(width: width, height: height, pixels: goodPixels)

        let analyzer = LightingQualityAnalyzer()
        let (_, _, goodScan) = analyzer.detectLightingConditions(
            texture: goodImage,
            whiteBalanceGains: nil,
            whiteBalanceTemperature: nil,
            strictness: .strict
        )

        // Scenario 2: Bad lighting (harsh left-right gradient)
        var badPixels: [SIMD3<Float>] = []
        for y in 0..<height {
            for x in 0..<width {
                let brightness = 0.2 + (Float(x) / Float(width)) * 0.6  // 0.2 to 0.8 gradient
                badPixels.append(SIMD3<Float>(brightness, brightness, brightness))
            }
        }
        let badImage = createImage(width: width, height: height, pixels: badPixels)
        let (_, _, badScan) = analyzer.detectLightingConditions(
            texture: badImage,
            whiteBalanceGains: nil,
            whiteBalanceTemperature: nil,
            strictness: .strict
        )

        print("Good lighting uniformity: \(String(format: "%.2f", goodScan.uniformity))")
        print("Bad lighting uniformity: \(String(format: "%.2f", badScan.uniformity))")

        // Verify bad lighting has LOWER uniformity
        XCTAssertLessThan(badScan.uniformity, goodScan.uniformity, "Bad lighting should have lower uniformity score")

        // Verify per-metric confidence is LOWER for bad lighting
        let goodSpecularConf = computeMetricConfidence(metric: .specular, scanQuality: goodScan)
        let badSpecularConf = computeMetricConfidence(metric: .specular, scanQuality: badScan)

        print("Good lighting specular confidence: \(String(format: "%.2f", goodSpecularConf))")
        print("Bad lighting specular confidence: \(String(format: "%.2f", badSpecularConf))")

        XCTAssertLessThan(badSpecularConf, goodSpecularConf, "Bad lighting should LOWER specular confidence (not inflate)")

        // Verify gating: specular should be gated if uniformity < 0.7
        if badScan.uniformity < 0.7 {
            XCTAssertEqual(badSpecularConf, 0.0, "Specular should be GATED when uniformity < 0.7")
        }

        print("✓ Bad lighting correctly lowers confidence (no inflation)")
    }

    /// Test luminance drift bounds (for future chromatic adaptation)
    /// NOTE: Currently N/A since chromatic adaptation is NOT implemented
    func testLuminanceDriftBounds() {
        print("\n=== Regression Test: Luminance Drift Bounds (Future) ===")

        let width = 200
        let height = 200
        let pixels = Array(repeating: SIMD3<Float>(0.5, 0.5, 0.5), count: width * height)
        let image = createImage(width: width, height: height, pixels: pixels)

        // Compute original mean luminance (BT.709)
        let originalLuminance: Float = 0.5 * 0.2126 + 0.5 * 0.7152 + 0.5 * 0.0722

        // Currently we do NOT apply chromatic adaptation, so luminance should be unchanged
        // This test will become relevant if/when chromatic adaptation is implemented

        let analyzer = LightingQualityAnalyzer()
        let (brightness, _, _) = analyzer.detectLightingConditions(
            texture: image,
            whiteBalanceGains: nil,
            whiteBalanceTemperature: nil,
            strictness: .strict
        )

        print("Original luminance: \(String(format: "%.4f", originalLuminance))")
        print("Detected brightness: \(String(format: "%.4f", brightness))")

        // Since we don't modify pixels, brightness should match original
        let drift = abs(brightness - 0.5)
        print("Luminance drift: \(String(format: "%.2f", drift * 100))%")

        // Allow 5% tolerance for analysis sampling/rounding
        XCTAssertLessThan(drift, 0.05, "Luminance drift should be minimal (analysis-only)")

        print("✓ Luminance drift within bounds (no normalization applied)")
        print("NOTE: This test will enforce ±2% bounds when chromatic adaptation is implemented")
    }
}
