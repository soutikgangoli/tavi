//
//  VolumeMetrics.swift
//  Tavi
//
//  Volume-based aging metrics: cheek hollowing, under-eye bags, facial symmetry
//  HIGH VALUE for comprehensive aging analysis
//

import Foundation
import simd

/// Volume-based aging analysis
public struct VolumeAnalysis {
    let overallScore: Float  // 0-100
    let cheekHollowing: CheekHollowingAnalysis
    let underEyeBags: UnderEyeBagAnalysis
    let facialSymmetry: SymmetryAnalysis
    let volumeChanges: VolumeChanges?  // Compared to baseline
}

/// Cheek hollowing (volume loss) analysis
public struct CheekHollowingAnalysis {
    let score: Float  // 0-100, lower = more hollowing
    let severity: HollowingSeverity
    let leftCheekVolume: Float
    let rightCheekVolume: Float
    let volumeLoss: Float  // % compared to ideal
}

public enum HollowingSeverity: String {
    case none = "None"
    case mild = "Mild"
    case moderate = "Moderate"
    case severe = "Severe"
}

/// Under-eye bags analysis
public struct UnderEyeBagAnalysis {
    let score: Float  // 0-100, higher = less prominent bags
    let severity: BagSeverity
    let leftEyeVolume: Float
    let rightEyeVolume: Float
    let protrusion: Float  // mm of protrusion
}

public enum BagSeverity: String {
    case none = "None"
    case mild = "Mild"
    case moderate = "Moderate"
    case severe = "Severe"
}

/// Facial symmetry analysis
public struct SymmetryAnalysis {
    let score: Float  // 0-100, higher = more symmetric
    let leftRightDeviation: Float  // Average distance deviation
    let asymmetricRegions: [FaceRegion]
}

/// Volume changes over time
public struct VolumeChanges {
    let cheekVolumeChange: Float  // % change
    let eyeVolumeChange: Float
    let overallVolumeChange: Float
    let trend: VolumeTrend
}

public enum VolumeTrend: String {
    case increasing = "Increasing"
    case stable = "Stable"
    case decreasing = "Decreasing"
}

/// Volume-based metrics analyzer
public class VolumeMetricsAnalyzer {

    // MARK: - Public API

    /// Analyze volume-based aging metrics
    public func analyzeVolume(
        geometry: FaceMeshGeometry,
        baseline: FaceMeshGeometry? = nil
    ) -> VolumeAnalysis {

        // Analyze cheek hollowing
        let cheekHollowing = analyzeCheekHollowing(geometry: geometry, baseline: baseline)

        // Analyze under-eye bags
        let underEyeBags = analyzeUnderEyeBags(geometry: geometry)

        // Analyze facial symmetry
        let symmetry = analyzeFacialSymmetry(geometry: geometry)

        // Calculate volume changes if baseline exists
        let volumeChanges = baseline != nil ? calculateVolumeChanges(
            current: geometry,
            baseline: baseline!
        ) : nil

        // Overall score (average of components)
        let overallScore = (cheekHollowing.score + underEyeBags.score + symmetry.score) / 3.0

        return VolumeAnalysis(
            overallScore: overallScore,
            cheekHollowing: cheekHollowing,
            underEyeBags: underEyeBags,
            facialSymmetry: symmetry,
            volumeChanges: volumeChanges
        )
    }

    // MARK: - Cheek Hollowing Analysis

    private func analyzeCheekHollowing(
        geometry: FaceMeshGeometry,
        baseline: FaceMeshGeometry?
    ) -> CheekHollowingAnalysis {

        // Extract cheek regions (approximate indices)
        let leftCheekIndices = getCheekIndices(side: .left)
        let rightCheekIndices = getCheekIndices(side: .right)

        // Calculate volumes
        let leftVolume = calculateRegionVolume(geometry: geometry, indices: leftCheekIndices)
        let rightVolume = calculateRegionVolume(geometry: geometry, indices: rightCheekIndices)

        // Average volume
        let avgVolume = (leftVolume + rightVolume) / 2.0

        // Estimate volume loss (compared to ideal full cheeks)
        let idealVolume: Float = 150.0  // cm³ (approximate)
        let volumeLoss = max(0, (idealVolume - avgVolume) / idealVolume * 100)

        // Score (inverse of volume loss)
        let score = 100 - volumeLoss

        // Classify severity
        let severity: HollowingSeverity
        if volumeLoss < 10 {
            severity = .none
        } else if volumeLoss < 25 {
            severity = .mild
        } else if volumeLoss < 40 {
            severity = .moderate
        } else {
            severity = .severe
        }

        return CheekHollowingAnalysis(
            score: score,
            severity: severity,
            leftCheekVolume: leftVolume,
            rightCheekVolume: rightVolume,
            volumeLoss: volumeLoss
        )
    }

    // MARK: - Under-Eye Bags Analysis

    private func analyzeUnderEyeBags(geometry: FaceMeshGeometry) -> UnderEyeBagAnalysis {

        // Extract under-eye regions
        let leftEyeIndices = getUnderEyeIndices(side: .left)
        let rightEyeIndices = getUnderEyeIndices(side: .right)

        // Calculate protrusion (how much bags stick out)
        let leftProtrusion = calculateProtrusion(geometry: geometry, indices: leftEyeIndices)
        let rightProtrusion = calculateProtrusion(geometry: geometry, indices: rightEyeIndices)

        let avgProtrusion = (leftProtrusion + rightProtrusion) / 2.0

        // Score (less protrusion = better)
        let score = max(0, 100 - (avgProtrusion / 0.005 * 100))  // 5mm = 0 score

        // Classify severity
        let severity: BagSeverity
        if avgProtrusion < 0.001 {  // <1mm
            severity = .none
        } else if avgProtrusion < 0.002 {  // 1-2mm
            severity = .mild
        } else if avgProtrusion < 0.004 {  // 2-4mm
            severity = .moderate
        } else {
            severity = .severe
        }

        // Volume (approximate)
        let leftVolume = calculateRegionVolume(geometry: geometry, indices: leftEyeIndices)
        let rightVolume = calculateRegionVolume(geometry: geometry, indices: rightEyeIndices)

        return UnderEyeBagAnalysis(
            score: score,
            severity: severity,
            leftEyeVolume: leftVolume,
            rightEyeVolume: rightVolume,
            protrusion: avgProtrusion * 1000  // Convert to mm
        )
    }

    // MARK: - Facial Symmetry Analysis

    private func analyzeFacialSymmetry(geometry: FaceMeshGeometry) -> SymmetryAnalysis {

        let vertices = geometry.vertices

        // Find center line (midpoint between left/right landmarks)
        let centerX = calculateFaceCenterX(vertices: vertices)

        var leftRightDeviations: [Float] = []
        var asymmetricRegions: Set<FaceRegion> = []

        // Compare left and right sides
        for i in 0..<vertices.count {
            let vertex = vertices[i]
            let distanceFromCenter = abs(vertex.x - centerX)

            // Find corresponding point on opposite side
            let mirroredX = centerX - (vertex.x - centerX)
            let mirroredPoint = SIMD3<Float>(mirroredX, vertex.y, vertex.z)

            // Find nearest vertex to mirrored point
            if let nearestIndex = findNearestVertex(to: mirroredPoint, in: vertices) {
                let nearest = vertices[nearestIndex]
                let deviation = distance(vertex, nearest)
                leftRightDeviations.append(deviation)

                // If deviation > 2mm, mark region as asymmetric
                if deviation > 0.002 {
                    let region = determineRegion(vertex: vertex)
                    asymmetricRegions.insert(region)
                }
            }
        }

        // Average deviation
        let avgDeviation = leftRightDeviations.reduce(0, +) / Float(max(leftRightDeviations.count, 1))

        // Score (less deviation = better symmetry)
        let score = max(0, 100 - (avgDeviation / 0.005 * 100))  // 5mm avg = 0 score

        return SymmetryAnalysis(
            score: score,
            leftRightDeviation: avgDeviation * 1000,  // Convert to mm
            asymmetricRegions: Array(asymmetricRegions)
        )
    }

    // MARK: - Volume Changes Over Time

    private func calculateVolumeChanges(
        current: FaceMeshGeometry,
        baseline: FaceMeshGeometry
    ) -> VolumeChanges {

        // Calculate total face volume for both
        let currentVolume = calculateTotalFaceVolume(geometry: current)
        let baselineVolume = calculateTotalFaceVolume(geometry: baseline)

        let volumeChange = ((currentVolume - baselineVolume) / baselineVolume) * 100

        // Determine trend
        let trend: VolumeTrend
        if volumeChange > 2 {
            trend = .increasing
        } else if volumeChange < -2 {
            trend = .decreasing
        } else {
            trend = .stable
        }

        return VolumeChanges(
            cheekVolumeChange: volumeChange,  // Simplified
            eyeVolumeChange: volumeChange,     // Simplified
            overallVolumeChange: volumeChange,
            trend: trend
        )
    }

    // MARK: - Helper Methods

    private func getCheekIndices(side: Side) -> [Int] {
        // ARKit face mesh cheek region (approximate)
        // Left cheek: ~300-400, Right cheek: ~400-500
        switch side {
        case .left:
            return Array(300..<400)
        case .right:
            return Array(400..<500)
        }
    }

    private func getUnderEyeIndices(side: Side) -> [Int] {
        // Under-eye region indices (approximate)
        switch side {
        case .left:
            return Array(100..<150)
        case .right:
            return Array(150..<200)
        }
    }

    private func calculateRegionVolume(geometry: FaceMeshGeometry, indices: [Int]) -> Float {
        // Calculate convex hull volume for region
        let vertices = geometry.vertices
        var regionVertices: [SIMD3<Float>] = []

        for index in indices where index < vertices.count {
            regionVertices.append(vertices[index])
        }

        // Simplified volume calculation (bounding box)
        guard !regionVertices.isEmpty else { return 0 }

        let minX = regionVertices.map { $0.x }.min() ?? 0
        let maxX = regionVertices.map { $0.x }.max() ?? 0
        let minY = regionVertices.map { $0.y }.min() ?? 0
        let maxY = regionVertices.map { $0.y }.max() ?? 0
        let minZ = regionVertices.map { $0.z }.min() ?? 0
        let maxZ = regionVertices.map { $0.z }.max() ?? 0

        let volume = (maxX - minX) * (maxY - minY) * (maxZ - minZ)
        return volume * 1_000_000  // Convert to cm³
    }

    private func calculateProtrusion(geometry: FaceMeshGeometry, indices: [Int]) -> Float {
        // Measure how much region protrudes from surrounding surface
        let vertices = geometry.vertices

        var regionDepths: [Float] = []

        for index in indices where index < vertices.count {
            let vertex = vertices[index]
            // Z-depth from face plane
            regionDepths.append(abs(vertex.z))
        }

        // Average depth
        return regionDepths.reduce(0, +) / Float(max(regionDepths.count, 1))
    }

    private func calculateTotalFaceVolume(geometry: FaceMeshGeometry) -> Float {
        // Simplified total volume calculation
        let allIndices = Array(0..<geometry.vertices.count)
        return calculateRegionVolume(geometry: geometry, indices: allIndices)
    }

    private func calculateFaceCenterX(vertices: [SIMD3<Float>]) -> Float {
        let avgX = vertices.map { $0.x }.reduce(0, +) / Float(vertices.count)
        return avgX
    }

    private func findNearestVertex(to point: SIMD3<Float>, in vertices: [SIMD3<Float>]) -> Int? {
        var minDistance: Float = .infinity
        var nearestIndex: Int? = nil

        for (index, vertex) in vertices.enumerated() {
            let dist = distance(point, vertex)
            if dist < minDistance {
                minDistance = dist
                nearestIndex = index
            }
        }

        return nearestIndex
    }

    private func determineRegion(vertex: SIMD3<Float>) -> FaceRegion {
        // Simplified region determination based on Y coordinate
        if vertex.y > 0.05 {
            return .forehead
        } else if vertex.y > 0.02 {
            return .eyes
        } else if vertex.y > -0.02 {
            return .cheeks
        } else if vertex.y > -0.05 {
            return .mouth
        } else {
            return .chin
        }
    }

    enum Side {
        case left, right
    }
}
