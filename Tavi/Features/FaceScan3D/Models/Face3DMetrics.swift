//
//  Face3DMetrics.swift
//  Tavi
//
//  3D skin metrics computed from unified mesh and albedo texture
//  Created on 2025-10-27.
//

import Foundation
import UIKit
import CoreGraphics
import simd

// MARK: - Face ROI Definition

/// Face region of interest for 3D scanning (UV-based)
/// Note: Renamed from Face3DROI to Face3DROI to avoid conflict with 2D Face3DROI struct
public enum Face3DROI: String, CaseIterable, Codable {
    case forehead = "Forehead"
    case leftCheek = "LeftCheek"
    case rightCheek = "RightCheek"
    case noseBridge = "NoseBridge"
    case chin = "Chin"

    /// Display name
    public var displayName: String {
        return rawValue
    }

    /// Canonical UV bounds for this ROI (approximate)
    /// Based on ARSCNFaceGeometry canonical UV layout
    public var uvBounds: UVBounds {
        switch self {
        case .forehead:
            return UVBounds(minU: 0.3, maxU: 0.7, minV: 0.7, maxV: 0.95)
        case .leftCheek:
            return UVBounds(minU: 0.15, maxU: 0.45, minV: 0.35, maxV: 0.65)
        case .rightCheek:
            return UVBounds(minU: 0.55, maxU: 0.85, minV: 0.35, maxV: 0.65)
        case .noseBridge:
            return UVBounds(minU: 0.4, maxU: 0.6, minV: 0.45, maxV: 0.7)
        case .chin:
            return UVBounds(minU: 0.35, maxU: 0.65, minV: 0.1, maxV: 0.35)
        }
    }
}

/// UV coordinate bounds for ROI
public struct UVBounds: Codable {
    public let minU: Float
    public let maxU: Float
    public let minV: Float
    public let maxV: Float

    public init(minU: Float, maxU: Float, minV: Float, maxV: Float) {
        self.minU = minU
        self.maxU = maxU
        self.minV = minV
        self.maxV = maxV
    }

    /// Check if UV coordinate is within bounds
    public func contains(u: Float, v: Float) -> Bool {
        return u >= minU && u <= maxU && v >= minV && v <= maxV
    }

    /// Check if UV coordinate is within bounds
    public func contains(_ uv: SIMD2<Float>) -> Bool {
        return contains(u: uv.x, v: uv.y)
    }
}

// MARK: - UV Mask

/// Binary mask for a face ROI in UV space
public struct UIMask {
    /// ROI this mask represents
    public let roi: Face3DROI

    /// Vertex indices that belong to this ROI
    public let vertexIndices: [Int]

    /// Triangle indices that belong to this ROI
    public let triangleIndices: [Int]

    /// UV bounds
    public let bounds: UVBounds

    /// Pixel mask in texture space (2D binary array)
    /// true = inside ROI, false = outside
    public let pixelMask: [[Bool]]

    /// Texture resolution
    public let textureWidth: Int
    public let textureHeight: Int

    public init(
        roi: Face3DROI,
        vertexIndices: [Int],
        triangleIndices: [Int],
        bounds: UVBounds,
        pixelMask: [[Bool]],
        textureWidth: Int,
        textureHeight: Int
    ) {
        self.roi = roi
        self.vertexIndices = vertexIndices
        self.triangleIndices = triangleIndices
        self.bounds = bounds
        self.pixelMask = pixelMask
        self.textureWidth = textureWidth
        self.textureHeight = textureHeight
    }
}

// MARK: - ROI Texture Sample

/// Texture data sampled from an ROI
public struct ROITextureSample {
    /// ROI this sample is from
    public let roi: Face3DROI

    /// Pixel colors (RGB) within the ROI
    public let pixels: [SIMD3<Float>]

    /// UV coordinates of sampled pixels
    public let uvCoordinates: [SIMD2<Float>]

    /// Sample dimensions
    public let width: Int
    public let height: Int

    /// Number of valid pixels
    public var pixelCount: Int {
        return pixels.count
    }

    public init(
        roi: Face3DROI,
        pixels: [SIMD3<Float>],
        uvCoordinates: [SIMD2<Float>],
        width: Int,
        height: Int
    ) {
        self.roi = roi
        self.pixels = pixels
        self.uvCoordinates = uvCoordinates
        self.width = width
        self.height = height
    }
}

// MARK: - ROI Metrics

/// Computed metrics for a single ROI
public struct ROI3DMetrics: Codable {
    /// ROI identifier
    public let roi: Face3DROI

    // Raw metric values (0-1 range)

    /// Roughness proxy (0-1, higher = rougher texture)
    public let roughnessProxy: Float

    /// Pigmentation variance index (0-1, higher = more variation)
    public let pigmentationIndex: Float

    /// Specular/oiliness proxy (0-1, higher = more specular highlights)
    public let specularProxy: Float?

    /// Number of pixels analyzed
    public let pixelCount: Int

    /// Average luminance (0-1)
    public let averageLuminance: Float

    /// Average CIELAB L* value (0-100)
    public let averageLightness: Float

    /// Average CIELAB A* value (green-red axis)
    public let averageAChannel: Float

    /// Average CIELAB B* value (blue-yellow axis)
    public let averageBChannel: Float

    // Scores (0-100 percentage, higher = better skin quality)

    /// Roughness score (0-100%, higher = smoother skin)
    public let roughnessScore: Float

    /// Pigmentation score (0-100%, higher = more even pigmentation)
    public let pigmentationScore: Float

    /// Specular score (0-100%, higher = less oily)
    public let specularScore: Float?

    // Quality flags

    /// Whether this ROI has sufficient data for reliable metrics
    public let isLowConfidence: Bool

    /// Confidence level for this ROI
    public let confidenceLevel: String

    public init(
        roi: Face3DROI,
        roughnessProxy: Float,
        pigmentationIndex: Float,
        specularProxy: Float?,
        pixelCount: Int,
        averageLuminance: Float,
        averageLightness: Float,
        averageAChannel: Float,
        averageBChannel: Float,
        roughnessScore: Float,
        pigmentationScore: Float,
        specularScore: Float?,
        isLowConfidence: Bool = false,
        confidenceLevel: String = "High"
    ) {
        self.roi = roi
        self.roughnessProxy = roughnessProxy
        self.pigmentationIndex = pigmentationIndex
        self.specularProxy = specularProxy
        self.pixelCount = pixelCount
        self.averageLuminance = averageLuminance
        self.averageLightness = averageLightness
        self.averageAChannel = averageAChannel
        self.averageBChannel = averageBChannel
        self.roughnessScore = roughnessScore
        self.pigmentationScore = pigmentationScore
        self.specularScore = specularScore
        self.isLowConfidence = isLowConfidence
        self.confidenceLevel = confidenceLevel
    }
}

// MARK: - Face 3D Metrics

/// Complete 3D face metrics computed from mesh and texture
public struct Face3DMetrics: Codable {
    /// Metrics per ROI
    public let roiMetrics: [Face3DROI: ROI3DMetrics]

    // Global raw metrics (0-1 range)

    /// Global roughness proxy (weighted by pixel count)
    public let globalRoughnessProxy: Float

    /// Global pigmentation variance index (weighted by pixel count)
    public let globalPigmentationIndex: Float

    /// Global discoloration index (inter-ROI variance)
    public let globalDiscolorationIndex: Float

    /// Global specular/oiliness proxy (weighted by pixel count)
    public let globalSpecularProxy: Float?

    /// Global average luminance
    public let globalAverageLuminance: Float

    // Global scores (0-100 percentage, higher = better)

    /// Global roughness score (0-100%, higher = smoother)
    public let globalRoughnessScore: Float

    /// Global pigmentation score (0-100%, higher = more even)
    public let globalPigmentationScore: Float

    /// Global discoloration score (0-100%, higher = more uniform across face)
    public let globalDiscolorationScore: Float

    /// Global specular score (0-100%, higher = less oily)
    public let globalSpecularScore: Float?

    /// Overall skin quality score (0-100%, weighted composite)
    public let overallScore: Float

    /// Score interpretation ("Excellent", "Good", etc.)
    public let scoreInterpretation: String

    /// Mesh statistics
    public let vertexCount: Int
    public let triangleCount: Int
    public let textureResolution: CGSize

    /// Processing metadata
    public let timestamp: TimeInterval
    public let processingTime: TimeInterval

    /// Quality validation
    public let textureQuality: String?  // "Good quality" or warning message
    public let lowConfidenceROIs: [Face3DROI]  // ROIs excluded from global metrics
    public let isHighQuality: Bool  // Overall quality flag

    // NEW: Advanced metrics

    /// Skin elasticity analysis (requires historical scans)
    public let elasticityAnalysis: ElasticityAnalysis?

    /// Volume-based aging metrics (cheek hollowing, under-eye bags, symmetry)
    public let volumeAnalysis: VolumeAnalysis?

    /// Regional analysis (under-eye, lips, nose, jawline)
    public let regionalAnalysis: RegionalAnalysis?

    /// Skin type classification
    public let skinTypeAnalysis: SkinTypeAnalysis?

    public init(
        roiMetrics: [Face3DROI: ROI3DMetrics],
        globalRoughnessProxy: Float,
        globalPigmentationIndex: Float,
        globalDiscolorationIndex: Float,
        globalSpecularProxy: Float?,
        globalAverageLuminance: Float,
        globalRoughnessScore: Float,
        globalPigmentationScore: Float,
        globalDiscolorationScore: Float,
        globalSpecularScore: Float?,
        overallScore: Float,
        scoreInterpretation: String,
        vertexCount: Int,
        triangleCount: Int,
        textureResolution: CGSize,
        processingTime: TimeInterval,
        textureQuality: String? = nil,
        lowConfidenceROIs: [Face3DROI] = [],
        isHighQuality: Bool = true,
        elasticityAnalysis: ElasticityAnalysis? = nil,
        volumeAnalysis: VolumeAnalysis? = nil,
        regionalAnalysis: RegionalAnalysis? = nil,
        skinTypeAnalysis: SkinTypeAnalysis? = nil
    ) {
        self.roiMetrics = roiMetrics
        self.globalRoughnessProxy = globalRoughnessProxy
        self.globalPigmentationIndex = globalPigmentationIndex
        self.globalDiscolorationIndex = globalDiscolorationIndex
        self.globalSpecularProxy = globalSpecularProxy
        self.globalAverageLuminance = globalAverageLuminance
        self.globalRoughnessScore = globalRoughnessScore
        self.globalPigmentationScore = globalPigmentationScore
        self.globalDiscolorationScore = globalDiscolorationScore
        self.globalSpecularScore = globalSpecularScore
        self.overallScore = overallScore
        self.scoreInterpretation = scoreInterpretation
        self.vertexCount = vertexCount
        self.triangleCount = triangleCount
        self.textureResolution = textureResolution
        self.timestamp = Date().timeIntervalSince1970
        self.processingTime = processingTime
        self.textureQuality = textureQuality
        self.lowConfidenceROIs = lowConfidenceROIs
        self.isHighQuality = isHighQuality
        self.elasticityAnalysis = elasticityAnalysis
        self.volumeAnalysis = volumeAnalysis
        self.regionalAnalysis = regionalAnalysis
        self.skinTypeAnalysis = skinTypeAnalysis
    }

    /// Get metrics for specific ROI
    public func metrics(for roi: Face3DROI) -> ROI3DMetrics? {
        return roiMetrics[roi]
    }

    /// Get all ROI metrics sorted by ROI name
    public var sortedROI3DMetrics: [(Face3DROI, ROI3DMetrics)] {
        return roiMetrics.sorted { $0.key.rawValue < $1.key.rawValue }
    }

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case roiMetrics, globalRoughnessProxy, globalPigmentationIndex
        case globalDiscolorationIndex, globalSpecularProxy, globalAverageLuminance
        case globalRoughnessScore, globalPigmentationScore, globalDiscolorationScore
        case globalSpecularScore, overallScore, scoreInterpretation
        case vertexCount, triangleCount, textureWidth, textureHeight
        case timestamp, processingTime, textureQuality, lowConfidenceROIs, isHighQuality
        case elasticityAnalysis, volumeAnalysis, regionalAnalysis, skinTypeAnalysis
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        roiMetrics = try container.decode([Face3DROI: ROI3DMetrics].self, forKey: .roiMetrics)
        globalRoughnessProxy = try container.decode(Float.self, forKey: .globalRoughnessProxy)
        globalPigmentationIndex = try container.decode(Float.self, forKey: .globalPigmentationIndex)
        globalDiscolorationIndex = try container.decode(Float.self, forKey: .globalDiscolorationIndex)
        globalSpecularProxy = try container.decodeIfPresent(Float.self, forKey: .globalSpecularProxy)
        globalAverageLuminance = try container.decode(Float.self, forKey: .globalAverageLuminance)
        globalRoughnessScore = try container.decode(Float.self, forKey: .globalRoughnessScore)
        globalPigmentationScore = try container.decode(Float.self, forKey: .globalPigmentationScore)
        globalDiscolorationScore = try container.decode(Float.self, forKey: .globalDiscolorationScore)
        globalSpecularScore = try container.decodeIfPresent(Float.self, forKey: .globalSpecularScore)
        overallScore = try container.decode(Float.self, forKey: .overallScore)
        scoreInterpretation = try container.decode(String.self, forKey: .scoreInterpretation)
        vertexCount = try container.decode(Int.self, forKey: .vertexCount)
        triangleCount = try container.decode(Int.self, forKey: .triangleCount)

        let width = try container.decode(CGFloat.self, forKey: .textureWidth)
        let height = try container.decode(CGFloat.self, forKey: .textureHeight)
        textureResolution = CGSize(width: width, height: height)

        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        processingTime = try container.decode(TimeInterval.self, forKey: .processingTime)
        textureQuality = try container.decodeIfPresent(String.self, forKey: .textureQuality)
        lowConfidenceROIs = try container.decode([Face3DROI].self, forKey: .lowConfidenceROIs)
        isHighQuality = try container.decode(Bool.self, forKey: .isHighQuality)
        elasticityAnalysis = try container.decodeIfPresent(ElasticityAnalysis.self, forKey: .elasticityAnalysis)
        volumeAnalysis = try container.decodeIfPresent(VolumeAnalysis.self, forKey: .volumeAnalysis)
        regionalAnalysis = try container.decodeIfPresent(RegionalAnalysis.self, forKey: .regionalAnalysis)
        skinTypeAnalysis = try container.decodeIfPresent(SkinTypeAnalysis.self, forKey: .skinTypeAnalysis)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(roiMetrics, forKey: .roiMetrics)
        try container.encode(globalRoughnessProxy, forKey: .globalRoughnessProxy)
        try container.encode(globalPigmentationIndex, forKey: .globalPigmentationIndex)
        try container.encode(globalDiscolorationIndex, forKey: .globalDiscolorationIndex)
        try container.encodeIfPresent(globalSpecularProxy, forKey: .globalSpecularProxy)
        try container.encode(globalAverageLuminance, forKey: .globalAverageLuminance)
        try container.encode(globalRoughnessScore, forKey: .globalRoughnessScore)
        try container.encode(globalPigmentationScore, forKey: .globalPigmentationScore)
        try container.encode(globalDiscolorationScore, forKey: .globalDiscolorationScore)
        try container.encodeIfPresent(globalSpecularScore, forKey: .globalSpecularScore)
        try container.encode(overallScore, forKey: .overallScore)
        try container.encode(scoreInterpretation, forKey: .scoreInterpretation)
        try container.encode(vertexCount, forKey: .vertexCount)
        try container.encode(triangleCount, forKey: .triangleCount)
        try container.encode(textureResolution.width, forKey: .textureWidth)
        try container.encode(textureResolution.height, forKey: .textureHeight)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(processingTime, forKey: .processingTime)
        try container.encodeIfPresent(textureQuality, forKey: .textureQuality)
        try container.encode(lowConfidenceROIs, forKey: .lowConfidenceROIs)
        try container.encode(isHighQuality, forKey: .isHighQuality)
        try container.encodeIfPresent(elasticityAnalysis, forKey: .elasticityAnalysis)
        try container.encodeIfPresent(volumeAnalysis, forKey: .volumeAnalysis)
        try container.encodeIfPresent(regionalAnalysis, forKey: .regionalAnalysis)
        try container.encodeIfPresent(skinTypeAnalysis, forKey: .skinTypeAnalysis)
    }
}

// MARK: - Metric Visualization

/// Visualization data for metric overlays
public struct MetricVisualization {
    /// Heatmap image (color-coded metric values)
    public let heatmapImage: UIImage?

    /// ROI boundary overlays
    public let roiBoundaries: [Face3DROI: UIBezierPath]

    /// Legend colors for metric ranges
    public let legendColors: [Float: UIColor]

    public init(
        heatmapImage: UIImage?,
        roiBoundaries: [Face3DROI: UIBezierPath],
        legendColors: [Float: UIColor]
    ) {
        self.heatmapImage = heatmapImage
        self.roiBoundaries = roiBoundaries
        self.legendColors = legendColors
    }
}
