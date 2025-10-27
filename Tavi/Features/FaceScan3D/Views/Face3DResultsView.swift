//
//  Face3DResultsView.swift
//  Tavi
//
//  Display Face3DMetrics with interactive 3D viewer and score cards
//  Created on 2025-10-27.
//

import SwiftUI
import SceneKit

/// Results view for displaying Face3DMetrics
public struct Face3DResultsView: View {

    let metrics: Face3DMetrics
    let texturedMesh: TextureBakeResult?

    @State private var selectedMetricType: MetricType = .roughness
    @State private var showOriginal: Bool = false
    @State private var selectedROI: FaceROI? = nil
    @State private var show3DView: Bool = true

    public init(metrics: Face3DMetrics, texturedMesh: TextureBakeResult? = nil) {
        self.metrics = metrics
        self.texturedMesh = texturedMesh
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Overall Score Card
                overallScoreSection

                // 3D Viewer Section
                if show3DView, let mesh = texturedMesh {
                    threeDViewerSection(mesh: mesh)
                }

                // Global Scores Grid
                globalScoresSection

                // Per-ROI Scores
                perROIScoresSection

                // Quality Information
                qualityInfoSection
            }
            .padding()
        }
        .navigationTitle("3D Scan Results")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Overall Score Section

    private var overallScoreSection: some View {
        CardView {
            VStack(spacing: 16) {
                Text("Overall Skin Quality")
                    .font(.headline)

                HStack(spacing: 24) {
                    // Circular Progress
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 12)

                        Circle()
                            .trim(from: 0, to: CGFloat(metrics.overallScore / 100.0))
                            .stroke(scoreColor(metrics.overallScore), lineWidth: 12)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 4) {
                            Text(String(format: "%.0f%%", metrics.overallScore))
                                .font(.system(size: 36, weight: .bold))

                            Text("Overall")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 100, height: 100)

                    // Interpretation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Grade")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(metrics.scoreInterpretation)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor(metrics.overallScore))

                        if !metrics.isHighQuality {
                            Label("Quality Warning", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 3D Viewer Section

    private func threeDViewerSection(mesh: TextureBakeResult) -> some View {
        CardView {
            VStack(spacing: 12) {
                HStack {
                    Text("3D Model Viewer")
                        .font(.headline)

                    Spacer()

                    Picker("View Mode", selection: $showOriginal) {
                        Text("Texture").tag(false)
                        Text("Heatmap").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                if !showOriginal {
                    // SceneKit view with textured mesh
                    SceneKitView(mesh: mesh, overlayType: selectedMetricType)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Heatmap overlay toggle
                    Text("Heatmap overlay - Not implemented yet")
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Metric type selector for heatmap
                if showOriginal {
                    Picker("Metric", selection: $selectedMetricType) {
                        Text("Roughness").tag(MetricType.roughness)
                        Text("Pigmentation").tag(MetricType.pigmentation)
                        Text("Luminance").tag(MetricType.luminance)
                        Text("Lightness").tag(MetricType.lightness)
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    // MARK: - Global Scores Section

    private var globalScoresSection: some View {
        VStack(spacing: 12) {
            Text("Global Metrics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ScoreCard(
                    title: "Smoothness",
                    score: metrics.globalRoughnessScore,
                    icon: "waveform.path",
                    explanation: "Your smoothness score is \(Int(metrics.globalRoughnessScore))%. Higher percentage means smoother skin texture."
                )

                ScoreCard(
                    title: "Pigmentation",
                    score: metrics.globalPigmentationScore,
                    icon: "paintpalette",
                    explanation: "Your pigmentation score is \(Int(metrics.globalPigmentationScore))%. Higher percentage means more even skin tone."
                )

                ScoreCard(
                    title: "Discoloration",
                    score: metrics.globalDiscolorationScore,
                    icon: "circle.lefthalf.filled",
                    explanation: "Your discoloration score is \(Int(metrics.globalDiscolorationScore))%. Higher percentage means more uniform color across your face."
                )

                if let specularScore = metrics.globalSpecularScore {
                    ScoreCard(
                        title: "Oil Control",
                        score: specularScore,
                        icon: "drop",
                        explanation: "Your oil control score is \(Int(specularScore))%. Higher percentage means less oily skin."
                    )
                }
            }
        }
    }

    // MARK: - Per-ROI Scores Section

    private var perROIScoresSection: some View {
        VStack(spacing: 12) {
            Text("Regional Analysis")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(metrics.sortedROIMetrics, id: \.0) { (roi, roiMetrics) in
                ROIScoreRow(roi: roi, metrics: roiMetrics, isSelected: selectedROI == roi)
                    .onTapGesture {
                        withAnimation {
                            selectedROI = selectedROI == roi ? nil : roi
                        }
                    }
            }
        }
    }

    // MARK: - Quality Info Section

    private var qualityInfoSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Scan Information")
                    .font(.headline)

                InfoRow(label: "Texture Quality", value: metrics.textureQuality ?? "N/A")
                InfoRow(label: "Vertices", value: "\(metrics.vertexCount)")
                InfoRow(label: "Triangles", value: "\(metrics.triangleCount)")
                InfoRow(label: "Texture Size", value: "\(Int(metrics.textureResolution.width))x\(Int(metrics.textureResolution.height))")
                InfoRow(label: "Processing Time", value: String(format: "%.2fs", metrics.processingTime))

                if !metrics.lowConfidenceROIs.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Low Confidence ROIs", systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundColor(.orange)

                        Text(metrics.lowConfidenceROIs.map { $0.displayName }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("These regions were excluded from global metrics due to insufficient data.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Float) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }
}

// MARK: - Score Card

struct ScoreCard: View {
    let title: String
    let score: Float
    let icon: String
    let explanation: String

    @State private var showExplanation = false

    var body: some View {
        CardView {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(scoreColor)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(String(format: "%.0f%%", score))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor)

                // Explanation button
                Button {
                    showExplanation.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .popover(isPresented: $showExplanation) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(width: 250)
        }
    }

    private var scoreColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }
}

// MARK: - ROI Score Row

struct ROIScoreRow: View {
    let roi: FaceROI
    let metrics: ROIMetrics
    let isSelected: Bool

    var body: some View {
        CardView {
            VStack(spacing: 12) {
                HStack {
                    Text(roi.displayName)
                        .font(.headline)

                    Spacer()

                    if metrics.isLowConfidence {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }

                    Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if isSelected {
                    Divider()

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Smoothness")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0f%%", metrics.roughnessScore))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pigmentation")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0f%%", metrics.pigmentationScore))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        if let specularScore = metrics.specularScore {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Oil Control")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.0f%%", specularScore))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    // Raw metrics
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Raw Metrics")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Pixels: \(metrics.pixelCount) | Confidence: \(metrics.confidenceLevel)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - SceneKit View

struct SceneKitView: UIViewRepresentable {
    let mesh: TextureBakeResult
    let overlayType: MetricType

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = createScene()
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = .systemBackground
        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update scene if needed
    }

    private func createScene() -> SCNScene {
        let scene = SCNScene()

        // Create face mesh node
        if let meshNode = createMeshNode(from: mesh) {
            scene.rootNode.addChildNode(meshNode)
        }

        // Add camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 0.5)
        scene.rootNode.addChildNode(cameraNode)

        return scene
    }

    private func createMeshNode(from bakeResult: TextureBakeResult) -> SCNNode? {
        let unifiedMesh = bakeResult.unifiedMesh

        // Create geometry source for vertices
        let vertexData = Data(bytes: unifiedMesh.vertices, count: unifiedMesh.vertices.count * MemoryLayout<Vector3>.stride)
        let vertexSource = SCNGeometrySource(
            data: vertexData,
            semantic: .vertex,
            vectorCount: unifiedMesh.vertices.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Vector3>.stride
        )

        // Create geometry source for texture coordinates
        let texCoordData = Data(bytes: unifiedMesh.textureCoordinates, count: unifiedMesh.textureCoordinates.count * MemoryLayout<Vector2>.stride)
        let texCoordSource = SCNGeometrySource(
            data: texCoordData,
            semantic: .texcoord,
            vectorCount: unifiedMesh.textureCoordinates.count,
            usesFloatComponents: true,
            componentsPerVector: 2,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Vector2>.stride
        )

        // Create geometry element for indices
        let indexData = Data(bytes: unifiedMesh.triangleIndices, count: unifiedMesh.triangleIndices.count * MemoryLayout<UInt16>.stride)
        let geometryElement = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: unifiedMesh.triangleIndices.count / 3,
            bytesPerIndex: MemoryLayout<UInt16>.size
        )

        // Create geometry
        let geometry = SCNGeometry(sources: [vertexSource, texCoordSource], elements: [geometryElement])

        // Create material with texture
        let material = SCNMaterial()
        material.diffuse.contents = UIImage(cgImage: bakeResult.albedoTexture)
        material.lightingModel = .physicallyBased
        geometry.materials = [material]

        // Create node
        let node = SCNNode(geometry: geometry)
        return node
    }
}

// MARK: - Metric Type

public enum MetricType {
    case roughness
    case pigmentation
    case luminance
    case lightness
}

// MARK: - Preview

#Preview {
    NavigationStack {
        // Create dummy metrics for preview (0-100% scale)
        let dummyMetrics = Face3DMetrics(
            roiMetrics: [
                .forehead: ROIMetrics(
                    roi: .forehead,
                    roughnessProxy: 0.15,
                    pigmentationIndex: 0.08,
                    specularProxy: 0.12,
                    pixelCount: 450,
                    averageLuminance: 0.65,
                    averageLightness: 68.0,
                    averageAChannel: 8.5,
                    averageBChannel: 12.3,
                    roughnessScore: 75.0,
                    pigmentationScore: 82.0,
                    specularScore: 78.0,
                    isLowConfidence: false,
                    confidenceLevel: "High"
                )
            ],
            globalRoughnessProxy: 0.15,
            globalPigmentationIndex: 0.08,
            globalDiscolorationIndex: 0.05,
            globalSpecularProxy: 0.12,
            globalAverageLuminance: 0.65,
            globalRoughnessScore: 75.0,
            globalPigmentationScore: 82.0,
            globalDiscolorationScore: 85.0,
            globalSpecularScore: 78.0,
            overallScore: 79.0,
            scoreInterpretation: "Very Good",
            vertexCount: 1220,
            triangleCount: 2304,
            textureResolution: CGSize(width: 1024, height: 1024),
            processingTime: 2.35,
            textureQuality: "Good quality (variance: 125.3)",
            lowConfidenceROIs: [],
            isHighQuality: true
        )

        Face3DResultsView(metrics: dummyMetrics, texturedMesh: nil)
    }
}
