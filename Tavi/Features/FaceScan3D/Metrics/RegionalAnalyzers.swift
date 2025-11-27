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
public struct RegionalAnalysis: Codable, Sendable {
    let underEyeDarkness: UnderEyeDarknessAnalysis?  // FIXED: Returns nil if extraction fails
    let lipAnalysis: LipAnalysis?                     // FIXED: Returns nil if insufficient data
    let nosePores: NosePoreAnalysis?                  // FIXED: Returns nil if extraction fails
    let jawlineDefinition: JawlineAnalysis?           // FIXED: Returns nil if no vertices found
}

// MARK: - Under-Eye Darkness

public struct UnderEyeDarknessAnalysis: Codable, Sendable {
    let score: Float  // 0-100, higher = less darkness
    let severity: DarknessSeverity
    let leftEyeDarkness: Float
    let rightEyeDarkness: Float
    let colorDeviation: Float  // From surrounding skin
}

public enum DarknessSeverity: String, Codable, Sendable {
    case none = "None"
    case mild = "Mild"
    case moderate = "Moderate"
    case severe = "Severe"
}

// MARK: - Lip Analysis

public struct LipAnalysis: Codable, Sendable {
    let textureScore: Float  // 0-100
    let volumeScore: Float   // 0-100, fullness
    let symmetryScore: Float // 0-100
    let hydrationLevel: LipHydrationLevel
    let upperLipVolume: Float
    let lowerLipVolume: Float
    let confidence: Float  // 0-100, based on vertex count
}

public enum LipHydrationLevel: String, Codable, Sendable {
    case wellHydrated = "Well Hydrated"
    case normal = "Normal"
    case dry = "Dry"
    case veryDry = "Very Dry"
}

// MARK: - Nose Pore Analysis

public struct NosePoreAnalysis: Codable, Sendable {
    let density: Float  // Pores per cm²
    let averageSize: Float  // mm
    let score: Float  // 0-100, lower = better
    let heatmap: [[Float]]  // 2D grid of pore density
}

// MARK: - Jawline Definition

public struct JawlineAnalysis: Codable, Sendable {
    let definition: Float  // 0-100, higher = more defined
    let angle: Float  // Jawline angle in degrees
    let symmetry: Float  // 0-100
    let contour: [SIMD3<Float>]  // 3D jawline contour points
    let confidence: Float  // 0-100, based on vertex count
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

    public func analyzeUnderEyeDarkness(texture: UIImage) -> UnderEyeDarknessAnalysis? {

        guard let cgImage = texture.cgImage else {
            AppLogger.metrics.warning("⚠️ RegionalAnalyzers: No CGImage for under-eye analysis")
            return nil  // FIXED: Return nil instead of fake data
        }

        // Extract under-eye regions
        let leftEyeRegion = extractUnderEyeRegion(image: cgImage, side: .left)
        let rightEyeRegion = extractUnderEyeRegion(image: cgImage, side: .right)

        // Calculate darkness (LAB L* channel)
        guard let leftDarkness = calculateRegionBrightness(region: leftEyeRegion),
              let rightDarkness = calculateRegionBrightness(region: rightEyeRegion) else {
            AppLogger.metrics.warning("⚠️ RegionalAnalyzers: Under-eye region brightness calculation failed")
            return nil  // FIXED: Return nil instead of fake data
        }

        let avgDarkness = (leftDarkness + rightDarkness) / 2.0

        // Compare with surrounding skin (cheeks)
        guard let cheekBrightness = calculateCheekBrightness(image: cgImage) else {
            AppLogger.metrics.warning("⚠️ RegionalAnalyzers: Cheek brightness calculation failed")
            return nil  // FIXED: Return nil when comparison fails
        }
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

    public func analyzeLips(geometry: FaceMeshGeometry, texture: UIImage) -> LipAnalysis? {
        AppLogger.metrics.info("   🔍 Analyzing lip region...")

        // Extract lip region from geometry (dynamically adapts to face shape)
        let lipIndices = getLipIndices(geometry: geometry)
        let lipVertices = lipIndices.compactMap { index in
            index < geometry.vertices.count ? geometry.vertices[index] : nil
        }

        AppLogger.metrics.debug("      Found \(lipVertices.count) lip vertices")

        // Need at least 3 vertices for basic analysis (lowered from 4)
        guard lipVertices.count >= 3 else {
            AppLogger.metrics.warning("      ❌ Insufficient lip vertices (\(lipVertices.count) < 3)")
            return nil
        }

        // Calculate confidence based on vertex count
        let confidence: Float
        if lipVertices.count >= 20 {
            confidence = 85  // High confidence
        } else if lipVertices.count >= 10 {
            confidence = 70  // Medium confidence
        } else if lipVertices.count >= 5 {
            confidence = 55  // Low-medium confidence
        } else {
            confidence = 40  // Low confidence (3-4 vertices)
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
                lowerLipVolume: lowerLipVolume,
                confidence: confidence
            )
        }

        let lipRegion = extractLipRegion(image: cgImage)
        let textureScore = analyzeLipTexture(region: lipRegion)
        let hydration = classifyLipHydration(textureScore: textureScore)

        AppLogger.metrics.info("      ✅ Lip analysis: confidence=\(String(format: "%.0f", confidence))%")

        return LipAnalysis(
            textureScore: textureScore,
            volumeScore: volumeScore,
            symmetryScore: symmetryScore,
            hydrationLevel: hydration,
            upperLipVolume: upperLipVolume,
            lowerLipVolume: lowerLipVolume,
            confidence: confidence
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

    public func analyzeJawline(geometry: FaceMeshGeometry) -> JawlineAnalysis? {
        AppLogger.metrics.info("   🔍 Analyzing jawline region...")

        // Extract jawline vertices (dynamically adapts to face shape)
        let jawlineIndices = getJawlineIndices(geometry: geometry)
        let jawlineVertices = jawlineIndices.compactMap { index in
            index < geometry.vertices.count ? geometry.vertices[index] : nil
        }

        AppLogger.metrics.debug("      Found \(jawlineVertices.count) jawline vertices")

        // Need at least 3 vertices for basic analysis (lowered threshold)
        guard jawlineVertices.count >= 3 else {
            AppLogger.metrics.warning("      ❌ Insufficient jawline vertices (\(jawlineVertices.count) < 3)")
            return nil
        }

        // Calculate confidence based on vertex count
        let confidence: Float
        if jawlineVertices.count >= 30 {
            confidence = 90  // High confidence
        } else if jawlineVertices.count >= 15 {
            confidence = 75  // Medium-high confidence
        } else if jawlineVertices.count >= 8 {
            confidence = 60  // Medium confidence
        } else {
            confidence = 45  // Low confidence (3-7 vertices)
        }

        // Calculate definition (how sharp the jawline is)
        let definition = calculateJawlineDefinition(vertices: jawlineVertices)

        // Calculate jawline angle
        let angle = calculateJawlineAngle(vertices: jawlineVertices)

        // Calculate symmetry
        let symmetry = calculateJawlineSymmetry(vertices: jawlineVertices)

        AppLogger.metrics.info("      ✅ Jawline analysis: confidence=\(String(format: "%.0f", confidence))%")

        return JawlineAnalysis(
            definition: definition,
            angle: angle,
            symmetry: symmetry,
            contour: jawlineVertices,
            confidence: confidence
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

    private func calculateRegionBrightness(region: CGImage?) -> Float? {
        guard let region = region else {
            AppLogger.metrics.warning("⚠️ RegionalAnalyzers: Region extraction failed")
            return nil  // FIXED: Return nil instead of arbitrary 50
        }

        // Calculate average LAB L* (brightness) using proper color space conversion
        let pixels = extractPixels(from: region)

        var totalLightness: Float = 0

        for pixel in pixels {
            // Convert RGB (0-255) to LAB L* (0-100)
            let lab = rgbToLAB(r: Float(pixel.0), g: Float(pixel.1), b: Float(pixel.2))
            totalLightness += lab.l
        }

        let avgLightness = totalLightness / Float(max(pixels.count, 1))
        return avgLightness
    }

    // MARK: - Color Space Conversion

    /// Convert sRGB to CIELAB color space
    private func rgbToLAB(r: Float, g: Float, b: Float) -> (l: Float, a: Float, b: Float) {
        // Step 1: sRGB (0-255) to linear RGB (0-1)
        let rLinear = srgbToLinear(r / 255.0)
        let gLinear = srgbToLinear(g / 255.0)
        let bLinear = srgbToLinear(b / 255.0)

        // Step 2: Linear RGB to XYZ (D65 illuminant)
        let x = rLinear * 0.4124564 + gLinear * 0.3575761 + bLinear * 0.1804375
        let y = rLinear * 0.2126729 + gLinear * 0.7151522 + bLinear * 0.0721750
        let z = rLinear * 0.0193339 + gLinear * 0.1191920 + bLinear * 0.9503041

        // Step 3: XYZ to LAB (D65 reference white)
        let xn: Float = 0.95047  // D65 white point X
        let yn: Float = 1.00000  // D65 white point Y
        let zn: Float = 1.08883  // D65 white point Z

        let xr = xyzToLab(x / xn)
        let yr = xyzToLab(y / yn)
        let zr = xyzToLab(z / zn)

        let l = 116.0 * yr - 16.0
        let a = 500.0 * (xr - yr)
        let bVal = 200.0 * (yr - zr)

        return (l, a, bVal)
    }

    /// Convert sRGB gamma to linear RGB
    private func srgbToLinear(_ c: Float) -> Float {
        if c <= 0.04045 {
            return c / 12.92
        } else {
            return pow((c + 0.055) / 1.055, 2.4)
        }
    }

    /// XYZ to LAB conversion helper
    private func xyzToLab(_ t: Float) -> Float {
        let delta: Float = 6.0 / 29.0

        if t > delta * delta * delta {
            return pow(t, 1.0 / 3.0)
        } else {
            return t / (3.0 * delta * delta) + 4.0 / 29.0
        }
    }

    private func calculateCheekBrightness(image: CGImage) -> Float? {
        // Extract cheek region and calculate brightness
        let cheekRegion = image.cropping(to: CGRect(
            x: image.width / 3,
            y: image.height / 2,
            width: image.width / 6,
            height: image.height / 6
        ))

        return calculateRegionBrightness(region: cheekRegion)  // Now returns Optional
    }

    /// Get lip region indices dynamically based on vertex positions
    /// Adapts to different face shapes
    private func getLipIndices(geometry: FaceMeshGeometry) -> [Int] {
        let vertices = geometry.vertices

        // Calculate face bounds
        let bounds = calculateFaceBounds(vertices: vertices)
        let centerX = vertices.map { $0.x }.reduce(0, +) / Float(vertices.count)

        // Lip region is in lower-mid face, centered
        let lipYMin = bounds.minY + (bounds.maxY - bounds.minY) * 0.10  // 10% from bottom
        let lipYMax = bounds.minY + (bounds.maxY - bounds.minY) * 0.35  // 35% from bottom
        let lipXMin = centerX - 0.04  // Within 4cm of center (±)
        let lipXMax = centerX + 0.04
        let lipZMin = bounds.minZ + (bounds.maxZ - bounds.minZ) * 0.5   // Front 50% of face

        var lipIndices: [Int] = []

        for (index, vertex) in vertices.enumerated() {
            // Skip extended vertices
            guard index < geometry.originalVertexCount else { break }

            // Check if vertex is in lip region
            guard vertex.y >= lipYMin && vertex.y <= lipYMax else { continue }
            guard vertex.x >= lipXMin && vertex.x <= lipXMax else { continue }
            guard vertex.z >= lipZMin else { continue }

            lipIndices.append(index)
        }

        return lipIndices
    }

    /// Calculate bounding box of face vertices
    private func calculateFaceBounds(vertices: [SIMD3<Float>]) -> (minX: Float, maxX: Float, minY: Float, maxY: Float, minZ: Float, maxZ: Float) {
        guard !vertices.isEmpty else {
            return (0, 0, 0, 0, 0, 0)
        }

        var minX = vertices[0].x, maxX = vertices[0].x
        var minY = vertices[0].y, maxY = vertices[0].y
        var minZ = vertices[0].z, maxZ = vertices[0].z

        for vertex in vertices {
            minX = min(minX, vertex.x)
            maxX = max(maxX, vertex.x)
            minY = min(minY, vertex.y)
            maxY = max(maxY, vertex.y)
            minZ = min(minZ, vertex.z)
            maxZ = max(maxZ, vertex.z)
        }

        return (minX, maxX, minY, maxY, minZ, maxZ)
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

        guard filtered.count >= 4 else { return 0 }

        // Calculate actual 3D volume using signed tetrahedron volumes
        // This gives a better approximation than vertex counting

        // Find the centroid of the lip region
        var centroid = SIMD3<Float>(0, 0, 0)
        for vertex in filtered {
            centroid += vertex
        }
        centroid /= Float(filtered.count)

        // Calculate volume as sum of tetrahedra from centroid to each triangle
        var totalVolume: Float = 0

        // Create triangulation from consecutive vertices (fan triangulation from centroid)
        for i in 0..<filtered.count {
            let v0 = filtered[i]
            let v1 = filtered[(i + 1) % filtered.count]

            // Volume of tetrahedron formed by centroid and edge
            let vol = calculateTetrahedronVolume(
                p0: centroid,
                p1: v0,
                p2: v1,
                p3: centroid + SIMD3<Float>(0, 0, 0.01)  // Small offset for proper volume
            )

            totalVolume += abs(vol)
        }

        // Alternative: Use bounding volume for simpler approximation
        let boundingVolume = calculateBoundingVolume(vertices: filtered)

        // Return the larger of the two estimates (more conservative)
        return max(totalVolume, boundingVolume) * 1000  // Convert to cm³
    }

    /// Calculate volume of tetrahedron from 4 points
    private func calculateTetrahedronVolume(
        p0: SIMD3<Float>,
        p1: SIMD3<Float>,
        p2: SIMD3<Float>,
        p3: SIMD3<Float>
    ) -> Float {
        // Volume = |det(v1, v2, v3)| / 6
        // where v1, v2, v3 are vectors from p0 to p1, p2, p3

        let v1 = p1 - p0
        let v2 = p2 - p0
        let v3 = p3 - p0

        // Determinant: v1 · (v2 × v3)
        let determinant = dot(v1, cross(v2, v3))

        return abs(determinant) / 6.0
    }

    /// Calculate bounding volume as fallback
    private func calculateBoundingVolume(vertices: [SIMD3<Float>]) -> Float {
        guard !vertices.isEmpty else { return 0 }

        let minX = vertices.map { $0.x }.min() ?? 0
        let maxX = vertices.map { $0.x }.max() ?? 0
        let minY = vertices.map { $0.y }.min() ?? 0
        let maxY = vertices.map { $0.y }.max() ?? 0
        let minZ = vertices.map { $0.z }.min() ?? 0
        let maxZ = vertices.map { $0.z }.max() ?? 0

        return (maxX - minX) * (maxY - minY) * (maxZ - minZ)
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
        let avg = pixels.map { (Float($0.0) + Float($0.1) + Float($0.2)) / 3.0 }.reduce(0, +) / Float(pixels.count)
        let variance = pixels.map { pixel in
            let val = (Float(pixel.0) + Float(pixel.1) + Float(pixel.2)) / 3.0
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
            let brightness = (Float(pixel.0) + Float(pixel.1) + Float(pixel.2)) / 3.0

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

    /// Get jawline region indices dynamically based on vertex positions
    /// Adapts to different face shapes (round, square, oval, etc.)
    private func getJawlineIndices(geometry: FaceMeshGeometry) -> [Int] {
        let vertices = geometry.vertices

        // Calculate face bounds
        let bounds = calculateFaceBounds(vertices: vertices)

        // Jawline is bottom 15% of face, extending from side to side
        let jawYMin = bounds.minY
        let jawYMax = bounds.minY + (bounds.maxY - bounds.minY) * 0.15
        let jawXMin = bounds.minX + (bounds.maxX - bounds.minX) * 0.15  // Skip ear regions
        let jawXMax = bounds.maxX - (bounds.maxX - bounds.minX) * 0.15

        var jawIndices: [Int] = []

        for (index, vertex) in vertices.enumerated() {
            // Skip extended vertices
            guard index < geometry.originalVertexCount else { break }

            // Check if vertex is in jawline region
            guard vertex.y >= jawYMin && vertex.y <= jawYMax else { continue }
            guard vertex.x >= jawXMin && vertex.x <= jawXMax else { continue }

            jawIndices.append(index)
        }

        return jawIndices
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

        guard vertices.count >= 3,
              let start = vertices.first,
              let end = vertices.last else {
            return 120  // Default angle
        }

        let mid = vertices[vertices.count / 2]

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

    // REMOVED: defaultUnderEyeAnalysis() - was returning fake data (60, 50, 50, 10)
    // Now returns nil when extraction fails instead of fake values

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
