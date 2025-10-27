//
//  PigmentationMapper.swift
//  Tavi
//
//  Color variance and pigmentation evenness analysis
//  Maps skin tone uniformity and detects hyperpigmentation
//

import UIKit
import CoreImage

/// Pigmentation analysis result
struct PigmentationAnalysis {
    let evenness: Float  // 0-100, higher is better
    let variance: Float
    let darkSpots: Int
    let regionalScores: [String: Float]
    let colorMap: UIImage?
}

/// Pigmentation analyzer
class PigmentationMapper {

    // MARK: - Public API

    /// Analyze pigmentation from texture
    func analyzePigmentation(texture: UIImage) -> PigmentationAnalysis {
        print("🎨 Analyzing pigmentation...")

        // Calculate color variance
        let variance = calculateColorVariance(image: texture)

        // Detect dark spots
        let darkSpots = detectDarkSpots(image: texture)

        // Calculate evenness (inverse of variance)
        let evenness = max(0, 100 - variance * 100)

        print("✅ Pigmentation evenness: \(String(format: "%.1f", evenness))/100")
        print("   Dark spots detected: \(darkSpots)")

        return PigmentationAnalysis(
            evenness: evenness,
            variance: variance,
            darkSpots: darkSpots,
            regionalScores: [:],
            colorMap: nil
        )
    }

    // MARK: - Private Methods

    /// Calculate color variance across image
    private func calculateColorVariance(image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 0.5 }

        let width = cgImage.width
        let height = cgImage.height

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return 0.5
        }

        var rValues: [Float] = []
        var gValues: [Float] = []
        var bValues: [Float] = []

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                rValues.append(Float(ptr[offset]) / 255.0)
                gValues.append(Float(ptr[offset + 1]) / 255.0)
                bValues.append(Float(ptr[offset + 2]) / 255.0)
            }
        }

        // Calculate variance for each channel
        let rVariance = calculateVariance(rValues)
        let gVariance = calculateVariance(gValues)
        let bVariance = calculateVariance(bValues)

        return (rVariance + gVariance + bVariance) / 3.0
    }

    /// Calculate variance of array
    private func calculateVariance(_ values: [Float]) -> Float {
        let mean = values.reduce(0, +) / Float(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Float(values.count)
    }

    /// Detect dark spots (hyperpigmentation)
    private func detectDarkSpots(image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }

        let width = cgImage.width
        let height = cgImage.height

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return 0
        }

        // Calculate average brightness
        var totalBrightness: Float = 0
        let totalPixels = width * height

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = Float(ptr[offset]) / 255.0
                let g = Float(ptr[offset + 1]) / 255.0
                let b = Float(ptr[offset + 2]) / 255.0

                // Perceived brightness
                let brightness = 0.299 * r + 0.587 * g + 0.114 * b
                totalBrightness += brightness
            }
        }

        let avgBrightness = totalBrightness / Float(totalPixels)
        let darkThreshold = avgBrightness * 0.7  // 30% darker than average

        // Count dark spots
        var darkPixels = 0
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = Float(ptr[offset]) / 255.0
                let g = Float(ptr[offset + 1]) / 255.0
                let b = Float(ptr[offset + 2]) / 255.0

                let brightness = 0.299 * r + 0.587 * g + 0.114 * b

                if brightness < darkThreshold {
                    darkPixels += 1
                }
            }
        }

        // Estimate number of spots (cluster dark pixels)
        let darkRatio = Float(darkPixels) / Float(totalPixels)
        return Int(darkRatio * 100)  // Approximation
    }
}
