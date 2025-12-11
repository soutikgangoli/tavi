//
//  MetalCapabilities.swift
//  Tavi
//
//  Device capability checks for GPU-accelerated skin analysis
//  Determines if device supports required Metal features
//

import Foundation
import Metal
import os.log

/// Singleton class for checking Metal device capabilities
/// Determines if GPU acceleration is available and suitable for skin analysis
public final class MetalCapabilities {

    // MARK: - Singleton

    public static let shared = MetalCapabilities()

    // MARK: - Properties

    /// Metal device (if available)
    public let device: MTLDevice?

    /// Logger
    private let logger = Logger(subsystem: "com.tavi.app", category: "MetalCapabilities")

    // MARK: - Initialization

    private init() {
        self.device = MTLCreateSystemDefaultDevice()

        if let device = device {
            logger.info("✅ Metal device detected: \(device.name)")
            logCapabilities()
        } else {
            logger.warning("⚠️ Metal not available on this device")
        }
    }

    // MARK: - Capability Checks

    /// Check if Metal is available
    public var isMetalAvailable: Bool {
        return device != nil
    }

    /// Check if device supports Apple GPU Family 3 or higher
    /// Required for advanced compute features used in skin analysis
    public var supportsAppleGPUFamily3: Bool {
        guard let device = device else { return false }

        // Check Apple families (newer iOS devices)
        if device.supportsFamily(.apple3) {
            return true
        }

        // Fallback check for older API
        if #available(iOS 13.0, *) {
            return device.supportsFamily(.apple3)
        }

        return false
    }

    /// Check if device supports required texture size
    /// Skin analysis uses 4096x4096 textures
    public var supportsRequiredTextureSize: Bool {
        guard let device = device else { return false }

        // Check if device supports 4096x4096 textures
        // Most modern iOS devices support up to 16384x16384
        let requiredSize = 4096

        // Create a test descriptor to verify
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: requiredSize,
            height: requiredSize,
            mipmapped: false
        )

        // Try to create texture (very lightweight, just checks limits)
        let testTexture = device.makeTexture(descriptor: descriptor)
        return testTexture != nil
    }

    /// Check if device supports required threadgroup memory
    /// Analysis kernels need at least 16KB of shared memory
    public var supportsRequiredThreadgroupMemory: Bool {
        guard let device = device else { return false }

        // Check max threadgroup memory
        // Modern iOS devices support 32KB-64KB
        let requiredMemory = 16 * 1024  // 16KB

        // Most Apple GPUs support 32KB+, but check to be safe
        // Unfortunately, there's no direct API to query this
        // We'll use GPU family as a proxy
        return supportsAppleGPUFamily3
    }

    /// Check if device supports all features required for GPU analysis
    public var supportsGPUAnalysis: Bool {
        guard isMetalAvailable else {
            logger.info("❌ GPU analysis not supported: Metal not available")
            return false
        }

        guard supportsAppleGPUFamily3 else {
            logger.info("❌ GPU analysis not supported: Requires Apple GPU Family 3+")
            return false
        }

        guard supportsRequiredTextureSize else {
            logger.info("❌ GPU analysis not supported: Cannot create 4096x4096 textures")
            return false
        }

        guard supportsRequiredThreadgroupMemory else {
            logger.info("❌ GPU analysis not supported: Insufficient threadgroup memory")
            return false
        }

        logger.info("✅ GPU analysis fully supported on this device")
        return true
    }

    // MARK: - Device Information

    /// Get maximum supported texture size (width or height)
    public var maxTextureSize: Int {
        guard let device = device else { return 0 }

        // Try progressively larger textures to find limit
        // This is a rough estimate - actual limit may be higher
        let testSizes = [4096, 8192, 16384, 32768]

        for size in testSizes {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: size,
                height: size,
                mipmapped: false
            )
            descriptor.usage = .shaderRead

            if device.makeTexture(descriptor: descriptor) == nil {
                // Previous size was the max
                let index = testSizes.firstIndex(of: size) ?? 0
                return index > 0 ? testSizes[index - 1] : 0
            }
        }

        return testSizes.last ?? 0
    }

    /// Get maximum threads per threadgroup
    public var maxThreadsPerThreadgroup: MTLSize {
        guard let device = device else {
            return MTLSize(width: 0, height: 0, depth: 0)
        }
        return device.maxThreadsPerThreadgroup
    }

    /// Get recommended threadgroup size for 2D kernels
    /// Returns optimal size based on device capabilities
    public var recommendedThreadgroupSize: MTLSize {
        guard let device = device else {
            return MTLSize(width: 16, height: 16, depth: 1)
        }

        let maxThreads = device.maxThreadsPerThreadgroup

        // Use 16x16 (256 threads) as default for 2D processing
        // This works well on all modern iOS devices
        if maxThreads.width >= 16 && maxThreads.height >= 16 {
            return MTLSize(width: 16, height: 16, depth: 1)
        }

        // Fallback to 8x8 for older devices
        return MTLSize(width: 8, height: 8, depth: 1)
    }

    // MARK: - Fallback Recommendation

    /// Get recommendation for CPU fallback configuration
    /// Returns optimal downsampling size for CPU processing
    public var cpuFallbackDownsampleSize: Int {
        // If GPU is available but limited, use higher resolution CPU fallback
        if isMetalAvailable && !supportsGPUAnalysis {
            return 2048  // Higher quality fallback
        }

        // Standard CPU fallback resolution
        return 1024
    }

    // MARK: - Diagnostics

    /// Log detailed device capabilities
    public func logCapabilities() {
        guard let device = device else {
            logger.info("📊 Metal Capabilities: Not available")
            return
        }

        logger.info("📊 Metal Device Capabilities:")
        logger.info("   Device: \(device.name)")
        logger.info("   Metal available: ✅")
        logger.info("   Apple GPU Family 3+: \(supportsAppleGPUFamily3 ? "✅" : "❌")")
        logger.info("   Max texture size: \(maxTextureSize)x\(maxTextureSize)")
        logger.info("   Max threads/threadgroup: \(maxThreadsPerThreadgroup.width)x\(maxThreadsPerThreadgroup.height)x\(maxThreadsPerThreadgroup.depth)")
        logger.info("   Recommended threadgroup: \(recommendedThreadgroupSize.width)x\(recommendedThreadgroupSize.height)")
        logger.info("   Supports 4096x4096 textures: \(supportsRequiredTextureSize ? "✅" : "❌")")
        logger.info("   GPU analysis ready: \(supportsGPUAnalysis ? "✅" : "❌")")

        // Additional GPU family checks
        if #available(iOS 13.0, *) {
            logger.info("   GPU Families:")
            logger.info("     Apple 1: \(device.supportsFamily(.apple1) ? "✅" : "❌")")
            logger.info("     Apple 2: \(device.supportsFamily(.apple2) ? "✅" : "❌")")
            logger.info("     Apple 3: \(device.supportsFamily(.apple3) ? "✅" : "❌")")
            logger.info("     Apple 4: \(device.supportsFamily(.apple4) ? "✅" : "❌")")
            logger.info("     Apple 5: \(device.supportsFamily(.apple5) ? "✅" : "❌")")
            logger.info("     Apple 6: \(device.supportsFamily(.apple6) ? "✅" : "❌")")
            logger.info("     Apple 7: \(device.supportsFamily(.apple7) ? "✅" : "❌")")
        }

        // Memory recommendations
        if supportsGPUAnalysis {
            logger.info("   ✅ Use GPU acceleration (full 4096x4096 resolution)")
        } else if isMetalAvailable {
            logger.info("   ⚠️ Limited Metal support - use CPU with \(cpuFallbackDownsampleSize)x\(cpuFallbackDownsampleSize)")
        } else {
            logger.info("   ⚠️ No Metal - use CPU with 1024x1024 downsampling")
        }
    }

    /// Get device description for debugging
    public var deviceDescription: String {
        guard let device = device else {
            return "Metal: Not available"
        }

        let gpuSupport = supportsGPUAnalysis ? "GPU-Ready" : "CPU Fallback"
        return "\(device.name) [\(gpuSupport)]"
    }

    /// Check if GPU should be used for analysis (convenience)
    public var shouldUseGPU: Bool {
        return supportsGPUAnalysis
    }

    /// Check if CPU fallback is needed
    public var needsCPUFallback: Bool {
        return !supportsGPUAnalysis
    }
}
