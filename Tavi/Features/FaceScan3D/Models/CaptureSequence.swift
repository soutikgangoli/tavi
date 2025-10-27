//
//  CaptureSequence.swift
//  Tavi
//
//  Multi-angle capture sequence data structures
//  Created on 2025-10-27.
//

import Foundation
import ARKit
import simd

// MARK: - Codable Math Types

/// Codable 3D vector
public struct Vector3: Codable, Equatable {
    public let x: Float
    public let y: Float
    public let z: Float

    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    public init(_ simd: SIMD3<Float>) {
        self.x = simd.x
        self.y = simd.y
        self.z = simd.z
    }

    public func toSIMD() -> SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }

    public func length() -> Float {
        return sqrt(x * x + y * y + z * z)
    }

    public func normalized() -> Vector3 {
        let len = length()
        guard len > 0 else { return self }
        return Vector3(x: x / len, y: y / len, z: z / len)
    }

    public static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
        return Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    public static func * (lhs: Vector3, rhs: Float) -> Vector3 {
        return Vector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }
}

/// Codable 2D vector
public struct Vector2: Codable, Equatable {
    public let x: Float
    public let y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }

    public init(_ simd: SIMD2<Float>) {
        self.x = simd.x
        self.y = simd.y
    }

    public func toSIMD() -> SIMD2<Float> {
        return SIMD2<Float>(x, y)
    }
}

/// Codable 4x4 matrix
public struct Matrix4x4: Codable {
    public let m00: Float; public let m01: Float; public let m02: Float; public let m03: Float
    public let m10: Float; public let m11: Float; public let m12: Float; public let m13: Float
    public let m20: Float; public let m21: Float; public let m22: Float; public let m23: Float
    public let m30: Float; public let m31: Float; public let m32: Float; public let m33: Float

    public init(_ simd: simd_float4x4) {
        self.m00 = simd[0][0]; self.m01 = simd[0][1]; self.m02 = simd[0][2]; self.m03 = simd[0][3]
        self.m10 = simd[1][0]; self.m11 = simd[1][1]; self.m12 = simd[1][2]; self.m13 = simd[1][3]
        self.m20 = simd[2][0]; self.m21 = simd[2][1]; self.m22 = simd[2][2]; self.m23 = simd[2][3]
        self.m30 = simd[3][0]; self.m31 = simd[3][1]; self.m32 = simd[3][2]; self.m33 = simd[3][3]
    }

    public func toSIMD() -> simd_float4x4 {
        return simd_float4x4(
            SIMD4<Float>(m00, m01, m02, m03),
            SIMD4<Float>(m10, m11, m12, m13),
            SIMD4<Float>(m20, m21, m22, m23),
            SIMD4<Float>(m30, m31, m32, m33)
        )
    }
}

/// 3D Bounding box
public struct BoundingBox: Codable {
    public let min: Vector3
    public let max: Vector3

    public var center: Vector3 {
        Vector3(
            x: (min.x + max.x) / 2,
            y: (min.y + max.y) / 2,
            z: (min.z + max.z) / 2
        )
    }

    public var size: Vector3 {
        Vector3(
            x: max.x - min.x,
            y: max.y - min.y,
            z: max.z - min.z
        )
    }

    static func from(vertices: [Vector3]) -> BoundingBox {
        var minX: Float = .infinity
        var maxX: Float = -.infinity
        var minY: Float = .infinity
        var maxY: Float = -.infinity
        var minZ: Float = .infinity
        var maxZ: Float = -.infinity

        for vertex in vertices {
            minX = Swift.min(minX, vertex.x)
            maxX = Swift.max(maxX, vertex.x)
            minY = Swift.min(minY, vertex.y)
            maxY = Swift.max(maxY, vertex.y)
            minZ = Swift.min(minZ, vertex.z)
            maxZ = Swift.max(maxZ, vertex.z)
        }

        return BoundingBox(
            min: Vector3(x: minX, y: minY, z: minZ),
            max: Vector3(x: maxX, y: maxY, z: maxZ)
        )
    }
}

// MARK: - Capture Data Structures

/// A single mesh capture at a specific pose
public struct MeshCapture: Codable {
    /// Unique identifier for this capture
    public let id: UUID

    /// Which guidance step this was captured at
    public let step: String

    /// Vertex positions in local face coordinate space
    public let vertices: [Vector3]

    /// Triangle indices (groups of 3)
    public let triangleIndices: [Int32]

    /// Normal vectors for each vertex
    public let normals: [Vector3]

    /// Texture coordinates
    public let textureCoordinates: [Vector2]

    /// Head pose transform (4x4 matrix)
    public let transform: Matrix4x4

    /// Yaw angle in degrees
    public let yaw: Float

    /// Pitch angle in degrees
    public let pitch: Float

    /// Roll angle in degrees
    public let roll: Float

    /// Timestamp of capture
    public let timestamp: TimeInterval

    /// Lighting estimation at capture time
    public let ambientIntensity: CGFloat
    public let colorTemperature: CGFloat

    /// Distance from camera in meters
    public let distanceFromCamera: Float

    public init(
        step: GuidanceStep,
        geometry: FaceMeshGeometry,
        yaw: Float,
        pitch: Float,
        roll: Float,
        lightEstimation: LightEstimation?
    ) {
        self.id = UUID()
        self.step = step.shortName

        // Convert vertices to codable format
        self.vertices = geometry.vertices.map { simdVert in Vector3(simdVert) }
        self.triangleIndices = geometry.triangleIndices
        self.normals = geometry.normals.map { simdNorm in Vector3(simdNorm) }
        self.textureCoordinates = geometry.textureCoordinates.map { simdTex in Vector2(simdTex) }

        // Store transform
        self.transform = Matrix4x4(geometry.transform)

        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
        self.timestamp = geometry.timestamp

        // Store lighting
        self.ambientIntensity = lightEstimation?.ambientIntensity ?? 0
        self.colorTemperature = lightEstimation?.ambientColorTemperature ?? 0

        // Calculate distance
        self.distanceFromCamera = abs(geometry.transform.columns.3.z)
    }
}

/// Complete capture sequence with all poses
public struct CaptureSequence: Codable {
    /// Unique identifier for this sequence
    public let id: UUID

    /// All mesh captures in this sequence
    public var captures: [MeshCapture]

    /// Texture samples (RGB frames) for each capture (not codable - stored separately)
    public var textureSamples: [PoseSample] = []

    /// When the sequence was started
    public let startTime: TimeInterval

    /// When the sequence was completed (nil if in progress)
    public var completionTime: TimeInterval?

    /// Metadata
    public var metadata: SequenceMetadata

    enum CodingKeys: String, CodingKey {
        case id, captures, textureSamples, startTime, completionTime, metadata
    }

    public init() {
        self.id = UUID()
        self.captures = []
        self.textureSamples = []
        self.startTime = Date().timeIntervalSince1970
        self.completionTime = nil
        self.metadata = SequenceMetadata()
    }

    /// Add a capture to the sequence
    public mutating func addCapture(_ capture: MeshCapture) {
        captures.append(capture)

        // Update metadata
        metadata.totalCaptures = captures.count
        metadata.minLighting = min(metadata.minLighting ?? capture.ambientIntensity, capture.ambientIntensity)
        metadata.maxLighting = max(metadata.maxLighting ?? capture.ambientIntensity, capture.ambientIntensity)
        metadata.minDistance = min(metadata.minDistance ?? capture.distanceFromCamera, capture.distanceFromCamera)
        metadata.maxDistance = max(metadata.maxDistance ?? capture.distanceFromCamera, capture.distanceFromCamera)
    }

    /// Add a texture sample to the sequence
    public mutating func addTextureSample(_ sample: PoseSample) {
        textureSamples.append(sample)
    }

    /// Mark sequence as complete
    public mutating func complete() {
        completionTime = Date().timeIntervalSince1970
    }

    /// Duration of capture sequence in seconds
    public var duration: TimeInterval? {
        guard let completionTime = completionTime else { return nil }
        return completionTime - startTime
    }
}

/// Metadata about the capture sequence
public struct SequenceMetadata: Codable {
    public var totalCaptures: Int = 0
    public var minLighting: CGFloat?
    public var maxLighting: CGFloat?
    public var minDistance: Float?
    public var maxDistance: Float?
    public var deviceModel: String = ""
    public var osVersion: String = ""

    public init() {
        #if os(iOS)
        self.deviceModel = UIDevice.current.model
        self.osVersion = UIDevice.current.systemVersion
        #endif
    }
}

/// Merged face mesh from multiple captures
public struct MergedFaceMesh: Codable {
    /// Unified vertex positions
    public let vertices: [Vector3]

    /// Unified triangle indices
    public let triangleIndices: [Int32]

    /// Averaged normals
    public let normals: [Vector3]

    /// Texture coordinates
    public let textureCoordinates: [Vector2]

    /// Number of source captures
    public let sourceCount: Int

    /// Timestamp of merge
    public let mergeTimestamp: TimeInterval

    /// Bounding box
    public let boundingBox: BoundingBox

    public init(
        vertices: [Vector3],
        triangleIndices: [Int32],
        normals: [Vector3],
        textureCoordinates: [Vector2],
        sourceCount: Int
    ) {
        self.vertices = vertices
        self.triangleIndices = triangleIndices
        self.normals = normals
        self.textureCoordinates = textureCoordinates
        self.sourceCount = sourceCount
        self.mergeTimestamp = Date().timeIntervalSince1970

        // Calculate bounding box
        self.boundingBox = BoundingBox.from(vertices: vertices)
    }

    /// Get merged mesh as FaceMeshGeometry for processing
    public var geometry: FaceMeshGeometry {
        return FaceMeshGeometry(
            vertices: vertices.map { $0.toSIMD() },
            normals: normals.map { $0.toSIMD() },
            textureCoordinates: textureCoordinates.map { $0.toSIMD() },
            triangleIndices: triangleIndices
        )
    }

    /// Export to OBJ format
    public func toOBJ() -> String {
        var obj = "# Tavi Merged Face Mesh\n"
        obj += "# Source captures: \(sourceCount)\n"
        obj += "# Vertices: \(vertices.count)\n"
        obj += "# Triangles: \(triangleIndices.count / 3)\n\n"

        // Write vertices
        for vertex in vertices {
            obj += "v \(vertex.x) \(vertex.y) \(vertex.z)\n"
        }

        obj += "\n"

        // Write normals
        for normal in normals {
            obj += "vn \(normal.x) \(normal.y) \(normal.z)\n"
        }

        obj += "\n"

        // Write texture coordinates
        for texCoord in textureCoordinates {
            obj += "vt \(texCoord.x) \(texCoord.y)\n"
        }

        obj += "\n"

        // Write faces
        for i in stride(from: 0, to: triangleIndices.count, by: 3) {
            let i0 = Int(triangleIndices[i]) + 1
            let i1 = Int(triangleIndices[i + 1]) + 1
            let i2 = Int(triangleIndices[i + 2]) + 1
            obj += "f \(i0)/\(i0)/\(i0) \(i1)/\(i1)/\(i1) \(i2)/\(i2)/\(i2)\n"
        }

        return obj
    }
}
