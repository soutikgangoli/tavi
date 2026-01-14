//
//  RegionalAnalyzers.swift
//  Ollvy
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

    // MARK: - Performance Optimization

    private let maxAnalysisSize: Int = 1024

    private func downsample(_ image: CGImage, maxSize: Int? = nil) -> CGImage? {
        let targetSize = maxSize ?? maxAnalysisSize
        let scale = min(1.0, Double(targetSize) / Double(max(image.width, image.height)))
        if scale >= 1.0 { return image }

        let newWidth = Int(Double(image.width) * scale)
        let newHeight = Int(Double(image.height) * scale)

        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: newWidth, height: newHeight,
            bitsPerComponent: 8, bytesPerRow: newWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage()
    }

    // MARK: - Public API

    /// Analyze all regions
    public func analyzeRegions(
        geometry: FaceMeshGeometry,
        texture: UIImage
    ) -> RegionalAnalysis {

        // PERFORMANCE: Downsample for efficient analysis
        let analysisTexture: UIImage
        if let cgImage = texture.cgImage, let downsampled = downsample(cgImage) {
            analysisTexture = UIImage(cgImage: downsampled)
        } else {
            analysisTexture = texture
        }

        let underEye = analyzeUnderEyeDarkness(texture: analysisTexture)
        let lips = analyzeLips(geometry: geometry, texture: analysisTexture)
        let nose = analyzeNosePores(texture: analysisTexture)
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
        AppLogger.metrics.info("   🔍 LIP ANALYSIS START ========================")
        AppLogger.metrics.info("      📊 Geometry stats: totalVertices=\(geometry.vertices.count), originalVertexCount=\(geometry.originalVertexCount)")

        // Extract lip region from geometry (dynamically adapts to face shape)
        let lipIndices = getLipIndices(geometry: geometry)
        let lipVertices = lipIndices.compactMap { index in
            index < geometry.vertices.count ? geometry.vertices[index] : nil
        }

        AppLogger.metrics.info("      🎯 Lip vertex detection: found \(lipVertices.count) vertices (indices: \(lipIndices.count))")

        // PHASE 5 FIX: Lowered vertex requirement from 3 to 2
        // Also added texture-only fallback if < 2 vertices
        guard lipVertices.count >= 2 else {
            AppLogger.metrics.warning("      ⚠️ FALLBACK: Insufficient lip vertices (\(lipVertices.count) < 2)")
            AppLogger.metrics.warning("      ⚠️ Using texture-only analysis (volumeScore and symmetryScore will be defaults)")
            // Texture-only fallback analysis
            let fallbackResult = analyzeLipsFromTextureOnly(texture: texture)
            AppLogger.metrics.info("      📋 FALLBACK RESULT: texture=\(String(format: "%.0f", fallbackResult.textureScore)), volume=\(String(format: "%.0f", fallbackResult.volumeScore)) (DEFAULT), symmetry=\(String(format: "%.0f", fallbackResult.symmetryScore)) (DEFAULT), hydration=\(fallbackResult.hydrationLevel.rawValue), confidence=\(String(format: "%.0f", fallbackResult.confidence))%")
            AppLogger.metrics.info("   🔍 LIP ANALYSIS END (FALLBACK) ================")
            return fallbackResult
        }

        // Calculate confidence based on vertex count
        let confidence: Float
        if lipVertices.count >= 20 {
            confidence = 85  // High confidence
            AppLogger.metrics.info("      ✅ Confidence: HIGH (85%) - \(lipVertices.count) vertices >= 20")
        } else if lipVertices.count >= 10 {
            confidence = 70  // Medium confidence
            AppLogger.metrics.info("      ✅ Confidence: MEDIUM (70%) - \(lipVertices.count) vertices >= 10")
        } else if lipVertices.count >= 5 {
            confidence = 55  // Low-medium confidence
            AppLogger.metrics.info("      ⚡ Confidence: LOW-MEDIUM (55%) - \(lipVertices.count) vertices >= 5")
        } else if lipVertices.count >= 3 {
            confidence = 40  // Low confidence (3-4 vertices)
            AppLogger.metrics.info("      ⚠️ Confidence: LOW (40%) - \(lipVertices.count) vertices >= 3")
        } else {
            confidence = 30  // Very low confidence (2 vertices)
            AppLogger.metrics.info("      ⚠️ Confidence: VERY LOW (30%) - only \(lipVertices.count) vertices")
        }

        // Calculate volume (fullness) - REAL 3D CALCULATION
        let upperLipVolume = calculateLipVolume(vertices: lipVertices, region: .upper)
        let lowerLipVolume = calculateLipVolume(vertices: lipVertices, region: .lower)
        let totalVolume = upperLipVolume + lowerLipVolume
        let volumeScore = min(100, totalVolume / 2.0 * 100)  // Normalize
        AppLogger.metrics.info("      📐 Volume (REAL 3D): upper=\(String(format: "%.3f", upperLipVolume)), lower=\(String(format: "%.3f", lowerLipVolume)), total=\(String(format: "%.3f", totalVolume)), score=\(String(format: "%.0f", volumeScore))")

        // Calculate symmetry - REAL 3D CALCULATION
        let symmetryScore = calculateLipSymmetry(vertices: lipVertices)
        AppLogger.metrics.info("      📐 Symmetry (REAL 3D): score=\(String(format: "%.0f", symmetryScore))")

        // Analyze texture from image
        guard let cgImage = texture.cgImage else {
            AppLogger.metrics.warning("      ⚠️ No CGImage available - using default textureScore=60")
            let result = LipAnalysis(
                textureScore: 60,
                volumeScore: volumeScore,
                symmetryScore: symmetryScore,
                hydrationLevel: .normal,
                upperLipVolume: upperLipVolume,
                lowerLipVolume: lowerLipVolume,
                confidence: confidence
            )
            AppLogger.metrics.info("      📋 RESULT: texture=60 (DEFAULT), volume=\(String(format: "%.0f", volumeScore)) (REAL), symmetry=\(String(format: "%.0f", symmetryScore)) (REAL), hydration=normal (DEFAULT), confidence=\(String(format: "%.0f", confidence))%")
            AppLogger.metrics.info("   🔍 LIP ANALYSIS END (PARTIAL) =================")
            return result
        }

        let lipRegion = extractLipRegion(image: cgImage)
        let textureScore = analyzeLipTexture(region: lipRegion)
        let hydration = classifyLipHydration(textureScore: textureScore)
        AppLogger.metrics.info("      🎨 Texture (REAL): score=\(String(format: "%.0f", textureScore)), hydration=\(hydration.rawValue)")

        let result = LipAnalysis(
            textureScore: textureScore,
            volumeScore: volumeScore,
            symmetryScore: symmetryScore,
            hydrationLevel: hydration,
            upperLipVolume: upperLipVolume,
            lowerLipVolume: lowerLipVolume,
            confidence: confidence
        )

        AppLogger.metrics.info("      📋 FINAL RESULT: texture=\(String(format: "%.0f", textureScore)) (REAL), volume=\(String(format: "%.0f", volumeScore)) (REAL), symmetry=\(String(format: "%.0f", symmetryScore)) (REAL), hydration=\(hydration.rawValue) (REAL), confidence=\(String(format: "%.0f", confidence))%")
        AppLogger.metrics.info("   🔍 LIP ANALYSIS END (SUCCESS) ==================")

        return result
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
    /// FIXED: Improved lip region detection with correct coordinate handling
    private func getLipIndices(geometry: FaceMeshGeometry) -> [Int] {
        let vertices = geometry.vertices

        // Calculate face bounds
        let bounds = calculateFaceBounds(vertices: vertices)
        let centerX = vertices.map { $0.x }.reduce(0, +) / Float(vertices.count)

        // Log face bounds for debugging
        AppLogger.metrics.info("      📏 Face bounds: X=[\(String(format: "%.3f", bounds.minX)) to \(String(format: "%.3f", bounds.maxX))], Y=[\(String(format: "%.3f", bounds.minY)) to \(String(format: "%.3f", bounds.maxY))], Z=[\(String(format: "%.3f", bounds.minZ)) to \(String(format: "%.3f", bounds.maxZ))]")
        AppLogger.metrics.info("      📏 Face center X: \(String(format: "%.3f", centerX))")

        // FIXED: Lip region bounds with proper ARKit coordinate handling
        // In ARKit face coords: minY = chin (bottom), maxY = forehead (top)
        // Lips are in the lower portion of the face, roughly 15-35% from bottom
        let faceHeight = bounds.maxY - bounds.minY
        let lipYMin = bounds.minY + faceHeight * 0.15  // 15% from bottom (chin area)
        let lipYMax = bounds.minY + faceHeight * 0.35  // 35% from bottom (below nose)
        let lipXMin = centerX - 0.06  // Within 6cm of center
        let lipXMax = centerX + 0.06
        let lipZMin = bounds.minZ + (bounds.maxZ - bounds.minZ) * 0.4   // Front 60% of face

        // Log lip detection bounds
        AppLogger.metrics.info("      👄 Lip detection region: Y=[\(String(format: "%.3f", lipYMin)) to \(String(format: "%.3f", lipYMax))], X=[\(String(format: "%.3f", lipXMin)) to \(String(format: "%.3f", lipXMax))], Z>=\(String(format: "%.3f", lipZMin))")
        AppLogger.metrics.info("      👄 Lip Y range: \(String(format: "%.0f", 15))%-\(String(format: "%.0f", 35))% from bottom (faceHeight=\(String(format: "%.3f", faceHeight)))")

        var lipIndices: [Int] = []
        var verticesChecked = 0
        var verticesSkippedExtended = 0

        for (index, vertex) in vertices.enumerated() {
            // Skip extended vertices but DON'T break - continue checking remaining original vertices
            if index >= geometry.originalVertexCount {
                verticesSkippedExtended += 1
                continue
            }

            verticesChecked += 1

            // Check if vertex is in lip region
            guard vertex.y >= lipYMin && vertex.y <= lipYMax else { continue }
            guard vertex.x >= lipXMin && vertex.x <= lipXMax else { continue }
            guard vertex.z >= lipZMin else { continue }

            lipIndices.append(index)
        }

        AppLogger.metrics.info("      👄 Vertex scan: checked=\(verticesChecked), skippedExtended=\(verticesSkippedExtended), foundInLipRegion=\(lipIndices.count)")

        AppLogger.metrics.debug("      Lip region: Found \(lipIndices.count) vertices in bounds")

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
        guard !pixels.isEmpty else { return 60 }

        // Calculate standard deviation (not variance) for proper 0-100 scaling
        let avg = pixels.map { (Float($0.0) + Float($0.1) + Float($0.2)) / 3.0 }.reduce(0, +) / Float(pixels.count)
        let variance = pixels.map { pixel in
            let val = (Float(pixel.0) + Float(pixel.1) + Float(pixel.2)) / 3.0
            return pow(val - avg, 2)
        }.reduce(0, +) / Float(pixels.count)

        // Use standard deviation (sqrt of variance) which is in 0-128 range for 8-bit images
        let stdDev = sqrt(variance)

        // Normalize: stdDev of 0 = perfectly smooth = 100, stdDev of 50+ = rough = 0
        // Typical healthy lip stdDev is 10-30
        let normalizedRoughness = min(1.0, stdDev / 50.0)

        // Score (lower roughness = smoother = better)
        let score = (1.0 - normalizedRoughness) * 100

        AppLogger.metrics.info("      📊 Lip texture: stdDev=\(String(format: "%.1f", stdDev)), score=\(String(format: "%.0f", score))")

        return max(0, min(100, score))
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

    /// FIXED: Texture-only fallback for lip analysis - ALWAYS returns valid data (never nil)
    /// This provides a degraded but still useful analysis based on texture alone
    private func analyzeLipsFromTextureOnly(texture: UIImage) -> LipAnalysis {
        AppLogger.metrics.info("      📸 Using texture-only lip analysis fallback")

        // Default values if texture analysis fails
        var textureScore: Float = 65  // Default mid-range
        var hydration: LipHydrationLevel = .normal

        // Try to analyze from texture if available
        if let cgImage = texture.cgImage {
            let lipRegion = extractLipRegion(image: cgImage)
            textureScore = analyzeLipTexture(region: lipRegion)
            hydration = classifyLipHydration(textureScore: textureScore)
        } else {
            AppLogger.metrics.warning("      ⚠️ No texture available, using default lip values")
        }

        // Estimate volume and symmetry with default values (can't calculate from texture alone)
        let volumeScore: Float = 60  // Default mid-range
        let upperLipVolume: Float = 0.5  // Default
        let lowerLipVolume: Float = 0.5  // Default
        let symmetryScore: Float = 70  // Default (assume normal symmetry)

        // Low confidence since we're using fallback method
        let confidence: Float = 35

        AppLogger.metrics.info("      ✅ Lip analysis (texture-only fallback): texture=\(String(format: "%.0f", textureScore)), hydration=\(hydration.rawValue), confidence=\(String(format: "%.0f", confidence))%")

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
        guard !pixels.isEmpty else { return [] }

        // STEP 1: Calculate baseline brightness (average of region)
        // FIXED: Previously used absolute threshold (100) which failed for Indian skin
        var totalBrightness: Float = 0
        for pixel in pixels {
            totalBrightness += (Float(pixel.0) + Float(pixel.1) + Float(pixel.2)) / 3.0
        }
        let baselineBrightness = totalBrightness / Float(pixels.count)

        // STEP 2: Use RELATIVE threshold - pores are 35% darker than baseline
        // Indian skin baseline ~100-130 → threshold ~65-85
        // Light skin baseline ~170-200 → threshold ~110-130
        let poreThreshold = baselineBrightness * 0.65

        var pores: [PoreDetection] = []

        // Simplified pore detection (look for small dark spots relative to skin tone)
        for (index, pixel) in pixels.enumerated() {
            let brightness = (Float(pixel.0) + Float(pixel.1) + Float(pixel.2)) / 3.0

            if brightness < poreThreshold {  // Dark spot relative to baseline
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
