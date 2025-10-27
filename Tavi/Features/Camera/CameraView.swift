//
//  CameraView.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var showingInfo = false
    @State private var showingCalibrationDetails = false
    @State private var showingCaptureResult = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview
                CameraPreviewView(viewModel: viewModel)
                    .ignoresSafeArea()

                // Face landmarks overlay
                if viewModel.showFaceLandmarks,
                   !viewModel.detectedFaces.isEmpty,
                   let imageSize = viewModel.getImageSize() {
                    FaceLandmarksOverlay(
                        faceResults: viewModel.detectedFaces,
                        imageSize: imageSize,
                        viewSize: geometry.size,
                        isMirrored: viewModel.currentCameraPosition == .front,
                        showDebugInfo: true
                    )
                    .ignoresSafeArea()
                }

                // ROI overlay
                if viewModel.showROIs,
                   !viewModel.faceROIs.isEmpty,
                   let imageSize = viewModel.getImageSize() {
                    ROIOverlay(
                        roiSets: viewModel.faceROIs,
                        imageSize: imageSize,
                        viewSize: geometry.size,
                        isMirrored: viewModel.currentCameraPosition == .front,
                        showLabels: true
                    )
                    .ignoresSafeArea()
                }

                // Clean calibration overlay matching 3D style
                if viewModel.isCapturing {
                    CameraCalibrationOverlay(
                        viewModel: viewModel,
                        onCapture: {
                            Task {
                                await viewModel.startMultiFrameCapture()
                                if viewModel.lastCaptureResult != nil {
                                    showingCaptureResult = true
                                }
                            }
                        }
                    )
                }

                // Minimal top controls (matches 3D style)
                if !viewModel.captureInProgress {
                    VStack {
                        HStack {
                            // Camera switch button
                            Button {
                                viewModel.switchCamera()
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath.camera")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .padding(12)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            .padding()

                            Spacer()

                            // Debug toggle button
                            Menu {
                                Button {
                                    viewModel.toggleFaceLandmarks()
                                } label: {
                                    Label(viewModel.showFaceLandmarks ? "Hide Landmarks" : "Show Landmarks", systemImage: "face.smiling")
                                }

                                Button {
                                    viewModel.toggleROIs()
                                } label: {
                                    Label(viewModel.showROIs ? "Hide ROIs" : "Show ROIs", systemImage: "rectangle.3.group")
                                }

                                Button {
                                    viewModel.toggleExposureLock()
                                } label: {
                                    Label(viewModel.isExposureLocked ? "Unlock Exposure" : "Lock Exposure", systemImage: viewModel.isExposureLocked ? "lock.fill" : "lock.open")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
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
            }

            // Landmark legend (only when enabled, minimal style)
            if viewModel.showFaceLandmarks && !viewModel.detectedFaces.isEmpty && !viewModel.captureInProgress {
                VStack {
                    HStack {
                        Spacer()
                        LandmarkLegend()
                            .padding()
                    }
                    Spacer()
                }
            }

            // ROI legend (only when enabled, minimal style)
            if viewModel.showROIs && !viewModel.faceROIs.isEmpty && !viewModel.captureInProgress {
                VStack {
                    HStack {
                        Spacer()
                        ROILegend()
                            .padding()
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
        .navigationTitle("2D Skin Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Automatically start camera when view appears
            viewModel.startCapture()
        }
        .onDisappear {
            // Stop camera when leaving the view
            viewModel.stopCapture()
        }
        .sheet(isPresented: $showingCaptureResult) {
            if let result = viewModel.lastCaptureResult {
                CaptureResultView(
                    result: result,
                    metrics: viewModel.lastMetricsResult,
                    scores: viewModel.lastScoreSummary,
                    isPresented: $showingCaptureResult
                )
            }
        }
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: View {
    @ObservedObject var viewModel: CameraViewModel

    var body: some View {
        ZStack {
            Color.black

            if let frame = viewModel.latestFrame {
                Image(uiImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    Text("Camera Preview")
                        .font(.headline)
                        .foregroundStyle(.gray)
                }
            }
        }
    }
}

// MARK: - Info Overlay

struct InfoOverlay: View {
    @Binding var isPresented: Bool
    let resolution: String
    let frameRate: String
    let cameraPosition: String
    let exposureLocked: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Camera Information")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white)
                            .font(.title2)
                    }
                }

                Divider()
                    .background(.white.opacity(0.3))

                CameraInfoRow(label: "Resolution", value: resolution)
                CameraInfoRow(label: "Frame Rate", value: frameRate)
                CameraInfoRow(label: "Camera", value: cameraPosition)
                CameraInfoRow(label: "Exposure", value: exposureLocked ? "Locked" : "Auto")

                Divider()
                    .background(.white.opacity(0.3))

                Text("Features")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Switch between front and back camera")
                    FeatureRow(icon: "lock.fill", text: "Lock/unlock exposure and white balance")
                    FeatureRow(icon: "4k.tv.fill", text: "4K 30fps support on compatible devices")
                    FeatureRow(icon: "camera.metering.matrix", text: "TrueDepth camera support")
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .padding(40)
        }
    }
}

struct CameraInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CameraView()
    }
}
