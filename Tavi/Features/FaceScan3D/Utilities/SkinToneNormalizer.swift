//
//  SkinToneNormalizer.swift
//  Tavi
//
//  Normalizes pigmentation metrics across diverse skin tones
//  Uses LAB color space to account for different skin tone lightness levels
//  NO ML REQUIRED - uses color science principles
//

import UIKit
import simd

/// Detected skin tone category (simplified Fitzpatrick scale)
public enum SkinToneCategory: String, Codable, Sendable, CustomStringConvertible {
    case veryLight      // Fitzpatrick I
    case light          // Fitzpatrick II
    case medium         // Fitzpatrick III
    case mediumDark     // Fitzpatrick IV
    case dark           // Fitzpatrick V
    case veryDark       // Fitzpatrick VI

    public var description: String {
        return rawValue
    }

    var referenceL: Float {
        // Reference L* values in LAB space for each skin tone
        switch self {
        case .veryLight: return 85.0      // Very light skin
        case .light: return 75.0          // Light skin
        case .medium: return 65.0         // Medium skin
        case .mediumDark: return 55.0     // Medium-dark skin
        case .dark: return 45.0           // Dark skin
        case .veryDark: return 35.0       // Very dark skin
        }
    }

    // REMOVED: pigmentationScaleFactor
    // Old approach reduced scores for dark skin (unfair - could hide real issues)
    // New approach: Detect RELATIVE changes from baseline (fair for all skin tones)
}

/// Normalizes pigmentation and color metrics for diverse skin tones
public class SkinToneNormalizer {

    // MARK: - Public API

    /// Detect skin tone category from texture
    /// IMPROVED: Better thresholds for Indian/South Asian skin tones (L* 45-65)
    public func detectSkinTone(texture: UIImage) -> SkinToneCategory {
        // Sample central face region (avoid background)
        let averageLAB = calculateAverageLAB(image: texture, centralRegionOnly: true)

        // Classify based on L* (lightness) value
        // Thresholds refined to better distinguish Indian skin tones
        let L = averageLAB.l

        if L > 78 {
            return .veryLight  // Fitzpatrick I
        } else if L > 68 {
            return .light      // Fitzpatrick II
        } else if L > 58 {
            return .medium     // Fitzpatrick III (lighter Indian)
        } else if L > 48 {
            return .mediumDark // Fitzpatrick IV (most Indian skin tones)
        } else if L > 38 {
            return .dark       // Fitzpatrick V (darker Indian)
        } else {
            return .veryDark   // Fitzpatrick VI
        }
    }

    /// Normalize pigmentation score for skin tone
    /// NEW APPROACH: Scores represent RELATIVE variation from baseline
    /// A score of 60 means "moderate pigmentation variation" for ANY skin tone
    public func normalizePigmentationScore(
        rawScore: Float,
        skinTone: SkinToneCategory
    ) -> Float {
        // NO scale factors - raw score already represents relative variation
        // Pigmentation analysis should detect LOCAL differences (spots, patches)
        // not penalize overall skin darkness

        // Just ensure score stays in valid range
        return min(100, max(0, rawScore))
    }

    /// Normalize discoloration score for skin tone
    /// NEW APPROACH: Scores represent RELATIVE variation from baseline
    /// Discoloration detection should identify ABNORMAL patches (melasma, PIH, vitiligo)
    /// not penalize natural skin tone variation
    public func normalizeDiscolorationScore(
        rawScore: Float,
        skinTone: SkinToneCategory
    ) -> Float {
        // NO scale factors - discoloration means "different from person's baseline"
        // Whether baseline is light or dark doesn't matter
        // A dark skin person with melasma should get same score as light skin with melasma

        // Just ensure score stays in valid range
        return min(100, max(0, rawScore))
    }

    /// Get recommended thresholds for this skin tone
    /// NEW APPROACH: Uniform thresholds since scores represent relative variation
    public func getThresholds(for skinTone: SkinToneCategory) -> (pigmentationThreshold: Float, discolorationThreshold: Float) {
        // SAME threshold for all skin tones (fair approach)
        // A score of 60 means "moderate concern" regardless of baseline skin color
        // This ensures equal sensitivity to real pigmentation issues across all Fitzpatrick types

        return (pigmentationThreshold: 60, discolorationThreshold: 60)
    }

    // MARK: - Private Methods

    /// Calculate average LAB color for image
    private func calculateAverageLAB(image: UIImage, centralRegionOnly: Bool) -> (l: Float, a: Float, b: Float) {
        guard let cgImage = image.cgImage else {
            return (l: 70, a: 0, b: 0) // Default
        }

        let width = cgImage.width
        let height = cgImage.height

        // Define sampling region (central 50% to avoid background)
        let sampleRect: CGRect
        if centralRegionOnly {
            let centerX = width / 2
            let centerY = height / 2
            let sampleWidth = width / 2
            let sampleHeight = height / 2
            sampleRect = CGRect(
                x: centerX - sampleWidth / 2,
                y: centerY - sampleHeight / 2,
                width: sampleWidth,
                height: sampleHeight
            )
        } else {
            sampleRect = CGRect(x: 0, y: 0, width: width, height: height)
        }

        // Extract RGB data
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

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Sample pixels in region and convert to LAB
        var totalL: Float = 0
        var totalA: Float = 0
        var totalB: Float = 0
        var count: Int = 0

        let startX = Int(sampleRect.minX)
        let endX = Int(sampleRect.maxX)
        let startY = Int(sampleRect.minY)
        let endY = Int(sampleRect.maxY)

        for y in startY..<endY {
            for x in startX..<endX {
                let index = (y * width + x) * 4
                let r = Float(rgbData[index]) / 255.0
                let g = Float(rgbData[index + 1]) / 255.0
                let b = Float(rgbData[index + 2]) / 255.0

                // Convert RGB to LAB
                let lab = rgbToLAB(r: r, g: g, b: b)
                totalL += lab.l
                totalA += lab.a
                totalB += lab.b
                count += 1
            }
        }

        guard count > 0 else {
            return (l: 70, a: 0, b: 0)
        }

        return (
            l: totalL / Float(count),
            a: totalA / Float(count),
            b: totalB / Float(count)
        )
    }

    /// Convert RGB to LAB color space
    private func rgbToLAB(r: Float, g: Float, b: Float) -> (l: Float, a: Float, b: Float) {
        // First convert RGB to XYZ
        let rLinear = r <= 0.04045 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let gLinear = g <= 0.04045 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let bLinear = b <= 0.04045 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)

        // Convert to XYZ (D65 illuminant)
        var x = rLinear * 0.4124 + gLinear * 0.3576 + bLinear * 0.1805
        var y = rLinear * 0.2126 + gLinear * 0.7152 + bLinear * 0.0722
        var z = rLinear * 0.0193 + gLinear * 0.1192 + bLinear * 0.9505

        // Normalize for D65 white point
        x = x / 0.95047
        y = y / 1.00000
        z = z / 1.08883

        // Convert XYZ to LAB
        let fx = x > 0.008856 ? pow(x, 1.0/3.0) : (7.787 * x + 16.0/116.0)
        let fy = y > 0.008856 ? pow(y, 1.0/3.0) : (7.787 * y + 16.0/116.0)
        let fz = z > 0.008856 ? pow(z, 1.0/3.0) : (7.787 * z + 16.0/116.0)

        let L = 116.0 * fy - 16.0
        let A = 500.0 * (fx - fy)
        let B = 200.0 * (fy - fz)

        return (l: L, a: A, b: B)
    }
}
