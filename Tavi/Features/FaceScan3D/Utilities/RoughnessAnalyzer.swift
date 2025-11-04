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
    ///
    /// NOTE: Now uses Metal GPU acceleration for full-resolution processing (no downsampling needed!)
    /// Metal enables 20-50x faster blur, allowing analysis of complete texture data.
    public func computeRoughnessProxy(_ sample: ROITextureSample) -> Float {
        // TRY METAL GPU FIRST (if available)
        if let metalProcessor = MetalTextureProcessor.shared {
            return computeRoughnessProxyGPU(sample, metalProcessor: metalProcessor)
        }

        // FALLBACK TO CPU (with downsampling for performance)
        AppLogger.mesh.warning("⚠️ Metal unavailable - using CPU fallback with downsampling")
        let maxDimension = 512
        let downsampledSample = downsampleIfNeeded(sample, maxDimension: maxDimension)

        // Convert to luminance
        let luminance = convertToLuminance(downsampledSample.pixels)

        guard !luminance.isEmpty else { return 0 }

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
        // Convert ROITextureSample → UIImage
        guard let uiImage = sampleToUIImage(sample) else {
            AppLogger.mesh.error("Failed to convert sample to UIImage - falling back to CPU")
            return computeRoughnessProxyCPU(sample)
        }

        // Apply Gaussian blur using Metal (full resolution!)
        let blurRadius = Float(configuration.filterRadius)
        guard let blurredImage = metalProcessor.applyGaussianBlur(uiImage, radius: blurRadius) else {
            AppLogger.mesh.error("Metal blur failed - falling back to CPU")
            return computeRoughnessProxyCPU(sample)
        }

        // OPTIMIZATION: Could use GPU luminance conversion here too
        // For now using CPU conversion (fast enough for post-blur data)

        // Convert blurred image back to pixel data
        guard let blurredSample = uiImageToSample(blurredImage, roi: sample.roi) else {
            AppLogger.mesh.error("Failed to convert blurred image - falling back to CPU")
            return computeRoughnessProxyCPU(sample)
        }

        // Convert to luminance (original and blurred)
        // Note: Could optimize with GPU luminance shader if needed
        let originalLuminance = convertToLuminance(sample.pixels)
        let blurredLuminance = convertToLuminance(blurredSample.pixels)

        guard originalLuminance.count == blurredLuminance.count else {
            AppLogger.mesh.error("Luminance arrays mismatch - falling back to CPU")
            return computeRoughnessProxyCPU(sample)
        }

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

        AppLogger.mesh.info("✅ Metal GPU roughness: \(String(format: "%.3f", roughnessProxy)) (full \(sample.width)×\(sample.height) resolution)")

        return roughnessProxy
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
    private func sampleToUIImage(_ sample: ROITextureSample) -> UIImage? {
        let width = sample.width
        let height = sample.height

        guard width > 0 && height > 0 else { return nil }

        // Create RGBA bitmap
        var rgbaData = [UInt8]()
        rgbaData.reserveCapacity(width * height * 4)

        for pixel in sample.pixels {
            rgbaData.append(UInt8(clamp(pixel.x, 0, 1) * 255))  // R
            rgbaData.append(UInt8(clamp(pixel.y, 0, 1) * 255))  // G
            rgbaData.append(UInt8(clamp(pixel.z, 0, 1) * 255))  // B
            rgbaData.append(255)  // A
        }

        // Create CGImage
        guard let dataProvider = CGDataProvider(data: Data(rgbaData) as CFData),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            return nil
        }

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
