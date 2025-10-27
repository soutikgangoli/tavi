//
//  TextureModels.swift
//  Tavi
//
//  Data structures for texture capture and baking
//  Created on 2025-10-27.
//

import Foundation
import UIKit
import CoreGraphics
import simd

// MARK: - Pose Sample

/// Single texture sample captured at a specific pose
public struct PoseSample: Codable {
    /// Unique identifier
    public let id: UUID

    /// Guidance step this sample was captured at
    public let step: String

    /// High-resolution RGB texture frame (stored as PNG data)
    public let textureImageData: Data

    /// Original image dimensions
    public let imageWidth: Int
    public let imageHeight: Int

    /// Face anchor transform at capture time
    public let faceTransform: Matrix4x4

    /// Head rotation angles
    public let yaw, pitch, roll: Float

    /// Ambient light intensity (lumens)
    public let ambientIntensity: CGFloat

    /// Color temperature (Kelvin)
    public let colorTemperature: CGFloat

    /// Estimated light direction (normalized)
    public let lightDirection: Vector3?

    /// Distance from camera (meters)
    public let distanceFromCamera: Float

    /// Quality metrics
    public let focusSharpness: Float  // Laplacian variance
    public let exposureScore: Float   // 0-1, 0.5 = ideal
    public let isFrontFacing: Bool    // |yaw| < 15° && |pitch| < 10°

    /// Timestamp
    public let timestamp: TimeInterval

    public init(
        step: String,
        textureImage: UIImage,
        faceTransform: simd_float4x4,
        yaw: Float,
        pitch: Float,
        roll: Float,
        ambientIntensity: CGFloat,
        colorTemperature: CGFloat,
        lightDirection: SIMD3<Float>?,
        distanceFromCamera: Float,
        focusSharpness: Float,
        exposureScore: Float,
        isFrontFacing: Bool
    ) {
        self.id = UUID()
        self.step = step
        self.textureImageData = textureImage.pngData() ?? Data()
        self.imageWidth = Int(textureImage.size.width)
        self.imageHeight = Int(textureImage.size.height)
        self.faceTransform = Matrix4x4(faceTransform)
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
        self.ambientIntensity = ambientIntensity
        self.colorTemperature = colorTemperature
        self.lightDirection = lightDirection.map { Vector3($0) }
        self.distanceFromCamera = distanceFromCamera
        self.focusSharpness = focusSharpness
        self.exposureScore = exposureScore
        self.isFrontFacing = isFrontFacing
        self.timestamp = Date().timeIntervalSince1970
    }

    /// Reconstruct UIImage from stored data
    public func getImage() -> UIImage? {
        return UIImage(data: textureImageData)
    }
}

// MARK: - Texture Bake Result

/// Result of unified texture baking process
public struct TextureBakeResult {
    /// Unified mesh with canonical UV coordinates
    public let unifiedMesh: UnifiedMesh

    /// Baked albedo texture (lighting-minimized)
    public let albedoTexture: CGImage

    /// Texture resolution
    public let textureWidth: Int
    public let textureHeight: Int

    /// Number of pose samples used
    public let sampleCount: Int

    /// Quality metrics
    public let averageSharpness: Float
    public let coveragePercentage: Float  // % of UV space filled

    /// Processing metadata
    public let processingTime: TimeInterval
    public let timestamp: TimeInterval

    public init(
        unifiedMesh: UnifiedMesh,
        albedoTexture: CGImage,
        sampleCount: Int,
        averageSharpness: Float,
        coveragePercentage: Float,
        processingTime: TimeInterval
    ) {
        self.unifiedMesh = unifiedMesh
        self.albedoTexture = albedoTexture
        self.textureWidth = albedoTexture.width
        self.textureHeight = albedoTexture.height
        self.sampleCount = sampleCount
        self.averageSharpness = averageSharpness
        self.coveragePercentage = coveragePercentage
        self.processingTime = processingTime
        self.timestamp = Date().timeIntervalSince1970
    }
}

// MARK: - Unified Mesh

/// Unified mesh with texture coordinates
public struct UnifiedMesh: Codable {
    /// 3D vertex positions
    public let vertices: [Vector3]

    /// Per-vertex normals
    public let normals: [Vector3]

    /// Canonical UV texture coordinates (0-1 range)
    public let textureCoordinates: [Vector2]

    /// Triangle indices (groups of 3)
    public let triangleIndices: [Int32]

    /// Source mesh count
    public let sourceCount: Int

    /// Bounding box
    public let boundingBox: BoundingBox

    public init(
        vertices: [Vector3],
        normals: [Vector3],
        textureCoordinates: [Vector2],
        triangleIndices: [Int32],
        sourceCount: Int,
        boundingBox: BoundingBox
    ) {
        self.vertices = vertices
        self.normals = normals
        self.textureCoordinates = textureCoordinates
        self.triangleIndices = triangleIndices
        self.sourceCount = sourceCount
        self.boundingBox = boundingBox
    }

    public var vertexCount: Int { vertices.count }
    public var triangleCount: Int { triangleIndices.count / 3 }
}

// MARK: - Face Scan Metadata

/// Complete metadata for face scan export
public struct FaceScanMetadata: Codable {
    /// Scan identification
    public let scanId: UUID
    public let timestamp: TimeInterval

    /// Device information
    public let deviceModel: String
    public let iOSVersion: String
    public let hasTrueDepth: Bool

    /// Capture information
    public let totalPoses: Int
    public let captureSteps: [String]
    public let totalDuration: TimeInterval?

    /// Head pose transforms for each capture
    public let headTransforms: [Matrix4x4]

    /// Lighting statistics
    public let minAmbientIntensity: CGFloat
    public let maxAmbientIntensity: CGFloat
    public let avgAmbientIntensity: CGFloat
    public let avgColorTemperature: CGFloat

    /// Distance statistics (meters)
    public let minDistance: Float
    public let maxDistance: Float
    public let avgDistance: Float

    /// Calibration flags
    public let calibrationPassed: Bool
    public let lightingCondition: String  // "good", "tooDark", "tooBright"
    public let distanceCondition: String  // "good", "tooClose", "tooFar"

    /// Quality metrics
    public let avgFocusSharpness: Float
    public let avgExposureScore: Float
    public let textureCoverage: Float  // % of UV space

    /// Processing info
    public let processingTime: TimeInterval

    public init(
        scanId: UUID = UUID(),
        deviceModel: String,
        iOSVersion: String,
        hasTrueDepth: Bool,
        totalPoses: Int,
        captureSteps: [String],
        totalDuration: TimeInterval?,
        headTransforms: [Matrix4x4],
        minAmbientIntensity: CGFloat,
        maxAmbientIntensity: CGFloat,
        avgAmbientIntensity: CGFloat,
        avgColorTemperature: CGFloat,
        minDistance: Float,
        maxDistance: Float,
        avgDistance: Float,
        calibrationPassed: Bool,
        lightingCondition: String,
        distanceCondition: String,
        avgFocusSharpness: Float,
        avgExposureScore: Float,
        textureCoverage: Float,
        processingTime: TimeInterval
    ) {
        self.scanId = scanId
        self.timestamp = Date().timeIntervalSince1970
        self.deviceModel = deviceModel
        self.iOSVersion = iOSVersion
        self.hasTrueDepth = hasTrueDepth
        self.totalPoses = totalPoses
        self.captureSteps = captureSteps
        self.totalDuration = totalDuration
        self.headTransforms = headTransforms
        self.minAmbientIntensity = minAmbientIntensity
        self.maxAmbientIntensity = maxAmbientIntensity
        self.avgAmbientIntensity = avgAmbientIntensity
        self.avgColorTemperature = avgColorTemperature
        self.minDistance = minDistance
        self.maxDistance = maxDistance
        self.avgDistance = avgDistance
        self.calibrationPassed = calibrationPassed
        self.lightingCondition = lightingCondition
        self.distanceCondition = distanceCondition
        self.avgFocusSharpness = avgFocusSharpness
        self.avgExposureScore = avgExposureScore
        self.textureCoverage = textureCoverage
        self.processingTime = processingTime
    }
}

// MARK: - Bounding Box

public struct BoundingBox: Codable {
    public let min: Vector3
    public let max: Vector3

    public var size: Vector3 {
        Vector3(
            x: max.x - min.x,
            y: max.y - min.y,
            z: max.z - min.z
        )
    }

    public var center: Vector3 {
        Vector3(
            x: (min.x + max.x) / 2,
            y: (min.y + max.y) / 2,
            z: (min.z + max.z) / 2
        )
    }

    public init(min: Vector3, max: Vector3) {
        self.min = min
        self.max = max
    }

    public static func compute(from vertices: [Vector3]) -> BoundingBox {
        guard !vertices.isEmpty else {
            return BoundingBox(min: Vector3(x: 0, y: 0, z: 0), max: Vector3(x: 0, y: 0, z: 0))
        }

        var minX = vertices[0].x
        var minY = vertices[0].y
        var minZ = vertices[0].z
        var maxX = vertices[0].x
        var maxY = vertices[0].y
        var maxZ = vertices[0].z

        for vertex in vertices {
            minX = min(minX, vertex.x)
            minY = min(minY, vertex.y)
            minZ = min(minZ, vertex.z)
            maxX = max(maxX, vertex.x)
            maxY = max(maxY, vertex.y)
            maxZ = max(maxZ, vertex.z)
        }

        return BoundingBox(
            min: Vector3(x: minX, y: minY, z: minZ),
            max: Vector3(x: maxX, y: maxY, z: maxZ)
        )
    }
}
