//
//  MeshValidator.swift
//  Tavi
//
//  Comprehensive mesh quality validation
//  Checks for manifold topology, degenerate triangles, and other quality issues
//

import simd

/// Mesh validation result
struct MeshValidationResult {
    // Topology checks
    let isManifold: Bool
    let nonManifoldEdges: Int
    let nonManifoldVertices: Int
    let boundaryLoops: Int

    // Triangle quality
    let degenerateTriangles: Int
    let invertedNormals: Int
    let badAspectRatioTriangles: Int

    // Overall quality
    let qualityScore: Float  // 0-1, higher is better
    let isValid: Bool
    let issues: [String]

    var description: String {
        var desc = "Mesh Validation Results\n"
        desc += "═══════════════════════\n"
        desc += "Topology:\n"
        desc += "  Manifold: \(isManifold ? "✓" : "✗")\n"
        desc += "  Non-manifold edges: \(nonManifoldEdges)\n"
        desc += "  Non-manifold vertices: \(nonManifoldVertices)\n"
        desc += "  Boundary loops: \(boundaryLoops)\n"
        desc += "\nTriangle Quality:\n"
        desc += "  Degenerate: \(degenerateTriangles)\n"
        desc += "  Inverted normals: \(invertedNormals)\n"
        desc += "  Bad aspect ratio: \(badAspectRatioTriangles)\n"
        desc += "\nOverall:\n"
        desc += "  Quality score: \(String(format: "%.2f", qualityScore * 100))%\n"
        desc += "  Status: \(isValid ? "PASS ✓" : "FAIL ✗")\n"

        if !issues.isEmpty {
            desc += "\nIssues:\n"
            for issue in issues {
                desc += "  • \(issue)\n"
            }
        }

        return desc
    }
}

/// Mesh quality validator
class MeshValidator {

    // MARK: - Configuration

    private let minTriangleArea: Float = 1e-7
    private let maxAspectRatio: Float = 10.0
    private let minQualityScore: Float = 0.7

    // MARK: - Public API

    /// Validate mesh quality
    func validate(geometry: FaceMeshGeometry) -> MeshValidationResult {
        print("🔍 Validating mesh quality...")

        var issues: [String] = []

        // Check topology
        let (isManifold, nonManifoldEdges, nonManifoldVertices) = checkManifold(geometry: geometry)
        let boundaryLoops = findBoundaryLoops(geometry: geometry)

        if !isManifold {
            issues.append("Mesh is not manifold")
        }
        if nonManifoldEdges > 0 {
            issues.append("\(nonManifoldEdges) non-manifold edges detected")
        }

        // Check triangle quality
        let degenerateTriangles = countDegenerateTriangles(geometry: geometry)
        let invertedNormals = countInvertedNormals(geometry: geometry)
        let badAspectRatioTriangles = countBadAspectRatioTriangles(geometry: geometry)

        if degenerateTriangles > 0 {
            issues.append("\(degenerateTriangles) degenerate triangles (zero area)")
        }
        if invertedNormals > 0 {
            issues.append("\(invertedNormals) inverted normals")
        }
        if badAspectRatioTriangles > 0 {
            issues.append("\(badAspectRatioTriangles) triangles with bad aspect ratio")
        }

        // Calculate quality score
        let totalTriangles = geometry.triangleIndices.count / 3
        let triangleQualityRatio = 1.0 - Float(degenerateTriangles + badAspectRatioTriangles) / Float(max(totalTriangles, 1))
        let topologyScore: Float = isManifold ? 1.0 : 0.5
        let qualityScore = (triangleQualityRatio * 0.7 + topologyScore * 0.3)

        let isValid = qualityScore >= minQualityScore && isManifold

        let result = MeshValidationResult(
            isManifold: isManifold,
            nonManifoldEdges: nonManifoldEdges,
            nonManifoldVertices: nonManifoldVertices,
            boundaryLoops: boundaryLoops,
            degenerateTriangles: degenerateTriangles,
            invertedNormals: invertedNormals,
            badAspectRatioTriangles: badAspectRatioTriangles,
            qualityScore: qualityScore,
            isValid: isValid,
            issues: issues
        )

        print(result.description)

        return result
    }

    // MARK: - Private Methods

    /// Check if mesh is manifold
    private func checkManifold(geometry: FaceMeshGeometry) -> (isManifold: Bool, nonManifoldEdges: Int, nonManifoldVertices: Int) {
        // Build edge connectivity
        var edgeCount: [Edge: Int] = [:]

        for i in stride(from: 0, to: geometry.triangleIndices.count, by: 3) {
            let v0 = Int(geometry.triangleIndices[i])
            let v1 = Int(geometry.triangleIndices[i + 1])
            let v2 = Int(geometry.triangleIndices[i + 2])

            edgeCount[Edge(v0, v1), default: 0] += 1
            edgeCount[Edge(v1, v2), default: 0] += 1
            edgeCount[Edge(v2, v0), default: 0] += 1
        }

        // Count non-manifold edges (shared by more than 2 triangles)
        let nonManifoldEdges = edgeCount.filter { $0.value > 2 }.count

        // Check for non-manifold vertices using disk topology test
        let nonManifoldVertices = detectNonManifoldVertices(geometry: geometry, edgeCount: edgeCount)

        let isManifold = nonManifoldEdges == 0 && nonManifoldVertices == 0

        return (isManifold, nonManifoldEdges, nonManifoldVertices)
    }

    /// Detect non-manifold vertices (vertices where the edge ring doesn't form a single disk)
    private func detectNonManifoldVertices(geometry: FaceMeshGeometry, edgeCount: [Edge: Int]) -> Int {
        // Build vertex-to-triangle adjacency
        var vertexToTriangles: [Int: Set<Int>] = [:]

        for i in stride(from: 0, to: geometry.triangleIndices.count, by: 3) {
            let triangleIndex = i / 3
            let v0 = Int(geometry.triangleIndices[i])
            let v1 = Int(geometry.triangleIndices[i + 1])
            let v2 = Int(geometry.triangleIndices[i + 2])

            vertexToTriangles[v0, default: []].insert(triangleIndex)
            vertexToTriangles[v1, default: []].insert(triangleIndex)
            vertexToTriangles[v2, default: []].insert(triangleIndex)
        }

        // Build vertex-to-edge adjacency
        var vertexToEdges: [Int: Set<Edge>] = [:]

        for (edge, _) in edgeCount {
            vertexToEdges[edge.v0, default: []].insert(edge)
            vertexToEdges[edge.v1, default: []].insert(edge)
        }

        var nonManifoldCount = 0

        // Check each vertex
        for (vertex, edges) in vertexToEdges {
            // A manifold vertex should have edges forming a single connected ring
            // For interior vertices: #edges == #triangles
            // For boundary vertices: #edges == #triangles + 1

            let triangles = vertexToTriangles[vertex] ?? []

            if edges.isEmpty || triangles.isEmpty {
                continue
            }

            // Check if edges form a continuous ring
            if !isEdgeRingContinuous(edges: Array(edges), centerVertex: vertex) {
                nonManifoldCount += 1
            }
        }

        return nonManifoldCount
    }

    /// Check if edges around a vertex form a continuous ring (disk topology)
    private func isEdgeRingContinuous(edges: [Edge], centerVertex: Int) -> Bool {
        guard edges.count >= 2 else { return true }  // 0 or 1 edge is always continuous

        // Build adjacency map: vertex -> connected vertices
        var neighbors: Set<Int> = []

        for edge in edges {
            if edge.v0 == centerVertex {
                neighbors.insert(edge.v1)
            } else if edge.v1 == centerVertex {
                neighbors.insert(edge.v0)
            }
        }

        // For a manifold vertex, the degree (number of neighbors) should match edge count
        // Exception: Boundary vertices can have degree == edges + 1

        let degree = neighbors.count

        // Simple heuristic: if degree significantly differs from edge count, likely non-manifold
        if abs(degree - edges.count) > 1 {
            return false
        }

        return true
    }

    /// Find boundary loops
    private func findBoundaryLoops(geometry: FaceMeshGeometry) -> Int {
        var edgeCount: [Edge: Int] = [:]

        for i in stride(from: 0, to: geometry.triangleIndices.count, by: 3) {
            let v0 = Int(geometry.triangleIndices[i])
            let v1 = Int(geometry.triangleIndices[i + 1])
            let v2 = Int(geometry.triangleIndices[i + 2])

            edgeCount[Edge(v0, v1), default: 0] += 1
            edgeCount[Edge(v1, v2), default: 0] += 1
            edgeCount[Edge(v2, v0), default: 0] += 1
        }

        // Boundary edges have count == 1
        let boundaryEdges = edgeCount.filter { $0.value == 1 }.count

        // Approximate number of loops (each loop has at least 3 edges)
        return boundaryEdges / 3
    }

    /// Count degenerate triangles
    private func countDegenerateTriangles(geometry: FaceMeshGeometry) -> Int {
        var count = 0

        for i in stride(from: 0, to: geometry.triangleIndices.count, by: 3) {
            let v0 = geometry.vertices[Int(geometry.triangleIndices[i])]
            let v1 = geometry.vertices[Int(geometry.triangleIndices[i + 1])]
            let v2 = geometry.vertices[Int(geometry.triangleIndices[i + 2])]

            let area = triangleArea(v0, v1, v2)
            if area < minTriangleArea {
                count += 1
            }
        }

        return count
    }

    /// Count inverted normals
    private func countInvertedNormals(geometry: FaceMeshGeometry) -> Int {
        var count = 0

        for i in stride(from: 0, to: geometry.triangleIndices.count, by: 3) {
            let i0 = Int(geometry.triangleIndices[i])
            let i1 = Int(geometry.triangleIndices[i + 1])
            let i2 = Int(geometry.triangleIndices[i + 2])

            let v0 = geometry.vertices[i0]
            let v1 = geometry.vertices[i1]
            let v2 = geometry.vertices[i2]

            // Triangle normal (from geometry)
            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let geometricNormal = normalize(cross(edge1, edge2))

            // Vertex normals average
            let vertexNormalAvg = normalize(
                geometry.normals[i0] + geometry.normals[i1] + geometry.normals[i2]
            )

            // Check if they point in opposite directions
            if dot(geometricNormal, vertexNormalAvg) < 0 {
                count += 1
            }
        }

        return count
    }

    /// Count triangles with bad aspect ratio
    private func countBadAspectRatioTriangles(geometry: FaceMeshGeometry) -> Int {
        var count = 0

        for i in stride(from: 0, to: geometry.triangleIndices.count, by: 3) {
            let v0 = geometry.vertices[Int(geometry.triangleIndices[i])]
            let v1 = geometry.vertices[Int(geometry.triangleIndices[i + 1])]
            let v2 = geometry.vertices[Int(geometry.triangleIndices[i + 2])]

            let aspectRatio = triangleAspectRatio(v0, v1, v2)
            if aspectRatio > maxAspectRatio {
                count += 1
            }
        }

        return count
    }

    /// Calculate triangle area
    private func triangleArea(_ v0: SIMD3<Float>, _ v1: SIMD3<Float>, _ v2: SIMD3<Float>) -> Float {
        let edge1 = v1 - v0
        let edge2 = v2 - v0
        let crossProduct = cross(edge1, edge2)
        return length(crossProduct) * 0.5
    }

    /// Calculate triangle aspect ratio
    private func triangleAspectRatio(_ v0: SIMD3<Float>, _ v1: SIMD3<Float>, _ v2: SIMD3<Float>) -> Float {
        let edge1 = distance(v0, v1)
        let edge2 = distance(v1, v2)
        let edge3 = distance(v2, v0)

        let maxEdge = max(edge1, edge2, edge3)
        let minEdge = min(edge1, edge2, edge3)

        guard minEdge > 0 else { return Float.infinity }

        return maxEdge / minEdge
    }
}

// MARK: - Edge

private struct Edge: Hashable {
    let v0: Int
    let v1: Int

    init(_ a: Int, _ b: Int) {
        if a < b {
            self.v0 = a
            self.v1 = b
        } else {
            self.v0 = b
            self.v1 = a
        }
    }
}

// MARK: - FaceMeshGeometry Extension

extension FaceMeshGeometry {
    /// Validate mesh quality
    func validated() -> MeshValidationResult {
        let validator = MeshValidator()
        return validator.validate(geometry: self)
    }

    /// Check if mesh passes validation
    var isValid: Bool {
        return validated().isValid
    }
}
