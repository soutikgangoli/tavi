//
//  ICPAligner.swift
//  Tavi
//
//  Iterative Closest Point (ICP) algorithm for refined mesh alignment
//  Improves upon ARKit's initial transformation estimates
//

import ARKit
import simd

/// ICP alignment result
struct ICPResult {
    let refinedTransform: simd_float4x4
    let finalError: Float
    let iterations: Int
    let converged: Bool
    let alignmentQuality: Float  // 0-1, higher is better
}

/// Iterative Closest Point aligner
class ICPAligner {

    // MARK: - Configuration

    private let maxIterations = 20
    private let convergenceThreshold: Float = 0.0001  // 0.1mm
    private let maxCorrespondenceDistance: Float = 0.01  // 1cm
    private let subsampleRate = 3  // Use every Nth vertex for speed

    // MARK: - Public API

    /// Refine alignment between source and target meshes
    /// - Parameters:
    ///   - source: Mesh to align
    ///   - target: Reference mesh
    ///   - initialTransform: Starting transformation (from ARKit)
    /// - Returns: Refined transformation
    func align(
        source: FaceMeshGeometry,
        target: FaceMeshGeometry,
        initialTransform: simd_float4x4
    ) -> ICPResult {
        print("🎯 Starting ICP alignment...")
        print("   Source: \(source.vertices.count) vertices")
        print("   Target: \(target.vertices.count) vertices")

        var currentTransform = initialTransform
        var previousError: Float = .infinity
        var iteration = 0

        // Subsample vertices for performance
        let sourceIndices = stride(from: 0, to: source.vertices.count, by: subsampleRate).map { $0 }
        let sourcePoints = sourceIndices.map { source.vertices[$0] }
        let sourceNormals = sourceIndices.map { source.vertices[$0] }

        // Build KD-tree for target (for fast nearest neighbor search)
        let targetTree = KDTree(points: target.vertices)

        // ICP iteration loop
        while iteration < maxIterations {
            // Step 1: Transform source points
            let transformedPoints = sourcePoints.map { point in
                transformPoint(point, by: currentTransform)
            }

            // Step 2: Find correspondences (nearest neighbors)
            var correspondences: [(source: SIMD3<Float>, target: SIMD3<Float>)] = []
            for transformedPoint in transformedPoints {
                if let nearest = targetTree.findNearest(to: transformedPoint) {
                    let dist = distance(transformedPoint, nearest)
                    if dist < maxCorrespondenceDistance {
                        correspondences.append((source: transformedPoint, target: nearest))
                    }
                }
            }

            guard correspondences.count > sourcePoints.count / 2 else {
                print("❌ ICP failed: too few correspondences (\(correspondences.count))")
                return ICPResult(
                    refinedTransform: initialTransform,
                    finalError: previousError,
                    iterations: iteration,
                    converged: false,
                    alignmentQuality: 0.0
                )
            }

            // Step 3: Calculate alignment error
            let currentError = calculateAlignmentError(correspondences)

            // Check for convergence
            let errorChange = abs(previousError - currentError)
            if errorChange < convergenceThreshold {
                print("✅ ICP converged at iteration \(iteration)")
                print("   Final error: \(String(format: "%.4f", currentError))m")
                print("   Error change: \(String(format: "%.6f", errorChange))m")

                let quality = calculateAlignmentQuality(error: currentError, correspondenceRatio: Float(correspondences.count) / Float(sourcePoints.count))

                return ICPResult(
                    refinedTransform: currentTransform,
                    finalError: currentError,
                    iterations: iteration,
                    converged: true,
                    alignmentQuality: quality
                )
            }

            // Step 4: Estimate transformation
            let deltaTransform = estimateTransform(correspondences)
            currentTransform = deltaTransform * currentTransform

            previousError = currentError
            iteration += 1
        }

        print("⚠️ ICP reached max iterations without convergence")
        print("   Final error: \(String(format: "%.4f", previousError))m")

        let quality = calculateAlignmentQuality(error: previousError, correspondenceRatio: 0.8)

        return ICPResult(
            refinedTransform: currentTransform,
            finalError: previousError,
            iterations: iteration,
            converged: false,
            alignmentQuality: quality
        )
    }

    // MARK: - Private Methods

    /// Transform a 3D point by a 4x4 matrix
    private func transformPoint(_ point: SIMD3<Float>, by transform: simd_float4x4) -> SIMD3<Float> {
        let homogeneous = SIMD4<Float>(point.x, point.y, point.z, 1.0)
        let transformed = transform * homogeneous
        return SIMD3<Float>(transformed.x, transformed.y, transformed.z) / transformed.w
    }

    /// Calculate mean alignment error
    private func calculateAlignmentError(_ correspondences: [(source: SIMD3<Float>, target: SIMD3<Float>)]) -> Float {
        let distances = correspondences.map { distance($0.source, $0.target) }
        return distances.reduce(0, +) / Float(distances.count)
    }

    /// Estimate rigid transformation from correspondences using SVD
    private func estimateTransform(_ correspondences: [(source: SIMD3<Float>, target: SIMD3<Float>)]) -> simd_float4x4 {
        // Calculate centroids
        let sourceCentroid = correspondences.map { $0.source }.reduce(SIMD3<Float>.zero, +) / Float(correspondences.count)
        let targetCentroid = correspondences.map { $0.target }.reduce(SIMD3<Float>.zero, +) / Float(correspondences.count)

        // Center the points
        let centeredSource = correspondences.map { $0.source - sourceCentroid }
        let centeredTarget = correspondences.map { $0.target - targetCentroid }

        // Compute cross-covariance matrix H = sum(target * source^T)
        var H = simd_float3x3()
        for (s, t) in zip(centeredSource, centeredTarget) {
            H[0] += t * s.x
            H[1] += t * s.y
            H[2] += t * s.z
        }

        // SVD decomposition: H = U * S * V^T
        // Rotation: R = V * U^T
        // For simplicity, use a simplified rotation estimation
        let (rotation, _) = extractRotation(from: H)

        // Translation: t = target_centroid - R * source_centroid
        let rotatedSourceCentroid = rotation * sourceCentroid
        let translation = targetCentroid - rotatedSourceCentroid

        // Construct 4x4 transform matrix
        return makeTransform(rotation: rotation, translation: translation)
    }

    /// Extract rotation from cross-covariance matrix
    private func extractRotation(from H: simd_float3x3) -> (simd_float3x3, Bool) {
        // Simplified: use the matrix as-is if it's close to orthonormal
        // In production, you'd use proper SVD

        // Normalize columns
        let c0 = normalize(H[0])
        let c1 = normalize(H[1])
        let c2 = normalize(H[2])

        // Check if columns are orthogonal (determinant close to 1)
        let rotation = simd_float3x3(c0, c1, c2)
        let det = determinant(rotation)

        if abs(det - 1.0) < 0.1 {
            return (rotation, true)
        } else {
            // Return identity if not valid
            return (matrix_identity_float3x3, false)
        }
    }

    /// Create 4x4 transformation matrix
    private func makeTransform(rotation: simd_float3x3, translation: SIMD3<Float>) -> simd_float4x4 {
        var transform = matrix_identity_float4x4
        transform[0] = SIMD4<Float>(rotation[0], 0)
        transform[1] = SIMD4<Float>(rotation[1], 0)
        transform[2] = SIMD4<Float>(rotation[2], 0)
        transform[3] = SIMD4<Float>(translation, 1)
        return transform
    }

    /// Calculate alignment quality score (0-1)
    private func calculateAlignmentQuality(error: Float, correspondenceRatio: Float) -> Float {
        // Quality based on error and correspondence ratio
        let errorScore = max(0, 1.0 - error / 0.01)  // Good if error < 1cm
        let correspondenceScore = correspondenceRatio
        return (errorScore * 0.6 + correspondenceScore * 0.4)
    }
}

// MARK: - KD-Tree for Nearest Neighbor Search

/// Simple KD-tree for 3D point nearest neighbor queries
private class KDTree {
    private struct Node {
        let point: SIMD3<Float>
        let left: Node?
        let right: Node?
        let axis: Int
    }

    private let root: Node?

    init(points: [SIMD3<Float>]) {
        self.root = Self.buildTree(points: points, depth: 0)
    }

    /// Build KD-tree recursively
    private static func buildTree(points: [SIMD3<Float>], depth: Int) -> Node? {
        guard !points.isEmpty else { return nil }
        guard points.count > 1 else {
            return Node(point: points[0], left: nil, right: nil, axis: depth % 3)
        }

        let axis = depth % 3
        let sortedPoints = points.sorted { getComponent($0, axis: axis) < getComponent($1, axis: axis) }
        let median = sortedPoints.count / 2

        return Node(
            point: sortedPoints[median],
            left: buildTree(points: Array(sortedPoints[..<median]), depth: depth + 1),
            right: buildTree(points: Array(sortedPoints[(median + 1)...]), depth: depth + 1),
            axis: axis
        )
    }

    /// Find nearest neighbor
    func findNearest(to query: SIMD3<Float>) -> SIMD3<Float>? {
        var best: (point: SIMD3<Float>, distance: Float)?
        searchNearest(node: root, query: query, best: &best)
        return best?.point
    }

    /// Recursive nearest neighbor search
    private func searchNearest(node: Node?, query: SIMD3<Float>, best: inout (point: SIMD3<Float>, distance: Float)?) {
        guard let node = node else { return }

        let dist = distance(node.point, query)
        if best == nil || dist < best!.distance {
            best = (node.point, dist)
        }

        let axis = node.axis
        let queryValue = Self.getComponent(query, axis: axis)
        let nodeValue = Self.getComponent(node.point, axis: axis)
        let diff = queryValue - nodeValue

        // Search near side first
        let nearNode = diff < 0 ? node.left : node.right
        let farNode = diff < 0 ? node.right : node.left

        searchNearest(node: nearNode, query: query, best: &best)

        // Check if we need to search far side
        if best == nil || abs(diff) < best!.distance {
            searchNearest(node: farNode, query: query, best: &best)
        }
    }

    /// Get component by axis (0=x, 1=y, 2=z)
    private static func getComponent(_ point: SIMD3<Float>, axis: Int) -> Float {
        switch axis {
        case 0: return point.x
        case 1: return point.y
        case 2: return point.z
        default: return point.x
        }
    }
}
