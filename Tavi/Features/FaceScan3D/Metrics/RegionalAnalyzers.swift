//
//  RegionalAnalyzers.swift
//  Tavi
//
//  Specific region analyzers: under-eye darkness, lip texture, nose pores, jawline
//  Comprehensive regional skin analysis
//

import Foundation
import UIKit
import simd

/// Complete regional analysis result
public struct RegionalAnalysis {
    let underEyeDarkness: UnderEyeDarknessAnalysis
    let lipAnalysis: LipAnalysis
    let nosePores: NosePoreAnalysis
    let jawlineDefinition: JawlineAnalysis
}

// MARK: - Under-Eye Darkness

public struct UnderEyeDarknessAnalysis {
    let score: Float  // 0-100, higher = less darkness
    let severity: DarknessSeverity
    let leftEyeDarkness: Float
    let rightEyeDarkness: Float
    let colorDeviation: Float  // From surrounding skin
}

public enum DarknessSeverity: String {
    case none = "None"
    case mild = "Mild"
    case moderate = "Moderate"
    case severe = "Severe"
}

// MARK: - Lip Analysis

public struct LipAnalysis {
    let textureScore: Float  // 0-100
    let volumeScore: Float   // 0-100, fullness
    let symmetryScore: Float // 0-100
    let hydrationLevel: LipHydrationLevel
    let upperLipVolume: Float
    let lowerLipVolume: Float
}

public enum LipHydrationLevel: String {
    case wellHydrated = "Well Hydrated"
    case normal = "Normal"
    case dry = "Dry"
    case veryDry = "Very Dry"
}

// MARK: - Nose Pore Analysis

public struct NosePoreAnalysis {
    let density: Float  // Pores per cm²
    let averageSize: Float  // mm
    let score: Float  // 0-100, lower = better
    let heatmap: [[Float]]  // 2D grid of pore density
}

// MARK: - Jawline Definition

public struct JawlineAnalysis {
    let definition: Float  // 0-100, higher = more defined
    let angle: Float  // Jawline angle in degrees
    let symmetry: Float  // 0-100
    let contour: [SIMD3<Float>]  // 3D jawline contour points
}

/// Regional skin analyzers
public class RegionalAnalyzers {

    // MARK: - Public API

    /// Analyze all regions
    public func analyzeRegions(
        geometry: FaceMeshGeometry,
        texture: UIImage
    ) -> RegionalAnalysis {

        let underEye = analyzeUnderEyeDarkness(texture: texture)
        let lips = analyzeLips(geometry: geometry, texture: texture)
        let nose = analyzeNosePores(texture: texture)
        let jawline = analyzeJawline(geometry: geometry)

        return RegionalAnalysis(
            underEyeDarkness: underEye,
            lipAnalysis: lips,
            nosePores: nose,
            jawlineDefinition: jawline
        )
    }

    // MARK: - Under-Eye Darkness Analysis

    public func analyzeUnderEyeDarkness(texture: UIImage) -> UnderEyeDarknessAnalysis {

        guard let cgImage = texture.cgImage else {
            return defaultUnderEyeAnalysis()
        }

        // Extract under-eye regions
        let leftEyeRegion = extractUnderEyeRegion(image: cgImage, side: .left)
        let rightEyeRegion = extractUnderEyeRegion(image: cgImage, side: .right)

        // Calculate darkness (LAB L* channel)
        let leftDarkness = calculateRegionBrightness(region: leftEyeRegion)
        let rightDarkness = calculateRegionBrightness(region: rightEyeRegion)

        let avgDarkness = (leftDarkness + rightDarkness) / 2.0

        // Compare with surrounding skin (cheeks)
        let cheekBrightness = calculateCheekBrightness(image: cgImage)
        let colorDeviation = abs(avgDarkness - cheekBrightness)

        // Score (less deviation = better)
        let score = max(0, 100 - (colorDeviation / 30 * 100))  // 30 point deviation = 0 score

        // Classify severity
        let severity: DarknessSeverity
        if colorDeviation < 5 {
            severity = .none
        } else if colorDeviation < 15 {
            severity = .mild
        } else if colorDeviation < 25 {
            severity = .moderate
        } else {
            severity = .severe
        }

        return UnderEyeDarknessAnalysis(
            score: score,
            severity: severity,
            leftEyeDarkness: leftDarkness,
            rightEyeDarkness: rightDarkness,
            colorDeviation: colorDeviation
        )
    }

    // MARK: - Lip Analysis

    public func analyzeLips(geometry: FaceMeshGeometry, texture: UIImage) -> LipAnalysis {

        // Extract lip region from geometry
        let lipIndices = getLipIndices()
        let lipVertices = lipIndices.compactMap { index in
            index < geometry.vertices.count ? geometry.vertices[index] : nil
        }

        // Calculate volume (fullness)
        let upperLipVolume = calculateLipVolume(vertices: lipVertices, region: .upper)
        let lowerLipVolume = calculateLipVolume(vertices: lipVertices, region: .lower)

        let totalVolume = upperLipVolume + lowerLipVolume
        let volumeScore = min(100, totalVolume / 2.0 * 100)  // Normalize

        // Calculate symmetry
        let symmetryScore = calculateLipSymmetry(vertices: lipVertices)

        // Analyze texture from image
        guard let cgImage = texture.cgImage else {
            return LipAnalysis(
                textureScore: 60,
                volumeScore: volumeScore,
                symmetryScore: symmetryScore,
                hydrationLevel: .normal,
                upperLipVolume: upperLipVolume,
                lowerLipVolume: lowerLipVolume
            )
        }

        let lipRegion = extractLipRegion(image: cgImage)
        let textureScore = analyzeLipTexture(region: lipRegion)
        let hydration = classifyLipHydration(textureScore: textureScore)

        return LipAnalysis(
            textureScore: textureScore,
            volumeScore: volumeScore,
            symmetryScore: symmetryScore,
            hydrationLevel: hydration,
            upperLipVolume: upperLipVolume,
            lowerLipVolume: lowerLipVolume
        )
    }

    // MARK: - Nose Pore Analysis

    public func analyzeNosePores(texture: UIImage) -> NosePoreAnalysis {

        guard let cgImage = texture.cgImage else {
            return NosePoreAnalysis(
                density: 0,
                averageSize: 0,
                score: 60,
                heatmap: []
            )
        }

        // Extract nose region
        let noseRegion = extractNoseRegion(image: cgImage)

        // Detect pores using high-frequency texture analysis
        let poreDetection = detectPores(in: noseRegion)

        // Calculate density (pores per cm²)
        let areaCm2: Float = 4.0  // Approximate nose area
        let density = Float(poreDetection.count) / areaCm2

        // Calculate average pore size
        let avgSize = poreDetection.map { $0.size }.reduce(0, +) / Float(max(poreDetection.count, 1))

        // Score (lower density and size = better)
        let densityFactor = min(1.0, density / 50.0)  // 50 pores/cm² = max
        let sizeFactor = min(1.0, avgSize / 0.5)  // 0.5mm = max
        let score = (1.0 - (densityFactor + sizeFactor) / 2.0) * 100

        // Create heatmap
        let heatmap = createPoreHeatmap(pores: poreDetection, regionSize: CGSize(width: 100, height: 100))

        return NosePoreAnalysis(
            density: density,
            averageSize: avgSize,
            score: score,
            heatmap: heatmap
        )
    }

    // MARK: - Jawline Analysis

    public func analyzeJawline(geometry: FaceMeshGeometry) -> JawlineAnalysis {

        // Extract jawline vertices
        let jawlineIndices = getJawlineIndices()
        let jawlineVertices = jawlineIndices.compactMap { index in
            index < geometry.vertices.count ? geometry.vertices[index] : nil
        }

        // Calculate definition (how sharp the jawline is)
        let definition = calculateJawlineDefinition(vertices: jawlineVertices)

        // Calculate jawline angle
        let angle = calculateJawlineAngle(vertices: jawlineVertices)

        // Calculate symmetry
        let symmetry = calculateJawlineSymmetry(vertices: jawlineVertices)

        return JawlineAnalysis(
            definition: definition,
            angle: angle,
            symmetry: symmetry,
            contour: jawlineVertices
        )
    }

    // MARK: - Helper Methods

    private func extractUnderEyeRegion(image: CGImage, side: Side) -> CGImage? {
        // Extract ROI for under-eye area
        let width = image.width
        let height = image.height

        let rect: CGRect
        switch side {
        case .left:
            rect = CGRect(x: width / 4, y: height / 3, width: width / 6, height: height / 12)
        case .right:
            rect = CGRect(x: width * 7 / 12, y: height / 3, width: width / 6, height: height / 12)
        }

        return image.cropping(to: rect)
    }

    private func calculateRegionBrightness(region: CGImage?) -> Float {
        guard let region = region else { return 50 }

        // Calculate average LAB L* (brightness)
        // Simplified: use grayscale average
        let pixels = extractPixels(from: region)
        let avgBrightness = pixels.map { Float($0.0 + $0.1 + $0.2) / 3.0 }.reduce(0, +) / Float(max(pixels.count, 1))

        return avgBrightness
    }

    private func calculateCheekBrightness(image: CGImage) -> Float {
        // Extract cheek region and calculate brightness
        let cheekRegion = image.cropping(to: CGRect(
            x: image.width / 3,
            y: image.height / 2,
            width: image.width / 6,
            height: image.height / 6
        ))

        return calculateRegionBrightness(region: cheekRegion)
    }

    private func getLipIndices() -> [Int] {
        // ARKit lip region indices (approximate)
        return Array(600..<700)
    }

    private func calculateLipVolume(vertices: [SIMD3<Float>], region: LipRegion) -> Float {
        // Calculate volume for upper or lower lip
        let filtered = vertices.filter { vertex in
            switch region {
            case .upper:
                return vertex.y > 0  // Upper lip
            case .lower:
                return vertex.y <= 0  // Lower lip
            }
        }

        // Simplified volume calculation
        return Float(filtered.count) * 0.01
    }

    private func calculateLipSymmetry(vertices: [SIMD3<Float>]) -> Float {
        // Compare left and right sides
        let centerX = vertices.map { $0.x }.reduce(0, +) / Float(vertices.count)

        let leftSide = vertices.filter { $0.x < centerX }
        let rightSide = vertices.filter { $0.x >= centerX }

        let sizeDiff = abs(Float(leftSide.count - rightSide.count)) / Float(vertices.count)

        return max(0, (1.0 - sizeDiff) * 100)
    }

    private func extractLipRegion(image: CGImage) -> CGImage? {
        // Extract lip ROI
        let rect = CGRect(
            x: image.width / 3,
            y: image.height * 2 / 3,
            width: image.width / 3,
            height: image.height / 8
        )
        return image.cropping(to: rect)
    }

    private func analyzeLipTexture(region: CGImage?) -> Float {
        guard let region = region else { return 60 }

        // Analyze texture roughness
        let pixels = extractPixels(from: region)

        // Calculate variance (smooth lips = low variance)
        let avg = pixels.map { Float($0.0 + $0.1 + $0.2) / 3.0 }.reduce(0, +) / Float(pixels.count)
        let variance = pixels.map { pixel in
            let val = Float(pixel.0 + pixel.1 + pixel.2) / 3.0
            return pow(val - avg, 2)
        }.reduce(0, +) / Float(pixels.count)

        // Score (lower variance = smoother = better)
        return max(0, 100 - variance)
    }

    private func classifyLipHydration(textureScore: Float) -> LipHydrationLevel {
        if textureScore >= 80 {
            return .wellHydrated
        } else if textureScore >= 60 {
            return .normal
        } else if textureScore >= 40 {
            return .dry
        } else {
            return .veryDry
        }
    }

    private func extractNoseRegion(image: CGImage) -> CGImage? {
        // Extract nose ROI
        let rect = CGRect(
            x: image.width * 5 / 12,
            y: image.height * 5 / 12,
            width: image.width / 6,
            height: image.height / 6
        )
        return image.cropping(to: rect)
    }

    private func detectPores(in region: CGImage?) -> [PoreDetection] {
        guard let region = region else { return [] }

        // High-frequency analysis to detect pores
        let pixels = extractPixels(from: region)

        var pores: [PoreDetection] = []

        // Simplified pore detection (look for small dark spots)
        for (index, pixel) in pixels.enumerated() {
            let brightness = Float(pixel.0 + pixel.1 + pixel.2) / 3.0

            if brightness < 100 {  // Dark spot
                let x = index % region.width
                let y = index / region.width

                pores.append(PoreDetection(
                    x: Float(x),
                    y: Float(y),
                    size: 0.3  // mm (estimated)
                ))
            }
        }

        return pores
    }

    private func createPoreHeatmap(pores: [PoreDetection], regionSize: CGSize) -> [[Float]] {
        // Create 2D heatmap grid
        let gridSize = 20
        var heatmap = Array(repeating: Array(repeating: Float(0), count: gridSize), count: gridSize)

        for pore in pores {
            let gridX = Int(pore.x / Float(regionSize.width) * Float(gridSize))
            let gridY = Int(pore.y / Float(regionSize.height) * Float(gridSize))

            if gridX >= 0 && gridX < gridSize && gridY >= 0 && gridY < gridSize {
                heatmap[gridY][gridX] += 1
            }
        }

        return heatmap
    }

    private func getJawlineIndices() -> [Int] {
        // ARKit jawline region indices (approximate)
        return Array(800..<900)
    }

    private func calculateJawlineDefinition(vertices: [SIMD3<Float>]) -> Float {
        // Calculate how sharp/defined the jawline is
        // Sharp jawline = high gradient in Z (depth)

        var gradients: [Float] = []

        for i in 1..<vertices.count {
            let gradient = abs(vertices[i].z - vertices[i-1].z)
            gradients.append(gradient)
        }

        let avgGradient = gradients.reduce(0, +) / Float(max(gradients.count, 1))

        // Normalize to 0-100 (higher = more defined)
        return min(100, avgGradient * 1000)
    }

    private func calculateJawlineAngle(vertices: [SIMD3<Float>]) -> Float {
        // Calculate jawline angle (gonial angle)
        // Approximate from vertex positions

        guard vertices.count >= 3 else { return 120 }  // Default angle

        let start = vertices.first!
        let mid = vertices[vertices.count / 2]
        let end = vertices.last!

        // Calculate angle between vectors
        let v1 = mid - start
        let v2 = end - mid

        let cosAngle = dot(normalize(v1), normalize(v2))
        let angle = acos(cosAngle) * 180 / .pi

        return angle
    }

    private func calculateJawlineSymmetry(vertices: [SIMD3<Float>]) -> Float {
        // Compare left and right jawline
        let centerX = vertices.map { $0.x }.reduce(0, +) / Float(vertices.count)

        let leftSide = vertices.filter { $0.x < centerX }
        let rightSide = vertices.filter { $0.x >= centerX }

        let sizeDiff = abs(Float(leftSide.count - rightSide.count)) / Float(vertices.count)

        return max(0, (1.0 - sizeDiff) * 100)
    }

    private func extractPixels(from image: CGImage) -> [(UInt8, UInt8, UInt8)] {
        // Extract RGB pixels from image
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

    private func defaultUnderEyeAnalysis() -> UnderEyeDarknessAnalysis {
        return UnderEyeDarknessAnalysis(
            score: 60,
            severity: .mild,
            leftEyeDarkness: 50,
            rightEyeDarkness: 50,
            colorDeviation: 10
        )
    }

    enum Side {
        case left, right
    }

    enum LipRegion {
        case upper, lower
    }

    struct PoreDetection {
        let x: Float
        let y: Float
        let size: Float
    }
}
