//
//  MeshExporter.swift
//  Ollvy
//
//  Export mesh data to various formats (JSON, Binary, OBJ)
//  Created on 2025-10-27.
//

import Foundation

/// Exports mesh data to various formats
public class MeshExporter {

    /// Export format options
    public enum ExportFormat {
        case json
        case binary
        case obj
    }

    /// Export a capture sequence to Data
    public static func export(sequence: CaptureSequence, format: ExportFormat) throws -> Data {
        switch format {
        case .json:
            return try exportJSON(sequence: sequence)
        case .binary:
            return try exportBinary(sequence: sequence)
        case .obj:
            return try exportOBJSequence(sequence: sequence)
        }
    }

    /// Export a merged mesh to Data
    public static func export(mesh: MergedFaceMesh, format: ExportFormat) throws -> Data {
        switch format {
        case .json:
            return try exportJSON(mesh: mesh)
        case .binary:
            return try exportBinary(mesh: mesh)
        case .obj:
            return mesh.toOBJ().data(using: .utf8) ?? Data()
        }
    }

    // MARK: - JSON Export

    private static func exportJSON(sequence: CaptureSequence) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(sequence)
    }

    private static func exportJSON(mesh: MergedFaceMesh) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(mesh)
    }

    // MARK: - Binary Export

    private static func exportBinary(sequence: CaptureSequence) throws -> Data {
        var data = Data()

        // Header
        data.append("TAVIFACE".data(using: .utf8)!) // Magic number
        data.append(contentsOf: [0x01, 0x00]) // Version 1.0

        // Metadata
        data.append(uint32: UInt32(sequence.captures.count))
        data.append(double: sequence.startTime)
        data.append(double: sequence.completionTime ?? 0)

        // Each capture
        for capture in sequence.captures {
            try data.append(captureData: capture)
        }

        return data
    }

    private static func exportBinary(mesh: MergedFaceMesh) throws -> Data {
        var data = Data()

        // Header
        data.append("TAVIMESH".data(using: .utf8)!) // Magic number
        data.append(contentsOf: [0x01, 0x00]) // Version 1.0

        // Counts
        data.append(uint32: UInt32(mesh.vertices.count))
        data.append(uint32: UInt32(mesh.triangleIndices.count))
        data.append(uint32: UInt32(mesh.sourceCount))

        // Vertices
        for vertex in mesh.vertices {
            data.append(float: vertex.x)
            data.append(float: vertex.y)
            data.append(float: vertex.z)
        }

        // Normals
        for normal in mesh.normals {
            data.append(float: normal.x)
            data.append(float: normal.y)
            data.append(float: normal.z)
        }

        // Texture coordinates
        for texCoord in mesh.textureCoordinates {
            data.append(float: texCoord.x)
            data.append(float: texCoord.y)
        }

        // Indices
        for index in mesh.triangleIndices {
            data.append(int32: index)
        }

        return data
    }

    // MARK: - OBJ Export

    private static func exportOBJSequence(sequence: CaptureSequence) throws -> Data {
        var obj = "# Ollvy Multi-Capture Face Sequence\n"
        obj += "# Total captures: \(sequence.captures.count)\n\n"

        for (index, capture) in sequence.captures.enumerated() {
            obj += "# Capture \(index + 1): \(capture.step)\n"
            obj += "# Yaw: \(capture.yaw)°, Pitch: \(capture.pitch)°, Roll: \(capture.roll)°\n"
            obj += "# Distance: \(capture.distanceFromCamera)m\n\n"

            obj += "o capture_\(index)_\(capture.step)\n\n"

            let vertexOffset = index * (capture.vertices.count)

            // Vertices
            for vertex in capture.vertices {
                obj += "v \(vertex.x) \(vertex.y) \(vertex.z)\n"
            }

            obj += "\n"

            // Normals
            for normal in capture.normals {
                obj += "vn \(normal.x) \(normal.y) \(normal.z)\n"
            }

            obj += "\n"

            // Texture coordinates
            for texCoord in capture.textureCoordinates {
                obj += "vt \(texCoord.x) \(texCoord.y)\n"
            }

            obj += "\n"

            // Faces
            let indexCount = capture.triangleIndices.count
            for i in stride(from: 0, to: indexCount, by: 3) {
                // Bounds check: ensure we have 3 indices for the face
                guard i + 2 < indexCount else { break }
                let i0 = Int(capture.triangleIndices[i]) + vertexOffset + 1
                let i1 = Int(capture.triangleIndices[i + 1]) + vertexOffset + 1
                let i2 = Int(capture.triangleIndices[i + 2]) + vertexOffset + 1
                obj += "f \(i0)/\(i0)/\(i0) \(i1)/\(i1)/\(i1) \(i2)/\(i2)/\(i2)\n"
            }

            obj += "\n\n"
        }

        return obj.data(using: .utf8) ?? Data()
    }

    // MARK: - Import

    /// Import a capture sequence from JSON
    public static func importSequence(from data: Data) throws -> CaptureSequence {
        let decoder = JSONDecoder()
        return try decoder.decode(CaptureSequence.self, from: data)
    }

    /// Import a merged mesh from JSON
    public static func importMesh(from data: Data) throws -> MergedFaceMesh {
        let decoder = JSONDecoder()
        return try decoder.decode(MergedFaceMesh.self, from: data)
    }
}

// MARK: - Data Extensions

extension Data {
    mutating func append(uint32: UInt32) {
        var value = uint32.littleEndian
        Swift.withUnsafeBytes(of: &value) { self.append(contentsOf: $0) }
    }

    mutating func append(int32: Int32) {
        var value = int32.littleEndian
        Swift.withUnsafeBytes(of: &value) { self.append(contentsOf: $0) }
    }

    mutating func append(float: Float) {
        var value = float
        Swift.withUnsafeBytes(of: &value) { self.append(contentsOf: $0) }
    }

    mutating func append(double: Double) {
        var value = double
        Swift.withUnsafeBytes(of: &value) { self.append(contentsOf: $0) }
    }

    mutating func append(captureData capture: MeshCapture) throws {
        // Step name length + data
        guard let stepData = capture.step.data(using: .utf8) else {
            // Skip this capture if UTF-8 encoding fails (should never happen with valid strings)
            return
        }
        self.append(uint32: UInt32(stepData.count))
        self.append(stepData)

        // Vertex count
        self.append(uint32: UInt32(capture.vertices.count))

        // Vertices
        for vertex in capture.vertices {
            self.append(float: vertex.x)
            self.append(float: vertex.y)
            self.append(float: vertex.z)
        }

        // Normals
        for normal in capture.normals {
            self.append(float: normal.x)
            self.append(float: normal.y)
            self.append(float: normal.z)
        }

        // Triangle indices count
        self.append(uint32: UInt32(capture.triangleIndices.count))

        // Indices
        for index in capture.triangleIndices {
            self.append(int32: index)
        }

        // Pose data
        self.append(float: capture.yaw)
        self.append(float: capture.pitch)
        self.append(float: capture.roll)

        // Lighting
        self.append(float: Float(capture.ambientIntensity))
        self.append(float: Float(capture.colorTemperature))

        // Distance
        self.append(float: capture.distanceFromCamera)

        // Timestamp
        self.append(double: capture.timestamp)
    }
}

// MARK: - File Management

extension MeshExporter {

    /// Save export data to file
    public static func save(
        _ data: Data,
        to url: URL,
        format: ExportFormat
    ) throws {
        try data.write(to: url, options: .atomic)
    }

    /// Suggested file extension for format
    public static func fileExtension(for format: ExportFormat) -> String {
        switch format {
        case .json:
            return "json"
        case .binary:
            return "bin"
        case .obj:
            return "obj"
        }
    }

    /// Generate a filename for export
    public static func generateFilename(prefix: String = "face_scan", format: ExportFormat) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let ext = fileExtension(for: format)
        return "\(prefix)_\(timestamp).\(ext)"
    }
}
