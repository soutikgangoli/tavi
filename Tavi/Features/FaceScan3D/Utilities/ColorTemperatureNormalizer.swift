//
//  ColorTemperatureNormalizer.swift
//  Tavi
//
//  Normalizes for different lighting conditions (natural, fluorescent, warm, etc.)
//  Uses white balance correction to account for color temperature variations
//  NO ML REQUIRED - uses color science and gray world assumption
//

import UIKit
import CoreImage

/// Normalizes images for different color temperatures and lighting conditions
public class ColorTemperatureNormalizer {

    private let skinToneNormalizer = SkinToneNormalizer()

    // MARK: - Color Temperature Detection

    /// Detected lighting type
    public enum LightingType: String, Codable {
        case daylight       // ~5500-6500K (neutral)
        case warmLight      // ~2700-3500K (incandescent, warm LED)
        case coolLight      // ~4000-5000K (fluorescent, cool LED)
        case mixedLight     // Multiple sources detected
        case unknown

        var colorTemperature: CGFloat {
            switch self {
            case .daylight: return 6000
            case .warmLight: return 3000
            case .coolLight: return 4500
            case .mixedLight: return 5500
            case .unknown: return 6000
            }
        }

        var description: String {
            switch self {
            case .daylight: return "Natural daylight"
            case .warmLight: return "Warm indoor lighting"
            case .coolLight: return "Cool indoor lighting"
            case .mixedLight: return "Mixed lighting"
            case .unknown: return "Unknown lighting"
            }
        }
    }

    // MARK: - Public API

    /// Detect lighting type from ARKit light estimation
    public func detectLightingType(
        ambientColorTemperature: CGFloat?
    ) -> LightingType {
        guard let temp = ambientColorTemperature else {
            return .unknown
        }

        // Classify based on color temperature (in Kelvin)
        if temp >= 5500 && temp <= 6500 {
            return .daylight
        } else if temp >= 2700 && temp < 4000 {
            return .warmLight
        } else if temp >= 4000 && temp < 5500 {
            return .coolLight
        } else {
            return .mixedLight
        }
    }

    /// Apply white balance correction to normalize color temperature
    /// IMPROVED: Skin-tone-aware target temperature (preserves natural undertones)
    public func normalizeColorTemperature(
        image: UIImage,
        currentColorTemp: CGFloat,
        targetColorTemp: CGFloat? = nil,  // Optional override
        skinTone: SkinToneCategory? = nil
    ) -> UIImage? {
        guard let inputCG = image.cgImage else { return image }

        let context = CIContext()
        let inputImage = CIImage(cgImage: inputCG)

        // Determine adaptive target temperature based on skin tone
        let adaptiveTarget: CGFloat
        if let target = targetColorTemp {
            adaptiveTarget = target
        } else if let tone = skinTone {
            // Indian skin has warmer undertones - preserve some warmth
            switch tone {
            case .veryLight, .light:
                adaptiveTarget = 6000  // Standard daylight
            case .medium, .mediumDark:
                adaptiveTarget = 5800  // Slightly warmer to preserve golden undertones
            case .dark, .veryDark:
                adaptiveTarget = 5600  // More warmth preservation
            }
        } else {
            adaptiveTarget = 6000  // Default
        }

        // Calculate temperature adjustment
        let tempDelta = (adaptiveTarget - currentColorTemp) / 1000.0

        // Apply white balance filter
        guard let filter = CIFilter(name: "CITemperatureAndTint") else {
            AppLogger.metrics.warning("Temperature filter not available")
            return image
        }

        filter.setValue(inputImage, forKey: kCIInputImageKey)

        // Temperature adjustment (mapped to filter values)
        // Positive = cooler, Negative = warmer
        let tempAdjustment = CIVector(x: tempDelta * 1000, y: 0)
        filter.setValue(tempAdjustment, forKey: "inputNeutral")

        guard let outputImage = filter.outputImage,
              let outputCG = context.createCGImage(outputImage, from: outputImage.extent) else {
            AppLogger.metrics.warning("Failed to apply temperature correction")
            return image
        }

        AppLogger.metrics.info("Applied color temperature normalization: \(Int(currentColorTemp))K → \(Int(adaptiveTarget))K")
        return UIImage(cgImage: outputCG)
    }

    /// Estimate color temperature from image (gray world assumption)
    public func estimateColorTemperature(from image: UIImage) -> CGFloat {
        guard let cgImage = image.cgImage else { return 6000 }

        // Sample average RGB from central region
        let avgRGB = sampleAverageRGB(image: cgImage)

        // Calculate R/B ratio (warm light has higher R, cool light has higher B)
        let rbRatio = avgRGB.r / max(avgRGB.b, 0.01)

        // Map R/B ratio to color temperature (empirical)
        let estimatedTemp: CGFloat
        if rbRatio > 1.3 {
            // Warm light (more red)
            estimatedTemp = 3000 + (1.5 - rbRatio) * 1000
        } else if rbRatio < 0.9 {
            // Cool light (more blue)
            estimatedTemp = 5000 + (1.0 - rbRatio) * 1500
        } else {
            // Neutral
            estimatedTemp = 5500
        }

        return max(2500, min(7000, estimatedTemp))
    }

    /// Check if lighting is consistent across multiple frames
    public func checkLightingConsistency(
        temperatures: [CGFloat],
        tolerance: CGFloat = 500  // Kelvin
    ) -> (isConsistent: Bool, avgTemp: CGFloat, variance: CGFloat) {
        guard !temperatures.isEmpty else {
            return (isConsistent: false, avgTemp: 6000, variance: 0)
        }

        let avg = temperatures.reduce(0, +) / CGFloat(temperatures.count)
        let variance = temperatures.map { pow($0 - avg, 2) }.reduce(0, +) / CGFloat(temperatures.count)
        let stdDev = sqrt(variance)

        let isConsistent = stdDev <= tolerance

        return (isConsistent: isConsistent, avgTemp: avg, variance: stdDev)
    }

    // MARK: - Private Methods

    /// Sample average RGB from image
    private func sampleAverageRGB(image: CGImage) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let width = image.width
        let height = image.height

        // Sample central 50% region
        let sampleWidth = width / 2
        let sampleHeight = height / 2
        let startX = (width - sampleWidth) / 2
        let startY = (height - sampleHeight) / 2

        var rgbData = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &rgbData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var count: CGFloat = 0

        for y in startY..<(startY + sampleHeight) {
            for x in startX..<(startX + sampleWidth) {
                let index = (y * width + x) * 4
                totalR += CGFloat(rgbData[index])
                totalG += CGFloat(rgbData[index + 1])
                totalB += CGFloat(rgbData[index + 2])
                count += 1
            }
        }

        guard count > 0 else {
            return (r: 128, g: 128, b: 128)
        }

        return (
            r: totalR / count / 255.0,
            g: totalG / count / 255.0,
            b: totalB / count / 255.0
        )
    }
}
