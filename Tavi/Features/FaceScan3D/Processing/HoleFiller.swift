//
//  HoleFiller.swift
//  Tavi
//
//  Detect and fill holes in mesh geometry
//  Important for complete face coverage and accurate metrics
//

import simd

/// Hole filling result
struct HoleFillingResult {
    let filledVertices: [SIMD3<Float>]
    let filledNormals: [SIMD3<Float>]
    let filledTriangles: [Int16]
    let filledTextureCoords: [SIMD2<Float>]
    let holesDetected: Int
    let holesFilled: Int
    let newVerticesAdded: Int
}

/// Mesh hole detection and filling
class HoleFiller {

    // MARK: - Configuration

    private let maxHoleSize = 50  // Maximum boundary vertices to fill
    private let minHoleSize = 3   // Minimum vertices to consider a hole

    // MARK: - Public API

    /// Detect and fill holes in mesh
    func fillHoles(geometry: FaceMeshGeometry) -> HoleFillingResult {
        print("🔧 Detecting holes in mesh...")

        // Build edge connectivity
        let edges = buildEdgeMap(triangles: geometry.triangleIndices)

        // Find boundary loops (edges with only one adjacent triangle)
        let boundaries = findBoundaryLoops(edges: edges, vertexCount: geometry.vertices.count)

        print("   Found \(boundaries.count) boundary loops")

        // Filter fillable holes
        let fillableHoles = boundaries.filter { boundary in
            boundary.count >= minHoleSize && boundary.count <= maxHoleSize
        }

        print("   Fillable holes: \(fillableHoles.count)")

        // Fill holes
        var vertices = geometry.vertices
        var normals = geometry.normals
        var textureCoords = geometry.textureCoordinates
        var triangles = Array(geometry.triangleIndices)
        var newVerticesAdded = 0

        for hole in fillableHoles {
            let (newTris, newVerts, newNorms, newTexCoords) = fillHole(
                boundary: hole,
                vertices: vertices,
                normals: normals,
                textureCoords: textureCoords
            )

            // Add new vertices
            let baseIndex = vertices.count
            vertices.append(contentsOf: newVerts)
            normals.append(contentsOf: newNorms)
            textureCoords.append(contentsOf: newTexCoords)

            // Add new triangles (offset indices)
            for tri in newTris {
                triangles.append(Int16(tri.0))
                triangles.append(Int16(tri.1))
                triangles.append(Int16(tri.2))
            }

            newVerticesAdded += newVerts.count
        }

        print("✅ Filled \(fillableHoles.count) holes")
        print("   Added \(newVerticesAdded) vertices")
        print("   Added \(fillableHoles.count * 3) triangles (approx)")

        return HoleFillingResult(
            filledVertices: vertices,
            filledNormals: normals,
            filledTriangles: triangles,
            filledTextureCoords: textureCoords,
            holesDetected: boundaries.count,
            holesFilled: fillableHoles.count,
            newVerticesAdded: newVerticesAdded
        )
    }

    // MARK: - Private Methods

    /// Build edge connectivity map
    private func buildEdgeMap(triangles: [Int16]) -> [Edge: Int] {
        var edgeCount: [Edge: Int] = [:]

        for i in stride(from: 0, to: triangles.count, by: 3) {
            let v0 = Int(triangles[i])
            let v1 = Int(triangles[i + 1])
            let v2 = Int(triangles[i + 2])

            // Add three edges
            edgeCount[Edge(v0, v1), default: 0] += 1
            edgeCount[Edge(v1, v2), default: 0] += 1
            edgeCount[Edge(v2, v0), default: 0] += 1
        }

        return edgeCount
    }

    /// Find boundary loops (edges with only one adjacent triangle)
    private func findBoundaryLoops(edges: [Edge: Int], vertexCount: Int) -> [[Int]] {
        // Find boundary edges
        let boundaryEdges = edges.filter { $0.value == 1 }.map { $0.key }

        guard !boundaryEdges.isEmpty else { return [] }

        // Build adjacency for boundary vertices
        var adjacency: [Int: Set<Int>] = [:]
        for edge in boundaryEdges {
            adjacency[edge.a, default: []].insert(edge.b)
            adjacency[edge.b, default: []].insert(edge.a)
        }

        // Extract loops
        var loops: [[Int]] = []
        var visited = Set<Int>()

        for startVertex in adjacency.keys {
            guard !visited.contains(startVertex) else { continue }

            var loop: [Int] = [startVertex]
            visited.insert(startVertex)
            var current = startVertex

            // Follow the boundary
            while let neighbors = adjacency[current] {
                let unvisited = neighbors.subtracting(visited)
                guard let next = unvisited.first else { break }

                loop.append(next)
                visited.insert(next)
                current = next

                // Check if loop closed
                if adjacency[current]?.contains(startVertex) == true && loop.count > 2 {
                    break
                }
            }

            if loop.count >= minHoleSize {
                loops.append(loop)
            }
        }

        return loops
    }

    /// Fill a single hole using advancing front triangulation
    private func fillHole(
        boundary: [Int],
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        textureCoords: [SIMD2<Float>]
    ) -> (triangles: [(Int, Int, Int)], newVertices: [SIMD3<Float>], newNormals: [SIMD3<Float>], newTexCoords: [SIMD2<Float>]) {

        // Simple ear-clipping triangulation for small holes
        if boundary.count == 3 {
            // Triangle hole - just create one triangle
            return ([(boundary[0], boundary[1], boundary[2])], [], [], [])
        } else if boundary.count == 4 {
            // Quad hole - create two triangles
            return ([
                (boundary[0], boundary[1], boundary[2]),
                (boundary[0], boundary[2], boundary[3])
            ], [], [], [])
        } else {
            // Larger hole - fan triangulation from centroid
            let boundaryPositions = boundary.map { vertices[$0] }
            let boundaryNormals = boundary.map { normals[$0] }
            let boundaryTexCoords = boundary.map { textureCoords[$0] }

            // Calculate centroid
            let centroid = boundaryPositions.reduce(SIMD3<Float>.zero, +) / Float(boundaryPositions.count)
            let centroidNormal = normalize(boundaryNormals.reduce(SIMD3<Float>.zero, +))
            let centroidTexCoord = boundaryTexCoords.reduce(SIMD2<Float>.zero, +) / Float(boundaryTexCoords.count)

            // Create triangles from each boundary edge to centroid
            let centroidIndex = vertices.count  // Index of new centroid vertex
            var triangles: [(Int, Int, Int)] = []

            for i in 0..<boundary.count {
                let v0 = boundary[i]
                let v1 = boundary[(i + 1) % boundary.count]
                triangles.append((v0, v1, centroidIndex))
            }

            return (triangles, [centroid], [centroidNormal], [centroidTexCoord])
        }
    }
}

// MARK: - Edge

/// Unordered edge representation
private struct Edge: Hashable {
    let a: Int
    let b: Int

    init(_ a: Int, _ b: Int) {
        if a < b {
            self.a = a
            self.b = b
        } else {
            self.a = b
            self.b = a
        }
    }
}

// MARK: - FaceMeshGeometry Extension

extension FaceMeshGeometry {
    /// Fill holes in mesh
    func withFilledHoles() -> FaceMeshGeometry {
        let filler = HoleFiller()
        let result = filler.fillHoles(geometry: self)

        return FaceMeshGeometry(
            vertices: result.filledVertices,
            normals: result.filledNormals,
            textureCoordinates: result.filledTextureCoords,
            triangleIndices: result.filledTriangles
        )
    }
}
