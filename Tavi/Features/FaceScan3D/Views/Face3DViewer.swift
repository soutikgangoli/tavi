//
//  Face3DViewer.swift
//  Tavi
//
//  Interactive 3D viewer for face mesh with metric overlays
//  Created on 2025-10-27.
//

import SwiftUI
import SceneKit

/// Interactive 3D viewer for face mesh with metric overlays
public struct Face3DViewer: View {
    @ObservedObject var viewModel: FaceScan3DViewModel

    @State private var selectedOverlay: OverlayType? = nil
    @State private var showOverlay: Bool = true
    @State private var rotationEnabled: Bool = true

    public init(viewModel: FaceScan3DViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 3D Scene
            ZStack {
                SceneView(
                    scene: createScene(),
                    options: [.allowsCameraControl, .autoenablesDefaultLighting]
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Overlay controls
                VStack {
                    Spacer()

                    overlayControls
                        .padding()
                }
            }
        }
        .navigationTitle("3D View")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Overlay Controls

    private var overlayControls: some View {
        VStack(spacing: 12) {
            // Overlay toggle
            Toggle("Show Overlay", isOn: $showOverlay)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)

            // Overlay type selector
            if showOverlay {
                HStack(spacing: 8) {
                    overlayButton("Roughness", type: .roughness, icon: "waveform.path")
                    overlayButton("Pigmentation", type: .pigmentation, icon: "paintpalette")
                    overlayButton("Discoloration", type: .discoloration, icon: "face.smiling")

                    if viewModel.face3DMetrics?.globalSpecularProxy != nil {
                        overlayButton("Specular", type: .specular, icon: "sparkles")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
            }
        }
    }

    private func overlayButton(_ title: String, type: OverlayType, icon: String) -> some View {
        Button(action: {
            selectedOverlay = selectedOverlay == type ? nil : type
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selectedOverlay == type ? Color.blue : Color.clear)
            .foregroundColor(selectedOverlay == type ? .white : .primary)
            .cornerRadius(6)
        }
    }

    // MARK: - Scene Creation

    private func createScene() -> SCNScene {
        let scene = SCNScene()

        // Add camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 0.3)
        scene.rootNode.addChildNode(cameraNode)

        // Add mesh if available
        if let meshNode = createMeshNode() {
            scene.rootNode.addChildNode(meshNode)
        }

        return scene
    }

    private func createMeshNode() -> SCNNode? {
        guard let result = viewModel.bakeResult else {
            return nil
        }

        let mesh = result.unifiedMesh

        // Create geometry
        let geometry = createGeometry(from: mesh)

        // Apply texture (with overlay if enabled)
        if showOverlay, let overlayType = selectedOverlay {
            applyOverlayTexture(to: geometry, type: overlayType, baseTexture: result.albedoTexture)
        } else {
            applyBaseTexture(to: geometry, texture: result.albedoTexture)
        }

        // Create node
        let node = SCNNode(geometry: geometry)

        // Position and scale
        node.position = SCNVector3(x: 0, y: 0, z: 0)
        node.scale = SCNVector3(x: 1, y: 1, z: 1)

        return node
    }

    private func createGeometry(from mesh: UnifiedMesh) -> SCNGeometry {
        // Extract vertex positions
        var vertices = [SCNVector3]()
        for i in 0..<mesh.vertexCount {
            let pos = mesh.vertices[i]
            vertices.append(SCNVector3(pos.x, pos.y, pos.z))
        }

        // Extract normals
        var normals = [SCNVector3]()
        for i in 0..<mesh.vertexCount {
            let normal = mesh.normals[i]
            normals.append(SCNVector3(normal.x, normal.y, normal.z))
        }

        // Extract texture coordinates
        var texCoords = [CGPoint]()
        for i in 0..<mesh.vertexCount {
            let uv = mesh.textureCoordinates[i]
            texCoords.append(CGPoint(x: CGFloat(uv.x), y: CGFloat(uv.y)))
        }

        // Create geometry sources
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

    private func applyBaseTexture(to geometry: SCNGeometry, texture: CGImage) {
        let material = SCNMaterial()
        material.diffuse.contents = UIImage(cgImage: texture)
        material.isDoubleSided = true
        geometry.materials = [material]
    }

    private func applyOverlayTexture(to geometry: SCNGeometry, type: OverlayType, baseTexture: CGImage) {
        guard let metrics = viewModel.face3DMetrics else {
            applyBaseTexture(to: geometry, texture: baseTexture)
            return
        }

        let generator = HeatmapOverlayGenerator()

        // Generate overlay
        let overlayTexture: CGImage?

        switch type {
        case .discoloration:
            // Use discoloration overlay
            if let discolImage = generator.generateDiscolorationOverlay(
                metrics: metrics,
                resolution: CGSize(width: baseTexture.width, height: baseTexture.height)
            )?.cgImage {
                overlayTexture = generator.generateHeatmapOverlay(
                    baseTexture,
                    intensityMap: discolImage,
                    mask: nil
                )
            } else {
                overlayTexture = nil
            }

        case .roughness, .pigmentation, .specular:
            // Use intensity map
            let metricType: MetricType
            switch type {
            case .roughness:
                metricType = .roughness
            case .pigmentation:
                metricType = .pigmentation
            case .specular:
                metricType = .specular
            default:
                metricType = .roughness
            }

            if let intensityMap = generator.generateIntensityMap(
                metrics: metrics,
                type: metricType,
                resolution: CGSize(width: baseTexture.width, height: baseTexture.height)
            ) {
                overlayTexture = generator.generateHeatmapOverlay(
                    baseTexture,
                    intensityMap: intensityMap,
                    mask: nil
                )
            } else {
                overlayTexture = nil
            }
        }

        if let overlayTexture = overlayTexture {
            let material = SCNMaterial()
            material.diffuse.contents = UIImage(cgImage: overlayTexture)
            material.isDoubleSided = true
            geometry.materials = [material]
        } else {
            applyBaseTexture(to: geometry, texture: baseTexture)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct Face3DViewer_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            Face3DViewer(viewModel: FaceScan3DViewModel())
        }
    }
}
#endif
