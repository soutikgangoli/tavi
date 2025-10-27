//
//  SpecularAnalyzer.swift
//  Tavi
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
    public func computeSpecularProxy(_ sample: ROITextureSample) -> Float {
        guard !sample.pixels.isEmpty else {
            return 0
        }

        // Step 1: Convert to luminance (perceived brightness)
        let luminanceValues = sample.pixels.map { pixel in
            // Standard luminance: Y = 0.2126R + 0.7152G + 0.0722B
            return 0.2126 * pixel.x + 0.7152 * pixel.y + 0.0722 * pixel.z
        }

        // Step 2: Compute adaptive threshold using percentile
        let threshold = computeAdaptiveThreshold(luminanceValues)

        // Step 3: Count bright pixels above threshold
        let brightPixelCount = luminanceValues.filter { $0 >= threshold }.count

        // Step 4: Compute ratio
        let ratio = Float(brightPixelCount) / Float(sample.pixels.count)

        // Step 5: Clamp to maximum
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

    // MARK: - Advanced Analysis

    /// Compute specular map (pixel-wise specular detection)
    /// Returns boolean array indicating which pixels are specular
    public func computeSpecularMap(_ sample: ROITextureSample) -> [Bool] {
        guard !sample.pixels.isEmpty else {
            return []
        }

        let luminanceValues = sample.pixels.map { pixel in
            0.2126 * pixel.x + 0.7152 * pixel.y + 0.0722 * pixel.z
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
            0.2126 * pixel.x + 0.7152 * pixel.y + 0.0722 * pixel.z
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
    public func computeSpecularProxySaturation(_ sample: ROITextureSample) -> Float {
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

            // Compute saturation (HSV)
            let maxChannel = max(pixel.x, pixel.y, pixel.z)
            let minChannel = min(pixel.x, pixel.y, pixel.z)
            let saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0

            // Low saturation = specular
            if saturation < 0.15 {
                specularPixelCount += 1
            }
        }

        let ratio = Float(specularPixelCount) / Float(sample.pixels.count)
        return min(ratio, configuration.maximumSpecularRatio)
    }
}
