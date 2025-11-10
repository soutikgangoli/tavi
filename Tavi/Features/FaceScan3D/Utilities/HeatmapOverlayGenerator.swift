//
//  HeatmapOverlayGenerator.swift
//  Tavi
//
//  Generate heatmap overlays for 3D face metrics visualization
//  Created on 2025-10-27.
//

import Foundation
import UIKit
import CoreGraphics
import simd

/// Generates visual overlays for 3D face metrics
public class HeatmapOverlayGenerator {

    // MARK: - Configuration

    public struct Configuration {
        /// Overlay opacity (0-1)
        public var overlayAlpha: CGFloat = 0.6

        /// Heatmap color scheme
        public var lowValueColor: UIColor = .green
        public var midValueColor: UIColor = .yellow
        public var highValueColor: UIColor = .red

        /// ROI outline color
        public var roiOutlineColor: UIColor = .white
        public var roiOutlineWidth: CGFloat = 2.0

        /// Discoloration delta visualization
        public var showDeltaLabels: Bool = true
        public var deltaLabelFontSize: CGFloat = 12.0

        public init() {}
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Main API

    /// Generate heatmap overlay by compositing intensity map with base texture
    public func generateHeatmapOverlay(
        _ baseTexture: CGImage,
        intensityMap: CGImage,
        mask: UIMask?
    ) -> CGImage? {

        let width = baseTexture.width
        let height = baseTexture.height

        // Create color space and context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        // Draw base texture
        context.draw(baseTexture, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Draw intensity map with alpha blending
        context.setAlpha(configuration.overlayAlpha)
        context.draw(intensityMap, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Draw mask outline if provided
        if let mask = mask {
            drawROIOutline(mask: mask, in: context, width: width, height: height)
        }

        return context.makeImage()
    }

    /// Generate intensity map from ROI metrics
    public func generateIntensityMap(
        metrics: Face3DMetrics,
        type: AnalysisMetricType,
        resolution: CGSize
    ) -> CGImage? {

        let width = Int(resolution.width)
        let height = Int(resolution.height)

        // Create pixel buffer
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        // Fill each ROI with color based on metric value
        for (roi, roiMetrics) in metrics.roiMetrics {
            let value = type.getValue(from: roiMetrics)
            let color = colorForValue(value)

            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)

            let bounds = roi.uvBounds

            // Fill pixels in this ROI
            for y in 0..<height {
                for x in 0..<width {
                    let u = Float(x) / Float(width)
                    let v = 1.0 - Float(y) / Float(height)

                    if bounds.contains(u: u, v: v) {
                        let idx = (y * width + x) * 4
                        pixelData[idx] = UInt8(r * 255)
                        pixelData[idx + 1] = UInt8(g * 255)
                        pixelData[idx + 2] = UInt8(b * 255)
                        pixelData[idx + 3] = 255
                    }
                }
            }
        }

        // Create image from pixel data
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let provider = CGDataProvider(
            data: Data(pixelData) as CFData
        ) else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    /// Generate discoloration overlay with ROI outlines and delta labels
    public func generateDiscolorationOverlay(
        metrics: Face3DMetrics,
        resolution: CGSize
    ) -> UIImage? {

        let width = resolution.width
        let height = resolution.height

        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        // Compute ROI LAB means and global mean
        var roiLABMeans: [Face3DROI: (l: Float, a: Float, b: Float)] = [:]
        var globalL: Float = 0
        var globalA: Float = 0
        var totalPixels: Int = 0

        for (roi, roiMetrics) in metrics.roiMetrics {
            roiLABMeans[roi] = (
                roiMetrics.averageLightness,
                roiMetrics.averageAChannel,
                roiMetrics.averageBChannel
            )
            globalL += roiMetrics.averageLightness * Float(roiMetrics.pixelCount)
            globalA += roiMetrics.averageAChannel * Float(roiMetrics.pixelCount)
            totalPixels += roiMetrics.pixelCount
        }

        if totalPixels > 0 {
            globalL /= Float(totalPixels)
            globalA /= Float(totalPixels)
        }

        // Draw each ROI
        for roi in Face3DROI.allCases {
            guard let labMean = roiLABMeans[roi] else { continue }

            let bounds = roi.uvBounds

            // Convert UV bounds to screen coordinates
            let rect = CGRect(
                x: CGFloat(bounds.minU) * width,
                y: CGFloat(1.0 - bounds.maxV) * height,  // Flip V
                width: CGFloat(bounds.maxU - bounds.minU) * width,
                height: CGFloat(bounds.maxV - bounds.minV) * height
            )

            // Draw outline
            context.setStrokeColor(configuration.roiOutlineColor.cgColor)
            context.setLineWidth(configuration.roiOutlineWidth)
            context.stroke(rect)

            // Compute delta from global mean
            let deltaL = labMean.l - globalL
            let deltaA = labMean.a - globalA

            // Draw label if enabled
            if configuration.showDeltaLabels {
                let labelText = String(format: "ΔL*: %.1f\nΔA*: %.1f", deltaL, deltaA)

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center

                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: configuration.deltaLabelFontSize, weight: .semibold),
                    .foregroundColor: configuration.roiOutlineColor,
                    .paragraphStyle: paragraphStyle,
                    .strokeColor: UIColor.black,
                    .strokeWidth: -2.0
                ]

                let labelSize = labelText.size(withAttributes: attributes)
                let labelRect = CGRect(
                    x: rect.midX - labelSize.width / 2,
                    y: rect.midY - labelSize.height / 2,
                    width: labelSize.width,
                    height: labelSize.height
                )

                labelText.draw(in: labelRect, withAttributes: attributes)
            }
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }

    /// Generate combined overlay with multiple metric layers
    public func generateCombinedOverlay(
        baseTexture: CGImage,
        metrics: Face3DMetrics,
        layers: [OverlayLayer]
    ) -> CGImage? {

        var currentImage = baseTexture

        for layer in layers {
            guard layer.enabled else { continue }

            let overlayImage: CGImage?

            switch layer.type {
            case .roughness:
                overlayImage = generateIntensityMap(
                    metrics: metrics,
                    type: .roughness,
                    resolution: CGSize(width: baseTexture.width, height: baseTexture.height)
                )

            case .pigmentation:
                overlayImage = generateIntensityMap(
                    metrics: metrics,
                    type: .pigmentation,
                    resolution: CGSize(width: baseTexture.width, height: baseTexture.height)
                )

            case .discoloration:
                if let uiImage = generateDiscolorationOverlay(
                    metrics: metrics,
                    resolution: CGSize(width: baseTexture.width, height: baseTexture.height)
                ) {
                    overlayImage = uiImage.cgImage
                } else {
                    overlayImage = nil
                }

            case .specular:
                overlayImage = generateIntensityMap(
                    metrics: metrics,
                    type: .specular,
                    resolution: CGSize(width: baseTexture.width, height: baseTexture.height)
                )
            }

            if let overlayImage = overlayImage {
                currentImage = generateHeatmapOverlay(
                    currentImage,
                    intensityMap: overlayImage,
                    mask: nil
                ) ?? currentImage
            }
        }

        return currentImage
    }

    // MARK: - Helpers

    private func drawROIOutline(mask: UIMask, in context: CGContext, width: Int, height: Int) {
        let bounds = mask.bounds

        let rect = CGRect(
            x: CGFloat(bounds.minU) * CGFloat(width),
            y: CGFloat(1.0 - bounds.maxV) * CGFloat(height),
            width: CGFloat(bounds.maxU - bounds.minU) * CGFloat(width),
            height: CGFloat(bounds.maxV - bounds.minV) * CGFloat(height)
        )

        context.setStrokeColor(configuration.roiOutlineColor.cgColor)
        context.setLineWidth(configuration.roiOutlineWidth)
        context.stroke(rect)
    }

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

// MARK: - Overlay Layer

/// Overlay layer configuration
public struct OverlayLayer {
    public let type: OverlayType
    public var enabled: Bool

    public init(type: OverlayType, enabled: Bool = true) {
        self.type = type
        self.enabled = enabled
    }
}

// Note: OverlayType is defined in FaceScan3DAPI.swift
