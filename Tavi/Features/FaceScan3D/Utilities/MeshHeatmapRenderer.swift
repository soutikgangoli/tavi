//
//  MeshHeatmapRenderer.swift
//  Tavi
//
//  Mesh-based heatmap renderer that draws colored triangles
//  following the actual face mesh captured by ARKit.
//  Created on 2025-12-11.
//

import Foundation
import UIKit
import CoreGraphics
import simd

/// Renders heatmaps by rasterizing mesh triangles in UV space
/// Each triangle is colored based on the facial region it belongs to
public class MeshHeatmapRenderer {

    // MARK: - Configuration

    /// Overlay opacity for heatmap colors
    private let overlayAlpha: CGFloat = 0.45

    // MARK: - Public API

    /// Main entry point - generates mesh-accurate heatmap
    /// - Parameters:
    ///   - mesh: The unified face mesh with UV coordinates
    ///   - metrics: Face3DMetrics containing scores per ROI
    ///   - metricType: Type of heatmap to generate
    ///   - baseTexture: The base face texture to overlay on
    /// - Returns: UIImage with mesh-colored heatmap overlay
    public func generateMeshHeatmap(
        mesh: UnifiedMesh,
        metrics: Face3DMetrics,
        metricType: BeautifulHeatmapType,
        baseTexture: CGImage
    ) -> UIImage? {
        let width = baseTexture.width
        let height = baseTexture.height
        let size = CGSize(width: width, height: height)

        // Step 1: Assign each triangle to an ROI
        let triangleROIs = assignTrianglesToROIs(mesh: mesh)

        // Step 2: Create pixel buffer for heatmap overlay
        var pixelBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // Step 3: Rasterize each triangle with its ROI color
        let triangleCount = mesh.triangleIndices.count / 3

        for triIdx in 0..<triangleCount {
            // Get vertex indices for this triangle
            let i0 = Int(mesh.triangleIndices[triIdx * 3])
            let i1 = Int(mesh.triangleIndices[triIdx * 3 + 1])
            let i2 = Int(mesh.triangleIndices[triIdx * 3 + 2])

            // Get UV coordinates
            let uv0 = mesh.textureCoordinates[i0]
            let uv1 = mesh.textureCoordinates[i1]
            let uv2 = mesh.textureCoordinates[i2]

            // Get ROI for this triangle
            guard let roi = triangleROIs[triIdx] else { continue }

            // Get score for this ROI
            let score = getRegionScore(roi: roi, metrics: metrics, metricType: metricType)

            // Get color for this score
            let color = colorForScore(score)

            // Convert UV to pixel coordinates
            let p0 = uvToPixel(uv0, width: width, height: height)
            let p1 = uvToPixel(uv1, width: width, height: height)
            let p2 = uvToPixel(uv2, width: width, height: height)

            // Rasterize the triangle
            rasterizeTriangle(
                p0: p0, p1: p1, p2: p2,
                color: color,
                pixelBuffer: &pixelBuffer,
                width: width,
                height: height
            )
        }

        // Step 4: Create overlay image from pixel buffer
        guard let overlayImage = createImage(from: pixelBuffer, width: width, height: height) else {
            return nil
        }

        // Step 5: Composite overlay onto base texture and draw labels
        return compositeWithLabels(
            baseTexture: baseTexture,
            overlay: overlayImage,
            mesh: mesh,
            triangleROIs: triangleROIs,
            metrics: metrics,
            metricType: metricType,
            size: size
        )
    }

    // MARK: - Triangle to ROI Assignment

    /// Assign each triangle to an ROI based on UV centroid
    /// - Parameter mesh: The unified face mesh
    /// - Returns: Dictionary mapping triangle index to Face3DROI
    private func assignTrianglesToROIs(mesh: UnifiedMesh) -> [Int: Face3DROI] {
        var triangleROIs: [Int: Face3DROI] = [:]
        let triangleCount = mesh.triangleIndices.count / 3

        for triIdx in 0..<triangleCount {
            // Get vertex indices
            let i0 = Int(mesh.triangleIndices[triIdx * 3])
            let i1 = Int(mesh.triangleIndices[triIdx * 3 + 1])
            let i2 = Int(mesh.triangleIndices[triIdx * 3 + 2])

            // Get UV coordinates
            let uv0 = mesh.textureCoordinates[i0]
            let uv1 = mesh.textureCoordinates[i1]
            let uv2 = mesh.textureCoordinates[i2]

            // Calculate centroid
            // FLIP V coordinate: ARKit V=0 is bottom, Face3DROI uvBounds expect V=0 at top
            let centroidU = (uv0.x + uv1.x + uv2.x) / 3.0
            let centroidV = 1.0 - (uv0.y + uv1.y + uv2.y) / 3.0

            // Check which ROI contains this centroid
            for roi in Face3DROI.allCases {
                if roi.uvBounds.contains(u: centroidU, v: centroidV) {
                    triangleROIs[triIdx] = roi
                    break
                }
            }
        }

        return triangleROIs
    }

    // MARK: - Triangle Rasterization

    /// Convert UV coordinate to pixel coordinate
    /// CRITICAL: ARKit UVs use OpenGL convention (V=0 at BOTTOM)
    /// But screen/image coordinates use (Y=0 at TOP)
    /// We must flip the V coordinate: screenY = 1.0 - uvY
    private func uvToPixel(_ uv: Vector2, width: Int, height: Int) -> (x: Int, y: Int) {
        let x = Int(uv.x * Float(width))
        // FLIP V coordinate: ARKit V=0 is bottom, screen Y=0 is top
        let y = Int((1.0 - uv.y) * Float(height))
        return (x: max(0, min(width - 1, x)), y: max(0, min(height - 1, y)))
    }

    /// Rasterize a single triangle in pixel space
    /// Uses barycentric coordinates for point-in-triangle test
    private func rasterizeTriangle(
        p0: (x: Int, y: Int),
        p1: (x: Int, y: Int),
        p2: (x: Int, y: Int),
        color: UIColor,
        pixelBuffer: inout [UInt8],
        width: Int,
        height: Int
    ) {
        // Get RGBA components
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        let rByte = UInt8(r * 255)
        let gByte = UInt8(g * 255)
        let bByte = UInt8(b * 255)
        let aByte = UInt8(overlayAlpha * 255)  // Use overlay alpha

        // Calculate bounding box
        let minX = max(0, min(p0.x, min(p1.x, p2.x)))
        let maxX = min(width - 1, max(p0.x, max(p1.x, p2.x)))
        let minY = max(0, min(p0.y, min(p1.y, p2.y)))
        let maxY = min(height - 1, max(p0.y, max(p1.y, p2.y)))

        // Pre-calculate edge vectors for barycentric coordinates
        let v0 = (x: Float(p2.x - p0.x), y: Float(p2.y - p0.y))
        let v1 = (x: Float(p1.x - p0.x), y: Float(p1.y - p0.y))

        // Calculate dot products for denominator
        let dot00 = v0.x * v0.x + v0.y * v0.y
        let dot01 = v0.x * v1.x + v0.y * v1.y
        let dot11 = v1.x * v1.x + v1.y * v1.y
        let denom = dot00 * dot11 - dot01 * dot01

        // Skip degenerate triangles
        guard abs(denom) > 0.0001 else { return }

        let invDenom = 1.0 / denom

        // Iterate over bounding box
        for y in minY...maxY {
            for x in minX...maxX {
                // Calculate barycentric coordinates
                let v2 = (x: Float(x - p0.x), y: Float(y - p0.y))

                let dot02 = v0.x * v2.x + v0.y * v2.y
                let dot12 = v1.x * v2.x + v1.y * v2.y

                let u = (dot11 * dot02 - dot01 * dot12) * invDenom
                let v = (dot00 * dot12 - dot01 * dot02) * invDenom

                // Check if point is inside triangle
                if u >= 0 && v >= 0 && (u + v) <= 1 {
                    let idx = (y * width + x) * 4

                    // Alpha blend with existing color
                    let existingA = Float(pixelBuffer[idx + 3]) / 255.0

                    if existingA > 0 {
                        // Blend colors
                        let newA = Float(aByte) / 255.0
                        let blendedA = newA + existingA * (1 - newA)

                        if blendedA > 0 {
                            let blendFactor = newA / blendedA
                            pixelBuffer[idx] = UInt8(Float(rByte) * blendFactor + Float(pixelBuffer[idx]) * (1 - blendFactor))
                            pixelBuffer[idx + 1] = UInt8(Float(gByte) * blendFactor + Float(pixelBuffer[idx + 1]) * (1 - blendFactor))
                            pixelBuffer[idx + 2] = UInt8(Float(bByte) * blendFactor + Float(pixelBuffer[idx + 2]) * (1 - blendFactor))
                            pixelBuffer[idx + 3] = UInt8(blendedA * 255)
                        }
                    } else {
                        // First color at this pixel
                        pixelBuffer[idx] = rByte
                        pixelBuffer[idx + 1] = gByte
                        pixelBuffer[idx + 2] = bByte
                        pixelBuffer[idx + 3] = aByte
                    }
                }
            }
        }
    }

    // MARK: - Image Creation

    /// Create CGImage from pixel buffer
    private func createImage(from pixelBuffer: [UInt8], width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let provider = CGDataProvider(data: Data(pixelBuffer) as CFData) else {
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
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    // MARK: - Compositing and Labels

    /// Composite overlay onto base texture and draw score labels
    private func compositeWithLabels(
        baseTexture: CGImage,
        overlay: CGImage,
        mesh: UnifiedMesh,
        triangleROIs: [Int: Face3DROI],
        metrics: Face3DMetrics,
        metricType: BeautifulHeatmapType,
        size: CGSize
    ) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { rendererContext in
            let context = rendererContext.cgContext

            // Flip coordinate system for CGImage drawing
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1.0, y: -1.0)

            // Draw base texture
            let rect = CGRect(origin: .zero, size: size)
            context.draw(baseTexture, in: rect)

            // Draw overlay
            context.draw(overlay, in: rect)

            // Reset transform for label drawing
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: 0, y: -size.height)

            // Calculate ROI centroids from mesh triangles for label placement
            let roiCentroids = calculateROICentroids(
                mesh: mesh,
                triangleROIs: triangleROIs,
                size: size
            )

            // Draw score labels
            drawScoreLabels(
                centroids: roiCentroids,
                metrics: metrics,
                metricType: metricType,
                size: size
            )
        }
    }

    /// Calculate centroid positions for each ROI based on mesh triangles
    private func calculateROICentroids(
        mesh: UnifiedMesh,
        triangleROIs: [Int: Face3DROI],
        size: CGSize
    ) -> [Face3DROI: CGPoint] {
        // Accumulate triangle centroids per ROI
        var roiSums: [Face3DROI: (x: CGFloat, y: CGFloat, count: Int)] = [:]

        for roi in Face3DROI.allCases {
            roiSums[roi] = (x: 0, y: 0, count: 0)
        }

        let triangleCount = mesh.triangleIndices.count / 3

        for triIdx in 0..<triangleCount {
            guard let roi = triangleROIs[triIdx] else { continue }

            // Get vertex indices
            let i0 = Int(mesh.triangleIndices[triIdx * 3])
            let i1 = Int(mesh.triangleIndices[triIdx * 3 + 1])
            let i2 = Int(mesh.triangleIndices[triIdx * 3 + 2])

            // Get UV coordinates
            let uv0 = mesh.textureCoordinates[i0]
            let uv1 = mesh.textureCoordinates[i1]
            let uv2 = mesh.textureCoordinates[i2]

            // Calculate centroid in pixel space
            // FLIP V coordinate: ARKit V=0 is bottom, screen Y=0 is top
            let centroidU = CGFloat((uv0.x + uv1.x + uv2.x) / 3.0)
            let centroidV = CGFloat(1.0 - (uv0.y + uv1.y + uv2.y) / 3.0)

            let pixelX = centroidU * size.width
            let pixelY = centroidV * size.height

            // Accumulate
            var current = roiSums[roi]!
            current.x += pixelX
            current.y += pixelY
            current.count += 1
            roiSums[roi] = current
        }

        // Calculate final centroids
        var centroids: [Face3DROI: CGPoint] = [:]

        for roi in Face3DROI.allCases {
            let sum = roiSums[roi]!
            if sum.count > 0 {
                centroids[roi] = CGPoint(
                    x: sum.x / CGFloat(sum.count),
                    y: sum.y / CGFloat(sum.count)
                )
            } else {
                // Fallback to UV bounds center if no triangles
                let bounds = roi.uvBounds
                centroids[roi] = CGPoint(
                    x: CGFloat((bounds.minU + bounds.maxU) / 2.0) * size.width,
                    y: CGFloat((bounds.minV + bounds.maxV) / 2.0) * size.height
                )
            }
        }

        return centroids
    }

    /// Draw score labels at ROI centroids
    private func drawScoreLabels(
        centroids: [Face3DROI: CGPoint],
        metrics: Face3DMetrics,
        metricType: BeautifulHeatmapType,
        size: CGSize
    ) {
        for roi in Face3DROI.allCases {
            guard let center = centroids[roi] else { continue }

            let score = getRegionScore(roi: roi, metrics: metrics, metricType: metricType)
            let color = colorForScore(score)

            drawModernScoreLabel(score: score, at: center, color: color, size: size)
        }
    }

    /// Draw modern score label with pill background
    private func drawModernScoreLabel(score: Float, at center: CGPoint, color: UIColor, size: CGSize) {
        let scoreText = "\(Int(score))"

        // Calculate font size based on image size
        let baseFontSize = min(size.width, size.height) * 0.035
        let fontSize = max(16, min(baseFontSize, 36))

        // Pill dimensions
        let pillWidth = fontSize * 2.0
        let pillHeight = fontSize * 1.4
        let pillRect = CGRect(
            x: center.x - pillWidth / 2,
            y: center.y - pillHeight / 2,
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
            x: center.x - textSize.width / 2,
            y: center.y - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )

        scoreText.draw(in: textRect, withAttributes: attributes)
    }

    // MARK: - Score and Color Helpers

    /// Get the score for a specific region based on metric type
    private func getRegionScore(roi: Face3DROI, metrics: Face3DMetrics, metricType: BeautifulHeatmapType) -> Float {
        // Try to get region-specific metrics
        if let roiMetrics = metrics.roiMetrics[roi] {
            let score: Float
            switch metricType {
            case .overall:
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
            if score > 0 {
                return score
            }
        }

        // Fallback to global scores
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

        if globalScore > 0 {
            return globalScore
        }

        return metrics.overallScore > 0 ? metrics.overallScore : 50.0
    }

    /// Generate color based on score (0-100) using thermal medical palette
    private func colorForScore(_ score: Float) -> UIColor {
        let normalizedScore = max(0, min(100, score))

        switch normalizedScore {
        case 85...100:
            // Deep Blue - Excellent health
            let t = CGFloat((normalizedScore - 85) / 15)
            return UIColor(
                red: 0.23 + (0.02 - 0.23) * t,
                green: 0.51 + (0.71 - 0.51) * t,
                blue: 0.96 + (0.83 - 0.96) * t,
                alpha: 1.0
            )
        case 70..<85:
            // Cyan - Good health
            let t = CGFloat((normalizedScore - 70) / 15)
            return UIColor(
                red: 0.02 + (0.08 - 0.02) * t,
                green: 0.71 + (0.72 - 0.71) * t,
                blue: 0.83 + (0.65 - 0.83) * t,
                alpha: 1.0
            )
        case 50..<70:
            // Teal to Amber - Fair
            let t = CGFloat((normalizedScore - 50) / 20)
            return UIColor(
                red: 0.96 + (0.08 - 0.96) * t,
                green: 0.62 + (0.72 - 0.62) * t,
                blue: 0.04 + (0.65 - 0.04) * t,
                alpha: 1.0
            )
        case 30..<50:
            // Amber - Needs attention
            let t = CGFloat((normalizedScore - 30) / 20)
            return UIColor(
                red: 0.98 + (0.96 - 0.98) * t,
                green: 0.45 + (0.62 - 0.45) * t,
                blue: 0.09 + (0.04 - 0.09) * t,
                alpha: 1.0
            )
        default:
            // Soft Orange - Priority attention (0-30)
            let t = CGFloat(normalizedScore / 30)
            return UIColor(
                red: 0.98,
                green: 0.45 * t + 0.30 * (1 - t),
                blue: 0.09,
                alpha: 1.0
            )
        }
    }
}
