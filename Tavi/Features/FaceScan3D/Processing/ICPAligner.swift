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

    /// Extract rotation from cross-covariance matrix using proper SVD
    private func extractRotation(from H: simd_float3x3) -> (simd_float3x3, Bool) {
        // Compute SVD: H = U * S * V^T
        // The rotation matrix is R = V * U^T

        let svdResult = computeSVD3x3(H)

        guard svdResult.converged else {
            print("⚠️ SVD did not converge, using simplified approach")
            return extractRotationSimplified(from: H)
        }

        // R = V * U^T
        let rotation = svdResult.V * simd_transpose(svdResult.U)

        // Ensure proper rotation (det = 1, not reflection det = -1)
        let det = determinant3x3(rotation)

        if det < 0 {
            // Flip sign of last column of V to ensure proper rotation
            var correctedV = svdResult.V
            correctedV[2] = -correctedV[2]
            let correctedRotation = correctedV * simd_transpose(svdResult.U)
            return (correctedRotation, true)
        } else {
            return (rotation, true)
        }
    }

    /// Simplified rotation extraction (fallback)
    private func extractRotationSimplified(from H: simd_float3x3) -> (simd_float3x3, Bool) {
        // Normalize columns
        let c0 = normalize(H[0])
        let c1 = normalize(H[1])
        let c2 = normalize(H[2])

        // Check if columns are orthogonal (determinant close to 1)
        let rotation = simd_float3x3(c0, c1, c2)
        let det = determinant3x3(rotation)

        if abs(det - 1.0) < 0.1 {
            return (rotation, true)
        } else {
            // Return identity if not valid
            return (matrix_identity_float3x3, false)
        }
    }

    /// Calculate determinant of 3x3 matrix
    private func determinant3x3(_ m: simd_float3x3) -> Float {
        let c0 = m[0]
        let c1 = m[1]
        let c2 = m[2]

        return c0.x * (c1.y * c2.z - c1.z * c2.y) -
               c0.y * (c1.x * c2.z - c1.z * c2.x) +
               c0.z * (c1.x * c2.y - c1.y * c2.x)
    }

    // MARK: - SVD Implementation

    /// SVD result for 3x3 matrix
    private struct SVDResult {
        let U: simd_float3x3      // Left singular vectors
        let S: SIMD3<Float>       // Singular values
        let V: simd_float3x3      // Right singular vectors
        let converged: Bool
    }

    /// Compute SVD of 3x3 matrix using Jacobi method
    /// Returns: H = U * diag(S) * V^T
    private func computeSVD3x3(_ A: simd_float3x3) -> SVDResult {
        let maxIterations = 30
        let tolerance: Float = 1e-6

        // Step 1: Compute A^T * A
        let AtA = simd_transpose(A) * A

        // Step 2: Compute eigendecomposition of A^T * A to get V and S^2
        let eigenResult = computeEigen3x3(AtA, maxIterations: maxIterations, tolerance: tolerance)

        guard eigenResult.converged else {
            return SVDResult(U: matrix_identity_float3x3, S: SIMD3<Float>(1, 1, 1), V: matrix_identity_float3x3, converged: false)
        }

        let V = eigenResult.eigenvectors
        var S = SIMD3<Float>(
            sqrt(max(0, eigenResult.eigenvalues.x)),
            sqrt(max(0, eigenResult.eigenvalues.y)),
            sqrt(max(0, eigenResult.eigenvalues.z))
        )

        // Sort singular values in descending order
        let sorted = sortSingularValues(S: S, V: V)
        S = sorted.S
        let sortedV = sorted.V

        // Step 3: Compute U = A * V * S^-1
        var U = matrix_identity_float3x3

        for i in 0..<3 {
            if S[i] > tolerance {
                let vi = sortedV[i]
                let ui = A * vi / S[i]
                U[i] = normalize(ui)
            } else {
                // For zero singular values, use arbitrary orthonormal vector
                U[i] = SIMD3<Float>(i == 0 ? 1 : 0, i == 1 ? 1 : 0, i == 2 ? 1 : 0)
            }
        }

        return SVDResult(U: U, S: S, V: sortedV, converged: true)
    }

    /// Eigendecomposition result
    private struct EigenResult {
        let eigenvalues: SIMD3<Float>
        let eigenvectors: simd_float3x3
        let converged: Bool
    }

    /// Compute eigendecomposition of symmetric 3x3 matrix using Jacobi method
    private func computeEigen3x3(_ A: simd_float3x3, maxIterations: Int, tolerance: Float) -> EigenResult {
        var matrix = A
        var V = matrix_identity_float3x3

        for iteration in 0..<maxIterations {
            // Find largest off-diagonal element
            let (p, q, maxOffDiag) = findLargestOffDiagonal(matrix)

            // Check convergence
            if maxOffDiag < tolerance {
                let eigenvalues = SIMD3<Float>(matrix[0][0], matrix[1][1], matrix[2][2])
                return EigenResult(eigenvalues: eigenvalues, eigenvectors: V, converged: true)
            }

            // Compute Jacobi rotation
            let (c, s) = computeJacobiRotation(matrix: matrix, p: p, q: q)

            // Apply rotation: A = J^T * A * J
            applyJacobiRotation(matrix: &matrix, V: &V, p: p, q: q, c: c, s: s)
        }

        // Did not converge
        let eigenvalues = SIMD3<Float>(matrix[0][0], matrix[1][1], matrix[2][2])
        return EigenResult(eigenvalues: eigenvalues, eigenvectors: V, converged: false)
    }

    /// Find largest off-diagonal element
    private func findLargestOffDiagonal(_ A: simd_float3x3) -> (p: Int, q: Int, value: Float) {
        var maxVal: Float = 0
        var maxP = 0
        var maxQ = 1

        for i in 0..<3 {
            for j in (i+1)..<3 {
                let val = abs(A[i][j])
                if val > maxVal {
                    maxVal = val
                    maxP = i
                    maxQ = j
                }
            }
        }

        return (maxP, maxQ, maxVal)
    }

    /// Compute Jacobi rotation parameters
    private func computeJacobiRotation(matrix: simd_float3x3, p: Int, q: Int) -> (c: Float, s: Float) {
        let App = matrix[p][p]
        let Aqq = matrix[q][q]
        let Apq = matrix[p][q]

        if abs(Apq) < 1e-10 {
            return (1.0, 0.0)
        }

        let tau = (Aqq - App) / (2.0 * Apq)
        let t: Float

        if tau >= 0 {
            t = 1.0 / (tau + sqrt(1.0 + tau * tau))
        } else {
            t = -1.0 / (-tau + sqrt(1.0 + tau * tau))
        }

        let c = 1.0 / sqrt(1.0 + t * t)
        let s = t * c

        return (c, s)
    }

    /// Apply Jacobi rotation to matrix and eigenvector matrix
    private func applyJacobiRotation(matrix: inout simd_float3x3, V: inout simd_float3x3, p: Int, q: Int, c: Float, s: Float) {
        // Update matrix A
        let App = matrix[p][p]
        let Aqq = matrix[q][q]
        let Apq = matrix[p][q]

        matrix[p][p] = c * c * App - 2.0 * s * c * Apq + s * s * Aqq
        matrix[q][q] = s * s * App + 2.0 * s * c * Apq + c * c * Aqq
        matrix[p][q] = 0.0
        matrix[q][p] = 0.0

        // Update other elements
        for i in 0..<3 {
            if i != p && i != q {
                let Aip = matrix[i][p]
                let Aiq = matrix[i][q]
                matrix[i][p] = c * Aip - s * Aiq
                matrix[p][i] = matrix[i][p]
                matrix[i][q] = s * Aip + c * Aiq
                matrix[q][i] = matrix[i][q]
            }
        }

        // Update eigenvectors V
        for i in 0..<3 {
            let Vip = V[i][p]
            let Viq = V[i][q]
            V[i][p] = c * Vip - s * Viq
            V[i][q] = s * Vip + c * Viq
        }
    }

    /// Sort singular values in descending order
    private func sortSingularValues(S: SIMD3<Float>, V: simd_float3x3) -> (S: SIMD3<Float>, V: simd_float3x3) {
        var values = [(value: Float, index: Int)]()
        values.append((S.x, 0))
        values.append((S.y, 1))
        values.append((S.z, 2))

        values.sort { $0.value > $1.value }

        let sortedS = SIMD3<Float>(values[0].value, values[1].value, values[2].value)
        var sortedV = matrix_identity_float3x3
        sortedV[0] = V[values[0].index]
        sortedV[1] = V[values[1].index]
        sortedV[2] = V[values[2].index]

        return (sortedS, sortedV)
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
    private class Node {
        let point: SIMD3<Float>
        let left: Node?
        let right: Node?
        let axis: Int

        init(point: SIMD3<Float>, left: Node?, right: Node?, axis: Int) {
            self.point = point
            self.left = left
            self.right = right
            self.axis = axis
        }
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

        let leftChild = buildTree(points: Array(sortedPoints[..<median]), depth: depth + 1)
        let rightChild = buildTree(points: Array(sortedPoints[(median + 1)...]), depth: depth + 1)

        return Node(
            point: sortedPoints[median],
            left: leftChild,
            right: rightChild,
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
