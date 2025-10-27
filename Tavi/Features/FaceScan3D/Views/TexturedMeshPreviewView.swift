//
//  TexturedMeshPreviewView.swift
//  Tavi
//
//  3D preview of textured face mesh using SceneKit
//  Created on 2025-10-27.
//

import SwiftUI
import SceneKit

/// 3D preview view for textured mesh
public struct TexturedMeshPreviewView: View {
    let bakeResult: TextureBakeResult

    @State private var rotationAngle: Double = 0
    @State private var showWireframe = false

    public init(bakeResult: TextureBakeResult) {
        self.bakeResult = bakeResult
    }

    public var body: some View {
        VStack {
            // SceneKit view
            SceneKitPreview(
                mesh: bakeResult.unifiedMesh,
                texture: bakeResult.albedoTexture,
                showWireframe: showWireframe,
                rotationAngle: rotationAngle
            )
            .ignoresSafeArea()

            // Controls overlay
            VStack {
                Spacer()

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vertices: \(bakeResult.unifiedMesh.vertexCount)")
                        Text("Triangles: \(bakeResult.unifiedMesh.triangleCount)")
                        Text("Coverage: \(Int(bakeResult.coveragePercentage * 100))%")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)

                    Spacer()

                    VStack(spacing: 12) {
                        Button(action: { showWireframe.toggle() }) {
                            Image(systemName: showWireframe ? "square.grid.3x3.fill" : "square.grid.3x3")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(.ultraThinMaterial)
                                .cornerRadius(10)
                        }

                        Button(action: resetCamera) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(.ultraThinMaterial)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func resetCamera() {
        withAnimation {
            rotationAngle = 0
        }
    }
}

// MARK: - SceneKit Preview

private struct SceneKitPreview: UIViewRepresentable {
    let mesh: UnifiedMesh
    let texture: CGImage
    let showWireframe: Bool
    let rotationAngle: Double

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = SCNScene()
        sceneView.backgroundColor = UIColor.black
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.defaultCameraController.interactionMode = .orbitTurntable

        // Create mesh node
        if let meshNode = createMeshNode() {
            sceneView.scene?.rootNode.addChildNode(meshNode)
        }

        // Setup camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 0.5)
        sceneView.scene?.rootNode.addChildNode(cameraNode)

        return sceneView
    }

    func updateUIView(_ sceneView: SCNView, context: Context) {
        // Update wireframe mode
        if let meshNode = sceneView.scene?.rootNode.childNode(withName: "faceMesh", recursively: false) {
            if let geometry = meshNode.geometry {
                geometry.firstMaterial?.fillMode = showWireframe ? .lines : .fill
            }

            // Apply rotation
            meshNode.eulerAngles.y = Float(rotationAngle * .pi / 180)
        }
    }

    private func createMeshNode() -> SCNNode? {
        // Create SCNGeometry from mesh data
        guard let geometry = createSCNGeometry() else { return nil }

        // Apply texture material
        let material = SCNMaterial()
        material.diffuse.contents = UIImage(cgImage: texture)
        material.isDoubleSided = true
        material.lightingModel = .physicallyBased
        material.roughness.contents = 0.8
        material.metalness.contents = 0.0

        geometry.materials = [material]

        // Create node
        let node = SCNNode(geometry: geometry)
        node.name = "faceMesh"

        return node
    }

    private func createSCNGeometry() -> SCNGeometry? {
        // Create geometry sources
        let vertices = mesh.vertices.map { SCNVector3($0.x, $0.y, $0.z) }
        let normals = mesh.normals.map { SCNVector3($0.x, $0.y, $0.z) }
        let texCoords = mesh.textureCoordinates.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }

        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
        let texCoordSource = SCNGeometrySource(textureCoordinates: texCoords)

        // Create geometry element (indices)
        let indices = mesh.triangleIndices.map { Int32($0) }
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)

        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: mesh.triangleCount,
            bytesPerIndex: MemoryLayout<Int32>.size
        )

        // Create geometry
        return SCNGeometry(sources: [vertexSource, normalSource, texCoordSource], elements: [element])
    }
}

// MARK: - Full Preview with Controls

/// Full textured mesh preview with export options
public struct FullMeshPreviewView: View {
    let bakeResult: TextureBakeResult
    let metadata: FaceScanMetadata

    @State private var showingExportSheet = false
    @State private var selectedFormat: ExportManager.ExportFormat = .obj
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var showingExportResult = false

    public init(bakeResult: TextureBakeResult, metadata: FaceScanMetadata) {
        self.bakeResult = bakeResult
        self.metadata = metadata
    }

    public var body: some View {
        ZStack {
            TexturedMeshPreviewView(bakeResult: bakeResult)

            // Export button overlay
            VStack {
                HStack {
                    Spacer()

                    Button(action: { showingExportSheet = true }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .foregroundColor(.white)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                    }
                    .padding()
                }

                Spacer()
            }
        }
        .actionSheet(isPresented: $showingExportSheet) {
            ActionSheet(
                title: Text("Export Format"),
                message: Text("Choose export format for textured mesh"),
                buttons: [
                    .default(Text("OBJ + MTL + PNG")) {
                        selectedFormat = .obj
                        exportMesh()
                    },
                    .default(Text("glTF 2.0 + PNG")) {
                        selectedFormat = .gltf
                        exportMesh()
                    },
                    .default(Text("USDZ (iOS native)")) {
                        selectedFormat = .usdz
                        exportMesh()
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingExportResult) {
            if let url = exportURL {
                ExportResultView(exportURL: url.deletingLastPathComponent())
            }
        }
        .overlay {
            if isExporting {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)

                        Text("Exporting mesh...")
                            .foregroundColor(.white)
                    }
                    .padding(40)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                }
            }
        }
        .alert("Export Error", isPresented: .constant(exportError != nil)) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "Unknown error")
        }
    }

    private func exportMesh() {
        isExporting = true

        Task {
            do {
                let url = try ExportManager.exportMesh(
                    bakeResult,
                    metadata: metadata,
                    format: selectedFormat
                )

                await MainActor.run {
                    exportURL = url
                    isExporting = false
                    showingExportResult = true
                }

                print("✅ Export complete: \(url.path)")

            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }
}
