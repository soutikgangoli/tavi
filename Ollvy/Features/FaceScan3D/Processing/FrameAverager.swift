//
//  FrameAverager.swift
//  Ollvy
//
//  Multi-frame averaging for high-quality noise reduction
//  Captures 10-15 frames per pose and averages vertex positions with outlier rejection
//

import ARKit
import simd

/// Result of frame averaging operation
public struct AveragedFrame {
    public let geometry: FaceMeshGeometry
    public let confidence: Float  // 0-1, based on tracking quality
    public let framesUsed: Int
    public let framesRejected: Int

    public init(geometry: FaceMeshGeometry, confidence: Float, framesUsed: Int, framesRejected: Int) {
        self.geometry = geometry
        self.confidence = confidence
        self.framesUsed = framesUsed
        self.framesRejected = framesRejected
    }
}

/// Multi-frame averaging with quality-based weighting
class FrameAverager {

    // MARK: - Configuration

    private let minFrames: Int
    private let maxFrames: Int
    private let outlierThreshold: Float = 3.0  // Standard deviations
    private let minTrackingConfidence: Float = 0.7

    // MARK: - Initialization

    init(minFrames: Int = 8, maxFrames: Int = 15) {
        self.minFrames = minFrames
        self.maxFrames = maxFrames
    }

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
        guard self.capturedFrames.count < self.maxFrames else { return }
        guard confidence >= self.minTrackingConfidence else {
            AppLogger.faceScan.debug("⚠️ Frame rejected: low tracking confidence \(confidence)")
            return
        }

        self.capturedFrames.append(CapturedFrame(
            geometry: geometry,
            confidence: confidence,
            timestamp: timestamp
        ))
    }

    /// Check if enough frames captured
    var hasEnoughFrames: Bool {
        return self.capturedFrames.count >= self.minFrames
    }

    /// Get current frame count
    var frameCount: Int {
        return self.capturedFrames.count
    }

    /// Average all captured frames with outlier rejection
    func average() -> AveragedFrame? {
        guard self.capturedFrames.count >= self.minFrames else {
            AppLogger.faceScan.error("❌ Not enough frames: \(self.capturedFrames.count)/\(self.minFrames)")
            return nil
        }

        AppLogger.faceScan.info("📊 Averaging \(self.capturedFrames.count) frames...")

        // Get reference geometry (first frame)
        let referenceGeometry = self.capturedFrames[0].geometry
        let vertexCount = referenceGeometry.vertices.count

        // Collect all vertex positions
        var vertexPositions: [[SIMD3<Float>]] = []
        for frame in self.capturedFrames {
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

        // Calculate normals from averaged vertices and triangles
        // (ARFaceGeometry doesn't provide normals directly, we compute them)
        var averagedNormals = Array(repeating: SIMD3<Float>.zero, count: vertexCount)
        var normalCounts = Array(repeating: 0, count: vertexCount)

        // Use reference geometry's triangle structure
        let triangleIndices = Array(referenceGeometry.triangleIndices)
        for i in stride(from: 0, to: triangleIndices.count, by: 3) {
            let i0 = Int(triangleIndices[i])
            let i1 = Int(triangleIndices[i + 1])
            let i2 = Int(triangleIndices[i + 2])

            let v0 = averagedVertices[i0]
            let v1 = averagedVertices[i1]
            let v2 = averagedVertices[i2]

            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let faceNormal = cross(edge1, edge2)

            averagedNormals[i0] += faceNormal
            averagedNormals[i1] += faceNormal
            averagedNormals[i2] += faceNormal
            normalCounts[i0] += 1
            normalCounts[i1] += 1
            normalCounts[i2] += 1
        }

        // Normalize all vertex normals
        for i in 0..<vertexCount {
            if normalCounts[i] > 0 {
                averagedNormals[i] = normalize(averagedNormals[i] / Float(normalCounts[i]))
            }
        }

        // Calculate overall confidence
        let avgConfidence = self.capturedFrames.map { $0.confidence }.reduce(0, +) / Float(self.capturedFrames.count)
        let totalRejections = rejectionCounts.reduce(0, +)
        let rejectionRate = Float(totalRejections) / Float(vertexCount * self.capturedFrames.count)
        let qualityPenalty = max(0, 1.0 - rejectionRate * 2.0)  // Penalize high rejection rates
        let finalConfidence = avgConfidence * qualityPenalty

        AppLogger.faceScan.info("✅ Averaged \(self.capturedFrames.count) frames")
        AppLogger.faceScan.debug("   Confidence: \(String(format: "%.2f", finalConfidence))")
        AppLogger.faceScan.debug("   Rejections: \(totalRejections) (\(String(format: "%.1f%%", rejectionRate * 100)))")

        // Create averaged geometry (convert Int16 to Int32 for FaceMeshGeometry)
        let triangleIndicesInt32 = Array(referenceGeometry.triangleIndices).map { Int32($0) }
        let averagedGeometry = FaceMeshGeometry(
            vertices: averagedVertices,
            normals: averagedNormals,
            textureCoordinates: Array(referenceGeometry.textureCoordinates),
            triangleIndices: triangleIndicesInt32
        )

        let result = AveragedFrame(
            geometry: averagedGeometry,
            confidence: finalConfidence,
            framesUsed: self.capturedFrames.count,
            framesRejected: 0  // Individual frame rejection handled in addFrame
        )

        // Reset for next capture
        reset()

        return result
    }

    /// Reset frame buffer
    func reset() {
        self.capturedFrames.removeAll()
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

}
