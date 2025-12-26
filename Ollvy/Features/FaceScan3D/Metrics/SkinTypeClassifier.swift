//
//  SkinTypeClassifier.swift
//  Ollvy
//
//  Skin type classification: oily/dry/combination/normal
//  Inferred from texture + specular data
//

import Foundation
import UIKit

/// Skin type classification result
public struct SkinTypeAnalysis: Codable, Sendable {
    let skinType: SkinType
    let confidence: Float  // 0-1
    let oilinessScore: Float  // 0-100
    let drynessScore: Float   // 0-100
    let regionalTypes: [FaceRegion: SkinType]
}

// Note: SkinType enum is defined in UserProfile.swift

/// Skin type classifier
public class SkinTypeClassifier {

    // MARK: - Public API

    /// Classify skin type from texture and specular data
    public func classifySkinType(
        texture: UIImage,
        roughnessScore: Float,
        specularity: Float
    ) -> SkinTypeAnalysis {

        // Calculate oiliness from specular reflectance
        let oilinessScore = calculateOiliness(specularity: specularity, texture: texture)

        // Calculate dryness from roughness and texture
        let drynessScore = calculateDryness(roughness: roughnessScore, texture: texture)

        // Determine overall skin type
        let skinType = determineSkinType(
            oiliness: oilinessScore,
            dryness: drynessScore
        )

        // Calculate confidence
        let confidence = calculateConfidence(oiliness: oilinessScore, dryness: drynessScore)

        // Analyze regional types (T-zone vs cheeks)
        let regionalTypes = analyzeRegionalTypes(texture: texture, roughness: roughnessScore)

        return SkinTypeAnalysis(
            skinType: skinType,
            confidence: confidence,
            oilinessScore: oilinessScore,
            drynessScore: drynessScore,
            regionalTypes: regionalTypes
        )
    }

    // MARK: - Private Methods

    private func calculateOiliness(specularity: Float, texture: UIImage) -> Float {
        // High specular reflectance = oily skin
        var oiliness = specularity * 100

        // Analyze shine in texture
        if let cgImage = texture.cgImage {
            let tZoneShine = analyzeTZoneShine(image: cgImage)
            oiliness = (oiliness + tZoneShine) / 2.0
        }

        return min(100, max(0, oiliness))
    }

    private func calculateDryness(roughness: Float, texture: UIImage) -> Float {
        // High roughness + low specularity = dry skin
        var dryness = roughness

        // Analyze texture for dryness indicators (flaking, scaling)
        if let cgImage = texture.cgImage {
            let textureVariance = analyzeTextureVariance(image: cgImage)
            dryness = (dryness + textureVariance) / 2.0
        }

        return min(100, max(0, dryness))
    }

    private func determineSkinType(oiliness: Float, dryness: Float) -> SkinType {
        // Classification logic
        if oiliness > 60 && dryness < 40 {
            return .oily
        } else if dryness > 60 && oiliness < 40 {
            return .dry
        } else if oiliness > 50 && dryness > 50 {
            return .combination  // Mixed signals = combination
        } else {
            return .normal
        }
    }

    private func calculateConfidence(oiliness: Float, dryness: Float) -> Float {
        // Confidence based on how clear the classification is
        let spread = abs(oiliness - dryness)

        // High spread = clear classification = high confidence
        return min(1.0, spread / 100.0)
    }

    private func analyzeRegionalTypes(texture: UIImage, roughness: Float) -> [FaceRegion: SkinType] {
        guard let cgImage = texture.cgImage else { return [:] }

        var regional: [FaceRegion: SkinType] = [:]

        // Analyze T-zone (forehead, nose)
        let tZoneOiliness = analyzeTZoneShine(image: cgImage)
        let tZoneType = determineSkinType(oiliness: tZoneOiliness, dryness: roughness)
        regional[.forehead] = tZoneType
        // regional[.nose] = tZoneType  // Nose typically same as forehead

        // Analyze cheeks
        let cheekDryness = analyzeCheekTexture(image: cgImage)
        let cheekType = determineSkinType(oiliness: 50, dryness: cheekDryness)
        regional[.cheeks] = cheekType

        return regional
    }

    private func analyzeTZoneShine(image: CGImage) -> Float {
        // Extract T-zone (forehead + nose)
        let foreheadRegion = image.cropping(to: CGRect(
            x: image.width / 3,
            y: image.height / 6,
            width: image.width / 3,
            height: image.height / 6
        ))

        guard let region = foreheadRegion else { return 50 }

        // Calculate brightness (shiny skin = bright)
        let pixels = extractPixels(from: region)
        let avgBrightness = pixels.map { (Float($0.0) + Float($0.1) + Float($0.2)) / 3.0 }.reduce(0, +) / Float(max(pixels.count, 1))

        // Normalize to 0-100
        return min(100, avgBrightness / 255 * 100)
    }

    private func analyzeTextureVariance(image: CGImage) -> Float {
        // High variance = rough/dry texture
        let pixels = extractPixels(from: image)

        let avg = pixels.map { (Float($0.0) + Float($0.1) + Float($0.2)) / 3.0 }.reduce(0, +) / Float(pixels.count)
        let variance = pixels.map { pixel in
            let val = (Float(pixel.0) + Float(pixel.1) + Float(pixel.2)) / 3.0
            return pow(val - avg, 2)
        }.reduce(0, +) / Float(pixels.count)

        // Normalize to 0-100
        return min(100, sqrt(variance))
    }

    private func analyzeCheekTexture(image: CGImage) -> Float {
        // Extract cheek region
        let cheekRegion = image.cropping(to: CGRect(
            x: image.width / 4,
            y: image.height / 2,
            width: image.width / 6,
            height: image.height / 6
        ))

        guard let region = cheekRegion else { return 50 }

        // Analyze texture variance (dry skin = high variance)
        let pixels = extractPixels(from: region)

        let avg = pixels.map { (Float($0.0) + Float($0.1) + Float($0.2)) / 3.0 }.reduce(0, +) / Float(max(pixels.count, 1))
        let variance = pixels.map { pixel in
            let val = (Float(pixel.0) + Float(pixel.1) + Float(pixel.2)) / 3.0
            return pow(val - avg, 2)
        }.reduce(0, +) / Float(max(pixels.count, 1))

        return min(100, sqrt(variance))
    }

    private func extractPixels(from image: CGImage) -> [(UInt8, UInt8, UInt8)] {
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return []
        }

        var pixels: [(UInt8, UInt8, UInt8)] = []
        let bytesPerPixel = 4  // RGBA

        for i in stride(from: 0, to: CFDataGetLength(data), by: bytesPerPixel) {
            let r = bytes[i]
            let g = bytes[i + 1]
            let b = bytes[i + 2]
            pixels.append((r, g, b))
        }

        return pixels
    }
}
