//
//  HeatmapGenerator.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import CoreGraphics
import UIKit
import Accelerate

/// Generates heatmap overlays for metric visualization
public class HeatmapGenerator {

    // MARK: - Configuration

    public struct Configuration {
        /// Opacity of heatmap overlay (0.0-1.0)
        public let overlayOpacity: Double

        /// Gaussian blur radius for smoothing
        public let blurRadius: Int

        /// Interpolation quality
        public let interpolationQuality: CGInterpolationQuality

        public init(
            overlayOpacity: Double = 0.5,
            blurRadius: Int = 15,
            interpolationQuality: CGInterpolationQuality = .high
        ) {
            self.overlayOpacity = overlayOpacity
            self.blurRadius = blurRadius
            self.interpolationQuality = interpolationQuality
        }

        public static let `default` = Configuration()
    }

    // MARK: - Properties

    private let configuration: Configuration

    // MARK: - Initialization

    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    // MARK: - Main Generation Method

    /// Generate heatmap overlay from face image and metric values
    /// - Parameters:
    ///   - faceImage: Base face image
    ///   - metricMap: Dictionary mapping ROI types to metric values (0-100%)
    ///   - roiSet: Face ROI set with region definitions
    /// - Returns: Composite image with heatmap overlay
    public func generateHeatmap(
        faceImage: CGImage,
        metricMap: [ROIType: Double],
        roiSet: FaceROISet
    ) throws -> CGImage {
        let width = faceImage.width
        let height = faceImage.height

        // Create metric value map for each pixel
        let valueMap = createValueMap(
            width: width,
            height: height,
            metricMap: metricMap,
            roiSet: roiSet
        )

        // Apply Gaussian blur for smooth transitions
        let smoothedMap = try applyGaussianBlur(
            valueMap: valueMap,
            width: width,
            height: height,
            radius: configuration.blurRadius
        )

        // Generate color heatmap
        let heatmapImage = try createColorHeatmap(
            valueMap: smoothedMap,
            width: width,
            height: height
        )

        // Composite with original image
        let composite = try compositeImages(
            baseImage: faceImage,
            overlayImage: heatmapImage,
            opacity: configuration.overlayOpacity
        )

        return composite
    }

    /// Generate heatmap overlay with ROI masks
    /// - Parameters:
    ///   - faceImage: Base face image
    ///   - roiImages: Array of extracted ROI images with metrics
    ///   - scores: Score summary with per-ROI scores
    ///   - roiSet: Face ROI set with region definitions
    /// - Returns: Composite image with heatmap overlay
    public func generateHeatmapFromScores(
        faceImage: CGImage,
        scores: ScoreSummary,
        roiSet: FaceROISet
    ) throws -> CGImage {
        // Extract metric values from scores
        var metricMap: [ROIType: Double] = [:]

        for (roiType, roiScores) in scores.roiScores {
            // Use composite score as overall metric
            metricMap[roiType] = roiScores.compositeScore
        }

        return try generateHeatmap(
            faceImage: faceImage,
            metricMap: metricMap,
            roiSet: roiSet
        )
    }

    // MARK: - Value Map Creation

    /// Create pixel-wise value map from ROI metrics
    private func createValueMap(
        width: Int,
        height: Int,
        metricMap: [ROIType: Double],
        roiSet: FaceROISet
    ) -> [Double] {
        var valueMap = [Double](repeating: -1.0, count: width * height)

        // Fill each ROI region with its metric value
        for (roiType, value) in metricMap {
            guard let roi = roiSet.rois[roiType] else { continue }

            let rect = roi.imageRect
            let minX = Int(rect.minX.rounded())
            let minY = Int(rect.minY.rounded())
            let maxX = Int(rect.maxX.rounded())
            let maxY = Int(rect.maxY.rounded())

            for y in max(0, minY)..<min(height, maxY) {
                for x in max(0, minX)..<min(width, maxX) {
                    let index = y * width + x
                    valueMap[index] = value / 100.0  // Normalize to 0-1
                }
            }
        }

        // Fill unmapped regions with average value
        let mappedValues = valueMap.filter { $0 >= 0 }
        let averageValue = mappedValues.isEmpty ? 0.5 : mappedValues.reduce(0, +) / Double(mappedValues.count)

        for i in 0..<valueMap.count {
            if valueMap[i] < 0 {
                valueMap[i] = averageValue
            }
        }

        return valueMap
    }

    // MARK: - Gaussian Blur

    /// Apply Gaussian blur for smooth transitions
    private func applyGaussianBlur(
        valueMap: [Double],
        width: Int,
        height: Int,
        radius: Int
    ) throws -> [Double] {
        guard radius > 0 else { return valueMap }

        var result = valueMap
        let kernelSize = radius * 2 + 1

        // Create Gaussian kernel
        let sigma = Double(radius) / 3.0
        var kernel = [Double](repeating: 0, count: kernelSize)
        var kernelSum: Double = 0

        for i in 0..<kernelSize {
            let x = Double(i - radius)
            kernel[i] = exp(-(x * x) / (2.0 * sigma * sigma))
            kernelSum += kernel[i]
        }

        // Normalize kernel
        for i in 0..<kernelSize {
            kernel[i] /= kernelSum
        }

        // Horizontal pass
        var temp = [Double](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                var sum: Double = 0
                var weightSum: Double = 0

                for k in 0..<kernelSize {
                    let sx = x + k - radius
                    if sx >= 0 && sx < width {
                        sum += valueMap[y * width + sx] * kernel[k]
                        weightSum += kernel[k]
                    }
                }

                temp[y * width + x] = sum / weightSum
            }
        }

        // Vertical pass
        for y in 0..<height {
            for x in 0..<width {
                var sum: Double = 0
                var weightSum: Double = 0

                for k in 0..<kernelSize {
                    let sy = y + k - radius
                    if sy >= 0 && sy < height {
                        sum += temp[sy * width + x] * kernel[k]
                        weightSum += kernel[k]
                    }
                }

                result[y * width + x] = sum / weightSum
            }
        }

        return result
    }

    // MARK: - Color Mapping

    /// Create color heatmap from value map
    /// Blue (low) → Green → Yellow → Red (high)
    private func createColorHeatmap(
        valueMap: [Double],
        width: Int,
        height: Int
    ) throws -> CGImage {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let value = valueMap[index]

                let color = valueToColor(value)

                let offset = (y * width + x) * bytesPerPixel
                pixelData[offset] = color.b      // B
                pixelData[offset + 1] = color.g  // G
                pixelData[offset + 2] = color.r  // R
                pixelData[offset + 3] = 255      // A
            }
        }

        guard let provider = CGDataProvider(data: Data(pixelData) as CFData) else {
            throw HeatmapError.imageCreationFailed
        }

        guard let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            throw HeatmapError.imageCreationFailed
        }

        return image
    }

    /// Convert value (0-1) to RGB color (blue → red spectrum)
    private func valueToColor(_ value: Double) -> (r: UInt8, g: UInt8, b: UInt8) {
        let clamped = max(0.0, min(1.0, value))

        // Blue → Cyan → Green → Yellow → Red
        if clamped < 0.25 {
            // Blue → Cyan
            let t = clamped / 0.25
            return (
                r: 0,
                g: UInt8(t * 255),
                b: 255
            )
        } else if clamped < 0.5 {
            // Cyan → Green
            let t = (clamped - 0.25) / 0.25
            return (
                r: 0,
                g: 255,
                b: UInt8((1.0 - t) * 255)
            )
        } else if clamped < 0.75 {
            // Green → Yellow
            let t = (clamped - 0.5) / 0.25
            return (
                r: UInt8(t * 255),
                g: 255,
                b: 0
            )
        } else {
            // Yellow → Red
            let t = (clamped - 0.75) / 0.25
            return (
                r: 255,
                g: UInt8((1.0 - t) * 255),
                b: 0
            )
        }
    }

    // MARK: - Image Composition

    /// Composite heatmap overlay with base image
    private func compositeImages(
        baseImage: CGImage,
        overlayImage: CGImage,
        opacity: Double
    ) throws -> CGImage {
        let width = baseImage.width
        let height = baseImage.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw HeatmapError.contextCreationFailed
        }

        // Draw base image
        context.draw(baseImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Draw overlay with opacity
        context.setAlpha(opacity)
        context.draw(overlayImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let composite = context.makeImage() else {
            throw HeatmapError.imageCreationFailed
        }

        return composite
    }

    // MARK: - Batch Generation

    /// Generate heatmaps for multiple metrics
    public func generateMultipleHeatmaps(
        faceImage: CGImage,
        scores: ScoreSummary,
        roiSet: FaceROISet,
        metrics: [HeatmapMetric]
    ) throws -> [HeatmapMetric: CGImage] {
        var heatmaps: [HeatmapMetric: CGImage] = [:]

        for metric in metrics {
            var metricMap: [ROIType: Double] = [:]

            for (roiType, roiScores) in scores.roiScores {
                let value: Double
                switch metric {
                case .composite:
                    value = roiScores.compositeScore
                case .sharpness:
                    value = roiScores.sharpnessScore
                case .texture:
                    value = roiScores.textureScore
                case .pigmentation:
                    value = roiScores.pigmentationScore
                case .moisture:
                    value = roiScores.moistureScore
                }
                metricMap[roiType] = value
            }

            let heatmap = try generateHeatmap(
                faceImage: faceImage,
                metricMap: metricMap,
                roiSet: roiSet
            )

            heatmaps[metric] = heatmap
        }

        return heatmaps
    }
}

// MARK: - Heatmap Metric

public enum HeatmapMetric: String, CaseIterable {
    case composite = "Overall Quality"
    case sharpness = "Sharpness"
    case texture = "Texture Quality"
    case pigmentation = "Pigmentation"
    case moisture = "Moisture Level"

    public var displayName: String {
        return rawValue
    }

    public var icon: String {
        switch self {
        case .composite:
            return "star.fill"
        case .sharpness:
            return "camera.aperture"
        case .texture:
            return "waveform"
        case .pigmentation:
            return "paintpalette"
        case .moisture:
            return "drop.fill"
        }
    }
}

// MARK: - Errors

public enum HeatmapError: Error, LocalizedError {
    case imageCreationFailed
    case contextCreationFailed
    case invalidImageSize

    public var errorDescription: String? {
        switch self {
        case .imageCreationFailed:
            return "Failed to create heatmap image"
        case .contextCreationFailed:
            return "Failed to create graphics context"
        case .invalidImageSize:
            return "Invalid image dimensions"
        }
    }
}
