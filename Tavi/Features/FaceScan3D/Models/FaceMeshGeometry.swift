//
//  FaceMeshGeometry.swift
//  Tavi
//
//  Face mesh geometry data from ARFaceAnchor
//  Created on 2025-10-27.
//

import Foundation
import ARKit
import simd

/// Complete face mesh geometry data extracted from ARFaceAnchor
public struct FaceMeshGeometry: Equatable {
    /// 3D vertex positions in world space
    public let vertices: [SIMD3<Float>]

    /// Triangle indices (groups of 3 form triangles)
    public let triangleIndices: [Int32]

    /// Normal vectors for each vertex
    public let normals: [SIMD3<Float>]

    /// Texture coordinates (UV mapping)
    public let textureCoordinates: [SIMD2<Float>]

    /// Face anchor transform matrix
    public let transform: simd_float4x4

    /// Timestamp of this geometry capture
    public let timestamp: TimeInterval

    /// Number of original ARKit vertices (before extension)
    /// Use this for metrics calculation to avoid extended boundary vertices
    public let originalVertexCount: Int

    /// Whether this mesh was extended for forehead coverage
    public let wasExtended: Bool

    /// Total number of vertices
    public var vertexCount: Int {
        return vertices.count
    }

    /// Total number of triangles
    public var triangleCount: Int {
        return triangleIndices.count / 3
    }

    /// Initialize from ARFaceAnchor with optional mesh extension for forehead coverage
    public init(
        faceAnchor: ARFaceAnchor,
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        extendForehead: Bool = true
    ) {
        let geometry = faceAnchor.geometry

        // Modern ARKit API: vertices, triangleIndices, and textureCoordinates are already arrays
        // Extract vertices directly
        let arkitVertices = Array(geometry.vertices)
        let arkitVertexCount = arkitVertices.count

        // Extract triangle indices and convert from Int16 to Int32
        let arkitTriangleIndices = geometry.triangleIndices.map { Int32($0) }

        // Compute normals from vertices and triangles (ARFaceGeometry doesn't provide normals)
        var arkitNormals = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0), count: arkitVertexCount)

        // Calculate face normals and accumulate to vertex normals
        for i in stride(from: 0, to: arkitTriangleIndices.count, by: 3) {
            let i0 = Int(arkitTriangleIndices[i])
            let i1 = Int(arkitTriangleIndices[i + 1])
            let i2 = Int(arkitTriangleIndices[i + 2])

            let v0 = arkitVertices[i0]
            let v1 = arkitVertices[i1]
            let v2 = arkitVertices[i2]

            // Calculate face normal using cross product
            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let faceNormal = normalize(cross(edge1, edge2))

            // Accumulate to vertex normals
            arkitNormals[i0] += faceNormal
            arkitNormals[i1] += faceNormal
            arkitNormals[i2] += faceNormal
        }

        // Normalize all vertex normals
        for i in 0..<arkitVertexCount {
            arkitNormals[i] = normalize(arkitNormals[i])
        }

        // Extract texture coordinates directly
        let arkitTexCoords = Array(geometry.textureCoordinates)

        // Apply mesh extension for forehead coverage if requested
        if extendForehead {
            let extender = MeshExtender()
            let extended = extender.extend(
                vertices: arkitVertices,
                triangleIndices: arkitTriangleIndices,
                normals: arkitNormals,
                textureCoordinates: arkitTexCoords
            )

            self.vertices = extended.vertices
            self.triangleIndices = extended.triangleIndices
            self.normals = extended.normals
            self.textureCoordinates = extended.textureCoordinates
            self.originalVertexCount = extended.originalVertexCount
            self.wasExtended = extended.wasExtended
        } else {
            // No extension - use ARKit data directly
            self.vertices = arkitVertices
            self.triangleIndices = arkitTriangleIndices
            self.normals = arkitNormals
            self.textureCoordinates = arkitTexCoords
            self.originalVertexCount = arkitVertexCount
            self.wasExtended = false
        }

        self.transform = faceAnchor.transform
        self.timestamp = timestamp
    }

    /// Initialize from raw mesh data (for processed/smoothed meshes)
    public init(
        vertices: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        textureCoordinates: [SIMD2<Float>],
        triangleIndices: [Int32],
        transform: simd_float4x4 = matrix_identity_float4x4,
        timestamp: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.vertices = vertices
        self.normals = normals
        self.textureCoordinates = textureCoordinates
        self.triangleIndices = triangleIndices
        self.transform = transform
        self.timestamp = timestamp
        self.originalVertexCount = vertices.count
        self.wasExtended = false
    }
}

/// Light estimation data from ARFrame
public struct LightEstimation {
    /// Ambient light intensity
    public let ambientIntensity: CGFloat

    /// Ambient color temperature in Kelvin
    public let ambientColorTemperature: CGFloat

    /// Primary light direction (if available)
    public let primaryLightDirection: SIMD3<Float>?

    /// Primary light intensity (if available)
    public let primaryLightIntensity: CGFloat?

    /// Initialize from ARFrame
    public init?(frame: ARFrame) {
        guard let lightEstimate = frame.lightEstimate else {
            return nil
        }

        self.ambientIntensity = lightEstimate.ambientIntensity
        self.ambientColorTemperature = lightEstimate.ambientColorTemperature

        // TrueDepth provides directional light info
        if let directionalEstimate = lightEstimate as? ARDirectionalLightEstimate {
            self.primaryLightDirection = directionalEstimate.primaryLightDirection
            self.primaryLightIntensity = directionalEstimate.primaryLightIntensity
        } else {
            self.primaryLightDirection = nil
            self.primaryLightIntensity = nil
        }
    }
}

/// Blend shape coefficients from face tracking
public struct FaceBlendShapes {
    /// Raw blend shape coefficients dictionary
    public let coefficients: [ARFaceAnchor.BlendShapeLocation: NSNumber]

    /// Convenience accessors for common blend shapes
    public var eyeBlinkLeft: Float {
        return coefficients[.eyeBlinkLeft]?.floatValue ?? 0
    }

    public var eyeBlinkRight: Float {
        return coefficients[.eyeBlinkRight]?.floatValue ?? 0
    }

    public var jawOpen: Float {
        return coefficients[.jawOpen]?.floatValue ?? 0
    }

    public var mouthSmileLeft: Float {
        return coefficients[.mouthSmileLeft]?.floatValue ?? 0
    }

    public var mouthSmileRight: Float {
        return coefficients[.mouthSmileRight]?.floatValue ?? 0
    }

    // MARK: - Additional Expression Blend Shapes

    public var eyeWideLeft: Float {
        return coefficients[.eyeWideLeft]?.floatValue ?? 0
    }

    public var eyeWideRight: Float {
        return coefficients[.eyeWideRight]?.floatValue ?? 0
    }

    public var eyeSquintLeft: Float {
        return coefficients[.eyeSquintLeft]?.floatValue ?? 0
    }

    public var eyeSquintRight: Float {
        return coefficients[.eyeSquintRight]?.floatValue ?? 0
    }

    public var browInnerUp: Float {
        return coefficients[.browInnerUp]?.floatValue ?? 0
    }

    public var browDownLeft: Float {
        return coefficients[.browDownLeft]?.floatValue ?? 0
    }

    public var browDownRight: Float {
        return coefficients[.browDownRight]?.floatValue ?? 0
    }

    public var mouthFrownLeft: Float {
        return coefficients[.mouthFrownLeft]?.floatValue ?? 0
    }

    public var mouthFrownRight: Float {
        return coefficients[.mouthFrownRight]?.floatValue ?? 0
    }

    public var mouthPucker: Float {
        return coefficients[.mouthPucker]?.floatValue ?? 0
    }

    public var cheekPuff: Float {
        return coefficients[.cheekPuff]?.floatValue ?? 0
    }

    /// Initialize from ARFaceAnchor
    public init(faceAnchor: ARFaceAnchor) {
        self.coefficients = faceAnchor.blendShapes
    }
}
