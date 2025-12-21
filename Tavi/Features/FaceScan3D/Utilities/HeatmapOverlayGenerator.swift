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
        /// Overlay opacity (0-1) - slightly reduced for thermal palette visibility
        public var overlayAlpha: CGFloat = 0.45

        /// Thermal medical heatmap color scheme (legacy compatibility)
        /// Deep Blue (excellent) → Teal (good) → Soft Orange (attention)
        public var lowValueColor: UIColor = UIColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1)  // Deep Blue #3B82F6
        public var midValueColor: UIColor = UIColor(red: 0.08, green: 0.72, blue: 0.65, alpha: 1)  // Teal #14B8A6
        public var highValueColor: UIColor = UIColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 1) // Soft Orange #F97316

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
            // V is now in screen coordinate system (0=top, 1=bottom)
            for y in 0..<height {
                for x in 0..<width {
                    let u = Float(x) / Float(width)
                    let v = Float(y) / Float(height)

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

        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0.0)
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
            // V is already in screen coordinate system (0=top, 1=bottom)
            let rect = CGRect(
                x: CGFloat(bounds.minU) * width,
                y: CGFloat(bounds.minV) * height,
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

        // V is already in screen coordinate system (0=top, 1=bottom)
        let rect = CGRect(
            x: CGFloat(bounds.minU) * CGFloat(width),
            y: CGFloat(bounds.minV) * CGFloat(height),
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

    // MARK: - Regional Heatmap Generation

    /// Generate mesh-based heatmap that follows actual face mesh triangles
    /// Falls back to ellipse-based method if mesh is not available
    /// - Parameters:
    ///   - mesh: Optional unified face mesh from ARKit
    ///   - baseTexture: Base face texture to overlay on
    ///   - metrics: Face3DMetrics containing scores per ROI
    ///   - metricType: Type of heatmap to generate
    /// - Returns: UIImage with heatmap overlay
    public func generateMeshBasedHeatmap(
        mesh: UnifiedMesh?,
        baseTexture: CGImage,
        metrics: Face3DMetrics,
        metricType: BeautifulHeatmapType
    ) -> UIImage? {
        // DISABLED: Mesh-based rendering produces jagged triangle artifacts
        // The ARKit mesh has sparse coverage and sharp edges that don't look good
        // Always use the smooth ellipse-based gradient method instead
        //
        // TODO: If mesh-based rendering is needed in the future, apply:
        // 1. Gaussian blur to smooth edges
        // 2. Filter out triangles outside face bounds
        // 3. Edge feathering for smooth transitions

        // Use smooth ellipse-based gradient method (looks professional)
        return generateBeautifulHeatmap(
            baseTexture: baseTexture,
            metrics: metrics,
            metricType: metricType
        )
    }

    /// Generate a modern, gradient-based heatmap with smooth elliptical zones
    /// Each region gets a gradient fill that looks like a professional thermal map
    public func generateBeautifulHeatmap(
        baseTexture: CGImage,
        metrics: Face3DMetrics,
        metricType: BeautifulHeatmapType
    ) -> UIImage? {
        let width = baseTexture.width
        let height = baseTexture.height
        let size = CGSize(width: width, height: height)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let result = renderer.image { rendererContext in
            let context = rendererContext.cgContext

            // CRITICAL: Flip the coordinate system for CGImage drawing
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1.0, y: -1.0)

            // Draw the base face texture (right-side up)
            let rect = CGRect(origin: .zero, size: size)
            context.draw(baseTexture, in: rect)

            // Reset transform for overlay drawing
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: 0, y: -size.height)

            // Draw gradient overlays for EACH face region
            for roi in Face3DROI.allCases {
                let regionScore = getRegionScore(roi: roi, metrics: metrics, metricType: metricType)
                let regionColor = colorForScore(regionScore)

                let bounds = roi.uvBounds
                let regionRect = uvBoundsToRect(bounds, in: size)

                // Create elliptical gradient for organic look
                drawGradientZone(
                    in: context,
                    rect: regionRect,
                    color: regionColor,
                    score: regionScore
                )
            }

            // Draw score labels on top (second pass for visibility)
            for roi in Face3DROI.allCases {
                let regionScore = getRegionScore(roi: roi, metrics: metrics, metricType: metricType)
                let regionColor = colorForScore(regionScore)
                let bounds = roi.uvBounds
                let regionRect = uvBoundsToRect(bounds, in: size)

                drawModernScoreLabel(
                    score: regionScore,
                    in: regionRect,
                    color: regionColor
                )
            }
        }

        return result
    }

    /// Draw a smooth gradient zone with elliptical shape
    private func drawGradientZone(in context: CGContext, rect: CGRect, color: UIColor, score: Float) {
        context.saveGState()

        // Create elliptical path for organic look
        let ellipseRect = rect.insetBy(dx: rect.width * 0.05, dy: rect.height * 0.05)
        let ellipsePath = UIBezierPath(ovalIn: ellipseRect)

        // Clip to ellipse
        context.addPath(ellipsePath.cgPath)
        context.clip()

        // Draw radial gradient from center (more opaque) to edge (transparent)
        let centerPoint = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(rect.width, rect.height) / 2

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        let colors = [
            UIColor(red: r, green: g, blue: b, alpha: 0.5).cgColor,
            UIColor(red: r, green: g, blue: b, alpha: 0.3).cgColor,
            UIColor(red: r, green: g, blue: b, alpha: 0.0).cgColor
        ] as CFArray

        let locations: [CGFloat] = [0.0, 0.6, 1.0]

        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
            context.drawRadialGradient(
                gradient,
                startCenter: centerPoint,
                startRadius: 0,
                endCenter: centerPoint,
                endRadius: radius,
                options: [.drawsAfterEndLocation]
            )
        }

        context.restoreGState()
    }

    /// Draw modern score label with pill background
    private func drawModernScoreLabel(score: Float, in rect: CGRect, color: UIColor) {
        let scoreText = "\(Int(score))"

        // Calculate font size based on region size
        let baseFontSize = min(rect.width, rect.height) * 0.28
        let fontSize = max(16, min(baseFontSize, 36))

        // Pill dimensions
        let pillWidth = fontSize * 2.0
        let pillHeight = fontSize * 1.4
        let pillRect = CGRect(
            x: rect.midX - pillWidth / 2,
            y: rect.midY - pillHeight / 2,
            width: pillWidth,
            height: pillHeight
        )

        // Draw pill background with shadow
        let pillPath = UIBezierPath(roundedRect: pillRect, cornerRadius: pillHeight / 2)

        // Shadow
        UIColor.black.withAlphaComponent(0.3).setFill()
        let shadowRect = pillRect.offsetBy(dx: 2, dy: 2)
        UIBezierPath(roundedRect: shadowRect, cornerRadius: pillHeight / 2).fill()

        // White background
        UIColor.white.setFill()
        pillPath.fill()

        // Colored border
        color.setStroke()
        pillPath.lineWidth = 3.0
        pillPath.stroke()

        // Draw score text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let textSize = scoreText.size(withAttributes: attributes)
        let textRect = CGRect(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )

        scoreText.draw(in: textRect, withAttributes: attributes)
    }

    /// Get the score for a specific region based on metric type
    private func getRegionScore(roi: Face3DROI, metrics: Face3DMetrics, metricType: BeautifulHeatmapType) -> Float {
        // Try to get region-specific metrics
        if let roiMetrics = metrics.roiMetrics[roi] {
            let score: Float
            switch metricType {
            case .overall:
                // Average of roughness and pigmentation scores for overall
                let roughness = roiMetrics.roughnessScore
                let pigmentation = roiMetrics.pigmentationScore
                score = (roughness + pigmentation) / 2.0
            case .sharpness, .texture:
                score = roiMetrics.roughnessScore
            case .pigmentation:
                score = roiMetrics.pigmentationScore
            case .moisture:
                score = roiMetrics.specularScore ?? 50.0
            }
            // If score is valid (non-zero), return it
            if score > 0 {
                return score
            }
            // Otherwise fall through to global fallback
        }

        // Fallback to global scores if region data not available or had zero values
        let globalScore: Float
        switch metricType {
        case .overall:
            globalScore = metrics.overallScore
        case .sharpness, .texture:
            globalScore = metrics.globalRoughnessScore
        case .pigmentation:
            globalScore = metrics.globalPigmentationScore
        case .moisture:
            globalScore = metrics.globalSpecularScore ?? 50.0
        }

        // If global score is also 0, use overallScore as final fallback
        // This ensures we show SOME meaningful score rather than 0
        if globalScore > 0 {
            return globalScore
        }

        // Ultimate fallback: use the overall score if available
        return metrics.overallScore > 0 ? metrics.overallScore : 50.0
    }

    /// Convert UV bounds to pixel rect
    private func uvBoundsToRect(_ bounds: UVBounds, in size: CGSize) -> CGRect {
        // UV coordinates now use screen coordinate system:
        // U is horizontal (0=left, 1=right)
        // V is vertical (0=top, 1=bottom) - same as screen coordinates
        let x = CGFloat(bounds.minU) * size.width
        let y = CGFloat(bounds.minV) * size.height  // No flip needed - V is already in screen coords
        let width = CGFloat(bounds.maxU - bounds.minU) * size.width
        let height = CGFloat(bounds.maxV - bounds.minV) * size.height

        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Generate color based on score (0-100) using thermal medical palette
    /// Deep Blue (excellent) → Cyan → Teal → Amber → Soft Orange (needs attention)
    /// This palette is colorblind-friendly and avoids anxiety-inducing red
    private func colorForScore(_ score: Float) -> UIColor {
        let normalizedScore = max(0, min(100, score))

        switch normalizedScore {
        case 85...100:
            // Deep Blue #3B82F6 - Excellent health
            let t = CGFloat((normalizedScore - 85) / 15)
            return UIColor(
                red: 0.23 + (0.02 - 0.23) * t,  // 59→6
                green: 0.51 + (0.71 - 0.51) * t, // 130→182
                blue: 0.96 + (0.83 - 0.96) * t,  // 246→212
                alpha: 1.0
            )
        case 70..<85:
            // Cyan #06B6D4 - Good health
            let t = CGFloat((normalizedScore - 70) / 15)
            return UIColor(
                red: 0.02 + (0.08 - 0.02) * t,   // 6→20
                green: 0.71 + (0.72 - 0.71) * t, // 182→184
                blue: 0.83 + (0.65 - 0.83) * t,  // 212→166
                alpha: 1.0
            )
        case 50..<70:
            // Teal #14B8A6 → Amber #F59E0B - Fair, transitioning
            let t = CGFloat((normalizedScore - 50) / 20)
            return UIColor(
                red: 0.96 + (0.08 - 0.96) * t,   // 245→20 (amber to teal)
                green: 0.62 + (0.72 - 0.62) * t, // 158→184
                blue: 0.04 + (0.65 - 0.04) * t,  // 11→166
                alpha: 1.0
            )
        case 30..<50:
            // Amber #F59E0B - Needs attention
            let t = CGFloat((normalizedScore - 30) / 20)
            return UIColor(
                red: 0.98 + (0.96 - 0.98) * t,   // 249→245
                green: 0.45 + (0.62 - 0.45) * t, // 115→158
                blue: 0.09 + (0.04 - 0.09) * t,  // 22→11
                alpha: 1.0
            )
        default:
            // Soft Orange #F97316 - Priority attention (0-30)
            let t = CGFloat(normalizedScore / 30)
            return UIColor(
                red: 0.98,                       // 249 (constant warm)
                green: 0.45 * t + 0.30 * (1 - t), // 77→115 (darker when lower)
                blue: 0.09,                      // 22 (constant)
                alpha: 1.0
            )
        }
    }

}

/// Types for beautiful heatmap generation
public enum BeautifulHeatmapType {
    case overall
    case sharpness
    case texture
    case pigmentation
    case moisture
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
