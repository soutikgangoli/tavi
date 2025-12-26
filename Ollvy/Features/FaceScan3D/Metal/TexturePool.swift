//
//  TexturePool.swift
//  Ollvy
//
//  Thread-safe texture memory pool for efficient GPU resource management
//  Reduces allocation overhead by reusing textures across analysis operations
//

import Foundation
import Metal
import os.log

/// Thread-safe pool for reusable Metal textures
/// Dramatically reduces GPU memory allocation overhead during analysis
public final class TexturePool {

    // MARK: - Configuration

    /// Maximum number of pooled textures per configuration
    /// Larger pools reduce allocation but increase memory usage
    private let maxPoolSize: Int

    /// Texture cache key (encodes size and format)
    private struct TextureKey: Hashable {
        let width: Int
        let height: Int
        let format: MTLPixelFormat

        func hash(into hasher: inout Hasher) {
            hasher.combine(width)
            hasher.combine(height)
            hasher.combine(format.rawValue)
        }
    }

    /// Pooled texture entry
    private struct PooledTexture {
        let texture: MTLTexture
        var inUse: Bool
        var lastUsed: Date
    }

    // MARK: - Properties

    /// Metal device for creating textures
    private let device: MTLDevice

    /// Texture pools organized by configuration
    /// Key: TextureKey (width x height x format)
    /// Value: Array of pooled textures
    private var pools: [TextureKey: [PooledTexture]] = [:]

    /// Lock for thread-safe access
    private let lock = NSLock()

    /// Logger
    private let logger = Logger(subsystem: "com.ollvy.app", category: "TexturePool")

    /// Statistics for monitoring
    private var stats = Statistics()

    private struct Statistics {
        var totalAcquisitions: Int = 0
        var cacheHits: Int = 0
        var cacheMisses: Int = 0
        var totalReleases: Int = 0

        var hitRate: Double {
            guard totalAcquisitions > 0 else { return 0 }
            return Double(cacheHits) / Double(totalAcquisitions)
        }
    }

    // MARK: - Initialization

    /// Create a texture pool
    /// - Parameters:
    ///   - device: Metal device to use for texture creation
    ///   - maxPoolSize: Maximum textures per configuration (default: 4)
    public init(device: MTLDevice, maxPoolSize: Int = 4) {
        self.device = device
        self.maxPoolSize = maxPoolSize
        logger.info("✅ TexturePool initialized (max size per config: \(maxPoolSize))")
    }

    // MARK: - Public API

    /// Acquire a texture from the pool (or create new if none available)
    /// - Parameters:
    ///   - width: Texture width in pixels
    ///   - height: Texture height in pixels
    ///   - format: Pixel format (default: RGBA8Unorm)
    /// - Returns: Reusable Metal texture
    /// - Throws: Error if texture creation fails
    public func acquire(
        width: Int,
        height: Int,
        format: MTLPixelFormat = .rgba8Unorm
    ) throws -> MTLTexture {
        let key = TextureKey(width: width, height: height, format: format)

        lock.lock()
        defer { lock.unlock() }

        stats.totalAcquisitions += 1

        // Check if we have an available texture in the pool
        if var pool = pools[key] {
            // Find first available texture
            if let index = pool.firstIndex(where: { !$0.inUse }) {
                // Mark as in use
                pool[index].inUse = true
                pool[index].lastUsed = Date()
                pools[key] = pool

                stats.cacheHits += 1
                logger.debug("📦 TexturePool: Cache HIT (\(width)x\(height), format: \(format.rawValue))")

                return pool[index].texture
            }
        }

        // Cache miss - need to create new texture
        stats.cacheMisses += 1
        logger.debug("📦 TexturePool: Cache MISS (\(width)x\(height), format: \(format.rawValue)) - creating new")

        // Create new texture
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw GPUAnalysisError.textureCreationFailed("\(width)x\(height), format: \(format)")
        }

        // Add to pool if under max size
        var pool = pools[key] ?? []
        let poolMaxSize = self.maxPoolSize
        if pool.count < poolMaxSize {
            let entry = PooledTexture(
                texture: texture,
                inUse: true,
                lastUsed: Date()
            )
            pool.append(entry)
            pools[key] = pool

            logger.debug("📦 TexturePool: Added to pool (size: \(pool.count)/\(poolMaxSize))")
        } else {
            logger.debug("📦 TexturePool: Pool full (\(pool.count)), texture not pooled")
        }

        return texture
    }

    /// Release a texture back to the pool for reuse
    /// - Parameter texture: Texture to release
    public func release(_ texture: MTLTexture) {
        lock.lock()
        defer { lock.unlock() }

        stats.totalReleases += 1

        // Find the texture in pools
        let key = TextureKey(
            width: texture.width,
            height: texture.height,
            format: texture.pixelFormat
        )

        guard var pool = pools[key] else {
            logger.debug("📦 TexturePool: Released texture not in pool (one-time use)")
            return
        }

        // Mark as available
        if let index = pool.firstIndex(where: { $0.texture === texture }) {
            pool[index].inUse = false
            pools[key] = pool
            logger.debug("📦 TexturePool: Released texture back to pool")
        } else {
            logger.debug("📦 TexturePool: Released texture not found in pool")
        }
    }

    /// Clear all pooled textures (free GPU memory)
    /// Should be called when analysis is complete or memory pressure occurs
    public func clear() {
        // Acquire lock and clear pools
        lock.lock()
        let totalTextures = pools.values.reduce(0) { $0 + $1.count }
        pools.removeAll()
        lock.unlock()

        // Log AFTER releasing lock to prevent deadlock
        // (logStatistics() -> getStatistics() tries to acquire the same lock)
        logger.info("🧹 TexturePool: Cleared \(totalTextures) pooled textures")
    }

    /// Clear only unused textures (keep in-use textures)
    /// Useful for periodic cleanup while maintaining active operations
    public func clearUnused() {
        lock.lock()
        defer { lock.unlock() }

        var clearedCount = 0

        for (key, var pool) in pools {
            // Remove unused textures
            let originalCount = pool.count
            pool.removeAll(where: { !$0.inUse })
            clearedCount += (originalCount - pool.count)

            // Update or remove pool
            if pool.isEmpty {
                pools.removeValue(forKey: key)
            } else {
                pools[key] = pool
            }
        }

        logger.info("🧹 TexturePool: Cleared \(clearedCount) unused textures")
    }

    /// Clear old unused textures (haven't been used in specified time)
    /// - Parameter maxAge: Maximum age for unused textures (default: 60 seconds)
    public func clearOld(maxAge: TimeInterval = 60) {
        lock.lock()
        defer { lock.unlock() }

        let cutoffDate = Date().addingTimeInterval(-maxAge)
        var clearedCount = 0

        for (key, var pool) in pools {
            // Remove old unused textures
            let originalCount = pool.count
            pool.removeAll(where: { !$0.inUse && $0.lastUsed < cutoffDate })
            clearedCount += (originalCount - pool.count)

            // Update or remove pool
            if pool.isEmpty {
                pools.removeValue(forKey: key)
            } else {
                pools[key] = pool
            }
        }

        if clearedCount > 0 {
            logger.info("🧹 TexturePool: Cleared \(clearedCount) old textures (>\(Int(maxAge))s)")
        }
    }

    // MARK: - Statistics

    /// Get current pool statistics
    public func getStatistics() -> (
        totalTextures: Int,
        inUseTextures: Int,
        acquisitions: Int,
        hitRate: Double
    ) {
        lock.lock()
        defer { lock.unlock() }

        let totalTextures = pools.values.reduce(0) { $0 + $1.count }
        let inUseTextures = pools.values.reduce(0) { sum, pool in
            sum + pool.filter { $0.inUse }.count
        }

        return (
            totalTextures: totalTextures,
            inUseTextures: inUseTextures,
            acquisitions: stats.totalAcquisitions,
            hitRate: stats.hitRate
        )
    }

    /// Log current statistics
    public func logStatistics() {
        let stats = getStatistics()
        logger.info("📊 TexturePool Statistics:")
        logger.info("   Total pooled: \(stats.totalTextures) textures")
        logger.info("   In use: \(stats.inUseTextures) textures")
        logger.info("   Total acquisitions: \(stats.acquisitions)")
        logger.info("   Cache hit rate: \(String(format: "%.1f%%", stats.hitRate * 100))")
    }

    // MARK: - Convenience

    /// Execute work with automatic texture acquire/release
    /// - Parameters:
    ///   - width: Texture width
    ///   - height: Texture height
    ///   - format: Pixel format
    ///   - work: Closure that uses the texture
    /// - Returns: Result from work closure
    /// - Throws: Errors from acquire or work closure
    public func withTexture<T>(
        width: Int,
        height: Int,
        format: MTLPixelFormat = .rgba8Unorm,
        work: (MTLTexture) throws -> T
    ) throws -> T {
        let texture = try acquire(width: width, height: height, format: format)
        defer { release(texture) }
        return try work(texture)
    }
}
