//
//  AcneAnalyzer.swift
//  Tavi
//
//  UNIFIED ACNE DETECTION - Fair across all skin tones
//
//  Method: Darkness variations + 3D mesh elevation
//  Works for all Fitzpatrick types (I-VI) including Indian/dark skin
//
//  Rationale:
//  - Light skin: Inflamed acne appears RED
//  - Dark skin: Inflamed acne appears DARKER BROWN (not red)
//  - Solution: Don't rely on color - use darkness + physical elevation
//

import UIKit
import simd

/// Acne analysis result
public struct AcneAnalysis: Codable, Sendable {
    let overallScore: Float  // 0-100, higher is better (less acne)
    let blemishCount: Int
    let severity: AcneSeverity
    let blemishes: [Blemish]
    let regionalScores: [String: Float]
    let confidence: Float  // 0-100, based on lighting and mesh quality
}

/// Individual blemish detection
public struct Blemish: Codable, Sendable {
    let location: String  // "forehead", "cheeks", "chin", etc.
    let type: BlemishType
    let severity: Float  // 0-1
    let size: Float      // in pixels
    let elevation: Float // 3D height in mm (0 for flat spots)
    let normalizedX: Float  // 0-1 position in image
    let normalizedY: Float
}

public enum BlemishType: String, Codable, Sendable {
    case blackhead       // Flat dark spot, no elevation
    case postInflammatory // Flat dark spot (PIH - post-inflammatory hyperpigmentation)
    case papule          // Small bump (< 1mm elevation)
    case pustule         // Medium bump (1-2mm elevation)
    case cyst            // Large bump (> 2mm elevation)
}

public enum AcneSeverity: String, Codable, Sendable {
    case clear           // 0-5 blemishes
    case mild            // 6-20 blemishes
    case moderate        // 21-50 blemishes
    case severe          // 50+ blemishes

    var score: Float {
        switch self {
        case .clear: return 95
        case .mild: return 75
        case .moderate: return 50
        case .severe: return 25
        }
    }
}

/// Unified acne analyzer - skin-tone-fair approach
public class AcneAnalyzer {

    // MARK: - Configuration

    private let minBlemishSize: Float = 2.0      // pixels
    private let maxBlemishSize: Float = 50.0     // pixels

    // MARK: - Public API

    /// Analyze acne using unified approach (darkness + 3D elevation)
    /// Works fairly across all skin tones (Fitzpatrick I-VI)
    public func analyzeAcne(texture: UIImage, geometry: FaceMeshGeometry? = nil) -> AcneAnalysis {
        print("🔬 Analyzing acne (unified method - skin-tone-fair)...")

        guard let cgImage = texture.cgImage else {
            return AcneAnalysis(
                overallScore: 50,
                blemishCount: 0,
                severity: .clear,
                blemishes: [],
                regionalScores: [:],
                confidence: 0
            )
        }

        let width = cgImage.width
        let height = cgImage.height

        // Step 1: Detect darkness variations (adaptive threshold)
        let darknessSpots = detectDarknessVariations(image: cgImage)
        print("   Found \(darknessSpots.count) darkness variations")

        // Step 2: Detect 3D elevations (if geometry available)
        var elevationMap: [SIMD2<Int>: Float] = [:]
        if let geometry = geometry {
            elevationMap = detect3DElevations(geometry: geometry, imageSize: CGSize(width: width, height: height))
            print("   Found \(elevationMap.count) elevated regions")
        }

        // Step 3: Correlate darkness + elevation to identify acne
        let blemishes = correlateDarknessAndElevation(
            darknessSpots: darknessSpots,
            elevationMap: elevationMap,
            imageSize: CGSize(width: width, height: height)
        )

        print("   Detected \(blemishes.count) blemishes")

        // Step 4: Classify severity
        let severity = classifySeverity(blemishCount: blemishes.count)

        // Step 5: Calculate regional scores
        let regionalScores = calculateRegionalScores(blemishes: blemishes)

        // Step 6: Calculate overall score
        let overallScore = calculateOverallScore(blemishes: blemishes, severity: severity)

        // Step 7: Calculate confidence
        let confidence = calculateConfidence(
            darknessSpotCount: darknessSpots.count,
            hasGeometry: geometry != nil,
            imageSize: CGSize(width: width, height: height)
        )

        print("✅ Acne analysis complete:")
        print("   Blemishes: \(blemishes.count) (\(severity.rawValue))")
        print("   Score: \(String(format: "%.1f", overallScore))/100")
        print("   Confidence: \(String(format: "%.0f", confidence))%")

        return AcneAnalysis(
            overallScore: overallScore,
            blemishCount: blemishes.count,
            severity: severity,
            blemishes: blemishes,
            regionalScores: regionalScores,
            confidence: confidence
        )
    }

    // MARK: - Step 1: Darkness Detection (Adaptive)

    /// Detect local darkness variations (works for all skin tones)
    private func detectDarknessVariations(image: CGImage) -> [(x: Int, y: Int, darkness: Float, size: Float)] {
        let width = image.width
        let height = image.height

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
            return []
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Calculate adaptive darkness threshold based on skin brightness
        let avgBrightness = calculateAverageBrightness(data: grayData, width: width, height: height)

        // Dark spots are 20-30% darker than surrounding skin
        // This works for all skin tones (light to dark)
        let darknessThreshold = UInt8(max(30, Int(avgBrightness * 0.70)))

        print("   Adaptive darkness threshold: \(darknessThreshold) (avg brightness: \(avgBrightness))")

        // Detect local minima (dark spots)
        var darkSpots: [(x: Int, y: Int, darkness: Float, size: Float)] = []
        var visited = Set<Int>()

        for y in stride(from: 10, to: height - 10, by: 3) {
            for x in stride(from: 10, to: width - 10, by: 3) {
                let idx = y * width + x
                guard !visited.contains(idx) else { continue }

                let centerValue = grayData[idx]

                // Check if this is a local minimum (darker than neighbors)
                if centerValue < darknessThreshold && isLocalDarkSpot(data: grayData, x: x, y: y, width: width, height: height) {
                    // Measure dark spot size via flood-fill
                    let (size, darkness) = measureDarkSpot(
                        data: grayData,
                        startX: x,
                        startY: y,
                        width: width,
                        height: height,
                        threshold: centerValue + 30,
                        visited: &visited
                    )

                    if size >= minBlemishSize && size <= maxBlemishSize {
                        darkSpots.append((x, y, Float(centerValue), size))
                    }
                }
            }
        }

        return darkSpots
    }

    /// Calculate average brightness of center face region
    private func calculateAverageBrightness(data: [UInt8], width: Int, height: Int) -> Float {
        let centerX = width / 2
        let centerY = height / 2
        let sampleRadius = min(width, height) / 6

        var sum: Float = 0
        var count = 0

        for y in stride(from: centerY - sampleRadius, to: centerY + sampleRadius, by: 5) {
            for x in stride(from: centerX - sampleRadius, to: centerX + sampleRadius, by: 5) {
                guard x >= 0 && x < width && y >= 0 && y < height else { continue }
                sum += Float(data[y * width + x])
                count += 1
            }
        }

        return count > 0 ? sum / Float(count) : 128.0
    }

    /// Check if pixel is a local dark spot
    private func isLocalDarkSpot(data: [UInt8], x: Int, y: Int, width: Int, height: Int) -> Bool {
        let centerValue = data[y * width + x]
        let radius = 2

        for dy in -radius...radius {
            for dx in -radius...radius {
                if dx == 0 && dy == 0 { continue }

                let nx = x + dx
                let ny = y + dy

                if nx >= 0 && nx < width && ny >= 0 && ny < height {
                    if data[ny * width + nx] <= centerValue {
                        return false
                    }
                }
            }
        }

        return true
    }

    /// Measure dark spot size using flood-fill
    private func measureDarkSpot(
        data: [UInt8],
        startX: Int,
        startY: Int,
        width: Int,
        height: Int,
        threshold: UInt8,
        visited: inout Set<Int>
    ) -> (size: Float, avgDarkness: Float) {
        var queue = [(startX, startY)]
        var size: Float = 0
        var totalDarkness: Float = 0
        let startIdx = startY * width + startX

        visited.insert(startIdx)

        while !queue.isEmpty && size < maxBlemishSize {
            let (x, y) = queue.removeFirst()
            size += 1
            totalDarkness += Float(data[y * width + x])

            for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                let nx = x + dx
                let ny = y + dy

                if nx >= 0 && nx < width && ny >= 0 && ny < height {
                    let idx = ny * width + nx
                    if !visited.contains(idx) && data[idx] < threshold {
                        visited.insert(idx)
                        queue.append((nx, ny))
                    }
                }
            }
        }

        let avgDarkness = size > 0 ? totalDarkness / size : 0
        return (size, avgDarkness)
    }

    // MARK: - Step 2: 3D Elevation Detection

    /// Detect elevated regions in 3D mesh (bumps = potential acne)
    private func detect3DElevations(geometry: FaceMeshGeometry, imageSize: CGSize) -> [SIMD2<Int>: Float] {
        var elevationMap: [SIMD2<Int>: Float] = [:]

        let vertices = geometry.vertices
        let normals = geometry.normals

        // Build adjacency for local elevation comparison
        let adjacency = buildAdjacency(geometry: geometry)

        for (index, vertex) in vertices.enumerated() {
            let neighbors = adjacency[index]
            guard !neighbors.isEmpty else { continue }

            // Calculate local elevation (z-displacement from neighbors)
            var totalDisplacement: Float = 0

            for neighborIndex in neighbors {
                let neighborVertex = vertices[neighborIndex]
                let zDiff = vertex.z - neighborVertex.z
                totalDisplacement += abs(zDiff)
            }

            let avgDisplacement = totalDisplacement / Float(neighbors.count)

            // If elevated more than 0.5mm (0.0005m), it's a potential bump
            if avgDisplacement > 0.0005 {
                // Project 3D vertex to 2D image coordinates
                let normalizedX = (vertex.x + 0.05) / 0.1  // ARKit face is ~0.1m wide
                let normalizedY = (vertex.y + 0.05) / 0.1

                let imageX = Int(normalizedX * Float(imageSize.width))
                let imageY = Int(normalizedY * Float(imageSize.height))

                if imageX >= 0 && imageX < Int(imageSize.width) && imageY >= 0 && imageY < Int(imageSize.height) {
                    let key = SIMD2<Int>(imageX, imageY)
                    elevationMap[key] = avgDisplacement * 1000  // Convert to mm
                }
            }
        }

        return elevationMap
    }

    /// Build vertex adjacency for mesh analysis
    private func buildAdjacency(geometry: FaceMeshGeometry) -> [[Int]] {
        var adjacency = Array(repeating: Set<Int>(), count: geometry.vertices.count)

        for i in stride(from: 0, to: geometry.triangleIndices.count, by: 3) {
            let v0 = Int(geometry.triangleIndices[i])
            let v1 = Int(geometry.triangleIndices[i + 1])
            let v2 = Int(geometry.triangleIndices[i + 2])

            adjacency[v0].insert(v1)
            adjacency[v0].insert(v2)
            adjacency[v1].insert(v0)
            adjacency[v1].insert(v2)
            adjacency[v2].insert(v0)
            adjacency[v2].insert(v1)
        }

        return adjacency.map { Array($0) }
    }

    // MARK: - Step 3: Correlate Darkness + Elevation

    /// Correlate darkness spots with 3D elevations to identify acne
    private func correlateDarknessAndElevation(
        darknessSpots: [(x: Int, y: Int, darkness: Float, size: Float)],
        elevationMap: [SIMD2<Int>: Float],
        imageSize: CGSize
    ) -> [Blemish] {
        var blemishes: [Blemish] = []

        for spot in darknessSpots {
            // Check if there's a corresponding elevation nearby
            let elevation = findNearbyElevation(
                x: spot.x,
                y: spot.y,
                elevationMap: elevationMap,
                searchRadius: Int(spot.size / 2)
            )

            // Classify blemish type based on elevation
            let type: BlemishType
            if elevation == 0 {
                // Flat dark spot
                type = spot.darkness < 50 ? .blackhead : .postInflammatory
            } else if elevation < 1.0 {
                // Small bump
                type = .papule
            } else if elevation < 2.0 {
                // Medium bump
                type = .pustule
            } else {
                // Large bump
                type = .cyst
            }

            // Determine face region
            let location = determineFaceRegion(
                x: spot.x,
                y: spot.y,
                imageSize: imageSize
            )

            // Calculate severity (0-1) based on size and elevation
            let severity = min(1.0, (spot.size / maxBlemishSize) * 0.5 + (elevation / 3.0) * 0.5)

            let blemish = Blemish(
                location: location,
                type: type,
                severity: severity,
                size: spot.size,
                elevation: elevation,
                normalizedX: Float(spot.x) / Float(imageSize.width),
                normalizedY: Float(spot.y) / Float(imageSize.height)
            )

            blemishes.append(blemish)
        }

        return blemishes
    }

    /// Find nearby elevation for a given position
    private func findNearbyElevation(
        x: Int,
        y: Int,
        elevationMap: [SIMD2<Int>: Float],
        searchRadius: Int
    ) -> Float {
        var maxElevation: Float = 0

        for dy in -searchRadius...searchRadius {
            for dx in -searchRadius...searchRadius {
                let key = SIMD2<Int>(x + dx, y + dy)
                if let elevation = elevationMap[key] {
                    maxElevation = max(maxElevation, elevation)
                }
            }
        }

        return maxElevation
    }

    /// Determine which face region a blemish is in
    private func determineFaceRegion(x: Int, y: Int, imageSize: CGSize) -> String {
        let normalizedX = Float(x) / Float(imageSize.width)
        let normalizedY = Float(y) / Float(imageSize.height)

        if normalizedY < 0.3 {
            return "forehead"
        } else if normalizedY < 0.5 {
            if normalizedX < 0.4 {
                return "leftCheek"
            } else if normalizedX > 0.6 {
                return "rightCheek"
            } else {
                return "nose"
            }
        } else if normalizedY < 0.7 {
            if normalizedX < 0.4 {
                return "leftCheek"
            } else if normalizedX > 0.6 {
                return "rightCheek"
            } else {
                return "mouth"
            }
        } else {
            return "chin"
        }
    }

    // MARK: - Step 4-6: Scoring

    private func classifySeverity(blemishCount: Int) -> AcneSeverity {
        if blemishCount <= 5 {
            return .clear
        } else if blemishCount <= 20 {
            return .mild
        } else if blemishCount <= 50 {
            return .moderate
        } else {
            return .severe
        }
    }

    private func calculateRegionalScores(blemishes: [Blemish]) -> [String: Float] {
        var regionalCounts: [String: Int] = [:]
        var regionalSeverities: [String: Float] = [:]

        for blemish in blemishes {
            regionalCounts[blemish.location, default: 0] += 1
            regionalSeverities[blemish.location, default: 0] += blemish.severity
        }

        var regionalScores: [String: Float] = [:]

        for (region, count) in regionalCounts {
            let avgSeverity = regionalSeverities[region]! / Float(count)
            // Score: 100 = perfect, 0 = very bad
            let score = max(0, 100 - Float(count) * 5 - avgSeverity * 50)
            regionalScores[region] = score
        }

        return regionalScores
    }

    private func calculateOverallScore(blemishes: [Blemish], severity: AcneSeverity) -> Float {
        if blemishes.isEmpty {
            return 95  // Perfect score
        }

        // Start with severity base score
        var score = severity.score

        // Reduce score based on blemish severity
        let avgSeverity = blemishes.map { $0.severity }.reduce(0, +) / Float(blemishes.count)
        score -= avgSeverity * 20

        return max(10, min(100, score))
    }

    private func calculateConfidence(
        darknessSpotCount: Int,
        hasGeometry: Bool,
        imageSize: CGSize
    ) -> Float {
        var confidence: Float = 70  // Base confidence

        // Higher confidence if we have 3D geometry
        if hasGeometry {
            confidence += 20  // 3D validation increases confidence
        } else {
            confidence -= 15  // Only 2D, lower confidence
        }

        // Lower confidence if too many or too few spots (might be noise or missed)
        if darknessSpotCount > 200 {
            confidence -= 20  // Too many - likely noise
        } else if darknessSpotCount < 3 && !hasGeometry {
            confidence -= 10  // Too few without 3D - might be missing some
        }

        return max(30, min(90, confidence))
    }
}
