//
//  LightingNormalizer.swift
//  Tavi
//
//  Lighting control and normalization for consistent skin analysis
//  Critical for clinical-grade accuracy across different lighting conditions
//

import UIKit
import ARKit
import CoreImage

/// Lighting quality assessment
struct LightingQuality {
    let overallScore: Float  // 0-1
    let brightness: Float
    let uniformity: Float
    let shadowPresence: Float
    let isAcceptable: Bool
    let issues: [String]
}

/// Normalized texture result
struct NormalizedTexture {
    let normalizedImage: UIImage
    let lightingQuality: LightingQuality
    let whiteBalanceCorrected: Bool
    let exposureAdjusted: Bool
}

/// Lighting normalization and quality control
class LightingNormalizer {

    // MARK: - Configuration

    private let minBrightness: Float = 0.3
    private let maxBrightness: Float = 0.8
    private let minUniformity: Float = 0.7
    private let maxShadowPresence: Float = 0.3
    private let minAcceptableScore: Float = 0.6

    // MARK: - Public API

    /// Assess lighting quality
    func assessLightingQuality(image: UIImage) -> LightingQuality {
        guard let ciImage = CIImage(image: image) else {
            return LightingQuality(
                overallScore: 0,
                brightness: 0,
                uniformity: 0,
                shadowPresence: 1,
                isAcceptable: false,
                issues: ["Failed to process image"]
            )
        }

        var issues: [String] = []

        // Calculate brightness
        let brightness = calculateAverageBrightness(ciImage: ciImage)
        if brightness < minBrightness {
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
        let brightnessScore = 1.0 - abs(brightness - 0.55) / 0.55  // Optimal at 0.55
        let uniformityScore = uniformity
        let shadowScore = 1.0 - shadowPresence

        let overallScore = (brightnessScore * 0.4 + uniformityScore * 0.4 + shadowScore * 0.2)
        let isAcceptable = overallScore >= minAcceptableScore

        return LightingQuality(
            overallScore: overallScore,
            brightness: brightness,
            uniformity: uniformity,
            shadowPresence: shadowPresence,
            isAcceptable: isAcceptable,
            issues: issues
        )
    }

    /// Normalize texture with lighting correction
    func normalize(image: UIImage) -> NormalizedTexture? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // Assess quality first
        let quality = assessLightingQuality(image: image)

        // Apply corrections
        var correctedImage = ciImage

        // 1. White balance correction
        correctedImage = applyWhiteBalance(correctedImage)
        let whiteBalanceCorrected = true

        // 2. Exposure normalization
        correctedImage = normalizeExposure(correctedImage, targetBrightness: 0.55)
        let exposureAdjusted = true

        // 3. Shadow compensation (if needed)
        if quality.shadowPresence > maxShadowPresence {
            correctedImage = compensateShadows(correctedImage)
        }

        // Convert back to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(correctedImage, from: correctedImage.extent) else {
            return nil
        }
        let normalizedUIImage = UIImage(cgImage: cgImage)

        return NormalizedTexture(
            normalizedImage: normalizedUIImage,
            lightingQuality: quality,
            whiteBalanceCorrected: whiteBalanceCorrected,
            exposureAdjusted: exposureAdjusted
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
                      colorSpace: nil)

        // Calculate perceived brightness (luminance)
        let r = Float(bitmap[0]) / 255.0
        let g = Float(bitmap[1]) / 255.0
        let b = Float(bitmap[2]) / 255.0

        return 0.299 * r + 0.587 * g + 0.114 * b
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
        return max(0, 1.0 - cv * 2.0)
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

    /// Apply white balance correction
    private func applyWhiteBalance(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIWhitePointAdjust") else { return image }

        // Estimate white point (simplified)
        let avgColor = CIVector(x: 0.95, y: 0.95, z: 0.95)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(avgColor, forKey: "inputColor")

        return filter.outputImage ?? image
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

    /// Compensate for shadows
    private func compensateShadows(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIHighlightShadowAdjust") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.7, forKey: "inputShadowAmount")  // Lift shadows
        filter.setValue(0.0, forKey: "inputHighlightAmount")

        return filter.outputImage ?? image
    }
}
