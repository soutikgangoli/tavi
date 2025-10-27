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

                // Clean Apple Face ID-style Guide
                if viewModel.isCapturing && !viewModel.captureInProgress {
                    FaceIDStyleGuide(
                        faceResult: viewModel.detectedFaces.first,
                        lightingStatus: viewModel.currentMetrics?.calibrationStatus,
                        onAutoCapture: {
                            Task {
                                await viewModel.startMultiFrameCapture()
                                if viewModel.lastCaptureResult != nil {
                                    showingCaptureResult = true
                                }
                            }
                        }
                    )
                }

                // Controls overlay
                VStack {
                // Top controls
                HStack {
                    // Info button
                    Button {
                        showingInfo.toggle()
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    }
                    .padding()

                    // Face landmarks toggle
                    if viewModel.faceDetectionEnabled {
                        Button {
                            viewModel.toggleFaceLandmarks()
                        } label: {
                            Image(systemName: viewModel.showFaceLandmarks ? "face.smiling.fill" : "face.smiling")
                                .font(.title2)
                                .foregroundStyle(viewModel.showFaceLandmarks ? .green : .white)
                                .shadow(color: .black.opacity(0.3), radius: 2)
                        }
                        .padding(.leading)

                        // ROI toggle
                        Button {
                            viewModel.toggleROIs()
                        } label: {
                            Image(systemName: viewModel.showROIs ? "rectangle.3.group.fill" : "rectangle.3.group")
                                .font(.title2)
                                .foregroundStyle(viewModel.showROIs ? .purple : .white)
                                .shadow(color: .black.opacity(0.3), radius: 2)
                        }
                        .padding(.leading, 8)
                    }

                    Spacer()

                    // Face detection indicator
                    if viewModel.faceDetectionEnabled && !viewModel.detectedFaces.isEmpty {
                        Text("\(viewModel.detectedFaces.count) face\(viewModel.detectedFaces.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.green.opacity(0.8))
                            .cornerRadius(8)
                    }

                    Spacer()

                    // Camera switch button
                    Button {
                        viewModel.switchCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    }
                    .padding()
                }

                Spacer()

                // Bottom controls
                VStack(spacing: 20) {
                    // Control buttons
                    HStack(spacing: 40) {
                        // Exposure lock button
                        Button {
                            viewModel.toggleExposureLock()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: viewModel.isExposureLocked ? "lock.fill" : "lock.open.fill")
                                    .font(.title2)
                                Text(viewModel.isExposureLocked ? "Locked" : "Auto")
                                    .font(.caption2)
                            }
                            .foregroundStyle(viewModel.isExposureLocked ? .yellow : .white)
                            .frame(width: 60, height: 60)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        }
                        .disabled(!viewModel.isCapturing)

                        // Start/Stop button
                        Button {
                            if viewModel.isCapturing {
                                viewModel.stopCapture()
                            } else {
                                viewModel.startCapture()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 70, height: 70)

                                if viewModel.isCapturing {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.red)
                                        .frame(width: 30, height: 30)
                                } else {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 60, height: 60)
                                }
                            }
                        }

                        // Multi-frame capture button
                        Button {
                            Task {
                                await viewModel.startMultiFrameCapture()
                                if viewModel.lastCaptureResult != nil {
                                    showingCaptureResult = true
                                }
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.title2)
                                Text("Capture")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.blue)
                            .frame(width: 60, height: 60)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        }
                        .disabled(!viewModel.isCapturing || viewModel.captureInProgress)
                    }
                    .padding(.bottom, 40)
                }
            }

            // Info overlay
            if showingInfo {
                InfoOverlay(
                    isPresented: $showingInfo,
                    resolution: viewModel.currentResolution,
                    frameRate: viewModel.currentFrameRate,
                    cameraPosition: viewModel.currentCameraPosition == .front ? "Front" : "Back",
                    exposureLocked: viewModel.isExposureLocked
                )
            }

            // Calibration details overlay
            if showingCalibrationDetails, let metrics = viewModel.currentMetrics {
                DetailedCalibrationView(
                    metrics: metrics,
                    isPresented: $showingCalibrationDetails
                )
            }

            // Landmark legend
            if viewModel.showFaceLandmarks && !viewModel.detectedFaces.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        LandmarkLegend()
                            .padding()
                    }
                    Spacer()
                }
            }

            // ROI legend
            if viewModel.showROIs && !viewModel.faceROIs.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        ROILegend()
                            .padding()
                    }
                    Spacer()
                }
            }

            // Capture progress overlay
            if viewModel.captureInProgress {
                CaptureProgressView(progress: viewModel.captureController.progress)
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
