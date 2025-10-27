//
//  PoreAnalyzer.swift
//  Tavi
//
//  Pore detection and analysis using texture frequency analysis
//  High-frequency texture components indicate visible pores
//

import UIKit
import Accelerate

/// Pore analysis result
struct PoreAnalysis {
    let visibility: Float  // 0-100, lower is better
    let density: Float     // pores per cm²
    let averageSize: Float // in pixels
    let regionalScores: [String: Float]
}

/// Pore analyzer using texture frequency analysis
class PoreAnalyzer {

    // MARK: - Public API

    /// Analyze pore visibility from high-resolution texture
    func analyzePores(texture: UIImage) -> PoreAnalysis {
        print("🔬 Analyzing pore visibility...")

        // High-frequency texture energy correlates with visible pores
        let highFreqEnergy = calculateHighFrequencyEnergy(image: texture)

        // Convert to visibility score (0-100)
        let visibility = min(100, highFreqEnergy * 10)

        print("✅ Pore visibility: \(String(format: "%.1f", visibility))/100")

        return PoreAnalysis(
            visibility: visibility,
            density: 0,  // Simplified
            averageSize: 0,  // Simplified
            regionalScores: [:]
        )
    }

    // MARK: - Private Methods

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
        var floatData = grayData.map { Float($0) / 255.0 }

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
}
