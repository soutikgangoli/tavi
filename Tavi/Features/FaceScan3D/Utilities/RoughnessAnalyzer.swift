//
//  RoughnessAnalyzer.swift
//  Tavi
//
//  Compute roughness proxy from texture high-frequency energy
//  Created on 2025-10-27.
//

import Foundation
import UIKit
import Accelerate
import simd

/// Analyzes texture roughness using high-frequency energy
public class RoughnessAnalyzer {

    // MARK: - Configuration

    public struct Configuration {
        /// High-pass filter radius (pixels)
        public var filterRadius: Int = 3

        /// Normalization factor for energy
        public var normalizationFactor: Float = 10.0

        public init() {}
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Main API

    /// Compute roughness proxy from ROI texture sample
    /// Returns 0-1 score (higher = rougher)
    public func computeRoughnessProxy(_ sample: ROITextureSample) -> Float {
        // Convert to luminance
        let luminance = convertToLuminance(sample.pixels)

        guard !luminance.isEmpty else { return 0 }

        // Apply high-pass filter
        let highpass = applyHighPassFilter(luminance, width: sample.width, height: sample.height)

        // Compute mean luminance
        var meanLuma: Float = 0
        vDSP_meanv(luminance, 1, &meanLuma, vDSP_Length(luminance.count))

        // Compute mean of absolute high-pass values
        var absHighpass = highpass.map { abs($0) }
        var meanHighpass: Float = 0
        vDSP_meanv(absHighpass, 1, &meanHighpass, vDSP_Length(absHighpass.count))

        // Normalized energy = mean(abs(highpass)) / mean(luma)
        let normalizedEnergy = meanLuma > 0 ? meanHighpass / meanLuma : 0

        // Scale to 0-1 range
        let roughnessProxy = min(normalizedEnergy * configuration.normalizationFactor, 1.0)

        return roughnessProxy
    }

    // MARK: - Luminance Conversion

    /// Convert RGB pixels to luminance (grayscale)
    private func convertToLuminance(_ pixels: [SIMD3<Float>]) -> [Float] {
        var luminance = [Float](repeating: 0, count: pixels.count)

        for (i, pixel) in pixels.enumerated() {
            // Standard luminance formula: Y = 0.299R + 0.587G + 0.114B
            luminance[i] = 0.299 * pixel.x + 0.587 * pixel.y + 0.114 * pixel.z
        }

        return luminance
    }

    // MARK: - High-Pass Filter

    /// Apply high-pass filter using unsharp mask approach
    /// highpass = original - lowpass(original)
    private func applyHighPassFilter(
        _ luminance: [Float],
        width: Int,
        height: Int
    ) -> [Float] {

        // Create 2D array
        var image2D = Array(repeating: Array(repeating: Float(0), count: width), count: height)
        var idx = 0

        for y in 0..<height {
            for x in 0..<width {
                if idx < luminance.count {
                    image2D[y][x] = luminance[idx]
                    idx += 1
                }
            }
        }

        // Apply Gaussian blur (low-pass)
        let blurred = applyGaussianBlur(image2D, width: width, height: height)

        // High-pass = original - blurred
        var highpass = [Float](repeating: 0, count: luminance.count)
        idx = 0

        for y in 0..<height {
            for x in 0..<width {
                if idx < luminance.count {
                    highpass[idx] = luminance[idx] - blurred[y][x]
                    idx += 1
                }
            }
        }

        return highpass
    }

    /// Apply Gaussian blur (box blur approximation)
    private func applyGaussianBlur(
        _ image: [[Float]],
        width: Int,
        height: Int
    ) -> [[Float]] {

        var blurred = Array(repeating: Array(repeating: Float(0), count: width), count: height)
        let radius = configuration.filterRadius

        for y in 0..<height {
            for x in 0..<width {
                var sum: Float = 0
                var count: Float = 0

                // Box filter kernel
                for dy in -radius...radius {
                    for dx in -radius...radius {
                        let ny = y + dy
                        let nx = x + dx

                        if ny >= 0 && ny < height && nx >= 0 && nx < width {
                            sum += image[ny][nx]
                            count += 1
                        }
                    }
                }

                blurred[y][x] = count > 0 ? sum / count : 0
            }
        }

        return blurred
    }

    // MARK: - Alternative Methods

    /// Compute roughness using Laplacian variance (alternative method)
    public func computeRoughnessLaplacian(_ sample: ROITextureSample) -> Float {
        let luminance = convertToLuminance(sample.pixels)

        guard !luminance.isEmpty else { return 0 }

        // Create 2D array
        var image2D = Array(repeating: Array(repeating: Float(0), count: sample.width), count: sample.height)
        var idx = 0

        for y in 0..<sample.height {
            for x in 0..<sample.width {
                if idx < luminance.count {
                    image2D[y][x] = luminance[idx]
                    idx += 1
                }
            }
        }

        // Apply Laplacian filter
        var laplacian: [Float] = []

        for y in 1..<(sample.height - 1) {
            for x in 1..<(sample.width - 1) {
                let center = image2D[y][x]
                let top = image2D[y - 1][x]
                let bottom = image2D[y + 1][x]
                let left = image2D[y][x - 1]
                let right = image2D[y][x + 1]

                // Laplacian kernel: center * 4 - (top + bottom + left + right)
                let lap = center * 4 - (top + bottom + left + right)
                laplacian.append(lap)
            }
        }

        // Compute variance
        guard !laplacian.isEmpty else { return 0 }

        var mean: Float = 0
        vDSP_meanv(laplacian, 1, &mean, vDSP_Length(laplacian.count))

        var variance: Float = 0
        for value in laplacian {
            let diff = value - mean
            variance += diff * diff
        }
        variance /= Float(laplacian.count)

        // Normalize to 0-1 range (variance typically 0-100 for natural images)
        let roughnessProxy = min(sqrt(variance) / 10.0, 1.0)

        return roughnessProxy
    }
}
