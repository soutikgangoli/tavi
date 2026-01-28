//
//  VolumeMetrics.swift
//  Ollvy
//
//  Volume-based aging metrics: cheek hollowing, under-eye bags, facial symmetry
//  HIGH VALUE for comprehensive aging analysis
//

import Foundation
import simd

/// Volume-based aging analysis
public struct VolumeAnalysis: Codable, Sendable {
    let overallScore: Float  // 0-100
    let cheekHollowing: CheekHollowingAnalysis?  // nil if insufficient data
    let underEyeBags: UnderEyeBagAnalysis?  // nil if insufficient data
    let facialSymmetry: SymmetryAnalysis?  // nil if insufficient data
    let volumeChanges: VolumeChanges?  // Compared to baseline
}

/// Cheek hollowing (volume loss) analysis
public struct CheekHollowingAnalysis: Codable, Sendable {
    let score: Float  // 0-100, lower = more hollowing
    let severity: HollowingSeverity
    let leftCheekVolume: Float
    let rightCheekVolume: Float
    let volumeLoss: Float  // % compared to ideal
}

public enum HollowingSeverity: String, Codable, Sendable {
    case none = "None"
    case mild = "Mild"
    case moderate = "Moderate"
    case severe = "Severe"
}

/// Under-eye bags analysis
public struct UnderEyeBagAnalysis: Codable, Sendable {
    let score: Float  // 0-100, higher = less prominent bags
    let severity: BagSeverity
    let leftEyeVolume: Float
    let rightEyeVolume: Float
    let protrusion: Float  // mm of protrusion
}

public enum BagSeverity: String, Codable, Sendable {
    case none = "None"
    case mild = "Mild"
    case moderate = "Moderate"
    case severe = "Severe"
}

/// Facial symmetry analysis
public struct SymmetryAnalysis: Codable, Sendable {
    let score: Float  // 0-100, higher = more symmetric
    let leftRightDeviation: Float  // Average distance deviation
    let asymmetricRegions: [FaceRegion]
}

/// Volume changes over time
public struct VolumeChanges: Codable, Sendable {
    let cheekVolumeChange: Float  // % change
    let eyeVolumeChange: Float
    let overallVolumeChange: Float
    let trend: VolumeTrend
}

public enum VolumeTrend: String, Codable, Sendable {
    case increasing = "Increasing"
    case stable = "Stable"
    case decreasing = "Decreasing"
}

/// Volume-based metrics analyzer
public class VolumeMetricsAnalyzer {

    // MARK: - Public API

    /// Analyze volume-based aging metrics
    /// Returns nil if insufficient vertex data for analysis
    public func analyzeVolume(
        geometry: FaceMeshGeometry,
        baseline: FaceMeshGeometry? = nil
    ) -> VolumeAnalysis? {
        AppLogger.metrics.info("💠 VolumeMetricsAnalyzer: Starting analysis...")

        // Analyze cheek hollowing
        let cheekHollowing = analyzeCheekHollowing(geometry: geometry, baseline: baseline)
        if cheekHollowing == nil {
            AppLogger.metrics.warning("   ⚠️ Cheek hollowing analysis failed (returned nil)")
        }

        // Analyze under-eye bags
        let underEyeBags = analyzeUnderEyeBags(geometry: geometry)
        if underEyeBags == nil {
            AppLogger.metrics.warning("   ⚠️ Under-eye bag analysis failed (returned nil)")
        }

        // Analyze facial symmetry
        let symmetry = analyzeFacialSymmetry(geometry: geometry)
        if symmetry == nil {
            AppLogger.metrics.warning("   ⚠️ Facial symmetry analysis failed (returned nil)")
        }

        // Calculate volume changes if baseline exists
        let volumeChanges: VolumeChanges?
        if let baselineGeometry = baseline {
            volumeChanges = calculateVolumeChanges(
                current: geometry,
                baseline: baselineGeometry
            )
        } else {
            volumeChanges = nil
        }

        // Calculate overall score from available components
        var scores: [Float] = []
        if let cheek = cheekHollowing { scores.append(cheek.score) }
        if let eyes = underEyeBags { scores.append(eyes.score) }
        if let sym = symmetry { scores.append(sym.score) }

        // Need at least one valid component for a score
        guard !scores.isEmpty else {
            AppLogger.metrics.warning("   ❌ VolumeMetrics: No valid components - returning nil")
            return nil
        }

        let overallScore = scores.reduce(0, +) / Float(scores.count)
        AppLogger.metrics.info("   ✅ VolumeMetrics: Overall score = \(String(format: "%.1f", overallScore)) from \(scores.count) components")

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
    ) -> CheekHollowingAnalysis? {
        AppLogger.metrics.info("   🔍 Analyzing cheek hollowing...")

        // Extract cheek regions dynamically (adapts to face shape)
        let leftCheekIndices = getCheekIndices(side: .left, geometry: geometry)
        let rightCheekIndices = getCheekIndices(side: .right, geometry: geometry)

        AppLogger.metrics.debug("      Left cheek: \(leftCheekIndices.count) vertices, Right cheek: \(rightCheekIndices.count) vertices")

        // Calculate volumes - returns nil if insufficient vertices
        guard let leftVolume = calculateRegionVolume(geometry: geometry, indices: leftCheekIndices),
              let rightVolume = calculateRegionVolume(geometry: geometry, indices: rightCheekIndices) else {
            AppLogger.metrics.warning("      ❌ Insufficient cheek vertices for volume calculation")
            return nil
        }

        // Validate we got meaningful volumes (not zeros from bad data)
        guard leftVolume > 0 || rightVolume > 0 else {
            AppLogger.metrics.warning("      ❌ Cheek volumes are zero - insufficient data")
            return nil
        }

        // Average volume
        let avgVolume = (leftVolume + rightVolume) / 2.0

        // Calculate volume score based on relative fullness (not compared to arbitrary ideal)
        // Use baseline comparison if available, otherwise use relative scoring
        let volumeScore: Float
        let volumeLoss: Float
        let severity: HollowingSeverity

        if let baselineGeometry = baseline {
            // Compare to baseline for accurate volume loss calculation
            let baselineLeftIndices = getCheekIndices(side: .left, geometry: baselineGeometry)
            let baselineRightIndices = getCheekIndices(side: .right, geometry: baselineGeometry)

            guard let baselineLeftVolume = calculateRegionVolume(geometry: baselineGeometry, indices: baselineLeftIndices),
                  let baselineRightVolume = calculateRegionVolume(geometry: baselineGeometry, indices: baselineRightIndices) else {
                AppLogger.metrics.warning("      ❌ Insufficient baseline cheek vertices")
                return nil
            }

            let baselineAvgVolume = (baselineLeftVolume + baselineRightVolume) / 2.0

            // Calculate actual volume loss compared to baseline
            volumeLoss = max(0, ((baselineAvgVolume - avgVolume) / max(baselineAvgVolume, 0.001)) * 100)

            // Score based on volume loss (0% loss = 100 score, 50% loss = 50 score)
            volumeScore = max(0, 100 - volumeLoss)

            // Classify severity based on actual loss
            if volumeLoss < 5 {
                severity = .none
            } else if volumeLoss < 15 {
                severity = .mild
            } else if volumeLoss < 30 {
                severity = .moderate
            } else {
                severity = .severe
            }
        } else {
            // No baseline - use relative scoring based on face geometry
            // Calculate relative fullness based on face dimensions
            let faceWidth = calculateFaceWidth(geometry: geometry)
            let expectedVolume = faceWidth * 0.8  // Proportional to face width
            volumeLoss = max(0, ((expectedVolume - avgVolume) / max(expectedVolume, 0.001)) * 100)

            // Validate volume loss is reasonable
            guard volumeLoss >= 0 && volumeLoss < 200 else {
                AppLogger.metrics.warning("      ❌ Invalid volume loss calculation: \(volumeLoss)")
                return nil
            }

            // More lenient scoring without baseline (removed artificial floor)
            volumeScore = max(0, 100 - (volumeLoss * 0.5))

            // More lenient severity classification without baseline
            if volumeLoss < 20 {
                severity = .none
            } else if volumeLoss < 35 {
                severity = .mild
            } else if volumeLoss < 50 {
                severity = .moderate
            } else {
                severity = .severe
            }
        }

        AppLogger.metrics.info("      ✅ Cheek hollowing: score=\(String(format: "%.1f", volumeScore)), severity=\(severity.rawValue)")

        return CheekHollowingAnalysis(
            score: volumeScore,
            severity: severity,
            leftCheekVolume: leftVolume,
            rightCheekVolume: rightVolume,
            volumeLoss: volumeLoss
        )
    }

    // MARK: - Under-Eye Bags Analysis

    private func analyzeUnderEyeBags(geometry: FaceMeshGeometry) -> UnderEyeBagAnalysis? {
        AppLogger.metrics.info("   🔍 Analyzing under-eye bags...")

        // Extract under-eye regions dynamically (adapts to face shape)
        let leftEyeIndices = getUnderEyeIndices(side: .left, geometry: geometry)
        let rightEyeIndices = getUnderEyeIndices(side: .right, geometry: geometry)

        AppLogger.metrics.debug("      Left eye: \(leftEyeIndices.count) vertices, Right eye: \(rightEyeIndices.count) vertices")

        // Need at least some vertices to analyze
        guard !leftEyeIndices.isEmpty || !rightEyeIndices.isEmpty else {
            AppLogger.metrics.warning("      ❌ No under-eye vertices found")
            return nil
        }

        // Calculate protrusion (how much bags stick out)
        let leftProtrusion = calculateProtrusion(geometry: geometry, indices: leftEyeIndices)
        let rightProtrusion = calculateProtrusion(geometry: geometry, indices: rightEyeIndices)

        var avgProtrusion = (leftProtrusion + rightProtrusion) / 2.0

        // DIAGNOSTIC: Log raw protrusion values for debugging
        AppLogger.metrics.debug("      👁️ Under-eye protrusion: left=\(String(format: "%.2f", leftProtrusion * 1000))mm, right=\(String(format: "%.2f", rightProtrusion * 1000))mm, avg=\(String(format: "%.2f", avgProtrusion * 1000))mm")

        // Validate we have meaningful protrusion data (0 = missing data, not "perfect skin")
        guard avgProtrusion > 0 else {
            AppLogger.metrics.warning("      ❌ avgProtrusion = 0, no valid data available")
            return nil
        }

        // SANITY CHECK: Clamp unrealistic protrusion values
        // Human under-eye bags rarely exceed 8mm even in severe cases
        // Values > 10mm likely indicate mesh artifacts or measurement errors
        if avgProtrusion > 0.010 {
            AppLogger.metrics.warning("      ⚠️ Protrusion \(String(format: "%.1f", avgProtrusion * 1000))mm seems unrealistic, clamping to 8mm")
            avgProtrusion = 0.008  // Clamp to 8mm max (still severe)
        }

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

        // Volume (approximate) - use 0 if nil
        let leftVolume = calculateRegionVolume(geometry: geometry, indices: leftEyeIndices) ?? 0
        let rightVolume = calculateRegionVolume(geometry: geometry, indices: rightEyeIndices) ?? 0

        AppLogger.metrics.info("      ✅ Under-eye bags: score=\(String(format: "%.1f", score)), severity=\(severity.rawValue), protrusion=\(String(format: "%.1f", avgProtrusion * 1000))mm")

        return UnderEyeBagAnalysis(
            score: score,
            severity: severity,
            leftEyeVolume: leftVolume,
            rightEyeVolume: rightVolume,
            protrusion: avgProtrusion * 1000  // Convert to mm
        )
    }

    // MARK: - Facial Symmetry Analysis

    private func analyzeFacialSymmetry(geometry: FaceMeshGeometry) -> SymmetryAnalysis? {
        AppLogger.metrics.info("   🔍 Analyzing facial symmetry...")

        let vertices = geometry.vertices

        // Need sufficient vertices for symmetry analysis
        guard vertices.count >= 10 else {
            AppLogger.metrics.warning("      ❌ Insufficient vertices (\(vertices.count)) for symmetry analysis")
            return nil
        }

        // Find center line (midpoint between left/right landmarks)
        let centerX = calculateFaceCenterX(vertices: vertices)

        var leftRightDeviations: [Float] = []
        var asymmetricRegions: Set<FaceRegion> = []

        // Compare left and right sides
        for i in 0..<vertices.count {
            let vertex = vertices[i]
            _ = abs(vertex.x - centerX)  // distanceFromCenter (for reference)

            // Find corresponding point on opposite side
            let mirroredX = centerX - (vertex.x - centerX)
            let mirroredPoint = SIMD3<Float>(mirroredX, vertex.y, vertex.z)

            // Find nearest vertex to mirrored point
            if let nearestIndex = findNearestVertex(to: mirroredPoint, in: vertices) {
                let nearest = vertices[nearestIndex]
                // FIX: Compare mirrored point (expected position) to nearest vertex (actual position)
                // Previously compared vertex to nearest, which measured distance across face (always large!)
                let deviation = distance(mirroredPoint, nearest)
                leftRightDeviations.append(deviation)

                // If deviation > 2mm, mark region as asymmetric
                if deviation > 0.002 {
                    let region = determineRegion(vertex: vertex)
                    asymmetricRegions.insert(region)
                }
            }
        }

        // Need deviations to calculate symmetry
        guard !leftRightDeviations.isEmpty else {
            AppLogger.metrics.warning("      ❌ No deviation data calculated")
            return nil
        }

        // Average deviation
        let avgDeviation = leftRightDeviations.reduce(0, +) / Float(leftRightDeviations.count)

        // Score (less deviation = better symmetry)
        let score = max(0, 100 - (avgDeviation / 0.005 * 100))  // 5mm avg = 0 score

        AppLogger.metrics.info("      ✅ Facial symmetry: score=\(String(format: "%.1f", score)), avgDeviation=\(String(format: "%.2f", avgDeviation * 1000))mm")

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
    ) -> VolumeChanges? {
        AppLogger.metrics.info("   🔍 Calculating volume changes over time...")

        // Calculate total face volume for both
        guard let currentVolume = calculateTotalFaceVolume(geometry: current),
              let baselineVolume = calculateTotalFaceVolume(geometry: baseline),
              baselineVolume > 0 else {
            AppLogger.metrics.warning("      ❌ Cannot calculate total face volume")
            return nil
        }

        let volumeChange = ((currentVolume - baselineVolume) / baselineVolume) * 100

        // Calculate regional volume changes (use 0 if nil for optional regions)
        let currentCheekVolumeLeft = calculateRegionVolume(geometry: current, indices: getCheekIndices(side: .left, geometry: current)) ?? 0
        let baselineCheekVolumeLeft = calculateRegionVolume(geometry: baseline, indices: getCheekIndices(side: .left, geometry: baseline)) ?? 0
        let currentCheekVolumeRight = calculateRegionVolume(geometry: current, indices: getCheekIndices(side: .right, geometry: current)) ?? 0
        let baselineCheekVolumeRight = calculateRegionVolume(geometry: baseline, indices: getCheekIndices(side: .right, geometry: baseline)) ?? 0

        let cheekVolumeChangeLeft = ((currentCheekVolumeLeft - baselineCheekVolumeLeft) / max(baselineCheekVolumeLeft, 0.001)) * 100
        let cheekVolumeChangeRight = ((currentCheekVolumeRight - baselineCheekVolumeRight) / max(baselineCheekVolumeRight, 0.001)) * 100
        let cheekVolumeChange = (cheekVolumeChangeLeft + cheekVolumeChangeRight) / 2.0

        // Calculate under-eye volume changes
        let currentEyeVolumeLeft = calculateRegionVolume(geometry: current, indices: getUnderEyeIndices(side: .left, geometry: current)) ?? 0
        let baselineEyeVolumeLeft = calculateRegionVolume(geometry: baseline, indices: getUnderEyeIndices(side: .left, geometry: baseline)) ?? 0
        let currentEyeVolumeRight = calculateRegionVolume(geometry: current, indices: getUnderEyeIndices(side: .right, geometry: current)) ?? 0
        let baselineEyeVolumeRight = calculateRegionVolume(geometry: baseline, indices: getUnderEyeIndices(side: .right, geometry: baseline)) ?? 0

        let eyeVolumeChangeLeft = ((currentEyeVolumeLeft - baselineEyeVolumeLeft) / max(baselineEyeVolumeLeft, 0.001)) * 100
        let eyeVolumeChangeRight = ((currentEyeVolumeRight - baselineEyeVolumeRight) / max(baselineEyeVolumeRight, 0.001)) * 100
        let eyeVolumeChange = (eyeVolumeChangeLeft + eyeVolumeChangeRight) / 2.0

        // Determine trend based on overall volume
        let trend: VolumeTrend
        if volumeChange > 2 {
            trend = .increasing
        } else if volumeChange < -2 {
            trend = .decreasing
        } else {
            trend = .stable
        }

        AppLogger.metrics.info("      ✅ Volume changes: overall=\(String(format: "%.1f", volumeChange))%, trend=\(trend.rawValue)")

        return VolumeChanges(
            cheekVolumeChange: cheekVolumeChange,
            eyeVolumeChange: eyeVolumeChange,
            overallVolumeChange: volumeChange,
            trend: trend
        )
    }

    // MARK: - Helper Methods

    /// Get cheek region indices dynamically based on vertex positions
    /// This adapts to different face shapes (thin, round, fat, etc.)
    private func getCheekIndices(side: Side, geometry: FaceMeshGeometry) -> [Int] {
        let vertices = geometry.vertices

        // Calculate face bounds
        let centerX = calculateFaceCenterX(vertices: vertices)
        let bounds = calculateFaceBounds(vertices: vertices)

        // Cheek region is in the mid-lower face, offset from center
        let cheekYMin = bounds.minY + (bounds.maxY - bounds.minY) * 0.3  // 30% from bottom
        let cheekYMax = bounds.minY + (bounds.maxY - bounds.minY) * 0.65 // 65% from bottom
        let cheekZMin = bounds.minZ + (bounds.maxZ - bounds.minZ) * 0.2  // Front 20-80% of face
        let cheekZMax = bounds.minZ + (bounds.maxZ - bounds.minZ) * 0.8

        var cheekIndices: [Int] = []

        for (index, vertex) in vertices.enumerated() {
            // Skip extended vertices
            guard index < geometry.originalVertexCount else { break }

            // Check if vertex is in cheek Y range
            guard vertex.y >= cheekYMin && vertex.y <= cheekYMax else { continue }

            // Check if vertex is in cheek Z range (not too far back/forward)
            guard vertex.z >= cheekZMin && vertex.z <= cheekZMax else { continue }

            // Determine left vs right based on X position
            switch side {
            case .left:
                // Left cheek: X < centerX, and offset from center (not too close to nose)
                if vertex.x < centerX && abs(vertex.x - centerX) > 0.02 {
                    cheekIndices.append(index)
                }
            case .right:
                // Right cheek: X > centerX, and offset from center
                if vertex.x > centerX && abs(vertex.x - centerX) > 0.02 {
                    cheekIndices.append(index)
                }
            }
        }

        return cheekIndices
    }

    /// Get under-eye region indices dynamically based on vertex positions
    /// Adapts to different face shapes
    private func getUnderEyeIndices(side: Side, geometry: FaceMeshGeometry) -> [Int] {
        let vertices = geometry.vertices

        // Calculate face bounds
        let centerX = calculateFaceCenterX(vertices: vertices)
        let bounds = calculateFaceBounds(vertices: vertices)

        // Under-eye region is in upper-mid face
        let eyeYMin = bounds.minY + (bounds.maxY - bounds.minY) * 0.55 // 55% from bottom
        let eyeYMax = bounds.minY + (bounds.maxY - bounds.minY) * 0.75 // 75% from bottom
        let eyeZMin = bounds.minZ + (bounds.maxZ - bounds.minZ) * 0.3  // Front 30-90% of face
        let eyeZMax = bounds.minZ + (bounds.maxZ - bounds.minZ) * 0.9

        var eyeIndices: [Int] = []

        for (index, vertex) in vertices.enumerated() {
            // Skip extended vertices
            guard index < geometry.originalVertexCount else { break }

            // Check if vertex is in eye Y range
            guard vertex.y >= eyeYMin && vertex.y <= eyeYMax else { continue }

            // Check if vertex is in eye Z range
            guard vertex.z >= eyeZMin && vertex.z <= eyeZMax else { continue }

            // Determine left vs right based on X position
            switch side {
            case .left:
                // Left eye: X < centerX, offset from center
                if vertex.x < centerX && abs(vertex.x - centerX) > 0.015 && abs(vertex.x - centerX) < 0.06 {
                    eyeIndices.append(index)
                }
            case .right:
                // Right eye: X > centerX, offset from center
                if vertex.x > centerX && abs(vertex.x - centerX) > 0.015 && abs(vertex.x - centerX) < 0.06 {
                    eyeIndices.append(index)
                }
            }
        }

        return eyeIndices
    }

    /// Calculate bounding box of face vertices
    private func calculateFaceBounds(vertices: [SIMD3<Float>]) -> (minX: Float, maxX: Float, minY: Float, maxY: Float, minZ: Float, maxZ: Float) {
        guard let first = vertices.first else {
            return (0, 0, 0, 0, 0, 0)
        }
        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y
        var minZ = first.z, maxZ = first.z

        for vertex in vertices {
            minX = min(minX, vertex.x)
            maxX = max(maxX, vertex.x)
            minY = min(minY, vertex.y)
            maxY = max(maxY, vertex.y)
            minZ = min(minZ, vertex.z)
            maxZ = max(maxZ, vertex.z)
        }

        return (minX, maxX, minY, maxY, minZ, maxZ)
    }
    
    /// Calculate face width for proportional volume estimation
    private func calculateFaceWidth(geometry: FaceMeshGeometry) -> Float {
        let bounds = calculateFaceBounds(vertices: geometry.vertices)
        return bounds.maxX - bounds.minX
    }

    private func calculateRegionVolume(geometry: FaceMeshGeometry, indices: [Int]) -> Float? {
        // Calculate convex hull volume for region using Quickhull algorithm
        let vertices = geometry.vertices
        var regionVertices: [SIMD3<Float>] = []

        for index in indices where index < vertices.count {
            regionVertices.append(vertices[index])
        }

        // Need at least 4 points for 3D convex hull - return nil instead of 0
        guard regionVertices.count >= 4 else {
            AppLogger.metrics.debug("      → Region has <4 vertices (\(regionVertices.count)), cannot calculate volume")
            return nil
        }

        // Compute convex hull using Quickhull
        let convexHull = computeConvexHull3D(points: regionVertices)

        // Check for valid hull
        guard !convexHull.faces.isEmpty else {
            AppLogger.metrics.debug("      → Convex hull has no faces - degenerate geometry")
            return nil
        }

        // Calculate volume from convex hull triangulation
        let volume = calculateConvexHullVolume(hull: convexHull)

        return volume * 1_000_000  // Convert to cm³
    }

    // MARK: - Convex Hull (Quickhull Algorithm)

    private struct ConvexHull {
        let faces: [ConvexFace]
        let vertices: [SIMD3<Float>]
    }

    private struct ConvexFace {
        let v0: Int
        let v1: Int
        let v2: Int
        var normal: SIMD3<Float>
    }

    /// Compute 3D convex hull using Quickhull algorithm
    private func computeConvexHull3D(points: [SIMD3<Float>]) -> ConvexHull {
        guard points.count >= 4 else {
            return ConvexHull(faces: [], vertices: points)
        }

        // Step 1: Find initial tetrahedron (4 extreme points)
        let initialIndices = findInitialTetrahedron(points: points)

        guard initialIndices.count == 4 else {
            // Degenerate case - return empty hull
            return ConvexHull(faces: [], vertices: points)
        }

        // Step 2: Create initial faces
        var faces: [ConvexFace] = [
            createFace(v0: initialIndices[0], v1: initialIndices[1], v2: initialIndices[2], points: points),
            createFace(v0: initialIndices[0], v1: initialIndices[2], v2: initialIndices[3], points: points),
            createFace(v0: initialIndices[0], v1: initialIndices[3], v2: initialIndices[1], points: points),
            createFace(v0: initialIndices[1], v1: initialIndices[3], v2: initialIndices[2], points: points)
        ]

        // Step 3: Assign remaining points to faces
        var unassignedPoints = Set(0..<points.count)
        for index in initialIndices {
            unassignedPoints.remove(index)
        }

        // Simplified: Use bounding box for large point sets (performance optimization)
        if unassignedPoints.count > 100 {
            // For large regions, fall back to simpler calculation
            return ConvexHull(faces: faces, vertices: points)
        }

        // Step 4: Iteratively add points to convex hull
        while !unassignedPoints.isEmpty {
            // Find furthest point from any face
            var maxDistance: Float = 0
            var furthestPoint: Int = -1
            _ = -1  // furthestFace (not needed for expansion)

            for (_, face) in faces.enumerated() {
                for pointIndex in unassignedPoints {
                    let distance = distanceFromFace(point: points[pointIndex], face: face, points: points)
                    if distance > maxDistance {
                        maxDistance = distance
                        furthestPoint = pointIndex
                    }
                }
            }

            guard furthestPoint >= 0, maxDistance > 0.0001 else {
                // All remaining points are inside hull
                break
            }

            // Remove visible faces and create new faces
            faces = expandHull(faces: faces, newPoint: furthestPoint, points: points)
            unassignedPoints.remove(furthestPoint)
        }

        return ConvexHull(faces: faces, vertices: points)
    }

    /// Find 4 points forming initial tetrahedron
    private func findInitialTetrahedron(points: [SIMD3<Float>]) -> [Int] {
        guard points.count >= 4 else { return [] }

        // Find extremes along each axis
        var minX = 0, maxX = 0
        var minY = 0, maxY = 0
        var minZ = 0, maxZ = 0

        for (index, point) in points.enumerated() {
            if point.x < points[minX].x { minX = index }
            if point.x > points[maxX].x { maxX = index }
            if point.y < points[minY].y { minY = index }
            if point.y > points[maxY].y { maxY = index }
            if point.z < points[minZ].z { minZ = index }
            if point.z > points[maxZ].z { maxZ = index }
        }

        // Choose 4 most extreme points
        let extremes = Set([minX, maxX, minY, maxY, minZ, maxZ])
        var selected = Array(extremes.prefix(4))

        // Ensure we have exactly 4 distinct points
        if selected.count < 4 {
            for i in 0..<points.count {
                if !selected.contains(i) {
                    selected.append(i)
                    if selected.count == 4 { break }
                }
            }
        }

        return selected
    }

    /// Create a face with correct normal orientation
    private func createFace(v0: Int, v1: Int, v2: Int, points: [SIMD3<Float>]) -> ConvexFace {
        let p0 = points[v0]
        let p1 = points[v1]
        let p2 = points[v2]

        let edge1 = p1 - p0
        let edge2 = p2 - p0
        let normal = normalize(cross(edge1, edge2))

        return ConvexFace(v0: v0, v1: v1, v2: v2, normal: normal)
    }

    /// Calculate distance from point to face
    private func distanceFromFace(point: SIMD3<Float>, face: ConvexFace, points: [SIMD3<Float>]) -> Float {
        let facePoint = points[face.v0]
        let toPoint = point - facePoint
        return dot(toPoint, face.normal)
    }

    /// Expand hull by adding new point
    private func expandHull(faces: [ConvexFace], newPoint: Int, points: [SIMD3<Float>]) -> [ConvexFace] {
        // Step 1: Find all faces visible from the new point
        var visibleFaces = Set<Int>()

        for (index, face) in faces.enumerated() {
            let distance = distanceFromFace(point: points[newPoint], face: face, points: points)
            if distance > 0.0001 {  // Face is visible from point
                visibleFaces.insert(index)
            }
        }

        guard !visibleFaces.isEmpty else {
            // Point is inside hull, no expansion needed
            return faces
        }

        // Step 2: Find horizon edges (edges between visible and non-visible faces)
        var horizonEdges: [(Int, Int)] = []
        var edgeFaceCount: [[Int]: Int] = [:]  // edge -> count of adjacent faces

        for face in faces {
            let edges = [
                [face.v0, face.v1].sorted(),
                [face.v1, face.v2].sorted(),
                [face.v2, face.v0].sorted()
            ]

            for edge in edges {
                edgeFaceCount[edge, default: 0] += 1
            }
        }

        // Horizon edges are those on the boundary of visible region
        for visibleIndex in visibleFaces {
            let face = faces[visibleIndex]
            let edges = [
                (face.v0, face.v1),
                (face.v1, face.v2),
                (face.v2, face.v0)
            ]

            for edge in edges {
                let sortedEdge = [edge.0, edge.1].sorted()

                // Check if this edge is shared with a non-visible face
                var isHorizon = false
                for (otherIndex, otherFace) in faces.enumerated() {
                    if visibleFaces.contains(otherIndex) { continue }

                    let otherEdges = [
                        [otherFace.v0, otherFace.v1].sorted(),
                        [otherFace.v1, otherFace.v2].sorted(),
                        [otherFace.v2, otherFace.v0].sorted()
                    ]

                    if otherEdges.contains(sortedEdge) {
                        isHorizon = true
                        break
                    }
                }

                if isHorizon {
                    horizonEdges.append(edge)
                }
            }
        }

        // Step 3: Remove visible faces
        var newFaces: [ConvexFace] = []
        for (index, face) in faces.enumerated() {
            if !visibleFaces.contains(index) {
                newFaces.append(face)
            }
        }

        // Step 4: Create new faces from horizon edges to new point
        for edge in horizonEdges {
            let newFace = createFace(v0: edge.0, v1: edge.1, v2: newPoint, points: points)

            // Ensure normal points outward (away from hull center)
            let center = calculateHullCenter(faces: newFaces, points: points)
            let faceCenter = (points[newFace.v0] + points[newFace.v1] + points[newFace.v2]) / 3.0
            let toFace = faceCenter - center

            if dot(toFace, newFace.normal) > 0 {
                // Normal already points outward
                newFaces.append(newFace)
            } else {
                // Flip face orientation
                newFaces.append(createFace(v0: edge.1, v1: edge.0, v2: newPoint, points: points))
            }
        }

        return newFaces
    }

    /// Calculate center of convex hull
    private func calculateHullCenter(faces: [ConvexFace], points: [SIMD3<Float>]) -> SIMD3<Float> {
        guard !faces.isEmpty else { return SIMD3<Float>(0, 0, 0) }

        var vertexIndices = Set<Int>()
        for face in faces {
            vertexIndices.insert(face.v0)
            vertexIndices.insert(face.v1)
            vertexIndices.insert(face.v2)
        }

        var sum = SIMD3<Float>(0, 0, 0)
        for index in vertexIndices {
            sum += points[index]
        }

        return sum / Float(vertexIndices.count)
    }

    /// Calculate volume of convex hull
    private func calculateConvexHullVolume(hull: ConvexHull) -> Float {
        guard !hull.faces.isEmpty else { return 0 }

        var totalVolume: Float = 0
        let origin = SIMD3<Float>(0, 0, 0)

        for face in hull.faces {
            let p0 = hull.vertices[face.v0]
            let p1 = hull.vertices[face.v1]
            let p2 = hull.vertices[face.v2]

            // Volume of tetrahedron formed by origin and face
            let v1 = p0 - origin
            let v2 = p1 - origin
            let v3 = p2 - origin

            // Volume = 1/6 * |v1 · (v2 × v3)|
            let tetrahedronVolume = abs(dot(v1, cross(v2, v3))) / 6.0
            totalVolume += tetrahedronVolume
        }

        return totalVolume
    }

    private func calculateProtrusion(geometry: FaceMeshGeometry, indices: [Int]) -> Float {
        // Measure how much the under-eye region protrudes relative to surrounding face surface
        // NOT absolute Z distance from origin (which would give ~40mm for face at 40mm from camera)
        let vertices = geometry.vertices

        guard !indices.isEmpty else { return 0 }

        // STEP 1: Calculate the reference plane from surrounding cheek vertices
        // The reference plane represents the "flat" face surface around the under-eye area
        let centerX = calculateFaceCenterX(vertices: vertices)

        // FIX: Get face bounds to constrain reference vertices to front of face
        let faceBounds = calculateFaceBounds(vertices: vertices)
        let frontZ = faceBounds.maxZ  // Most forward point
        let zTolerance: Float = 0.015  // 15mm tolerance - only use front face vertices

        // Find neighboring cheek vertices (same Y range but outside under-eye X range)
        var referenceZValues: [Float] = []
        let underEyeMinX = indices.compactMap { $0 < vertices.count ? vertices[$0].x : nil }.min() ?? centerX
        let underEyeMaxX = indices.compactMap { $0 < vertices.count ? vertices[$0].x : nil }.max() ?? centerX
        let underEyeMinY = indices.compactMap { $0 < vertices.count ? vertices[$0].y : nil }.min() ?? 0
        let underEyeMaxY = indices.compactMap { $0 < vertices.count ? vertices[$0].y : nil }.max() ?? 0

        for (idx, vertex) in vertices.enumerated() {
            guard idx < geometry.originalVertexCount else { break }

            // Same Y range as under-eye
            guard vertex.y >= underEyeMinY - 0.01 && vertex.y <= underEyeMaxY + 0.01 else { continue }

            // FIX: Constrain to front of face (within 15mm of most forward point)
            // This prevents including side/back of face vertices that cause 100mm+ Z ranges
            guard vertex.z >= frontZ - zTolerance else { continue }

            // Outside under-eye X range (cheek area)
            let isLeftCheek = vertex.x < underEyeMinX - 0.005
            let isRightCheek = vertex.x > underEyeMaxX + 0.005

            if isLeftCheek || isRightCheek {
                referenceZValues.append(vertex.z)
            }
        }

        // If no reference points found, use the face plane Z at similar Y position
        if referenceZValues.isEmpty {
            // Fallback: use vertices at similar Y position but further from center
            let avgY = indices.compactMap { $0 < vertices.count ? vertices[$0].y : nil }.reduce(0, +) / Float(indices.count)
            for (idx, vertex) in vertices.enumerated() {
                guard idx < geometry.originalVertexCount else { break }
                // FIX: Also apply Z constraint in fallback
                guard vertex.z >= frontZ - zTolerance else { continue }
                if abs(vertex.y - avgY) < 0.015 && abs(vertex.x - centerX) > 0.04 {
                    referenceZValues.append(vertex.z)
                }
            }

            // Still no reference? Return healthy default (assume no bags)
            guard !referenceZValues.isEmpty else {
                AppLogger.metrics.debug("      ℹ️ No reference vertices found - assuming healthy (0.5mm)")
                return 0.0005
            }
        }

        // STEP 2: Calculate reference Z using IQR-based outlier rejection
        let sortedReferenceZ = referenceZValues.sorted()

        // FIX: Use IQR to reject outliers (Q1-1.5*IQR to Q3+1.5*IQR)
        let referenceZ: Float
        if sortedReferenceZ.count >= 4 {
            let q1Index = sortedReferenceZ.count / 4
            let q3Index = (sortedReferenceZ.count * 3) / 4
            let q1 = sortedReferenceZ[q1Index]
            let q3 = sortedReferenceZ[q3Index]
            let iqr = q3 - q1
            let lowerBound = q1 - 1.5 * iqr
            let upperBound = q3 + 1.5 * iqr

            let filteredZ = sortedReferenceZ.filter { $0 >= lowerBound && $0 <= upperBound }
            if filteredZ.isEmpty {
                // All outliers? Use median
                referenceZ = sortedReferenceZ[sortedReferenceZ.count / 2]
            } else {
                referenceZ = filteredZ.reduce(0, +) / Float(filteredZ.count)
            }

            AppLogger.metrics.debug("      📊 IQR filtering: Q1=\(String(format: "%.3f", q1)), Q3=\(String(format: "%.3f", q3)), kept \(filteredZ.count)/\(sortedReferenceZ.count) samples")
        } else if sortedReferenceZ.count >= 1 {
            // Small sample - use median
            referenceZ = sortedReferenceZ[sortedReferenceZ.count / 2]
        } else {
            referenceZ = 0
        }

        // VALIDATION: Check reference Z range is reasonable
        let zRange = (sortedReferenceZ.last ?? 0) - (sortedReferenceZ.first ?? 0)
        if zRange > 0.020 {  // >20mm range = still unreliable even after filtering
            AppLogger.metrics.warning("      ❌ Reference Z range still too large (\(String(format: "%.1f", zRange * 1000))mm) after filtering - assuming healthy")
            return 0.0005  // 0.5mm = healthy default
        }

        // STEP 3: Calculate under-eye Z values and measure protrusion relative to reference
        var protrusionValues: [Float] = []

        for index in indices where index < vertices.count {
            let vertex = vertices[index]
            // Protrusion = how much further the under-eye vertex sticks out vs reference plane
            // Positive = protrudes outward (toward camera), which is what bags do
            // In ARKit, camera faces -Z, so bags protruding toward camera have LARGER Z (less negative)
            let protrusion = vertex.z - referenceZ

            // Only count forward protrusion (bags stick out, not in)
            if protrusion > 0 {
                protrusionValues.append(protrusion)
            }
        }

        // If no protrusion detected, return minimal value (flat under-eye = good!)
        guard !protrusionValues.isEmpty else { return 0.0005 }  // 0.5mm minimal

        // STEP 4: Return average protrusion (in meters, will be converted to mm later)
        let avgProtrusion = protrusionValues.reduce(0, +) / Float(protrusionValues.count)

        // DIAGNOSTIC: Log the calculation for debugging
        AppLogger.metrics.debug("      🔍 Protrusion calc: referenceZ=\(String(format: "%.4f", referenceZ)), samples=\(referenceZValues.count), avgProtrusion=\(String(format: "%.4f", avgProtrusion * 1000))mm")

        return avgProtrusion
    }

    private func calculateTotalFaceVolume(geometry: FaceMeshGeometry) -> Float? {
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
