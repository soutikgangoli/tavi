//
//  PoreAnalyzer.swift
//  Ollvy
//
//  Pore detection and analysis using texture frequency analysis
//  High-frequency texture components indicate visible pores
//

import UIKit
import Accelerate
import Metal
import simd

/// Pore size classification
public enum PoreSize: String, Codable, Sendable {
    case small = "Small"     // < 3 pixels
    case medium = "Medium"   // 3-6 pixels
    case large = "Large"     // > 6 pixels
    case veryLarge = "Very Large"  // > 10 pixels

    public var score: Float {
        switch self {
        case .small: return 90
        case .medium: return 70
        case .large: return 50
        case .veryLarge: return 30
        }
    }
}

/// Pore size distribution
public struct PoreSizeDistribution: Codable, Sendable {
    public let smallCount: Int       // Pores < 3 pixels
    public let mediumCount: Int      // Pores 3-6 pixels
    public let largeCount: Int       // Pores 6-10 pixels
    public let veryLargeCount: Int   // Pores > 10 pixels

    public var totalCount: Int {
        smallCount + mediumCount + largeCount + veryLargeCount
    }

    public var smallPercentage: Float {
        guard totalCount > 0 else { return 0 }
        return Float(smallCount) / Float(totalCount) * 100
    }

    public var mediumPercentage: Float {
        guard totalCount > 0 else { return 0 }
        return Float(mediumCount) / Float(totalCount) * 100
    }

    public var largePercentage: Float {
        guard totalCount > 0 else { return 0 }
        return Float(largeCount) / Float(totalCount) * 100
    }

    public var veryLargePercentage: Float {
        guard totalCount > 0 else { return 0 }
        return Float(veryLargeCount) / Float(totalCount) * 100
    }

    public var dominantSize: PoreSize {
        let counts = [(PoreSize.small, smallCount), (PoreSize.medium, mediumCount),
                      (PoreSize.large, largeCount), (PoreSize.veryLarge, veryLargeCount)]
        return counts.max(by: { $0.1 < $1.1 })?.0 ?? .medium
    }
}

/// Pore analysis result
public struct PoreAnalysis: Codable, Sendable {
    public let visibility: Float  // 0-100, lower is better (inverse)
    public let visibilityScore: Float  // 0-100, higher is better (for consistency with other metrics)
    public let density: Float     // pores per cm²
    public let averageSize: Float // in pixels
    public let sizeDistribution: PoreSizeDistribution  // NEW: Size classification
    public let dominantSize: PoreSize  // NEW: Most common pore size
    public let regionalScores: [String: Float]
    public let confidence: Float  // 0-100, reliability of detection

    public init(visibility: Float, density: Float, averageSize: Float, sizeDistribution: PoreSizeDistribution, regionalScores: [String: Float], confidence: Float) {
        self.visibility = visibility
        self.visibilityScore = 100 - visibility  // Inverse for consistency
        self.density = density
        self.averageSize = averageSize
        self.sizeDistribution = sizeDistribution
        self.dominantSize = sizeDistribution.dominantSize
        self.regionalScores = regionalScores
        self.confidence = confidence
    }
}

/// Pore analyzer using texture frequency analysis
class PoreAnalyzer {

    // MARK: - Resolution-Aware Pore Thresholds

    /// Resolution-aware pore size thresholds
    /// Based on 4096x4096 reference resolution (1 pixel ≈ 0.025mm on face)
    private struct PoreThresholds {
        let small: Float      // Upper bound for "small" pores
        let medium: Float     // Upper bound for "medium" pores
        let large: Float      // Upper bound for "large" pores
        // Anything above large is "veryLarge"

        /// Calculate thresholds for given texture resolution
        static func forResolution(width: Int, height: Int) -> PoreThresholds {
            // Reference: At 4096x4096, thresholds are 3, 6, 10 pixels
            let referenceSize: Float = 4096.0
            let actualSize = Float(max(width, height))
            let scale = actualSize / referenceSize

            AppLogger.metrics.debug("📐 Pore thresholds: resolution=\(width)x\(height), scale=\(String(format: "%.2f", scale))")
            AppLogger.metrics.debug("   small<\(String(format: "%.1f", 3.0 * scale))px, medium<\(String(format: "%.1f", 6.0 * scale))px, large<\(String(format: "%.1f", 10.0 * scale))px")

            return PoreThresholds(
                small: 3.0 * scale,
                medium: 6.0 * scale,
                large: 10.0 * scale
            )
        }

        /// Default thresholds (for unknown resolution or legacy paths)
        static let `default` = PoreThresholds(small: 3.0, medium: 6.0, large: 10.0)
    }

    // MARK: - GPU Acceleration

    /// Metal analyzer for GPU-accelerated analysis (if available)
    private var metalAnalyzer: MetalAnalyzerBase?

    /// Texture pool for efficient GPU memory management
    private var texturePool: TexturePool?

    /// Use GPU acceleration if available
    private let useGPU: Bool

    // MARK: - Initialization

    init() {
        // Check if GPU acceleration is available
        self.useGPU = MetalCapabilities.shared.supportsGPUAnalysis

        if useGPU {
            do {
                self.metalAnalyzer = try MetalAnalyzerBase()
                if let device = metalAnalyzer?.device {
                    self.texturePool = TexturePool(device: device, maxPoolSize: 4)
                }
                AppLogger.metrics.info("✅ PoreAnalyzer: GPU acceleration enabled")
            } catch {
                AppLogger.metrics.warning("⚠️ PoreAnalyzer: Failed to initialize Metal - falling back to CPU")
                self.metalAnalyzer = nil
                self.texturePool = nil
            }
        } else {
            AppLogger.metrics.info("ℹ️ PoreAnalyzer: Using CPU analysis (GPU not supported)")
        }
    }

    deinit {
        // Clean up GPU resources
        texturePool?.clear()
    }

    // MARK: - Performance Optimization

    private let maxAnalysisSize: Int = 1024

    private func downsample(_ image: CGImage, maxSize: Int? = nil) -> CGImage? {
        let targetSize = maxSize ?? maxAnalysisSize
        let scale = min(1.0, Double(targetSize) / Double(max(image.width, image.height)))
        if scale >= 1.0 { return image }

        let newWidth = Int(Double(image.width) * scale)
        let newHeight = Int(Double(image.height) * scale)

        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: newWidth, height: newHeight,
            bitsPerComponent: 8, bytesPerRow: newWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage()
    }

    // MARK: - Public API

    /// Analyze pore visibility from high-resolution texture
    func analyzePores(texture: UIImage) -> PoreAnalysis {
        AppLogger.metrics.info("🔬 Analyzing pore visibility...")

        guard let cgImage = texture.cgImage else {
            AppLogger.metrics.warning("⚠️ Could not extract CGImage from texture")
            let emptyDistribution = PoreSizeDistribution(smallCount: 0, mediumCount: 0, largeCount: 0, veryLargeCount: 0)
            return PoreAnalysis(visibility: 0, density: 0, averageSize: 0, sizeDistribution: emptyDistribution, regionalScores: [:], confidence: 0)
        }

        // GPU PATH: Use full resolution analysis on GPU
        if useGPU, let metalAnalyzer = metalAnalyzer {
            AppLogger.metrics.info("   🎨 Using GPU acceleration (full resolution)")
            return analyzePoresGPU(texture: texture, metalAnalyzer: metalAnalyzer)
        }

        // CPU FALLBACK: Downsample to 1024x1024 max for efficient processing
        AppLogger.metrics.info("   💻 Using CPU analysis (with downsampling)")
        let analysisImage: CGImage
        let analysisTexture: UIImage
        if let downsampled = downsample(cgImage) {
            analysisImage = downsampled
            analysisTexture = UIImage(cgImage: downsampled)
            AppLogger.metrics.info("   📐 Downsampled \(cgImage.width)x\(cgImage.height) → \(downsampled.width)x\(downsampled.height)")
        } else {
            analysisImage = cgImage
            analysisTexture = texture
        }

        // High-frequency texture energy correlates with visible pores
        let highFreqEnergy = calculateHighFrequencyEnergy(image: analysisTexture)

        // Detect individual pores using local minima in high-pass filtered image
        let poreDetectionResult = detectPores(image: analysisImage)

        // Calculate pore density (pores per cm²)
        // Assume texture covers ~10cm x 10cm of face (approximate)
        let faceAreaCm2: Float = 100.0  // Approximate face area
        let density = Float(poreDetectionResult.poreCount) / faceAreaCm2

        // Calculate average pore size
        let averageSize = poreDetectionResult.averagePoreSize

        // Classify pores by size using resolution-aware thresholds
        let cpuPoreThresholds = PoreThresholds.forResolution(width: cgImage.width, height: cgImage.height)
        var smallCount = 0
        var mediumCount = 0
        var largeCount = 0
        var veryLargeCount = 0

        for pore in poreDetectionResult.poreLocations {
            if pore.size < cpuPoreThresholds.small {
                smallCount += 1
            } else if pore.size < cpuPoreThresholds.medium {
                mediumCount += 1
            } else if pore.size < cpuPoreThresholds.large {
                largeCount += 1
            } else {
                veryLargeCount += 1
            }
        }

        let sizeDistribution = PoreSizeDistribution(
            smallCount: smallCount,
            mediumCount: mediumCount,
            largeCount: largeCount,
            veryLargeCount: veryLargeCount
        )

        // Analyze regional pore distribution
        let regionalScores = analyzeRegionalPores(
            image: cgImage,
            poreLocations: poreDetectionResult.poreLocations
        )

        // Convert to visibility score (0-100)
        // Base visibility from texture energy
        let textureVisibility = min(100, highFreqEnergy * 10)
        // FIX: Add penalty based on pore SIZE DISTRIBUTION (CPU path)
        let sizePenalty = calculateSizePenalty(sizeDistribution: sizeDistribution)
        let visibility = min(100, textureVisibility + sizePenalty)

        // Calculate confidence score
        let confidence = calculateConfidence(
            poreCount: poreDetectionResult.poreCount,
            averagePoreSize: averageSize,
            imageResolution: (width: cgImage.width, height: cgImage.height),
            skinBrightness: poreDetectionResult.skinBrightness
        )

        AppLogger.metrics.info("✅ Pore analysis complete:")
        AppLogger.metrics.info("   Visibility: \(String(format: "%.1f", visibility))/100 (Score: \(String(format: "%.1f", 100 - visibility)))")
        AppLogger.metrics.info("   Density: \(String(format: "%.1f", density)) pores/cm²")
        AppLogger.metrics.info("   Avg size: \(String(format: "%.2f", averageSize)) pixels")
        AppLogger.metrics.info("   Size distribution: Small=\(smallCount), Medium=\(mediumCount), Large=\(largeCount), VeryLarge=\(veryLargeCount)")
        AppLogger.metrics.info("   Dominant size: \(sizeDistribution.dominantSize.rawValue)")
        AppLogger.metrics.info("   Confidence: \(String(format: "%.1f", confidence))%")
        AppLogger.metrics.info("   Regional scores: \(regionalScores.count) regions")

        return PoreAnalysis(
            visibility: visibility,
            density: density,
            averageSize: averageSize,
            sizeDistribution: sizeDistribution,
            regionalScores: regionalScores,
            confidence: confidence
        )
    }

    // MARK: - GPU Acceleration Methods

    /// GPU-accelerated pore analysis (full resolution, no downsampling)
    private func analyzePoresGPU(texture: UIImage, metalAnalyzer: MetalAnalyzerBase) -> PoreAnalysis {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Convert UIImage to Metal texture
            guard let inputTexture = MetalHelpers.textureFromUIImage(texture, device: metalAnalyzer.device) else {
                AppLogger.metrics.error("❌ GPU: Failed to convert image to texture - falling back to CPU")
                return analyzePoresCPU(texture: texture)
            }

            let width = inputTexture.width
            let height = inputTexture.height
            AppLogger.metrics.info("   📏 Analyzing full resolution: \(width)x\(height)")

            // STEP 1: Calculate adaptive skin brightness threshold
            let adaptiveThreshold = try calculateSkinBrightnessGPU(
                inputTexture: inputTexture,
                metalAnalyzer: metalAnalyzer
            )
            AppLogger.metrics.debug("   🎯 Adaptive darkness threshold: \(String(format: "%.3f", adaptiveThreshold))")

            // STEP 2: Compute Laplacian map
            let laplacianTexture = try computeLaplacianGPU(
                inputTexture: inputTexture,
                metalAnalyzer: metalAnalyzer
            )

            // STEP 3: Detect pores as local maxima
            let poreDetectionResult = try detectPoresGPU(
                inputTexture: inputTexture,
                laplacianTexture: laplacianTexture,
                adaptiveThreshold: adaptiveThreshold,
                metalAnalyzer: metalAnalyzer
            )

            // STEP 4: Calculate high-frequency energy for visibility score
            let highFreqEnergy = calculateHighFreqEnergyFromLaplacian(
                laplacianTexture: laplacianTexture,
                width: width,
                height: height
            )

            // Calculate pore density (pores per cm²)
            let faceAreaCm2: Float = 100.0
            let density = Float(poreDetectionResult.poreCount) / faceAreaCm2

            // Classify pores by size using resolution-aware thresholds
            let poreThresholds = PoreThresholds.forResolution(width: width, height: height)
            let sizeDistribution = classifyPoreSizes(pores: poreDetectionResult.poreLocations, thresholds: poreThresholds)

            // Analyze regional distribution
            let regionalScores = try analyzeRegionalPoresGPU(
                inputTexture: inputTexture,
                laplacianTexture: laplacianTexture,
                adaptiveThreshold: adaptiveThreshold,
                metalAnalyzer: metalAnalyzer
            )

            // Convert to visibility score (0-100)
            // Base visibility from texture energy
            let textureVisibility = min(100, highFreqEnergy * 10)

            // FIX: Add penalty based on pore SIZE DISTRIBUTION
            // Previously, sizeDistribution was collected but NEVER used in scoring!
            // This caused 99.9% scores even with 707 VeryLarge pores detected
            let sizePenalty = calculateSizePenalty(sizeDistribution: sizeDistribution)
            let visibility = min(100, textureVisibility + sizePenalty)

            // Calculate confidence
            let confidence = calculateConfidence(
                poreCount: poreDetectionResult.poreCount,
                averagePoreSize: poreDetectionResult.averagePoreSize,
                imageResolution: (width: width, height: height),
                skinBrightness: adaptiveThreshold * 255.0
            )

            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            AppLogger.metrics.info("✅ Pore analysis complete (GPU):")
            AppLogger.metrics.info("   Visibility: \(String(format: "%.1f", visibility))/100 (Score: \(String(format: "%.1f", 100 - visibility)))")
            AppLogger.metrics.info("   Density: \(String(format: "%.1f", density)) pores/cm²")
            AppLogger.metrics.info("   Avg size: \(String(format: "%.2f", poreDetectionResult.averagePoreSize)) pixels")
            AppLogger.metrics.info("   Size distribution: Small=\(sizeDistribution.smallCount), Medium=\(sizeDistribution.mediumCount), Large=\(sizeDistribution.largeCount), VeryLarge=\(sizeDistribution.veryLargeCount)")
            AppLogger.metrics.info("   Confidence: \(String(format: "%.1f", confidence))%")
            AppLogger.metrics.info("   GPU time: \(String(format: "%.1f", elapsed))ms")

            return PoreAnalysis(
                visibility: visibility,
                density: density,
                averageSize: poreDetectionResult.averagePoreSize,
                sizeDistribution: sizeDistribution,
                regionalScores: regionalScores,
                confidence: confidence
            )

        } catch {
            AppLogger.metrics.error("❌ GPU analysis failed: \(error.localizedDescription) - falling back to CPU")
            return analyzePoresCPU(texture: texture)
        }
    }

    /// Helper to run CPU analysis (extracted from main method)
    private func analyzePoresCPU(texture: UIImage) -> PoreAnalysis {
        guard let cgImage = texture.cgImage else {
            let emptyDistribution = PoreSizeDistribution(smallCount: 0, mediumCount: 0, largeCount: 0, veryLargeCount: 0)
            return PoreAnalysis(visibility: 0, density: 0, averageSize: 0, sizeDistribution: emptyDistribution, regionalScores: [:], confidence: 0)
        }

        // Downsample for CPU
        let analysisImage: CGImage
        let analysisTexture: UIImage
        if let downsampled = downsample(cgImage) {
            analysisImage = downsampled
            analysisTexture = UIImage(cgImage: downsampled)
            AppLogger.metrics.info("   📐 CPU: Downsampled \(cgImage.width)x\(cgImage.height) → \(downsampled.width)x\(downsampled.height)")
        } else {
            analysisImage = cgImage
            analysisTexture = texture
        }

        let highFreqEnergy = calculateHighFrequencyEnergy(image: analysisTexture)
        let poreDetectionResult = detectPores(image: analysisImage)
        let faceAreaCm2: Float = 100.0
        let density = Float(poreDetectionResult.poreCount) / faceAreaCm2

        // Use resolution-aware thresholds for CPU fallback path
        let fallbackThresholds = PoreThresholds.forResolution(width: cgImage.width, height: cgImage.height)
        var smallCount = 0, mediumCount = 0, largeCount = 0, veryLargeCount = 0
        for pore in poreDetectionResult.poreLocations {
            if pore.size < fallbackThresholds.small { smallCount += 1 }
            else if pore.size < fallbackThresholds.medium { mediumCount += 1 }
            else if pore.size < fallbackThresholds.large { largeCount += 1 }
            else { veryLargeCount += 1 }
        }

        let sizeDistribution = PoreSizeDistribution(
            smallCount: smallCount,
            mediumCount: mediumCount,
            largeCount: largeCount,
            veryLargeCount: veryLargeCount
        )

        let regionalScores = analyzeRegionalPores(image: cgImage, poreLocations: poreDetectionResult.poreLocations)
        // FIX: Add size distribution penalty (CPU fallback path)
        let textureVisibility = min(100, highFreqEnergy * 10)
        let sizePenalty = calculateSizePenalty(sizeDistribution: sizeDistribution)
        let visibility = min(100, textureVisibility + sizePenalty)
        let confidence = calculateConfidence(
            poreCount: poreDetectionResult.poreCount,
            averagePoreSize: poreDetectionResult.averagePoreSize,
            imageResolution: (width: cgImage.width, height: cgImage.height),
            skinBrightness: poreDetectionResult.skinBrightness
        )

        return PoreAnalysis(
            visibility: visibility,
            density: density,
            averageSize: poreDetectionResult.averagePoreSize,
            sizeDistribution: sizeDistribution,
            regionalScores: regionalScores,
            confidence: confidence
        )
    }

    /// Calculate average skin brightness using GPU
    private func calculateSkinBrightnessGPU(
        inputTexture: MTLTexture,
        metalAnalyzer: MetalAnalyzerBase
    ) throws -> Float {
        let pipeline = try metalAnalyzer.loadPipeline(named: "calculateSkinBrightness")

        // Create output buffer
        let resultBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<Float>.size)

        // Execute with cancellation support
        try metalAnalyzer.executeCancellableSync(operation: "calculateSkinBrightness") { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw GPUAnalysisError.commandBufferFailed("Failed to create compute encoder")
            }

            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(inputTexture, index: 0)
            encoder.setBuffer(resultBuffer, offset: 0, index: 0)

            let (threadgroups, threadsPerGroup) = metalAnalyzer.calculateThreadgroups(
                pipeline: pipeline,
                width: inputTexture.width,
                height: inputTexture.height
            )

            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
        }

        // Read result and convert to adaptive threshold
        let brightnessPtr = resultBuffer.contents().assumingMemoryBound(to: Float.self)
        let avgBrightness = brightnessPtr.pointee

        // Calculate adaptive threshold (matches CPU logic)
        let adaptiveMultiplier = calculateAdaptiveMultiplier(brightness: avgBrightness * 255.0)
        // FIXED: Lowered min from 50 to 30 to support very dark skin (Fitzpatrick V-VI)
        let threshold = max(30.0, min(180.0, avgBrightness * 255.0 * adaptiveMultiplier)) / 255.0

        return threshold
    }

    /// Compute Laplacian map on GPU
    private func computeLaplacianGPU(
        inputTexture: MTLTexture,
        metalAnalyzer: MetalAnalyzerBase
    ) throws -> MTLTexture {
        let pipeline = try metalAnalyzer.loadPipeline(named: "computePoreLaplacian")

        // Create output texture
        let laplacianTexture = try metalAnalyzer.createTexture(
            width: inputTexture.width,
            height: inputTexture.height,
            format: .rgba8Unorm
        )

        // Execute with cancellation support
        try metalAnalyzer.executeCancellableSync(operation: "computePoreLaplacian") { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw GPUAnalysisError.commandBufferFailed("Failed to create compute encoder")
            }

            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(inputTexture, index: 0)
            encoder.setTexture(laplacianTexture, index: 1)

            let (threadgroups, threadsPerGroup) = metalAnalyzer.calculateThreadgroups(
                pipeline: pipeline,
                width: inputTexture.width,
                height: inputTexture.height
            )

            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
        }

        return laplacianTexture
    }

    /// Pore detection result structure
    private struct GPUPoreDetectionResult {
        let poreCount: Int
        let averagePoreSize: Float
        let poreLocations: [(x: Int, y: Int, size: Float)]
    }

    /// Detect pores using GPU
    private func detectPoresGPU(
        inputTexture: MTLTexture,
        laplacianTexture: MTLTexture,
        adaptiveThreshold: Float,
        metalAnalyzer: MetalAnalyzerBase
    ) throws -> GPUPoreDetectionResult {
        let pipeline = try metalAnalyzer.loadPipeline(named: "detectPoreMaxima")

        // Maximum pores we can store (buffer size limit)
        let maxPores: UInt32 = 10000

        // Create buffers
        let poreCountBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<UInt32>.size)
        let poreLocationsBuffer = try metalAnalyzer.createBuffer(
            length: MemoryLayout<SIMD4<Float>>.stride * Int(maxPores)  // (x, y, intensity, size)
        )
        var maxPoresVar = maxPores
        let maxPoresBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<UInt32>.size)
        memcpy(maxPoresBuffer.contents(), &maxPoresVar, MemoryLayout<UInt32>.size)

        var threshold = adaptiveThreshold
        let thresholdBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<Float>.size)
        memcpy(thresholdBuffer.contents(), &threshold, MemoryLayout<Float>.size)

        // Initialize pore count to 0
        memset(poreCountBuffer.contents(), 0, MemoryLayout<UInt32>.size)

        // Execute with cancellation support
        try metalAnalyzer.executeCancellableSync(operation: "detectPoreMaxima") { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw GPUAnalysisError.commandBufferFailed("Failed to create compute encoder")
            }

            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(inputTexture, index: 0)
            encoder.setTexture(laplacianTexture, index: 1)
            encoder.setBuffer(poreCountBuffer, offset: 0, index: 0)
            encoder.setBuffer(poreLocationsBuffer, offset: 0, index: 1)
            encoder.setBuffer(maxPoresBuffer, offset: 0, index: 2)
            encoder.setBuffer(thresholdBuffer, offset: 0, index: 3)

            let (threadgroups, threadsPerGroup) = metalAnalyzer.calculateThreadgroups(
                pipeline: pipeline,
                width: inputTexture.width,
                height: inputTexture.height
            )

            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
        }

        // Read results
        let poreCountPtr = poreCountBuffer.contents().assumingMemoryBound(to: UInt32.self)
        let detectedPoreCount = min(Int(poreCountPtr.pointee), Int(maxPores))

        let poreLocationsPtr = poreLocationsBuffer.contents().assumingMemoryBound(to: SIMD4<Float>.self)

        var poreLocations: [(x: Int, y: Int, size: Float)] = []
        var totalSize: Float = 0

        for i in 0..<detectedPoreCount {
            let pore = poreLocationsPtr[i]
            let x = Int(pore.x)
            let y = Int(pore.y)
            let size = pore.w  // w component contains size
            poreLocations.append((x, y, size))
            totalSize += size
        }

        let avgSize = detectedPoreCount > 0 ? totalSize / Float(detectedPoreCount) : 0

        return GPUPoreDetectionResult(
            poreCount: detectedPoreCount,
            averagePoreSize: avgSize,
            poreLocations: poreLocations
        )
    }

    /// Calculate high-frequency energy from Laplacian texture
    private func calculateHighFreqEnergyFromLaplacian(
        laplacianTexture: MTLTexture,
        width: Int,
        height: Int
    ) -> Float {
        // Read back Laplacian data
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: width, height: height, depth: 1)
        )

        laplacianTexture.getBytes(
            &pixelData,
            bytesPerRow: bytesPerRow,
            from: region,
            mipmapLevel: 0
        )

        // Calculate average energy
        var totalEnergy: Float = 0
        var count = 0

        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let energy = Float(pixelData[i]) / 255.0
            totalEnergy += energy
            count += 1
        }

        return count > 0 ? totalEnergy / Float(count) : 0
    }

    /// Classify pores by size using resolution-aware thresholds
    private func classifyPoreSizes(pores: [(x: Int, y: Int, size: Float)], thresholds: PoreThresholds) -> PoreSizeDistribution {
        var smallCount = 0
        var mediumCount = 0
        var largeCount = 0
        var veryLargeCount = 0

        for pore in pores {
            if pore.size < thresholds.small {
                smallCount += 1
            } else if pore.size < thresholds.medium {
                mediumCount += 1
            } else if pore.size < thresholds.large {
                largeCount += 1
            } else {
                veryLargeCount += 1
            }
        }

        return PoreSizeDistribution(
            smallCount: smallCount,
            mediumCount: mediumCount,
            largeCount: largeCount,
            veryLargeCount: veryLargeCount
        )
    }

    /// Calculate visibility penalty based on pore size distribution
    /// Larger pores increase visibility (higher penalty = more visible = worse score)
    private func calculateSizePenalty(sizeDistribution: PoreSizeDistribution) -> Float {
        let total = Float(sizeDistribution.smallCount + sizeDistribution.mediumCount +
                          sizeDistribution.largeCount + sizeDistribution.veryLargeCount)
        guard total > 0 else { return 0 }

        // Weight larger pores more heavily for visibility penalty
        // Small pores: no penalty (normal, healthy)
        // Medium pores: slight penalty
        // Large pores: moderate penalty
        // VeryLarge pores: significant penalty
        let weightedScore = (
            Float(sizeDistribution.smallCount) * 0.0 +
            Float(sizeDistribution.mediumCount) * 0.5 +
            Float(sizeDistribution.largeCount) * 2.0 +
            Float(sizeDistribution.veryLargeCount) * 5.0
        )

        // Normalize by total pores and scale to max 50 points of penalty
        // This ensures size distribution can add up to 50 visibility points
        return min(50, weightedScore / max(1, total) * 10)
    }

    /// Analyze regional pores using GPU
    private func analyzeRegionalPoresGPU(
        inputTexture: MTLTexture,
        laplacianTexture: MTLTexture,
        adaptiveThreshold: Float,
        metalAnalyzer: MetalAnalyzerBase
    ) throws -> [String: Float] {
        let pipeline = try metalAnalyzer.loadPipeline(named: "analyzeRegionalPores")

        // Define face regions
        let regions: [String: (minX: Float, maxX: Float, minY: Float, maxY: Float)] = [
            "forehead": (0.3, 0.7, 0.1, 0.3),
            "leftCheek": (0.1, 0.4, 0.4, 0.7),
            "rightCheek": (0.6, 0.9, 0.4, 0.7),
            "nose": (0.4, 0.6, 0.3, 0.6),
            "chin": (0.35, 0.65, 0.7, 0.9)
        ]

        var regionalScores: [String: Float] = [:]

        for (regionName, bounds) in regions {
            let (threadgroups, threadsPerGroup) = metalAnalyzer.calculateThreadgroups(
                pipeline: pipeline,
                width: inputTexture.width,
                height: inputTexture.height
            )
            let numThreadgroups = threadgroups.width * threadgroups.height

            // Create buffers
            struct PartialResults {
                var totalPoreCount: Float
                var totalPoreSize: Float
                var skinBrightnessSum: Float
                var validPixelCount: Float
            }

            let resultsBuffer = try metalAnalyzer.createBuffer(
                length: MemoryLayout<PartialResults>.stride * numThreadgroups
            )

            var boundsVec = SIMD4<Float>(bounds.minX, bounds.maxX, bounds.minY, bounds.maxY)
            let boundsBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<SIMD4<Float>>.size)
            memcpy(boundsBuffer.contents(), &boundsVec, MemoryLayout<SIMD4<Float>>.size)

            var threshold = adaptiveThreshold
            let thresholdBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<Float>.size)
            memcpy(thresholdBuffer.contents(), &threshold, MemoryLayout<Float>.size)

            var threadgroupsPerRow = UInt32(threadgroups.width)
            let threadgroupsPerRowBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<UInt32>.size)
            memcpy(threadgroupsPerRowBuffer.contents(), &threadgroupsPerRow, MemoryLayout<UInt32>.size)

            // Execute
            try metalAnalyzer.executeCancellableSync(operation: "analyzeRegionalPores") { commandBuffer in
                guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                    throw GPUAnalysisError.commandBufferFailed("Failed to create encoder")
                }

                encoder.setComputePipelineState(pipeline)
                encoder.setTexture(inputTexture, index: 0)
                encoder.setTexture(laplacianTexture, index: 1)
                encoder.setBuffer(resultsBuffer, offset: 0, index: 0)
                encoder.setBuffer(boundsBuffer, offset: 0, index: 1)
                encoder.setBuffer(thresholdBuffer, offset: 0, index: 2)
                encoder.setBuffer(threadgroupsPerRowBuffer, offset: 0, index: 3)

                encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
                encoder.endEncoding()
            }

            // Reduce results
            let resultsPtr = resultsBuffer.contents().assumingMemoryBound(to: PartialResults.self)
            var totalPoreCount: Float = 0
            var totalPoreSize: Float = 0
            var totalValidPixels: Float = 0

            for i in 0..<numThreadgroups {
                let result = resultsPtr[i]
                totalPoreCount += result.totalPoreCount
                totalPoreSize += result.totalPoreSize
                totalValidPixels += result.validPixelCount
            }

            // Calculate regional score
            if totalValidPixels > 0 {
                let regionArea = (bounds.maxX - bounds.minX) * (bounds.maxY - bounds.minY)
                let density = totalPoreCount / (regionArea * 100.0)
                let avgSize = totalPoreCount > 0 ? totalPoreSize / totalPoreCount : 0

                // Score: 100 = no pores, 0 = many large pores
                let score = max(0, 100 - (density * 50 + avgSize * 2))
                regionalScores[regionName] = score
            } else {
                regionalScores[regionName] = 50.0
            }
        }

        return regionalScores
    }

    // MARK: - CPU Methods (Private)

    /// Calculate high-frequency energy (indicates pores)
    private func calculateHighFrequencyEnergy(image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 5 }

        // Convert to grayscale
        let width = cgImage.width
        let height = cgImage.height

        var grayData = [UInt8](repeating: 0, count: width * height)

        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: &grayData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: 0
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Apply high-pass filter to detect high-frequency components
        let floatData = grayData.map { Float($0) / 255.0 }

        // Simple Laplacian operator (high-pass filter)
        var filteredData = [Float](repeating: 0, count: width * height)

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = floatData[y * width + x]
                let top = floatData[(y - 1) * width + x]
                let bottom = floatData[(y + 1) * width + x]
                let left = floatData[y * width + (x - 1)]
                let right = floatData[y * width + (x + 1)]

                // Laplacian: 4*center - (top + bottom + left + right)
                let laplacian = 4 * center - (top + bottom + left + right)
                filteredData[y * width + x] = abs(laplacian)
            }
        }

        // Calculate average energy
        let energy = filteredData.reduce(0, +) / Float(filteredData.count)

        return energy
    }

    // MARK: - Pore Detection

    /// Result of pore detection
    private struct PoreDetectionResult {
        let poreCount: Int
        let averagePoreSize: Float
        let poreLocations: [(x: Int, y: Int, size: Float)]
        let skinBrightness: Float  // For confidence calculation
    }

    /// Detect individual pores using local minima detection
    private func detectPores(image: CGImage) -> PoreDetectionResult {
        let width = image.width
        let height = image.height

        // Convert to grayscale
        var grayData = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &grayData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: 0
        ) else {
            return PoreDetectionResult(poreCount: 0, averagePoreSize: 0, poreLocations: [], skinBrightness: 128.0)
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Apply Gaussian blur to reduce noise
        let blurred = applyGaussianBlur(data: grayData, width: width, height: height)

        // Calculate adaptive darkness threshold based on skin tone
        // This makes pore detection fair across all skin tones (light to dark)
        let avgSkinBrightness = calculateAverageSkinBrightness(data: blurred, width: width, height: height)

        // Pores are typically 20-30% darker than surrounding skin
        // Use LIGHTING-AWARE adaptive multiplier for better accuracy across lighting conditions
        let adaptiveMultiplier = calculateAdaptiveMultiplier(brightness: avgSkinBrightness)
        // FIXED: Lowered min from 50 to 30 to support very dark skin (Fitzpatrick V-VI)
        let minDarkness = UInt8(max(30, min(180, Int(avgSkinBrightness * adaptiveMultiplier))))

        AppLogger.metrics.debug("Adaptive pore threshold: \(minDarkness) (skin brightness: \(avgSkinBrightness))")

        // Detect local minima (dark spots = pores)
        var poreLocations: [(x: Int, y: Int, size: Float)] = []
        let searchRadius = 2  // Search within 2-pixel radius

        for y in stride(from: searchRadius, to: height - searchRadius, by: 3) {
            for x in stride(from: searchRadius, to: width - searchRadius, by: 3) {
                let centerValue = blurred[y * width + x]

                // Check if this is a local minimum (darker than neighbors)
                if centerValue < minDarkness && isLocalMinimum(data: blurred, x: x, y: y, width: width, height: height, radius: searchRadius) {
                    // Estimate pore size by measuring dark region extent
                    let poreSize = measurePoreSize(data: blurred, centerX: x, centerY: y, width: width, height: height)
                    poreLocations.append((x, y, poreSize))
                }
            }
        }

        // Calculate average pore size
        let averageSize: Float = poreLocations.isEmpty ? 0 : poreLocations.map { $0.size }.reduce(0, +) / Float(poreLocations.count)

        return PoreDetectionResult(
            poreCount: poreLocations.count,
            averagePoreSize: averageSize,
            poreLocations: poreLocations,
            skinBrightness: avgSkinBrightness
        )
    }

    /// Calculate average skin brightness for adaptive thresholding
    /// This enables fair pore detection across all skin tones (light to dark)
    private func calculateAverageSkinBrightness(data: [UInt8], width: Int, height: Int) -> Float {
        // Sample center region of face (avoid edges and hair)
        let sampleMinX = width / 3
        let sampleMaxX = width * 2 / 3
        let sampleMinY = height / 3
        let sampleMaxY = height * 2 / 3

        var sum: Float = 0
        var count: Int = 0

        for y in stride(from: sampleMinY, to: sampleMaxY, by: 5) {
            for x in stride(from: sampleMinX, to: sampleMaxX, by: 5) {
                sum += Float(data[y * width + x])
                count += 1
            }
        }

        return count > 0 ? sum / Float(count) : 128.0  // Default to mid-gray if sampling fails
    }

    /// Calculate adaptive multiplier based on lighting conditions
    /// Adjusts pore detection threshold for different lighting scenarios
    /// FIXED: Uses linear interpolation to avoid discontinuous 17% jumps at boundaries
    private func calculateAdaptiveMultiplier(brightness: Float) -> Float {
        // Zones:
        // Very dark (<60): 0.6 (most sensitive)
        // Dark transition (60-100): linear 0.6 → 0.7
        // Optimal (100-200): 0.7 (standard)
        // Bright transition (200-240): linear 0.7 → 0.75
        // Very bright (>240): 0.75 (least sensitive)

        if brightness < 60 {
            return 0.6  // Very dark - most sensitive
        } else if brightness < 100 {
            // Linear interpolation from 0.6 to 0.7 over brightness 60-100
            let t = (brightness - 60) / 40.0  // 0 to 1
            return 0.6 + t * 0.1
        } else if brightness <= 200 {
            return 0.7  // Optimal lighting range
        } else if brightness < 240 {
            // Linear interpolation from 0.7 to 0.75 over brightness 200-240
            let t = (brightness - 200) / 40.0  // 0 to 1
            return 0.7 + t * 0.05
        } else {
            return 0.75  // Very bright - least sensitive
        }
    }

    /// Apply Gaussian blur to reduce noise
    private func applyGaussianBlur(data: [UInt8], width: Int, height: Int) -> [UInt8] {
        var blurred = [UInt8](repeating: 0, count: width * height)

        // Simple 3x3 Gaussian kernel
        let kernel: [[Float]] = [
            [1, 2, 1],
            [2, 4, 2],
            [1, 2, 1]
        ]
        let kernelSum: Float = 16.0

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var sum: Float = 0

                for ky in -1...1 {
                    for kx in -1...1 {
                        let pixelValue = Float(data[(y + ky) * width + (x + kx)])
                        sum += pixelValue * kernel[ky + 1][kx + 1]
                    }
                }

                blurred[y * width + x] = UInt8(sum / kernelSum)
            }
        }

        return blurred
    }

    /// Check if pixel is a local minimum
    private func isLocalMinimum(data: [UInt8], x: Int, y: Int, width: Int, height: Int, radius: Int) -> Bool {
        let centerValue = data[y * width + x]

        for dy in -radius...radius {
            for dx in -radius...radius {
                if dx == 0 && dy == 0 { continue }

                let nx = x + dx
                let ny = y + dy

                if nx >= 0 && nx < width && ny >= 0 && ny < height {
                    if data[ny * width + nx] <= centerValue {
                        return false  // Not a minimum
                    }
                }
            }
        }

        return true
    }

    /// Measure pore size by flood-fill like expansion
    private func measurePoreSize(data: [UInt8], centerX: Int, centerY: Int, width: Int, height: Int) -> Float {
        let centerValue = data[centerY * width + centerX]
        // FIXED: Use percentage (15% brighter) instead of fixed +30 offset
        // This ensures consistent pore boundary detection across all skin tones
        // Indian skin center ~120 → threshold ~138 (was 150 with +30)
        let threshold = UInt8(min(255, Int(Float(centerValue) * 1.15)))

        var size: Float = 1.0
        var visited = Set<Int>()
        var queue = [(centerX, centerY)]
        visited.insert(centerY * width + centerX)

        // FIXED: Scale max pore size based on resolution (was fixed 100 pixels)
        // Reference: 100 pixels at 1024px resolution = ~1cm diameter pore
        // 4096px → 400 pixels, 512px → 50 pixels
        let referenceSize = 1024
        let resolutionScale = Float(max(width, height)) / Float(referenceSize)
        let maxPoreSize = Float(100) * resolutionScale

        while !queue.isEmpty && size < maxPoreSize {
            let (x, y) = queue.removeFirst()

            for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                let nx = x + dx
                let ny = y + dy

                if nx >= 0 && nx < width && ny >= 0 && ny < height {
                    let index = ny * width + nx
                    if !visited.contains(index) && data[index] < threshold {
                        visited.insert(index)
                        queue.append((nx, ny))
                        size += 1
                    }
                }
            }
        }

        return size
    }

    // MARK: - Regional Analysis

    /// Analyze pore distribution across face regions
    private func analyzeRegionalPores(
        image: CGImage,
        poreLocations: [(x: Int, y: Int, size: Float)]
    ) -> [String: Float] {
        let width = image.width
        let height = image.height

        // Define face regions (normalized coordinates)
        let regions: [String: (minX: Float, maxX: Float, minY: Float, maxY: Float)] = [
            "forehead": (0.3, 0.7, 0.1, 0.3),
            "leftCheek": (0.1, 0.4, 0.4, 0.7),
            "rightCheek": (0.6, 0.9, 0.4, 0.7),
            "nose": (0.4, 0.6, 0.3, 0.6),
            "chin": (0.35, 0.65, 0.7, 0.9)
        ]

        var regionalScores: [String: Float] = [:]

        for (regionName, bounds) in regions {
            // Count pores in this region
            var poreCount = 0
            var totalPoreSize: Float = 0

            for pore in poreLocations {
                let normalizedX = Float(pore.x) / Float(width)
                let normalizedY = Float(pore.y) / Float(height)

                if normalizedX >= bounds.minX && normalizedX <= bounds.maxX &&
                   normalizedY >= bounds.minY && normalizedY <= bounds.maxY {
                    poreCount += 1
                    totalPoreSize += pore.size
                }
            }

            // Calculate region score (lower is better)
            let regionArea = (bounds.maxX - bounds.minX) * (bounds.maxY - bounds.minY)
            let density = Float(poreCount) / (regionArea * 100.0)  // Pores per normalized area
            let avgSize = poreCount > 0 ? totalPoreSize / Float(poreCount) : 0

            // Score: 100 = no pores, 0 = many large pores
            let score = max(0, 100 - (density * 50 + avgSize * 2))
            regionalScores[regionName] = score
        }

        return regionalScores
    }

    // MARK: - Confidence Calculation

    /// Calculate confidence score for pore detection
    /// Factors: image quality, lighting, detection consistency
    private func calculateConfidence(
        poreCount: Int,
        averagePoreSize: Float,
        imageResolution: (width: Int, height: Int),
        skinBrightness: Float
    ) -> Float {
        // STANDARDIZED: Direct texture measurement (pore detection)
        // Base: 75 (direct texture measurement)
        // Range: 45-95 (never 100% due to inherent limitations)
        var confidence: Float = 75.0  // Base confidence for direct texture measurement

        // Factor 1: Image resolution
        let totalPixels = imageResolution.width * imageResolution.height
        if totalPixels >= 1_000_000 {  // 1MP+
            confidence += 10
        } else if totalPixels >= 500_000 {  // 0.5MP+
            confidence += 5
        } else {  // Low resolution
            confidence -= 10
        }

        // Factor 2: Lighting conditions - STANDARDIZED across all analyzers
        // Excellent: +10, Good: +5, Suboptimal: -5, Poor: -15
        if skinBrightness >= 100 && skinBrightness <= 200 {
            confidence += 10  // Optimal lighting range
        } else if skinBrightness >= 80 && skinBrightness <= 220 {
            confidence += 5   // Good lighting
        } else if skinBrightness < 60 || skinBrightness > 240 {
            confidence -= 15  // Poor lighting
        } else {
            confidence -= 5   // Suboptimal
        }

        // Factor 3: Detection count (more pores = more reliable statistics)
        if poreCount >= 50 {
            confidence += 10  // Good sample size
        } else if poreCount >= 20 {
            confidence += 5   // Adequate sample
        } else if poreCount < 10 {
            confidence -= 15  // Too few pores detected
        }

        // Factor 4: Pore size consistency (should be 2-20 pixels typically)
        if averagePoreSize >= 2 && averagePoreSize <= 20 {
            confidence += 5   // Reasonable pore sizes
        } else if averagePoreSize > 30 {
            confidence -= 10  // Suspiciously large (likely false positives)
        }

        // Clamp to 45-95 range (standardized for direct texture analysis)
        return max(45, min(95, confidence))
    }
}
