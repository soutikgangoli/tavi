//
//  FaceScan3DDemoView.swift
//  Ollvy
//
//  Demo view showing FaceScan3D usage
//  Created on 2025-10-27.
//

import SwiftUI

/// Demo view showing how to use FaceScan3DView with calibration
struct FaceScan3DDemoView: View {
    @StateObject private var viewModel = FaceScan3DViewModel()
    @State private var showDebug = false
    @State private var showMesh = true
    @State private var wireframeMode = false
    @State private var meshColor: Color = .white
    @State private var showCalibration = true
    @State private var currentVertexCount: Int = 0
    @State private var capturedPosesCount: Int = 0
    @State private var showingSuccessAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 3D Face Scan View with Calibration
                FaceScan3DView(
                    viewModel: viewModel,
                    showDebug: showDebug,
                    showMesh: showMesh,
                    meshColor: meshColor,
                    wireframeMode: wireframeMode,
                    showCalibration: showCalibration,
                    onGeometryUpdate: { geometry in
                        currentVertexCount = geometry.vertexCount
                    },
                    onCaptureComplete: { capturedPoses in
                        capturedPosesCount = capturedPoses.count
                        showingSuccessAlert = true
                    }
                )
                .ignoresSafeArea()

                // Settings button
                VStack {
                    HStack {
                        Spacer()

                        Menu {
                            Toggle("Show Debug", isOn: $showDebug)
                            Toggle("Show Mesh", isOn: $showMesh)
                            Toggle("Wireframe Mode", isOn: $wireframeMode)
                            Toggle("Show Calibration", isOn: $showCalibration)

                            Divider()

                            ColorPicker("Mesh Color", selection: $meshColor)
                        } label: {
                            Image(systemName: "gear")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding()
                    }

                    Spacer()
                }
            }
            .navigationTitle("3D Face Scan")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Scan Complete!", isPresented: $showingSuccessAlert) {
                Button("OK") { }
            } message: {
                Text("Successfully captured \(capturedPosesCount) poses")
            }
        }
    }
}

#Preview {
    FaceScan3DDemoView()
}
