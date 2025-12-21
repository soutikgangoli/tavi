//
//  MetalAnalyzerBase.swift
//  Tavi
//
//  Base class for GPU-accelerated skin analyzers
//  Provides shared Metal infrastructure and pipeline management
//

import Foundation
import Metal
import MetalPerformanceShaders
import UIKit
import os.log

// MARK: - GPU Analysis Errors

public enum GPUAnalysisError: Error, CustomStringConvertible {
    case metalUnavailable
    case pipelineCreationFailed(String)
    case textureCreationFailed(String)
    case commandBufferFailed(String)
    case timeout(String)
    case invalidInput(String)
    case computationFailed(String)

    public var description: String {
        switch self {
        case .metalUnavailable:
            return "Metal GPU not available on this device"
        case .pipelineCreationFailed(let function):
            return "Failed to create compute pipeline for '\(function)'"
        case .textureCreationFailed(let details):
            return "Failed to create texture: \(details)"
        case .commandBufferFailed(let details):
            return "Command buffer execution failed: \(details)"
        case .timeout(let operation):
            return "GPU operation timed out: \(operation)"
        case .invalidInput(let details):
            return "Invalid input: \(details)"
        case .computationFailed(let details):
            return "GPU computation failed: \(details)"
        }
    }
}

// MARK: - Metal Analyzer Base

/// Base class for all GPU-accelerated skin analyzers
/// Provides shared Metal device, command queue, and pipeline caching
open class MetalAnalyzerBase {

    // MARK: - Properties

    /// Shared Metal device (GPU)
    public let device: MTLDevice

    /// Command queue for submitting GPU work
    public let commandQueue: MTLCommandQueue

    /// Pipeline state cache (function name -> compiled pipeline)
    /// Caching prevents expensive recompilation on every analysis
    private var pipelineCache: [String: MTLComputePipelineState] = [:]

    /// Concurrent access lock for pipeline cache
    private let cacheLock = NSLock()

    /// Logger for debugging
    private let logger = Logger(subsystem: "com.tavi.app", category: "MetalAnalyzer")

    /// Default GPU timeout (5 seconds)
    /// Prevents hang if shader gets stuck
    public static let defaultTimeout: TimeInterval = 5.0

    // MARK: - Initialization

    /// Initialize with Metal device
    /// - Parameter device: Metal device to use for GPU operations
    /// - Throws: GPUAnalysisError.metalUnavailable if device/queue creation fails
    public init(device: MTLDevice) throws {
        guard let queue = device.makeCommandQueue() else {
            throw GPUAnalysisError.metalUnavailable
        }

        self.device = device
        self.commandQueue = queue

        logger.info("✅ MetalAnalyzerBase initialized with device: \(device.name)")
    }

    /// Convenience initializer using system default device
    /// - Throws: GPUAnalysisError.metalUnavailable if Metal is not available
    public convenience init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw GPUAnalysisError.metalUnavailable
        }
        try self.init(device: device)
    }

    // MARK: - Pipeline Management

    /// Load and cache a compute pipeline for the specified function
    /// - Parameter functionName: Name of the Metal kernel function
    /// - Returns: Compiled compute pipeline state
    /// - Throws: GPUAnalysisError.pipelineCreationFailed if compilation fails
    public func loadPipeline(named functionName: String) throws -> MTLComputePipelineState {
        // Check cache first (thread-safe)
        cacheLock.lock()
        if let cached = pipelineCache[functionName] {
            cacheLock.unlock()
            logger.debug("📦 Using cached pipeline: \(functionName)")
            return cached
        }
        cacheLock.unlock()

        // Load shader library
        guard let library = device.makeDefaultLibrary() else {
            throw GPUAnalysisError.pipelineCreationFailed("\(functionName): failed to load Metal library")
        }

        // Find function in library
        guard let function = library.makeFunction(name: functionName) else {
            throw GPUAnalysisError.pipelineCreationFailed("\(functionName): function not found in library")
        }

        // Compile pipeline
        let pipeline: MTLComputePipelineState
        do {
            pipeline = try device.makeComputePipelineState(function: function)
        } catch {
            throw GPUAnalysisError.pipelineCreationFailed("\(functionName): \(error.localizedDescription)")
        }

        // Cache for future use (thread-safe)
        cacheLock.lock()
        pipelineCache[functionName] = pipeline
        cacheLock.unlock()

        logger.info("✅ Compiled pipeline: \(functionName)")
        logger.debug("   Max threads per threadgroup: \(pipeline.maxTotalThreadsPerThreadgroup)")
        logger.debug("   Thread execution width: \(pipeline.threadExecutionWidth)")

        return pipeline
    }

    /// Clear pipeline cache (useful for memory management)
    public func clearPipelineCache() {
        cacheLock.lock()
        pipelineCache.removeAll()
        cacheLock.unlock()
        logger.info("🧹 Pipeline cache cleared")
    }

    // MARK: - Command Buffer Execution

    /// Execute GPU work with timeout protection
    /// - Parameters:
    ///   - timeout: Maximum execution time in seconds (default: 5s)
    ///   - operation: Name of operation for error messages
    ///   - work: Closure that encodes GPU commands into command buffer
    /// - Throws: GPUAnalysisError if execution fails or times out
    public func executeWithTimeout(
        timeout: TimeInterval = MetalAnalyzerBase.defaultTimeout,
        operation: String,
        work: (MTLCommandBuffer) throws -> Void
    ) async throws {
        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw GPUAnalysisError.commandBufferFailed("\(operation): failed to create command buffer")
        }

        commandBuffer.label = operation

        // Encode work
        try work(commandBuffer)

        // Submit to GPU
        commandBuffer.commit()

        // Wait for completion with timeout
        let startTime = Date()
        while commandBuffer.status != .completed && commandBuffer.status != .error {
            // Check timeout
            if Date().timeIntervalSince(startTime) > timeout {
                throw GPUAnalysisError.timeout(operation)
            }

            // Small sleep to avoid busy-waiting
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }

        // Check for errors
        if let error = commandBuffer.error {
            throw GPUAnalysisError.commandBufferFailed("\(operation): \(error.localizedDescription)")
        }

        if commandBuffer.status == .error {
            throw GPUAnalysisError.commandBufferFailed("\(operation): command buffer status is error")
        }
    }

    /// Synchronous execute with polling (prevents 5-minute hang on GPU issues)
    /// Uses polling instead of blocking waitUntilCompleted() which can freeze app for ~5 min
    /// - Parameters:
    ///   - timeout: Maximum execution time in seconds
    ///   - operation: Name of operation for error messages
    ///   - work: Closure that encodes GPU commands
    /// - Throws: GPUAnalysisError if execution fails or times out
    public func executeSync(
        timeout: TimeInterval = MetalAnalyzerBase.defaultTimeout,
        operation: String,
        work: (MTLCommandBuffer) throws -> Void
    ) throws {
        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw GPUAnalysisError.commandBufferFailed("\(operation): failed to create command buffer")
        }

        commandBuffer.label = operation

        // Encode work
        try work(commandBuffer)

        // Submit to GPU
        commandBuffer.commit()

        // Poll for completion with timeout (prevents 5-minute hang)
        // DO NOT use waitUntilCompleted() - it blocks for GPU timeout (~5 min) if GPU hangs
        let startTime = Date()
        let pollInterval: TimeInterval = 0.002 // 2ms polling

        while commandBuffer.status != .completed && commandBuffer.status != .error {
            // Check timeout
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > timeout {
                logger.error("❌ GPU timeout after \(String(format: "%.1f", elapsed))s: \(operation)")
                throw GPUAnalysisError.timeout(operation)
            }

            // Check for task cancellation (if in async context)
            if Task.isCancelled {
                logger.info("🛑 GPU operation cancelled: \(operation)")
                throw GPUAnalysisError.timeout("\(operation) (cancelled)")
            }

            // Small sleep to avoid busy-waiting
            Thread.sleep(forTimeInterval: pollInterval)
        }

        // Check for errors
        if let error = commandBuffer.error {
            throw GPUAnalysisError.commandBufferFailed("\(operation): \(error.localizedDescription)")
        }

        if commandBuffer.status == .error {
            throw GPUAnalysisError.commandBufferFailed("\(operation): command buffer status is error")
        }
    }

    /// Execute GPU work with cancellation support (non-blocking polling)
    /// This version uses polling instead of waitUntilCompleted() to allow
    /// checking for Task cancellation, preventing thread pool exhaustion
    /// - Parameters:
    ///   - timeout: Maximum execution time in seconds (default: 5s)
    ///   - operation: Name of operation for error messages
    ///   - work: Closure that encodes GPU commands into command buffer
    /// - Throws: GPUAnalysisError if execution fails or times out, CancellationError if cancelled
    public func executeCancellable(
        timeout: TimeInterval = MetalAnalyzerBase.defaultTimeout,
        operation: String,
        work: (MTLCommandBuffer) throws -> Void
    ) async throws {
        // Check cancellation before starting
        try Task.checkCancellation()

        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw GPUAnalysisError.commandBufferFailed("\(operation): failed to create command buffer")
        }

        commandBuffer.label = operation

        // Encode work
        try work(commandBuffer)

        // Submit to GPU
        commandBuffer.commit()

        // Poll for completion with cancellation checks
        let startTime = Date()
        let pollInterval: UInt64 = 2_000_000 // 2ms polling interval

        while commandBuffer.status != .completed && commandBuffer.status != .error {
            // Check for task cancellation
            try Task.checkCancellation()

            // Check timeout
            if Date().timeIntervalSince(startTime) > timeout {
                throw GPUAnalysisError.timeout(operation)
            }

            // Yield to allow other tasks to run
            try await Task.sleep(nanoseconds: pollInterval)
        }

        // Check for GPU errors
        if let error = commandBuffer.error {
            throw GPUAnalysisError.commandBufferFailed("\(operation): \(error.localizedDescription)")
        }

        if commandBuffer.status == .error {
            throw GPUAnalysisError.commandBufferFailed("\(operation): command buffer status is error")
        }
    }

    /// Synchronous version with cancellation support using polling (NO SEMAPHORES)
    ///
    /// CRITICAL FIX: This method previously used a semaphore pattern that caused deadlocks:
    /// - Old code: Task {} + semaphore.wait() on cooperative pool → DEADLOCK
    /// - New code: Polling with Thread.sleep() + Task.isCancelled checks → SAFE
    ///
    /// The deadlock happened because:
    /// 1. This method was called from Task.detached (cooperative pool thread)
    /// 2. semaphore.wait() blocked that cooperative pool thread
    /// 3. The inner Task {} needed a cooperative pool thread to run
    /// 4. All cooperative pool threads were blocked → DEADLOCK
    ///
    /// - Parameters:
    ///   - timeout: Maximum execution time in seconds (default: 5s)
    ///   - operation: Name of operation for error messages
    ///   - work: Closure that encodes GPU commands into command buffer
    /// - Throws: GPUAnalysisError if execution fails, times out, or is cancelled
    public func executeCancellableSync(
        timeout: TimeInterval = MetalAnalyzerBase.defaultTimeout,
        operation: String,
        work: @escaping (MTLCommandBuffer) throws -> Void
    ) throws {
        // Check cancellation IMMEDIATELY before starting any work
        if Task.isCancelled {
            logger.info("🛑 GPU operation cancelled before start: \(operation)")
            throw GPUAnalysisError.timeout("\(operation) (cancelled)")
        }

        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw GPUAnalysisError.commandBufferFailed("\(operation): failed to create command buffer")
        }

        commandBuffer.label = operation

        // Encode work
        try work(commandBuffer)

        // Submit to GPU
        commandBuffer.commit()

        // Poll for completion with timeout AND cancellation checks
        // CRITICAL: NO SEMAPHORE - use Thread.sleep which doesn't block cooperative pool
        let startTime = Date()
        let pollInterval: TimeInterval = 0.002 // 2ms polling

        while commandBuffer.status != .completed && commandBuffer.status != .error {
            // Check timeout
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > timeout {
                logger.error("❌ GPU timeout after \(String(format: "%.1f", elapsed))s: \(operation)")
                throw GPUAnalysisError.timeout(operation)
            }

            // Check for task cancellation (CRITICAL for responsive cancel)
            if Task.isCancelled {
                logger.info("🛑 GPU operation cancelled during execution: \(operation)")
                throw GPUAnalysisError.timeout("\(operation) (cancelled)")
            }

            // Small sleep to avoid busy-waiting
            // Thread.sleep is safe here - it doesn't block the cooperative thread pool
            // because this code runs on a detached thread from Task.detached
            Thread.sleep(forTimeInterval: pollInterval)
        }

        // Check for GPU errors
        if let error = commandBuffer.error {
            throw GPUAnalysisError.commandBufferFailed("\(operation): \(error.localizedDescription)")
        }

        if commandBuffer.status == .error {
            throw GPUAnalysisError.commandBufferFailed("\(operation): command buffer status is error")
        }
    }

    // MARK: - Texture Creation Helpers

    /// Create a 2D texture with specified dimensions and format
    /// - Parameters:
    ///   - width: Texture width in pixels
    ///   - height: Texture height in pixels
    ///   - format: Pixel format (default: RGBA8Unorm)
    ///   - usage: Texture usage flags (default: read + write)
    /// - Returns: Metal texture
    /// - Throws: GPUAnalysisError.textureCreationFailed if creation fails
    public func createTexture(
        width: Int,
        height: Int,
        format: MTLPixelFormat = .rgba8Unorm,
        usage: MTLTextureUsage = [.shaderRead, .shaderWrite]
    ) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = usage

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw GPUAnalysisError.textureCreationFailed("\(width)x\(height), format: \(format)")
        }

        return texture
    }

    /// Create buffer for storing data
    /// - Parameters:
    ///   - length: Buffer size in bytes
    ///   - options: Buffer storage options
    /// - Returns: Metal buffer
    /// - Throws: GPUAnalysisError if creation fails
    public func createBuffer(
        length: Int,
        options: MTLResourceOptions = .storageModeShared
    ) throws -> MTLBuffer {
        guard let buffer = device.makeBuffer(length: length, options: options) else {
            throw GPUAnalysisError.textureCreationFailed("buffer of length \(length)")
        }
        return buffer
    }

    // MARK: - Thread Dispatch Calculation

    /// Calculate optimal threadgroup configuration for 2D texture
    /// - Parameters:
    ///   - pipeline: Compute pipeline to execute
    ///   - width: Texture width
    ///   - height: Texture height
    /// - Returns: Tuple of (threadgroups, threadsPerThreadgroup)
    public func calculateThreadgroups(
        pipeline: MTLComputePipelineState,
        width: Int,
        height: Int
    ) -> (threadgroups: MTLSize, threadsPerThreadgroup: MTLSize) {
        // Get optimal thread execution width from pipeline
        let w = pipeline.threadExecutionWidth
        let h = pipeline.maxTotalThreadsPerThreadgroup / w

        let threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)

        let threadgroups = MTLSize(
            width: (width + w - 1) / w,
            height: (height + h - 1) / h,
            depth: 1
        )

        return (threadgroups, threadsPerThreadgroup)
    }

    /// Calculate threadgroup configuration for 1D processing
    /// Useful for reduction operations
    /// - Parameters:
    ///   - pipeline: Compute pipeline
    ///   - totalThreads: Total number of threads needed
    /// - Returns: Tuple of (threadgroups, threadsPerThreadgroup)
    public func calculateThreadgroups1D(
        pipeline: MTLComputePipelineState,
        totalThreads: Int
    ) -> (threadgroups: MTLSize, threadsPerThreadgroup: MTLSize) {
        let threadsPerGroup = min(pipeline.maxTotalThreadsPerThreadgroup, 256)
        let numGroups = (totalThreads + threadsPerGroup - 1) / threadsPerGroup

        return (
            threadgroups: MTLSize(width: numGroups, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: threadsPerGroup, height: 1, depth: 1)
        )
    }
}
