//
//  MeshExtender.swift
//  Tavi
//
//  Extends face mesh beyond ARKit boundaries to cover entire face
//  Preserves original mesh quality - only adds vertices at periphery
//  Created on 2025-10-28.
//

import Foundation
import simd

/// Extends face mesh around entire boundary to ensure complete face coverage
/// Works for all face sizes - extends forehead, cheeks, sides, and chin
public class MeshExtender {

    /// Configuration for mesh extension
    public struct Configuration {
        /// How far to extend the mesh (as fraction of face height)
        public var extensionAmount: Float = 0.20 // 20% extension around entire boundary

        /// Number of vertex rows to add
        public var extensionRows: Int = 2

        public init() {}
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Extend mesh around entire boundary to ensure complete face coverage
    /// - Returns: Extended mesh with original vertices preserved
    public func extend(
        vertices: [SIMD3<Float>],
        triangleIndices: [Int32],
        normals: [SIMD3<Float>],
        textureCoordinates: [SIMD2<Float>]
    ) -> ExtendedMesh {

        // Find mesh bounds for extension calculations
        let bounds = calculateBounds(vertices: vertices)

        // Find ALL boundary edges (edges that belong to only one triangle)
        // This extends the entire face boundary, not just forehead
        let boundaryEdges = findBoundaryEdges(
            triangleIndices: triangleIndices,
            vertices: vertices
        )

        guard !boundaryEdges.isEmpty else {
            // No boundary found - return original mesh
            return ExtendedMesh(
                vertices: vertices,
                triangleIndices: triangleIndices,
                normals: normals,
                textureCoordinates: textureCoordinates,
                originalVertexCount: vertices.count
            )
        }

        // Create extended vertices by extruding boundary outward
        let extension = createExtension(
            boundaryEdges: boundaryEdges,
            originalVertices: vertices,
            originalNormals: normals,
            originalTexCoords: textureCoordinates,
            bounds: bounds
        )

        // Combine original and new geometry
        var extendedVertices = vertices
        var extendedNormals = normals
        var extendedTexCoords = textureCoordinates
        var extendedTriangles = triangleIndices

        extendedVertices.append(contentsOf: extension.newVertices)
        extendedNormals.append(contentsOf: extension.newNormals)
        extendedTexCoords.append(contentsOf: extension.newTexCoords)
        extendedTriangles.append(contentsOf: extension.newTriangles)

        return ExtendedMesh(
            vertices: extendedVertices,
            triangleIndices: extendedTriangles,
            normals: extendedNormals,
            textureCoordinates: extendedTexCoords,
            originalVertexCount: vertices.count
        )
    }

    // MARK: - Private Methods

    private struct Bounds {
        let min: SIMD3<Float>
        let max: SIMD3<Float>
    }

    private func calculateBounds(vertices: [SIMD3<Float>]) -> Bounds {
        guard !vertices.isEmpty else {
            return Bounds(min: SIMD3<Float>(0, 0, 0), max: SIMD3<Float>(0, 0, 0))
        }

        var minVec = vertices[0]
        var maxVec = vertices[0]

        for vertex in vertices {
            minVec = simd_min(minVec, vertex)
            maxVec = simd_max(maxVec, vertex)
        }

        return Bounds(min: minVec, max: maxVec)
    }

    private struct Edge: Hashable {
        let v0: Int32
        let v1: Int32

        init(_ v0: Int32, _ v1: Int32) {
            // Normalize edge (smaller index first) for consistent hashing
            if v0 < v1 {
                self.v0 = v0
                self.v1 = v1
            } else {
                self.v0 = v1
                self.v1 = v0
            }
        }
    }

    private struct BoundaryEdge {
        let v0: Int32
        let v1: Int32
        let midpoint: SIMD3<Float>
    }

    private func findBoundaryEdges(
        triangleIndices: [Int32],
        vertices: [SIMD3<Float>]
    ) -> [BoundaryEdge] {

        // Count how many times each edge appears
        var edgeCounts: [Edge: Int] = [:]

        for i in stride(from: 0, to: triangleIndices.count, by: 3) {
            let i0 = triangleIndices[i]
            let i1 = triangleIndices[i + 1]
            let i2 = triangleIndices[i + 2]

            // Add all three edges of this triangle
            edgeCounts[Edge(i0, i1), default: 0] += 1
            edgeCounts[Edge(i1, i2), default: 0] += 1
            edgeCounts[Edge(i2, i0), default: 0] += 1
        }

        // Boundary edges appear only once (not shared between triangles)
        // Include ALL boundary edges to extend entire face perimeter
        var boundaryEdges: [BoundaryEdge] = []

        for (edge, count) in edgeCounts where count == 1 {
            let v0 = vertices[Int(edge.v0)]
            let v1 = vertices[Int(edge.v1)]
            let midpoint = (v0 + v1) / 2.0

            boundaryEdges.append(BoundaryEdge(
                v0: edge.v0,
                v1: edge.v1,
                midpoint: midpoint
            ))
        }

        return boundaryEdges
    }

    private struct Extension {
        let newVertices: [SIMD3<Float>]
        let newNormals: [SIMD3<Float>]
        let newTexCoords: [SIMD2<Float>]
        let newTriangles: [Int32]
    }

    private func createExtension(
        boundaryEdges: [BoundaryEdge],
        originalVertices: [SIMD3<Float>],
        originalNormals: [SIMD3<Float>],
        originalTexCoords: [SIMD2<Float>],
        bounds: Bounds
    ) -> Extension {

        let faceHeight = bounds.max.y - bounds.min.y
        let extensionDistance = faceHeight * configuration.extensionAmount / Float(configuration.extensionRows)

        var newVertices: [SIMD3<Float>] = []
        var newNormals: [SIMD3<Float>] = []
        var newTexCoords: [SIMD2<Float>] = []
        var newTriangles: [Int32] = []

        let originalCount = Int32(originalVertices.count)

        // For each boundary edge, create extension rows
        for boundaryEdge in boundaryEdges {
            let v0Idx = Int(boundaryEdge.v0)
            let v1Idx = Int(boundaryEdge.v1)

            let v0 = originalVertices[v0Idx]
            let v1 = originalVertices[v1Idx]

            let n0 = originalNormals[v0Idx]
            let n1 = originalNormals[v1Idx]

            let uv0 = originalTexCoords[v0Idx]
            let uv1 = originalTexCoords[v1Idx]

            // Calculate extrusion direction
            let avgNormal = normalize(n0 + n1)

            // Extrude along surface normal (outward from face)
            // This works for all boundaries: forehead, sides, chin
            let extrusionDir = avgNormal

            var prevRow0 = boundaryEdge.v0
            var prevRow1 = boundaryEdge.v1

            // Create extension rows
            for row in 1...configuration.extensionRows {
                let t = Float(row) * extensionDistance

                // Create new vertices for this row
                let newV0 = v0 + extrusionDir * t
                let newV1 = v1 + extrusionDir * t

                let newN0 = normalize(n0) // Keep normals similar to boundary
                let newN1 = normalize(n1)

                // Extrapolate UVs outward
                let uvOffset = SIMD2<Float>(0, 0.05 * Float(row)) // Extend UV space slightly
                let newUV0 = uv0 + uvOffset
                let newUV1 = uv1 + uvOffset

                let idx0 = originalCount + Int32(newVertices.count)
                newVertices.append(newV0)
                newNormals.append(newN0)
                newTexCoords.append(newUV0)

                let idx1 = originalCount + Int32(newVertices.count)
                newVertices.append(newV1)
                newNormals.append(newN1)
                newTexCoords.append(newUV1)

                // Create quad (2 triangles) connecting previous row to current row
                // Triangle 1: prevRow0, prevRow1, idx0
                newTriangles.append(prevRow0)
                newTriangles.append(prevRow1)
                newTriangles.append(idx0)

                // Triangle 2: prevRow1, idx1, idx0
                newTriangles.append(prevRow1)
                newTriangles.append(idx1)
                newTriangles.append(idx0)

                prevRow0 = idx0
                prevRow1 = idx1
            }
        }

        return Extension(
            newVertices: newVertices,
            newNormals: newNormals,
            newTexCoords: newTexCoords,
            newTriangles: newTriangles
        )
    }
}

// MARK: - Extended Mesh Result

/// Result of mesh extension with metadata
public struct ExtendedMesh {
    /// All vertices (original + extended)
    public let vertices: [SIMD3<Float>]

    /// All triangle indices
    public let triangleIndices: [Int32]

    /// All normals
    public let normals: [SIMD3<Float>]

    /// All texture coordinates
    public let textureCoordinates: [SIMD2<Float>]

    /// Number of original vertices (before extension)
    /// This is useful for preserving quality - metrics should only use 0..<originalVertexCount
    public let originalVertexCount: Int

    /// Number of added vertices
    public var addedVertexCount: Int {
        return vertices.count - originalVertexCount
    }

    /// Whether this mesh was extended
    public var wasExtended: Bool {
        return addedVertexCount > 0
    }
}
