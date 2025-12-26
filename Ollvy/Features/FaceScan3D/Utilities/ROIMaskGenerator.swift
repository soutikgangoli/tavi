//
//  ROIMaskGenerator.swift
//  Ollvy
//
//  Generate UV-based ROI masks from 3D face mesh
//  Created on 2025-10-27.
//

import Foundation
import UIKit
import CoreGraphics
import simd

/// Generates ROI masks from mesh UV coordinates
public class ROIMaskGenerator {

    // MARK: - Configuration

    public struct Configuration {
        /// Texture resolution for pixel masks
        public var textureWidth: Int = 2048
        public var textureHeight: Int = 2048

        public init() {}
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Main API

    /// Generate ROI masks from UV coordinates and topology
    public func generateROIMasks(
        from uvCoordinates: [SIMD2<Float>],
        topology: [Int32]
    ) -> [Face3DROI: UIMask] {

        var masks: [Face3DROI: UIMask] = [:]

        for roi in Face3DROI.allCases {
            let mask = generateMask(
                for: roi,
                uvCoordinates: uvCoordinates,
                topology: topology
            )
            masks[roi] = mask
        }

        return masks
    }

    // MARK: - Mask Generation

    private func generateMask(
        for roi: Face3DROI,
        uvCoordinates: [SIMD2<Float>],
        topology: [Int32]
    ) -> UIMask {

        let bounds = roi.uvBounds

        // Find vertices in this ROI
        var vertexIndices: [Int] = []
        for (index, uv) in uvCoordinates.enumerated() {
            if bounds.contains(uv) {
                vertexIndices.append(index)
            }
        }

        // Find triangles in this ROI (all 3 vertices must be in ROI)
        var triangleIndices: [Int] = []
        let vertexSet = Set(vertexIndices)

        for i in stride(from: 0, to: topology.count, by: 3) {
            let v0 = Int(topology[i])
            let v1 = Int(topology[i + 1])
            let v2 = Int(topology[i + 2])

            if vertexSet.contains(v0) && vertexSet.contains(v1) && vertexSet.contains(v2) {
                triangleIndices.append(contentsOf: [i, i + 1, i + 2])
            }
        }

        // Generate pixel mask
        let pixelMask = generatePixelMask(
            for: roi,
            bounds: bounds
        )

        return UIMask(
            roi: roi,
            vertexIndices: vertexIndices,
            triangleIndices: triangleIndices,
            bounds: bounds,
            pixelMask: pixelMask,
            textureWidth: configuration.textureWidth,
            textureHeight: configuration.textureHeight
        )
    }

    /// Generate 2D pixel mask for ROI in texture space
    private func generatePixelMask(
        for roi: Face3DROI,
        bounds: UVBounds
    ) -> [[Bool]] {

        let width = configuration.textureWidth
        let height = configuration.textureHeight

        var mask = Array(repeating: Array(repeating: false, count: width), count: height)

        // For each pixel, check if UV is in bounds
        // V is now in screen coordinate system (0=top, 1=bottom)
        for y in 0..<height {
            for x in 0..<width {
                let u = Float(x) / Float(width)
                let v = Float(y) / Float(height)

                if bounds.contains(u: u, v: v) {
                    mask[y][x] = true
                }
            }
        }

        return mask
    }
}

// MARK: - ROI Texture Sampler

/// Samples texture data within ROI masks
public class ROITextureSampler {

    /// Sample texture within an ROI mask
    public static func sampleROITexture(
        _ texture: CGImage,
        mask: UIMask
    ) -> ROITextureSample? {

        let width = texture.width
        let height = texture.height

        // Extract pixel data from texture
        guard let pixelData = extractPixelData(from: texture) else {
            return nil
        }

        var pixels: [SIMD3<Float>] = []
        var uvCoordinates: [SIMD2<Float>] = []

        // Sample pixels within mask
        for y in 0..<height {
            for x in 0..<width {
                // Check if this pixel is in the ROI
                let maskY = Int(Float(y) / Float(height) * Float(mask.textureHeight))
                let maskX = Int(Float(x) / Float(width) * Float(mask.textureWidth))

                guard maskY < mask.textureHeight && maskX < mask.textureWidth else { continue }
                guard mask.pixelMask[maskY][maskX] else { continue }

                // Extract RGB color
                let pixelIndex = (y * width + x) * 4
                let r = Float(pixelData[pixelIndex]) / 255.0
                let g = Float(pixelData[pixelIndex + 1]) / 255.0
                let b = Float(pixelData[pixelIndex + 2]) / 255.0

                pixels.append(SIMD3<Float>(r, g, b))

                // Calculate UV coordinate (V is in screen coordinates: 0=top, 1=bottom)
                let u = Float(x) / Float(width)
                let v = Float(y) / Float(height)
                uvCoordinates.append(SIMD2<Float>(u, v))
            }
        }

        guard !pixels.isEmpty else {
            return nil
        }

        return ROITextureSample(
            roi: mask.roi,
            pixels: pixels,
            uvCoordinates: uvCoordinates,
            width: width,
            height: height
        )
    }

    // MARK: - Pixel Extraction

    private static func extractPixelData(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height

        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

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
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return pixelData
    }
}
