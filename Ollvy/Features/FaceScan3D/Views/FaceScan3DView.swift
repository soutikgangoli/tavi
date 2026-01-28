//
//  FaceScan3DView.swift
//  Ollvy
//
//  SwiftUI wrapper for ARKit face scanning
//  Created on 2025-10-27.
//

import SwiftUI
import ARKit

/// SwiftUI view that displays real-time 3D face mesh using ARKit
public struct FaceScan3DView: View {
    @ObservedObject var viewModel: FaceScan3DViewModel

    /// Whether to show debug information
    public var showDebug: Bool = false

    /// Whether to show the face mesh
    public var showMesh: Bool = true

    /// Mesh color
    public var meshColor: Color = .white

    /// Whether to use wireframe mode
    public var wireframeMode: Bool = true

    /// Whether to show calibration overlay
    public var showCalibration: Bool = true

    /// Callback when geometry is updated
    public var onGeometryUpdate: ((FaceMeshGeometry) -> Void)?

    /// Callback when all poses are captured
    public var onCaptureComplete: (([GuidanceStep: CapturedPoseData]) -> Void)?

    @AppStorage(AppDefaultsKey.enableFaceMesh) private var enableFaceMesh: Bool = true
    @State private var errorState: ErrorState?

    public init(
        viewModel: FaceScan3DViewModel,
        showDebug: Bool = false,
        showMesh: Bool = true,
        meshColor: Color = .white,
        wireframeMode: Bool = false,
        showCalibration: Bool = true,
        onGeometryUpdate: ((FaceMeshGeometry) -> Void)? = nil,
        onCaptureComplete: (([GuidanceStep: CapturedPoseData]) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.showDebug = showDebug
        self.showMesh = showMesh
        self.meshColor = meshColor
        self.wireframeMode = wireframeMode
        self.showCalibration = showCalibration
        self.onGeometryUpdate = onGeometryUpdate
        self.onCaptureComplete = onCaptureComplete
    }

    public var body: some View {
        Group {
            if let error = errorState {
                errorView(error)
            } else {
                contentView
            }
        }
        .onChange(of: viewModel.currentGeometry) { _, newGeometry in
            handleGeometryUpdate(newGeometry)
        }
        .onChange(of: viewModel.capturedPoses.count) { _, newCount in
            handleCaptureProgress(newCount)
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        ZStack {
            // ARKit face tracking view
            // Show mesh during guidance to visualize 3D face geometry (if settings enabled)
            ARFaceTrackingViewRepresentable(
                viewModel: viewModel,
                showMesh: showMesh && enableFaceMesh,
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
                            .cornerRadius(Designs.Radius.medium)
                            .padding()

                        Spacer()
                    }

                    Spacer()
                }
            }

            // Error message with Continue Anyway option
            if let errorMessage = viewModel.errorMessage {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Button {
                            viewModel.continueAnywayOverride = true
                        } label: {
                            Text("Continue Anyway")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.orange)
                                .cornerRadius(Designs.Radius.small)
                        }
                        .accessibilityLabel("Continue scan anyway despite warning")
                    }
                    .padding()
                    .background(.red.opacity(Designs.Opacity.semiTransparent))
                    .cornerRadius(Designs.Radius.medium)
                    .padding()
                }
            }
        }
    }

    // MARK: - Error View

    private func errorView(_ error: ErrorState) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.app(size: 60))
                .foregroundColor(.orange)

            Text("Scan Error")
                .font(.title2)
                .fontWeight(.semibold)

            Text(error.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                errorState = nil
            } label: {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top)
        }
        .padding()
    }

    // MARK: - Event Handlers

    private func handleGeometryUpdate(_ newGeometry: FaceMeshGeometry?) {
        if let geometry = newGeometry {
            onGeometryUpdate?(geometry)
        }
    }

    private func handleCaptureProgress(_ newCount: Int) {
        // Complete when all active poses are captured
        let totalPosesRequired = GuidanceStep.activePoses.count
        if newCount >= totalPosesRequired {
            AppLogger.faceScan.info("✅ All active poses captured (\(newCount)/\(totalPosesRequired)) - starting processing")
            onCaptureComplete?(viewModel.capturedPoses)
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error, context: String) {
        AppLogger.ui.error("FaceScan3DView error (\(context)): \(error)")
        CrashReporter.shared.logError(error, context: ["view": "FaceScan3DView", "operation": context])
        errorState = ErrorState(
            message: "Unable to \(context). Please try again.",
            error: error
        )
    }

    private struct ErrorState {
        let message: String
        let error: Error
    }
}

// MARK: - ARKit View Representable

struct ARFaceTrackingViewRepresentable: UIViewControllerRepresentable {
    @ObservedObject var viewModel: FaceScan3DViewModel
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
        // CRITICAL FIX: Stop session IMMEDIATELY when cleanup flag is set
        // This is called by SwiftUI whenever @ObservedObject viewModel changes
        // By checking shouldStopSession here, we stop the AR session the instant
        // the cancel button sets the flag, not waiting for viewWillDisappear
        if viewModel.shouldStopSession || viewModel.isCleaningUp {
            uiViewController.stopSessionImmediately()
            return
        }

        uiViewController.showDebugMesh = showMesh
        uiViewController.setMeshColor(meshColor)
        uiViewController.setWireframeMode(wireframeMode)
    }
}

// MARK: - Debug Info View

private struct DebugInfoView: View {
    @ObservedObject var viewModel: FaceScan3DViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("3D Face Scan Debug")
                .font(.headline)
                .foregroundStyle(.white)

            Divider()
                .background(.white.opacity(Designs.Opacity.medium))

            HStack {
                Circle()
                    .fill(viewModel.faceDetected ? Color.green : Color.red)
                    .frame(width: Designs.Sizes.indicatorTiny, height: Designs.Sizes.indicatorTiny)
                Text("Face: \(viewModel.faceDetected ? "Detected" : "Not Found")")
                    .font(.caption)
                    .foregroundStyle(.white)
            }

            Text("FPS: \(String(format: "%.1f", viewModel.currentFPS))")
                .font(.caption)
                .foregroundStyle(.white)

            Divider()
                .background(.white.opacity(Designs.Opacity.medium))

            Text("Face Angles (ARKit)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text("Yaw: \(String(format: "%.1f°", viewModel.cachedYaw))")
                .font(.caption)
                .foregroundStyle(.white)

            Text("Pitch: \(String(format: "%.1f°", viewModel.cachedPitch))")
                .font(.caption)
                .foregroundStyle(.white)

            Text("Roll: \(String(format: "%.1f°", viewModel.cachedRoll))")
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
                    .background(.white.opacity(Designs.Opacity.medium))

                Text("Light Intensity: \(Int(light.ambientIntensity))")
                    .font(.caption)
                    .foregroundStyle(.white)

                Text("Color Temp: \(Int(light.ambientColorTemperature))K")
                    .font(.caption)
                    .foregroundStyle(.white)
            }

            if let blendShapes = viewModel.blendShapes {
                Divider()
                    .background(.white.opacity(Designs.Opacity.medium))

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
    FaceScan3DView(viewModel: FaceScan3DViewModel(), showDebug: true)
}
