//
//  FrameAverager.swift
//  Tavi
//
//  Multi-frame averaging for clinical-grade noise reduction
//  Captures 10-15 frames per pose and averages vertex positions with outlier rejection
//

import ARKit
import simd

/// Result of frame averaging operation
struct AveragedFrame {
    let geometry: ARFaceGeometry
    let confidence: Float  // 0-1, based on tracking quality
    let framesUsed: Int
    let framesRejected: Int
}

/// Multi-frame averaging with quality-based weighting
class FrameAverager {

    // MARK: - Configuration

    private let minFrames = 8
    private let maxFrames = 15
    private let outlierThreshold: Float = 3.0  // Standard deviations
    private let minTrackingConfidence: Float = 0.7

    // MARK: - Frame Capture

    /// Captured frame with metadata
    private struct CapturedFrame {
        let geometry: ARFaceGeometry
        let confidence: Float
        let timestamp: TimeInterval
    }

    private var capturedFrames: [CapturedFrame] = []

    // MARK: - Public API

    /// Add a frame to the buffer
    func addFrame(_ geometry: ARFaceGeometry, confidence: Float, timestamp: TimeInterval) {
        guard capturedFrames.count < maxFrames else { return }
        guard confidence >= minTrackingConfidence else {
            print("⚠️ Frame rejected: low tracking confidence \(confidence)")
            return
        }

        capturedFrames.append(CapturedFrame(
            geometry: geometry,
            confidence: confidence,
            timestamp: timestamp
        ))
    }

    /// Check if enough frames captured
    var hasEnoughFrames: Bool {
        return capturedFrames.count >= minFrames
    }

    /// Get current frame count
    var frameCount: Int {
        return capturedFrames.count
    }

    /// Average all captured frames with outlier rejection
    func average() -> AveragedFrame? {
        guard capturedFrames.count >= minFrames else {
            print("❌ Not enough frames: \(capturedFrames.count)/\(minFrames)")
            return nil
        }

        print("📊 Averaging \(capturedFrames.count) frames...")

        // Get reference geometry (first frame)
        let referenceGeometry = capturedFrames[0].geometry
        let vertexCount = referenceGeometry.vertices.count

        // Collect all vertex positions
        var vertexPositions: [[SIMD3<Float>]] = []
        for frame in capturedFrames {
            let positions = (0..<frame.geometry.vertices.count).map { i in
                frame.geometry.vertices[i]
            }
            vertexPositions.append(positions)
        }

        // Average each vertex with outlier rejection
        var averagedVertices: [SIMD3<Float>] = []
        var rejectionCounts = Array(repeating: 0, count: vertexCount)

        for vertexIndex in 0..<vertexCount {
            let positions = vertexPositions.map { $0[vertexIndex] }
            let (averaged, rejectedCount) = averageVertexWithOutlierRejection(positions)
            averagedVertices.append(averaged)
            rejectionCounts[vertexIndex] = rejectedCount
        }

        // Average normals (no outlier rejection, just weighted)
        var averagedNormals: [SIMD3<Float>] = []
        for vertexIndex in 0..<vertexCount {
            let normals = capturedFrames.map { frame in
                frame.geometry.normals[vertexIndex]
            }
            let weights = capturedFrames.map { $0.confidence }
            let averaged = weightedAverageNormals(normals, weights: weights)
            averagedNormals.append(averaged)
        }

        // Calculate overall confidence
        let avgConfidence = capturedFrames.map { $0.confidence }.reduce(0, +) / Float(capturedFrames.count)
        let totalRejections = rejectionCounts.reduce(0, +)
        let rejectionRate = Float(totalRejections) / Float(vertexCount * capturedFrames.count)
        let qualityPenalty = max(0, 1.0 - rejectionRate * 2.0)  // Penalize high rejection rates
        let finalConfidence = avgConfidence * qualityPenalty

        print("✅ Averaged \(capturedFrames.count) frames")
        print("   Confidence: \(String(format: "%.2f", finalConfidence))")
        print("   Rejections: \(totalRejections) (\(String(format: "%.1f%%", rejectionRate * 100)))")

        // Create averaged geometry
        let averagedGeometry = createGeometry(
            vertices: averagedVertices,
            normals: averagedNormals,
            textureCoordinates: Array(referenceGeometry.textureCoordinates),
            triangleIndices: Array(referenceGeometry.triangleIndices)
        )

        let result = AveragedFrame(
            geometry: averagedGeometry,
            confidence: finalConfidence,
            framesUsed: capturedFrames.count,
            framesRejected: 0  // Individual frame rejection handled in addFrame
        )

        // Reset for next capture
        reset()

        return result
    }

    /// Reset frame buffer
    func reset() {
        capturedFrames.removeAll()
    }

    // MARK: - Private Methods

    /// Average vertex positions with outlier rejection
    private func averageVertexWithOutlierRejection(_ positions: [SIMD3<Float>]) -> (SIMD3<Float>, Int) {
        guard positions.count > 2 else {
            return (positions.first ?? .zero, 0)
        }

        // Calculate mean
        let mean = positions.reduce(SIMD3<Float>.zero, +) / Float(positions.count)

        // Calculate standard deviation
        let squaredDistances = positions.map { pos in
            let diff = pos - mean
            return dot(diff, diff)
        }
        let variance = squaredDistances.reduce(0, +) / Float(positions.count)
        let stdDev = sqrt(variance)

        // Filter outliers
        var validPositions: [SIMD3<Float>] = []
        var rejectedCount = 0

        for pos in positions {
            let distance = sqrt(dot(pos - mean, pos - mean))
            if distance <= stdDev * outlierThreshold {
                validPositions.append(pos)
            } else {
                rejectedCount += 1
            }
        }

        // If too many rejected, use all
        if validPositions.count < positions.count / 2 {
            validPositions = positions
            rejectedCount = 0
        }

        // Calculate final average
        let finalAverage = validPositions.reduce(SIMD3<Float>.zero, +) / Float(validPositions.count)

        return (finalAverage, rejectedCount)
    }

    /// Weighted average of normals
    private func weightedAverageNormals(_ normals: [SIMD3<Float>], weights: [Float]) -> SIMD3<Float> {
        var sum = SIMD3<Float>.zero
        var weightSum: Float = 0

        for (normal, weight) in zip(normals, weights) {
            sum += normal * weight
            weightSum += weight
        }

        let averaged = sum / weightSum
        return normalize(averaged)
    }

    /// Create ARFaceGeometry from arrays
    private func createGeometry(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        textureCoordinates: [SIMD2<Float>],
        triangleIndices: [Int16]
    ) -> ARFaceGeometry {
        // ARFaceGeometry can't be created directly, so we'll wrap it in our own type
        // For now, return the reference geometry and we'll update vertices via Metal buffer
        // This is a limitation - in production you'd create a custom mesh type

        // Create custom face geometry wrapper
        return ARFaceGeometryWrapper(
            vertices: vertices,
            normals: normals,
            textureCoordinates: textureCoordinates,
            triangleIndices: triangleIndices
        )
    }
}

// MARK: - ARFaceGeometry Wrapper

/// Custom wrapper since ARFaceGeometry can't be instantiated directly
class ARFaceGeometryWrapper: ARFaceGeometry {
    private let _vertices: [SIMD3<Float>]
    private let _normals: [SIMD3<Float>]
    private let _textureCoordinates: [SIMD2<Float>]
    private let _triangleIndices: [Int16]

    init(vertices: [SIMD3<Float>], normals: [SIMD3<Float>], textureCoordinates: [SIMD2<Float>], triangleIndices: [Int16]) {
        self._vertices = vertices
        self._normals = normals
        self._textureCoordinates = textureCoordinates
        self._triangleIndices = triangleIndices
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override var vertices: UnsafeBufferPointer<SIMD3<Float>> {
        return _vertices.withUnsafeBufferPointer { $0 }
    }

    override var normals: UnsafeBufferPointer<SIMD3<Float>> {
        return _normals.withUnsafeBufferPointer { $0 }
    }

    override var textureCoordinates: UnsafeBufferPointer<SIMD2<Float>> {
        return _textureCoordinates.withUnsafeBufferPointer { $0 }
    }

    override var triangleIndices: UnsafeBufferPointer<Int16> {
        return _triangleIndices.withUnsafeBufferPointer { $0 }
    }

    override var triangleCount: Int {
        return _triangleIndices.count / 3
    }

    override var vertexCount: Int {
        return _vertices.count
    }
}
