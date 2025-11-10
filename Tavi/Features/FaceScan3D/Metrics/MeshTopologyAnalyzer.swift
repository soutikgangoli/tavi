//
//  MeshTopologyAnalyzer.swift
//  Tavi
//
//  Advanced mesh topology analysis for quality validation
//  Created on 2025-10-28.
//

import Foundation
import simd

/// Mesh topology quality analysis results
public struct TopologyAnalysis: Codable, Sendable {
    /// Overall topology quality score (0-100)
    public let overallScore: Float

    /// Mesh manifoldness check
    public let isManifold: Bool

    /// Mesh is watertight (no boundary edges)
    public let isWatertight: Bool

    /// Number of non-manifold edges (shared by >2 triangles)
    public let nonManifoldEdges: Int

    /// Number of non-manifold vertices
    public let nonManifoldVertices: Int

    /// Vertex valence statistics
    public let vertexValenceStats: ValenceStatistics

    /// Triangle quality metrics
    public let triangleQuality: TriangleQualityMetrics

    /// Curvature discontinuities (sharp edges/creases)
    public let curvatureDiscontinuities: Int

    /// Euler characteristic (should be 2 for sphere-like surface)
    public let eulerCharacteristic: Int

    /// Self-intersections detected
    public let hasSelfIntersections: Bool

    /// Number of degenerate triangles (zero area)
    public let degenerateTriangles: Int

    /// Overall topology quality level
    public var qualityLevel: TopologyQuality {
        if overallScore >= 90 { return .excellent }
        if overallScore >= 75 { return .good }
        if overallScore >= 60 { return .acceptable }
        if overallScore >= 40 { return .poor }
        return .invalid
    }

    /// Human-readable quality description
    public var qualityDescription: String {
        return qualityLevel.description
    }
}

/// Topology quality levels
public enum TopologyQuality: String, Codable {
    case excellent = "Excellent"
    case good = "Good"
    case acceptable = "Acceptable"
    case poor = "Poor"
    case invalid = "Invalid"

    var description: String { rawValue }
}

/// Vertex valence statistics (number of edges per vertex)
public struct ValenceStatistics: Codable, Sendable {
    /// Average valence (ideal: ~6 for regular triangulation)
    public let averageValence: Float

    /// Minimum valence
    public let minValence: Int

    /// Maximum valence
    public let maxValence: Int

    /// Number of irregular vertices (valence != 6)
    public let irregularVertices: Int

    /// Percentage of vertices with ideal valence (5-7)
    public let idealValenceRatio: Float
}

/// Triangle quality metrics
public struct TriangleQualityMetrics: Codable, Sendable {
    /// Average aspect ratio (ideal: 1.0 for equilateral)
    public let averageAspectRatio: Float

    /// Minimum angle in mesh (degrees)
    public let minAngle: Float

    /// Maximum angle in mesh (degrees)
    public let maxAngle: Float

    /// Percentage of well-shaped triangles (aspect ratio < 2.0)
    public let wellShapedRatio: Float

    /// Average triangle area
    public let averageArea: Float

    /// Triangle area standard deviation (uniformity)
    public let areaStdDev: Float
}

/// Advanced mesh topology analyzer
public class MeshTopologyAnalyzer {

    // MARK: - Public API

    /// Analyze mesh topology quality
    public func analyzeTopology(geometry: FaceMeshGeometry) -> TopologyAnalysis {
        AppLogger.metrics.info("🔬 MeshTopologyAnalyzer: Starting topology analysis...")

        let vertices = geometry.vertices
        let triangles = geometry.triangleIndices
        let vertexCount = vertices.count
        let triangleCount = triangles.count / 3

        // Build edge adjacency data structure
        let edgeData = buildEdgeAdjacency(vertices: vertices, triangles: triangles)

        // 1. Check manifoldness
        let (isManifold, nonManifoldEdges, nonManifoldVertices) = checkManifoldness(edgeData: edgeData, vertexCount: vertexCount)

        // 2. Check watertightness (no boundary edges)
        let isWatertight = checkWatertight(edgeData: edgeData)

        // 3. Compute vertex valence statistics
        let valenceStats = computeValenceStatistics(edgeData: edgeData, vertexCount: vertexCount)

        // 4. Compute triangle quality metrics
        let triangleQuality = computeTriangleQuality(vertices: vertices, triangles: triangles)

        // 5. Detect curvature discontinuities
        let curvatureDiscontinuities = detectCurvatureDiscontinuities(
            vertices: vertices,
            triangles: triangles,
            normals: geometry.normals,
            edgeData: edgeData
        )

        // 6. Compute Euler characteristic
        let eulerCharacteristic = computeEulerCharacteristic(
            vertexCount: vertexCount,
            edgeCount: edgeData.edges.count,
            faceCount: triangleCount
        )

        // 7. Check for self-intersections (simplified check)
        let hasSelfIntersections = detectSelfIntersections(vertices: vertices, triangles: triangles)

        // 8. Count degenerate triangles
        let degenerateTriangles = countDegenerateTriangles(vertices: vertices, triangles: triangles)

        // Compute overall quality score
        let overallScore = computeOverallScore(
            isManifold: isManifold,
            isWatertight: isWatertight,
            nonManifoldEdges: nonManifoldEdges,
            nonManifoldVertices: nonManifoldVertices,
            valenceStats: valenceStats,
            triangleQuality: triangleQuality,
            curvatureDiscontinuities: curvatureDiscontinuities,
            eulerCharacteristic: eulerCharacteristic,
            hasSelfIntersections: hasSelfIntersections,
            degenerateTriangles: degenerateTriangles,
            totalTriangles: triangleCount
        )

        let analysis = TopologyAnalysis(
            overallScore: overallScore,
            isManifold: isManifold,
            isWatertight: isWatertight,
            nonManifoldEdges: nonManifoldEdges,
            nonManifoldVertices: nonManifoldVertices,
            vertexValenceStats: valenceStats,
            triangleQuality: triangleQuality,
            curvatureDiscontinuities: curvatureDiscontinuities,
            eulerCharacteristic: eulerCharacteristic,
            hasSelfIntersections: hasSelfIntersections,
            degenerateTriangles: degenerateTriangles
        )

        AppLogger.metrics.info("Topology Analysis Results:")
        AppLogger.metrics.info("- Overall Score: \(String(format: "%.1f", overallScore))/100 (\(analysis.qualityLevel))")
        AppLogger.metrics.info("- Manifold: \(isManifold) (non-manifold edges: \(nonManifoldEdges), vertices: \(nonManifoldVertices))")
        AppLogger.metrics.info("- Watertight: \(isWatertight)")
        AppLogger.metrics.info("- Valence: avg=\(String(format: "%.1f", valenceStats.averageValence)), ideal ratio=\(String(format: "%.1f%%", valenceStats.idealValenceRatio * 100))")
        AppLogger.metrics.info("- Triangle Quality: aspect ratio=\(String(format: "%.2f", triangleQuality.averageAspectRatio)), well-shaped=\(String(format: "%.1f%%", triangleQuality.wellShapedRatio * 100))")
        AppLogger.metrics.info("- Euler Characteristic: \(eulerCharacteristic) (expected: 2 for sphere)")
        AppLogger.metrics.info("- Curvature Discontinuities: \(curvatureDiscontinuities)")
        AppLogger.metrics.info("- Degenerate Triangles: \(degenerateTriangles)")
        AppLogger.metrics.info("- Self-Intersections: \(hasSelfIntersections)")

        return analysis
    }

    // MARK: - Edge Adjacency Data Structure

    private struct EdgeData {
        var edges: [Edge: EdgeInfo] = [:]
        var vertexNeighbors: [Int: Set<Int>] = [:]
    }

    private struct Edge: Hashable {
        let v0: Int32
        let v1: Int32

        init(_ a: Int32, _ b: Int32) {
            // Ensure consistent ordering
            if a < b {
                v0 = a
                v1 = b
            } else {
                v0 = b
                v1 = a
            }
        }
    }

    private struct EdgeInfo {
        var triangleCount: Int = 0
        var triangles: [Int] = []
    }

    private func buildEdgeAdjacency(vertices: [SIMD3<Float>], triangles: [Int32]) -> EdgeData {
        var edgeData = EdgeData()

        // Initialize vertex neighbors
        for i in 0..<vertices.count {
            edgeData.vertexNeighbors[i] = Set<Int>()
        }

        // Process each triangle
        for i in stride(from: 0, to: triangles.count, by: 3) {
            let v0 = triangles[i]
            let v1 = triangles[i + 1]
            let v2 = triangles[i + 2]

            let triangleIdx = i / 3

            // Add three edges
            let edges = [
                Edge(v0, v1),
                Edge(v1, v2),
                Edge(v2, v0)
            ]

            for edge in edges {
                if edgeData.edges[edge] == nil {
                    edgeData.edges[edge] = EdgeInfo()
                }
                if var edgeInfo = edgeData.edges[edge] {
                    edgeInfo.triangleCount += 1
                    edgeInfo.triangles.append(triangleIdx)
                    edgeData.edges[edge] = edgeInfo
                }
            }

            // Build vertex neighbor lists
            edgeData.vertexNeighbors[Int(v0)]?.insert(Int(v1))
            edgeData.vertexNeighbors[Int(v0)]?.insert(Int(v2))
            edgeData.vertexNeighbors[Int(v1)]?.insert(Int(v0))
            edgeData.vertexNeighbors[Int(v1)]?.insert(Int(v2))
            edgeData.vertexNeighbors[Int(v2)]?.insert(Int(v0))
            edgeData.vertexNeighbors[Int(v2)]?.insert(Int(v1))
        }

        return edgeData
    }

    // MARK: - Manifoldness Check

    private func checkManifoldness(edgeData: EdgeData, vertexCount: Int) -> (Bool, Int, Int) {
        // A manifold mesh has:
        // 1. Each edge shared by at most 2 triangles
        // 2. Each vertex has a single connected neighborhood

        var nonManifoldEdgeCount = 0

        // Check edges
        for (_, info) in edgeData.edges {
            if info.triangleCount > 2 {
                nonManifoldEdgeCount += 1
            }
        }

        // Check vertices (simplified: count vertices with extremely high valence)
        var nonManifoldVertexCount = 0
        for (_, neighbors) in edgeData.vertexNeighbors {
            if neighbors.count > 20 {  // Abnormally high valence
                nonManifoldVertexCount += 1
            }
        }

        let isManifold = nonManifoldEdgeCount == 0 && nonManifoldVertexCount == 0

        return (isManifold, nonManifoldEdgeCount, nonManifoldVertexCount)
    }

    // MARK: - Watertight Check

    private func checkWatertight(edgeData: EdgeData) -> Bool {
        // Watertight = no boundary edges (all edges shared by exactly 2 triangles)
        for (_, info) in edgeData.edges {
            if info.triangleCount != 2 {
                return false
            }
        }
        return true
    }

    // MARK: - Vertex Valence Statistics

    private func computeValenceStatistics(edgeData: EdgeData, vertexCount: Int) -> ValenceStatistics {
        var valences: [Int] = []
        var irregularCount = 0
        var idealCount = 0

        for (_, neighbors) in edgeData.vertexNeighbors {
            let valence = neighbors.count
            valences.append(valence)

            if valence != 6 {
                irregularCount += 1
            }

            if valence >= 5 && valence <= 7 {
                idealCount += 1
            }
        }

        let avgValence = valences.isEmpty ? 0 : Float(valences.reduce(0, +)) / Float(valences.count)
        let minValence = valences.min() ?? 0
        let maxValence = valences.max() ?? 0
        let idealValenceRatio = valences.isEmpty ? 0 : Float(idealCount) / Float(valences.count)

        return ValenceStatistics(
            averageValence: avgValence,
            minValence: minValence,
            maxValence: maxValence,
            irregularVertices: irregularCount,
            idealValenceRatio: idealValenceRatio
        )
    }

    // MARK: - Triangle Quality

    private func computeTriangleQuality(vertices: [SIMD3<Float>], triangles: [Int32]) -> TriangleQualityMetrics {
        var aspectRatios: [Float] = []
        var angles: [Float] = []
        var areas: [Float] = []
        var wellShapedCount = 0

        for i in stride(from: 0, to: triangles.count, by: 3) {
            let v0 = vertices[Int(triangles[i])]
            let v1 = vertices[Int(triangles[i + 1])]
            let v2 = vertices[Int(triangles[i + 2])]

            // Edge lengths
            let e0 = distance(v1, v2)
            let e1 = distance(v2, v0)
            let e2 = distance(v0, v1)

            // Aspect ratio (max edge / min edge)
            let maxEdge = max(e0, max(e1, e2))
            let minEdge = min(e0, min(e1, e2))
            let aspectRatio = minEdge > 0 ? maxEdge / minEdge : 10.0
            aspectRatios.append(aspectRatio)

            if aspectRatio < 2.0 {
                wellShapedCount += 1
            }

            // Compute angles using law of cosines
            let angle0 = computeAngle(a: e1, b: e2, c: e0)
            let angle1 = computeAngle(a: e2, b: e0, c: e1)
            let angle2 = computeAngle(a: e0, b: e1, c: e2)

            angles.append(angle0)
            angles.append(angle1)
            angles.append(angle2)

            // Triangle area (cross product magnitude / 2)
            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let crossProduct = cross(edge1, edge2)
            let area = length(crossProduct) / 2.0
            areas.append(area)
        }

        let avgAspectRatio = aspectRatios.isEmpty ? 0 : aspectRatios.reduce(0, +) / Float(aspectRatios.count)
        let minAngle = angles.min() ?? 0
        let maxAngle = angles.max() ?? 0
        let wellShapedRatio = aspectRatios.isEmpty ? 0 : Float(wellShapedCount) / Float(aspectRatios.count)
        let avgArea = areas.isEmpty ? 0 : areas.reduce(0, +) / Float(areas.count)

        // Compute standard deviation of areas
        let areaVariance = areas.isEmpty ? 0 : areas.map { pow($0 - avgArea, 2) }.reduce(0, +) / Float(areas.count)
        let areaStdDev = sqrt(areaVariance)

        return TriangleQualityMetrics(
            averageAspectRatio: avgAspectRatio,
            minAngle: minAngle,
            maxAngle: maxAngle,
            wellShapedRatio: wellShapedRatio,
            averageArea: avgArea,
            areaStdDev: areaStdDev
        )
    }

    private func computeAngle(a: Float, b: Float, c: Float) -> Float {
        // Law of cosines: c² = a² + b² - 2ab·cos(C)
        // cos(C) = (a² + b² - c²) / (2ab)

        let cosC = (a * a + b * b - c * c) / (2 * a * b)
        let clampedCosC = max(-1.0, min(1.0, cosC))  // Clamp to valid range
        let angleRad = acos(clampedCosC)
        let angleDeg = angleRad * 180.0 / .pi

        return angleDeg
    }

    // MARK: - Curvature Discontinuities

    private func detectCurvatureDiscontinuities(
        vertices: [SIMD3<Float>],
        triangles: [Int32],
        normals: [SIMD3<Float>],
        edgeData: EdgeData
    ) -> Int {
        // Sharp edges = adjacent triangles with very different normals

        var discontinuityCount = 0

        for (_, info) in edgeData.edges {
            guard info.triangles.count == 2 else { continue }

            let tri0 = info.triangles[0]
            let tri1 = info.triangles[1]

            // Get triangle normals (average of vertex normals)
            let tri0Verts = [
                Int(triangles[tri0 * 3]),
                Int(triangles[tri0 * 3 + 1]),
                Int(triangles[tri0 * 3 + 2])
            ]

            let tri1Verts = [
                Int(triangles[tri1 * 3]),
                Int(triangles[tri1 * 3 + 1]),
                Int(triangles[tri1 * 3 + 2])
            ]

            let normal0 = normalize((normals[tri0Verts[0]] + normals[tri0Verts[1]] + normals[tri0Verts[2]]) / 3.0)
            let normal1 = normalize((normals[tri1Verts[0]] + normals[tri1Verts[1]] + normals[tri1Verts[2]]) / 3.0)

            // Compute angle between normals
            let dotProduct = dot(normal0, normal1)
            let angleRad = acos(max(-1.0, min(1.0, dotProduct)))
            let angleDeg = angleRad * 180.0 / .pi

            // Sharp edge = angle > 30 degrees
            if angleDeg > 30.0 {
                discontinuityCount += 1
            }
        }

        return discontinuityCount
    }

    // MARK: - Euler Characteristic

    private func computeEulerCharacteristic(vertexCount: Int, edgeCount: Int, faceCount: Int) -> Int {
        // Euler's formula: V - E + F = 2 for a closed, sphere-like surface
        return vertexCount - edgeCount + faceCount
    }

    // MARK: - Self-Intersection Detection

    private func detectSelfIntersections(vertices: [SIMD3<Float>], triangles: [Int32]) -> Bool {
        // Simplified self-intersection check (full check is O(n²), very expensive)
        // Just check for vertices that are extremely close to non-adjacent triangles

        // Sample 10% of triangles for performance
        let sampleSize = max(10, triangles.count / 30)

        for i in stride(from: 0, to: min(sampleSize, triangles.count), by: 3) {
            let v0 = vertices[Int(triangles[i])]
            let v1 = vertices[Int(triangles[i + 1])]
            let v2 = vertices[Int(triangles[i + 2])]

            let triCenter = (v0 + v1 + v2) / 3.0

            // Check if any other vertex is very close to this triangle's center
            for j in 0..<vertices.count {
                if j == Int(triangles[i]) || j == Int(triangles[i + 1]) || j == Int(triangles[i + 2]) {
                    continue
                }

                let dist = distance(vertices[j], triCenter)

                if dist < 0.001 {  // Less than 1mm = likely intersection
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Degenerate Triangle Detection

    private func countDegenerateTriangles(vertices: [SIMD3<Float>], triangles: [Int32]) -> Int {
        var degenerateCount = 0

        for i in stride(from: 0, to: triangles.count, by: 3) {
            let v0 = vertices[Int(triangles[i])]
            let v1 = vertices[Int(triangles[i + 1])]
            let v2 = vertices[Int(triangles[i + 2])]

            // Triangle area
            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let crossProduct = cross(edge1, edge2)
            let area = length(crossProduct) / 2.0

            // Degenerate if area is essentially zero
            if area < 0.0000001 {
                degenerateCount += 1
            }
        }

        return degenerateCount
    }

    // MARK: - Overall Score Computation

    private func computeOverallScore(
        isManifold: Bool,
        isWatertight: Bool,
        nonManifoldEdges: Int,
        nonManifoldVertices: Int,
        valenceStats: ValenceStatistics,
        triangleQuality: TriangleQualityMetrics,
        curvatureDiscontinuities: Int,
        eulerCharacteristic: Int,
        hasSelfIntersections: Bool,
        degenerateTriangles: Int,
        totalTriangles: Int
    ) -> Float {
        var score: Float = 100.0

        // Manifoldness (critical) - 25 points
        if !isManifold {
            score -= 25.0
        }

        // Watertightness - 15 points
        if !isWatertight {
            score -= 15.0
        }

        // Non-manifold elements - up to 10 points penalty
        let nonManifoldRatio = Float(nonManifoldEdges + nonManifoldVertices) / Float(totalTriangles)
        score -= min(10.0, nonManifoldRatio * 100.0)

        // Vertex valence quality - 20 points
        let valenceScore = valenceStats.idealValenceRatio * 20.0
        score -= (20.0 - valenceScore)

        // Triangle quality - 15 points
        let triangleScore = triangleQuality.wellShapedRatio * 15.0
        score -= (15.0 - triangleScore)

        // Curvature discontinuities - up to 5 points
        let discontinuityRatio = Float(curvatureDiscontinuities) / Float(totalTriangles)
        score -= min(5.0, discontinuityRatio * 50.0)

        // Euler characteristic - 5 points
        if eulerCharacteristic != 2 {
            score -= 5.0
        }

        // Self-intersections (critical) - 10 points
        if hasSelfIntersections {
            score -= 10.0
        }

        // Degenerate triangles - up to 5 points
        let degenerateRatio = Float(degenerateTriangles) / Float(totalTriangles)
        score -= min(5.0, degenerateRatio * 100.0)

        return max(0, min(100, score))
    }
}
