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

    /// Total number of vertices
    public var vertexCount: Int {
        return vertices.count
    }

    /// Total number of triangles
    public var triangleCount: Int {
        return triangleIndices.count / 3
    }

    /// Initialize from ARFaceAnchor
    public init(faceAnchor: ARFaceAnchor, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        let geometry = faceAnchor.geometry

        // Modern ARKit API: vertices, triangleIndices, and textureCoordinates are already arrays
        // Extract vertices directly
        self.vertices = Array(geometry.vertices)
        let vertexCount = self.vertices.count

        // Extract triangle indices and convert from Int16 to Int32
        self.triangleIndices = geometry.triangleIndices.map { Int32($0) }

        // Compute normals from vertices and triangles (ARFaceGeometry doesn't provide normals)
        var normals = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0), count: vertexCount)

        // Calculate face normals and accumulate to vertex normals
        for i in stride(from: 0, to: triangleIndices.count, by: 3) {
            let i0 = Int(triangleIndices[i])
            let i1 = Int(triangleIndices[i + 1])
            let i2 = Int(triangleIndices[i + 2])

            let v0 = vertices[i0]
            let v1 = vertices[i1]
            let v2 = vertices[i2]

            // Calculate face normal using cross product
            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let faceNormal = normalize(cross(edge1, edge2))

            // Accumulate to vertex normals
            normals[i0] += faceNormal
            normals[i1] += faceNormal
            normals[i2] += faceNormal
        }

        // Normalize all vertex normals
        for i in 0..<vertexCount {
            normals[i] = normalize(normals[i])
        }
        self.normals = normals

        // Extract texture coordinates directly
        self.textureCoordinates = Array(geometry.textureCoordinates)

        self.transform = faceAnchor.transform
        self.timestamp = timestamp
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

    /// Initialize from ARFaceAnchor
    public init(faceAnchor: ARFaceAnchor) {
        self.coefficients = faceAnchor.blendShapes
    }
}
