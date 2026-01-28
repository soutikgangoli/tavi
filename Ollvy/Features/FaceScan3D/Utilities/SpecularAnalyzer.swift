//
//  SpecularAnalyzer.swift
//  Ollvy
//
//  Detect specular highlights and oiliness from raw RGB frames
//  Created on 2025-10-27.
//

import Foundation
import Accelerate
import simd

/// Analyzes specular reflections (shininess/oiliness) from raw RGB texture
public class SpecularAnalyzer {

    // MARK: - Configuration

    public struct Configuration {
        /// Percentile for adaptive brightness threshold (default: 95th percentile)
        /// Higher = only detect very bright pixels
        public var brightnessPercentile: Float = 0.95

        /// Minimum brightness threshold (absolute, 0-1 range)
        /// Prevents false positives in very dark regions
        public var minimumBrightnessThreshold: Float = 0.7

        /// Maximum specular ratio to clamp to (prevents over-detection)
        public var maximumSpecularRatio: Float = 0.3

        public init() {}
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Main API

    /// Compute specular/oiliness proxy from raw RGB texture
    /// Returns 0-1 score where higher = more specular highlights (oilier skin)
    /// NOW USES: Relative percentile + lighting normalization for better accuracy
    public func computeSpecularProxy(_ sample: ROITextureSample) -> Float {
        guard !sample.pixels.isEmpty else {
            return 0
        }

        // Step 1: Convert to luminance (perceived brightness)
        let luminanceValues = sample.pixels.map { pixel in
            // Use Luminance.swift single source of truth (BT.709)
            // Ensures consistency with other analyzers and CPU-GPU parity
            return Luminance.bt709LuminanceSRGB01(rgb01: pixel)
        }

        // Step 2: Calculate baseline skin reflectivity (median or mean of non-specular region)
        let baselineReflectivity = calculateBaselineReflectivity(luminanceValues: luminanceValues)

        // Step 3: Use RELATIVE threshold (deviation from baseline, not absolute percentile)
        let relativeThreshold = detectRelativeSpecularity(
            luminanceValues: luminanceValues,
            baseline: baselineReflectivity
        )

        // Step 4: Count bright pixels above relative threshold
        let brightPixelCount = luminanceValues.filter { $0 >= relativeThreshold }.count

        // Step 5: Compute ratio
        let ratio = Float(brightPixelCount) / Float(sample.pixels.count)

        // Step 6: Clamp to maximum
        let clampedRatio = min(ratio, configuration.maximumSpecularRatio)

        return clampedRatio
    }

    // MARK: - Threshold Computation

    private func computeAdaptiveThreshold(_ values: [Float]) -> Float {
        guard !values.isEmpty else {
            return 1.0
        }

        // Sort values to find percentile
        let sortedValues = values.sorted()
        let percentileIndex = Int(Float(sortedValues.count) * configuration.brightnessPercentile)
        let clampedIndex = min(percentileIndex, sortedValues.count - 1)

        let percentileThreshold = sortedValues[clampedIndex]

        // Use maximum of percentile threshold and minimum absolute threshold
        return max(percentileThreshold, configuration.minimumBrightnessThreshold)
    }

    /// Calculate baseline skin reflectivity (non-specular regions)
    /// Uses median of lower 60% of brightness values to avoid specular highlights
    private func calculateBaselineReflectivity(luminanceValues: [Float]) -> Float {
        guard !luminanceValues.isEmpty else {
            return 0.5
        }

        let sortedValues = luminanceValues.sorted()
        // Use 50th percentile (median) of non-highlight region
        let medianIndex = sortedValues.count / 2
        return sortedValues[medianIndex]
    }

    /// Detect relative specularity threshold based on deviation from baseline
    /// More reliable than absolute percentile across different lighting conditions
    private func detectRelativeSpecularity(luminanceValues: [Float], baseline: Float) -> Float {
        // Specular highlights are typically 30-50% brighter than baseline skin
        // Use 1.35x (35% brighter) as threshold
        let relativeMultiplier: Float = 1.35

        let relativeThreshold = baseline * relativeMultiplier

        // Still respect minimum absolute threshold to avoid false positives in very dark regions
        return max(relativeThreshold, configuration.minimumBrightnessThreshold)
    }

    // MARK: - Advanced Analysis

    /// Compute specular map (pixel-wise specular detection)
    /// Returns boolean array indicating which pixels are specular
    public func computeSpecularMap(_ sample: ROITextureSample) -> [Bool] {
        guard !sample.pixels.isEmpty else {
            return []
        }

        let luminanceValues = sample.pixels.map { pixel in
            Luminance.bt709LuminanceSRGB01(rgb01: pixel)
        }

        let threshold = computeAdaptiveThreshold(luminanceValues)

        return luminanceValues.map { $0 >= threshold }
    }

    /// Compute specular intensity distribution
    /// Returns mean and standard deviation of bright pixel intensities
    public func computeSpecularIntensityStats(_ sample: ROITextureSample) -> (mean: Float, stdDev: Float) {
        guard !sample.pixels.isEmpty else {
            return (0, 0)
        }

        let luminanceValues = sample.pixels.map { pixel in
            Luminance.bt709LuminanceSRGB01(rgb01: pixel)
        }

        let threshold = computeAdaptiveThreshold(luminanceValues)
        let brightPixels = luminanceValues.filter { $0 >= threshold }

        guard !brightPixels.isEmpty else {
            return (0, 0)
        }

        // Compute mean
        let mean = brightPixels.reduce(0, +) / Float(brightPixels.count)

        // Compute standard deviation
        var sumSquaredDiff: Float = 0
        for value in brightPixels {
            let diff = value - mean
            sumSquaredDiff += diff * diff
        }

        let variance = sumSquaredDiff / Float(brightPixels.count)
        let stdDev = sqrt(variance)

        return (mean, stdDev)
    }

    // MARK: - Alternative Methods

    /// Compute specular proxy using chromatic contrast
    /// Specular highlights tend to be achromatic (white/gray)
    public func computeSpecularProxyChromatic(_ sample: ROITextureSample) -> Float {
        guard !sample.pixels.isEmpty else {
            return 0
        }

        var specularPixelCount = 0

        for pixel in sample.pixels {
            // Compute luminance
            let luminance = 0.2126 * pixel.x + 0.7152 * pixel.y + 0.0722 * pixel.z

            // Check if bright enough
            guard luminance >= configuration.minimumBrightnessThreshold else {
                continue
            }

            // Compute chromatic difference (deviation from achromatic)
            let maxChannel = max(pixel.x, pixel.y, pixel.z)
            let minChannel = min(pixel.x, pixel.y, pixel.z)
            let chromaticDiff = maxChannel - minChannel

            // Specular highlights are achromatic (low chromatic difference)
            if chromaticDiff < 0.1 {
                specularPixelCount += 1
            }
        }

        let ratio = Float(specularPixelCount) / Float(sample.pixels.count)
        return min(ratio, configuration.maximumSpecularRatio)
    }

    /// Compute specular proxy using saturation threshold
    /// Specular highlights have low saturation
    /// FIXED: Now uses adaptive saturation threshold based on average skin saturation
    public func computeSpecularProxySaturation(_ sample: ROITextureSample) -> Float {
        guard !sample.pixels.isEmpty else {
            return 0
        }

        // SKIN-TONE ADAPTIVE: Calculate baseline saturation for this skin region
        // Darker skin may naturally have lower saturation, so threshold should adapt
        var totalSaturation: Float = 0
        var validPixelCount = 0

        for pixel in sample.pixels {
            let luminance = Luminance.bt709LuminanceSRGB01(rgb01: pixel)
            guard luminance >= 0.1 else { continue }  // Skip very dark pixels

            let maxChannel = max(pixel.x, pixel.y, pixel.z)
            let minChannel = min(pixel.x, pixel.y, pixel.z)
            let saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0
            totalSaturation += saturation
            validPixelCount += 1
        }

        // Calculate adaptive saturation threshold
        // If average saturation is low (darker skin), use lower threshold
        // If average saturation is high (lighter/more colorful skin), use higher threshold
        let avgSaturation = validPixelCount > 0 ? totalSaturation / Float(validPixelCount) : 0.2
        // Threshold = 40-60% of average saturation, clamped to reasonable range
        // This ensures specular detection works regardless of skin tone
        let adaptiveSaturationThreshold = max(0.08, min(0.25, avgSaturation * 0.5))

        var specularPixelCount = 0

        for pixel in sample.pixels {
            // Compute luminance
            let luminance = 0.2126 * pixel.x + 0.7152 * pixel.y + 0.0722 * pixel.z

            // Check if bright enough
            guard luminance >= configuration.minimumBrightnessThreshold else {
                continue
            }

            // Compute saturation (HSV)
            let maxChannel = max(pixel.x, pixel.y, pixel.z)
            let minChannel = min(pixel.x, pixel.y, pixel.z)
            let saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0

            // Low saturation = specular (using adaptive threshold)
            if saturation < adaptiveSaturationThreshold {
                specularPixelCount += 1
            }
        }

        let ratio = Float(specularPixelCount) / Float(sample.pixels.count)
        return min(ratio, configuration.maximumSpecularRatio)
    }
}
