//
//  GlowAnalyzer.swift
//  Ollvy
//
//  Differentiated glow (overall health) vs radiance (pure luminosity) analysis
//  Created on 2025-10-29.
//
//  NOTE: GlowAnalysis struct is defined in Face3DMetrics.swift
//

import UIKit
import Accelerate
import simd
import Metal

/// Analyzes skin glow (overall health) and radiance (pure luminosity)
public class GlowAnalyzer {

    // MARK: - GPU Infrastructure

    /// Metal analyzer for GPU acceleration
    private let metalAnalyzer: MetalAnalyzerBase?

    /// Whether GPU acceleration is available
    private var isGPUAvailable: Bool {
        return metalAnalyzer != nil
    }

    // MARK: - Performance Optimization

    /// Maximum texture size for analysis (1024x1024 provides good balance of accuracy and performance)
    private let maxAnalysisSize: Int = 1024

    // MARK: - Initialization

    public init() {
        // Initialize Metal GPU infrastructure
        do {
            self.metalAnalyzer = try MetalAnalyzerBase()
            AppLogger.metrics.info("✅ GlowAnalyzer: GPU acceleration enabled")
        } catch {
            self.metalAnalyzer = nil
            AppLogger.metrics.warning("⚠️ GlowAnalyzer: GPU unavailable, using CPU fallback - \(error.localizedDescription)")
        }
    }

    /// Downsample image to max size for efficient processing
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

    // MARK: - GPU Data Structures

    /// Partial results from GPU threadgroup (matches Metal structure)
    private struct GlowPartialResults {
        var lightnessSum: Float        // Sum of L* values (0-100 range)
        var specularPixelCount: Float  // Count of bright specular pixels
        var uniformitySum: Float       // Sum of local uniformity values
        var validPixelCount: Float     // Total pixels processed
    }

    // MARK: - Configuration

    private struct Configuration {
        // Glow formula weights - HIGH CONFIDENCE METRICS ONLY
        // EXCLUDES: Firmness/Wrinkles and Oil Control (age-related, low confidence)
        static let smoothnessWeight: Float = 0.25      // Texture smoothness
        static let evennessWeight: Float = 0.20        // Skin tone evenness
        static let radianceWeight: Float = 0.20        // Luminosity/glow
        static let clarityWeight: Float = 0.15         // Uniformity score (higher = more uniform skin)
        static let rednessWeight: Float = 0.10         // Redness score (higher = less inflammation)
        static let acneWeight: Float = 0.10            // Acne score

        // Radiance formula weights
        static let labLightnessWeight: Float = 0.70
        static let specularHighlightWeight: Float = 0.30

        // Specular detection - RELATIVE threshold (multiplier over baseline)
        // Base multiplier - actual value is skin-tone-adaptive (see specularMultiplier function)
        static let specularRelativeMultiplierBase: Float = 1.25
        static let specularMaxThreshold: Float = 0.95  // Never exceed this
    }

    /// Skin tone normalizer for adaptive thresholds
    private let skinToneNormalizer = SkinToneNormalizer()

    // MARK: - Input Validation

    /// Validate and clamp input metric to prevent cascading NaN/Inf failures
    /// Returns a safe value within expectedRange, logging warnings for outliers
    private func validateAndClamp(_ value: Float, name: String, expectedRange: ClosedRange<Float> = 0...100) -> Float {
        // Handle NaN/Inf
        if value.isNaN || value.isInfinite {
            AppLogger.metrics.error("❌ Glow input '\(name)' is NaN/Inf - using 50")
            return 50.0
        }

        // Handle out-of-range values
        if value < expectedRange.lowerBound || value > expectedRange.upperBound {
            let clamped = min(max(value, expectedRange.lowerBound), expectedRange.upperBound)
            AppLogger.metrics.warning("⚠️ Glow input '\(name)'=\(String(format: "%.1f", value)) outside \(expectedRange) - clamped to \(String(format: "%.1f", clamped))")
            return clamped
        }

        return value
    }

    /// Get specular multiplier based on skin tone
    /// Lighter skin has more visible specular highlights, needs higher threshold
    private func specularMultiplier(for skinTone: SkinToneCategory) -> Float {
        let multiplier: Float

        switch skinTone {
        case .veryLight, .light:
            multiplier = 1.35  // Higher threshold - more natural shine visible
        case .medium:
            multiplier = 1.30
        case .mediumDark:
            multiplier = 1.25  // Original calibration (Indian skin)
        case .dark, .veryDark:
            multiplier = 1.20  // Lower threshold - harder to detect shine
        }

        AppLogger.metrics.debug("✨ Specular multiplier for \(skinTone.rawValue): \(String(format: "%.2f", multiplier))")
        return multiplier
    }

    // MARK: - Public API

    /// Analyze glow and radiance from texture and existing metrics
    public func analyzeGlow(
        texture: UIImage,
        geometry: FaceMeshGeometry,
        existingMetrics: Face3DMetrics,
        specularAnalyzer: SpecularAnalyzer
    ) -> GlowAnalysis {

        AppLogger.metrics.info("✨ Analyzing skin glow and radiance...")

        // GPU PATH: Use full resolution texture for GPU-accelerated analysis
        // CPU FALLBACK: Downsampled texture created only when needed
        let analysisTexture: UIImage
        if isGPUAvailable {
            // GPU path: use full resolution for maximum accuracy
            analysisTexture = texture
            if let cgImage = texture.cgImage {
                AppLogger.metrics.info("   🎨 Using GPU acceleration (full resolution: \(cgImage.width)x\(cgImage.height))")
            }
        } else {
            // CPU fallback: downsample for performance
            if let cgImage = texture.cgImage, let downsampled = downsample(cgImage) {
                analysisTexture = UIImage(cgImage: downsampled)
                AppLogger.metrics.info("   💻 Using CPU analysis (downsampled: \(cgImage.width)x\(cgImage.height) → \(downsampled.width)x\(downsampled.height))")
            } else {
                analysisTexture = texture
            }
        }

        // PART 1: SKIN HEALTH SCORE (Overall Health Index)
        // ONLY HIGH-CONFIDENCE METRICS - NO AGE-RELATED FEATURES

        // VALIDATION: Sanity check input metrics to prevent cascade failures
        // If any input is NaN/Inf or out-of-range, clamp to safe value
        let smoothness = validateAndClamp(existingMetrics.globalRoughnessScore, name: "smoothness")
        let evenness = validateAndClamp(existingMetrics.globalPigmentationScore, name: "evenness")
        // FIXED: globalDiscolorationScore already returns higher = better (more uniform skin)
        // No inversion needed - uniform skin (80) should contribute 80, not 20
        let clarity = validateAndClamp(existingMetrics.globalDiscolorationScore, name: "clarity")

        // Get additional HIGH-CONFIDENCE metrics
        // FIXED: rednessAnalysis.overallScore already returns higher = better (less inflammation)
        // No inversion needed - healthy skin (95) should contribute 95, not 5
        let redness = validateAndClamp(existingMetrics.rednessAnalysis?.overallScore ?? 50.0, name: "redness")
        let acne = validateAndClamp(existingMetrics.acneAnalysis?.overallScore ?? 80.0, name: "acne")

        AppLogger.metrics.info("   Glow inputs validated: smoothness=\(String(format: "%.1f", smoothness)), evenness=\(String(format: "%.1f", evenness)), clarity=\(String(format: "%.1f", clarity))")

        // Get radiance from LAB analysis
        let radiancePreview = analyzeLABLightness(texture: analysisTexture) * 100.0

        // Compute skin health score with HIGH-CONFIDENCE metrics ONLY
        // EXCLUDED: Firmness/Wrinkles (age-related) and Oil Control (low confidence)
        let skinHealthScore = (
            smoothness * Configuration.smoothnessWeight +
            evenness * Configuration.evennessWeight +
            radiancePreview * Configuration.radianceWeight +
            clarity * Configuration.clarityWeight +
            redness * Configuration.rednessWeight +
            acne * Configuration.acneWeight
        )

        AppLogger.metrics.info("   Skin Analysis Score (High-Confidence Metrics Only): \(String(format: "%.1f", skinHealthScore))/100")
        AppLogger.metrics.info("     - Smoothness (25%): \(String(format: "%.1f", smoothness)) → \(String(format: "%.1f", smoothness * Configuration.smoothnessWeight))")
        AppLogger.metrics.info("     - Evenness (20%): \(String(format: "%.1f", evenness)) → \(String(format: "%.1f", evenness * Configuration.evennessWeight))")
        AppLogger.metrics.info("     - Radiance (20%): \(String(format: "%.1f", radiancePreview)) → \(String(format: "%.1f", radiancePreview * Configuration.radianceWeight))")
        AppLogger.metrics.info("     - Clarity (15%): \(String(format: "%.1f", clarity)) → \(String(format: "%.1f", clarity * Configuration.clarityWeight))")
        AppLogger.metrics.info("     - Redness Control (10%): \(String(format: "%.1f", redness)) → \(String(format: "%.1f", redness * Configuration.rednessWeight))")
        AppLogger.metrics.info("     - Acne (10%): \(String(format: "%.1f", acne)) → \(String(format: "%.1f", acne * Configuration.acneWeight))")
        AppLogger.metrics.info("     ⚠️ EXCLUDED: Firmness/Wrinkles & Oil Control (age-related/low confidence)")

        // PART 2: RADIANCE SCORE (Pure Luminosity)
        // Physics-based brightness measurement using LAB color space

        let labLightness = analyzeLABLightness(texture: analysisTexture)
        let specularRatio = analyzeSpecularHighlights(texture: analysisTexture)
        let luminosityIndex = (labLightness * 100.0)  // Convert L* (0-1) to 0-100 scale

        // Compute radiance score (pure brightness)
        // FIX: Scale labLightness and specularRatio to 0-100 BEFORE applying weights
        // Old formula: (0.5 * 0.70 + 0.3 * 0.30) * 100 = 44 max (capped!)
        // New formula: (50 * 0.70 + 30 * 0.30) = 44 (correct weighted average)
        let radianceScore = (
            (labLightness * 100.0) * Configuration.labLightnessWeight +
            (specularRatio * 100.0) * Configuration.specularHighlightWeight
        )  // Already 0-100 scale after weighted sum

        AppLogger.metrics.info("   Radiance Score (Luminosity): \(String(format: "%.1f", radianceScore))/100")
        AppLogger.metrics.info("     - LAB L* lightness: \(String(format: "%.1f", labLightness * 100))%")
        AppLogger.metrics.info("     - Specular highlights: \(String(format: "%.1f", specularRatio * 100))%")

        // PART 3: Regional Analysis

        let regionalGlow = computeRegionalGlow(
            existingMetrics: existingMetrics
        )

        let regionalRadiance = computeRegionalRadiance(
            texture: analysisTexture,
            geometry: geometry
        )

        // PART 4: Confidence

        let confidence = computeConfidence(
            textureQuality: existingMetrics.textureQuality,
            labLightness: labLightness,
            specularRatio: specularRatio
        )

        AppLogger.metrics.info("✅ Glow and radiance analysis complete (confidence: \(String(format: "%.0f", confidence))%)")

        return GlowAnalysis(
            skinHealthScore: skinHealthScore,
            radianceScore: radianceScore,
            smoothnessContribution: smoothness * Configuration.smoothnessWeight,
            evennessContribution: evenness * Configuration.evennessWeight,
            discolorationContribution: clarity * Configuration.clarityWeight,
            specularContribution: specularRatio * Configuration.specularHighlightWeight,
            labLightness: labLightness,
            specularHighlightRatio: specularRatio,
            luminosityIndex: luminosityIndex,
            regionalGlow: regionalGlow,
            regionalRadiance: regionalRadiance,
            confidence: confidence
        )
    }

    // MARK: - LAB Lightness Analysis (Physics-Based)

    /// Analyze LAB color space L* channel (lightness) with GPU acceleration
    /// This is a perceptually uniform measure of brightness
    private func analyzeLABLightness(texture: UIImage) -> Float {
        // Try GPU path first
        if isGPUAvailable {
            if let result = try? analyzeLABLightnessGPU(texture: texture) {
                return result
            }
            AppLogger.metrics.warning("⚠️ GPU LAB analysis failed, falling back to CPU")
        }

        // CPU fallback
        return analyzeLABLightnessCPU(texture: texture)
    }

    /// GPU-accelerated LAB lightness analysis
    private func analyzeLABLightnessGPU(texture: UIImage) throws -> Float {
        guard let analyzer = metalAnalyzer else {
            throw GPUAnalysisError.invalidInput("Metal analyzer not available")
        }

        // Convert to Metal texture
        guard let metalTexture = MetalHelpers.textureFromUIImage(texture, device: analyzer.device) else {
            throw GPUAnalysisError.textureCreationFailed("Failed to convert UIImage to Metal texture")
        }

        let width = metalTexture.width
        let height = metalTexture.height

        // Load pipeline
        let baselinePipeline = try analyzer.loadPipeline(named: "calculateBaselineBrightness")
        let analysisPipeline = try analyzer.loadPipeline(named: "analyzeGlow")

        // CRITICAL FIX: Use exactly 16x16 = 256 threads per threadgroup
        // The Metal shader's threadgroup shared memory arrays are sized for 256 threads
        // Using different sizes causes out-of-bounds access and zero results
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (width + 15) / 16,
            height: (height + 15) / 16,
            depth: 1
        )

        let threadgroupsPerRow = threadgroups.width
        let numThreadgroups = threadgroups.width * threadgroups.height

        // Log threadgroup configuration for debugging
        AppLogger.metrics.debug("🔧 GPU Threadgroups: \(threadgroups.width)x\(threadgroups.height) = \(numThreadgroups), threads/group: 16x16=256")

        // STEP 1: Calculate baseline brightness with partial results
        let partialBrightnessBuffer = try analyzer.createBuffer(length: numThreadgroups * MemoryLayout<Float>.stride)
        let partialCountsBuffer = try analyzer.createBuffer(length: numThreadgroups * MemoryLayout<Float>.stride)

        // CRITICAL FIX: Zero-initialize buffers to prevent garbage data
        // Metal buffers may contain garbage values which corrupt results
        memset(partialBrightnessBuffer.contents(), 0, numThreadgroups * MemoryLayout<Float>.stride)
        memset(partialCountsBuffer.contents(), 0, numThreadgroups * MemoryLayout<Float>.stride)

        // Create buffer for threadgroupsPerRow parameter
        var threadgroupsPerRowValueBaseline = UInt32(threadgroupsPerRow)
        let threadgroupsPerRowBufferBaseline = try analyzer.createBuffer(length: MemoryLayout<UInt32>.stride)
        memcpy(threadgroupsPerRowBufferBaseline.contents(), &threadgroupsPerRowValueBaseline, MemoryLayout<UInt32>.stride)

        try analyzer.executeSync(operation: "calculateBaselineBrightness") { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw GPUAnalysisError.commandBufferFailed("Failed to create compute encoder")
            }

            encoder.setComputePipelineState(baselinePipeline)
            encoder.setTexture(metalTexture, index: 0)
            encoder.setBuffer(partialBrightnessBuffer, offset: 0, index: 0)
            encoder.setBuffer(partialCountsBuffer, offset: 0, index: 1)
            encoder.setBuffer(threadgroupsPerRowBufferBaseline, offset: 0, index: 2)

            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
        }

        // Aggregate partial results on CPU
        let partialBrightnessPtr = partialBrightnessBuffer.contents().assumingMemoryBound(to: Float.self)
        let partialCountsPtr = partialCountsBuffer.contents().assumingMemoryBound(to: Float.self)

        var totalBrightness: Float = 0
        var totalCount: Float = 0

        for i in 0..<numThreadgroups {
            totalBrightness += partialBrightnessPtr[i]
            totalCount += partialCountsPtr[i]
        }

        // Calculate average baseline brightness
        let baselineBrightness = totalCount > 0 ? totalBrightness / totalCount : 0.5

        // STEP 2: Analyze glow metrics
        let resultsBufferSize = numThreadgroups * MemoryLayout<GlowPartialResults>.stride
        let resultsBuffer = try analyzer.createBuffer(length: resultsBufferSize)

        // CRITICAL FIX: Zero-initialize results buffer
        memset(resultsBuffer.contents(), 0, resultsBufferSize)

        // Create buffer for threadgroupsPerRow parameter
        var threadgroupsPerRowValue = UInt32(threadgroupsPerRow)
        let threadgroupsPerRowBuffer = try analyzer.createBuffer(length: MemoryLayout<UInt32>.stride)
        memcpy(threadgroupsPerRowBuffer.contents(), &threadgroupsPerRowValue, MemoryLayout<UInt32>.stride)

        // Create buffer for baseline brightness
        var baselineValue = baselineBrightness
        let baselineParamBuffer = try analyzer.createBuffer(length: MemoryLayout<Float>.stride)
        memcpy(baselineParamBuffer.contents(), &baselineValue, MemoryLayout<Float>.stride)

        try analyzer.executeSync(operation: "analyzeGlow") { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw GPUAnalysisError.commandBufferFailed("Failed to create compute encoder")
            }

            encoder.setComputePipelineState(analysisPipeline)
            encoder.setTexture(metalTexture, index: 0)
            encoder.setBuffer(resultsBuffer, offset: 0, index: 0)
            encoder.setBuffer(baselineParamBuffer, offset: 0, index: 1)
            encoder.setBuffer(threadgroupsPerRowBuffer, offset: 0, index: 2)

            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
        }

        // Read and aggregate results
        let resultsPtr = resultsBuffer.contents().assumingMemoryBound(to: GlowPartialResults.self)

        var totalLightness: Float = 0
        var totalValidPixels: Float = 0

        for i in 0..<numThreadgroups {
            let result = resultsPtr[i]
            totalLightness += result.lightnessSum
            totalValidPixels += result.validPixelCount
        }

        // Calculate raw average L* (should be 0-100 range)
        let rawAverageLStar = totalValidPixels > 0 ? totalLightness / totalValidPixels : 0

        // DIAGNOSTIC: Log GPU results for debugging LAB L* issue
        let expectedMinPixels = Float(width * height) * 0.01  // At least 1% of pixels should be valid
        AppLogger.metrics.debug("🔍 LAB GPU Debug: totalLightness=\(String(format: "%.2f", totalLightness)), pixels=\(String(format: "%.0f", totalValidPixels)) (min expected: \(String(format: "%.0f", expectedMinPixels))), rawL*=\(String(format: "%.2f", rawAverageLStar))")

        // VALIDATION: Check that we processed a reasonable number of pixels
        // A 2048x2048 texture should have ~4M pixels; even with black background, expect at least 1%
        if totalValidPixels < expectedMinPixels {
            AppLogger.metrics.warning("⚠️ GPU LAB analysis only processed \(Int(totalValidPixels)) pixels (expected at least \(Int(expectedMinPixels))), falling back to CPU")
            throw GPUAnalysisError.invalidInput("GPU processed too few pixels (\(Int(totalValidPixels))), likely texture issue")
        }

        // VALIDATION: L* should be 0-100, skin is typically 45-75
        // If we get suspiciously low values, the GPU texture may be corrupted
        if rawAverageLStar < 10 {
            AppLogger.metrics.warning("⚠️ LAB L* suspiciously low (\(String(format: "%.2f", rawAverageLStar))), falling back to CPU")
            throw GPUAnalysisError.invalidInput("GPU LAB L* too low (\(rawAverageLStar)), likely texture issue")
        }

        // Normalize L* from 0-100 to 0-1 range
        let averageLightness = rawAverageLStar / 100.0

        return max(0, min(1, averageLightness))
    }

    /// Convert sRGB value to linear RGB (inverse gamma correction)
    /// sRGB uses a piecewise gamma curve for perceptual uniformity
    private func srgbToLinear(_ c: Float) -> Float {
        if c <= 0.04045 {
            return c / 12.92
        } else {
            return pow((c + 0.055) / 1.055, 2.4)
        }
    }

    /// CPU fallback for LAB lightness analysis
    private func analyzeLABLightnessCPU(texture: UIImage) -> Float {
        guard let cgImage = texture.cgImage else { return 0.5 }

        let width = cgImage.width
        let height = cgImage.height

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return 0.5
        }

        var totalLightness: Float = 0
        var pixelCount = 0

        // Sample pixels for LAB conversion
        for y in stride(from: 0, to: height, by: 4) {  // Sample every 4 pixels for performance
            for x in stride(from: 0, to: width, by: 4) {
                let offset = (y * width + x) * 4
                guard offset + 2 < CFDataGetLength(data) else { continue }

                let r = Float(ptr[offset]) / 255.0
                let g = Float(ptr[offset + 1]) / 255.0
                let b = Float(ptr[offset + 2]) / 255.0

                // FIXED: Proper RGB→XYZ→LAB conversion with gamma correction
                // Step 1: Apply inverse sRGB gamma to get linear RGB
                let rLinear = srgbToLinear(r)
                let gLinear = srgbToLinear(g)
                let bLinear = srgbToLinear(b)

                // Step 2: Convert linear RGB to XYZ Y component (luminance)
                // Using exact D65 matrix coefficients to match GPU (GlowAnalysis.metal:49)
                let y_xyz = Luminance.yLinearD65(rgbLinear: SIMD3<Float>(rLinear, gLinear, bLinear))

                // Step 3: Convert Y to L* using CIE standard formula
                // L* = 116 * f(Y/Yn) - 16, where Yn = 1.0 (D65 white point)
                // f(t) = t^(1/3) for t > 0.008856, else f(t) = 7.787*t + 16/116
                let lStar: Float
                if y_xyz > 0.008856 {
                    lStar = 116.0 * pow(y_xyz, 1.0/3.0) - 16.0
                } else {
                    lStar = 903.3 * y_xyz  // Equivalent to 116 * (7.787*y + 16/116) - 16
                }

                // L* is in range 0-100, normalize to 0-1
                totalLightness += lStar / 100.0
                pixelCount += 1
            }
        }

        let averageLightness = pixelCount > 0 ? totalLightness / Float(pixelCount) : 0.5

        // DIAGNOSTIC: Log CPU results for comparison with GPU
        AppLogger.metrics.debug("🔍 LAB CPU Debug: totalL*=\(totalLightness * 100), pixels=\(pixelCount), avgL*=\(averageLightness * 100)%")

        // Clamp to 0-1 range
        return max(0, min(1, averageLightness))
    }

    // MARK: - Specular Highlight Analysis

    /// Detect bright specular highlights (shiny spots) with GPU acceleration
    /// FIXED: Now uses RELATIVE threshold based on baseline skin brightness
    /// Works correctly for Indian skin (Fitzpatrick III-IV) with brightness 0.45-0.65
    private func analyzeSpecularHighlights(texture: UIImage) -> Float {
        // Try GPU path first
        if isGPUAvailable {
            if let result = try? analyzeSpecularHighlightsGPU(texture: texture) {
                return result
            }
            AppLogger.metrics.warning("⚠️ GPU specular analysis failed, falling back to CPU")
        }

        // CPU fallback
        return analyzeSpecularHighlightsCPU(texture: texture)
    }

    /// GPU-accelerated specular highlight analysis
    /// Reuses the glow analysis kernel which computes both LAB lightness and specular count
    private func analyzeSpecularHighlightsGPU(texture: UIImage) throws -> Float {
        guard let analyzer = metalAnalyzer else {
            throw GPUAnalysisError.invalidInput("Metal analyzer not available")
        }

        // Convert to Metal texture
        guard let metalTexture = MetalHelpers.textureFromUIImage(texture, device: analyzer.device) else {
            throw GPUAnalysisError.textureCreationFailed("Failed to convert UIImage to Metal texture")
        }

        let width = metalTexture.width
        let height = metalTexture.height

        // Load pipelines
        let baselinePipeline = try analyzer.loadPipeline(named: "calculateBaselineBrightness")
        let analysisPipeline = try analyzer.loadPipeline(named: "analyzeGlow")

        // CRITICAL FIX: Use exactly 16x16 = 256 threads per threadgroup
        // The Metal shader's threadgroup shared memory arrays are sized for 256 threads
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (width + 15) / 16,
            height: (height + 15) / 16,
            depth: 1
        )

        let threadgroupsPerRow = threadgroups.width
        let numThreadgroups = threadgroups.width * threadgroups.height

        // STEP 1: Calculate baseline brightness with partial results
        let partialBrightnessBuffer = try analyzer.createBuffer(length: numThreadgroups * MemoryLayout<Float>.stride)
        let partialCountsBuffer = try analyzer.createBuffer(length: numThreadgroups * MemoryLayout<Float>.stride)

        // CRITICAL FIX: Zero-initialize buffers
        memset(partialBrightnessBuffer.contents(), 0, numThreadgroups * MemoryLayout<Float>.stride)
        memset(partialCountsBuffer.contents(), 0, numThreadgroups * MemoryLayout<Float>.stride)

        // Create buffer for threadgroupsPerRow parameter
        var threadgroupsPerRowValueBaseline = UInt32(threadgroupsPerRow)
        let threadgroupsPerRowBufferBaseline = try analyzer.createBuffer(length: MemoryLayout<UInt32>.stride)
        memcpy(threadgroupsPerRowBufferBaseline.contents(), &threadgroupsPerRowValueBaseline, MemoryLayout<UInt32>.stride)

        try analyzer.executeSync(operation: "calculateBaselineBrightness") { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw GPUAnalysisError.commandBufferFailed("Failed to create compute encoder")
            }

            encoder.setComputePipelineState(baselinePipeline)
            encoder.setTexture(metalTexture, index: 0)
            encoder.setBuffer(partialBrightnessBuffer, offset: 0, index: 0)
            encoder.setBuffer(partialCountsBuffer, offset: 0, index: 1)
            encoder.setBuffer(threadgroupsPerRowBufferBaseline, offset: 0, index: 2)

            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
        }

        // Aggregate partial results on CPU
        let partialBrightnessPtr = partialBrightnessBuffer.contents().assumingMemoryBound(to: Float.self)
        let partialCountsPtr = partialCountsBuffer.contents().assumingMemoryBound(to: Float.self)

        var totalBrightness: Float = 0
        var totalCount: Float = 0

        for i in 0..<numThreadgroups {
            totalBrightness += partialBrightnessPtr[i]
            totalCount += partialCountsPtr[i]
        }

        // Calculate average baseline brightness
        let baselineBrightness = totalCount > 0 ? totalBrightness / totalCount : 0.5

        // STEP 2: Analyze glow metrics (includes specular count)
        let resultsBufferSize = numThreadgroups * MemoryLayout<GlowPartialResults>.stride
        let resultsBuffer = try analyzer.createBuffer(length: resultsBufferSize)

        // CRITICAL FIX: Zero-initialize results buffer
        memset(resultsBuffer.contents(), 0, resultsBufferSize)

        // Create buffer for threadgroupsPerRow parameter
        var threadgroupsPerRowValue = UInt32(threadgroupsPerRow)
        let threadgroupsPerRowBuffer = try analyzer.createBuffer(length: MemoryLayout<UInt32>.stride)
        memcpy(threadgroupsPerRowBuffer.contents(), &threadgroupsPerRowValue, MemoryLayout<UInt32>.stride)

        // Create buffer for baseline brightness
        var baselineValue = baselineBrightness
        let baselineParamBuffer = try analyzer.createBuffer(length: MemoryLayout<Float>.stride)
        memcpy(baselineParamBuffer.contents(), &baselineValue, MemoryLayout<Float>.stride)

        try analyzer.executeSync(operation: "analyzeGlow") { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw GPUAnalysisError.commandBufferFailed("Failed to create compute encoder")
            }

            encoder.setComputePipelineState(analysisPipeline)
            encoder.setTexture(metalTexture, index: 0)
            encoder.setBuffer(resultsBuffer, offset: 0, index: 0)
            encoder.setBuffer(baselineParamBuffer, offset: 0, index: 1)
            encoder.setBuffer(threadgroupsPerRowBuffer, offset: 0, index: 2)

            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
        }

        // Read and aggregate results
        let resultsPtr = resultsBuffer.contents().assumingMemoryBound(to: GlowPartialResults.self)

        var totalSpecularPixels: Float = 0
        var totalValidPixels: Float = 0

        for i in 0..<numThreadgroups {
            let result = resultsPtr[i]
            totalSpecularPixels += result.specularPixelCount
            totalValidPixels += result.validPixelCount
        }

        // VALIDATION: Check we processed enough pixels
        let expectedMinPixels = Float(width * height) * 0.01
        if totalValidPixels < expectedMinPixels {
            AppLogger.metrics.debug("🔍 Specular GPU: only \(Int(totalValidPixels)) pixels, expected \(Int(expectedMinPixels))")
            throw GPUAnalysisError.invalidInput("GPU specular processed too few pixels")
        }

        // Calculate specular ratio and normalize
        let specularRatio = totalValidPixels > 0 ? totalSpecularPixels / totalValidPixels : 0.0

        // Clamp to reasonable range (0-0.3, most skin has <30% specular)
        return min(0.3, specularRatio) / 0.3  // Normalize to 0-1
    }

    /// CPU fallback for specular highlight analysis
    /// IMPROVED: Uses skin-tone-adaptive specular multiplier
    private func analyzeSpecularHighlightsCPU(texture: UIImage) -> Float {
        guard let cgImage = texture.cgImage else { return 0 }

        let width = cgImage.width
        let height = cgImage.height

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return 0
        }

        let totalPixels = width * height

        // STEP 1: Calculate baseline skin brightness from center region
        let baselineBrightness = calculateBaselineBrightness(ptr: ptr, width: width, height: height, dataLength: CFDataGetLength(data))

        // STEP 2: Detect skin tone for adaptive specular threshold
        let skinTone = skinToneNormalizer.detectSkinTone(texture: texture)
        let adaptiveMultiplier = specularMultiplier(for: skinTone)

        // STEP 3: Calculate RELATIVE specular threshold (skin-tone-aware)
        // Specular highlights are brighter than baseline skin by adaptive multiplier
        let specularThreshold = min(
            Configuration.specularMaxThreshold,
            baselineBrightness * adaptiveMultiplier
        )

        // STEP 3: Count pixels above relative threshold
        var brightPixelCount = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                guard offset + 2 < CFDataGetLength(data) else { continue }

                let r = Float(ptr[offset]) / 255.0
                let g = Float(ptr[offset + 1]) / 255.0
                let b = Float(ptr[offset + 2]) / 255.0

                let brightness = (r + g + b) / 3.0

                if brightness > specularThreshold {
                    brightPixelCount += 1
                }
            }
        }

        let specularRatio = Float(brightPixelCount) / Float(totalPixels)

        // Clamp to reasonable range (0-0.3, most skin has <30% specular)
        return min(0.3, specularRatio) / 0.3  // Normalize to 0-1
    }

    /// Calculate baseline skin brightness from center region
    /// Used for relative specular threshold calculation
    private func calculateBaselineBrightness(ptr: UnsafePointer<UInt8>, width: Int, height: Int, dataLength: Int) -> Float {
        let centerX = width / 2
        let centerY = height / 2
        let sampleRadius = min(width, height) / 4

        var totalBrightness: Float = 0
        var count = 0

        for y in max(0, centerY - sampleRadius)..<min(height, centerY + sampleRadius) {
            for x in max(0, centerX - sampleRadius)..<min(width, centerX + sampleRadius) {
                let offset = (y * width + x) * 4
                guard offset + 2 < dataLength else { continue }

                let r = Float(ptr[offset]) / 255.0
                let g = Float(ptr[offset + 1]) / 255.0
                let b = Float(ptr[offset + 2]) / 255.0

                totalBrightness += (r + g + b) / 3.0
                count += 1
            }
        }

        // Default to 0.5 if sampling fails (neutral)
        return count > 0 ? totalBrightness / Float(count) : 0.5
    }

    // MARK: - Regional Analysis

    /// Compute glow score per face region
    private func computeRegionalGlow(existingMetrics: Face3DMetrics) -> [Face3DROI: Float] {
        var regionalGlow: [Face3DROI: Float] = [:]

        for (roi, metrics) in existingMetrics.roiMetrics {
            // Apply same glow formula per region
            let smoothness = Float(metrics.roughnessScore)
            let evenness = Float(100.0 - metrics.pigmentationIndex * 100.0)  // Invert index to score
            let specular = Float(100.0 - (metrics.moistureProxy.specularRatio * 100.0))  // Lower specular = better

            // Simplified formula for regional (no discoloration per region)
            let regionalScore = (
                smoothness * 0.5 +
                evenness * 0.35 +
                specular * 0.15
            )

            regionalGlow[roi] = regionalScore
        }

        return regionalGlow
    }

    /// Compute radiance score per face region
    private func computeRegionalRadiance(
        texture: UIImage,
        geometry: FaceMeshGeometry
    ) -> [Face3DROI: Float] {
        var regionalRadiance: [Face3DROI: Float] = [:]

        // For each ROI, extract region and analyze brightness
        for roi in Face3DROI.allCases {
            // Extract region bounds from UV coordinates
            let uvBounds = roi.uvBounds

            // Extract texture region (simplified - full implementation would use UV mapping)
            if let regionBrightness = extractRegionBrightness(
                texture: texture,
                uvBounds: uvBounds
            ) {
                regionalRadiance[roi] = regionBrightness * 100.0  // Scale to 0-100
            } else {
                regionalRadiance[roi] = 50.0  // Default neutral
            }
        }

        return regionalRadiance
    }

    /// Extract average brightness from texture region
    private func extractRegionBrightness(
        texture: UIImage,
        uvBounds: UVBounds
    ) -> Float? {
        guard let cgImage = texture.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        // Convert UV bounds to pixel coordinates
        let minX = Int(Float(width) * uvBounds.minU)
        let maxX = Int(Float(width) * uvBounds.maxU)
        let minY = Int(Float(height) * uvBounds.minV)
        let maxY = Int(Float(height) * uvBounds.maxV)

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return nil
        }

        var totalBrightness: Float = 0
        var pixelCount = 0

        for y in minY..<maxY {
            for x in minX..<maxX {
                guard y >= 0, y < height, x >= 0, x < width else { continue }

                let offset = (y * width + x) * 4
                guard offset + 2 < CFDataGetLength(data) else { continue }

                let r = Float(ptr[offset]) / 255.0
                let g = Float(ptr[offset + 1]) / 255.0
                let b = Float(ptr[offset + 2]) / 255.0

                // Calculate luminance
                let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
                totalBrightness += luminance
                pixelCount += 1
            }
        }

        return pixelCount > 0 ? totalBrightness / Float(pixelCount) : nil
    }

    // MARK: - Confidence Calculation

    /// Calculate analysis confidence based on data quality
    /// STANDARDIZED: Uses consistent modifiers across all analyzers
    /// Base: 75 (direct texture measurement)
    /// Range: 45-95 (never 100% due to inherent limitations)
    private func computeConfidence(
        textureQuality: String?,
        labLightness: Float,
        specularRatio: Float
    ) -> Float {
        var confidence: Float = 75.0  // Base confidence for direct texture measurement

        // Factor 1: Texture quality (standardized modifiers)
        if textureQuality?.contains("warning") == true {
            confidence -= 15
        } else if textureQuality?.contains("Good") == true {
            confidence += 10
        }

        // Factor 2: Lighting conditions - STANDARDIZED across all analyzers
        // Excellent: +10, Good: +5, Suboptimal: -5, Poor: -15
        if labLightness < 0.2 {
            confidence -= 15  // Too dark
        } else if labLightness > 0.9 {
            confidence -= 15  // Too bright/overexposed
        } else if labLightness >= 0.4 && labLightness <= 0.7 {
            confidence += 10  // Optimal lighting range
        } else {
            confidence += 5   // Good but not optimal
        }

        // Factor 3: Specular consistency
        if specularRatio > 0.8 {
            confidence -= 10  // Too much specular (very oily or overlit)
        }

        // Clamp to 45-95 range (standardized for direct texture analysis)
        return max(45, min(95, confidence))
    }

    // MARK: - Fallback Computation

    /// Compute default specular score if not available
    private func computeDefaultSpecular(from texture: UIImage) -> Float {
        // Use simple specular detection as fallback
        let specularRatio = analyzeSpecularHighlights(texture: texture)

        // Convert ratio to score (lower specular = higher score for health)
        let specularScore = (1.0 - specularRatio) * 100.0

        return specularScore
    }
}
