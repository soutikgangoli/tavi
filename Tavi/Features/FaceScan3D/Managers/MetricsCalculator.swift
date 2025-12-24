//
//  MetricsCalculator.swift
//  Tavi
//
//  Handles 3D metrics calculations and analysis
//  Extracted from FaceScan3DViewModel for better maintainability
//

import Foundation
import ARKit
import simd

/// Calculates skin health metrics from 3D face mesh data
@MainActor
public class MetricsCalculator {

    // MARK: - Public Methods

    /// Calculates comprehensive face metrics from captured data
    public func calculateMetrics(from capturedPoses: [GuidanceStep: CapturedPoseData]) -> FaceMetrics? {
        guard !capturedPoses.isEmpty else {
            return nil
        }

        // Calculate individual metrics
        let volumeMetrics = calculateVolumeMetrics(from: capturedPoses)
        let symmetry = calculateSymmetry(from: capturedPoses)
        let surfaceQuality = calculateSurfaceQuality(from: capturedPoses)
        let regionalAnalysis = performRegionalAnalysis(from: capturedPoses)

        // Calculate overall score
        let overallScore = calculateOverallScore(
            volume: volumeMetrics,
            symmetry: symmetry,
            surfaceQuality: surfaceQuality
        )

        return FaceMetrics(
            overallScore: overallScore,
            volumeMetrics: volumeMetrics,
            symmetryScore: symmetry,
            surfaceQualityScore: surfaceQuality,
            regionalAnalysis: regionalAnalysis
        )
    }

    /// Calculates skin elasticity from blend shapes
    public func calculateElasticity(from blendShapes: [ARFaceAnchor.BlendShapeLocation: NSNumber]) -> Double {
        // Analyze facial muscle movement range
        var elasticityScore: Double = 0

        // Check smile range
        if let mouthSmileLeft = blendShapes[.mouthSmileLeft]?.doubleValue,
           let mouthSmileRight = blendShapes[.mouthSmileRight]?.doubleValue {
            let smileRange = (mouthSmileLeft + mouthSmileRight) / 2.0
            elasticityScore += smileRange * 30 // 30% weight
        }

        // Check cheek puff range
        if let cheekPuff = blendShapes[.cheekPuff]?.doubleValue {
            elasticityScore += cheekPuff * 20 // 20% weight
        }

        // Check eyebrow movement
        if let browInnerUp = blendShapes[.browInnerUp]?.doubleValue,
           let browOuterUpLeft = blendShapes[.browOuterUpLeft]?.doubleValue,
           let browOuterUpRight = blendShapes[.browOuterUpRight]?.doubleValue {
            let browMobility = (browInnerUp + browOuterUpLeft + browOuterUpRight) / 3.0
            elasticityScore += browMobility * 25 // 25% weight
        }

        // Check jaw movement
        if let jawOpen = blendShapes[.jawOpen]?.doubleValue {
            elasticityScore += jawOpen * 25 // 25% weight
        }

        return min(elasticityScore, 100.0)
    }

    /// Analyzes texture quality from face mesh
    public func analyzeTextureQuality(from geometry: FaceMeshGeometry) -> Double {
        // Calculate texture variance (smoothness indicator)
        let vertices = geometry.vertices

        guard vertices.count > 100 else {
            return 50.0 // Default score for insufficient data
        }

        // Calculate vertex spacing variance (evenness indicator)
        var totalVariance: Float = 0
        let sampleSize = min(100, vertices.count - 1)

        for i in 0..<sampleSize {
            let distance = simd_distance(vertices[i], vertices[i + 1])
            totalVariance += distance
        }

        let averageSpacing = totalVariance / Float(sampleSize)

        // Normalize to 0-100 score (lower variance = better quality)
        // Typical good spacing is around 0.005-0.015
        let quality = max(0, min(100, 100 - (averageSpacing * 1000)))

        return Double(quality)
    }

    /// Calculates pore visibility score
    public func calculatePoreVisibility(from geometry: FaceMeshGeometry) -> Double {
        // Analyze normal vectors for micro-surface details
        let normals = geometry.normals

        guard normals.count > 50 else {
            return 50.0
        }

        // Calculate normal variance (more variance = more visible pores)
        var totalDeviation: Float = 0
        let avgNormal = normals.reduce(simd_float3(0, 0, 0)) { $0 + $1 } / Float(normals.count)

        for normal in normals {
            totalDeviation += simd_distance(normal, avgNormal)
        }

        let averageDeviation = totalDeviation / Float(normals.count)

        // Convert to pore visibility score (0-100)
        // Higher deviation = more visible pores = lower score
        let poreScore = max(0, min(100, 100 - (averageDeviation * 500)))

        return Double(poreScore)
    }

    // MARK: - Private Methods

    private func calculateVolumeMetrics(from poses: [GuidanceStep: CapturedPoseData]) -> VolumeMetrics {
        // Calculate facial volume indicators
        var totalVertices: [simd_float3] = []

        for (_, poseData) in poses {
            totalVertices.append(contentsOf: poseData.geometry.vertices)
        }

        guard !totalVertices.isEmpty else {
            return VolumeMetrics(
                cheekVolume: 50,
                foreheadVolume: 50,
                chinVolume: 50,
                overallFullness: 50
            )
        }

        // Calculate bounding box
        let minPoint = totalVertices.reduce(totalVertices[0]) { simd_min($0, $1) }
        let maxPoint = totalVertices.reduce(totalVertices[0]) { simd_max($0, $1) }

        let width = maxPoint.x - minPoint.x
        let height = maxPoint.y - minPoint.y
        let depth = maxPoint.z - minPoint.z

        // Calculate volume scores (normalized to 0-100)
        let cheekVolume = Double(width * 100)
        let foreheadVolume = Double(height * 100)
        let chinVolume = Double(depth * 100)
        let overallFullness = (cheekVolume + foreheadVolume + chinVolume) / 3.0

        return VolumeMetrics(
            cheekVolume: min(100, cheekVolume),
            foreheadVolume: min(100, foreheadVolume),
            chinVolume: min(100, chinVolume),
            overallFullness: min(100, overallFullness)
        )
    }

    private func calculateSymmetry(from poses: [GuidanceStep: CapturedPoseData]) -> Double {
        // Check left/right symmetry
        guard let straightPose = poses[.lookStraight],
              let leftPose = poses[.turnLeft],
              let rightPose = poses[.turnRight] else {
            return 50.0 // Insufficient data
        }

        // Compare left and right facial halves
        let leftVertices = leftPose.geometry.vertices
        let rightVertices = rightPose.geometry.vertices

        guard leftVertices.count == rightVertices.count else {
            return 50.0
        }

        // Calculate average distance difference
        var totalDifference: Float = 0

        for i in 0..<min(leftVertices.count, rightVertices.count) {
            // Mirror right vertex across Y-axis
            let mirroredRight = simd_float3(-rightVertices[i].x, rightVertices[i].y, rightVertices[i].z)
            totalDifference += simd_distance(leftVertices[i], mirroredRight)
        }

        let averageDifference = totalDifference / Float(leftVertices.count)

        // Convert to symmetry score (lower difference = higher score)
        let symmetryScore = max(0, min(100, 100 - (averageDifference * 200)))

        return Double(symmetryScore)
    }

    private func calculateSurfaceQuality(from poses: [GuidanceStep: CapturedPoseData]) -> Double {
        guard let straightPose = poses[.lookStraight] else {
            return 50.0
        }

        let textureQuality = analyzeTextureQuality(from: straightPose.geometry)
        let poreVisibility = calculatePoreVisibility(from: straightPose.geometry)

        // Weighted average
        return (textureQuality * 0.6) + (poreVisibility * 0.4)
    }

    private func performRegionalAnalysis(from poses: [GuidanceStep: CapturedPoseData]) -> FacialRegionScores {
        guard let straightPose = poses[.lookStraight] else {
            return FacialRegionScores.empty
        }

        // Divide face into regions and analyze each
        return FacialRegionScores(
            foreheadScore: analyzeRegion(.forehead, from: straightPose),
            cheeksScore: analyzeRegion(.cheeks, from: straightPose),
            eyeAreaScore: analyzeRegion(.eyeArea, from: straightPose),
            noseScore: analyzeRegion(.nose, from: straightPose),
            mouthScore: analyzeRegion(.mouth, from: straightPose),
            chinScore: analyzeRegion(.chin, from: straightPose)
        )
    }

    private func analyzeRegion(_ region: FacialRegionType, from pose: CapturedPoseData) -> Double {
        // Analyze specific facial region
        // This is a simplified version - would need proper region segmentation
        return analyzeTextureQuality(from: pose.geometry)
    }

    private func calculateOverallScore(
        volume: VolumeMetrics,
        symmetry: Double,
        surfaceQuality: Double
    ) -> Double {
        // Weighted combination of metrics
        let volumeScore = volume.overallFullness
        let weightedScore = (volumeScore * 0.3) + (symmetry * 0.35) + (surfaceQuality * 0.35)

        return min(100, max(0, weightedScore))
    }
}

// MARK: - Supporting Types

public struct FaceMetrics {
    public let overallScore: Double
    public let volumeMetrics: VolumeMetrics
    public let symmetryScore: Double
    public let surfaceQualityScore: Double
    public let regionalAnalysis: FacialRegionScores
}

public struct VolumeMetrics {
    public let cheekVolume: Double
    public let foreheadVolume: Double
    public let chinVolume: Double
    public let overallFullness: Double
}

public struct FacialRegionScores {
    public let foreheadScore: Double
    public let cheeksScore: Double
    public let eyeAreaScore: Double
    public let noseScore: Double
    public let mouthScore: Double
    public let chinScore: Double

    public static let empty = FacialRegionScores(
        foreheadScore: 50.0,
        cheeksScore: 50.0,
        eyeAreaScore: 50.0,
        noseScore: 50.0,
        mouthScore: 50.0,
        chinScore: 50.0
    )
}

public enum FacialRegionType {
    case forehead
    case cheeks
    case eyeArea
    case nose
    case mouth
    case chin
}
