//
//  AlbedoEstimator.swift
//  Tavi
//
//  Estimate albedo (lighting-minimized) colors using Lambertian correction
//  Created on 2025-10-27.
//

import Foundation
import UIKit
import CoreGraphics
import simd

/// Estimates albedo by removing lighting effects using Lambertian model
public class AlbedoEstimator {

    // MARK: - Configuration

    public struct Configuration {
        /// Minimum dot product for lighting correction (avoid division by near-zero)
        public var minDotProduct: Float = 0.1

        /// Maximum correction factor to avoid amplifying noise
        public var maxCorrectionFactor: Float = 3.0

        /// Default ambient light intensity if not provided
        public var defaultAmbientIntensity: Float = 1000.0

        /// Gamma correction for display (2.2 is standard)
        public var gamma: Float = 2.2

        public init() {}
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Albedo Estimation

    /// Estimate albedo for a single pixel given its color, normal, and lighting
    public func estimateAlbedo(
        color: SIMD3<Float>,  // RGB in 0-1 range
        normal: SIMD3<Float>,  // Surface normal (normalized)
        lightDirection: SIMD3<Float>,  // Light direction (normalized, pointing TO light)
        lightIntensity: Float  // Ambient intensity (lumens)
    ) -> SIMD3<Float> {

        // Calculate Lambertian term: N · L
        let dotNL = max(dot(normal, lightDirection), configuration.minDotProduct)

        // Normalize light intensity to 0-1 range (assume 1000 lumens = standard)
        let normalizedIntensity = lightIntensity / configuration.defaultAmbientIntensity

        // Combined lighting factor
        let lightingFactor = dotNL * normalizedIntensity

        // Clamp correction factor to avoid amplifying noise
        let correctionFactor = min(1.0 / lightingFactor, configuration.maxCorrectionFactor)

        // Apply correction to each color channel
        var albedo = color * correctionFactor

        // Clamp to valid range
        albedo = clamp(albedo, min: SIMD3<Float>(repeating: 0), max: SIMD3<Float>(repeating: 1))

        return albedo
    }

    /// Process entire image to estimate albedo map
    /// This assumes uniform lighting across the face (simplified model)
    public func processImage(
        image: UIImage,
        lightDirection: SIMD3<Float>,
        lightIntensity: Float,
        averageNormal: SIMD3<Float> = SIMD3<Float>(0, 0, 1)  // Default: facing camera
    ) -> UIImage? {

        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        // Extract RGBA pixel data
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

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Process each pixel
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let r = Float(pixelData[i]) / 255.0
            let g = Float(pixelData[i + 1]) / 255.0
            let b = Float(pixelData[i + 2]) / 255.0

            let color = SIMD3<Float>(r, g, b)

            // Estimate albedo
            let albedo = estimateAlbedo(
                color: color,
                normal: averageNormal,
                lightDirection: lightDirection,
                lightIntensity: lightIntensity
            )

            // Write back
            pixelData[i] = UInt8(albedo.x * 255.0)
            pixelData[i + 1] = UInt8(albedo.y * 255.0)
            pixelData[i + 2] = UInt8(albedo.z * 255.0)
            // Alpha stays the same (pixelData[i + 3])
        }

        // Create corrected image
        guard let correctedCGImage = context.makeImage() else { return nil }

        return UIImage(cgImage: correctedCGImage)
    }

    /// Process image with per-pixel normals (more accurate but requires geometry projection)
    public func processImageWithNormals(
        image: UIImage,
        normalMap: [[SIMD3<Float>]],  // 2D array of normals (height x width)
        lightDirection: SIMD3<Float>,
        lightIntensity: Float
    ) -> UIImage? {

        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        guard normalMap.count == height, normalMap[0].count == width else {
            print("⚠️ AlbedoEstimator: Normal map dimensions don't match image")
            return processImage(image: image, lightDirection: lightDirection, lightIntensity: lightIntensity)
        }

        // Extract RGBA pixel data
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

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Process each pixel with its corresponding normal
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * 4

                let r = Float(pixelData[pixelIndex]) / 255.0
                let g = Float(pixelData[pixelIndex + 1]) / 255.0
                let b = Float(pixelData[pixelIndex + 2]) / 255.0

                let color = SIMD3<Float>(r, g, b)
                let normal = normalMap[y][x]

                // Estimate albedo
                let albedo = estimateAlbedo(
                    color: color,
                    normal: normal,
                    lightDirection: lightDirection,
                    lightIntensity: lightIntensity
                )

                // Write back
                pixelData[pixelIndex] = UInt8(albedo.x * 255.0)
                pixelData[pixelIndex + 1] = UInt8(albedo.y * 255.0)
                pixelData[pixelIndex + 2] = UInt8(albedo.z * 255.0)
            }
        }

        // Create corrected image
        guard let correctedCGImage = context.makeImage() else { return nil }

        return UIImage(cgImage: correctedCGImage)
    }

    // MARK: - Helpers

    /// Convert sRGB to linear color space
    private func sRGBToLinear(_ value: Float) -> Float {
        if value <= 0.04045 {
            return value / 12.92
        } else {
            return pow((value + 0.055) / 1.055, configuration.gamma)
        }
    }

    /// Convert linear to sRGB color space
    private func linearToSRGB(_ value: Float) -> Float {
        if value <= 0.0031308 {
            return value * 12.92
        } else {
            return 1.055 * pow(value, 1.0 / configuration.gamma) - 0.055
        }
    }

    /// Clamp SIMD3 vector
    private func clamp(_ value: SIMD3<Float>, min: SIMD3<Float>, max: SIMD3<Float>) -> SIMD3<Float> {
        return SIMD3<Float>(
            Swift.max(min.x, Swift.min(max.x, value.x)),
            Swift.max(min.y, Swift.min(max.y, value.y)),
            Swift.max(min.z, Swift.min(max.z, value.z))
        )
    }
}
