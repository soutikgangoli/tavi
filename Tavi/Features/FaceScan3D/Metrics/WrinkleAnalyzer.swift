//
//  WrinkleAnalyzer.swift
//  Tavi
//
//  Depth-based wrinkle measurement using 3D curvature analysis
//  Professional metric requiring 3D geometry (can't be done with 2D alone)
//

import simd

/// Wrinkle analysis result
struct WrinkleAnalysis {
    let overallScore: Float  // 0-100, lower is better (fewer/shallower wrinkles)
    let wrinkleDepth: WrinkleDepth
    let wrinkleCount: Int
    let wrinkleRegions: [WrinkleRegion]
    let regionalScores: [String: Float]  // By face region
}

/// Wrinkle depth classification
enum WrinkleDepth {
    case minimal   // <0.3mm
    case shallow   // 0.3-0.7mm
    case moderate  // 0.7-1.2mm
    case deep      // >1.2mm

    var score: Float {
        switch self {
        case .minimal: return 95
        case .shallow: return 75
        case .moderate: return 50
        case .deep: return 25
        }
    }
}

/// Individual wrinkle region
struct WrinkleRegion {
    let location: String  // "forehead", "eyes", "mouth", etc.
    let depth: Float      // in meters
    let length: Float     // in meters
    let severity: WrinkleSeverity
}

enum WrinkleSeverity: String {
    case fine
    case moderate
    case deep
}

/// Wrinkle analyzer using curvature computation
class WrinkleAnalyzer {

    // MARK: - Configuration

    private let minWrinkleDepth: Float = 0.0003  // 0.3mm
    private let deepWrinkleThreshold: Float = 0.0012  // 1.2mm
    private let curvatureThreshold: Float = 50.0  // High curvature = wrinkle

    // MARK: - Public API

    /// Analyze wrinkles from 3D geometry
    func analyzeWrinkles(geometry: FaceMeshGeometry) -> WrinkleAnalysis {
        print("📏 Analyzing wrinkles from 3D geometry...")

        // 1. Calculate vertex curvatures
        let curvatures = calculateCurvatures(geometry: geometry)

        // 2. Identify wrinkle regions (high negative curvature)
        let wrinkleVertices = identifyWrinkleVertices(curvatures: curvatures)

        // 3. Measure wrinkle depths
        let (avgDepth, maxDepth, wrinkleRegions) = measureWrinkleDepths(
            geometry: geometry,
            wrinkleVertices: wrinkleVertices,
            curvatures: curvatures
        )

        // 4. Classify wrinkle depth
        let depthClassification = classifyDepth(avgDepth)

        // 5. Calculate regional scores
        let regionalScores = calculateRegionalScores(
            geometry: geometry,
            wrinkleRegions: wrinkleRegions
        )

        // 6. Calculate overall score
        let overallScore = calculateOverallScore(
            avgDepth: avgDepth,
            maxDepth: maxDepth,
            wrinkleCount: wrinkleRegions.count
        )

        print("✅ Wrinkle analysis complete")
        print("   Overall score: \(String(format: "%.1f", overallScore))/100")
        print("   Wrinkle depth: \(depthClassification)")
        print("   Wrinkles detected: \(wrinkleRegions.count)")

        return WrinkleAnalysis(
            overallScore: overallScore,
            wrinkleDepth: depthClassification,
            wrinkleCount: wrinkleRegions.count,
            wrinkleRegions: wrinkleRegions,
            regionalScores: regionalScores
        )
    }

    // MARK: - Private Methods

    /// Calculate curvature at each vertex
    private func calculateCurvatures(geometry: FaceMeshGeometry) -> [Float] {
        let vertices = geometry.vertices
        let normals = geometry.normals
        let adjacency = buildAdjacency(geometry: geometry)

        var curvatures: [Float] = []

        for (index, vertex) in vertices.enumerated() {
            let neighbors = adjacency[index]
            guard !neighbors.isEmpty else {
                curvatures.append(0)
                continue
            }

            // Mean curvature estimation using normal variation
            let normal = normals[index]
            var normalVariation: Float = 0

            for neighborIndex in neighbors {
                let neighborNormal = normals[neighborIndex]
                let neighborVertex = vertices[neighborIndex]
                let edge = neighborVertex - vertex
                let edgeLength = length(edge)

                if edgeLength > 0 {
                    let normalDiff = normal - neighborNormal
                    normalVariation += length(normalDiff) / edgeLength
                }
            }

            let curvature = normalVariation / Float(neighbors.count)
            curvatures.append(curvature)
        }

        return curvatures
    }

    /// Build vertex adjacency list
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

    /// Identify vertices that are part of wrinkles
    private func identifyWrinkleVertices(curvatures: [Float]) -> Set<Int> {
        var wrinkleVertices = Set<Int>()

        for (index, curvature) in curvatures.enumerated() {
            if curvature > curvatureThreshold {
                wrinkleVertices.insert(index)
            }
        }

        return wrinkleVertices
    }

    /// Measure depths of detected wrinkles
    private func measureWrinkleDepths(
        geometry: FaceMeshGeometry,
        wrinkleVertices: Set<Int>,
        curvatures: [Float]
    ) -> (avgDepth: Float, maxDepth: Float, regions: [WrinkleRegion]) {

        // Group connected wrinkle vertices into regions
        let regions = clusterWrinkleRegions(
            geometry: geometry,
            wrinkleVertices: wrinkleVertices
        )

        var wrinkleRegions: [WrinkleRegion] = []
        var totalDepth: Float = 0
        var maxDepth: Float = 0

        for region in regions {
            let depth = estimateRegionDepth(
                geometry: geometry,
                regionVertices: region,
                curvatures: curvatures
            )

            let length = estimateRegionLength(
                geometry: geometry,
                regionVertices: region
            )

            let severity: WrinkleSeverity
            if depth < 0.0005 {  // 0.5mm
                severity = .fine
            } else if depth < 0.001 {  // 1mm
                severity = .moderate
            } else {
                severity = .deep
            }

            let location = identifyFaceRegion(
                geometry: geometry,
                regionVertices: region
            )

            wrinkleRegions.append(WrinkleRegion(
                location: location,
                depth: depth,
                length: length,
                severity: severity
            ))

            totalDepth += depth
            maxDepth = max(maxDepth, depth)
        }

        let avgDepth = wrinkleRegions.isEmpty ? 0 : totalDepth / Float(wrinkleRegions.count)

        return (avgDepth, maxDepth, wrinkleRegions)
    }

    /// Cluster connected wrinkle vertices
    private func clusterWrinkleRegions(
        geometry: FaceMeshGeometry,
        wrinkleVertices: Set<Int>
    ) -> [[Int]] {
        var visited = Set<Int>()
        var regions: [[Int]] = []

        let adjacency = buildAdjacency(geometry: geometry)

        for vertex in wrinkleVertices {
            guard !visited.contains(vertex) else { continue }

            // BFS to find connected component
            var region: [Int] = []
            var queue: [Int] = [vertex]
            visited.insert(vertex)

            while !queue.isEmpty {
                let current = queue.removeFirst()
                region.append(current)

                for neighbor in adjacency[current] {
                    if wrinkleVertices.contains(neighbor) && !visited.contains(neighbor) {
                        queue.append(neighbor)
                        visited.insert(neighbor)
                    }
                }
            }

            if region.count >= 3 {  // Minimum size
                regions.append(region)
            }
        }

        return regions
    }

    /// Estimate depth of a wrinkle region
    private func estimateRegionDepth(
        geometry: FaceMeshGeometry,
        regionVertices: [Int],
        curvatures: [Float]
    ) -> Float {
        // Use curvature as proxy for depth
        let avgCurvature = regionVertices.map { curvatures[$0] }.reduce(0, +) / Float(regionVertices.count)

        // Convert curvature to approximate depth (empirical)
        return avgCurvature * 0.00002  // Scale factor
    }

    /// Estimate length of wrinkle region
    private func estimateRegionLength(
        geometry: FaceMeshGeometry,
        regionVertices: [Int]
    ) -> Float {
        guard regionVertices.count > 1 else { return 0 }

        var totalLength: Float = 0
        for i in 0..<(regionVertices.count - 1) {
            let v1 = geometry.vertices[regionVertices[i]]
            let v2 = geometry.vertices[regionVertices[i + 1]]
            totalLength += distance(v1, v2)
        }

        return totalLength
    }

    /// Identify which face region the wrinkle is in
    private func identifyFaceRegion(
        geometry: FaceMeshGeometry,
        regionVertices: [Int]
    ) -> String {
        // Calculate centroid of region
        let centroid = regionVertices.map { geometry.vertices[$0] }
            .reduce(SIMD3<Float>.zero, +) / Float(regionVertices.count)

        // Simple heuristic based on Y position
        if centroid.y > 0.05 {
            return "forehead"
        } else if centroid.y > 0.0 {
            return "eyes"
        } else if centroid.y > -0.03 {
            return "cheeks"
        } else {
            return "mouth"
        }
    }

    /// Classify overall wrinkle depth
    private func classifyDepth(_ avgDepth: Float) -> WrinkleDepth {
        if avgDepth < 0.0003 {
            return .minimal
        } else if avgDepth < 0.0007 {
            return .shallow
        } else if avgDepth < 0.0012 {
            return .moderate
        } else {
            return .deep
        }
    }

    /// Calculate regional wrinkle scores
    private func calculateRegionalScores(
        geometry: FaceMeshGeometry,
        wrinkleRegions: [WrinkleRegion]
    ) -> [String: Float] {
        var regionScores: [String: (total: Float, count: Int)] = [:]

        for region in wrinkleRegions {
            let score = 100 - (region.depth * 100000)  // Scale to 0-100
            let current = regionScores[region.location, default: (0, 0)]
            regionScores[region.location] = (current.total + score, current.count + 1)
        }

        return regionScores.mapValues { $0.total / Float($0.count) }
    }

    /// Calculate overall wrinkle score
    private func calculateOverallScore(
        avgDepth: Float,
        maxDepth: Float,
        wrinkleCount: Int
    ) -> Float {
        // Lower depth = higher score
        let depthScore = max(0, 100 - (avgDepth * 100000))

        // Fewer wrinkles = higher score
        let countScore = max(0, 100 - Float(wrinkleCount) * 2)

        return (depthScore * 0.7 + countScore * 0.3)
    }
}
