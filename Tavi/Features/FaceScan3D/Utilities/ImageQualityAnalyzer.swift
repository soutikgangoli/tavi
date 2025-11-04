//
//  ImageQualityAnalyzer.swift
//  Tavi
//
//  Analyze image quality (focus sharpness, exposure) for texture capture
//  Created on 2025-10-27.
//

import Foundation
import UIKit
import CoreImage
import Accelerate

/// Analyzes image quality for texture capture
public class ImageQualityAnalyzer {

    // MARK: - Configuration

    public struct Configuration {
        /// Minimum Laplacian variance for acceptable sharpness
        /// RELAXED: Lowered from 100 to 50 to account for TrueDepth camera characteristics
        /// and real-world conditions. Face scanning doesn't require perfect sharpness.
        public var minSharpnessThreshold: Float = 50.0

        /// Ideal exposure score (0.5 = middle gray)
        public var idealExposure: Float = 0.5

        /// Maximum deviation from ideal exposure
        public var maxExposureDeviation: Float = 0.3

        public init() {}
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Focus Sharpness

    /// Calculate focus sharpness using Laplacian variance
    /// Higher values = sharper image
    /// Typical range: 0-500, with >100 being acceptably sharp
    public func calculateSharpness(image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 0 }

        // Convert to grayscale
        let width = cgImage.width
        let height = cgImage.height

        var pixelData = [UInt8](repeating: 0, count: width * height)

        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Apply Laplacian filter
        var laplacian = [Float](repeating: 0, count: width * height)

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let idx = y * width + x

                let center = Float(pixelData[idx])
                let top = Float(pixelData[(y - 1) * width + x])
                let bottom = Float(pixelData[(y + 1) * width + x])
                let left = Float(pixelData[y * width + (x - 1)])
                let right = Float(pixelData[y * width + (x + 1)])

                // Laplacian kernel: center * 4 - (top + bottom + left + right)
                laplacian[idx] = center * 4 - (top + bottom + left + right)
            }
        }

        // Calculate variance of Laplacian
        var mean: Float = 0
        vDSP_meanv(laplacian, 1, &mean, vDSP_Length(laplacian.count))

        var variance: Float = 0
        for value in laplacian {
            let diff = value - mean
            variance += diff * diff
        }
        variance /= Float(laplacian.count)

        return variance
    }

    /// Check if image is acceptably sharp
    public func isSharp(image: UIImage) -> Bool {
        let sharpness = calculateSharpness(image: image)
        return sharpness >= configuration.minSharpnessThreshold
    }

    // MARK: - Exposure Analysis

    /// Calculate exposure score (0-1, where 0.5 is ideal middle gray)
    /// Values near 0 = underexposed, near 1 = overexposed
    /// SKIN-TONE AWARE: Accounts for darker skin tones having lower absolute brightness
    public func calculateExposure(image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 0.5 }

        let width = cgImage.width
        let height = cgImage.height

        var pixelData = [UInt8](repeating: 0, count: width * height)

        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Calculate average brightness (0-255 range)
        var sum: Float = 0
        for pixel in pixelData {
            sum += Float(pixel)
        }

        let avgBrightness = sum / Float(pixelData.count)

        // Calculate dynamic range (skin-tone independent metric)
        let minVal = pixelData.min() ?? 0
        let maxVal = pixelData.max() ?? 255
        let dynamicRange = Float(maxVal - minVal) / 255.0

        // Normalize to 0-1 range
        let rawExposure = avgBrightness / 255.0

        // SKIN-TONE AWARE ADJUSTMENT:
        // If good dynamic range (>30%) but low brightness (<40%), likely darker skin in good lighting
        // Adjust exposure score to account for this (map 20-40% brightness → 45-55% exposure)
        if dynamicRange > 0.30 && rawExposure < 0.40 {
            // Scale: 0.20 brightness → 0.45 exposure, 0.40 brightness → 0.55 exposure
            let adjustedExposure = 0.45 + (rawExposure - 0.20) * 0.5
            return max(0.0, min(1.0, adjustedExposure))  // Clamp to valid range
        }

        return rawExposure
    }

    /// Check if image is acceptably exposed
    public func isWellExposed(image: UIImage) -> Bool {
        let exposure = calculateExposure(image: image)
        let deviation = abs(exposure - configuration.idealExposure)
        return deviation <= configuration.maxExposureDeviation
    }

    /// Calculate histogram of image (for exposure analysis)
    public func calculateHistogram(image: UIImage) -> [Int] {
        guard let cgImage = image.cgImage else { return [Int](repeating: 0, count: 256) }

        let width = cgImage.width
        let height = cgImage.height

        var pixelData = [UInt8](repeating: 0, count: width * height)

        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Build histogram
        var histogram = [Int](repeating: 0, count: 256)
        for pixel in pixelData {
            histogram[Int(pixel)] += 1
        }

        return histogram
    }

    // MARK: - Combined Quality Check

    /// Complete quality check with detailed metrics
    public func analyzeQuality(image: UIImage) -> QualityMetrics {
        let sharpness = calculateSharpness(image: image)
        let exposure = calculateExposure(image: image)

        let isSharp = sharpness >= configuration.minSharpnessThreshold
        let isWellExposed = abs(exposure - configuration.idealExposure) <= configuration.maxExposureDeviation

        return QualityMetrics(
            sharpness: sharpness,
            isSharp: isSharp,
            exposure: exposure,
            isWellExposed: isWellExposed,
            overallQuality: isSharp && isWellExposed
        )
    }
}

// MARK: - Quality Metrics

public struct QualityMetrics {
    /// Laplacian variance (higher = sharper)
    public let sharpness: Float

    /// Whether image meets sharpness threshold
    public let isSharp: Bool

    /// Exposure score (0-1, 0.5 = ideal)
    public let exposure: Float

    /// Whether image is well exposed
    public let isWellExposed: Bool

    /// Overall quality pass/fail
    public let overallQuality: Bool

    public init(
        sharpness: Float,
        isSharp: Bool,
        exposure: Float,
        isWellExposed: Bool,
        overallQuality: Bool
    ) {
        self.sharpness = sharpness
        self.isSharp = isSharp
        self.exposure = exposure
        self.isWellExposed = isWellExposed
        self.overallQuality = overallQuality
    }
}
