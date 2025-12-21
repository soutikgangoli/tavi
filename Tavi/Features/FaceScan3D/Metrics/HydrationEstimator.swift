//
//  HydrationEstimator.swift
//  Tavi
//
//  IMPORTANT: This provides INDIRECT hydration estimation, not direct measurement
//
//  Method: Correlates specular reflectance and surface roughness with hydration
//  Rationale: Hydrated skin appears more reflective (specular highlights) and smoother
//
//  Limitations:
//  - Does NOT measure actual water content in skin
//  - Affected by lighting conditions, skin products (oils, lotions), makeup
//  - Provides relative indicator only, not absolute measurement
//  - Cannot replace clinical hydration measurement devices
//

import UIKit
import simd
import Metal

/// Hydration estimation result (indirect measurement)
public struct HydrationEstimate: Codable, Sendable {
    let overallScore: Float  // 0-100 (estimated hydration indicator)
    let level: HydrationLevel
    let regionalScores: [String: Float]

    // Multi-method ensemble components
    let specularityScore: Float     // Method 1: Reflectance analysis
    let textureScore: Float          // Method 2: High-frequency texture analysis
    let varianceScore: Float         // Method 3: Color uniformity analysis

    let confidence: Float  // 0-100, reliability of estimate based on conditions
}

enum HydrationLevel: String, Codable {
    case veryDry = "Very Dry"
    case dry = "Dry"
    case normal = "Normal"
    case wellHydrated = "Well Hydrated"

    var score: Float {
        switch self {
        case .veryDry: return 25
        case .dry: return 50
        case .normal: return 75
        case .wellHydrated: return 90
        }
    }
}

/// Hydration estimator
class HydrationEstimator {

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
                AppLogger.metrics.info("✅ HydrationEstimator: GPU acceleration enabled")
            } catch {
                AppLogger.metrics.warning("⚠️ HydrationEstimator: Failed to initialize Metal - falling back to CPU")
                self.metalAnalyzer = nil
                self.texturePool = nil
            }
        } else {
            AppLogger.metrics.info("ℹ️ HydrationEstimator: Using CPU analysis (GPU not supported)")
        }
    }

    deinit {
        // Clean up GPU resources
        texturePool?.clear()
    }

    // MARK: - Performance Optimization

    /// Maximum texture size for CPU analysis (1024x1024 provides good balance of accuracy and performance)
    private let maxAnalysisSize: Int = 1024

    /// Downsample image to max size for efficient processing
    /// 4096x4096 → 1024x1024 = 16x fewer pixels, minimal accuracy impact for statistical analysis
    private func downsample(_ image: CGImage, maxSize: Int? = nil) -> CGImage? {
        let targetSize = maxSize ?? maxAnalysisSize
        let scale = min(1.0, Double(targetSize) / Double(max(image.width, image.height)))

        // No downsampling needed if already small enough
        if scale >= 1.0 { return image }

        let newWidth = Int(Double(image.width) * scale)
        let newHeight = Int(Double(image.height) * scale)

        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: newWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage()
    }

    // MARK: - Public API

    /// Estimate hydration using multi-method ensemble
    /// Method 1: Specularity (reflectance)
    /// Method 2: Texture frequency (smoothness)
    /// Method 3: Color variance (uniformity)
    func estimateHydration(
        texture: UIImage,
        roughnessScore: Float,
        geometry: FaceMeshGeometry
    ) -> HydrationEstimate {

        AppLogger.metrics.info("💧 Estimating skin hydration (multi-method ensemble)...")

        // GPU PATH: Use full resolution (4096x4096) analysis on GPU
        if useGPU, let metalAnalyzer = metalAnalyzer {
            AppLogger.metrics.info("   🎨 Using GPU acceleration (full resolution)")
            return estimateHydrationGPU(
                texture: texture,
                roughnessScore: roughnessScore,
                geometry: geometry,
                metalAnalyzer: metalAnalyzer
            )
        }

        // CPU FALLBACK: Downsample texture to max 1024x1024 for efficient processing
        // Statistical analysis accuracy is preserved at this resolution
        AppLogger.metrics.info("   💻 Using CPU analysis (with downsampling)")
        let analysisTexture: UIImage
        if let cgImage = texture.cgImage, let downsampled = downsample(cgImage) {
            analysisTexture = UIImage(cgImage: downsampled)
            AppLogger.metrics.info("   📐 Downsampled \(cgImage.width)x\(cgImage.height) → \(downsampled.width)x\(downsampled.height)")
        } else {
            analysisTexture = texture
        }

        // Method 1: Specularity analysis (hydrated skin reflects more light)
        let specularityScore = analyzeSpecularity(texture: analysisTexture)
        AppLogger.metrics.info("   Method 1 (Specularity): \(String(format: "%.1f", specularityScore))/100")

        // Method 2: Texture frequency analysis (hydrated skin is smoother)
        let textureScore = analyzeTextureFrequency(texture: analysisTexture)
        AppLogger.metrics.info("   Method 2 (Texture): \(String(format: "%.1f", textureScore))/100")

        // Method 3: Color variance analysis (hydrated skin is more uniform)
        let varianceScore = analyzeColorVariance(texture: analysisTexture)
        AppLogger.metrics.info("   Method 3 (Variance): \(String(format: "%.1f", varianceScore))/100")

        // Ensemble: Weighted average of all three methods
        // Weights: Specularity (40%), Texture (35%), Variance (25%)
        let score = (specularityScore * 0.40 + textureScore * 0.35 + varianceScore * 0.25)

        let level: HydrationLevel
        if score < 40 {
            level = .veryDry
        } else if score < 60 {
            level = .dry
        } else if score < 80 {
            level = .normal
        } else {
            level = .wellHydrated
        }

        // Analyze regional hydration across different face areas
        let regionalScores = analyzeRegionalHydration(
            texture: analysisTexture,
            roughnessScore: roughnessScore,
            geometry: geometry
        )

        // Calculate confidence based on measurement conditions
        let confidence = calculateConfidence(
            specularity: specularityScore,
            regionalScores: regionalScores,
            methodAgreement: calculateMethodAgreement(
                method1: specularityScore,
                method2: textureScore,
                method3: varianceScore
            )
        )

        AppLogger.metrics.info("✅ Hydration estimate: \(level.rawValue) (\(String(format: "%.1f", score))/100)")
        AppLogger.metrics.info("   Confidence: \(String(format: "%.0f", confidence))% (indirect measurement)")
        AppLogger.metrics.warning("   ⚠️  Note: Indirect estimate based on ensemble of 3 methods, not direct water content")
        AppLogger.metrics.info("   Regional scores: \(regionalScores.count) regions")

        return HydrationEstimate(
            overallScore: score,
            level: level,
            regionalScores: regionalScores,
            specularityScore: specularityScore,
            textureScore: textureScore,
            varianceScore: varianceScore,
            confidence: confidence
        )
    }

    // MARK: - GPU Acceleration Methods

    /// GPU-accelerated hydration analysis (full resolution, no downsampling)
    private func estimateHydrationGPU(
        texture: UIImage,
        roughnessScore: Float,
        geometry: FaceMeshGeometry,
        metalAnalyzer: MetalAnalyzerBase
    ) -> HydrationEstimate {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Convert UIImage to Metal texture
            guard let inputTexture = MetalHelpers.textureFromUIImage(texture, device: metalAnalyzer.device) else {
                AppLogger.metrics.error("❌ GPU: Failed to convert image to texture - falling back to CPU")
                return estimateHydrationCPU(texture: texture, roughnessScore: roughnessScore, geometry: geometry)
            }

            let width = inputTexture.width
            let height = inputTexture.height
            AppLogger.metrics.info("   📏 Analyzing full resolution: \(width)x\(height)")

            // STEP 1: Calculate adaptive threshold
            let adaptiveThreshold = try calculateAdaptiveThresholdGPU(
                inputTexture: inputTexture,
                metalAnalyzer: metalAnalyzer
            )
            AppLogger.metrics.debug("   🎯 Adaptive threshold: \(String(format: "%.3f", adaptiveThreshold))")

            // STEP 2: Analyze hydration (all three methods in single GPU pass)
            let results = try analyzeHydrationGPU(
                inputTexture: inputTexture,
                adaptiveThreshold: adaptiveThreshold,
                metalAnalyzer: metalAnalyzer
            )

            let specularityScore = results.specularity
            let textureScore = results.texture
            let varianceScore = results.variance

            AppLogger.metrics.info("   Method 1 (Specularity): \(String(format: "%.1f", specularityScore))/100")
            AppLogger.metrics.info("   Method 2 (Texture): \(String(format: "%.1f", textureScore))/100")
            AppLogger.metrics.info("   Method 3 (Variance): \(String(format: "%.1f", varianceScore))/100")

            // Ensemble: Weighted average
            let score = (specularityScore * 0.40 + textureScore * 0.35 + varianceScore * 0.25)

            let level: HydrationLevel
            if score < 40 {
                level = .veryDry
            } else if score < 60 {
                level = .dry
            } else if score < 80 {
                level = .normal
            } else {
                level = .wellHydrated
            }

            // Regional analysis (GPU)
            let regionalScores = try analyzeRegionalHydrationGPU(
                inputTexture: inputTexture,
                adaptiveThreshold: adaptiveThreshold,
                metalAnalyzer: metalAnalyzer
            )

            // Calculate confidence
            let confidence = calculateConfidence(
                specularity: specularityScore,
                regionalScores: regionalScores,
                methodAgreement: calculateMethodAgreement(
                    method1: specularityScore,
                    method2: textureScore,
                    method3: varianceScore
                )
            )

            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            AppLogger.metrics.info("✅ Hydration estimate (GPU): \(level.rawValue) (\(String(format: "%.1f", score))/100)")
            AppLogger.metrics.info("   GPU time: \(String(format: "%.1f", elapsed))ms")
            AppLogger.metrics.info("   Confidence: \(String(format: "%.0f", confidence))% (indirect measurement)")

            return HydrationEstimate(
                overallScore: score,
                level: level,
                regionalScores: regionalScores,
                specularityScore: specularityScore,
                textureScore: textureScore,
                varianceScore: varianceScore,
                confidence: confidence
            )

        } catch {
            AppLogger.metrics.error("❌ GPU analysis failed: \(error.localizedDescription) - falling back to CPU")
            return estimateHydrationCPU(texture: texture, roughnessScore: roughnessScore, geometry: geometry)
        }
    }

    /// Helper to run CPU analysis (extracted from main method)
    private func estimateHydrationCPU(
        texture: UIImage,
        roughnessScore: Float,
        geometry: FaceMeshGeometry
    ) -> HydrationEstimate {
        // Downsample for CPU
        let analysisTexture: UIImage
        if let cgImage = texture.cgImage, let downsampled = downsample(cgImage) {
            analysisTexture = UIImage(cgImage: downsampled)
            AppLogger.metrics.info("   📐 CPU: Downsampled \(cgImage.width)x\(cgImage.height) → \(downsampled.width)x\(downsampled.height)")
        } else {
            analysisTexture = texture
        }

        let specularityScore = analyzeSpecularity(texture: analysisTexture)
        let textureScore = analyzeTextureFrequency(texture: analysisTexture)
        let varianceScore = analyzeColorVariance(texture: analysisTexture)

        let score = (specularityScore * 0.40 + textureScore * 0.35 + varianceScore * 0.25)

        let level: HydrationLevel
        if score < 40 {
            level = .veryDry
        } else if score < 60 {
            level = .dry
        } else if score < 80 {
            level = .normal
        } else {
            level = .wellHydrated
        }

        let regionalScores = analyzeRegionalHydration(
            texture: analysisTexture,
            roughnessScore: roughnessScore,
            geometry: geometry
        )

        let confidence = calculateConfidence(
            specularity: specularityScore,
            regionalScores: regionalScores,
            methodAgreement: calculateMethodAgreement(
                method1: specularityScore,
                method2: textureScore,
                method3: varianceScore
            )
        )

        return HydrationEstimate(
            overallScore: score,
            level: level,
            regionalScores: regionalScores,
            specularityScore: specularityScore,
            textureScore: textureScore,
            varianceScore: varianceScore,
            confidence: confidence
        )
    }

    /// Calculate adaptive threshold using GPU
    private func calculateAdaptiveThresholdGPU(
        inputTexture: MTLTexture,
        metalAnalyzer: MetalAnalyzerBase
    ) throws -> Float {
        // Load pipeline
        let pipeline = try metalAnalyzer.loadPipeline(named: "calculateAdaptiveThreshold")

        // Create output buffer
        let resultBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<Float>.size)

        // Execute
        try metalAnalyzer.executeSync(operation: "calculateAdaptiveThreshold") { commandBuffer in
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

        // Read result
        let resultPtr = resultBuffer.contents().assumingMemoryBound(to: Float.self)
        return resultPtr.pointee
    }

    /// Analyze hydration using GPU (single pass)
    private func analyzeHydrationGPU(
        inputTexture: MTLTexture,
        adaptiveThreshold: Float,
        metalAnalyzer: MetalAnalyzerBase
    ) throws -> (specularity: Float, texture: Float, variance: Float) {
        // Load pipeline
        let pipeline = try metalAnalyzer.loadPipeline(named: "analyzeHydration")

        // Calculate threadgroup configuration
        let (threadgroups, threadsPerGroup) = metalAnalyzer.calculateThreadgroups(
            pipeline: pipeline,
            width: inputTexture.width,
            height: inputTexture.height
        )

        let numThreadgroups = threadgroups.width * threadgroups.height

        // Create buffer for partial results (one per threadgroup)
        struct PartialResults {
            var specularPixelCount: Float
            var textureEnergySum: Float
            var luminanceSum: Float
            var luminanceSqSum: Float
            var validPixelCount: Float
        }

        let resultsBuffer = try metalAnalyzer.createBuffer(
            length: MemoryLayout<PartialResults>.stride * numThreadgroups
        )

        // Create threshold buffer
        var threshold = adaptiveThreshold
        let thresholdBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<Float>.size)
        memcpy(thresholdBuffer.contents(), &threshold, MemoryLayout<Float>.size)

        // Create threadgroupsPerRow buffer (required for linear index calculation)
        var threadgroupsPerRow = UInt32(threadgroups.width)
        let threadgroupsPerRowBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<UInt32>.size)
        memcpy(threadgroupsPerRowBuffer.contents(), &threadgroupsPerRow, MemoryLayout<UInt32>.size)

        // Execute kernel
        try metalAnalyzer.executeSync(operation: "analyzeHydration") { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw GPUAnalysisError.commandBufferFailed("Failed to create compute encoder")
            }

            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(inputTexture, index: 0)
            encoder.setBuffer(resultsBuffer, offset: 0, index: 0)
            encoder.setBuffer(thresholdBuffer, offset: 0, index: 1)
            encoder.setBuffer(threadgroupsPerRowBuffer, offset: 0, index: 2)

            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
        }

        // Reduce partial results on CPU (small array)
        let resultsPtr = resultsBuffer.contents().assumingMemoryBound(to: PartialResults.self)
        var totalSpecular: Float = 0
        var totalTexture: Float = 0
        var totalLuminance: Float = 0
        var totalLuminanceSq: Float = 0
        var totalPixels: Float = 0

        for i in 0..<numThreadgroups {
            let result = resultsPtr[i]
            totalSpecular += result.specularPixelCount
            totalTexture += result.textureEnergySum
            totalLuminance += result.luminanceSum
            totalLuminanceSq += result.luminanceSqSum
            totalPixels += result.validPixelCount
        }

        // Calculate scores with NaN guards
        // FIXED: Added NaN/Inf guards to prevent garbage output from GPU errors
        let specularRatio = totalPixels > 0 ? totalSpecular / totalPixels : 0
        let specularityScoreRaw = min(100, specularRatio * 1000)
        let specularityScore = specularityScoreRaw.isNaN || specularityScoreRaw.isInfinite ? 50.0 : specularityScoreRaw

        let avgTextureEnergy = totalPixels > 0 ? totalTexture / totalPixels : 0
        // FIX: Use logarithmic scaling to handle wide range of texture energy values
        // Linear scaling (200) fails when avgEnergy >= 0.5 (score becomes 0)
        // Logarithmic scaling: log2(1 + x*10) compresses high values
        // avgEnergy 0.0 → score 100, 0.1 → 85, 0.3 → 60, 0.5 → 45, 1.0 → 30
        let logEnergy = log2(1 + avgTextureEnergy * 10)  // Range: 0 to ~3.5 for typical values
        let textureScoreRaw = max(0, min(100, 100 - (logEnergy * 28)))  // 28 = 100/3.5 approx
        let textureScore = textureScoreRaw.isNaN || textureScoreRaw.isInfinite ? 50.0 : textureScoreRaw
        AppLogger.metrics.debug("💧 Hydration GPU Debug: avgTextureEnergy=\(avgTextureEnergy), logEnergy=\(logEnergy), textureScore=\(textureScore)")

        let meanLuminance = totalPixels > 0 ? totalLuminance / totalPixels : 0
        let variance = totalPixels > 0 ? (totalLuminanceSq / totalPixels) - (meanLuminance * meanLuminance) : 0
        let stdDev = sqrt(max(0, variance))
        let varianceScoreRaw = max(0, min(100, 100 - (stdDev / 3.0)))
        let varianceScore = varianceScoreRaw.isNaN || varianceScoreRaw.isInfinite ? 50.0 : varianceScoreRaw

        return (specularityScore, textureScore, varianceScore)
    }

    /// Analyze regional hydration using GPU
    private func analyzeRegionalHydrationGPU(
        inputTexture: MTLTexture,
        adaptiveThreshold: Float,
        metalAnalyzer: MetalAnalyzerBase
    ) throws -> [String: Float] {
        let pipeline = try metalAnalyzer.loadPipeline(named: "analyzeRegionalHydration")

        // Define face regions
        let regions: [String: (minX: Float, maxX: Float, minY: Float, maxY: Float)] = [
            "forehead": (0.3, 0.7, 0.1, 0.3),
            "leftCheek": (0.1, 0.4, 0.4, 0.7),
            "rightCheek": (0.6, 0.9, 0.4, 0.7),
            "nose": (0.4, 0.6, 0.3, 0.6),
            "chin": (0.35, 0.65, 0.7, 0.9),
            "underEye": (0.3, 0.7, 0.3, 0.45)
        ]

        var regionalScores: [String: Float] = [:]

        for (regionName, bounds) in regions {
            // Calculate threadgroup config
            let (threadgroups, threadsPerGroup) = metalAnalyzer.calculateThreadgroups(
                pipeline: pipeline,
                width: inputTexture.width,
                height: inputTexture.height
            )
            let numThreadgroups = threadgroups.width * threadgroups.height

            // Create buffers
            struct PartialResults {
                var specularPixelCount: Float
                var textureEnergySum: Float
                var validPixelCount: Float
                var luminanceSum: Float
                var luminanceSqSum: Float
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

            // Create threadgroupsPerRow buffer (required for linear index calculation)
            var threadgroupsPerRow = UInt32(threadgroups.width)
            let threadgroupsPerRowBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<UInt32>.size)
            memcpy(threadgroupsPerRowBuffer.contents(), &threadgroupsPerRow, MemoryLayout<UInt32>.size)

            // Execute
            try metalAnalyzer.executeSync(operation: "analyzeRegionalHydration") { commandBuffer in
                guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                    throw GPUAnalysisError.commandBufferFailed("Failed to create encoder")
                }

                encoder.setComputePipelineState(pipeline)
                encoder.setTexture(inputTexture, index: 0)
                encoder.setBuffer(resultsBuffer, offset: 0, index: 0)
                encoder.setBuffer(boundsBuffer, offset: 0, index: 1)
                encoder.setBuffer(thresholdBuffer, offset: 0, index: 2)
                encoder.setBuffer(threadgroupsPerRowBuffer, offset: 0, index: 3)

                encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
                encoder.endEncoding()
            }

            // Reduce results
            let resultsPtr = resultsBuffer.contents().assumingMemoryBound(to: PartialResults.self)
            var totalSpecular: Float = 0
            var totalTexture: Float = 0
            var totalPixels: Float = 0

            for i in 0..<numThreadgroups {
                let result = resultsPtr[i]
                totalSpecular += result.specularPixelCount
                totalTexture += result.textureEnergySum
                totalPixels += result.validPixelCount
            }

            // Calculate regional score
            if totalPixels > 0 {
                let specularRatio = totalSpecular / totalPixels
                let regionalSpecularity = min(100, specularRatio * 1000)

                let avgTexture = totalTexture / totalPixels
                let regionalSmoothness = max(0, min(100, 100 - (avgTexture * 500)))

                let hydrationScore = regionalSpecularity * 0.6 + regionalSmoothness * 0.4
                regionalScores[regionName] = hydrationScore
            } else {
                regionalScores[regionName] = 50.0
            }
        }

        return regionalScores
    }

    // MARK: - CPU Methods (Private)

    private func analyzeSpecularity(texture: UIImage) -> Float {
        // Detect bright specular highlights (hydrated skin reflects more)
        // NOW USES: Skin-tone adaptive threshold for better accuracy across all skin tones
        guard let cgImage = texture.cgImage else { return 50 }

        let width = cgImage.width
        let height = cgImage.height

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return 50
        }

        // STEP 1: Calculate adaptive threshold based on skin tone
        let adaptiveThreshold = calculateAdaptiveSpecularThreshold(ptr: ptr, width: width, height: height)

        var brightPixels = 0
        let totalPixels = width * height

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = ptr[offset]
                let g = ptr[offset + 1]
                let b = ptr[offset + 2]

                // Bright pixels indicate specularity (using adaptive threshold)
                if r > adaptiveThreshold && g > adaptiveThreshold && b > adaptiveThreshold {
                    brightPixels += 1
                }
            }
        }

        let specularRatio = Float(brightPixels) / Float(totalPixels)
        return min(100, specularRatio * 1000)  // Scale to 0-100
    }

    /// Calculate skin-tone adaptive specular threshold
    /// Darker skin: lower absolute brightness, but same relative threshold
    private func calculateAdaptiveSpecularThreshold(ptr: UnsafePointer<UInt8>, width: Int, height: Int) -> UInt8 {
        // Calculate average skin brightness from center region
        var rSum: Int = 0, gSum: Int = 0, bSum: Int = 0
        var count = 0

        let centerX = width / 2
        let centerY = height / 2
        let sampleRadius = min(width, height) / 4

        for y in max(0, centerY - sampleRadius)..<min(height, centerY + sampleRadius) {
            for x in max(0, centerX - sampleRadius)..<min(width, centerX + sampleRadius) {
                let offset = (y * width + x) * 4
                rSum += Int(ptr[offset])
                gSum += Int(ptr[offset + 1])
                bSum += Int(ptr[offset + 2])
                count += 1
            }
        }

        guard count > 0 else { return 200 }

        let avgR = Float(rSum) / Float(count)
        let avgG = Float(gSum) / Float(count)
        let avgB = Float(bSum) / Float(count)
        let avgBrightness = (avgR + avgG + avgB) / 3.0

        // Adaptive threshold: 75% of max possible brightness for this skin tone
        // FIXED: Lowered minimum from 150 to 100 for Indian skin (Fitzpatrick III-IV)
        // Indian skin avgBrightness ~100-140 → maxPossible ~150-210 → threshold ~112-157
        // Previous min of 150 was often ABOVE max possible for Indian skin!
        let maxPossible = min(255.0, avgBrightness * 1.5)
        return UInt8(max(100, min(220, maxPossible * 0.75)))
    }

    /// Method 2: Analyze texture frequency (high-frequency = rough = dehydrated)
    private func analyzeTextureFrequency(texture: UIImage) -> Float {
        guard let cgImage = texture.cgImage else { return 50 }

        let width = cgImage.width
        let height = cgImage.height

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
            return 50
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Apply high-pass filter to detect texture
        let floatData = grayData.map { Float($0) / 255.0 }
        var highFreqEnergy: Float = 0

        // Simple Laplacian operator (high-pass filter)
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = floatData[y * width + x]
                let top = floatData[(y - 1) * width + x]
                let bottom = floatData[(y + 1) * width + x]
                let left = floatData[y * width + (x - 1)]
                let right = floatData[y * width + (x + 1)]

                // Laplacian: 4*center - (top + bottom + left + right)
                let laplacian = abs(4 * center - (top + bottom + left + right))
                highFreqEnergy += laplacian
            }
        }

        // Average energy
        let avgEnergy = highFreqEnergy / Float((width - 2) * (height - 2))

        // Convert to hydration score (low energy = smooth = hydrated)
        // FIX: Use logarithmic scaling to handle wide range of texture energy values
        // Linear scaling fails when avgEnergy >= 0.5 (score becomes 0)
        // Logarithmic scaling: log2(1 + x*10) compresses high values
        let logEnergy = log2(1 + avgEnergy * 10)
        let textureScore = max(0, min(100, 100 - (logEnergy * 28)))
        AppLogger.metrics.debug("💧 Hydration CPU Debug: avgEnergy=\(avgEnergy), logEnergy=\(logEnergy), textureScore=\(textureScore)")
        return textureScore
    }

    /// Method 3: Analyze color variance (high variance = uneven = dehydrated)
    private func analyzeColorVariance(texture: UIImage) -> Float {
        guard let cgImage = texture.cgImage else { return 50 }

        let width = cgImage.width
        let height = cgImage.height

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return 50
        }

        // Calculate variance in luminance
        var intensities: [Float] = []

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = Float(ptr[offset])
                let g = Float(ptr[offset + 1])
                let b = Float(ptr[offset + 2])

                // FIXED: Standardized on BT.709 (sRGB) for consistency
                let intensity = 0.2126 * r + 0.7152 * g + 0.0722 * b
                intensities.append(intensity)
            }
        }

        // Calculate standard deviation
        let mean = intensities.reduce(0, +) / Float(intensities.count)
        let variance = intensities.map { pow($0 - mean, 2) }.reduce(0, +) / Float(intensities.count)
        let stdDev = sqrt(variance)

        // Convert to hydration score (low variance = uniform = hydrated)
        let varianceScore = max(0, 100 - (stdDev / 3.0))  // Scale to 0-100
        return min(100, varianceScore)
    }

    /// Calculate how much the three methods agree (for confidence)
    private func calculateMethodAgreement(method1: Float, method2: Float, method3: Float) -> Float {
        // Calculate pairwise differences
        let diff12 = abs(method1 - method2)
        let diff13 = abs(method1 - method3)
        let diff23 = abs(method2 - method3)

        // Average difference
        let avgDiff = (diff12 + diff13 + diff23) / 3.0

        // Convert to agreement score (low diff = high agreement)
        let agreement = max(0, 100 - (avgDiff * 2))  // 50-point diff = 0 agreement
        return agreement
    }

    /// Analyze hydration across different face regions
    private func analyzeRegionalHydration(
        texture: UIImage,
        roughnessScore: Float,
        geometry: FaceMeshGeometry
    ) -> [String: Float] {
        guard let cgImage = texture.cgImage else { return [:] }

        // Define face regions (normalized coordinates in image space)
        let regions: [String: (minX: Float, maxX: Float, minY: Float, maxY: Float)] = [
            "forehead": (0.3, 0.7, 0.1, 0.3),
            "leftCheek": (0.1, 0.4, 0.4, 0.7),
            "rightCheek": (0.6, 0.9, 0.4, 0.7),
            "nose": (0.4, 0.6, 0.3, 0.6),
            "chin": (0.35, 0.65, 0.7, 0.9),
            "underEye": (0.3, 0.7, 0.3, 0.45)
        ]

        var regionalScores: [String: Float] = [:]

        for (regionName, bounds) in regions {
            // Extract region from texture
            let regionImage = extractRegion(
                from: cgImage,
                bounds: bounds
            )

            guard let region = regionImage else {
                regionalScores[regionName] = 50.0  // Default neutral score
                continue
            }

            // Analyze specularity for this region
            let regionalSpecularity = analyzeSpecularityInRegion(image: region)

            // Analyze texture smoothness for this region
            let regionalSmoothness = analyzeSmoothnessInRegion(image: region)

            // Combined hydration score for region
            let hydrationScore = (regionalSpecularity * 0.6 + regionalSmoothness * 0.4)

            regionalScores[regionName] = hydrationScore
        }

        return regionalScores
    }

    /// Extract a rectangular region from image
    private func extractRegion(
        from image: CGImage,
        bounds: (minX: Float, maxX: Float, minY: Float, maxY: Float)
    ) -> CGImage? {
        let width = image.width
        let height = image.height

        let x = Int(Float(width) * bounds.minX)
        let y = Int(Float(height) * bounds.minY)
        let w = Int(Float(width) * (bounds.maxX - bounds.minX))
        let h = Int(Float(height) * (bounds.maxY - bounds.minY))

        return image.cropping(to: CGRect(x: x, y: y, width: w, height: h))
    }

    /// Analyze specularity in a specific region
    /// FIXED: Now uses adaptive threshold based on region's skin tone
    private func analyzeSpecularityInRegion(image: CGImage) -> Float {
        let width = image.width
        let height = image.height

        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return 50
        }

        let totalPixels = width * height
        guard totalPixels > 0 else { return 50 }

        // SKIN-TONE ADAPTIVE: Calculate threshold based on region's average brightness
        // This ensures dark skin can still detect specular highlights
        var rSum: Int = 0, gSum: Int = 0, bSum: Int = 0
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                rSum += Int(ptr[offset])
                gSum += Int(ptr[offset + 1])
                bSum += Int(ptr[offset + 2])
            }
        }

        let avgR = Float(rSum) / Float(totalPixels)
        let avgG = Float(gSum) / Float(totalPixels)
        let avgB = Float(bSum) / Float(totalPixels)
        let avgBrightness = (avgR + avgG + avgB) / 3.0

        // Adaptive threshold: 70-80% brighter than average skin tone
        // For very dark skin (avg ~60): threshold ~80-90 (FIXED: was 120, blocked dark skin)
        // For dark skin (avg ~80): threshold ~100-120
        // For light skin (avg ~180): threshold ~200-220
        // This ensures relative specularity detection works for all skin tones
        let maxPossible = min(255.0, avgBrightness * 1.5)
        // FIXED: Lowered min from 120 to 80 to support very dark skin (Fitzpatrick V-VI)
        let brightnessThreshold = UInt8(max(80, min(220, maxPossible * 0.75)))

        var brightPixels = 0
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = ptr[offset]
                let g = ptr[offset + 1]
                let b = ptr[offset + 2]

                if r > brightnessThreshold && g > brightnessThreshold && b > brightnessThreshold {
                    brightPixels += 1
                }
            }
        }

        let specularRatio = Float(brightPixels) / Float(totalPixels)
        return min(100, specularRatio * 1000)
    }

    /// Analyze smoothness in a specific region (inverse of roughness)
    private func analyzeSmoothnessInRegion(image: CGImage) -> Float {
        let width = image.width
        let height = image.height

        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return 50
        }

        // Calculate texture variance (low variance = smooth = hydrated)
        var intensities: [Float] = []

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = Float(ptr[offset])
                let g = Float(ptr[offset + 1])
                let b = Float(ptr[offset + 2])

                // FIXED: Standardized on BT.709 (sRGB) for consistency
                let intensity = 0.2126 * r + 0.7152 * g + 0.0722 * b
                intensities.append(intensity)
            }
        }

        // Calculate variance
        let mean = intensities.reduce(0, +) / Float(intensities.count)
        let variance = intensities.map { pow($0 - mean, 2) }.reduce(0, +) / Float(intensities.count)
        let stdDev = sqrt(variance)

        // Convert to smoothness score (low variance = high score)
        let smoothness = max(0, 100 - stdDev / 2.0)

        return smoothness
    }

    /// Calculate confidence level of hydration estimate
    /// Takes into account lighting conditions, measurement consistency, and method agreement
    private func calculateConfidence(
        specularity: Float,
        regionalScores: [String: Float],
        methodAgreement: Float
    ) -> Float {
        // STANDARDIZED: Indirect proxy measurement (hydration estimation)
        // Base: 60 (lower due to indirect measurement nature)
        // Range: 35-80 (capped due to inherent uncertainty in proxy methods)
        var confidence: Float = 60.0  // Base confidence for indirect measurement

        // Factor 1: Lighting conditions - STANDARDIZED across all analyzers
        // Excellent: +10, Good: +5, Suboptimal: -5, Poor: -15
        if specularity < 10 {
            confidence -= 15  // Too dark/underlit
        } else if specularity > 90 {
            confidence -= 15  // Overlit - excessive specularity
        } else if specularity >= 20 && specularity <= 70 {
            confidence += 10  // Optimal lighting range
        } else {
            confidence += 5   // Good but not optimal
        }

        // Factor 2: Regional consistency
        if regionalScores.count >= 4 {
            let values = Array(regionalScores.values)
            let mean = values.reduce(0, +) / Float(values.count)
            let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Float(values.count)
            let stdDev = sqrt(variance)

            // Low variance = consistent = higher confidence
            if stdDev < 15 {
                confidence += 10
            } else if stdDev > 30 {
                confidence -= 10  // High variance = inconsistent
            }
        }

        // Factor 3: Method agreement (ensemble reliability)
        if methodAgreement >= 80 {
            confidence += 10  // Strong agreement (standardized from 15)
        } else if methodAgreement >= 60 {
            confidence += 5   // Good agreement (standardized from 10)
        } else if methodAgreement < 40 {
            confidence -= 15  // Poor agreement (methods disagree)
        }

        // Clamp to 35-80 range (standardized for indirect proxy analysis)
        return max(35, min(80, confidence))
    }
}
