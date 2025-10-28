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

/// Hydration estimation result (indirect measurement)
struct HydrationEstimate {
    let overallScore: Float  // 0-100 (estimated hydration indicator)
    let level: HydrationLevel
    let regionalScores: [String: Float]

    // Multi-method ensemble components
    let specularityScore: Float     // Method 1: Reflectance analysis
    let textureScore: Float          // Method 2: High-frequency texture analysis
    let varianceScore: Float         // Method 3: Color uniformity analysis

    let confidence: Float  // 0-100, reliability of estimate based on conditions
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

    /// Estimate hydration using multi-method ensemble
    /// Method 1: Specularity (reflectance)
    /// Method 2: Texture frequency (smoothness)
    /// Method 3: Color variance (uniformity)
    func estimateHydration(
        texture: UIImage,
        roughnessScore: Float,
        geometry: FaceMeshGeometry
    ) -> HydrationEstimate {

        print("💧 Estimating skin hydration (multi-method ensemble)...")

        // Method 1: Specularity analysis (hydrated skin reflects more light)
        let specularityScore = analyzeSpecularity(texture: texture)
        print("   Method 1 (Specularity): \(String(format: "%.1f", specularityScore))/100")

        // Method 2: Texture frequency analysis (hydrated skin is smoother)
        let textureScore = analyzeTextureFrequency(texture: texture)
        print("   Method 2 (Texture): \(String(format: "%.1f", textureScore))/100")

        // Method 3: Color variance analysis (hydrated skin is more uniform)
        let varianceScore = analyzeColorVariance(texture: texture)
        print("   Method 3 (Variance): \(String(format: "%.1f", varianceScore))/100")

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
            texture: texture,
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

        print("✅ Hydration estimate: \(level.rawValue) (\(String(format: "%.1f", score))/100)")
        print("   Confidence: \(String(format: "%.0f", confidence))% (indirect measurement)")
        print("   ⚠️  Note: Indirect estimate based on ensemble of 3 methods, not direct water content")
        print("   Regional scores: \(regionalScores.count) regions")

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
        let textureScore = max(0, 100 - (avgEnergy * 500))  // Scale to 0-100
        return min(100, textureScore)
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

                // Luminance (perceived brightness)
                let intensity = 0.299 * r + 0.587 * g + 0.114 * b
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
    private func analyzeSpecularityInRegion(image: CGImage) -> Float {
        let width = image.width
        let height = image.height

        guard let dataProvider = image.dataProvider,
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

                // Luminance
                let intensity = 0.299 * r + 0.587 * g + 0.114 * b
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
        var confidence: Float = 60.0  // Base confidence for indirect measurement

        // Factor 1: Lighting conditions (via specularity)
        if specularity < 10 {
            // Too dark/underlit - low specularity readings
            confidence -= 20
        } else if specularity > 90 {
            // Overlit - excessive specularity may indicate artificial lighting/flash
            confidence -= 15
        } else if specularity >= 20 && specularity <= 70 {
            // Good lighting range
            confidence += 10
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
                // High variance = inconsistent = lower confidence
                confidence -= 10
            }
        }

        // Factor 3: Method agreement (NEW for ensemble)
        // High agreement between methods = higher confidence
        if methodAgreement >= 80 {
            confidence += 15  // Strong agreement
        } else if methodAgreement >= 60 {
            confidence += 10  // Good agreement
        } else if methodAgreement < 40 {
            confidence -= 15  // Poor agreement (methods disagree)
        }

        // Clamp between 30-80% (slightly higher max due to ensemble reliability)
        return max(30, min(80, confidence))
    }
}
