//
//  LightingNormalizer.swift
//  Ollvy
//
//  Lighting control and normalization for consistent skin analysis
//  Critical for high accuracy across different lighting conditions
//

import UIKit
import ARKit
import CoreImage

/// Lighting quality assessment (Processing version)
public struct ProcessingLightingQuality {
    public let overallScore: Float  // 0-1
    public let brightness: Float
    public let uniformity: Float
    public let shadowPresence: Float
    public let isAcceptable: Bool
    public let issues: [String]

    public init(overallScore: Float, brightness: Float, uniformity: Float, shadowPresence: Float, isAcceptable: Bool, issues: [String]) {
        self.overallScore = overallScore
        self.brightness = brightness
        self.uniformity = uniformity
        self.shadowPresence = shadowPresence
        self.isAcceptable = isAcceptable
        self.issues = issues
    }
}

/// Normalized texture result
struct NormalizedTexture {
    let normalizedImage: UIImage
    let lightingQuality: ProcessingLightingQuality
    let whiteBalanceCorrected: Bool
    let exposureAdjusted: Bool

    init(normalizedImage: UIImage, lightingQuality: ProcessingLightingQuality, whiteBalanceCorrected: Bool, exposureAdjusted: Bool) {
        self.normalizedImage = normalizedImage
        self.lightingQuality = lightingQuality
        self.whiteBalanceCorrected = whiteBalanceCorrected
        self.exposureAdjusted = exposureAdjusted
    }
}

/// Lighting normalization and quality control
class LightingNormalizer {

    // MARK: - Configuration

    private let minBrightness: Float = 0.15  // Was: 0.3 - only block if VERY dark
    private let maxBrightness: Float = 0.8
    private let minUniformity: Float = 0.5  // Relaxed from 0.7 - faces have natural variance
    private let maxShadowPresence: Float = 0.3
    private let minAcceptableScore: Float = 0.5  // Relaxed from 0.6 for real-world lighting
    private let skinToneNormalizer = SkinToneNormalizer()

    // MARK: - Public API

    /// Assess lighting quality
    /// IMPROVED: Skin-tone-aware dynamic range thresholds
    /// ENHANCED: Added diagnostic logging to identify 0.00 score issues
    func assessLightingQuality(image: UIImage) -> ProcessingLightingQuality {
        guard let ciImage = CIImage(image: image) else {
            AppLogger.metrics.error("❌ LightingNormalizer: Failed to create CIImage")
            return ProcessingLightingQuality(
                overallScore: 0,
                brightness: 0,
                uniformity: 0,
                shadowPresence: 1,
                isAcceptable: false,
                issues: ["Failed to process image"]
            )
        }

        var issues: [String] = []

        // Detect skin tone for adaptive thresholds
        let skinTone = skinToneNormalizer.detectSkinTone(texture: image)
        AppLogger.metrics.debug("📊 Detected skin tone: \(skinTone)")

        // Calculate brightness
        let brightness = calculateAverageBrightness(ciImage: ciImage)

        // Calculate dynamic range (skin-tone independent metric)
        let dynamicRange = calculateDynamicRange(ciImage: ciImage)

        // SKIN-TONE AWARE: Adaptive dynamic range thresholds
        // Darker skin may have lower dynamic range even in good lighting
        let minDynamicRange: Float = (skinTone == .dark || skinTone == .veryDark) ? 0.25 : 0.30

        // Check dynamic range first (works for all skin tones)
        // Only flag as "too dark" if BOTH low brightness AND poor dynamic range
        if dynamicRange < minDynamicRange {
            issues.append("Too dark - increase lighting")
        } else if brightness < minBrightness {  // 0.15 - only block if VERY dark
            issues.append("Too dark - increase lighting")
        } else if brightness > maxBrightness {
            issues.append("Too bright - reduce lighting")
        }

        // Calculate uniformity
        let uniformity = calculateLightingUniformity(ciImage: ciImage)
        if uniformity < minUniformity {
            issues.append("Uneven lighting detected")
        }

        // Detect shadows
        let shadowPresence = detectShadows(ciImage: ciImage)
        if shadowPresence > maxShadowPresence {
            issues.append("Shadows detected - improve lighting")
        }

        // Calculate overall score
        // SKIN-TONE ADAPTIVE: Optimal brightness varies by skin tone
        // Light skin: optimal ~0.55-0.65 (brighter is better)
        // Dark skin: optimal ~0.35-0.45 (naturally lower reflectance)
        let optimalBrightness: Float
        let brightnessRange: Float
        switch skinTone {
        case .veryLight, .light:
            optimalBrightness = 0.60
            brightnessRange = 0.60
        case .medium, .mediumDark:
            optimalBrightness = 0.50
            brightnessRange = 0.50
        case .dark, .veryDark:
            optimalBrightness = 0.40
            brightnessRange = 0.40
        }
        let brightnessScore = max(0, 1.0 - abs(brightness - optimalBrightness) / brightnessRange)
        let uniformityScore = uniformity
        let shadowScore = 1.0 - shadowPresence

        // Adjusted weighting: brightness more important than uniformity (faces have natural variance)
        let overallScore = (brightnessScore * 0.5 + uniformityScore * 0.3 + shadowScore * 0.2)
        let isAcceptable = overallScore >= minAcceptableScore

        // DIAGNOSTIC: Log all score components to identify 0.00 score issues
        AppLogger.metrics.debug("📊 Lighting quality breakdown:")
        AppLogger.metrics.debug("   Brightness: \(String(format: "%.2f", brightness)) (optimal: \(String(format: "%.2f", optimalBrightness)), score: \(String(format: "%.2f", brightnessScore)))")
        AppLogger.metrics.debug("   Uniformity: \(String(format: "%.2f", uniformity)) (score: \(String(format: "%.2f", uniformityScore)))")
        AppLogger.metrics.debug("   Shadow: \(String(format: "%.2f", shadowPresence)) (score: \(String(format: "%.2f", shadowScore)))")
        AppLogger.metrics.debug("   Overall: \(String(format: "%.2f", overallScore)) (acceptable: \(isAcceptable))")

        if overallScore < 0.1 {
            AppLogger.metrics.warning("⚠️ Lighting quality very low! Check component scores above")
        }

        return ProcessingLightingQuality(
            overallScore: overallScore,
            brightness: brightness,
            uniformity: uniformity,
            shadowPresence: shadowPresence,
            isAcceptable: isAcceptable,
            issues: issues
        )
    }

    /// Normalize texture - PASSTHROUGH MODE
    /// NO PROCESSING - return original image as-is
    /// iPhone/ARKit camera already handles exposure and white balance well
    /// Processing was destroying skin detail needed for accurate metrics
    func normalize(image: UIImage) -> NormalizedTexture? {
        // Assess quality for logging purposes only
        let quality = assessLightingQuality(image: image)

        // PASSTHROUGH: Return original image with NO modifications
        // The camera image is already good enough
        return NormalizedTexture(
            normalizedImage: image,  // Original, untouched
            lightingQuality: quality,
            whiteBalanceCorrected: false,
            exposureAdjusted: false
        )
    }

    // MARK: - Private Methods

    /// Calculate average brightness
    private func calculateAverageBrightness(ciImage: CIImage) -> Float {
        let extent = ciImage.extent
        let inputImage = ciImage.cropped(to: extent)

        // Use CIAreaAverage to get average color
        guard let filter = CIFilter(name: "CIAreaAverage") else { return 0.5 }
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else { return 0.5 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext()
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: CGColorSpaceCreateDeviceRGB())

        // Calculate perceived brightness (luminance)
        let r = Float(bitmap[0]) / 255.0
        let g = Float(bitmap[1]) / 255.0
        let b = Float(bitmap[2]) / 255.0

        // FIXED: Standardized on BT.709 (sRGB) for consistency across all analyzers
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Calculate lighting uniformity
    private func calculateLightingUniformity(ciImage: CIImage) -> Float {
        // Divide image into grid and calculate variance of brightness
        let extent = ciImage.extent
        let gridSize = 4
        let cellWidth = extent.width / CGFloat(gridSize)
        let cellHeight = extent.height / CGFloat(gridSize)

        var brightnesses: [Float] = []

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let cellRect = CGRect(
                    x: CGFloat(col) * cellWidth,
                    y: CGFloat(row) * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
                let cellImage = ciImage.cropped(to: cellRect)
                let brightness = calculateAverageBrightness(ciImage: cellImage)
                brightnesses.append(brightness)
            }
        }

        // Calculate coefficient of variation (lower = more uniform)
        let mean = brightnesses.reduce(0, +) / Float(brightnesses.count)
        let variance = brightnesses.map { pow($0 - mean, 2) }.reduce(0, +) / Float(brightnesses.count)
        let stdDev = sqrt(variance)
        let cv = stdDev / mean

        // Convert to uniformity score (0-1, higher is better)
        // Fixed: Removed 2.0 multiplier - faces naturally have brightness variance due to geometry
        // (nose, eye sockets, cheeks create shadows even in perfect lighting)
        return max(0, 1.0 - cv)
    }

    /// Detect shadow presence
    private func detectShadows(ciImage: CIImage) -> Float {
        // Calculate histogram and check for dark regions
        let extent = ciImage.extent
        let inputImage = ciImage.cropped(to: extent)

        // Convert to grayscale
        guard let grayFilter = CIFilter(name: "CIColorControls") else { return 0 }
        grayFilter.setValue(inputImage, forKey: kCIInputImageKey)
        grayFilter.setValue(0, forKey: kCIInputSaturationKey)

        guard let grayImage = grayFilter.outputImage else { return 0 }

        // Simple shadow detection: percentage of pixels below threshold
        let darkThreshold: Float = 0.2
        let brightness = calculateAverageBrightness(ciImage: grayImage)

        // If overall brightness is low, likely shadows
        return brightness < darkThreshold ? 1.0 - brightness : 0.0
    }

    /// Calculate dynamic range (max - min brightness) as a 0-1 score
    /// Skin-tone independent: works for all skin tones
    private func calculateDynamicRange(ciImage: CIImage) -> Float {
        let extent = ciImage.extent
        let inputImage = ciImage.cropped(to: extent)

        // Convert to grayscale
        guard let grayFilter = CIFilter(name: "CIColorControls") else { return 0 }
        grayFilter.setValue(inputImage, forKey: kCIInputImageKey)
        grayFilter.setValue(0, forKey: kCIInputSaturationKey)

        guard let grayImage = grayFilter.outputImage else { return 0 }

        // Sample pixels to find min/max
        // FIX: Use RGBA8 format with deviceRGB colorspace instead of R8/gray
        // R8 with DeviceGray causes "unsupported colorspace" error on some devices
        let context = CIContext()
        let width = Int(extent.width)
        let height = Int(extent.height)
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        context.render(grayImage,
                      toBitmap: &pixelData,
                      rowBytes: width * 4,
                      bounds: CGRect(x: 0, y: 0, width: width, height: height),
                      format: .RGBA8,
                      colorSpace: CGColorSpaceCreateDeviceRGB())

        // Extract grayscale values from R channel (since input was desaturated)
        let grayValues = stride(from: 0, to: pixelData.count, by: 4).map { pixelData[$0] }
        let minVal = grayValues.min() ?? 0
        let maxVal = grayValues.max() ?? 255

        // Return dynamic range as 0-1 score
        return Float(maxVal - minVal) / 255.0
    }

    /// Apply adaptive white balance correction using Gray World algorithm
    /// This adapts to different lighting conditions (tungsten, daylight, LED, etc.)
    private func applyWhiteBalance(_ image: CIImage) -> CIImage {
        let extent = image.extent

        // Calculate average color of the image using Gray World assumption
        guard let avgFilter = CIFilter(name: "CIAreaAverage") else { return image }
        avgFilter.setValue(image, forKey: kCIInputImageKey)
        avgFilter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)

        guard let outputImage = avgFilter.outputImage else { return image }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext()
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: CGColorSpaceCreateDeviceRGB())

        let avgR = Float(bitmap[0]) / 255.0
        let avgG = Float(bitmap[1]) / 255.0
        let avgB = Float(bitmap[2]) / 255.0

        // Gray World: target neutral tones with slight warmth for skin
        // Skin typically has warm tones, so we target slightly warm neutral
        let targetR: Float = 0.55
        let targetG: Float = 0.52
        let targetB: Float = 0.48

        // Calculate gain for each channel to normalize colors
        let gainR = avgR > 0 ? targetR / avgR : 1.0
        let gainG = avgG > 0 ? targetG / avgG : 1.0
        let gainB = avgB > 0 ? targetB / avgB : 1.0

        // Clamp gains to reasonable range to avoid over-correction
        let clampedGainR = max(0.7, min(1.5, gainR))
        let clampedGainG = max(0.7, min(1.5, gainG))
        let clampedGainB = max(0.7, min(1.5, gainB))

        // Apply color matrix to correct white balance
        guard let colorMatrixFilter = CIFilter(name: "CIColorMatrix") else { return image }
        colorMatrixFilter.setValue(image, forKey: kCIInputImageKey)

        // R channel
        colorMatrixFilter.setValue(CIVector(x: CGFloat(clampedGainR), y: 0, z: 0, w: 0), forKey: "inputRVector")
        // G channel
        colorMatrixFilter.setValue(CIVector(x: 0, y: CGFloat(clampedGainG), z: 0, w: 0), forKey: "inputGVector")
        // B channel
        colorMatrixFilter.setValue(CIVector(x: 0, y: 0, z: CGFloat(clampedGainB), w: 0), forKey: "inputBVector")
        // A channel (unchanged)
        colorMatrixFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")

        return colorMatrixFilter.outputImage ?? image
    }

    /// Normalize exposure
    private func normalizeExposure(_ image: CIImage, targetBrightness: Float) -> CIImage {
        let currentBrightness = calculateAverageBrightness(ciImage: image)
        let adjustment = targetBrightness / currentBrightness

        guard let filter = CIFilter(name: "CIExposureAdjust") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(log2(adjustment), forKey: kCIInputEVKey)

        return filter.outputImage ?? image
    }

    /// Compensate for shadows - GENTLER version
    private func compensateShadows(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIHighlightShadowAdjust") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.4, forKey: "inputShadowAmount")  // Reduced from 0.7 - gentler lift
        filter.setValue(0.0, forKey: "inputHighlightAmount")

        return filter.outputImage ?? image
    }

    /// Preserve contrast after exposure adjustments
    /// Prevents washed-out appearance from brightness changes
    private func preserveContrast(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.05, forKey: kCIInputContrastKey)  // Slight contrast boost
        filter.setValue(1.0, forKey: kCIInputSaturationKey)  // Keep saturation
        filter.setValue(0.0, forKey: kCIInputBrightnessKey)  // No additional brightness

        return filter.outputImage ?? image
    }
}
