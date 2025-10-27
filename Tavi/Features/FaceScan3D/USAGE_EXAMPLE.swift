//
//  USAGE_EXAMPLE.swift
//  Tavi
//
//  Examples of how to use FaceScan3D module
//  This file is for documentation only - not compiled
//

import SwiftUI

// MARK: - Example 1: Basic Usage

struct BasicFaceScanExample: View {
    var body: some View {
        FaceScan3DView()
    }
}

// MARK: - Example 2: With Debug Info

struct DebugFaceScanExample: View {
    var body: some View {
        FaceScan3DView(
            showDebug: true,
            showMesh: true,
            meshColor: .white,
            wireframeMode: false
        )
    }
}

// MARK: - Example 3: Capture Geometry Data

struct GeometryCaptureExample: View {
    @State private var capturedVertices: [SIMD3<Float>] = []

    var body: some View {
        VStack {
            FaceScan3DView { geometry in
                // Access geometry data in real-time
                capturedVertices = geometry.vertices

                // Print stats
                print("Captured \(geometry.vertexCount) vertices")
                print("Triangle count: \(geometry.triangleCount)")

                // Access specific data
                if let firstVertex = geometry.vertices.first {
                    print("First vertex: \(firstVertex)")
                }

                // Access normals
                for normal in geometry.normals.prefix(5) {
                    print("Normal: \(normal)")
                }
            }

            Text("Vertices: \(capturedVertices.count)")
                .padding()
        }
    }
}

// MARK: - Example 4: Export to OBJ

struct OBJExportExample: View {
    @StateObject private var viewModel = FaceScan3DViewModel()
    @State private var showingExport = false

    var body: some View {
        ZStack {
            FaceScan3DView(showDebug: true)

            VStack {
                Spacer()

                Button("Export OBJ") {
                    if let obj = viewModel.exportToOBJ() {
                        // Save to file
                        saveOBJ(obj)
                        showingExport = true
                    }
                }
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .cornerRadius(12)
                .padding()
            }
        }
        .alert("Exported", isPresented: $showingExport) {
            Button("OK") { }
        } message: {
            Text("Face mesh exported as OBJ file")
        }
    }

    private func saveOBJ(_ content: String) {
        // Save to documents directory
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        let filename = "face_mesh_\(Date().timeIntervalSince1970).obj"
        let fileURL = documentsPath.appendingPathComponent(filename)

        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        print("Saved to: \(fileURL.path)")
    }
}

// MARK: - Example 5: Access Light Estimation

struct LightEstimationExample: View {
    @StateObject private var viewModel = FaceScan3DViewModel()

    var body: some View {
        ZStack {
            FaceScan3DView(showDebug: false)

            VStack {
                if let light = viewModel.lightEstimation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Light Info")
                            .font(.headline)

                        Text("Intensity: \(Int(light.ambientIntensity))")
                        Text("Temperature: \(Int(light.ambientColorTemperature))K")

                        if let direction = light.primaryLightDirection {
                            Text("Direction: (\(String(format: "%.2f", direction.x)), \(String(format: "%.2f", direction.y)), \(String(format: "%.2f", direction.z)))")
                        }

                        if let intensity = light.primaryLightIntensity {
                            Text("Primary Light: \(Int(intensity))")
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding()
                }

                Spacer()
            }
        }
    }
}

// MARK: - Example 6: Access Blend Shapes

struct BlendShapesExample: View {
    @StateObject private var viewModel = FaceScan3DViewModel()
    @State private var isSmiling = false
    @State private var isBlinking = false

    // Computed properties for smile and blink detection
    private var smileAmount: Float {
        guard let blendShapes = viewModel.blendShapes else { return 0 }
        return (blendShapes.mouthSmileLeft + blendShapes.mouthSmileRight) / 2
    }

    private var blinkAmount: Float {
        guard let blendShapes = viewModel.blendShapes else { return 0 }
        return (blendShapes.eyeBlinkLeft + blendShapes.eyeBlinkRight) / 2
    }

    var body: some View {
        ZStack {
            FaceScan3DView()

            VStack {
                if let blendShapes = viewModel.blendShapes {
                    blendShapesInfo(blendShapes: blendShapes)
                }

                Spacer()

                // Show feedback
                if isSmiling {
                    Text("😊 Smiling!")
                        .font(.title)
                        .padding()
                }

                if isBlinking {
                    Text("😑 Blinking")
                        .font(.title)
                        .padding()
                }
            }
        }
        .onChange(of: smileAmount) { newValue in
            isSmiling = newValue > 0.5
        }
        .onChange(of: blinkAmount) { newValue in
            isBlinking = newValue > 0.8
        }
    }

    // Separate view for blend shapes info
    private func blendShapesInfo(blendShapes: FaceBlendShapes) -> some View {
        let smileVal = (blendShapes.mouthSmileLeft + blendShapes.mouthSmileRight) / 2
        let blinkVal = (blendShapes.eyeBlinkLeft + blendShapes.eyeBlinkRight) / 2

        return VStack(alignment: .leading, spacing: 8) {
            Text("Face Expressions")
                .font(.headline)

            // Smile
            HStack {
                Text("Smile:")
                ProgressView(value: Double(smileVal))
                Text("\(Int(smileVal * 100))%")
            }

            // Blink
            HStack {
                Text("Blink:")
                ProgressView(value: Double(blinkVal))
                Text("\(Int(blinkVal * 100))%")
            }

            // Jaw open
            HStack {
                Text("Jaw Open:")
                ProgressView(value: Double(blendShapes.jawOpen))
                Text("\(Int(blendShapes.jawOpen * 100))%")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding()
    }
}

// MARK: - Example 7: Custom Mesh Color

struct CustomMeshColorExample: View {
    @State private var hue: Double = 0.0

    var body: some View {
        VStack {
            FaceScan3DView(
                showMesh: true,
                meshColor: Color(hue: hue, saturation: 0.8, brightness: 0.9),
                wireframeMode: false
            )

            HStack {
                Text("Mesh Color")
                Slider(value: $hue, in: 0...1)
            }
            .padding()
            .background(.ultraThinMaterial)
            .padding()
        }
    }
}

// MARK: - Example 8: Integration with Existing Camera

struct IntegratedExample: View {
    @State private var showFaceScan = false

    var body: some View {
        NavigationStack {
            VStack {
                // Your existing camera view
                CameraView()

                // Button to switch to 3D scan
                Button("Switch to 3D Face Scan") {
                    showFaceScan = true
                }
                .padding()
            }
            .sheet(isPresented: $showFaceScan) {
                FaceScan3DView(showDebug: true)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showFaceScan = false
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Example 9: Process Geometry for Analysis

struct GeometryAnalysisExample: View {
    @State private var faceWidth: Float = 0
    @State private var faceHeight: Float = 0
    @State private var faceDepth: Float = 0

    var body: some View {
        ZStack {
            FaceScan3DView { geometry in
                // Calculate bounding box
                var minX: Float = .infinity
                var maxX: Float = -.infinity
                var minY: Float = .infinity
                var maxY: Float = -.infinity
                var minZ: Float = .infinity
                var maxZ: Float = -.infinity

                for vertex in geometry.vertices {
                    minX = min(minX, vertex.x)
                    maxX = max(maxX, vertex.x)
                    minY = min(minY, vertex.y)
                    maxY = max(maxY, vertex.y)
                    minZ = min(minZ, vertex.z)
                    maxZ = max(maxZ, vertex.z)
                }

                faceWidth = maxX - minX
                faceHeight = maxY - minY
                faceDepth = maxZ - minZ
            }

            VStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Face Dimensions")
                        .font(.headline)

                    Text("Width: \(String(format: "%.3f", faceWidth))m")
                    Text("Height: \(String(format: "%.3f", faceHeight))m")
                    Text("Depth: \(String(format: "%.3f", faceDepth))m")
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding()

                Spacer()
            }
        }
    }
}

// MARK: - Example 10: Multi-View with FaceScan3D

struct MultiViewExample: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CameraView()
                .tabItem {
                    Label("2D Camera", systemImage: "camera")
                }
                .tag(0)

            FaceScan3DView(showDebug: true)
                .tabItem {
                    Label("3D Scan", systemImage: "face.smiling")
                }
                .tag(1)
        }
    }
}
