//
//  OutlierFilter.swift
//  Tavi
//
//  Remove outlier vertices caused by tracking errors
//  Uses K-nearest neighbor distance analysis and centroid distance filtering
//

import ARKit
import simd

/// Result of outlier filtering
struct FilterResult {
    let cleanedVertices: [SIMD3<Float>]
    let cleanedNormals: [SIMD3<Float>]
    let validIndices: [Int]  // Original indices that were kept
    let outlierCount: Int
    let outlierPercentage: Float
}

/// Outlier vertex detection and removal
class OutlierFilter {

    // MARK: - Configuration

    private let kNeighbors = 8
    private let stdDevThreshold: Float = 2.5
    private let maxCentroidDistance: Float = 0.15  // 15cm from face center
    private let minValidPercentage: Float = 0.90  // Keep at least 90% of vertices

    // MARK: - Public API

    /// Filter outliers from mesh geometry
    func filter(geometry: ARFaceGeometry) -> FilterResult {
        let vertices = Array(geometry.vertices)
        let normals = Array(geometry.normals)

        print("🔍 Filtering outliers from \(vertices.count) vertices...")

        // Step 1: Calculate face centroid
        let centroid = calculateCentroid(vertices)

        // Step 2: Build spatial index for nearest neighbor search
        let spatialIndex = buildSpatialIndex(vertices)

        // Step 3: Calculate outlier scores
        var outlierScores: [Float] = []
        for (index, vertex) in vertices.enumerated() {
            let score = calculateOutlierScore(
                vertex: vertex,
                index: index,
                centroid: centroid,
                spatialIndex: spatialIndex
            )
            outlierScores.append(score)
        }

        // Step 4: Determine threshold
        let (mean, stdDev) = calculateStatistics(outlierScores)
        let threshold = mean + stdDevThreshold * stdDev

        // Step 5: Filter vertices
        var cleanedVertices: [SIMD3<Float>] = []
        var cleanedNormals: [SIMD3<Float>] = []
        var validIndices: [Int] = []
        var outlierCount = 0

        for (index, score) in outlierScores.enumerated() {
            if score <= threshold {
                cleanedVertices.append(vertices[index])
                cleanedNormals.append(normals[index])
                validIndices.append(index)
            } else {
                outlierCount += 1
            }
        }

        let outlierPercentage = Float(outlierCount) / Float(vertices.count)

        // Safety check: if too many outliers, something is wrong
        if outlierPercentage > (1.0 - minValidPercentage) {
            print("⚠️ Too many outliers detected (\(String(format: "%.1f%%", outlierPercentage * 100))), keeping all vertices")
            return FilterResult(
                cleanedVertices: vertices,
                cleanedNormals: normals,
                validIndices: Array(0..<vertices.count),
                outlierCount: 0,
                outlierPercentage: 0
            )
        }

        print("✅ Filtered \(outlierCount) outliers (\(String(format: "%.1f%%", outlierPercentage * 100)))")
        print("   Kept \(cleanedVertices.count) vertices")

        return FilterResult(
            cleanedVertices: cleanedVertices,
            cleanedNormals: cleanedNormals,
            validIndices: validIndices,
            outlierCount: outlierCount,
            outlierPercentage: outlierPercentage
        )
    }

    // MARK: - Private Methods

    /// Calculate mesh centroid
    private func calculateCentroid(_ vertices: [SIMD3<Float>]) -> SIMD3<Float> {
        let sum = vertices.reduce(SIMD3<Float>.zero, +)
        return sum / Float(vertices.count)
    }

    /// Build spatial index (simple grid-based)
    private func buildSpatialIndex(_ vertices: [SIMD3<Float>]) -> SpatialIndex {
        return SpatialIndex(vertices: vertices)
    }

    /// Calculate outlier score for a vertex
    private func calculateOutlierScore(
        vertex: SIMD3<Float>,
        index: Int,
        centroid: SIMD3<Float>,
        spatialIndex: SpatialIndex
    ) -> Float {
        // Score component 1: Distance to centroid
        let centroidDistance = distance(vertex, centroid)
        let centroidScore = min(centroidDistance / maxCentroidDistance, 1.0)

        // Score component 2: Average distance to K nearest neighbors
        let neighbors = spatialIndex.findKNearest(to: vertex, k: kNeighbors + 1, excluding: index)
        let neighborDistances = neighbors.map { distance(vertex, $0) }
        let avgNeighborDistance = neighborDistances.reduce(0, +) / Float(neighborDistances.count)
        let neighborScore = avgNeighborDistance * 10.0  // Scale to reasonable range

        // Combined score
        let combinedScore = centroidScore * 0.3 + neighborScore * 0.7

        return combinedScore
    }

    /// Calculate mean and standard deviation
    private func calculateStatistics(_ values: [Float]) -> (mean: Float, stdDev: Float) {
        let mean = values.reduce(0, +) / Float(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Float(values.count)
        let stdDev = sqrt(variance)
        return (mean, stdDev)
    }
}

// MARK: - Spatial Index

/// Simple spatial index for nearest neighbor search
private class SpatialIndex {
    private let vertices: [SIMD3<Float>]

    init(vertices: [SIMD3<Float>]) {
        self.vertices = vertices
    }

    /// Find K nearest neighbors (brute force for simplicity)
    func findKNearest(to point: SIMD3<Float>, k: Int, excluding excludeIndex: Int) -> [SIMD3<Float>] {
        // Calculate distances to all vertices
        var distanceIndices: [(distance: Float, index: Int)] = []
        for (index, vertex) in vertices.enumerated() {
            if index == excludeIndex { continue }
            let dist = distance(point, vertex)
            distanceIndices.append((dist, index))
        }

        // Sort by distance and take top K
        distanceIndices.sort { $0.distance < $1.distance }
        let kNearest = distanceIndices.prefix(k)

        return kNearest.map { vertices[$0.index] }
    }
}

// MARK: - Geometry Extension

extension ARFaceGeometry {
    /// Create filtered geometry (helper for applying filter results)
    func applyFilter(_ filterResult: FilterResult) -> FaceMeshGeometry {
        // Map valid indices to new triangle indices
        var indexMap: [Int: Int] = [:]
        for (newIndex, oldIndex) in filterResult.validIndices.enumerated() {
            indexMap[oldIndex] = newIndex
        }

        // Filter triangles (keep only if all 3 vertices are valid)
        var newTriangles: [Int16] = []
        let triangleCount = self.triangleCount

        for triIndex in 0..<triangleCount {
            let baseIndex = triIndex * 3
            let i0 = Int(triangleIndices[baseIndex])
            let i1 = Int(triangleIndices[baseIndex + 1])
            let i2 = Int(triangleIndices[baseIndex + 2])

            if let new0 = indexMap[i0],
               let new1 = indexMap[i1],
               let new2 = indexMap[i2] {
                newTriangles.append(Int16(new0))
                newTriangles.append(Int16(new1))
                newTriangles.append(Int16(new2))
            }
        }

        // Filter texture coordinates
        let newTexCoords = filterResult.validIndices.map { textureCoordinates[$0] }

        // Create filtered geometry
        return FaceMeshGeometry(
            vertices: filterResult.cleanedVertices,
            normals: filterResult.cleanedNormals,
            textureCoordinates: newTexCoords,
            triangleIndices: newTriangles
        )
    }
}
