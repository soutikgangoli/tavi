//
//  RednessAnalyzer.swift
//  Tavi
//
//  Inflammation and redness detection using red channel analysis
//  Detects overall redness, regional inflammation, and rosacea indicators
//

import UIKit
import Accelerate
import Metal

/// Redness analysis result
public struct RednessAnalysis: Codable, Sendable {
    let overallScore: Float  // 0-100, higher is better (less red)
    let rednessLevel: RednessLevel
    let globalRedness: Float  // 0-1, average redness index
    let regionalRedness: [String: Float]  // Per-region redness (0-1)
    let inflamedAreas: [InflammedRegion]
    let confidence: Float  // 0-100, measurement confidence
    let detectionMethod: String  // "redness" or "darkening" (for dark skin)
}

/// Individual inflamed region
public struct InflammedRegion: Codable, Sendable {
    let location: String
    let severity: Float  // 0-1
    let area: Float      // in pixels
}

public enum RednessLevel: String, Codable, Sendable, CustomStringConvertible {
    case minimal         // Very little redness
    case mild            // Some redness, normal
    case moderate        // Noticeable redness
    case severe          // Significant inflammation

    public var description: String {
        return rawValue
    }

    var score: Float {
        switch self {
        case .minimal: return 95
        case .mild: return 75
        case .moderate: return 50
        case .severe: return 25
        }
    }
}

/// Redness analyzer using red channel analysis
public class RednessAnalyzer {

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
                AppLogger.metrics.info("✅ RednessAnalyzer: GPU acceleration enabled")
            } catch {
                AppLogger.metrics.warning("⚠️ RednessAnalyzer: Failed to initialize Metal - falling back to CPU")
                self.metalAnalyzer = nil
                self.texturePool = nil
            }
        } else {
            AppLogger.metrics.info("ℹ️ RednessAnalyzer: Using CPU analysis (GPU not supported)")
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

    // MARK: - Configuration

    private let adaptiveMultiplier: Float = 1.5    // Multiplier for relative detection (skin-tone adaptive)
    private let skinToneNormalizer = SkinToneNormalizer()

    /// Get adaptive redness thresholds based on skin tone
    /// FIXED: Indian skin (medium/mediumDark) has natural warmth, needs higher thresholds
    /// to avoid false positives for inflammation
    private func getAdaptiveThresholds(skinTone: SkinToneCategory) -> (moderate: Float, severe: Float) {
        switch skinTone {
        case .medium, .mediumDark:
            // Indian skin (Fitzpatrick III-IV) - higher tolerance for natural warmth
            return (moderate: 0.25, severe: 0.38)
        case .dark, .veryDark:
            // Very dark skin - use darkening detection, not redness
            return (moderate: 0.22, severe: 0.35)
        case .veryLight, .light:
            // Light skin - standard thresholds
            return (moderate: 0.20, severe: 0.30)
        }
    }

    // MARK: - Public API

    /// Analyze redness and inflammation from texture
    /// IMPROVED: Detects inflammation on darker skin (appears as darkening, not redness)
    public func analyzeRedness(texture: UIImage) -> RednessAnalysis {
        AppLogger.metrics.info("🔬 Analyzing redness and inflammation...")

        guard let cgImage = texture.cgImage else {
            return RednessAnalysis(
                overallScore: 50,
                rednessLevel: .mild,
                globalRedness: 0.1,
                regionalRedness: [:],
                inflamedAreas: [],
                confidence: 0,  // No confidence when image unavailable
                detectionMethod: "none"
            )
        }

        // GPU PATH: Use full resolution analysis on GPU
        if useGPU, let metalAnalyzer = metalAnalyzer {
            AppLogger.metrics.info("   🎨 Using GPU acceleration (full resolution)")
            return analyzeRednessGPU(texture: texture, cgImage: cgImage, metalAnalyzer: metalAnalyzer)
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

        // Convert to RGB data
        let width = analysisImage.width
        let height = analysisImage.height

        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        context?.draw(analysisImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Detect skin tone for adaptive inflammation detection
        let skinTone = skinToneNormalizer.detectSkinTone(texture: analysisTexture)

        // 1. Calculate global redness (skin-tone aware)
        let globalRedness = calculateGlobalRedness(pixelData: pixelData, width: width, height: height, skinTone: skinTone)

        // 2. Calculate regional redness
        let regionalRedness = calculateRegionalRedness(pixelData: pixelData, width: width, height: height)

        // Get adaptive thresholds based on skin tone (FIXED for Indian skin)
        let thresholds = getAdaptiveThresholds(skinTone: skinTone)

        // 3. Detect inflamed areas (using adaptive thresholds)
        let inflamedAreas = detectInflammedAreas(pixelData: pixelData, width: width, height: height, moderateThreshold: thresholds.moderate)

        // 4. Classify redness level (using adaptive thresholds)
        let rednessLevel = classifyRednessLevel(globalRedness: globalRedness, thresholds: thresholds)

        // 5. Calculate overall score (using adaptive thresholds)
        let overallScore = calculateOverallScore(
            globalRedness: globalRedness,
            inflamedAreaCount: inflamedAreas.count,
            thresholds: thresholds
        )

        // 6. Calculate confidence based on detection method and consistency
        let useDarkeningDetection = (skinTone == .dark || skinTone == .veryDark || skinTone == .mediumDark)
        let detectionMethodStr = useDarkeningDetection ? "darkening" : "redness"

        let confidence: Float = {
            var conf: Float = 65.0

            // Darkening method (for dark skin) slightly less reliable
            if useDarkeningDetection {
                conf -= 10
            }

            // High consistency across regions = higher confidence
            if !regionalRedness.isEmpty {
                let values = Array(regionalRedness.values)
                let avg = values.reduce(0, +) / Float(values.count)
                let variance = values.map { pow($0 - avg, 2) }.reduce(0, +) / Float(values.count)
                if variance < 0.01 { conf += 15 }  // Very consistent
            }

            // Inflamed area detection adds confidence
            if inflamedAreas.count > 0 && inflamedAreas.count < 20 {
                conf += 10  // Reasonable number of detections
            }

            return max(50, min(90, conf))
        }()

        AppLogger.metrics.info("✅ Redness analysis complete")
        AppLogger.metrics.info("   Global redness: \(String(format: "%.3f", globalRedness))")
        AppLogger.metrics.info("   Level: \(rednessLevel)")
        AppLogger.metrics.info("   Inflamed areas: \(inflamedAreas.count)")
        AppLogger.metrics.info("   Overall score: \(String(format: "%.1f", overallScore))/100")
        AppLogger.metrics.info("   Confidence: \(String(format: "%.1f", confidence))% (\(detectionMethodStr) method)")

        return RednessAnalysis(
            overallScore: overallScore,
            rednessLevel: rednessLevel,
            globalRedness: globalRedness,
            regionalRedness: regionalRedness,
            inflamedAreas: inflamedAreas,
            confidence: confidence,
            detectionMethod: detectionMethodStr
        )
    }

    // MARK: - Private Methods

    /// Calculate global average redness using skin-tone adaptive threshold
    /// IMPROVED: For darker skin, inflammation appears as darkening (not redness)
    private func calculateGlobalRedness(pixelData: [UInt8], width: Int, height: Int, skinTone: SkinToneCategory) -> Float {
        // STEP 1: Calculate baseline skin tone (average RGB in center region)
        let baselineRGB = calculateBaselineSkinTone(pixelData: pixelData, width: width, height: height)
        let baselineRedness = baselineRGB.r - (baselineRGB.g + baselineRGB.b) / 2.0
        let baselineBrightness = (baselineRGB.r + baselineRGB.g + baselineRGB.b) / 3.0

        // STEP 2: Use RELATIVE threshold (adaptive to skin tone)
        let adaptiveThreshold = max(0.08, baselineRedness * adaptiveMultiplier)

        var totalInflammation: Float = 0
        var pixelCount = 0

        // SKIN-TONE AWARE: Dark skin inflammation detection
        let useDarkeningDetection = (skinTone == .dark || skinTone == .veryDark || skinTone == .mediumDark)

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let r = Float(pixelData[index]) / 255.0
                let g = Float(pixelData[index + 1]) / 255.0
                let b = Float(pixelData[index + 2]) / 255.0

                if useDarkeningDetection {
                    // For dark skin: inflammation = localized darkening
                    let brightness = (r + g + b) / 3.0
                    let relativeDarkness = baselineBrightness - brightness

                    // Inflammation shows as areas significantly darker than baseline
                    if relativeDarkness > 0.10 {  // 10% darker = inflammation
                        totalInflammation += relativeDarkness
                        pixelCount += 1
                    }
                } else {
                    // For light skin: standard red-based detection
                    let redness = r - (g + b) / 2.0
                    let relativeRedness = redness - baselineRedness

                    if relativeRedness > adaptiveThreshold {
                        totalInflammation += relativeRedness
                        pixelCount += 1
                    }
                }
            }
        }

        return pixelCount > 0 ? totalInflammation / Float(pixelCount) : 0
    }

    /// Calculate redness per facial region
    private func calculateRegionalRedness(pixelData: [UInt8], width: Int, height: Int) -> [String: Float] {
        var regionalRedness: [String: (total: Float, count: Int)] = [:]

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let r = Float(pixelData[index]) / 255.0
                let g = Float(pixelData[index + 1]) / 255.0
                let b = Float(pixelData[index + 2]) / 255.0

                let redness = r - (g + b) / 2.0

                if redness > 0 {
                    let region = classifyLocation(x: x, y: y, width: width, height: height)
                    let current = regionalRedness[region, default: (0, 0)]
                    regionalRedness[region] = (current.total + redness, current.count + 1)
                }
            }
        }

        return regionalRedness.mapValues { $0.count > 0 ? $0.total / Float($0.count) : 0 }
    }

    /// Detect highly inflamed areas
    /// FIXED: Now accepts skin-tone-adaptive threshold for Indian skin
    private func detectInflammedAreas(pixelData: [UInt8], width: Int, height: Int, moderateThreshold: Float) -> [InflammedRegion] {
        var inflamedAreas: [InflammedRegion] = []
        var visited = Array(repeating: Array(repeating: false, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                guard !visited[y][x] else { continue }

                let index = (y * width + x) * 4
                let r = Float(pixelData[index]) / 255.0
                let g = Float(pixelData[index + 1]) / 255.0
                let b = Float(pixelData[index + 2]) / 255.0

                let redness = r - (g + b) / 2.0

                // Only consider significantly red areas (using adaptive threshold)
                if redness > moderateThreshold {
                    // BFS to find connected inflamed region
                    let area = floodFillInflamed(
                        x: x, y: y,
                        width: width, height: height,
                        pixelData: pixelData,
                        visited: &visited,
                        threshold: moderateThreshold
                    )

                    if let area = area, area.area >= 20 {  // Minimum 20 pixels
                        inflamedAreas.append(area)
                    }
                }
            }
        }

        return inflamedAreas
    }

    /// Flood fill to find connected inflamed region
    private func floodFillInflamed(
        x: Int, y: Int,
        width: Int, height: Int,
        pixelData: [UInt8],
        visited: inout [[Bool]],
        threshold: Float
    ) -> InflammedRegion? {
        var queue: [(Int, Int)] = [(x, y)]
        var pixels: [(Int, Int)] = []
        var totalRedness: Float = 0

        while !queue.isEmpty {
            let (cx, cy) = queue.removeFirst()

            guard cx >= 0 && cx < width && cy >= 0 && cy < height else { continue }
            guard !visited[cy][cx] else { continue }

            let index = (cy * width + cx) * 4
            let r = Float(pixelData[index]) / 255.0
            let g = Float(pixelData[index + 1]) / 255.0
            let b = Float(pixelData[index + 2]) / 255.0

            let redness = r - (g + b) / 2.0

            guard redness > threshold else { continue }

            visited[cy][cx] = true
            pixels.append((cx, cy))
            totalRedness += redness

            // Add neighbors
            queue.append((cx + 1, cy))
            queue.append((cx - 1, cy))
            queue.append((cx, cy + 1))
            queue.append((cx, cy - 1))
        }

        guard !pixels.isEmpty else { return nil }

        let avgX = pixels.map { $0.0 }.reduce(0, +) / pixels.count
        let avgY = pixels.map { $0.1 }.reduce(0, +) / pixels.count
        let area = Float(pixels.count)
        let severity = totalRedness / Float(pixels.count)

        let location = classifyLocation(x: avgX, y: avgY, width: width, height: height)

        return InflammedRegion(location: location, severity: severity, area: area)
    }

    /// Classify location on face
    private func classifyLocation(x: Int, y: Int, width: Int, height: Int) -> String {
        let normalizedY = Float(y) / Float(height)
        let normalizedX = Float(x) / Float(width)

        if normalizedY < 0.35 {
            return "forehead"
        } else if normalizedY < 0.65 {
            if normalizedX < 0.35 {
                return "left_cheek"
            } else if normalizedX > 0.65 {
                return "right_cheek"
            } else {
                return "nose"
            }
        } else {
            return "chin"
        }
    }

    /// Classify redness level (using skin-tone-adaptive thresholds)
    /// FIXED: Now uses adaptive thresholds for Indian skin
    private func classifyRednessLevel(globalRedness: Float, thresholds: (moderate: Float, severe: Float)) -> RednessLevel {
        let minimalThreshold: Float = 0.05

        if globalRedness < minimalThreshold {
            return .minimal
        } else if globalRedness < thresholds.moderate {
            return .mild
        } else if globalRedness < thresholds.severe {
            return .moderate
        } else {
            return .severe
        }
    }

    /// Calculate overall redness score
    /// FIXED: Now uses the calibrated RednessLevel score instead of broken formula
    /// Previous formula: 100 - (globalRedness * 500) produced 0 scores for mild redness
    private func calculateOverallScore(globalRedness: Float, inflamedAreaCount: Int, thresholds: (moderate: Float, severe: Float)) -> Float {
        // Use the classified redness level's calibrated score (with skin-tone-adaptive thresholds)
        // minimal=95, mild=75, moderate=50, severe=25
        let rednessLevel = classifyRednessLevel(globalRedness: globalRedness, thresholds: thresholds)
        let baseScore = rednessLevel.score

        // Small penalty for inflamed areas (max -15 points, 1.5 points per area)
        // This prevents over-penalization - even 10 areas only costs 15 points
        let areaPenalty = min(15.0, Float(inflamedAreaCount) * 1.5)

        return max(0, baseScore - areaPenalty)
    }

    /// Calculate baseline skin tone from center region (avoids edges, hair)
    private func calculateBaselineSkinTone(pixelData: [UInt8], width: Int, height: Int) -> (r: Float, g: Float, b: Float) {
        // Sample center region (avoid edges, hair)
        let centerX = width / 2
        let centerY = height / 2
        let sampleRadius = min(width, height) / 4

        var rSum: Float = 0, gSum: Float = 0, bSum: Float = 0
        var count = 0

        for y in max(0, centerY - sampleRadius)..<min(height, centerY + sampleRadius) {
            for x in max(0, centerX - sampleRadius)..<min(width, centerX + sampleRadius) {
                let index = (y * width + x) * 4
                rSum += Float(pixelData[index]) / 255.0
                gSum += Float(pixelData[index + 1]) / 255.0
                bSum += Float(pixelData[index + 2]) / 255.0
                count += 1
            }
        }

        return count > 0 ? (rSum / Float(count), gSum / Float(count), bSum / Float(count)) : (0.5, 0.5, 0.5)
    }

    // MARK: - GPU Acceleration Methods

    /// GPU-accelerated redness analysis (full resolution, no downsampling)
    private func analyzeRednessGPU(
        texture: UIImage,
        cgImage: CGImage,
        metalAnalyzer: MetalAnalyzerBase
    ) -> RednessAnalysis {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Convert UIImage to Metal texture
            guard let inputTexture = MetalHelpers.textureFromUIImage(texture, device: metalAnalyzer.device) else {
                AppLogger.metrics.error("❌ GPU: Failed to convert image to texture - falling back to CPU")
                return analyzeRednessCPU(texture: texture, cgImage: cgImage)
            }

            let width = inputTexture.width
            let height = inputTexture.height
            AppLogger.metrics.info("   📏 Analyzing full resolution: \(width)x\(height)")

            // STEP 1: Calculate baseline skin tone using GPU
            let baselineRGB = try calculateBaselineSkinToneGPU(
                inputTexture: inputTexture,
                metalAnalyzer: metalAnalyzer
            )
            let baselineRedness = baselineRGB.r - (baselineRGB.g + baselineRGB.b) / 2.0

            // STEP 2: Calculate adaptive threshold
            let adaptiveThreshold = max(0.08, baselineRedness * adaptiveMultiplier)
            AppLogger.metrics.debug("   🎯 Baseline redness: \(String(format: "%.3f", baselineRedness)), threshold: \(String(format: "%.3f", adaptiveThreshold))")

            // Detect skin tone for adaptive thresholds
            let analysisTexture = UIImage(cgImage: cgImage)
            let skinTone = skinToneNormalizer.detectSkinTone(texture: analysisTexture)
            let thresholds = getAdaptiveThresholds(skinTone: skinTone)

            // STEP 3: Analyze redness using GPU
            let results = try analyzeRednessGPUKernel(
                inputTexture: inputTexture,
                threshold: adaptiveThreshold,
                metalAnalyzer: metalAnalyzer
            )

            let globalRedness = results.redness
            let inflamedPixelCount = results.inflamedPixels

            AppLogger.metrics.info("   Global redness: \(String(format: "%.3f", globalRedness))")
            AppLogger.metrics.info("   Inflamed pixels: \(Int(inflamedPixelCount))")

            // STEP 4: Calculate regional redness using GPU
            let regionalRedness = try analyzeRegionalRednessGPU(
                inputTexture: inputTexture,
                metalAnalyzer: metalAnalyzer
            )

            // STEP 5: Detect inflamed areas (use CPU for flood-fill algorithm)
            // GPU is not efficient for this irregular, graph-traversal algorithm
            let inflamedAreas = detectInflammedAreasCPU(
                texture: texture,
                cgImage: cgImage,
                moderateThreshold: thresholds.moderate
            )

            // STEP 6: Classify redness level
            let rednessLevel = classifyRednessLevel(globalRedness: globalRedness, thresholds: thresholds)

            // STEP 7: Calculate overall score
            let overallScore = calculateOverallScore(
                globalRedness: globalRedness,
                inflamedAreaCount: inflamedAreas.count,
                thresholds: thresholds
            )

            // STEP 8: Calculate confidence
            let useDarkeningDetection = (skinTone == .dark || skinTone == .veryDark || skinTone == .mediumDark)
            let detectionMethodStr = useDarkeningDetection ? "darkening" : "redness"

            let confidence: Float = {
                var conf: Float = 65.0

                if useDarkeningDetection {
                    conf -= 10
                }

                if !regionalRedness.isEmpty {
                    let values = Array(regionalRedness.values)
                    let avg = values.reduce(0, +) / Float(values.count)
                    let variance = values.map { pow($0 - avg, 2) }.reduce(0, +) / Float(values.count)
                    if variance < 0.01 { conf += 15 }
                }

                if inflamedAreas.count > 0 && inflamedAreas.count < 20 {
                    conf += 10
                }

                return max(50, min(90, conf))
            }()

            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            AppLogger.metrics.info("✅ Redness analysis complete (GPU)")
            AppLogger.metrics.info("   GPU time: \(String(format: "%.1f", elapsed))ms")
            AppLogger.metrics.info("   Level: \(rednessLevel)")
            AppLogger.metrics.info("   Overall score: \(String(format: "%.1f", overallScore))/100")
            AppLogger.metrics.info("   Confidence: \(String(format: "%.1f", confidence))% (\(detectionMethodStr) method)")

            return RednessAnalysis(
                overallScore: overallScore,
                rednessLevel: rednessLevel,
                globalRedness: globalRedness,
                regionalRedness: regionalRedness,
                inflamedAreas: inflamedAreas,
                confidence: confidence,
                detectionMethod: detectionMethodStr
            )

        } catch {
            AppLogger.metrics.error("❌ GPU analysis failed: \(error.localizedDescription) - falling back to CPU")
            return analyzeRednessCPU(texture: texture, cgImage: cgImage)
        }
    }

    /// Helper to run CPU analysis (extracted from main method)
    private func analyzeRednessCPU(texture: UIImage, cgImage: CGImage) -> RednessAnalysis {
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

        let width = analysisImage.width
        let height = analysisImage.height

        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        context?.draw(analysisImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let skinTone = skinToneNormalizer.detectSkinTone(texture: analysisTexture)
        let globalRedness = calculateGlobalRedness(pixelData: pixelData, width: width, height: height, skinTone: skinTone)
        let regionalRedness = calculateRegionalRedness(pixelData: pixelData, width: width, height: height)
        let thresholds = getAdaptiveThresholds(skinTone: skinTone)
        let inflamedAreas = detectInflammedAreas(pixelData: pixelData, width: width, height: height, moderateThreshold: thresholds.moderate)
        let rednessLevel = classifyRednessLevel(globalRedness: globalRedness, thresholds: thresholds)
        let overallScore = calculateOverallScore(globalRedness: globalRedness, inflamedAreaCount: inflamedAreas.count, thresholds: thresholds)

        let useDarkeningDetection = (skinTone == .dark || skinTone == .veryDark || skinTone == .mediumDark)
        let detectionMethodStr = useDarkeningDetection ? "darkening" : "redness"

        let confidence: Float = {
            var conf: Float = 65.0
            if useDarkeningDetection { conf -= 10 }
            if !regionalRedness.isEmpty {
                let values = Array(regionalRedness.values)
                let avg = values.reduce(0, +) / Float(values.count)
                let variance = values.map { pow($0 - avg, 2) }.reduce(0, +) / Float(values.count)
                if variance < 0.01 { conf += 15 }
            }
            if inflamedAreas.count > 0 && inflamedAreas.count < 20 { conf += 10 }
            return max(50, min(90, conf))
        }()

        AppLogger.metrics.info("✅ Redness analysis complete (CPU)")
        AppLogger.metrics.info("   Global redness: \(String(format: "%.3f", globalRedness))")
        AppLogger.metrics.info("   Level: \(rednessLevel)")
        AppLogger.metrics.info("   Overall score: \(String(format: "%.1f", overallScore))/100")
        AppLogger.metrics.info("   Confidence: \(String(format: "%.1f", confidence))% (\(detectionMethodStr) method)")

        return RednessAnalysis(
            overallScore: overallScore,
            rednessLevel: rednessLevel,
            globalRedness: globalRedness,
            regionalRedness: regionalRedness,
            inflamedAreas: inflamedAreas,
            confidence: confidence,
            detectionMethod: detectionMethodStr
        )
    }

    /// Calculate baseline skin tone using GPU
    private func calculateBaselineSkinToneGPU(
        inputTexture: MTLTexture,
        metalAnalyzer: MetalAnalyzerBase
    ) throws -> (r: Float, g: Float, b: Float) {
        // Load pipeline
        let pipeline = try metalAnalyzer.loadPipeline(named: "calculateBaselineSkinTone")

        // Create output buffer (3 floats: R, G, B)
        let resultBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<Float>.size * 3)

        // Execute with cancellation support
        try metalAnalyzer.executeCancellableSync(operation: "calculateBaselineSkinTone") { commandBuffer in
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

        // Read results
        let resultPtr = resultBuffer.contents().assumingMemoryBound(to: Float.self)
        return (resultPtr[0], resultPtr[1], resultPtr[2])
    }

    /// Analyze redness using GPU kernel
    private func analyzeRednessGPUKernel(
        inputTexture: MTLTexture,
        threshold: Float,
        metalAnalyzer: MetalAnalyzerBase
    ) throws -> (redness: Float, inflamedPixels: Float) {
        // Load pipeline
        let pipeline = try metalAnalyzer.loadPipeline(named: "analyzeRedness")

        // Calculate threadgroup configuration
        let (threadgroups, threadsPerGroup) = metalAnalyzer.calculateThreadgroups(
            pipeline: pipeline,
            width: inputTexture.width,
            height: inputTexture.height
        )

        let numThreadgroups = threadgroups.width * threadgroups.height

        // Create buffers for partial results (one per threadgroup)
        let rednessBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<Float>.stride * numThreadgroups)
        let inflamedBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<Float>.stride * numThreadgroups)

        // Create threshold buffer
        var thresholdValue = threshold
        let thresholdBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<Float>.size)
        memcpy(thresholdBuffer.contents(), &thresholdValue, MemoryLayout<Float>.size)

        // Create threadgroupsPerRow buffer (required for linear index calculation)
        var threadgroupsPerRow = UInt32(threadgroups.width)
        let threadgroupsPerRowBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<UInt32>.size)
        memcpy(threadgroupsPerRowBuffer.contents(), &threadgroupsPerRow, MemoryLayout<UInt32>.size)

        // Execute kernel with cancellation support
        try metalAnalyzer.executeCancellableSync(operation: "analyzeRedness") { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw GPUAnalysisError.commandBufferFailed("Failed to create compute encoder")
            }

            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(inputTexture, index: 0)
            encoder.setBuffer(rednessBuffer, offset: 0, index: 0)
            encoder.setBuffer(inflamedBuffer, offset: 0, index: 1)
            encoder.setBuffer(thresholdBuffer, offset: 0, index: 2)
            encoder.setBuffer(threadgroupsPerRowBuffer, offset: 0, index: 3)

            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
        }

        // Reduce partial results on CPU (small array)
        let rednessPtr = rednessBuffer.contents().assumingMemoryBound(to: Float.self)
        let inflamedPtr = inflamedBuffer.contents().assumingMemoryBound(to: Float.self)

        var totalRedness: Float = 0
        var totalInflamed: Float = 0

        for i in 0..<numThreadgroups {
            totalRedness += rednessPtr[i]
            totalInflamed += inflamedPtr[i]
        }

        // Calculate average redness (pixels with positive redness)
        let avgRedness = totalRedness > 0 ? totalRedness / Float(inputTexture.width * inputTexture.height) : 0

        return (avgRedness, totalInflamed)
    }

    /// Analyze regional redness using GPU
    private func analyzeRegionalRednessGPU(
        inputTexture: MTLTexture,
        metalAnalyzer: MetalAnalyzerBase
    ) throws -> [String: Float] {
        let pipeline = try metalAnalyzer.loadPipeline(named: "analyzeRegionalRedness")

        // Define face regions (normalized coordinates)
        let regions: [String: (minX: Float, maxX: Float, minY: Float, maxY: Float)] = [
            "forehead": (0.3, 0.7, 0.1, 0.35),
            "left_cheek": (0.1, 0.35, 0.35, 0.65),
            "right_cheek": (0.65, 0.9, 0.35, 0.65),
            "nose": (0.35, 0.65, 0.35, 0.65),
            "chin": (0.35, 0.65, 0.65, 0.9)
        ]

        var regionalScores: [String: Float] = [:]

        for (regionName, bounds) in regions {
            // Calculate threadgroup configuration
            let (threadgroups, threadsPerGroup) = metalAnalyzer.calculateThreadgroups(
                pipeline: pipeline,
                width: inputTexture.width,
                height: inputTexture.height
            )

            let numThreadgroups = threadgroups.width * threadgroups.height

            // Create buffers
            let rednessBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<Float>.stride * numThreadgroups)
            let pixelCountBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<Float>.stride * numThreadgroups)

            // Create region bounds buffer (float4)
            var regionBounds: SIMD4<Float> = SIMD4<Float>(bounds.minX, bounds.maxX, bounds.minY, bounds.maxY)
            let boundsBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<SIMD4<Float>>.size)
            memcpy(boundsBuffer.contents(), &regionBounds, MemoryLayout<SIMD4<Float>>.size)

            // Create threadgroupsPerRow buffer
            var threadgroupsPerRow = UInt32(threadgroups.width)
            let threadgroupsPerRowBuffer = try metalAnalyzer.createBuffer(length: MemoryLayout<UInt32>.size)
            memcpy(threadgroupsPerRowBuffer.contents(), &threadgroupsPerRow, MemoryLayout<UInt32>.size)

            // Execute kernel with cancellation support
            try metalAnalyzer.executeCancellableSync(operation: "analyzeRegionalRedness") { commandBuffer in
                guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                    throw GPUAnalysisError.commandBufferFailed("Failed to create compute encoder")
                }

                encoder.setComputePipelineState(pipeline)
                encoder.setTexture(inputTexture, index: 0)
                encoder.setBuffer(rednessBuffer, offset: 0, index: 0)
                encoder.setBuffer(pixelCountBuffer, offset: 0, index: 1)
                encoder.setBuffer(boundsBuffer, offset: 0, index: 2)
                encoder.setBuffer(threadgroupsPerRowBuffer, offset: 0, index: 3)

                encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
                encoder.endEncoding()
            }

            // Reduce results
            let rednessPtr = rednessBuffer.contents().assumingMemoryBound(to: Float.self)
            let pixelCountPtr = pixelCountBuffer.contents().assumingMemoryBound(to: Float.self)

            var totalRedness: Float = 0
            var totalPixels: Float = 0

            for i in 0..<numThreadgroups {
                totalRedness += rednessPtr[i]
                totalPixels += pixelCountPtr[i]
            }

            regionalScores[regionName] = totalPixels > 0 ? totalRedness / totalPixels : 0
        }

        return regionalScores
    }

    /// Detect inflamed areas using CPU (flood-fill not efficient on GPU)
    private func detectInflammedAreasCPU(
        texture: UIImage,
        cgImage: CGImage,
        moderateThreshold: Float
    ) -> [InflammedRegion] {
        // Downsample for this operation (it's CPU-intensive)
        let analysisImage: CGImage
        if let downsampled = downsample(cgImage, maxSize: 512) {
            analysisImage = downsampled
        } else {
            analysisImage = cgImage
        }

        let width = analysisImage.width
        let height = analysisImage.height

        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        context?.draw(analysisImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return detectInflammedAreas(pixelData: pixelData, width: width, height: height, moderateThreshold: moderateThreshold)
    }
}
