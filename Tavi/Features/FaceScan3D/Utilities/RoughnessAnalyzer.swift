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

        /// Enable regional consistency validation for higher confidence
        public var enableRegionalValidation: Bool = true

        public init() {}
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Main API

    /// Compute roughness proxy from ROI texture sample
    /// Returns 0-1 score (higher = rougher)
    ///
    /// NOTE: Now uses Metal GPU acceleration for full-resolution processing (no downsampling needed!)
    /// Metal enables 20-50x faster blur, allowing analysis of complete texture data.
    public func computeRoughnessProxy(_ sample: ROITextureSample) -> Float {
        // DIAGNOSTIC: Check sample validity
        AppLogger.mesh.debug("🔍 RoughnessAnalyzer: Processing ROI \(String(describing: sample.roi))")
        AppLogger.mesh.debug("   Size: \(sample.width)×\(sample.height), Pixels: \(sample.pixels.count)")

        guard sample.pixels.count > 0 else {
            AppLogger.mesh.error("❌ RoughnessAnalyzer: Empty pixel array! Returning 0")
            return 0
        }

        // TRY METAL GPU FIRST (if available)
        if let metalProcessor = MetalTextureProcessor.shared {
            AppLogger.mesh.debug("🎨 RoughnessAnalyzer: Using Metal GPU path")
            let result = computeRoughnessProxyGPU(sample, metalProcessor: metalProcessor)

            // DIAGNOSTIC: Log unusual zero values
            if result == 0 {
                AppLogger.mesh.info("ℹ️ Metal GPU: Roughness proxy = 0.000 (perfect smoothness detected)")
                AppLogger.mesh.info("   → Will map to Smoothness Score = 100/100")
                AppLogger.mesh.info("   → If actual skin has visible texture, this indicates processing failure")
            } else if result > 0.5 {
                AppLogger.mesh.warning("⚠️ Metal GPU: Roughness proxy = \(String(format: "%.3f", Double(result))) (very rough)")
                AppLogger.mesh.warning("   → Will map to Smoothness Score ≈ 0/100")
                AppLogger.mesh.warning("   → For young skin, proxy should typically be 0.08-0.25")
            }

            return result
        }

        // FALLBACK TO CPU (with downsampling for performance)
        AppLogger.mesh.warning("⚠️ Metal unavailable - using CPU fallback with downsampling")
        let maxDimension = 512
        let downsampledSample = downsampleIfNeeded(sample, maxDimension: maxDimension)

        // Convert to luminance
        let luminance = convertToLuminance(downsampledSample.pixels)

        guard !luminance.isEmpty else {
            AppLogger.mesh.error("❌ RoughnessAnalyzer: Luminance conversion failed! Returning 0")
            return 0
        }

        // DIAGNOSTIC: Check luminance statistics
        var meanLumaCheck: Float = 0
        vDSP_meanv(luminance, 1, &meanLumaCheck, vDSP_Length(luminance.count))
        AppLogger.mesh.debug("🔍 RoughnessAnalyzer: Mean luminance = \(String(format: "%.3f", Double(meanLumaCheck)))")

        // Apply high-pass filter
        let highpass = applyHighPassFilter(luminance, width: downsampledSample.width, height: downsampledSample.height)

        // Compute mean luminance
        var meanLuma: Float = 0
        vDSP_meanv(luminance, 1, &meanLuma, vDSP_Length(luminance.count))

        // Compute mean of absolute high-pass values
        let absHighpass = highpass.map { abs($0) }
        var meanHighpass: Float = 0
        vDSP_meanv(absHighpass, 1, &meanHighpass, vDSP_Length(absHighpass.count))

        // Normalized energy = mean(abs(highpass)) / mean(luma)
        let normalizedEnergy = meanLuma > 0 ? meanHighpass / meanLuma : 0

        // Scale to 0-1 range
        let roughnessProxy = min(normalizedEnergy * configuration.normalizationFactor, 1.0)

        // DIAGNOSTIC: Log results with interpretation
        AppLogger.mesh.info("📊 RoughnessAnalyzer CPU Results:")
        AppLogger.mesh.info("   Roughness Proxy: \(String(format: "%.4f", Double(roughnessProxy))) [0=smooth, 1=rough]")
        AppLogger.mesh.info("   Mean Luminance: \(String(format: "%.3f", Double(meanLuma)))")
        AppLogger.mesh.info("   High-Pass Energy: \(String(format: "%.3f", Double(meanHighpass)))")

        // Interpretation
        if roughnessProxy < 0.08 {
            AppLogger.mesh.info("   → Excellent smoothness (will score 90-100)")
        } else if roughnessProxy < 0.25 {
            AppLogger.mesh.info("   → Good smoothness (will score 60-90)")
        } else if roughnessProxy < 0.50 {
            AppLogger.mesh.info("   → Moderate roughness (will score 20-60)")
        } else {
            AppLogger.mesh.warning("   → ⚠️ High roughness (will score 0-20)")
        }

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

    // MARK: - Performance Optimization

    /// Downsample large samples to improve performance
    private func downsampleIfNeeded(_ sample: ROITextureSample, maxDimension: Int) -> ROITextureSample {
        // Check if downsampling needed
        guard sample.width > maxDimension || sample.height > maxDimension else {
            return sample  // Already small enough
        }

        // Calculate scale factor
        let scale = Float(maxDimension) / Float(max(sample.width, sample.height))
        let newWidth = Int(Float(sample.width) * scale)
        let newHeight = Int(Float(sample.height) * scale)

        // Downsample using simple box filter (average of nearby pixels)
        var downsampledPixels: [SIMD3<Float>] = []
        var downsampledUVs: [SIMD2<Float>] = []
        downsampledPixels.reserveCapacity(newWidth * newHeight)
        downsampledUVs.reserveCapacity(newWidth * newHeight)

        let scaleX = Float(sample.width) / Float(newWidth)
        let scaleY = Float(sample.height) / Float(newHeight)

        for newY in 0..<newHeight {
            for newX in 0..<newWidth {
                // Map to original coordinates
                let origX = Int(Float(newX) * scaleX)
                let origY = Int(Float(newY) * scaleY)
                let origIdx = origY * sample.width + origX

                if origIdx < sample.pixels.count {
                    downsampledPixels.append(sample.pixels[origIdx])
                    // Downsample UVs if available
                    if origIdx < sample.uvCoordinates.count {
                        downsampledUVs.append(sample.uvCoordinates[origIdx])
                    } else {
                        downsampledUVs.append(SIMD2<Float>(0, 0))
                    }
                } else {
                    downsampledPixels.append(SIMD3<Float>(0, 0, 0))
                    downsampledUVs.append(SIMD2<Float>(0, 0))
                }
            }
        }

        print("      ℹ️ Downsampled from \(sample.width)x\(sample.height) to \(newWidth)x\(newHeight) for performance")

        return ROITextureSample(
            roi: sample.roi,
            pixels: downsampledPixels,
            uvCoordinates: downsampledUVs,
            width: newWidth,
            height: newHeight
        )
    }

    // MARK: - Metal GPU Acceleration

    /// Compute roughness using Metal GPU (NO downsampling - full resolution!)
    private func computeRoughnessProxyGPU(_ sample: ROITextureSample, metalProcessor: MetalTextureProcessor) -> Float {
        // MEMORY OPTIMIZATION: Wrap Metal GPU operations in autoreleasepool
        // This immediately releases temporary Metal objects (textures, command buffers)
        // preventing memory spikes when processing multiple ROIs in parallel
        return autoreleasepool {
            // Convert ROITextureSample → UIImage
            AppLogger.mesh.debug("🔍 Metal GPU: Converting sample to UIImage...")
            guard let uiImage = sampleToUIImage(sample) else {
                AppLogger.mesh.error("❌ Metal GPU: Failed to convert sample to UIImage - falling back to CPU")
                return computeRoughnessProxyCPU(sample)
            }
            AppLogger.mesh.debug("✅ Metal GPU: UIImage created successfully (\(uiImage.size.width)×\(uiImage.size.height))")

            // Apply Gaussian blur using Metal (full resolution!)
            let blurRadius = Float(configuration.filterRadius)
            AppLogger.mesh.debug("🔍 Metal GPU: Applying Gaussian blur (radius: \(blurRadius))...")
            guard let blurredImage = metalProcessor.applyGaussianBlur(uiImage, radius: blurRadius) else {
                AppLogger.mesh.error("❌ Metal GPU: Blur failed - falling back to CPU")
                return computeRoughnessProxyCPU(sample)
            }
            AppLogger.mesh.debug("✅ Metal GPU: Blur completed successfully")

            // OPTIMIZATION: Could use GPU luminance conversion here too
            // For now using CPU conversion (fast enough for post-blur data)

            // Convert blurred image back to pixel data
            AppLogger.mesh.debug("🔍 Metal GPU: Converting blurred image back to sample...")
            guard let blurredSample = uiImageToSample(blurredImage, roi: sample.roi) else {
                AppLogger.mesh.error("❌ Metal GPU: Failed to convert blurred image - falling back to CPU")
                return computeRoughnessProxyCPU(sample)
            }
            AppLogger.mesh.debug("✅ Metal GPU: Blurred sample created (pixels: \(blurredSample.pixels.count))")

            // CRITICAL FIX: Convert original sample to full raster for comparison
            // The blurred sample is a full 4096×4096 raster (16M pixels)
            // But the original sample.pixels is sparse ROI data (~1.5M pixels)
            // We need to convert the original to full raster too for fair comparison
            AppLogger.mesh.debug("🔍 Metal GPU: Converting original sample to full raster for comparison...")
            guard let originalUIImage = sampleToUIImage(sample) else {
                AppLogger.mesh.error("❌ Metal GPU: Failed to convert original to full raster - falling back to CPU")
                return computeRoughnessProxyCPU(sample)
            }
            guard let originalFullSample = uiImageToSample(originalUIImage, roi: sample.roi) else {
                AppLogger.mesh.error("❌ Metal GPU: Failed to extract original full sample - falling back to CPU")
                return computeRoughnessProxyCPU(sample)
            }
            AppLogger.mesh.debug("✅ Metal GPU: Original sample converted to full raster (pixels: \(originalFullSample.pixels.count))")

            // Convert to luminance (both now have same pixel count)
            let originalLuminance = convertToLuminance(originalFullSample.pixels)
            let blurredLuminance = convertToLuminance(blurredSample.pixels)

            guard originalLuminance.count == blurredLuminance.count else {
                AppLogger.mesh.error("❌ Metal GPU: Luminance arrays still mismatch (original: \(originalLuminance.count), blurred: \(blurredLuminance.count)) - falling back to CPU")
                return computeRoughnessProxyCPU(sample)
            }
            AppLogger.mesh.debug("✅ Metal GPU: Luminance arrays match (\(originalLuminance.count) pixels each)")

            // High-pass = original - blurred
            var highpass = [Float](repeating: 0, count: originalLuminance.count)
            for i in 0..<originalLuminance.count {
                highpass[i] = originalLuminance[i] - blurredLuminance[i]
            }

            // Compute mean luminance
            var meanLuma: Float = 0
            vDSP_meanv(originalLuminance, 1, &meanLuma, vDSP_Length(originalLuminance.count))

            // Compute mean of absolute high-pass values
            let absHighpass = highpass.map { abs($0) }
            var meanHighpass: Float = 0
            vDSP_meanv(absHighpass, 1, &meanHighpass, vDSP_Length(absHighpass.count))

            // Normalized energy = mean(abs(highpass)) / mean(luma)
            let normalizedEnergy = meanLuma > 0 ? meanHighpass / meanLuma : 0

            // Scale to 0-1 range
            let roughnessProxy = min(normalizedEnergy * configuration.normalizationFactor, 1.0)

            // DIAGNOSTIC: Detailed logging with interpretation
            AppLogger.mesh.info("📊 Metal GPU Results (full \(sample.width)×\(sample.height) resolution):")
            AppLogger.mesh.info("   Roughness Proxy: \(String(format: "%.4f", Double(roughnessProxy))) [0=smooth, 1=rough]")
            AppLogger.mesh.info("   Mean Luminance: \(String(format: "%.3f", Double(meanLuma)))")
            AppLogger.mesh.info("   High-Pass Energy: \(String(format: "%.3f", Double(meanHighpass)))")

            // Interpretation
            if roughnessProxy == 0 {
                if meanHighpass == 0 {
                    AppLogger.mesh.warning("   ⚠️ Zero proxy + zero high-pass = processing failure or perfectly uniform texture")
                } else {
                    AppLogger.mesh.info("   → Perfect smoothness detected (will score 100/100)")
                }
            } else if roughnessProxy < 0.08 {
                AppLogger.mesh.info("   → Excellent smoothness (will score 90-100)")
            } else if roughnessProxy < 0.25 {
                AppLogger.mesh.info("   → Good smoothness (will score 60-90)")
            } else if roughnessProxy < 0.50 {
                AppLogger.mesh.info("   → Moderate roughness (will score 20-60)")
            } else {
                AppLogger.mesh.warning("   → ⚠️ High roughness = \(String(format: "%.3f", Double(roughnessProxy))) (will score 0-20)")
            }

            return roughnessProxy
        }  // autoreleasepool
    }

    /// CPU fallback (explicit method for clarity)
    private func computeRoughnessProxyCPU(_ sample: ROITextureSample) -> Float {
        let maxDimension = 512
        let downsampledSample = downsampleIfNeeded(sample, maxDimension: maxDimension)
        let luminance = convertToLuminance(downsampledSample.pixels)
        guard !luminance.isEmpty else { return 0 }

        let highpass = applyHighPassFilter(luminance, width: downsampledSample.width, height: downsampledSample.height)

        var meanLuma: Float = 0
        vDSP_meanv(luminance, 1, &meanLuma, vDSP_Length(luminance.count))

        let absHighpass = highpass.map { abs($0) }
        var meanHighpass: Float = 0
        vDSP_meanv(absHighpass, 1, &meanHighpass, vDSP_Length(absHighpass.count))

        let normalizedEnergy = meanLuma > 0 ? meanHighpass / meanLuma : 0
        let roughnessProxy = min(normalizedEnergy * configuration.normalizationFactor, 1.0)

        return roughnessProxy
    }

    // MARK: - Image Conversion Helpers

    /// Convert ROITextureSample to UIImage
    ///
    /// CRITICAL FIX: ROITextureSample.pixels contains ONLY ROI pixels (sparse data),
    /// but width/height are the FULL texture dimensions (4096×4096).
    /// Instead of creating a full-size image with black background (which causes edge artifacts),
    /// we crop to the ROI bounding box to preserve only actual skin texture.
    private func sampleToUIImage(_ sample: ROITextureSample) -> UIImage? {
        guard sample.pixels.count > 0 && sample.uvCoordinates.count == sample.pixels.count else {
            AppLogger.mesh.error("❌ sampleToUIImage: Invalid sample data (pixels: \(sample.pixels.count), UVs: \(sample.uvCoordinates.count))")
            return nil
        }

        let fullWidth = sample.width
        let fullHeight = sample.height

        guard fullWidth > 0 && fullHeight > 0 else {
            AppLogger.mesh.error("❌ sampleToUIImage: Invalid dimensions (\(fullWidth)×\(fullHeight))")
            return nil
        }

        // Calculate bounding box of ROI in pixel coordinates
        var minX = Int.max, maxX = 0
        var minY = Int.max, maxY = 0

        for uv in sample.uvCoordinates {
            let x = Int(uv.x * Float(fullWidth - 1))
            let y = Int(uv.y * Float(fullHeight - 1))
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }

        // Ensure valid bounding box
        guard minX < maxX && minY < maxY else {
            AppLogger.mesh.error("❌ sampleToUIImage: Invalid bounding box (\(minX),\(minY))-(\(maxX),\(maxY))")
            return nil
        }

        // Calculate cropped dimensions
        let cropWidth = maxX - minX + 1
        let cropHeight = maxY - minY + 1

        AppLogger.mesh.debug("🔍 sampleToUIImage: Cropping ROI bounding box")
        AppLogger.mesh.debug("   Full texture: \(fullWidth)×\(fullHeight)")
        AppLogger.mesh.debug("   ROI bounds: (\(minX),\(minY))-(\(maxX),\(maxY))")
        AppLogger.mesh.debug("   Cropped size: \(cropWidth)×\(cropHeight)")
        AppLogger.mesh.debug("   Pixels: \(sample.pixels.count)")

        // Create cropped image with average ROI color as background
        // (prevents edge artifacts while maintaining texture information)
        var avgR: Float = 0, avgG: Float = 0, avgB: Float = 0
        for pixel in sample.pixels {
            avgR += pixel.x
            avgG += pixel.y
            avgB += pixel.z
        }
        let count = Float(sample.pixels.count)
        avgR /= count
        avgG /= count
        avgB /= count

        let bgR = UInt8(clamp(avgR, 0, 1) * 255)
        let bgG = UInt8(clamp(avgG, 0, 1) * 255)
        let bgB = UInt8(clamp(avgB, 0, 1) * 255)

        var rgbaData = [UInt8](repeating: 0, count: cropWidth * cropHeight * 4)

        // Fill with average background color
        for i in 0..<(cropWidth * cropHeight) {
            let offset = i * 4
            rgbaData[offset + 0] = bgR
            rgbaData[offset + 1] = bgG
            rgbaData[offset + 2] = bgB
            rgbaData[offset + 3] = 255
        }

        // Place ROI pixels at their positions in cropped space
        for i in 0..<sample.pixels.count {
            let uv = sample.uvCoordinates[i]
            let pixel = sample.pixels[i]

            // Convert UV to full texture coordinates
            let fullX = Int(uv.x * Float(fullWidth - 1))
            let fullY = Int(uv.y * Float(fullHeight - 1))

            // Convert to cropped coordinates
            let cropX = fullX - minX
            let cropY = fullY - minY

            // Bounds check
            guard cropX >= 0 && cropX < cropWidth && cropY >= 0 && cropY < cropHeight else {
                continue
            }

            let offset = (cropY * cropWidth + cropX) * 4
            if offset + 3 < rgbaData.count {
                rgbaData[offset + 0] = UInt8(clamp(pixel.x, 0, 1) * 255)  // R
                rgbaData[offset + 1] = UInt8(clamp(pixel.y, 0, 1) * 255)  // G
                rgbaData[offset + 2] = UInt8(clamp(pixel.z, 0, 1) * 255)  // B
                rgbaData[offset + 3] = 255  // A
            }
        }

        AppLogger.mesh.debug("✅ Created cropped ROI image: \(cropWidth)×\(cropHeight) from \(sample.pixels.count) pixels")

        // Create CGImage
        guard let dataProvider = CGDataProvider(data: Data(rgbaData) as CFData),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            AppLogger.mesh.error("❌ sampleToUIImage: Failed to create data provider or color space")
            return nil
        }

        let bytesPerRow = cropWidth * 4

        guard let cgImage = CGImage(
            width: cropWidth,
            height: cropHeight,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            AppLogger.mesh.error("❌ sampleToUIImage: CGImage creation failed!")
            return nil
        }

        AppLogger.mesh.debug("✅ sampleToUIImage: Successfully created cropped CGImage")
        return UIImage(cgImage: cgImage)
    }

    /// Convert UIImage back to ROITextureSample
    private func uiImageToSample(_ image: UIImage, roi: Face3DROI) -> ROITextureSample? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        // Extract pixel data
        var pixels: [SIMD3<Float>] = []
        pixels.reserveCapacity(width * height)

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * cgImage.bytesPerRow) + (x * bytesPerPixel)
                let r = Float(bytes[offset]) / 255.0
                let g = Float(bytes[offset + 1]) / 255.0
                let b = Float(bytes[offset + 2]) / 255.0
                pixels.append(SIMD3<Float>(r, g, b))
            }
        }

        // Create placeholder UVs
        let uvs = [SIMD2<Float>](repeating: SIMD2<Float>(0, 0), count: pixels.count)

        return ROITextureSample(
            roi: roi,
            pixels: pixels,
            uvCoordinates: uvs,
            width: width,
            height: height
        )
    }

    /// Clamp value to range [min, max]
    private func clamp(_ value: Float, _ min: Float, _ max: Float) -> Float {
        return Swift.max(min, Swift.min(max, value))
    }
}
