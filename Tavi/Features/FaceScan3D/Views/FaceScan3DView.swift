//
//  FaceScan3DView.swift
//  Tavi
//
//  SwiftUI wrapper for ARKit face scanning
//  Created on 2025-10-27.
//

import SwiftUI
import ARKit

/// SwiftUI view that displays real-time 3D face mesh using ARKit
public struct FaceScan3DView: View {
    @StateObject private var viewModel = FaceScan3DViewModel()

    /// Whether to show debug information
    public var showDebug: Bool = false

    /// Whether to show the face mesh
    public var showMesh: Bool = true

    /// Mesh color
    public var meshColor: Color = .white

    /// Whether to use wireframe mode
    public var wireframeMode: Bool = false

    /// Whether to show calibration overlay
    public var showCalibration: Bool = true

    /// Callback when geometry is updated
    public var onGeometryUpdate: ((FaceMeshGeometry) -> Void)?

    /// Callback when all poses are captured
    public var onCaptureComplete: (([GuidanceStep: CapturedPoseData]) -> Void)?

    public init(
        showDebug: Bool = false,
        showMesh: Bool = true,
        meshColor: Color = .white,
        wireframeMode: Bool = false,
        showCalibration: Bool = true,
        onGeometryUpdate: ((FaceMeshGeometry) -> Void)? = nil,
        onCaptureComplete: (([GuidanceStep: CapturedPoseData]) -> Void)? = nil
    ) {
        self.showDebug = showDebug
        self.showMesh = showMesh
        self.meshColor = meshColor
        self.wireframeMode = wireframeMode
        self.showCalibration = showCalibration
        self.onGeometryUpdate = onGeometryUpdate
        self.onCaptureComplete = onCaptureComplete
    }

    public var body: some View {
        ZStack {
            // ARKit face tracking view
            ARFaceTrackingViewRepresentable(
                viewModel: viewModel,
                showMesh: showMesh,
                meshColor: UIColor(meshColor),
                wireframeMode: wireframeMode
            )
            .ignoresSafeArea()

            // Calibration and guidance overlay
            if showCalibration {
                CalibrationOverlay(viewModel: viewModel)
            }

            // Debug overlay
            if showDebug {
                VStack {
                    HStack {
                        DebugInfoView(viewModel: viewModel)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .padding()

                        Spacer()
                    }

                    Spacer()
                }
            }

            // Error message
            if let errorMessage = viewModel.errorMessage {
                VStack {
                    Spacer()
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.red.opacity(0.8))
                        .cornerRadius(12)
                        .padding()
                }
            }
        }
        .onChange(of: viewModel.currentGeometry) { _, newGeometry in
            if let geometry = newGeometry {
                onGeometryUpdate?(geometry)
            }
        }
        .onChange(of: viewModel.capturedPoses.count) { oldCount, newCount in
            // Check if capture is complete
            if newCount == GuidanceStep.allCases.count && newCount > oldCount {
                onCaptureComplete?(viewModel.capturedPoses)
            }
        }
    }
}

// MARK: - ARKit View Representable

struct ARFaceTrackingViewRepresentable: UIViewControllerRepresentable {
    let viewModel: FaceScan3DViewModel
    let showMesh: Bool
    let meshColor: UIColor
    let wireframeMode: Bool

    func makeUIViewController(context: Context) -> ARFaceTrackingViewController {
        let controller = ARFaceTrackingViewController()
        controller.viewModel = viewModel
        controller.showDebugMesh = showMesh
        controller.setMeshColor(meshColor)
        controller.setWireframeMode(wireframeMode)
        return controller
    }

    func updateUIViewController(_ uiViewController: ARFaceTrackingViewController, context: Context) {
        uiViewController.showDebugMesh = showMesh
        uiViewController.setMeshColor(meshColor)
        uiViewController.setWireframeMode(wireframeMode)
    }
}

// MARK: - Debug Info View

struct DebugInfoView: View {
    @ObservedObject var viewModel: FaceScan3DViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("3D Face Scan Debug")
                .font(.headline)
                .foregroundStyle(.white)

            Divider()
                .background(.white.opacity(0.3))

            HStack {
                Circle()
                    .fill(viewModel.faceDetected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text("Face: \(viewModel.faceDetected ? "Detected" : "Not Found")")
                    .font(.caption)
                    .foregroundStyle(.white)
            }

            Text("FPS: \(String(format: "%.1f", viewModel.currentFPS))")
                .font(.caption)
                .foregroundStyle(.white)

            if let geometry = viewModel.currentGeometry {
                Text("Vertices: \(geometry.vertexCount)")
                    .font(.caption)
                    .foregroundStyle(.white)

                Text("Triangles: \(geometry.triangleCount)")
                    .font(.caption)
                    .foregroundStyle(.white)
            }

            if let light = viewModel.lightEstimation {
                Divider()
                    .background(.white.opacity(0.3))

                Text("Light Intensity: \(Int(light.ambientIntensity))")
                    .font(.caption)
                    .foregroundStyle(.white)

                Text("Color Temp: \(Int(light.ambientColorTemperature))K")
                    .font(.caption)
                    .foregroundStyle(.white)
            }

            if let blendShapes = viewModel.blendShapes {
                Divider()
                    .background(.white.opacity(0.3))

                Text("Eye Blink L: \(String(format: "%.2f", blendShapes.eyeBlinkLeft))")
                    .font(.caption)
                    .foregroundStyle(.white)

                Text("Eye Blink R: \(String(format: "%.2f", blendShapes.eyeBlinkRight))")
                    .font(.caption)
                    .foregroundStyle(.white)

                Text("Jaw Open: \(String(format: "%.2f", blendShapes.jawOpen))")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FaceScan3DView(showDebug: true)
}
