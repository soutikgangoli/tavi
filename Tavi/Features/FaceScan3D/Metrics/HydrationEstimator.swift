//
//  HydrationEstimator.swift
//  Tavi
//
//  Hydration estimation from specular reflectance and roughness correlation
//  Not direct measurement but provides relative hydration indicator
//

import UIImage
import simd

/// Hydration estimation result
struct HydrationEstimate {
    let overallScore: Float  // 0-100
    let level: HydrationLevel
    let regionalScores: [String: Float]
    let specularity: Float
    let roughnessCorrelation: Float
}

enum HydrationLevel: String {
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

    // MARK: - Public API

    /// Estimate hydration from texture and roughness
    func estimateHydration(
        texture: UIImage,
        roughnessScore: Float,
        geometry: FaceMeshGeometry
    ) -> HydrationEstimate {

        print("💧 Estimating skin hydration...")

        // Hydrated skin = more specular, smoother
        let specularity = analyzeSpecularity(texture: texture)
        let roughnessCorrelation = 100 - roughnessScore  // Inverse correlation

        // Combined score
        let score = (specularity * 0.6 + roughnessCorrelation * 0.4)

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

        print("✅ Hydration estimate: \(level.rawValue) (\(String(format: "%.1f", score))/100)")

        return HydrationEstimate(
            overallScore: score,
            level: level,
            regionalScores: [:],  // Simplified
            specularity: specularity,
            roughnessCorrelation: roughnessCorrelation
        )
    }

    // MARK: - Private Methods

    private func analyzeSpecularity(texture: UIImage) -> Float {
        // Detect bright specular highlights (hydrated skin reflects more)
        guard let cgImage = texture.cgImage else { return 50 }

        let width = cgImage.width
        let height = cgImage.height

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return 50
        }

        var brightPixels = 0
        let brightnessThreshold: UInt8 = 200
        let totalPixels = width * height

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = ptr[offset]
                let g = ptr[offset + 1]
                let b = ptr[offset + 2]

                // Bright pixels indicate specularity
                if r > brightnessThreshold && g > brightnessThreshold && b > brightnessThreshold {
                    brightPixels += 1
                }
            }
        }

        let specularRatio = Float(brightPixels) / Float(totalPixels)
        return min(100, specularRatio * 1000)  // Scale to 0-100
    }
}
