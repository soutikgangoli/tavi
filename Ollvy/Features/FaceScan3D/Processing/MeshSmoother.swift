//
//  MeshSmoother.swift
//  Ollvy
//
//  Taubin smoothing algorithm for mesh refinement
//  Superior to Laplacian smoothing - preserves volume and features while removing noise
//

import simd

/// Mesh smoothing result
struct SmoothingResult {
    let smoothedVertices: [SIMD3<Float>]
    let smoothedNormals: [SIMD3<Float>]
    let iterations: Int
    let avgDisplacement: Float
}

/// Taubin mesh smoother
class MeshSmoother {

    // MARK: - Configuration

    /// Smoothing parameters (Taubin's magic numbers)
    private let lambda: Float = 0.5      // Smoothing factor
    private let mu: Float = -0.53        // Inflation factor (negative, slightly larger than lambda)
    private let defaultIterations = 5    // Good balance of smoothness vs speed

    // MARK: - Public API

    /// Smooth mesh using Taubin smoothing
    /// - Parameters:
    ///   - geometry: Input mesh geometry
    ///   - iterations: Number of smoothing iterations (default: 5)
    ///   - preserveFeatures: If true, use feature-preserving variant
    /// - Returns: Smoothed mesh
    func smooth(
        geometry: FaceMeshGeometry,
        iterations: Int? = nil,
        preserveFeatures: Bool = true
    ) -> SmoothingResult {
        let iterationCount = iterations ?? defaultIterations
        AppLogger.mesh.info("🔮 Smoothing mesh with Taubin algorithm...")
        AppLogger.mesh.debug("   Vertices: \(geometry.vertices.count)")
        AppLogger.mesh.debug("   Iterations: \(iterationCount)")

        var currentVertices = geometry.vertices
        let triangleIndices = geometry.triangleIndices

        // Build adjacency list for efficient neighbor queries
        let adjacency = buildAdjacencyList(vertices: geometry.vertices, triangles: triangleIndices)

        // Feature edge detection (if preserving features)
        let featureEdges: Set<UnorderedPair>? = preserveFeatures
            ? detectFeatureEdges(vertices: geometry.vertices, normals: geometry.normals, adjacency: adjacency)
            : nil

        // Taubin smoothing iterations
        var totalDisplacement: Float = 0

        for iteration in 0..<iterationCount {
            // Smoothing pass (shrinking, lambda > 0)
            let smoothedVertices = applyLaplacian(
                vertices: currentVertices,
                adjacency: adjacency,
                factor: lambda,
                featureEdges: featureEdges
            )

            // Inflation pass (expanding, mu < 0)
            currentVertices = applyLaplacian(
                vertices: smoothedVertices,
                adjacency: adjacency,
                factor: mu,
                featureEdges: featureEdges
            )

            // Track displacement
            if iteration == iterationCount - 1 {
                totalDisplacement = calculateAverageDisplacement(
                    from: geometry.vertices,
                    to: currentVertices
                )
            }
        }

        // Recalculate normals
        let smoothedNormals = recalculateNormals(
            vertices: currentVertices,
            triangles: triangleIndices
        )

        AppLogger.mesh.info("✅ Smoothing complete")
        AppLogger.mesh.debug("   Avg displacement: \(String(format: "%.4f", totalDisplacement))m")

        return SmoothingResult(
            smoothedVertices: currentVertices,
            smoothedNormals: smoothedNormals,
            iterations: iterationCount,
            avgDisplacement: totalDisplacement
        )
    }

    // MARK: - Private Methods

    /// Build vertex adjacency list
    private func buildAdjacencyList(vertices: [SIMD3<Float>], triangles: [Int32]) -> [[Int]] {
        var adjacency = Array(repeating: Set<Int>(), count: vertices.count)

        for i in stride(from: 0, to: triangles.count, by: 3) {
            let v0 = Int(triangles[i])
            let v1 = Int(triangles[i + 1])
            let v2 = Int(triangles[i + 2])

            adjacency[v0].insert(v1)
            adjacency[v0].insert(v2)
            adjacency[v1].insert(v0)
            adjacency[v1].insert(v2)
            adjacency[v2].insert(v0)
            adjacency[v2].insert(v1)
        }

        return adjacency.map { Array($0) }
    }

    /// Apply Laplacian smoothing operator
    private func applyLaplacian(
        vertices: [SIMD3<Float>],
        adjacency: [[Int]],
        factor: Float,
        featureEdges: Set<UnorderedPair>?
    ) -> [SIMD3<Float>] {
        return vertices.enumerated().map { index, vertex in
            let neighbors = adjacency[index]
            guard !neighbors.isEmpty else { return vertex }

            // Calculate Laplacian (average of neighbors - current)
            var filteredNeighbors = neighbors

            // If preserving features, exclude neighbors across feature edges
            if let featureEdges = featureEdges {
                filteredNeighbors = neighbors.filter { neighbor in
                    !featureEdges.contains(UnorderedPair(index, neighbor))
                }
            }

            guard !filteredNeighbors.isEmpty else { return vertex }

            let neighborSum = filteredNeighbors.reduce(SIMD3<Float>.zero) { sum, neighborIndex in
                sum + vertices[neighborIndex]
            }
            let neighborAverage = neighborSum / Float(filteredNeighbors.count)
            let laplacian = neighborAverage - vertex

            // Apply scaled Laplacian
            return vertex + laplacian * factor
        }
    }

    /// Detect feature edges (sharp edges to preserve)
    private func detectFeatureEdges(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        adjacency: [[Int]]
    ) -> Set<UnorderedPair> {
        let featureAngleThreshold: Float = cos(30.0 * .pi / 180.0)  // 30 degrees
        var featureEdges = Set<UnorderedPair>()

        for (i, neighbors) in adjacency.enumerated() {
            let normal_i = normals[i]

            for j in neighbors {
                let normal_j = normals[j]
                let dotProduct = dot(normal_i, normal_j)

                // If normals differ significantly, it's a feature edge
                if dotProduct < featureAngleThreshold {
                    featureEdges.insert(UnorderedPair(i, j))
                }
            }
        }

        return featureEdges
    }

    /// Recalculate vertex normals from triangle normals
    private func recalculateNormals(vertices: [SIMD3<Float>], triangles: [Int32]) -> [SIMD3<Float>] {
        var normals = Array(repeating: SIMD3<Float>.zero, count: vertices.count)
        var counts = Array(repeating: 0, count: vertices.count)

        // Accumulate triangle normals
        for i in stride(from: 0, to: triangles.count, by: 3) {
            let i0 = Int(triangles[i])
            let i1 = Int(triangles[i + 1])
            let i2 = Int(triangles[i + 2])

            let v0 = vertices[i0]
            let v1 = vertices[i1]
            let v2 = vertices[i2]

            // Triangle normal
            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let triangleNormal = cross(edge1, edge2)

            // Add to vertices
            normals[i0] += triangleNormal
            normals[i1] += triangleNormal
            normals[i2] += triangleNormal
            counts[i0] += 1
            counts[i1] += 1
            counts[i2] += 1
        }

        // Normalize
        return normals.enumerated().map { index, normal in
            let count = counts[index]
            guard count > 0 else { return SIMD3<Float>(0, 0, 1) }
            let averaged = normal / Float(count)
            return normalize(averaged)
        }
    }

    /// Calculate average vertex displacement
    private func calculateAverageDisplacement(from original: [SIMD3<Float>], to smoothed: [SIMD3<Float>]) -> Float {
        let displacements = zip(original, smoothed).map { distance($0.0, $0.1) }
        return displacements.reduce(0, +) / Float(displacements.count)
    }
}

// MARK: - UnorderedPair (for edge representation)

/// Unordered pair of integers (for representing edges)
private struct UnorderedPair: Hashable {
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

    func hash(into hasher: inout Hasher) {
        hasher.combine(a)
        hasher.combine(b)
    }

    static func == (lhs: UnorderedPair, rhs: UnorderedPair) -> Bool {
        return lhs.a == rhs.a && lhs.b == rhs.b
    }
}

// MARK: - FaceMeshGeometry Extension

extension FaceMeshGeometry {
    /// Apply smoothing to mesh
    func smoothed(iterations: Int = 5, preserveFeatures: Bool = true) -> FaceMeshGeometry {
        let smoother = MeshSmoother()
        let result = smoother.smooth(geometry: self, iterations: iterations, preserveFeatures: preserveFeatures)

        return FaceMeshGeometry(
            vertices: result.smoothedVertices,
            normals: result.smoothedNormals,
            textureCoordinates: self.textureCoordinates,
            triangleIndices: self.triangleIndices
        )
    }
}
