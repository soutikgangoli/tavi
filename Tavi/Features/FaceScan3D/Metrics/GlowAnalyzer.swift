//
//  GlowAnalyzer.swift
//  Tavi
//
//  Differentiated glow (overall health) vs radiance (pure luminosity) analysis
//  Created on 2025-10-29.
//
//  NOTE: GlowAnalysis struct is defined in Face3DMetrics.swift
//

import UIKit
import Accelerate
import simd

/// Analyzes skin glow (overall health) and radiance (pure luminosity)
public class GlowAnalyzer {

    // MARK: - Configuration

    private struct Configuration {
        // Glow formula weights
        static let smoothnessWeight: Float = 0.40
        static let evennessWeight: Float = 0.30
        static let discolorationWeight: Float = 0.20
        static let specularWeight: Float = 0.10

        // Radiance formula weights
        static let labLightnessWeight: Float = 0.70
        static let specularHighlightWeight: Float = 0.30

        // Specular detection threshold (0-1, brightness level)
        static let specularBrightnessThreshold: Float = 0.85
    }

    // MARK: - Public API

    /// Analyze glow and radiance from texture and existing metrics
    public func analyzeGlow(
        texture: UIImage,
        geometry: FaceMeshGeometry,
        existingMetrics: Face3DMetrics,
        specularAnalyzer: SpecularAnalyzer
    ) -> GlowAnalysis {

        print("✨ Analyzing skin glow and radiance...")

        // PART 1: GLOW SCORE (Overall Health Index)
        // Uses existing computed metrics - no new computation needed

        let smoothness = existingMetrics.globalRoughnessScore
        let evenness = existingMetrics.globalPigmentationScore
        let discoloration = existingMetrics.globalDiscolorationScore
        let specular = existingMetrics.globalSpecularScore ?? computeDefaultSpecular(from: texture)

        // Compute glow score with weighted formula
        let glowScore = (
            smoothness * Configuration.smoothnessWeight +
            evenness * Configuration.evennessWeight +
            discoloration * Configuration.discolorationWeight +
            specular * Configuration.specularWeight
        )

        print("   Glow Score (Health Index): \(String(format: "%.1f", glowScore))/100")
        print("     - Smoothness contribution: \(String(format: "%.1f", smoothness * Configuration.smoothnessWeight))")
        print("     - Evenness contribution: \(String(format: "%.1f", evenness * Configuration.evennessWeight))")
        print("     - Discoloration contribution: \(String(format: "%.1f", discoloration * Configuration.discolorationWeight))")
        print("     - Specular contribution: \(String(format: "%.1f", specular * Configuration.specularWeight))")

        // PART 2: RADIANCE SCORE (Pure Luminosity)
        // Physics-based brightness measurement using LAB color space

        let labLightness = analyzeLABLightness(texture: texture)
        let specularRatio = analyzeSpecularHighlights(texture: texture)
        let luminosityIndex = (labLightness * 100.0)  // Convert L* (0-1) to 0-100 scale

        // Compute radiance score (pure brightness)
        let radianceScore = (
            labLightness * Configuration.labLightnessWeight +
            specularRatio * Configuration.specularHighlightWeight
        ) * 100.0  // Scale to 0-100

        print("   Radiance Score (Luminosity): \(String(format: "%.1f", radianceScore))/100")
        print("     - LAB L* lightness: \(String(format: "%.1f", labLightness * 100))%")
        print("     - Specular highlights: \(String(format: "%.1f", specularRatio * 100))%")

        // PART 3: Regional Analysis

        let regionalGlow = computeRegionalGlow(
            existingMetrics: existingMetrics
        )

        let regionalRadiance = computeRegionalRadiance(
            texture: texture,
            geometry: geometry
        )

        // PART 4: Confidence

        let confidence = computeConfidence(
            textureQuality: existingMetrics.textureQuality,
            labLightness: labLightness,
            specularRatio: specularRatio
        )

        print("✅ Glow and radiance analysis complete (confidence: \(String(format: "%.0f", confidence))%)")

        return GlowAnalysis(
            glowScore: glowScore,
            radianceScore: radianceScore,
            smoothnessContribution: smoothness * Configuration.smoothnessWeight,
            evennessContribution: evenness * Configuration.evennessWeight,
            discolorationContribution: discoloration * Configuration.discolorationWeight,
            specularContribution: specular * Configuration.specularWeight,
            labLightness: labLightness,
            specularHighlightRatio: specularRatio,
            luminosityIndex: luminosityIndex,
            regionalGlow: regionalGlow,
            regionalRadiance: regionalRadiance,
            confidence: confidence
        )
    }

    // MARK: - LAB Lightness Analysis (Physics-Based)

    /// Analyze LAB color space L* channel (lightness)
    /// This is a perceptually uniform measure of brightness
    private func analyzeLABLightness(texture: UIImage) -> Float {
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

                // Convert RGB to LAB L* (simplified approximation)
                // Full LAB conversion requires XYZ intermediate step
                // This uses CIE luminance as proxy for L*
                let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b

                // Approximate L* from luminance
                // L* = 116 * f(Y/Yn) - 16, where f(t) = t^(1/3) for t > 0.008856
                let lStar: Float
                if luminance > 0.008856 {
                    lStar = 116.0 * pow(luminance, 1.0/3.0) - 16.0
                } else {
                    lStar = 903.3 * luminance
                }

                // L* is in range 0-100, normalize to 0-1
                totalLightness += lStar / 100.0
                pixelCount += 1
            }
        }

        let averageLightness = pixelCount > 0 ? totalLightness / Float(pixelCount) : 0.5

        // Clamp to 0-1 range
        return max(0, min(1, averageLightness))
    }

    // MARK: - Specular Highlight Analysis

    /// Detect bright specular highlights (shiny spots)
    private func analyzeSpecularHighlights(texture: UIImage) -> Float {
        guard let cgImage = texture.cgImage else { return 0 }

        let width = cgImage.width
        let height = cgImage.height

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return 0
        }

        var brightPixelCount = 0
        let totalPixels = width * height

        // Count very bright pixels (specular highlights)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                guard offset + 2 < CFDataGetLength(data) else { continue }

                let r = Float(ptr[offset]) / 255.0
                let g = Float(ptr[offset + 1]) / 255.0
                let b = Float(ptr[offset + 2]) / 255.0

                // Calculate brightness
                let brightness = (r + g + b) / 3.0

                if brightness > Configuration.specularBrightnessThreshold {
                    brightPixelCount += 1
                }
            }
        }

        let specularRatio = Float(brightPixelCount) / Float(totalPixels)

        // Clamp to reasonable range (0-0.3, most skin has <30% specular)
        return min(0.3, specularRatio) / 0.3  // Normalize to 0-1
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
    private func computeConfidence(
        textureQuality: String?,
        labLightness: Float,
        specularRatio: Float
    ) -> Float {
        var confidence: Float = 85.0  // Base confidence for direct measurement

        // Factor 1: Texture quality
        if textureQuality?.contains("warning") == true {
            confidence -= 15
        } else if textureQuality?.contains("Good") == true {
            confidence += 10
        }

        // Factor 2: Lighting conditions (via LAB lightness)
        if labLightness < 0.2 {
            // Too dark
            confidence -= 20
        } else if labLightness > 0.9 {
            // Too bright/overexposed
            confidence -= 15
        } else if labLightness >= 0.4 && labLightness <= 0.7 {
            // Optimal lighting range
            confidence += 5
        }

        // Factor 3: Specular consistency
        if specularRatio > 0.8 {
            // Too much specular (very oily or overlit)
            confidence -= 10
        }

        // Clamp to 50-95 range
        return max(50, min(95, confidence))
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
