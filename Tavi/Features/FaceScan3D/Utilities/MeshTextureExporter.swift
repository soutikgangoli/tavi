//
//  MeshTextureExporter.swift
//  Tavi
//
//  Export textured mesh to various formats (OBJ+MTL, glTF, USDZ)
//  Created on 2025-10-27.
//

import Foundation
import UIKit
import CoreGraphics
import SceneKit
import ModelIO
import UniformTypeIdentifiers

/// Exports textured meshes to various 3D formats
public class MeshTextureExporter {

    // MARK: - Export Functions

    /// Export as OBJ + MTL + PNG
    public static func exportOBJ(
        unifiedMesh: UnifiedMesh,
        texture: CGImage,
        metadata: FaceScanMetadata,
        outputDirectory: URL
    ) throws -> URL {

        let timestamp = Int(metadata.timestamp)
        let baseName = "face_scan_\(timestamp)"

        // Create output files
        let objURL = outputDirectory.appendingPathComponent("\(baseName).obj")
        let mtlURL = outputDirectory.appendingPathComponent("\(baseName).mtl")
        let texURL = outputDirectory.appendingPathComponent("\(baseName).png")
        let metaURL = outputDirectory.appendingPathComponent("\(baseName)_metadata.json")

        // Write texture PNG
        try saveTexture(texture, to: texURL)

        // Write MTL file
        let mtlContent = generateMTL(textureName: "\(baseName).png")
        try mtlContent.write(to: mtlURL, atomically: true, encoding: .utf8)

        // Write OBJ file
        let objContent = generateOBJ(mesh: unifiedMesh, mtlName: "\(baseName).mtl")
        try objContent.write(to: objURL, atomically: true, encoding: .utf8)

        // Write metadata JSON
        let metaData = try JSONEncoder().encode(metadata)
        try metaData.write(to: metaURL)

        AppLogger.export.info("Exported OBJ: \(objURL.path)")
        return objURL
    }

    /// Export as glTF 2.0 + PNG
    public static func exportGLTF(
        unifiedMesh: UnifiedMesh,
        texture: CGImage,
        metadata: FaceScanMetadata,
        outputDirectory: URL
    ) throws -> URL {

        let timestamp = Int(metadata.timestamp)
        let baseName = "face_scan_\(timestamp)"

        let gltfURL = outputDirectory.appendingPathComponent("\(baseName).gltf")
        let binURL = outputDirectory.appendingPathComponent("\(baseName).bin")
        let texURL = outputDirectory.appendingPathComponent("\(baseName).png")
        let metaURL = outputDirectory.appendingPathComponent("\(baseName)_metadata.json")

        // Write texture PNG
        try saveTexture(texture, to: texURL)

        // Write binary geometry data
        let binData = try generateGLTFBinary(mesh: unifiedMesh)
        try binData.write(to: binURL)

        // Write glTF JSON
        let gltfContent = try generateGLTF(
            mesh: unifiedMesh,
            binFileName: "\(baseName).bin",
            texFileName: "\(baseName).png",
            binSize: binData.count
        )
        try gltfContent.write(to: gltfURL, atomically: true, encoding: .utf8)

        // Write metadata JSON
        let metaData = try JSONEncoder().encode(metadata)
        try metaData.write(to: metaURL)

        AppLogger.export.info("Exported glTF: \(gltfURL.path)")
        return gltfURL
    }

    /// Export as USDZ (using Model I/O)
    public static func exportUSDZ(
        unifiedMesh: UnifiedMesh,
        texture: CGImage,
        metadata: FaceScanMetadata,
        outputDirectory: URL
    ) throws -> URL {

        let timestamp = Int(metadata.timestamp)
        let baseName = "face_scan_\(timestamp)"

        let usdzURL = outputDirectory.appendingPathComponent("\(baseName).usdz")
        let metaURL = outputDirectory.appendingPathComponent("\(baseName)_metadata.json")

        // Create MDLMesh from unified mesh
        let mdlMesh = try createMDLMesh(from: unifiedMesh, texture: texture)

        // Create MDLAsset
        let asset = MDLAsset()
        asset.add(mdlMesh)

        // Export to USDZ
        try asset.export(to: usdzURL)

        // Write metadata JSON
        let metaData = try JSONEncoder().encode(metadata)
        try metaData.write(to: metaURL)

        AppLogger.export.info("Exported USDZ: \(usdzURL.path)")
        return usdzURL
    }

    // MARK: - OBJ Generation

    private static func generateOBJ(mesh: UnifiedMesh, mtlName: String) -> String {
        var obj = "# Tavi Face Scan - Textured Mesh\n"
        obj += "# Vertices: \(mesh.vertexCount)\n"
        obj += "# Triangles: \(mesh.triangleCount)\n"
        obj += "mtllib \(mtlName)\n\n"

        // Write vertices
        obj += "# Vertices\n"
        for vertex in mesh.vertices {
            obj += "v \(vertex.x) \(vertex.y) \(vertex.z)\n"
        }
        obj += "\n"

        // Write texture coordinates
        obj += "# Texture coordinates\n"
        for texCoord in mesh.textureCoordinates {
            obj += "vt \(texCoord.x) \(texCoord.y)\n"
        }
        obj += "\n"

        // Write normals
        obj += "# Normals\n"
        for normal in mesh.normals {
            obj += "vn \(normal.x) \(normal.y) \(normal.z)\n"
        }
        obj += "\n"

        // Write faces with material
        obj += "# Faces\n"
        obj += "usemtl FaceMaterial\n"
        for i in stride(from: 0, to: mesh.triangleIndices.count, by: 3) {
            let i0 = Int(mesh.triangleIndices[i]) + 1
            let i1 = Int(mesh.triangleIndices[i + 1]) + 1
            let i2 = Int(mesh.triangleIndices[i + 2]) + 1
            obj += "f \(i0)/\(i0)/\(i0) \(i1)/\(i1)/\(i1) \(i2)/\(i2)/\(i2)\n"
        }

        return obj
    }

    private static func generateMTL(textureName: String) -> String {
        var mtl = "# Tavi Face Scan - Material\n"
        mtl += "newmtl FaceMaterial\n"
        mtl += "Ka 1.0 1.0 1.0\n"  // Ambient
        mtl += "Kd 1.0 1.0 1.0\n"  // Diffuse
        mtl += "Ks 0.0 0.0 0.0\n"  // Specular
        mtl += "Ns 10.0\n"         // Shininess
        mtl += "d 1.0\n"           // Opacity
        mtl += "illum 2\n"         // Illumination model
        mtl += "map_Kd \(textureName)\n"  // Diffuse texture map

        return mtl
    }

    // MARK: - glTF Generation

    private static func generateGLTF(
        mesh: UnifiedMesh,
        binFileName: String,
        texFileName: String,
        binSize: Int
    ) throws -> String {

        let gltf: [String: Any] = [
            "asset": [
                "version": "2.0",
                "generator": "Tavi FaceScan3D"
            ],
            "scene": 0,
            "scenes": [
                [
                    "nodes": [0]
                ]
            ],
            "nodes": [
                [
                    "mesh": 0
                ]
            ],
            "meshes": [
                [
                    "primitives": [
                        [
                            "attributes": [
                                "POSITION": 0,
                                "NORMAL": 1,
                                "TEXCOORD_0": 2
                            ],
                            "indices": 3,
                            "material": 0
                        ]
                    ]
                ]
            ],
            "materials": [
                [
                    "pbrMetallicRoughness": [
                        "baseColorTexture": [
                            "index": 0
                        ],
                        "metallicFactor": 0.0,
                        "roughnessFactor": 1.0
                    ]
                ]
            ],
            "textures": [
                [
                    "source": 0
                ]
            ],
            "images": [
                [
                    "uri": texFileName
                ]
            ],
            "accessors": [
                // Position accessor (0)
                [
                    "bufferView": 0,
                    "componentType": 5126,  // FLOAT
                    "count": mesh.vertexCount,
                    "type": "VEC3",
                    "min": [mesh.boundingBox.min.x, mesh.boundingBox.min.y, mesh.boundingBox.min.z],
                    "max": [mesh.boundingBox.max.x, mesh.boundingBox.max.y, mesh.boundingBox.max.z]
                ],
                // Normal accessor (1)
                [
                    "bufferView": 1,
                    "componentType": 5126,  // FLOAT
                    "count": mesh.vertexCount,
                    "type": "VEC3"
                ],
                // TexCoord accessor (2)
                [
                    "bufferView": 2,
                    "componentType": 5126,  // FLOAT
                    "count": mesh.vertexCount,
                    "type": "VEC2"
                ],
                // Indices accessor (3)
                [
                    "bufferView": 3,
                    "componentType": 5125,  // UNSIGNED_INT
                    "count": mesh.triangleIndices.count,
                    "type": "SCALAR"
                ]
            ],
            "bufferViews": [
                // Positions (0)
                [
                    "buffer": 0,
                    "byteOffset": 0,
                    "byteLength": mesh.vertexCount * 12,  // 3 floats * 4 bytes
                    "target": 34962  // ARRAY_BUFFER
                ],
                // Normals (1)
                [
                    "buffer": 0,
                    "byteOffset": mesh.vertexCount * 12,
                    "byteLength": mesh.vertexCount * 12,
                    "target": 34962
                ],
                // TexCoords (2)
                [
                    "buffer": 0,
                    "byteOffset": mesh.vertexCount * 24,
                    "byteLength": mesh.vertexCount * 8,  // 2 floats * 4 bytes
                    "target": 34962
                ],
                // Indices (3)
                [
                    "buffer": 0,
                    "byteOffset": mesh.vertexCount * 32,
                    "byteLength": mesh.triangleIndices.count * 4,  // 1 uint * 4 bytes
                    "target": 34963  // ELEMENT_ARRAY_BUFFER
                ]
            ],
            "buffers": [
                [
                    "uri": binFileName,
                    "byteLength": binSize
                ]
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: gltf, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? ""
    }

    private static func generateGLTFBinary(mesh: UnifiedMesh) throws -> Data {
        var data = Data()

        // Write positions (Vec3<Float>)
        for vertex in mesh.vertices {
            data.appendFloat(vertex.x)
            data.appendFloat(vertex.y)
            data.appendFloat(vertex.z)
        }

        // Write normals (Vec3<Float>)
        for normal in mesh.normals {
            data.appendFloat(normal.x)
            data.appendFloat(normal.y)
            data.appendFloat(normal.z)
        }

        // Write texture coordinates (Vec2<Float>)
        for texCoord in mesh.textureCoordinates {
            data.appendFloat(texCoord.x)
            data.appendFloat(texCoord.y)
        }

        // Write indices (UInt32)
        for index in mesh.triangleIndices {
            data.appendUInt32(UInt32(index))
        }

        return data
    }

    // MARK: - USDZ Generation

    private static func createMDLMesh(from mesh: UnifiedMesh, texture: CGImage) throws -> MDLMesh {
        // Create vertex descriptor
        let vertexDescriptor = MDLVertexDescriptor()

        // Position attribute
        vertexDescriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: 0,
            bufferIndex: 0
        )

        // Normal attribute
        vertexDescriptor.attributes[1] = MDLVertexAttribute(
            name: MDLVertexAttributeNormal,
            format: .float3,
            offset: 0,
            bufferIndex: 1
        )

        // Texture coordinate attribute
        vertexDescriptor.attributes[2] = MDLVertexAttribute(
            name: MDLVertexAttributeTextureCoordinate,
            format: .float2,
            offset: 0,
            bufferIndex: 2
        )

        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: 12)  // 3 floats
        vertexDescriptor.layouts[1] = MDLVertexBufferLayout(stride: 12)  // 3 floats
        vertexDescriptor.layouts[2] = MDLVertexBufferLayout(stride: 8)   // 2 floats

        // Create allocator
        let allocator = MDLMeshBufferDataAllocator()

        // Create vertex buffers
        let positionData = mesh.vertices.flatMap { [$0.x, $0.y, $0.z] }
        let positionBuffer = allocator.newBuffer(with: Data(bytes: positionData, count: positionData.count * 4), type: .vertex)

        let normalData = mesh.normals.flatMap { [$0.x, $0.y, $0.z] }
        let normalBuffer = allocator.newBuffer(with: Data(bytes: normalData, count: normalData.count * 4), type: .vertex)

        let texCoordData = mesh.textureCoordinates.flatMap { [$0.x, $0.y] }
        let texCoordBuffer = allocator.newBuffer(with: Data(bytes: texCoordData, count: texCoordData.count * 4), type: .vertex)

        // Create index buffer
        let indexData = mesh.triangleIndices.map { UInt32($0) }
        let indexBuffer = allocator.newBuffer(with: Data(bytes: indexData, count: indexData.count * 4), type: .index)

        // Create submesh
        let submesh = MDLSubmesh(
            indexBuffer: indexBuffer,
            indexCount: mesh.triangleIndices.count,
            indexType: .uInt32,
            geometryType: .triangles,
            material: nil
        )

        // Create MDLMesh
        let mdlMesh = MDLMesh(
            vertexBuffers: [positionBuffer, normalBuffer, texCoordBuffer],
            vertexCount: mesh.vertexCount,
            descriptor: vertexDescriptor,
            submeshes: [submesh]
        )

        // Apply texture material
        let scatteringFunction = MDLScatteringFunction()
        let material = MDLMaterial(name: "FaceMaterial", scatteringFunction: scatteringFunction)

        // Create texture from CGImage
        let textureData = UIImage(cgImage: texture).pngData()!
        let dimensions = vector_int2(Int32(texture.width), Int32(texture.height))
        let mdlTexture = MDLTexture(
            data: textureData,
            topLeftOrigin: false,
            name: "albedo",
            dimensions: dimensions,
            rowStride: texture.width * 4,
            channelCount: 4,
            channelEncoding: .uInt8,
            isCube: false
        )

        // Create material property with texture sampler
        let textureSampler = MDLTextureSampler()
        textureSampler.texture = mdlTexture
        let textureProperty = MDLMaterialProperty(name: "baseColor", semantic: .baseColor, textureSampler: textureSampler)
        material.setProperty(textureProperty)
        submesh.material = material

        return mdlMesh
    }

    // MARK: - Helper Functions

    private static func saveTexture(_ texture: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "MeshTextureExporter", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create image destination"
            ])
        }

        CGImageDestinationAddImage(destination, texture, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "MeshTextureExporter", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to write texture PNG"
            ])
        }
    }
}

// MARK: - Data Extensions

extension Data {
    mutating func appendFloat(_ value: Float) {
        var mutableValue = value
        Swift.withUnsafeBytes(of: &mutableValue) { bytes in
            self.append(contentsOf: bytes)
        }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var mutableValue = value.littleEndian
        Swift.withUnsafeBytes(of: &mutableValue) { bytes in
            self.append(contentsOf: bytes)
        }
    }
}
