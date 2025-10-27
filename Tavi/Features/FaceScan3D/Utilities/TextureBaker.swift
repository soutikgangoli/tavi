//
//  TextureBaker.swift
//  Tavi
//
//  Bake unified texture atlas from multiple pose samples
//  Created on 2025-10-27.
//

import Foundation
import UIKit
import CoreGraphics
import simd

/// Bakes unified texture atlas from multiple texture samples
public class TextureBaker {

    // MARK: - Configuration

    public struct Configuration {
        /// Output texture resolution
        public var textureWidth: Int = 2048
        public var textureHeight: Int = 2048

        /// Blending weights
        public var sharpnessWeight: Float = 0.6  // Prefer sharp samples
        public var frontFacingWeight: Float = 0.3  // Prefer front-facing samples
        public var exposureWeight: Float = 0.1  // Slight preference for well-exposed

        /// Inpainting for small gaps
        public var enableInpainting: Bool = true
        public var inpaintingRadius: Int = 3  // Pixels

        public init() {}
    }

    private let configuration: Configuration
    private let albedoEstimator: AlbedoEstimator
    private let lightingNormalizer: LightingNormalizer

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.albedoEstimator = AlbedoEstimator()
        self.lightingNormalizer = LightingNormalizer()
    }

    // MARK: - Main Baking Function

    /// Bake unified texture from multiple pose samples
    public func bakeUnifiedTexture(
        from unifiedMesh: MergedFaceMesh,
        samples: [PoseSample]
    ) async -> TextureBakeResult? {

        let startTime = Date().timeIntervalSince1970

        guard !samples.isEmpty else {
            print("⚠️ TextureBaker: No samples provided")
            return nil
        }

        print("🎨 TextureBaker: Starting bake with \(samples.count) samples...")

        // Convert to UnifiedMesh structure
        let mesh = UnifiedMesh(
            vertices: unifiedMesh.vertices,
            normals: unifiedMesh.normals,
            textureCoordinates: unifiedMesh.textureCoordinates,
            triangleIndices: unifiedMesh.triangleIndices,
            sourceCount: unifiedMesh.sourceCount,
            boundingBox: unifiedMesh.boundingBox
        )

        // Step 1: Apply albedo correction to all samples
        let correctedSamples = await correctSamplesLighting(samples: samples)

        // Step 2: Create UV atlas and blend samples
        guard let atlasImage = await createTextureAtlas(mesh: mesh, samples: correctedSamples) else {
            print("⚠️ TextureBaker: Failed to create texture atlas")
            return nil
        }

        // Step 3: Apply inpainting if enabled
        let finalTexture: UIImage
        if configuration.enableInpainting {
            finalTexture = applyInpainting(to: atlasImage)
        } else {
            finalTexture = atlasImage
        }

        guard let cgTexture = finalTexture.cgImage else {
            print("⚠️ TextureBaker: Failed to get CGImage from texture")
            return nil
        }

        // Calculate metrics
        let avgSharpness = samples.map { $0.focusSharpness }.reduce(0, +) / Float(samples.count)
        let coverage = calculateCoverage(image: finalTexture)

        let processingTime = Date().timeIntervalSince1970 - startTime

        print("✅ TextureBaker: Bake complete - time: \(processingTime)s, coverage: \(coverage * 100)%")

        return TextureBakeResult(
            unifiedMesh: mesh,
            albedoTexture: cgTexture,
            sampleCount: samples.count,
            averageSharpness: avgSharpness,
            coveragePercentage: coverage,
            processingTime: processingTime
        )
    }

    // MARK: - Lighting Correction

    /// Apply lighting normalization and albedo correction to all samples
    private func correctSamplesLighting(samples: [PoseSample]) async -> [CorrectedSample] {
        var correctedSamples: [CorrectedSample] = []

        for sample in samples {
            guard let originalImage = sample.getImage() else { continue }

            // Step 1: Apply lighting normalization (white balance, exposure, shadow compensation)
            let normalizedResult = lightingNormalizer.normalize(image: originalImage)
            let normalizedImage = normalizedResult?.normalizedImage ?? originalImage

            // Log lighting quality
            if let quality = normalizedResult?.lightingQuality {
                print("   📸 Sample \(sample.step): lighting quality \(Int(quality.overallScore * 100))%")
                if !quality.isAcceptable {
                    print("      ⚠️ Issues: \(quality.issues.joined(separator: ", "))")
                }
            }

            // Step 2: Apply albedo correction to remove directional lighting
            let lightDir = sample.lightDirection?.toSIMD() ?? SIMD3<Float>(0, 1, 0.5)
            let normalizedLightDir = normalize(lightDir)

            let correctedImage = albedoEstimator.processImage(
                image: normalizedImage,
                lightDirection: normalizedLightDir,
                lightIntensity: Float(sample.ambientIntensity)
            ) ?? normalizedImage

            correctedSamples.append(CorrectedSample(
                original: sample,
                correctedImage: correctedImage
            ))
        }

        return correctedSamples
    }

    // MARK: - Texture Atlas Creation

    /// Create texture atlas by blending samples
    private func createTextureAtlas(mesh: UnifiedMesh, samples: [CorrectedSample]) async -> UIImage? {
        let width = configuration.textureWidth
        let height = configuration.textureHeight

        // Initialize atlas pixel data (RGBA)
        var pixelData = [Float](repeating: 0, count: width * height * 4)
        var weightData = [Float](repeating: 0, count: width * height)  // Track accumulated weights

        // For each sample, project its colors onto the UV space
        for sample in samples {
            guard let image = sample.correctedImage.cgImage else { continue }

            // Calculate sample weight based on quality metrics
            let sampleWeight = calculateSampleWeight(sample: sample.original)

            // Rasterize this sample's contribution to UV space
            // This is a simplified version - in production you'd use proper texture projection
            await rasterizeSampleToUV(
                image: image,
                sampleWeight: sampleWeight,
                pixelData: &pixelData,
                weightData: &weightData,
                width: width,
                height: height
            )
        }

        // Normalize by accumulated weights
        for i in 0..<(width * height) {
            let weight = weightData[i]
            if weight > 0 {
                let baseIdx = i * 4
                pixelData[baseIdx] /= weight      // R
                pixelData[baseIdx + 1] /= weight  // G
                pixelData[baseIdx + 2] /= weight  // B
                pixelData[baseIdx + 3] = 1.0      // A
            }
        }

        // Convert to UIImage
        return createImageFromPixelData(pixelData: pixelData, width: width, height: height)
    }

    /// Calculate weight for a sample based on quality metrics
    private func calculateSampleWeight(sample: PoseSample) -> Float {
        // Normalize sharpness (assume 0-500 range, 200 = good)
        let sharpnessNorm = min(sample.focusSharpness / 200.0, 1.0)

        // Front-facing bonus
        let frontFacingScore: Float = sample.isFrontFacing ? 1.0 : 0.5

        // Exposure score (0.5 = ideal)
        let exposureScore = 1.0 - abs(sample.exposureScore - 0.5) * 2.0

        // Weighted combination
        let weight = sharpnessNorm * configuration.sharpnessWeight +
                    frontFacingScore * configuration.frontFacingWeight +
                    exposureScore * configuration.exposureWeight

        return weight
    }

    /// Rasterize sample to UV space (simplified - assumes canonical ARKit UV mapping)
    private func rasterizeSampleToUV(
        image: CGImage,
        sampleWeight: Float,
        pixelData: inout [Float],
        weightData: inout [Float],
        width: Int,
        height: Int
    ) async {
        // This is a simplified implementation
        // In production, you'd properly project the 3D mesh onto the 2D texture
        // using the face anchor transform and camera projection

        // For now, we'll do a simple blending by sampling the source image
        // and mapping it to UV space assuming canonical ARKit face UV layout

        let srcWidth = image.width
        let srcHeight = image.height

        // Extract source pixel data
        var srcPixels = [UInt8](repeating: 0, count: srcWidth * srcHeight * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &srcPixels,
            width: srcWidth,
            height: srcHeight,
            bitsPerComponent: 8,
            bytesPerRow: srcWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: srcWidth, height: srcHeight))

        // Sample and blend into atlas
        // Simple approach: scale source to atlas size and blend
        for y in 0..<height {
            for x in 0..<width {
                // Map atlas UV to source image coordinates
                let srcX = Int((Float(x) / Float(width)) * Float(srcWidth))
                let srcY = Int((Float(y) / Float(height)) * Float(srcHeight))

                guard srcX < srcWidth && srcY < srcHeight else { continue }

                let srcIdx = (srcY * srcWidth + srcX) * 4
                let dstIdx = (y * width + x) * 4
                let weightIdx = y * width + x

                let r = Float(srcPixels[srcIdx]) / 255.0
                let g = Float(srcPixels[srcIdx + 1]) / 255.0
                let b = Float(srcPixels[srcIdx + 2]) / 255.0

                // Accumulate weighted color
                pixelData[dstIdx] += r * sampleWeight
                pixelData[dstIdx + 1] += g * sampleWeight
                pixelData[dstIdx + 2] += b * sampleWeight

                weightData[weightIdx] += sampleWeight
            }
        }
    }

    // MARK: - Inpainting

    /// Apply simple inpainting to fill small gaps
    private func applyInpainting(to image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let width = cgImage.width
        let height = cgImage.height

        // Extract pixel data
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
            return image
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Find and fill gaps (pixels with alpha = 0 or very dark)
        var filled = pixelData

        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4

                // Check if pixel needs inpainting (black or transparent)
                let r = pixelData[idx]
                let g = pixelData[idx + 1]
                let b = pixelData[idx + 2]
                let a = pixelData[idx + 3]

                if a < 10 || (r < 10 && g < 10 && b < 10) {
                    // Fill with average of neighbors
                    var sumR = 0
                    var sumG = 0
                    var sumB = 0
                    var count = 0

                    let radius = configuration.inpaintingRadius

                    for dy in -radius...radius {
                        for dx in -radius...radius {
                            let nx = x + dx
                            let ny = y + dy

                            guard nx >= 0 && nx < width && ny >= 0 && ny < height else { continue }

                            let nIdx = (ny * width + nx) * 4
                            let nA = pixelData[nIdx + 3]

                            if nA > 10 {
                                sumR += Int(pixelData[nIdx])
                                sumG += Int(pixelData[nIdx + 1])
                                sumB += Int(pixelData[nIdx + 2])
                                count += 1
                            }
                        }
                    }

                    if count > 0 {
                        filled[idx] = UInt8(sumR / count)
                        filled[idx + 1] = UInt8(sumG / count)
                        filled[idx + 2] = UInt8(sumB / count)
                        filled[idx + 3] = 255
                    }
                }
            }
        }

        // Create inpainted image
        guard let inpaintedContext = CGContext(
            data: &filled,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ), let inpaintedCGImage = inpaintedContext.makeImage() else {
            return image
        }

        return UIImage(cgImage: inpaintedCGImage)
    }

    // MARK: - Helpers

    /// Create UIImage from float pixel data
    private func createImageFromPixelData(pixelData: [Float], width: Int, height: Int) -> UIImage? {
        // Convert float to UInt8
        var byteData = [UInt8](repeating: 0, count: width * height * 4)

        for i in 0..<(width * height * 4) {
            byteData[i] = UInt8(max(0, min(255, pixelData[i] * 255)))
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &byteData,
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

    /// Calculate coverage percentage (non-black pixels)
    private func calculateCoverage(image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 0 }

        let width = cgImage.width
        let height = cgImage.height

        var pixelData = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return 0
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var filledPixels = 0
        for pixel in pixelData {
            if pixel > 10 {  // Not black
                filledPixels += 1
            }
        }

        return Float(filledPixels) / Float(width * height)
    }
}

// MARK: - Helper Structures

private struct CorrectedSample {
    let original: PoseSample
    let correctedImage: UIImage
}
