//
//  MetricsVisualizer.swift
//  Tavi
//
//  Visualize 3D face metrics as heatmaps and overlays
//  Created on 2025-10-27.
//

import Foundation
import UIKit
import CoreGraphics
import simd

/// Creates visual representations of 3D face metrics
public class MetricsVisualizer {

    // MARK: - Configuration

    public struct Configuration {
        /// Heatmap resolution
        public var heatmapWidth: Int = 512
        public var heatmapHeight: Int = 512

        /// Color scheme for heatmaps
        public var lowValueColor: UIColor = .green
        public var midValueColor: UIColor = .yellow
        public var highValueColor: UIColor = .red

        /// Overlay opacity
        public var overlayAlpha: CGFloat = 0.6

        public init() {}
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Main API

    /// Generate visualization for metrics
    public func generateVisualization(
        for metrics: Face3DMetrics,
        type: MetricType
    ) -> MetricVisualization {

        // Generate heatmap
        let heatmap = generateHeatmap(for: metrics, type: type)

        // Generate ROI boundaries
        let boundaries = generateROIBoundaries(for: metrics)

        // Generate legend
        let legend = generateLegendColors()

        return MetricVisualization(
            heatmapImage: heatmap,
            roiBoundaries: boundaries,
            legendColors: legend
        )
    }

    // MARK: - Heatmap Generation

    private func generateHeatmap(
        for metrics: Face3DMetrics,
        type: MetricType
    ) -> UIImage? {

        let width = configuration.heatmapWidth
        let height = configuration.heatmapHeight

        // Create color buffer
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        // For each ROI, fill with color based on metric value
        for (roi, roiMetrics) in metrics.roiMetrics {
            let value = type.getValue(from: roiMetrics)
            let color = colorForValue(value)

            let bounds = roi.uvBounds

            // Fill pixels in this ROI
            for y in 0..<height {
                for x in 0..<width {
                    let u = Float(x) / Float(width)
                    let v = 1.0 - Float(y) / Float(height)

                    if bounds.contains(u: u, v: v) {
                        let idx = (y * width + x) * 4

                        var r: CGFloat = 0
                        var g: CGFloat = 0
                        var b: CGFloat = 0
                        var a: CGFloat = 0

                        color.getRed(&r, green: &g, blue: &b, alpha: &a)

                        pixelData[idx] = UInt8(r * 255)
                        pixelData[idx + 1] = UInt8(g * 255)
                        pixelData[idx + 2] = UInt8(b * 255)
                        pixelData[idx + 3] = UInt8(configuration.overlayAlpha * 255)
                    }
                }
            }
        }

        // Create image from pixel data
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ), let cgImage = context.makeImage() else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - ROI Boundaries

    private func generateROIBoundaries(
        for metrics: Face3DMetrics
    ) -> [Face3DROI: UIBezierPath] {

        var boundaries: [Face3DROI: UIBezierPath] = [:]

        for roi in Face3DROI.allCases {
            let path = UIBezierPath()
            let bounds = roi.uvBounds

            // Create rectangle path
            let rect = CGRect(
                x: CGFloat(bounds.minU),
                y: CGFloat(1.0 - bounds.maxV),  // Flip V
                width: CGFloat(bounds.maxU - bounds.minU),
                height: CGFloat(bounds.maxV - bounds.minV)
            )

            path.append(UIBezierPath(rect: rect))

            boundaries[roi] = path
        }

        return boundaries
    }

    // MARK: - Legend Colors

    /// Generate legend colors with percentage scale (0-100)
    private func generateLegendColors() -> [Float: UIColor] {
        return [
            0.0: configuration.lowValueColor,    // 0%
            50.0: configuration.midValueColor,   // 50%
            100.0: configuration.highValueColor  // 100%
        ]
    }

    // MARK: - Color Mapping

    /// Map raw metric value (0-1) to color for heatmap
    /// Note: This works with raw metric values, not percentage scores
    private func colorForValue(_ value: Float) -> UIColor {
        let clampedValue = max(0, min(1, value))

        if clampedValue < 0.5 {
            // Interpolate between low and mid
            let t = CGFloat(clampedValue * 2.0)
            return interpolateColor(
                from: configuration.lowValueColor,
                to: configuration.midValueColor,
                t: t
            )
        } else {
            // Interpolate between mid and high
            let t = CGFloat((clampedValue - 0.5) * 2.0)
            return interpolateColor(
                from: configuration.midValueColor,
                to: configuration.highValueColor,
                t: t
            )
        }
    }

    /// Interpolate between two colors
    private func interpolateColor(from: UIColor, to: UIColor, t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }
}

// MARK: - Metric Type

/// Type of metric to visualize
public enum MetricType {
    case roughness
    case pigmentation
    case luminance
    case lightness
    case specular
    case roughnessScore
    case pigmentationScore
    case specularScore

    func getValue(from metrics: ROI3DMetrics) -> Float {
        switch self {
        case .roughness:
            return metrics.roughnessProxy
        case .pigmentation:
            return metrics.pigmentationIndex
        case .luminance:
            return metrics.averageLuminance
        case .lightness:
            return metrics.averageLightness / 100.0  // Normalize L* (0-100) to 0-1
        case .specular:
            return metrics.specularProxy ?? 0
        case .roughnessScore:
            return metrics.roughnessScore / 10.0  // Normalize 0-10 to 0-1
        case .pigmentationScore:
            return metrics.pigmentationScore / 10.0  // Normalize 0-10 to 0-1
        case .specularScore:
            return (metrics.specularScore ?? 0) / 10.0  // Normalize 0-10 to 0-1
        }
    }

    var displayName: String {
        switch self {
        case .roughness: return "Roughness"
        case .pigmentation: return "Pigmentation"
        case .luminance: return "Luminance"
        case .lightness: return "Lightness"
        case .specular: return "Specular/Oiliness"
        case .roughnessScore: return "Roughness Score"
        case .pigmentationScore: return "Pigmentation Score"
        case .specularScore: return "Specular Score"
        }
    }
}
