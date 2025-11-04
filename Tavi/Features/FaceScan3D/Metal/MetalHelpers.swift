//
//  MetalHelpers.swift
//  Tavi
//
//  Utility functions for UIImage ↔ MTLTexture conversion
//  Created on 2025-11-04.
//

import Foundation
import Metal
import UIKit
import CoreGraphics
import os.log

/// Helper utilities for Metal texture operations
public enum MetalHelpers {

    private static let logger = Logger(subsystem: "com.tavi.app", category: "MetalHelpers")

    // MARK: - UIImage → MTLTexture Conversion

    /// Convert UIImage to MTLTexture for GPU processing
    /// - Parameters:
    ///   - image: Input UIImage
    ///   - device: Metal device
    /// - Returns: MTLTexture, or nil if conversion failed
    public static func textureFromUIImage(_ image: UIImage, device: MTLDevice) -> MTLTexture? {
        // Get CGImage from UIImage
        guard let cgImage = image.cgImage else {
            logger.error("UIImage has no CGImage")
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height

        // Create texture descriptor
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            logger.error("Failed to create MTLTexture")
            return nil
        }

        // Create RGBA color space
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            logger.error("Failed to create color space")
            return nil
        }

        // Allocate pixel buffer
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let pixelData = UnsafeMutableRawPointer.allocate(
            byteCount: bytesPerRow * height,
            alignment: MemoryLayout<UInt8>.alignment
        )
        defer {
            pixelData.deallocate()
        }

        // Create bitmap context and draw image
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            logger.error("Failed to create CGContext")
            return nil
        }

        // Draw image into context (flipping coordinate system for Metal)
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Copy pixel data to texture
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: width, height: height, depth: 1)
        )

        texture.replace(
            region: region,
            mipmapLevel: 0,
            withBytes: pixelData,
            bytesPerRow: bytesPerRow
        )

        return texture
    }

    // MARK: - MTLTexture → UIImage Conversion

    /// Convert MTLTexture back to UIImage
    /// - Parameter texture: Metal texture
    /// - Returns: UIImage, or nil if conversion failed
    public static func uiImageFromTexture(_ texture: MTLTexture) -> UIImage? {
        let width = texture.width
        let height = texture.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width

        // Allocate pixel buffer
        let pixelData = UnsafeMutableRawPointer.allocate(
            byteCount: bytesPerRow * height,
            alignment: MemoryLayout<UInt8>.alignment
        )
        defer {
            pixelData.deallocate()
        }

        // Copy texture data to CPU
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: width, height: height, depth: 1)
        )

        texture.getBytes(
            pixelData,
            bytesPerRow: bytesPerRow,
            from: region,
            mipmapLevel: 0
        )

        // Create CGImage from pixel data
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            logger.error("Failed to create color space")
            return nil
        }

        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let dataProvider = CGDataProvider(
            dataInfo: nil,
            data: pixelData,
            size: bytesPerRow * height,
            releaseData: { _, _, _ in }
        ) else {
            logger.error("Failed to create data provider")
            return nil
        }

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: bytesPerPixel * 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            logger.error("Failed to create CGImage")
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - Texture Info

    /// Get human-readable texture info for debugging
    /// - Parameter texture: Metal texture
    /// - Returns: Debug description string
    public static func textureInfo(_ texture: MTLTexture) -> String {
        let sizeMB = Double(texture.width * texture.height * 4) / 1_048_576.0
        return """
        MTLTexture:
          Size: \(texture.width)×\(texture.height)
          Format: \(texture.pixelFormat.description)
          Usage: \(texture.usage)
          Memory: \(String(format: "%.2f", sizeMB)) MB
        """
    }
}

// MARK: - MTLPixelFormat Extension

extension MTLPixelFormat {
    var description: String {
        switch self {
        case .rgba8Unorm: return "RGBA8Unorm"
        case .bgra8Unorm: return "BGRA8Unorm"
        case .rgba16Float: return "RGBA16Float"
        case .rgba32Float: return "RGBA32Float"
        default: return "Other(\(self.rawValue))"
        }
    }
}
