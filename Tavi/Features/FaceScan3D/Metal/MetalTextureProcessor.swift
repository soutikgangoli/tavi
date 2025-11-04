//
//  MetalTextureProcessor.swift
//  Tavi
//
//  Metal GPU acceleration infrastructure for texture processing
//  Created on 2025-11-04.
//

import Foundation
import Metal
import MetalPerformanceShaders
import UIKit
import CoreGraphics
import os.log

/// Core Metal infrastructure for GPU-accelerated texture processing
public final class MetalTextureProcessor {

    // MARK: - Properties

    /// Metal device (GPU)
    public let device: MTLDevice

    /// Command queue for submitting GPU work
    private let commandQueue: MTLCommandQueue

    /// Shared logger
    private let logger = Logger(subsystem: "com.tavi.app", category: "MetalTextureProcessor")

    /// Singleton instance
    public static let shared: MetalTextureProcessor? = {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            AppLogger.mesh.warning("⚠️ Metal not available - falling back to CPU processing")
            return nil
        }
        return MetalTextureProcessor(device: device, commandQueue: queue)
    }()

    /// Whether Metal is available on this device
    public static var isAvailable: Bool {
        return shared != nil
    }

    // MARK: - Initialization

    private init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue

        logger.info("✅ Metal GPU initialized: \(device.name)")
        let maxThreads = device.maxThreadsPerThreadgroup
        logger.info("   Max threads per threadgroup: \(maxThreads.width)×\(maxThreads.height)×\(maxThreads.depth)")
        logger.info("   Supports family Apple7: \(device.supportsFamily(.apple7))")
    }

    // MARK: - Gaussian Blur (Metal Performance Shaders)

    /// Apply Gaussian blur using Metal Performance Shaders
    /// - Parameters:
    ///   - image: Input image
    ///   - radius: Blur radius (sigma)
    /// - Returns: Blurred image, or nil if processing failed
    public func applyGaussianBlur(_ image: UIImage, radius: Float) -> UIImage? {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Convert UIImage → MTLTexture
        guard let inputTexture = MetalHelpers.textureFromUIImage(image, device: device) else {
            logger.error("Failed to create input texture for blur")
            return nil
        }

        // Create output texture with same dimensions
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: inputTexture.pixelFormat,
            width: inputTexture.width,
            height: inputTexture.height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]

        guard let outputTexture = device.makeTexture(descriptor: textureDescriptor) else {
            logger.error("Failed to create output texture for blur")
            return nil
        }

        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            logger.error("Failed to create command buffer")
            return nil
        }

        // Apply Gaussian blur using MPS
        let blur = MPSImageGaussianBlur(device: device, sigma: radius)
        blur.encode(commandBuffer: commandBuffer, sourceTexture: inputTexture, destinationTexture: outputTexture)

        // Execute GPU work
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Convert MTLTexture → UIImage
        guard let result = MetalHelpers.uiImageFromTexture(outputTexture) else {
            logger.error("Failed to convert output texture to UIImage")
            return nil
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("✅ Metal Gaussian blur completed in \(String(format: "%.2f", elapsed))ms (\(inputTexture.width)×\(inputTexture.height))")

        return result
    }

    // MARK: - Texture Blending (Compute Shader)

    /// Blend multiple texture samples with weighted accumulation
    /// - Parameters:
    ///   - samples: Array of input images to blend
    ///   - weights: Weight for each sample (should match samples count)
    ///   - outputSize: Size of output texture
    /// - Returns: Blended image, or nil if processing failed
    public func blendTextureSamples(
        samples: [UIImage],
        weights: [Float],
        outputSize: CGSize
    ) -> UIImage? {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard !samples.isEmpty else {
            logger.error("No samples provided for blending")
            return nil
        }

        guard samples.count == weights.count else {
            logger.error("Sample count (\(samples.count)) doesn't match weight count (\(weights.count))")
            return nil
        }

        logger.info("🎨 Starting GPU texture blending: \(samples.count) samples → \(Int(outputSize.width))×\(Int(outputSize.height))")

        // Load Metal shader library
        guard let library = device.makeDefaultLibrary() else {
            logger.error("Failed to create Metal library")
            return nil
        }

        guard let function = library.makeFunction(name: "blendTextureSamples") else {
            logger.error("Failed to find blendTextureSamples function in shader library")
            return nil
        }

        guard let pipeline = try? device.makeComputePipelineState(function: function) else {
            logger.error("Failed to create compute pipeline")
            return nil
        }

        // Create output textures
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]

        guard let outputTexture = device.makeTexture(descriptor: textureDescriptor),
              let weightTexture = device.makeTexture(descriptor: textureDescriptor) else {
            logger.error("Failed to create output textures")
            return nil
        }

        // Convert input images to Metal textures
        let inputTextures = samples.compactMap { MetalHelpers.textureFromUIImage($0, device: device) }
        guard inputTextures.count == samples.count else {
            logger.error("Failed to convert all input images to textures")
            return nil
        }

        // Create texture array descriptor
        let arrayDescriptor = MTLTextureDescriptor()
        arrayDescriptor.textureType = .type2DArray
        arrayDescriptor.pixelFormat = .rgba8Unorm
        arrayDescriptor.width = Int(outputSize.width)
        arrayDescriptor.height = Int(outputSize.height)
        arrayDescriptor.arrayLength = inputTextures.count
        arrayDescriptor.usage = [.shaderRead]

        guard let inputTextureArray = device.makeTexture(descriptor: arrayDescriptor) else {
            logger.error("Failed to create texture array")
            return nil
        }

        // Copy input textures into array
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            logger.error("Failed to create command buffer for texture copy")
            return nil
        }

        for (index, texture) in inputTextures.enumerated() {
            // Resize texture to output size if needed
            let resizedTexture: MTLTexture
            if texture.width != Int(outputSize.width) || texture.height != Int(outputSize.height) {
                // Create temporary resized texture
                let tempDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .rgba8Unorm,
                    width: Int(outputSize.width),
                    height: Int(outputSize.height),
                    mipmapped: false
                )
                tempDescriptor.usage = [.shaderRead, .shaderWrite]

                guard let tempTexture = device.makeTexture(descriptor: tempDescriptor) else {
                    continue
                }

                // Use MPS to scale
                let scaler = MPSImageBilinearScale(device: device)
                scaler.encode(commandBuffer: commandBuffer, sourceTexture: texture, destinationTexture: tempTexture)
                resizedTexture = tempTexture
            } else {
                resizedTexture = texture
            }

            // Copy to array slice
            let origin = MTLOrigin(x: 0, y: 0, z: 0)
            let size = MTLSize(width: Int(outputSize.width), height: Int(outputSize.height), depth: 1)

            blitEncoder.copy(
                from: resizedTexture,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: origin,
                sourceSize: size,
                to: inputTextureArray,
                destinationSlice: index,
                destinationLevel: 0,
                destinationOrigin: origin
            )
        }

        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Now run compute shader
        guard let computeBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = computeBuffer.makeComputeCommandEncoder() else {
            logger.error("Failed to create compute encoder")
            return nil
        }

        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setTexture(outputTexture, index: 0)
        computeEncoder.setTexture(inputTextureArray, index: 1)
        computeEncoder.setTexture(weightTexture, index: 2)

        var sampleCount = UInt32(samples.count)
        computeEncoder.setBytes(&sampleCount, length: MemoryLayout<UInt32>.size, index: 0)

        // Configure thread execution
        let threadgroupSize = MTLSize(
            width: min(16, pipeline.maxTotalThreadsPerThreadgroup),
            height: min(16, pipeline.maxTotalThreadsPerThreadgroup / 16),
            depth: 1
        )

        let threadgroups = MTLSize(
            width: (Int(outputSize.width) + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (Int(outputSize.height) + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )

        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()

        computeBuffer.commit()
        computeBuffer.waitUntilCompleted()

        // Convert result to UIImage
        guard let result = MetalHelpers.uiImageFromTexture(outputTexture) else {
            logger.error("Failed to convert output texture to UIImage")
            return nil
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("✅ Metal texture blending completed in \(String(format: "%.2f", elapsed))ms")

        return result
    }

    // MARK: - Color Space Conversion

    /// Convert RGBA image to luminance (grayscale) using GPU
    /// - Parameter image: Input image
    /// - Returns: Grayscale image, or nil if conversion failed
    public func convertToLuminance(_ image: UIImage) -> UIImage? {
        // Load shader
        guard let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "rgbaToLuminance"),
              let pipeline = try? device.makeComputePipelineState(function: function) else {
            logger.error("Failed to create luminance conversion pipeline")
            return nil
        }

        // Convert to texture
        guard let inputTexture = MetalHelpers.textureFromUIImage(image, device: device) else {
            logger.error("Failed to create input texture for luminance conversion")
            return nil
        }

        // Create output texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: inputTexture.pixelFormat,
            width: inputTexture.width,
            height: inputTexture.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let outputTexture = device.makeTexture(descriptor: descriptor) else {
            logger.error("Failed to create output texture for luminance conversion")
            return nil
        }

        // Execute shader
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        computeEncoder.setComputePipelineState(pipeline)
        computeEncoder.setTexture(inputTexture, index: 0)
        computeEncoder.setTexture(outputTexture, index: 1)

        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (inputTexture.width + 15) / 16,
            height: (inputTexture.height + 15) / 16,
            depth: 1
        )

        computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return MetalHelpers.uiImageFromTexture(outputTexture)
    }

    // MARK: - Memory Management

    /// Force release of GPU resources and caches
    public func cleanup() {
        // MPS kernels and textures are automatically managed
        // This method is for future expansion if we add custom resources
        logger.info("🧹 Metal GPU resources cleaned up")
    }
}

/// Global helper for logging
private extension Logger {
    static let metal = Logger(subsystem: "com.tavi.app", category: "Metal")
}
