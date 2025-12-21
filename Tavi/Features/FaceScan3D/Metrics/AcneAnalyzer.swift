//
//  AcneAnalyzer.swift
//  Tavi
//
//  UNIFIED ACNE DETECTION - Fair across all skin tones
//
//  Method: Darkness variations + 3D mesh elevation
//  Works for all Fitzpatrick types (I-VI) including Indian/dark skin
//
//  Rationale:
//  - Light skin: Inflamed acne appears RED
//  - Dark skin: Inflamed acne appears DARKER BROWN (not red)
//  - Solution: Don't rely on color - use darkness + physical elevation
//
//  GPU/CPU Hybrid Approach:
//  - GPU: Parallel darkness map generation (embarrassingly parallel)
//  - CPU: Connected component analysis via flood-fill (graph traversal)
//  - CPU: Blemish classification and scoring (sequential logic)
//

import UIKit
import simd
import Metal

/// Acne analysis result
public struct AcneAnalysis: Codable, Sendable {
    let overallScore: Float  // 0-100, higher is better (less acne)
    let blemishCount: Int
    let severity: AcneSeverity
    let blemishes: [Blemish]
    let regionalScores: [String: Float]
    let confidence: Float  // 0-100, based on lighting and mesh quality
}

/// Individual blemish detection
public struct Blemish: Codable, Sendable {
    let location: String  // "forehead", "cheeks", "chin", etc.
    let type: BlemishType
    let severity: Float  // 0-1
    let size: Float      // in pixels
    let elevation: Float // 3D height in mm (0 for flat spots)
    let normalizedX: Float  // 0-1 position in image
    let normalizedY: Float
}

public enum BlemishType: String, Codable, Sendable {
    case blackhead       // Flat dark spot, no elevation
    case postInflammatory // Flat dark spot (PIH - post-inflammatory hyperpigmentation)
    case papule          // Small bump (< 1mm elevation)
    case pustule         // Medium bump (1-2mm elevation)
    case cyst            // Large bump (> 2mm elevation)
}

public enum AcneSeverity: String, Codable, Sendable {
    case clear           // 0-5 blemishes
    case mild            // 6-20 blemishes
    case moderate        // 21-50 blemishes
    case severe          // 50+ blemishes

    var score: Float {
        switch self {
        case .clear: return 95
        case .mild: return 75
        case .moderate: return 50
        case .severe: return 25
        }
    }
}

/// Unified acne analyzer - skin-tone-fair approach
public class AcneAnalyzer {

    // MARK: - GPU Configuration

    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let darknessDetectionPipeline: MTLComputePipelineState?
    private let textureCache: CVMetalTextureCache?

    // MARK: - Performance Optimization

    private let maxAnalysisSize: Int = 1024
    /// Maximum GPU texture size - prevents memory exhaustion on older devices
    /// 6144x6144 rgba32Float = 576MB which hangs older iPhones
    /// 2048x2048 r32Float = 16MB which is safe for all devices
    private let maxGPUTextureSize: Int = 2048
    private let useGPU: Bool

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

    // MARK: - Configuration

    // ADJUSTED: Increased minBlemishSize from 2.0 to 4.0 to reduce false positives
    // At 2048px downsampled resolution, 2px catches texture noise/pores
    private let minBlemishSize: Float = 4.0      // pixels (was 2.0)
    private let maxBlemishSize: Float = 50.0     // pixels
    private let skinToneNormalizer = SkinToneNormalizer()

    // MARK: - Initialization

    public init() {
        // Initialize Metal GPU resources
        if let device = MTLCreateSystemDefaultDevice() {
            self.device = device
            self.commandQueue = device.makeCommandQueue()

            // Create texture cache for efficient texture transfer
            var cache: CVMetalTextureCache?
            CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
            self.textureCache = cache

            // Load Metal library and create compute pipeline
            if let library = device.makeDefaultLibrary(),
               let function = library.makeFunction(name: "detectDarknessVariations") {
                self.darknessDetectionPipeline = try? device.makeComputePipelineState(function: function)
                self.useGPU = true
                AppLogger.metrics.info("✅ AcneAnalyzer: GPU acceleration enabled")
            } else {
                self.darknessDetectionPipeline = nil
                self.useGPU = false
                AppLogger.metrics.warning("⚠️ AcneAnalyzer: GPU pipeline creation failed, using CPU fallback")
            }
        } else {
            self.device = nil
            self.commandQueue = nil
            self.textureCache = nil
            self.darknessDetectionPipeline = nil
            self.useGPU = false
            AppLogger.metrics.warning("⚠️ AcneAnalyzer: Metal not available, using CPU fallback")
        }
    }

    // MARK: - Public API

    /// Analyze acne using unified approach (darkness + 3D elevation)
    /// Works fairly across all skin tones (Fitzpatrick I-VI)
    /// IMPROVED: Refined thresholds for very dark skin to avoid false positives
    public func analyzeAcne(texture: UIImage, geometry: FaceMeshGeometry? = nil) -> AcneAnalysis {
        AppLogger.metrics.info("🔬 Analyzing acne (unified method - skin-tone-fair)...")

        guard let cgImage = texture.cgImage else {
            return AcneAnalysis(
                overallScore: 50,
                blemishCount: 0,
                severity: .clear,
                blemishes: [],
                regionalScores: [:],
                confidence: 0
            )
        }

        // GPU PATH: Downsample to maxGPUTextureSize to prevent memory exhaustion
        // CPU FALLBACK: Downsample to maxAnalysisSize for performance
        let analysisImage: CGImage
        let analysisTexture: UIImage
        let width: Int
        let height: Int

        if useGPU {
            // GPU path: downsample to safe GPU size to prevent memory exhaustion
            // 6144x6144 rgba32Float = 576MB which hangs older iPhones
            if let downsampled = downsample(cgImage, maxSize: maxGPUTextureSize) {
                analysisImage = downsampled
                analysisTexture = UIImage(cgImage: downsampled)
                width = downsampled.width
                height = downsampled.height
                AppLogger.metrics.info("   🎨 Using GPU acceleration (downsampled: \(cgImage.width)x\(cgImage.height) → \(width)x\(height))")
            } else {
                analysisImage = cgImage
                analysisTexture = texture
                width = cgImage.width
                height = cgImage.height
                AppLogger.metrics.info("   🎨 Using GPU acceleration (full resolution: \(width)x\(height))")
            }
        } else {
            // CPU fallback: downsample for performance
            if let downsampled = downsample(cgImage) {
                analysisImage = downsampled
                analysisTexture = UIImage(cgImage: downsampled)
                width = downsampled.width
                height = downsampled.height
                AppLogger.metrics.info("   💻 Using CPU analysis (downsampled: \(cgImage.width)x\(cgImage.height) → \(width)x\(height))")
            } else {
                analysisImage = cgImage
                analysisTexture = texture
                width = cgImage.width
                height = cgImage.height
            }
        }

        // Detect skin tone for adaptive thresholds
        let skinTone = skinToneNormalizer.detectSkinTone(texture: analysisTexture)

        // Step 1: Detect darkness variations (GPU-accelerated or CPU fallback)
        let darknessSpots: [(x: Int, y: Int, darkness: Float, size: Float)]
        if useGPU {
            darknessSpots = detectDarknessVariationsGPU(image: analysisImage, skinTone: skinTone)
        } else {
            darknessSpots = detectDarknessVariationsCPU(image: analysisImage, skinTone: skinTone)
        }
        AppLogger.metrics.info("   Found \(darknessSpots.count) darkness variations")

        // Step 2: Detect 3D elevations (if geometry available)
        var elevationMap: [SIMD2<Int>: Float] = [:]
        if let geometry = geometry {
            elevationMap = detect3DElevations(geometry: geometry, imageSize: CGSize(width: width, height: height))
            AppLogger.metrics.info("   Found \(elevationMap.count) elevated regions")
        }

        // Step 3: Correlate darkness + elevation to identify acne
        let blemishes = correlateDarknessAndElevation(
            darknessSpots: darknessSpots,
            elevationMap: elevationMap,
            imageSize: CGSize(width: width, height: height)
        )

        AppLogger.metrics.info("   Detected \(blemishes.count) blemishes")

        // Step 4: Classify severity
        let severity = classifySeverity(blemishCount: blemishes.count)

        // Step 5: Calculate regional scores
        let regionalScores = calculateRegionalScores(blemishes: blemishes)

        // Step 6: Calculate overall score
        let overallScore = calculateOverallScore(blemishes: blemishes, severity: severity)

        // Step 7: Calculate confidence
        let confidence = calculateConfidence(
            darknessSpotCount: darknessSpots.count,
            hasGeometry: geometry != nil,
            imageSize: CGSize(width: width, height: height)
        )

        AppLogger.metrics.info("✅ Acne analysis complete:")
        AppLogger.metrics.info("   Blemishes: \(blemishes.count) (\(severity.rawValue))")
        AppLogger.metrics.info("   Score: \(String(format: "%.1f", overallScore))/100")
        AppLogger.metrics.info("   Confidence: \(String(format: "%.0f", confidence))%")

        return AcneAnalysis(
            overallScore: overallScore,
            blemishCount: blemishes.count,
            severity: severity,
            blemishes: blemishes,
            regionalScores: regionalScores,
            confidence: confidence
        )
    }

    // MARK: - Step 1: GPU-Accelerated Darkness Detection

    /// GPU-accelerated darkness detection
    /// Generates full-resolution darkness map, then performs CPU-based connected component analysis
    private func detectDarknessVariationsGPU(image: CGImage, skinTone: SkinToneCategory) -> [(x: Int, y: Int, darkness: Float, size: Float)] {
        guard let device = device,
              let commandQueue = commandQueue,
              let pipeline = darknessDetectionPipeline else {
            AppLogger.metrics.warning("⚠️ GPU resources unavailable, falling back to CPU")
            return detectDarknessVariationsCPU(image: image, skinTone: skinTone)
        }

        let width = image.width
        let height = image.height
        AppLogger.metrics.debug("   🔧 GPU darkness detection: \(width)x\(height)")

        // Create Metal textures from CGImage
        AppLogger.metrics.debug("   📤 Creating input texture...")
        guard let inputTexture = createMetalTexture(from: image, device: device) else {
            AppLogger.metrics.warning("⚠️ Input texture creation failed, falling back to CPU")
            return detectDarknessVariationsCPU(image: image, skinTone: skinTone)
        }
        AppLogger.metrics.debug("   ✅ Input texture created")

        AppLogger.metrics.debug("   📦 Creating output texture...")
        guard let darknessTexture = createEmptyTexture(width: width, height: height, device: device) else {
            AppLogger.metrics.warning("⚠️ Output texture creation failed, falling back to CPU")
            return detectDarknessVariationsCPU(image: image, skinTone: skinTone)
        }
        AppLogger.metrics.debug("   ✅ Output texture created")

        // Configure sampling radius based on image size
        let sampleRadius = Int32(min(5, max(3, width / 256)))

        // Dispatch GPU kernel
        AppLogger.metrics.debug("   🚀 Creating command buffer...")
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            AppLogger.metrics.warning("⚠️ Command buffer creation failed, falling back to CPU")
            return detectDarknessVariationsCPU(image: image, skinTone: skinTone)
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(inputTexture, index: 0)
        encoder.setTexture(darknessTexture, index: 1)
        encoder.setBytes([sampleRadius], length: MemoryLayout<Int32>.size, index: 0)

        // Calculate threadgroup size and grid size
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let gridSize = MTLSize(
            width: (width + threadgroupSize.width - 1) / threadgroupSize.width * threadgroupSize.width,
            height: (height + threadgroupSize.height - 1) / threadgroupSize.height * threadgroupSize.height,
            depth: 1
        )

        encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()

        AppLogger.metrics.debug("   ⏳ Committing GPU work (sampleRadius=\(sampleRadius))...")
        let gpuStartTime = Date()
        commandBuffer.commit()

        // Use cancellable polling instead of blocking waitUntilCompleted()
        // This allows cancellation to work properly during analysis
        if !waitForCommandBufferCompletionCancellable(commandBuffer, timeout: 5.0) {
            AppLogger.metrics.warning("⚠️ GPU command buffer timed out or was cancelled, falling back to CPU")
            return detectDarknessVariationsCPU(image: image, skinTone: skinTone)
        }
        let gpuTime = Date().timeIntervalSince(gpuStartTime)
        AppLogger.metrics.debug("   ✅ GPU kernel complete in \(String(format: "%.1f", gpuTime * 1000))ms")

        // Read back darkness map from GPU
        AppLogger.metrics.debug("   📥 Reading back darkness map...")
        guard let darknessData = readDarknessMap(from: darknessTexture) else {
            AppLogger.metrics.warning("⚠️ Darkness map readback failed, falling back to CPU")
            return detectDarknessVariationsCPU(image: image, skinTone: skinTone)
        }

        // Perform CPU-based connected component analysis on darkness map
        AppLogger.metrics.debug("   🔍 Running connected component analysis...")
        let analysisStartTime = Date()
        let darknessSpots = analyzeConnectedComponents(
            darknessData: darknessData,
            width: width,
            height: height,
            skinTone: skinTone
        )
        let analysisTime = Date().timeIntervalSince(analysisStartTime)

        AppLogger.metrics.debug("   ✅ GPU darkness detection complete: \(darknessSpots.count) spots in \(String(format: "%.1f", analysisTime * 1000))ms")
        return darknessSpots
    }

    /// Create Metal texture from CGImage
    private func createMetalTexture(from image: CGImage, device: MTLDevice) -> MTLTexture? {
        let width = image.width
        let height = image.height

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead]

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }

        // Extract pixel data from CGImage
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else {
            return nil
        }

        // Upload to GPU texture
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bytesPerRow)

        return texture
    }

    /// Create empty Metal texture for output
    /// Uses r32Float instead of rgba32Float to reduce memory by 4x
    /// (only R channel is used for darkness values)
    private func createEmptyTexture(width: Int, height: Int, device: MTLDevice) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,  // Only need R channel, saves 75% memory
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderWrite, .shaderRead]

        let memoryMB = Double(width * height * 4) / 1_000_000.0
        AppLogger.metrics.debug("   📦 GPU output texture: \(width)x\(height) r32Float (\(String(format: "%.1f", memoryMB))MB)")

        return device.makeTexture(descriptor: textureDescriptor)
    }

    /// Read darkness map from GPU texture (r32Float format - single channel)
    private func readDarknessMap(from texture: MTLTexture) -> [Float]? {
        let width = texture.width
        let height = texture.height

        // r32Float = 1 float per pixel (4 bytes)
        let bytesPerRow = width * MemoryLayout<Float>.size

        var darknessMap = [Float](repeating: 0, count: width * height)
        let region = MTLRegionMake2D(0, 0, width, height)

        // Direct read into darkness map (no RGBA extraction needed with r32Float)
        darknessMap.withUnsafeMutableBytes { ptr in
            texture.getBytes(ptr.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }

        AppLogger.metrics.debug("   📖 GPU readback complete: \(width)x\(height) (\(darknessMap.count) pixels)")
        return darknessMap
    }

    /// CPU-based connected component analysis on GPU-generated darkness map
    private func analyzeConnectedComponents(
        darknessData: [Float],
        width: Int,
        height: Int,
        skinTone: SkinToneCategory
    ) -> [(x: Int, y: Int, darkness: Float, size: Float)] {
        // Guard against empty darkness data (defensive programming)
        guard !darknessData.isEmpty else {
            AppLogger.metrics.warning("⚠️ Empty darkness data array - returning empty results")
            return []
        }
        
        // Calculate adaptive darkness threshold based on skin tone
        let darknessMultiplier: Float
        switch skinTone {
        case .veryLight, .light:
            darknessMultiplier = 0.70  // 30% darker for light skin
        case .medium:
            darknessMultiplier = 0.73  // 27% darker for medium skin
        case .mediumDark:
            darknessMultiplier = 0.76  // 24% darker for Indian skin
        case .dark:
            darknessMultiplier = 0.80  // 20% darker for dark skin
        case .veryDark:
            darknessMultiplier = 0.82  // 18% darker for very dark skin
        }

        // Calculate average darkness to set threshold
        let avgDarkness = darknessData.reduce(0, +) / Float(darknessData.count)

        // FIXED: Skin-tone-adaptive minimum threshold to prevent over-detection
        // Light skin shows blemishes more clearly → lower minimum threshold
        // Dark skin has natural variations → higher minimum to avoid false positives
        // Previous fixed threshold of 0.10 caused 126 false positives for mediumDark skin
        let baseMinimum: Float
        switch skinTone {
        case .veryLight, .light:
            baseMinimum = 0.08   // Light skin shows blemishes clearly
        case .medium:
            baseMinimum = 0.10   // Medium skin - standard threshold
        case .mediumDark:
            baseMinimum = 0.12   // Indian/Mediterranean skin - more natural variation
        case .dark:
            baseMinimum = 0.14   // Dark skin - higher threshold for natural texture
        case .veryDark:
            baseMinimum = 0.16   // Very dark skin - highest threshold
        }
        let darknessThreshold = max(baseMinimum, avgDarkness * darknessMultiplier)

        AppLogger.metrics.debug("   Adaptive darkness threshold: \(darknessThreshold) (avg: \(avgDarkness), tone: \(skinTone))")

        var darkSpots: [(x: Int, y: Int, darkness: Float, size: Float)] = []
        var visited = Set<Int>()

        // Scan for local maxima in darkness map
        for y in stride(from: 10, to: height - 10, by: 3) {
            for x in stride(from: 10, to: width - 10, by: 3) {
                let idx = y * width + x
                guard !visited.contains(idx) else { continue }

                let darkness = darknessData[idx]

                // Check if this pixel exceeds threshold
                if darkness > darknessThreshold && isLocalDarknessMaximum(data: darknessData, x: x, y: y, width: width, height: height) {
                    // Flood-fill to measure connected dark region
                    // TIGHTENED: Reduced from 0.85 to 0.70 to prevent over-connecting adjacent spots
                    // 0.85 (15% tolerance) was too permissive, combining texture noise into large regions
                    // 0.70 (30% tolerance) requires pixels to be more similar to join the same blemish
                    let floodThreshold = darkness * 0.70
                    let (size, avgDarkness) = measureDarkRegion(
                        data: darknessData,
                        startX: x,
                        startY: y,
                        width: width,
                        height: height,
                        threshold: floodThreshold,
                        visited: &visited
                    )

                    if size >= minBlemishSize && size <= maxBlemishSize {
                        darkSpots.append((x, y, avgDarkness, size))
                    }
                }
            }
        }

        return darkSpots
    }

    /// Check if pixel is a local maximum in darkness
    private func isLocalDarknessMaximum(data: [Float], x: Int, y: Int, width: Int, height: Int) -> Bool {
        let centerValue = data[y * width + x]
        let radius = 2

        for dy in -radius...radius {
            for dx in -radius...radius {
                if dx == 0 && dy == 0 { continue }

                let nx = x + dx
                let ny = y + dy

                if nx >= 0 && nx < width && ny >= 0 && ny < height {
                    if data[ny * width + nx] >= centerValue {
                        return false
                    }
                }
            }
        }

        return true
    }

    /// Flood-fill to measure connected dark region
    private func measureDarkRegion(
        data: [Float],
        startX: Int,
        startY: Int,
        width: Int,
        height: Int,
        threshold: Float,
        visited: inout Set<Int>
    ) -> (size: Float, avgDarkness: Float) {
        var queue = [(startX, startY)]
        var size: Float = 0
        var totalDarkness: Float = 0
        let startIdx = startY * width + startX

        visited.insert(startIdx)

        while !queue.isEmpty && size < maxBlemishSize {
            let (x, y) = queue.removeFirst()
            let darkness = data[y * width + x]

            size += 1
            totalDarkness += darkness

            // 4-connected neighbors
            for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                let nx = x + dx
                let ny = y + dy

                if nx >= 0 && nx < width && ny >= 0 && ny < height {
                    let idx = ny * width + nx
                    if !visited.contains(idx) && data[idx] >= threshold {
                        visited.insert(idx)
                        queue.append((nx, ny))
                    }
                }
            }
        }

        let avgDarkness = size > 0 ? totalDarkness / size : 0
        return (size, avgDarkness)
    }

    // MARK: - Step 1: CPU Fallback Darkness Detection

    /// CPU-based darkness detection (fallback when GPU unavailable)
    /// IMPROVED: Skin-tone-specific darkness thresholds
    private func detectDarknessVariationsCPU(image: CGImage, skinTone: SkinToneCategory) -> [(x: Int, y: Int, darkness: Float, size: Float)] {
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
            return []
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Calculate adaptive darkness threshold based on skin brightness
        let avgBrightness = calculateAverageBrightness(data: grayData, width: width, height: height)

        // SKIN-TONE AWARE: Adjust darkness threshold
        // Very dark skin needs less strict threshold to avoid false positives
        // REFINED: Larger increments provide better discrimination across skin tones
        let darknessMultiplier: Float
        switch skinTone {
        case .veryLight, .light:
            darknessMultiplier = 0.70  // 30% darker for light skin
        case .medium:
            darknessMultiplier = 0.73  // 27% darker for medium skin
        case .mediumDark:
            darknessMultiplier = 0.76  // 24% darker for Indian skin (balanced sensitivity)
        case .dark:
            darknessMultiplier = 0.80  // 20% darker for dark skin (reduce false positives)
        case .veryDark:
            darknessMultiplier = 0.82  // 18% darker for very dark skin (avoid texture noise)
        }

        // Dark spots are darker than surrounding skin
        // FIXED: Lowered min from 30 to 15 to support very dark skin (Fitzpatrick V-VI)
        let darknessThreshold = UInt8(max(15, Int(avgBrightness * darknessMultiplier)))

        AppLogger.metrics.debug("   Adaptive darkness threshold: \(darknessThreshold) (avg: \(avgBrightness), tone: \(skinTone), multiplier: \(darknessMultiplier))")

        // Detect local minima (dark spots)
        var darkSpots: [(x: Int, y: Int, darkness: Float, size: Float)] = []
        var visited = Set<Int>()

        for y in stride(from: 10, to: height - 10, by: 3) {
            for x in stride(from: 10, to: width - 10, by: 3) {
                let idx = y * width + x
                guard !visited.contains(idx) else { continue }

                let centerValue = grayData[idx]

                // Check if this is a local minimum (darker than neighbors)
                if centerValue < darknessThreshold && isLocalDarkSpot(data: grayData, x: x, y: y, width: width, height: height) {
                    // Measure dark spot size via flood-fill
                    // FIXED: Use percentage (15% brighter) instead of fixed +30 offset
                    // Ensures consistent blemish boundary detection for Indian skin
                    let spotThreshold = UInt8(min(255, Int(Float(centerValue) * 1.15)))
                    let (size, darkness) = measureDarkSpot(
                        data: grayData,
                        startX: x,
                        startY: y,
                        width: width,
                        height: height,
                        threshold: spotThreshold,
                        visited: &visited
                    )

                    if size >= minBlemishSize && size <= maxBlemishSize {
                        darkSpots.append((x, y, darkness, size))
                    }
                }
            }
        }

        return darkSpots
    }

    /// Calculate average brightness of center face region
    private func calculateAverageBrightness(data: [UInt8], width: Int, height: Int) -> Float {
        let centerX = width / 2
        let centerY = height / 2
        let sampleRadius = min(width, height) / 6

        var sum: Float = 0
        var count = 0

        for y in stride(from: centerY - sampleRadius, to: centerY + sampleRadius, by: 5) {
            for x in stride(from: centerX - sampleRadius, to: centerX + sampleRadius, by: 5) {
                guard x >= 0 && x < width && y >= 0 && y < height else { continue }
                sum += Float(data[y * width + x])
                count += 1
            }
        }

        return count > 0 ? sum / Float(count) : 128.0
    }

    /// Check if pixel is a local dark spot
    private func isLocalDarkSpot(data: [UInt8], x: Int, y: Int, width: Int, height: Int) -> Bool {
        let centerValue = data[y * width + x]
        let radius = 2

        for dy in -radius...radius {
            for dx in -radius...radius {
                if dx == 0 && dy == 0 { continue }

                let nx = x + dx
                let ny = y + dy

                if nx >= 0 && nx < width && ny >= 0 && ny < height {
                    if data[ny * width + nx] <= centerValue {
                        return false
                    }
                }
            }
        }

        return true
    }

    /// Measure dark spot size using flood-fill
    private func measureDarkSpot(
        data: [UInt8],
        startX: Int,
        startY: Int,
        width: Int,
        height: Int,
        threshold: UInt8,
        visited: inout Set<Int>
    ) -> (size: Float, avgDarkness: Float) {
        var queue = [(startX, startY)]
        var size: Float = 0
        var totalDarkness: Float = 0
        let startIdx = startY * width + startX

        visited.insert(startIdx)

        while !queue.isEmpty && size < maxBlemishSize {
            let (x, y) = queue.removeFirst()
            size += 1
            totalDarkness += Float(data[y * width + x])

            for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                let nx = x + dx
                let ny = y + dy

                if nx >= 0 && nx < width && ny >= 0 && ny < height {
                    let idx = ny * width + nx
                    if !visited.contains(idx) && data[idx] < threshold {
                        visited.insert(idx)
                        queue.append((nx, ny))
                    }
                }
            }
        }

        let avgDarkness = size > 0 ? totalDarkness / size : 0
        return (size, avgDarkness)
    }

    // MARK: - Step 2: 3D Elevation Detection

    /// Detect elevated regions in 3D mesh (bumps = potential acne)
    private func detect3DElevations(geometry: FaceMeshGeometry, imageSize: CGSize) -> [SIMD2<Int>: Float] {
        var elevationMap: [SIMD2<Int>: Float] = [:]

        let vertices = geometry.vertices
        _ = geometry.normals  // normals (available but not needed for elevation detection)

        // Build adjacency for local elevation comparison
        let adjacency = buildAdjacency(geometry: geometry)

        for (index, vertex) in vertices.enumerated() {
            let neighbors = adjacency[index]
            guard !neighbors.isEmpty else { continue }

            // Calculate local elevation (z-displacement from neighbors)
            var totalDisplacement: Float = 0

            for neighborIndex in neighbors {
                let neighborVertex = vertices[neighborIndex]
                let zDiff = vertex.z - neighborVertex.z
                totalDisplacement += abs(zDiff)
            }

            let avgDisplacement = totalDisplacement / Float(neighbors.count)

            // If elevated more than 0.5mm (0.0005m), it's a potential bump
            if avgDisplacement > 0.0005 {
                // Project 3D vertex to 2D image coordinates
                let normalizedX = (vertex.x + 0.05) / 0.1  // ARKit face is ~0.1m wide
                let normalizedY = (vertex.y + 0.05) / 0.1

                let imageX = Int(normalizedX * Float(imageSize.width))
                let imageY = Int(normalizedY * Float(imageSize.height))

                if imageX >= 0 && imageX < Int(imageSize.width) && imageY >= 0 && imageY < Int(imageSize.height) {
                    let key = SIMD2<Int>(imageX, imageY)
                    elevationMap[key] = avgDisplacement * 1000  // Convert to mm
                }
            }
        }

        return elevationMap
    }

    /// Build vertex adjacency for mesh analysis
    private func buildAdjacency(geometry: FaceMeshGeometry) -> [[Int]] {
        var adjacency = Array(repeating: Set<Int>(), count: geometry.vertices.count)

        for i in stride(from: 0, to: geometry.triangleIndices.count, by: 3) {
            let v0 = Int(geometry.triangleIndices[i])
            let v1 = Int(geometry.triangleIndices[i + 1])
            let v2 = Int(geometry.triangleIndices[i + 2])

            adjacency[v0].insert(v1)
            adjacency[v0].insert(v2)
            adjacency[v1].insert(v0)
            adjacency[v1].insert(v2)
            adjacency[v2].insert(v0)
            adjacency[v2].insert(v1)
        }

        return adjacency.map { Array($0) }
    }

    // MARK: - Step 3: Correlate Darkness + Elevation

    /// Correlate darkness spots with 3D elevations to identify acne
    private func correlateDarknessAndElevation(
        darknessSpots: [(x: Int, y: Int, darkness: Float, size: Float)],
        elevationMap: [SIMD2<Int>: Float],
        imageSize: CGSize
    ) -> [Blemish] {
        var blemishes: [Blemish] = []

        for spot in darknessSpots {
            // Check if there's a corresponding elevation nearby
            let elevation = findNearbyElevation(
                x: spot.x,
                y: spot.y,
                elevationMap: elevationMap,
                searchRadius: Int(spot.size / 2)
            )

            // Classify blemish type based on elevation
            let type: BlemishType
            if elevation == 0 {
                // Flat dark spot
                type = spot.darkness < 50 ? .blackhead : .postInflammatory
            } else if elevation < 1.0 {
                // Small bump
                type = .papule
            } else if elevation < 2.0 {
                // Medium bump
                type = .pustule
            } else {
                // Large bump
                type = .cyst
            }

            // Determine face region
            let location = determineFaceRegion(
                x: spot.x,
                y: spot.y,
                imageSize: imageSize
            )

            // Calculate severity (0-1) based on size and elevation
            let severity = min(1.0, (spot.size / maxBlemishSize) * 0.5 + (elevation / 3.0) * 0.5)

            let blemish = Blemish(
                location: location,
                type: type,
                severity: severity,
                size: spot.size,
                elevation: elevation,
                normalizedX: Float(spot.x) / Float(imageSize.width),
                normalizedY: Float(spot.y) / Float(imageSize.height)
            )

            blemishes.append(blemish)
        }

        return blemishes
    }

    /// Find nearby elevation for a given position
    private func findNearbyElevation(
        x: Int,
        y: Int,
        elevationMap: [SIMD2<Int>: Float],
        searchRadius: Int
    ) -> Float {
        var maxElevation: Float = 0

        for dy in -searchRadius...searchRadius {
            for dx in -searchRadius...searchRadius {
                let key = SIMD2<Int>(x + dx, y + dy)
                if let elevation = elevationMap[key] {
                    maxElevation = max(maxElevation, elevation)
                }
            }
        }

        return maxElevation
    }

    /// Determine which face region a blemish is in
    private func determineFaceRegion(x: Int, y: Int, imageSize: CGSize) -> String {
        let normalizedX = Float(x) / Float(imageSize.width)
        let normalizedY = Float(y) / Float(imageSize.height)

        if normalizedY < 0.3 {
            return "forehead"
        } else if normalizedY < 0.5 {
            if normalizedX < 0.4 {
                return "leftCheek"
            } else if normalizedX > 0.6 {
                return "rightCheek"
            } else {
                return "nose"
            }
        } else if normalizedY < 0.7 {
            if normalizedX < 0.4 {
                return "leftCheek"
            } else if normalizedX > 0.6 {
                return "rightCheek"
            } else {
                return "mouth"
            }
        } else {
            return "chin"
        }
    }

    // MARK: - Step 4-6: Scoring

    private func classifySeverity(blemishCount: Int) -> AcneSeverity {
        if blemishCount <= 5 {
            return .clear
        } else if blemishCount <= 20 {
            return .mild
        } else if blemishCount <= 50 {
            return .moderate
        } else {
            return .severe
        }
    }

    private func calculateRegionalScores(blemishes: [Blemish]) -> [String: Float] {
        var regionalCounts: [String: Int] = [:]
        var regionalSeverities: [String: Float] = [:]

        for blemish in blemishes {
            regionalCounts[blemish.location, default: 0] += 1
            regionalSeverities[blemish.location, default: 0] += blemish.severity
        }

        var regionalScores: [String: Float] = [:]

        for (region, count) in regionalCounts {
            // Safe unwrap instead of force unwrap (defensive programming)
            guard let severity = regionalSeverities[region] else {
                AppLogger.metrics.warning("⚠️ Missing severity for region '\(region)' - skipping")
                continue
            }
            let avgSeverity = severity / Float(count)
            // Score: 100 = perfect, 0 = very bad
            let score = max(0, 100 - Float(count) * 5 - avgSeverity * 50)
            regionalScores[region] = score
        }

        return regionalScores
    }

    private func calculateOverallScore(blemishes: [Blemish], severity: AcneSeverity) -> Float {
        if blemishes.isEmpty {
            return 95  // Perfect score
        }

        // Start with severity base score
        var score = severity.score

        // Reduce score based on blemish severity
        let avgSeverity = blemishes.map { $0.severity }.reduce(0, +) / Float(blemishes.count)
        score -= avgSeverity * 20

        return max(10, min(100, score))
    }

    private func calculateConfidence(
        darknessSpotCount: Int,
        hasGeometry: Bool,
        imageSize: CGSize
    ) -> Float {
        var confidence: Float = 70  // Base confidence

        // Higher confidence if we have 3D geometry
        if hasGeometry {
            confidence += 20  // 3D validation increases confidence
        } else {
            confidence -= 15  // Only 2D, lower confidence
        }

        // Lower confidence if too many or too few spots (might be noise or missed)
        if darknessSpotCount > 200 {
            confidence -= 20  // Too many - likely noise
        } else if darknessSpotCount < 3 && !hasGeometry {
            confidence -= 10  // Too few without 3D - might be missing some
        }

        return max(30, min(90, confidence))
    }
    
    // MARK: - Cancellable GPU Execution Helper
    
    /// Wait for command buffer completion with cancellation support
    /// Uses polling instead of blocking waitUntilCompleted() to allow cancellation
    /// - Parameters:
    ///   - commandBuffer: The Metal command buffer to wait for
    ///   - timeout: Maximum wait time in seconds (default: 5.0)
    /// - Returns: true if completed successfully, false if timed out or cancelled
    private func waitForCommandBufferCompletionCancellable(_ commandBuffer: MTLCommandBuffer, timeout: TimeInterval = 5.0) -> Bool {
        let startTime = Date()
        let pollInterval: UInt64 = 2_000_000 // 2ms polling interval
        
        while commandBuffer.status != .completed && commandBuffer.status != .error {
            // Check for task cancellation (if running in async context)
            if Task.isCancelled {
                AppLogger.metrics.info("🛑 GPU operation cancelled")
                return false
            }
            
            // Check timeout
            if Date().timeIntervalSince(startTime) > timeout {
                AppLogger.metrics.warning("⚠️ GPU command buffer timeout after \(timeout)s")
                return false
            }
            
            // Small sleep to avoid busy-waiting (non-blocking)
            Thread.sleep(forTimeInterval: Double(pollInterval) / 1_000_000_000.0)
        }
        
        // Check for GPU errors
        if let error = commandBuffer.error {
            AppLogger.metrics.error("❌ GPU command buffer error: \(error.localizedDescription)")
            return false
        }
        
        if commandBuffer.status == .error {
            AppLogger.metrics.error("❌ GPU command buffer status is error")
            return false
        }
        
        return true
    }
}
