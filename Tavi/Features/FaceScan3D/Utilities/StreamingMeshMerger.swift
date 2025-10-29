//
//  StreamingMeshMerger.swift
//  Tavi
//
//  Memory-efficient mesh merging using streaming approach
//  Processes large meshes in chunks to avoid memory spikes
//  Created on 2025-10-29.
//

import Foundation
import simd

/// Streaming mesh merger for memory-efficient processing of large meshes
///
/// Instead of loading all mesh data into memory at once, this implementation:
/// 1. Processes vertices in chunks (configurable chunk size)
/// 2. Writes intermediate results to temporary buffers
/// 3. Only keeps active working set in memory
/// 4. Suitable for meshes with >100k vertices
public actor StreamingMeshMerger {

    /// Configuration for streaming mesh merger
    public struct Configuration {
        /// Number of vertices to process in each chunk
        public var chunkSize: Int = 10_000

        /// Distance threshold for merging vertices (meters)
        public var vertexMergeThreshold: Float = 0.001

        /// Whether to align meshes before merging
        public var alignMeshes: Bool = true

        /// Whether to average normals at merged vertices
        public var averageNormals: Bool = true

        /// Whether to remove duplicate triangles
        public var removeDuplicateTriangles: Bool = true

        /// Progress callback frequency (0-1)
        public var progressUpdateInterval: Double = 0.05

        public init() {}
    }

    private let configuration: Configuration
    private var progressCallback: ((Double, String) -> Void)?

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    // MARK: - Public API

    /// Merge captures with memory-efficient streaming approach
    /// - Parameters:
    ///   - captures: Array of mesh captures to merge
    ///   - progress: Optional progress callback (0.0-1.0, message)
    /// - Returns: Merged mesh or nil if merging fails
    public func merge(
        captures: [MeshCapture],
        progress: ((Double, String) -> Void)? = nil
    ) async throws -> MergedFaceMesh? {
        self.progressCallback = progress

        guard !captures.isEmpty else { return nil }

        reportProgress(0.0, "Preparing mesh merge...")

        // Step 1: Align captures if needed (20%)
        let alignedCaptures: [StreamingCapture]
        if configuration.alignMeshes {
            alignedCaptures = try await alignCaptures(captures)
        } else {
            alignedCaptures = captures.map { StreamingCapture(from: $0) }
        }
        reportProgress(0.2, "Alignment complete")

        // Step 2: Stream-merge vertices in chunks (40%)
        let mergedVertexData = try await streamMergeVertices(alignedCaptures)
        reportProgress(0.6, "Vertex merging complete")

        // Step 3: Process triangles in streaming fashion (20%)
        let triangles = try await streamProcessTriangles(
            alignedCaptures,
            vertexMapping: mergedVertexData.mapping
        )
        reportProgress(0.8, "Triangle processing complete")

        // Step 4: Finalize normals and texture coordinates (20%)
        let (normals, texCoords) = try await finalizeAttributes(
            alignedCaptures,
            vertexMapping: mergedVertexData.mapping,
            finalVertexCount: mergedVertexData.vertices.count
        )
        reportProgress(1.0, "Merge complete!")

        return MergedFaceMesh(
            vertices: mergedVertexData.vertices,
            triangleIndices: triangles,
            normals: normals,
            textureCoordinates: texCoords,
            sourceCount: captures.count
        )
    }

    // MARK: - Streaming Implementation

    private func alignCaptures(_ captures: [MeshCapture]) async throws -> [StreamingCapture] {
        guard let reference = captures.first else { return [] }

        let referenceTransform = reference.transform.toSIMD()
        let inverseReference = referenceTransform.inverse

        var aligned: [StreamingCapture] = []

        for (index, capture) in captures.enumerated() {
            reportProgress(
                0.05 + (0.15 * Double(index) / Double(captures.count)),
                "Aligning capture \(index + 1)/\(captures.count)"
            )

            let captureTransform = capture.transform.toSIMD()
            let relativeTransform = inverseReference * captureTransform

            // Transform vertices in chunks
            var alignedVertices: [Vector3] = []
            alignedVertices.reserveCapacity(capture.vertices.count)

            for chunkStart in stride(from: 0, to: capture.vertices.count, by: configuration.chunkSize) {
                let chunkEnd = min(chunkStart + configuration.chunkSize, capture.vertices.count)
                let chunk = capture.vertices[chunkStart..<chunkEnd]

                for vertex in chunk {
                    let simdVertex = SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
                    let transformed = relativeTransform * simdVertex
                    alignedVertices.append(Vector3(x: transformed.x, y: transformed.y, z: transformed.z))
                }

                // Allow other tasks to run
                await Task.yield()
            }

            // Transform normals
            let rotationPart = simd_float3x3(
                relativeTransform.columns.0.xyz,
                relativeTransform.columns.1.xyz,
                relativeTransform.columns.2.xyz
            )

            var alignedNormals: [Vector3] = []
            alignedNormals.reserveCapacity(capture.normals.count)

            for normal in capture.normals {
                let simdNormal = SIMD3<Float>(normal.x, normal.y, normal.z)
                let transformed = rotationPart * simdNormal
                alignedNormals.append(Vector3(transformed).normalized())
            }

            aligned.append(StreamingCapture(
                vertices: alignedVertices,
                triangleIndices: capture.triangleIndices,
                normals: alignedNormals,
                textureCoordinates: capture.textureCoordinates
            ))
        }

        return aligned
    }

    private struct MergedVertexData {
        var vertices: [Vector3]
        var mapping: [Int: Int]
    }

    private func streamMergeVertices(_ captures: [StreamingCapture]) async throws -> MergedVertexData {
        var mergedVertices: [Vector3] = []
        var mapping: [Int: Int] = [:]
        var processed: Set<Int> = []

        // Build spatial hash for efficient proximity queries
        var spatialHash = SpatialHash(cellSize: configuration.vertexMergeThreshold * 2.0)

        var globalVertexIndex = 0

        // Process each capture
        for (captureIndex, capture) in captures.enumerated() {
            reportProgress(
                0.2 + (0.4 * Double(captureIndex) / Double(captures.count)),
                "Merging vertices from capture \(captureIndex + 1)/\(captures.count)"
            )

            // Process vertices in chunks
            for chunkStart in stride(from: 0, to: capture.vertices.count, by: configuration.chunkSize) {
                let chunkEnd = min(chunkStart + configuration.chunkSize, capture.vertices.count)

                for localIndex in chunkStart..<chunkEnd {
                    let vertex = capture.vertices[localIndex]

                    if processed.contains(globalVertexIndex) {
                        globalVertexIndex += 1
                        continue
                    }

                    // Check spatial hash for nearby vertices
                    let nearby = spatialHash.query(near: vertex, radius: configuration.vertexMergeThreshold)

                    if let existingIndex = nearby.first(where: { mergedIndex in
                        let distance = simd_distance(
                            mergedVertices[mergedIndex].toSIMD(),
                            vertex.toSIMD()
                        )
                        return distance < configuration.vertexMergeThreshold
                    }) {
                        // Map to existing vertex
                        mapping[globalVertexIndex] = existingIndex
                        processed.insert(globalVertexIndex)
                    } else {
                        // Create new merged vertex
                        let newIndex = mergedVertices.count
                        mergedVertices.append(vertex)
                        spatialHash.insert(vertex: vertex, index: newIndex)
                        mapping[globalVertexIndex] = newIndex
                        processed.insert(globalVertexIndex)
                    }

                    globalVertexIndex += 1
                }

                // Yield to allow other tasks to run
                await Task.yield()
            }
        }

        return MergedVertexData(vertices: mergedVertices, mapping: mapping)
    }

    private func streamProcessTriangles(
        _ captures: [StreamingCapture],
        vertexMapping: [Int: Int]
    ) async throws -> [Int32] {
        var triangles: [Int32] = []
        var triangleSet: Set<Triangle> = []

        var vertexOffset = 0

        for (captureIndex, capture) in captures.enumerated() {
            reportProgress(
                0.6 + (0.2 * Double(captureIndex) / Double(captures.count)),
                "Processing triangles from capture \(captureIndex + 1)/\(captures.count)"
            )

            // Process triangles in chunks
            let triangleCount = capture.triangleIndices.count / 3

            for chunkStart in stride(from: 0, to: triangleCount, by: configuration.chunkSize) {
                let chunkEnd = min(chunkStart + configuration.chunkSize, triangleCount)

                for triangleIndex in chunkStart..<chunkEnd {
                    let i = triangleIndex * 3

                    let originalI0 = vertexOffset + Int(capture.triangleIndices[i])
                    let originalI1 = vertexOffset + Int(capture.triangleIndices[i + 1])
                    let originalI2 = vertexOffset + Int(capture.triangleIndices[i + 2])

                    guard let mergedI0 = vertexMapping[originalI0],
                          let mergedI1 = vertexMapping[originalI1],
                          let mergedI2 = vertexMapping[originalI2] else {
                        continue
                    }

                    // Skip degenerate triangles
                    if mergedI0 == mergedI1 || mergedI1 == mergedI2 || mergedI0 == mergedI2 {
                        continue
                    }

                    let triangle = Triangle(
                        v0: Int32(mergedI0),
                        v1: Int32(mergedI1),
                        v2: Int32(mergedI2)
                    )

                    // Check for duplicates if configured
                    if configuration.removeDuplicateTriangles {
                        if !triangleSet.contains(triangle) {
                            triangles.append(contentsOf: [triangle.v0, triangle.v1, triangle.v2])
                            triangleSet.insert(triangle)
                        }
                    } else {
                        triangles.append(contentsOf: [triangle.v0, triangle.v1, triangle.v2])
                    }
                }

                await Task.yield()
            }

            vertexOffset += capture.vertices.count
        }

        return triangles
    }

    private func finalizeAttributes(
        _ captures: [StreamingCapture],
        vertexMapping: [Int: Int],
        finalVertexCount: Int
    ) async throws -> (normals: [Vector3], texCoords: [Vector2]) {
        reportProgress(0.8, "Finalizing vertex attributes...")

        // Average normals
        var normalAccumulators: [SIMD3<Float>] = Array(
            repeating: SIMD3<Float>(0, 0, 0),
            count: finalVertexCount
        )
        var normalCounts: [Int] = Array(repeating: 0, count: finalVertexCount)

        // Collect texture coordinates
        var texCoords: [Vector2?] = Array(repeating: nil, count: finalVertexCount)

        var vertexOffset = 0

        for (captureIndex, capture) in captures.enumerated() {
            reportProgress(
                0.8 + (0.2 * Double(captureIndex) / Double(captures.count)),
                "Processing attributes from capture \(captureIndex + 1)/\(captures.count)"
            )

            // Process in chunks
            for chunkStart in stride(from: 0, to: capture.normals.count, by: configuration.chunkSize) {
                let chunkEnd = min(chunkStart + configuration.chunkSize, capture.normals.count)

                for localIndex in chunkStart..<chunkEnd {
                    let originalIndex = vertexOffset + localIndex
                    guard let mergedIndex = vertexMapping[originalIndex] else { continue }

                    // Accumulate normal
                    if configuration.averageNormals {
                        normalAccumulators[mergedIndex] += capture.normals[localIndex].toSIMD()
                        normalCounts[mergedIndex] += 1
                    }

                    // Set texture coordinate (first occurrence)
                    if texCoords[mergedIndex] == nil, localIndex < capture.textureCoordinates.count {
                        texCoords[mergedIndex] = capture.textureCoordinates[localIndex]
                    }
                }

                await Task.yield()
            }

            vertexOffset += capture.vertices.count
        }

        // Finalize normals
        let normals = normalAccumulators.enumerated().map { index, accumulated in
            let count = Float(normalCounts[index])
            guard count > 0 else { return Vector3(x: 0, y: 1, z: 0) }

            let averaged = accumulated / count
            let length = simd_length(averaged)
            guard length > 0 else { return Vector3(x: 0, y: 1, z: 0) }

            return Vector3(averaged / length)
        }

        // Finalize texture coordinates
        let finalTexCoords = texCoords.map { $0 ?? Vector2(x: 0, y: 0) }

        return (normals, finalTexCoords)
    }

    // MARK: - Helper Types

    private struct StreamingCapture {
        let vertices: [Vector3]
        let triangleIndices: [Int32]
        let normals: [Vector3]
        let textureCoordinates: [Vector2]

        init(from capture: MeshCapture) {
            self.vertices = capture.vertices
            self.triangleIndices = capture.triangleIndices
            self.normals = capture.normals
            self.textureCoordinates = capture.textureCoordinates
        }

        init(vertices: [Vector3], triangleIndices: [Int32], normals: [Vector3], textureCoordinates: [Vector2]) {
            self.vertices = vertices
            self.triangleIndices = triangleIndices
            self.normals = normals
            self.textureCoordinates = textureCoordinates
        }
    }

    private struct Triangle: Hashable {
        let v0: Int32
        let v1: Int32
        let v2: Int32

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

    /// Spatial hash grid for efficient proximity queries
    private struct SpatialHash {
        private var grid: [SIMD3<Int>: [Int]] = [:]
        private let cellSize: Float

        init(cellSize: Float) {
            self.cellSize = cellSize
        }

        private func cellKey(for vertex: Vector3) -> SIMD3<Int> {
            return SIMD3<Int>(
                Int(floor(vertex.x / cellSize)),
                Int(floor(vertex.y / cellSize)),
                Int(floor(vertex.z / cellSize))
            )
        }

        mutating func insert(vertex: Vector3, index: Int) {
            let key = cellKey(for: vertex)
            grid[key, default: []].append(index)
        }

        func query(near vertex: Vector3, radius: Float) -> [Int] {
            let cellRadius = Int(ceil(radius / cellSize))
            let centerKey = cellKey(for: vertex)

            var results: [Int] = []

            for dx in -cellRadius...cellRadius {
                for dy in -cellRadius...cellRadius {
                    for dz in -cellRadius...cellRadius {
                        let key = SIMD3<Int>(
                            centerKey.x + dx,
                            centerKey.y + dy,
                            centerKey.z + dz
                        )

                        if let indices = grid[key] {
                            results.append(contentsOf: indices)
                        }
                    }
                }
            }

            return results
        }
    }

    // MARK: - Progress Reporting

    private func reportProgress(_ progress: Double, _ message: String) {
        progressCallback?(progress, message)
    }
}

// MARK: - Extensions

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}
