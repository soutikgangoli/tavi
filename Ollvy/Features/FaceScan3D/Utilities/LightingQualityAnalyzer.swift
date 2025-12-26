//
//  LightingQualityAnalyzer.swift
//  Ollvy
//
//  Enhanced lighting quality detection with regional sampling and directionality
//  Created on 2025-12-25.
//

import Foundation
import UIKit
import Accelerate
import simd
import AVFoundation

/// Enhanced lighting quality analyzer
public class LightingQualityAnalyzer {

    private let skinToneNormalizer = SkinToneNormalizer()

    // MARK: - Multi-Region Sampling

    /// Sample lighting from multiple face regions
    public func detectLightingConditions(
        texture: UIImage,
        whiteBalanceGains: AVCaptureDevice.WhiteBalanceGains? = nil,
        whiteBalanceTemperature: Float? = nil,
        strictness: LightingStrictnessLevel = .strict
    ) -> (brightness: Float, quality: LightingQuality, scanQuality: ScanQualityMetrics) {

        guard let cgImage = texture.cgImage else {
            return (0.5, .optimal, ScanQualityMetrics(exposure: 0.5, clipping: 0.5, sharpness: 0.5, uniformity: 0.5, colorCast: 0.5))
        }

        let width = cgImage.width
        let height = cgImage.height

        // Define sampling regions
        let regions = defineRegions(width: width, height: height)

        // Extract pixel data
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return (0.5, .optimal, ScanQualityMetrics(exposure: 0.5, clipping: 0.5, sharpness: 0.5, uniformity: 0.5, colorCast: 0.5))
        }

        let dataLength = CFDataGetLength(data)

        // Sample each region
        var regionalStats: [RegionStats] = []

        for (name, rect) in regions {
            let stats = sampleRegion(
                ptr: ptr,
                dataLength: dataLength,
                width: width,
                height: height,
                region: rect,
                regionName: name
            )
            regionalStats.append(stats)
        }

        // Compute aggregate metrics
        let aggregateStats = computeAggregateStats(regionalStats: regionalStats)

        // Compute quality components
        let exposureScore = computeExposureScore(stats: aggregateStats)
        let clippingScore = computeClippingScore(stats: aggregateStats)
        let sharpnessScore = computeSharpnessScore(regionalStats: regionalStats)
        let uniformityScore = computeUniformityScore(regionalStats: regionalStats)
        let colorCastScore = computeColorCastScore(
            regionalStats: regionalStats,
            whiteBalanceGains: whiteBalanceGains,
            whiteBalanceTemperature: whiteBalanceTemperature,
            texture: texture
        )

        let scanQuality = ScanQualityMetrics(
            exposure: exposureScore,
            clipping: clippingScore,
            sharpness: sharpnessScore,
            uniformity: uniformityScore,
            colorCast: colorCastScore
        )

        // Determine overall lighting quality
        let quality = determineLightingQuality(
            scanQuality: scanQuality,
            aggregateStats: aggregateStats,
            strictness: strictness
        )

        AppLogger.metrics.info("💡 Lighting: \(quality.description) | Exposure=\(String(format: "%.2f", exposureScore)) Clip=\(String(format: "%.2f", clippingScore)) Sharp=\(String(format: "%.2f", sharpnessScore)) Uniform=\(String(format: "%.2f", uniformityScore)) Cast=\(String(format: "%.2f", colorCastScore))")

        return (aggregateStats.meanBrightness, quality, scanQuality)
    }

    // MARK: - Region Definitions

    private struct RegionRect {
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    private func defineRegions(width: Int, height: Int) -> [(name: String, rect: RegionRect)] {
        let centerX = width / 2
        let centerY = height / 2
        let sampleSize = min(width, height) / 6

        return [
            ("center", RegionRect(x: centerX - sampleSize/2, y: centerY - sampleSize/2, width: sampleSize, height: sampleSize)),
            ("left", RegionRect(x: width / 6, y: centerY - sampleSize/2, width: sampleSize, height: sampleSize)),
            ("right", RegionRect(x: width * 5/6 - sampleSize, y: centerY - sampleSize/2, width: sampleSize, height: sampleSize)),
            ("top", RegionRect(x: centerX - sampleSize/2, y: height / 6, width: sampleSize, height: sampleSize)),
            ("bottom", RegionRect(x: centerX - sampleSize/2, y: height * 5/6 - sampleSize, width: sampleSize, height: sampleSize))
        ]
    }

    // MARK: - Region Sampling

    private struct RegionStats {
        let name: String
        let meanBrightness: Float
        let meanR: Float
        let meanG: Float
        let meanB: Float
        let brightnessValues: [Float]
        let p05: Float  // 5th percentile
        let p95: Float  // 95th percentile
        let overexposedRatio: Float
        let underexposedRatio: Float
        let edgeEnergy: Float  // For sharpness
    }

    private func sampleRegion(
        ptr: UnsafePointer<UInt8>,
        dataLength: Int,
        width: Int,
        height: Int,
        region: RegionRect,
        regionName: String
    ) -> RegionStats {

        var brightnessValues: [Float] = []
        var rValues: [Float] = []
        var gValues: [Float] = []
        var bValues: [Float] = []
        var overexposedCount = 0
        var underexposedCount = 0
        var totalEdgeEnergy: Float = 0
        var edgeSampleCount = 0

        // Sample every 2nd pixel for performance
        for y in stride(from: region.y, to: min(region.y + region.height, height), by: 2) {
            for x in stride(from: region.x, to: min(region.x + region.width, width), by: 2) {
                guard x >= 0 && x < width && y >= 0 && y < height else { continue }

                let offset = (y * width + x) * 4
                guard offset + 2 < dataLength else { continue }

                let r = Float(ptr[offset])
                let g = Float(ptr[offset + 1])
                let b = Float(ptr[offset + 2])

                let rNorm = r / 255.0
                let gNorm = g / 255.0
                let bNorm = b / 255.0

                // BT.709 luminance
                let luminance = 0.2126 * rNorm + 0.7152 * gNorm + 0.0722 * bNorm

                brightnessValues.append(luminance)
                rValues.append(rNorm)
                gValues.append(gNorm)
                bValues.append(bNorm)

                if luminance > 0.95 {
                    overexposedCount += 1
                } else if luminance < 0.05 {
                    underexposedCount += 1
                }

                // Compute edge energy for sharpness (Laplacian)
                if y > region.y && y < region.y + region.height - 1 &&
                   x > region.x && x < region.x + region.width - 1 {

                    let centerOffset = offset
                    let topOffset = ((y-1) * width + x) * 4
                    let bottomOffset = ((y+1) * width + x) * 4
                    let leftOffset = (y * width + (x-1)) * 4
                    let rightOffset = (y * width + (x+1)) * 4

                    if topOffset >= 0 && bottomOffset < dataLength &&
                       leftOffset >= 0 && rightOffset < dataLength {

                        let center = (Float(ptr[centerOffset]) + Float(ptr[centerOffset+1]) + Float(ptr[centerOffset+2])) / 3.0
                        let top = (Float(ptr[topOffset]) + Float(ptr[topOffset+1]) + Float(ptr[topOffset+2])) / 3.0
                        let bottom = (Float(ptr[bottomOffset]) + Float(ptr[bottomOffset+1]) + Float(ptr[bottomOffset+2])) / 3.0
                        let left = (Float(ptr[leftOffset]) + Float(ptr[leftOffset+1]) + Float(ptr[leftOffset+2])) / 3.0
                        let right = (Float(ptr[rightOffset]) + Float(ptr[rightOffset+1]) + Float(ptr[rightOffset+2])) / 3.0

                        let laplacian = abs(4 * center - top - bottom - left - right)
                        totalEdgeEnergy += laplacian
                        edgeSampleCount += 1
                    }
                }
            }
        }

        let count = brightnessValues.count
        guard count > 0 else {
            return RegionStats(
                name: regionName,
                meanBrightness: 0.5,
                meanR: 0.5,
                meanG: 0.5,
                meanB: 0.5,
                brightnessValues: [],
                p05: 0.0,
                p95: 1.0,
                overexposedRatio: 0.0,
                underexposedRatio: 0.0,
                edgeEnergy: 0.0
            )
        }

        // Compute mean
        let meanBrightness = brightnessValues.reduce(0, +) / Float(count)
        let meanR = rValues.reduce(0, +) / Float(count)
        let meanG = gValues.reduce(0, +) / Float(count)
        let meanB = bValues.reduce(0, +) / Float(count)

        // Compute percentiles
        let sortedBrightness = brightnessValues.sorted()
        let p05Index = max(0, min(count - 1, Int(Float(count) * 0.05)))
        let p95Index = max(0, min(count - 1, Int(Float(count) * 0.95)))
        let p05 = sortedBrightness[p05Index]
        let p95 = sortedBrightness[p95Index]

        let overexposedRatio = Float(overexposedCount) / Float(count)
        let underexposedRatio = Float(underexposedCount) / Float(count)

        let edgeEnergy = edgeSampleCount > 0 ? totalEdgeEnergy / Float(edgeSampleCount) : 0.0

        return RegionStats(
            name: regionName,
            meanBrightness: meanBrightness,
            meanR: meanR,
            meanG: meanG,
            meanB: meanB,
            brightnessValues: brightnessValues,
            p05: p05,
            p95: p95,
            overexposedRatio: overexposedRatio,
            underexposedRatio: underexposedRatio,
            edgeEnergy: edgeEnergy
        )
    }

    // MARK: - Aggregate Statistics

    private struct AggregateStats {
        let meanBrightness: Float
        let percentileRange: Float  // P95 - P05
        let overexposedRatio: Float
        let underexposedRatio: Float
        let contrast: Float  // Std dev of brightness
    }

    private func computeAggregateStats(regionalStats: [RegionStats]) -> AggregateStats {
        // Combine all brightness values
        var allBrightnessValues: [Float] = []
        var totalOverexposed: Float = 0
        var totalUnderexposed: Float = 0

        for stats in regionalStats {
            allBrightnessValues.append(contentsOf: stats.brightnessValues)
            totalOverexposed += stats.overexposedRatio
            totalUnderexposed += stats.underexposedRatio
        }

        let count = allBrightnessValues.count
        guard count > 0 else {
            return AggregateStats(
                meanBrightness: 0.5,
                percentileRange: 0.5,
                overexposedRatio: 0.0,
                underexposedRatio: 0.0,
                contrast: 0.1
            )
        }

        let meanBrightness = allBrightnessValues.reduce(0, +) / Float(count)

        // Percentile range across all regions
        let sortedAll = allBrightnessValues.sorted()
        let p05Index = max(0, min(count - 1, Int(Float(count) * 0.05)))
        let p95Index = max(0, min(count - 1, Int(Float(count) * 0.95)))
        let p05 = sortedAll[p05Index]
        let p95 = sortedAll[p95Index]
        let percentileRange = p95 - p05

        // Average overexposure/underexposure across regions
        let avgOverexposed = totalOverexposed / Float(regionalStats.count)
        let avgUnderexposed = totalUnderexposed / Float(regionalStats.count)

        // Compute contrast (std dev)
        var sumSquaredDiff: Float = 0
        for value in allBrightnessValues {
            let diff = value - meanBrightness
            sumSquaredDiff += diff * diff
        }
        let variance = sumSquaredDiff / Float(count)
        let contrast = sqrt(variance)

        return AggregateStats(
            meanBrightness: meanBrightness,
            percentileRange: percentileRange,
            overexposedRatio: avgOverexposed,
            underexposedRatio: avgUnderexposed,
            contrast: contrast
        )
    }

    // MARK: - Quality Component Scores

    private func computeExposureScore(stats: AggregateStats) -> Float {
        // Target: mean brightness 0.45-0.55 (45-55%)
        let targetMean: Float = 0.50
        let deviation = abs(stats.meanBrightness - targetMean)

        // Score: 1.0 at target, decreases with deviation
        // Allow ±0.1 with no penalty, then linear decrease
        let score = max(0.0, 1.0 - max(0.0, deviation - 0.05) * 3.0)
        return score
    }

    private func computeClippingScore(stats: AggregateStats) -> Float {
        // Penalize clipping (saturated pixels)
        // < 1% clipped = 1.0, > 10% = 0.0
        let totalClipped = stats.overexposedRatio + stats.underexposedRatio

        if totalClipped < 0.01 {
            return 1.0
        } else if totalClipped > 0.10 {
            return 0.0
        } else {
            // Linear interpolation
            return 1.0 - (totalClipped - 0.01) / 0.09
        }
    }

    private func computeSharpnessScore(regionalStats: [RegionStats]) -> Float {
        // Average edge energy across regions
        let totalEdgeEnergy = regionalStats.map { $0.edgeEnergy }.reduce(0, +)
        let meanEdgeEnergy = totalEdgeEnergy / Float(regionalStats.count)

        // Map to 0-1 (empirical range: 0.05-0.20 for good sharpness)
        // Below 0.08 = blurry, above 0.15 = sharp
        if meanEdgeEnergy < 0.08 {
            return meanEdgeEnergy / 0.08  // 0 to 1.0
        } else {
            return min(1.0, meanEdgeEnergy / 0.15)
        }
    }

    private func computeUniformityScore(regionalStats: [RegionStats]) -> Float {
        // Compute directionality: mean brightness differences between regions
        guard regionalStats.count >= 5 else { return 1.0 }

        // Find center, left, right, top, bottom
        let center = regionalStats.first { $0.name == "center" }?.meanBrightness ?? 0.5
        let left = regionalStats.first { $0.name == "left" }?.meanBrightness ?? 0.5
        let right = regionalStats.first { $0.name == "right" }?.meanBrightness ?? 0.5
        let top = regionalStats.first { $0.name == "top" }?.meanBrightness ?? 0.5
        let bottom = regionalStats.first { $0.name == "bottom" }?.meanBrightness ?? 0.5

        // Compute directional gradients
        let horizontalGradient = abs(left - right)
        let verticalGradient = abs(top - bottom)
        let maxGradient = max(horizontalGradient, verticalGradient)

        // Also check center vs extremes
        let centerDeviation = max(
            abs(center - left),
            abs(center - right),
            abs(center - top),
            abs(center - bottom)
        )

        // Combine gradients and center deviation
        let nonUniformity = max(maxGradient, centerDeviation)

        // Score: 1.0 if uniform (< 0.05 diff), 0.0 if very non-uniform (> 0.25 diff)
        if nonUniformity < 0.05 {
            return 1.0
        } else if nonUniformity > 0.25 {
            return 0.0
        } else {
            return 1.0 - (nonUniformity - 0.05) / 0.20
        }
    }

    private func computeColorCastScore(
        regionalStats: [RegionStats],
        whiteBalanceGains: AVCaptureDevice.WhiteBalanceGains?,
        whiteBalanceTemperature: Float?,
        texture: UIImage
    ) -> Float {

        // Strategy 1: Use AVCapture white balance metadata if available
        if let gains = whiteBalanceGains {
            // Evaluate white balance gains
            // Neutral D65 gains: R≈1.8, G=1.0, B≈1.6
            let rDeviation = abs(gains.redGain - 1.8)
            let bDeviation = abs(gains.blueGain - 1.6)
            let totalDeviation = rDeviation + bDeviation

            // Score based on deviation from neutral
            if totalDeviation < 0.2 {
                return 1.0
            } else if totalDeviation > 1.0 {
                return 0.5  // Strong cast but don't fail completely
            } else {
                return 1.0 - (totalDeviation - 0.2) * 0.625  // Linear 0.2→1.0 maps to 1.0→0.5
            }
        }

        // Strategy 2: Use temperature-tint if available
        if let temperature = whiteBalanceTemperature {
            // Neutral daylight: 5500-6500K
            let deviation = abs(temperature - 6000.0)

            if deviation < 500 {
                return 1.0
            } else if deviation > 2500 {
                return 0.5
            } else {
                return 1.0 - (deviation - 500) * 0.00025  // Linear map
            }
        }

        // Strategy 3: Compute cast from pixel data (skin-tone conditioned)
        // Detect skin tone for adaptive thresholds
        let skinTone = skinToneNormalizer.detectSkinTone(texture: texture)

        // Compute mean RGB across all regions
        var totalR: Float = 0
        var totalG: Float = 0
        var totalB: Float = 0

        for stats in regionalStats {
            totalR += stats.meanR
            totalG += stats.meanG
            totalB += stats.meanB
        }

        let count = Float(regionalStats.count)
        let meanR = totalR / count
        let meanG = totalG / count
        let meanB = totalB / count

        // Expected neutral skin chromaticity (skin-tone dependent)
        let expectedChromaticity: SIMD3<Float>
        switch skinTone {
        case .veryLight, .light:
            expectedChromaticity = SIMD3<Float>(0.68, 0.58, 0.50)  // Light skin
        case .medium, .mediumDark:
            expectedChromaticity = SIMD3<Float>(0.65, 0.55, 0.45)  // Medium skin
        case .dark, .veryDark:
            expectedChromaticity = SIMD3<Float>(0.55, 0.45, 0.35)  // Dark skin
        }

        let actualChromaticity = SIMD3<Float>(meanR, meanG, meanB)
        let castMagnitude = simd_length(actualChromaticity - expectedChromaticity)

        // Skin-tone conditioned thresholds
        let threshold: Float
        switch skinTone {
        case .veryLight, .light:
            threshold = 0.15  // Light skin: tighter tolerance
        case .medium, .mediumDark:
            threshold = 0.18  // Medium skin: moderate tolerance
        case .dark, .veryDark:
            threshold = 0.20  // Dark skin: more tolerance (harder to white balance)
        }

        // Score based on cast magnitude
        if castMagnitude < threshold * 0.5 {
            return 1.0
        } else if castMagnitude > threshold {
            return 0.6  // Strong cast but don't fail completely
        } else {
            return 1.0 - (castMagnitude - threshold * 0.5) / (threshold * 0.5) * 0.4
        }
    }

    // MARK: - Overall Lighting Quality Determination

    private func determineLightingQuality(
        scanQuality: ScanQualityMetrics,
        aggregateStats: AggregateStats,
        strictness: LightingStrictnessLevel
    ) -> LightingQuality {

        // Use percentile range instead of simple max-min
        let dynamicRange = aggregateStats.percentileRange

        // BLOCKING CONDITIONS (stricter with percentile approach)

        // 1. Severe overexposure
        if aggregateStats.overexposedRatio > 0.10 {
            return .tooBright
        }

        // 2. Very high brightness
        if aggregateStats.meanBrightness > 0.85 {
            return .tooBright
        }

        // 3. Poor dynamic range (percentile-based)
        // Was: max-min > 0.30 (easily fooled by single bright/dark pixel)
        // Now: P95-P05 > 0.30 (more robust)
        if dynamicRange < 0.30 {
            return .tooDark
        }

        // 4. Too many underexposed pixels
        if aggregateStats.underexposedRatio > 0.20 {
            return .tooDark
        }

        // 5. Very low brightness AND poor contrast
        if aggregateStats.meanBrightness < 0.20 && aggregateStats.contrast < 0.10 {
            return .tooDark
        }

        // WARNING CONDITIONS

        // Borderline overexposure
        if aggregateStats.overexposedRatio > 0.05 || aggregateStats.meanBrightness > 0.75 {
            return .suboptimalBright
        }

        // Low contrast/detail (using percentile range + std dev)
        if aggregateStats.contrast < 0.15 || dynamicRange < 0.40 {
            return .suboptimalDark
        }

        // OPTIMAL
        return .optimal
    }
}
