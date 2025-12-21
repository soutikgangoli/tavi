//
//  MeshMerger.swift
//  Tavi
//
//  Mesh merging and stitching algorithm for multi-angle captures
//  Created on 2025-10-27.
//

import Foundation
import simd

/// Merges multiple mesh captures into a single unified mesh
public class MeshMerger {

    /// Configuration for mesh merging
    public struct Configuration {
        /// Distance threshold for considering vertices as the same (in meters)
        public var vertexMergeThreshold: Float = 0.001

        /// Whether to align meshes using transforms
        public var alignMeshes: Bool = true

        /// Whether to average normals at merged vertices
        public var averageNormals: Bool = true

        /// Whether to remove duplicate triangles
        public var removeDuplicateTriangles: Bool = true

        public init() {}
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Merge multiple mesh captures into one unified mesh
    public func merge(captures: [MeshCapture]) -> MergedFaceMesh? {
        guard !captures.isEmpty else { return nil }

        // Step 1: Transform all vertices to world space if needed
        if configuration.alignMeshes {
            let aligned = alignCaptures(captures)
            return mergeInternal(captures: aligned, sourceCount: captures.count)
        } else {
            return mergeInternal(captures: captures, sourceCount: captures.count)
        }
    }

    private func mergeInternal<T: CaptureData>(captures: [T], sourceCount: Int) -> MergedFaceMesh {
        // Step 2: Collect all unique vertices and build mapping
        let vertexMap = buildVertexMap(from: captures)

        // Step 3: Merge vertices within threshold distance
        let mergedVertices = mergeVertices(vertexMap)

        // Step 4: Collect and deduplicate triangles
        let triangles = collectTriangles(
            from: captures,
            vertexMapping: mergedVertices.mapping
        )

        // Step 5: Average normals at merged vertices
        let normals = configuration.averageNormals
            ? averageNormals(
                captures: captures,
                vertexMapping: mergedVertices.mapping,
                finalVertexCount: mergedVertices.vertices.count
            )
            : collectNormals(from: captures)

        // Step 6: Collect texture coordinates
        let texCoords = collectTextureCoordinates(
            from: captures,
            vertexMapping: mergedVertices.mapping
        )

        let mesh = MergedFaceMesh(
            vertices: mergedVertices.vertices,
            triangleIndices: triangles,
            normals: normals,
            textureCoordinates: texCoords,
            sourceCount: sourceCount
        )

        // DIAGNOSTIC: Log mesh topology stats
        let vertexCount = mesh.vertices.count
        let triangleCount = triangles.count / 3
        let edgeCount = countUniqueEdges(triangles: triangles)
        let eulerCharacteristic = vertexCount - edgeCount + triangleCount

        AppLogger.mesh.info("📐 Merged mesh topology:")
        AppLogger.mesh.info("   Vertices: \(vertexCount)")
        AppLogger.mesh.info("   Triangles: \(triangleCount)")
        AppLogger.mesh.info("   Edges: \(edgeCount)")
        AppLogger.mesh.info("   Euler characteristic: \(eulerCharacteristic) (expected ~2 for closed surface)")

        if eulerCharacteristic != 2 {
            AppLogger.mesh.warning("⚠️ Euler characteristic ≠ 2 indicates mesh is not a closed surface")
            AppLogger.mesh.warning("   This is normal for face meshes which have boundary edges")
        }

        return mesh
    }

    /// Count unique edges in triangle mesh
    private func countUniqueEdges(triangles: [Int32]) -> Int {
        var edges: Set<UInt64> = []
        for i in stride(from: 0, to: triangles.count, by: 3) {
            let v0 = triangles[i]
            let v1 = triangles[i + 1]
            let v2 = triangles[i + 2]
            edges.insert(edgeKey(v0, v1))
            edges.insert(edgeKey(v1, v2))
            edges.insert(edgeKey(v2, v0))
        }
        return edges.count
    }

    // MARK: - Private Methods

    private func alignCaptures(_ captures: [MeshCapture]) -> [AlignedCapture] {
        // Use first capture as reference
        guard let reference = captures.first else { return [] }

        // For simplicity, we'll transform all to the reference frame
        // In a production system, you'd compute optimal alignment
        let referenceTransform = reference.transform.toSIMD()
        let inverseReference = referenceTransform.inverse

        return captures.map { capture in
            // Transform vertices to reference space
            let captureTransform = capture.transform.toSIMD()
            let relativeTransform = inverseReference * captureTransform

            let alignedVertices = capture.vertices.map { vertex in
                let simdVertex = SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
                let transformed = relativeTransform * simdVertex
                return Vector3(x: transformed.x, y: transformed.y, z: transformed.z)
            }

            // Transform normals (only rotation part)
            let rotationPart = simd_float3x3(
                relativeTransform.columns.0.xyz,
                relativeTransform.columns.1.xyz,
                relativeTransform.columns.2.xyz
            )

            let alignedNormals = capture.normals.map { normal in
                let simdNormal = SIMD3<Float>(normal.x, normal.y, normal.z)
                let transformed = rotationPart * simdNormal
                return Vector3(transformed).normalized()
            }

            return AlignedCapture(
                vertices: alignedVertices,
                triangleIndices: capture.triangleIndices,
                normals: alignedNormals,
                textureCoordinates: capture.textureCoordinates
            )
        }
    }

    // Helper struct for aligned captures
    fileprivate struct AlignedCapture {
        let vertices: [Vector3]
        let triangleIndices: [Int32]
        let normals: [Vector3]
        let textureCoordinates: [Vector2]
    }

    private struct VertexMap {
        var vertices: [Vector3]
        var sources: [[Int]] // Which capture and vertex index
    }

    private func buildVertexMap<T: CaptureData>(from captures: [T]) -> VertexMap {
        var map = VertexMap(vertices: [], sources: [])

        for (captureIndex, capture) in captures.enumerated() {
            for (vertexIndex, vertex) in capture.vertices.enumerated() {
                map.vertices.append(vertex)
                map.sources.append([captureIndex, vertexIndex])
            }
        }

        return map
    }

    private struct MergedVertices {
        var vertices: [Vector3]
        var mapping: [Int: Int] // Original index -> Merged index
    }

    private func mergeVertices(_ vertexMap: VertexMap) -> MergedVertices {
        var mergedVertices: [Vector3] = []
        var mapping: [Int: Int] = [:]
        var processed: Set<Int> = []

        for (index, vertex) in vertexMap.vertices.enumerated() {
            if processed.contains(index) {
                continue
            }

            // Find all vertices within threshold
            var cluster: [Int] = [index]

            for (otherIndex, otherVertex) in vertexMap.vertices.enumerated() {
                if otherIndex == index || processed.contains(otherIndex) {
                    continue
                }

                let distance = simd_distance(vertex.toSIMD(), otherVertex.toSIMD())
                if distance < configuration.vertexMergeThreshold {
                    cluster.append(otherIndex)
                }
            }

            // Average cluster vertices
            var avgX: Float = 0
            var avgY: Float = 0
            var avgZ: Float = 0

            for clusterIndex in cluster {
                let v = vertexMap.vertices[clusterIndex]
                avgX += v.x
                avgY += v.y
                avgZ += v.z
            }

            let count = Float(cluster.count)
            let mergedVertex = Vector3(
                x: avgX / count,
                y: avgY / count,
                z: avgZ / count
            )

            let mergedIndex = mergedVertices.count
            mergedVertices.append(mergedVertex)

            // Map all cluster members to this merged vertex
            for clusterIndex in cluster {
                mapping[clusterIndex] = mergedIndex
                processed.insert(clusterIndex)
            }
        }

        return MergedVertices(vertices: mergedVertices, mapping: mapping)
    }

    /// Create a canonical edge key from two vertex indices (order-independent)
    private func edgeKey(_ v1: Int32, _ v2: Int32) -> UInt64 {
        let minV = min(v1, v2)
        let maxV = max(v1, v2)
        return UInt64(minV) << 32 | UInt64(maxV)
    }

    private func collectTriangles<T: CaptureData>(
        from captures: [T],
        vertexMapping: [Int: Int]
    ) -> [Int32] {
        var triangles: [Int32] = []
        var triangleSet: Set<Triangle> = []

        // FIXED: Track edge usage to prevent non-manifold edges
        // Non-manifold edges are shared by more than 2 triangles, causing mesh issues
        var edgeUsage: [UInt64: Int] = [:]
        var skippedNonManifold = 0

        var vertexOffset = 0

        for capture in captures {
            for i in stride(from: 0, to: capture.triangleIndices.count, by: 3) {
                let originalI0 = vertexOffset + Int(capture.triangleIndices[i])
                let originalI1 = vertexOffset + Int(capture.triangleIndices[i + 1])
                let originalI2 = vertexOffset + Int(capture.triangleIndices[i + 2])

                guard let mergedI0 = vertexMapping[originalI0],
                      let mergedI1 = vertexMapping[originalI1],
                      let mergedI2 = vertexMapping[originalI2] else {
                    continue
                }

                // Check for degenerate triangle
                if mergedI0 == mergedI1 || mergedI1 == mergedI2 || mergedI0 == mergedI2 {
                    continue
                }

                let triangle = Triangle(
                    v0: Int32(mergedI0),
                    v1: Int32(mergedI1),
                    v2: Int32(mergedI2)
                )

                // Check for non-manifold edges before adding triangle
                // An edge shared by more than 2 triangles creates non-manifold geometry
                let edge1 = edgeKey(triangle.v0, triangle.v1)
                let edge2 = edgeKey(triangle.v1, triangle.v2)
                let edge3 = edgeKey(triangle.v2, triangle.v0)

                let wouldCreateNonManifold = (edgeUsage[edge1, default: 0] >= 2) ||
                                             (edgeUsage[edge2, default: 0] >= 2) ||
                                             (edgeUsage[edge3, default: 0] >= 2)

                if wouldCreateNonManifold {
                    skippedNonManifold += 1
                    continue  // Skip this triangle to maintain manifold property
                }

                // Remove duplicates if configured
                if configuration.removeDuplicateTriangles {
                    if !triangleSet.contains(triangle) {
                        triangles.append(triangle.v0)
                        triangles.append(triangle.v1)
                        triangles.append(triangle.v2)
                        triangleSet.insert(triangle)

                        // Update edge usage counts
                        edgeUsage[edge1, default: 0] += 1
                        edgeUsage[edge2, default: 0] += 1
                        edgeUsage[edge3, default: 0] += 1
                    }
                } else {
                    triangles.append(triangle.v0)
                    triangles.append(triangle.v1)
                    triangles.append(triangle.v2)

                    // Update edge usage counts
                    edgeUsage[edge1, default: 0] += 1
                    edgeUsage[edge2, default: 0] += 1
                    edgeUsage[edge3, default: 0] += 1
                }
            }

            vertexOffset += capture.vertices.count
        }

        if skippedNonManifold > 0 {
            AppLogger.mesh.info("   ⚠️ Skipped \(skippedNonManifold) triangles to prevent non-manifold edges")
        }

        return triangles
    }

    private func averageNormals<T: CaptureData>(
        captures: [T],
        vertexMapping: [Int: Int],
        finalVertexCount: Int
    ) -> [Vector3] {
        // Accumulate normals for each merged vertex
        var normalAccumulators: [SIMD3<Float>] = Array(
            repeating: SIMD3<Float>(0, 0, 0),
            count: finalVertexCount
        )
        var normalCounts: [Int] = Array(repeating: 0, count: finalVertexCount)

        var vertexOffset = 0

        for capture in captures {
            for (vertexIndex, normal) in capture.normals.enumerated() {
                let originalIndex = vertexOffset + vertexIndex
                guard let mergedIndex = vertexMapping[originalIndex] else { continue }

                normalAccumulators[mergedIndex] += normal.toSIMD()
                normalCounts[mergedIndex] += 1
            }

            vertexOffset += capture.vertices.count
        }

        // Average and normalize
        return normalAccumulators.enumerated().map { index, accumulated in
            let count = Float(normalCounts[index])
            guard count > 0 else {
                return Vector3(x: 0, y: 1, z: 0) // Default up
            }

            let averaged = accumulated / count
            let length = simd_length(averaged)
            guard length > 0 else {
                return Vector3(x: 0, y: 1, z: 0)
            }

            return Vector3(averaged / length)
        }
    }

    private func collectNormals<T: CaptureData>(from captures: [T]) -> [Vector3] {
        return captures.flatMap { $0.normals }
    }

    private func collectTextureCoordinates<T: CaptureData>(
        from captures: [T],
        vertexMapping: [Int: Int]
    ) -> [Vector2] {
        // Use first occurrence of each merged vertex's texture coordinate
        var texCoords: [Vector2?] = Array(
            repeating: nil,
            count: vertexMapping.values.max().map { $0 + 1 } ?? 0
        )

        var vertexOffset = 0

        for capture in captures {
            for (vertexIndex, texCoord) in capture.textureCoordinates.enumerated() {
                let originalIndex = vertexOffset + vertexIndex
                guard let mergedIndex = vertexMapping[originalIndex] else { continue }

                if texCoords[mergedIndex] == nil {
                    texCoords[mergedIndex] = texCoord
                }
            }

            vertexOffset += capture.vertices.count
        }

        // Fill any missing with default
        return texCoords.map { $0 ?? Vector2(x: 0, y: 0) }
    }

    // MARK: - Helper Types

    private struct Triangle: Hashable {
        let v0: Int32
        let v1: Int32
        let v2: Int32

        // Normalize triangle (sort vertices) for duplicate detection
        func hash(into hasher: inout Hasher) {
            let sorted = [v0, v1, v2].sorted()
            hasher.combine(sorted[0])
            hasher.combine(sorted[1])
            hasher.combine(sorted[2])
        }

        static func == (lhs: Triangle, rhs: Triangle) -> Bool {
            let lhsSorted = [lhs.v0, lhs.v1, lhs.v2].sorted()
            let rhsSorted = [rhs.v0, rhs.v1, rhs.v2].sorted()
            return lhsSorted == rhsSorted
        }
    }
}

// MARK: - Protocols

/// Protocol to unify MeshCapture and AlignedCapture for generic merging
fileprivate protocol CaptureData {
    var vertices: [Vector3] { get }
    var triangleIndices: [Int32] { get }
    var normals: [Vector3] { get }
    var textureCoordinates: [Vector2] { get }
}

extension MeshCapture: CaptureData {}
extension MeshMerger.AlignedCapture: CaptureData {}

// MARK: - Extensions

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}
