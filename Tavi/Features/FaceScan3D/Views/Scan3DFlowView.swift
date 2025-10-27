//
//  Scan3DFlowView.swift
//  Tavi
//
//  Complete 3D scan flow: Capture → Merge → Bake → Metrics → Results
//  Created on 2025-10-27.
//

import SwiftUI

/// Complete 3D scan flow with automatic processing
public struct Scan3DFlowView: View {
    @StateObject private var viewModel = FaceScan3DViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var flowState: FlowState = .capturing
    @State private var showResults = false
    @State private var processingProgress: String = ""

    enum FlowState {
        case capturing
        case processing
        case complete
        case error(String)
    }

    public init() {
        // All @State and @StateObject properties have default values
    }

    public var body: some View {
        ZStack {
            // Main content based on state
            switch flowState {
            case .capturing:
                capturingView

            case .processing:
                processingView

            case .complete:
                if let metrics = viewModel.face3DMetrics,
                   let bakeResult = viewModel.bakeResult {
                    Face3DResultsView(metrics: metrics, texturedMesh: bakeResult)
                        .navigationBarBackButtonHidden(false)
                }

            case .error(let message):
                errorView(message: message)
            }
        }
        .navigationTitle("3D Face Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if flowState == .capturing {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Capturing View

    private var capturingView: some View {
        FaceScan3DView(
            showDebug: false,
            showMesh: true,
            showCalibration: true,
            onCaptureComplete: { capturedPoses in
                // All poses captured - start processing pipeline
                processCapture()
            }
        )
        .environmentObject(viewModel)
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Processing animation
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(.circular)

            VStack(spacing: 12) {
                Text("Processing 3D Scan")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(processingProgress)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            VStack(spacing: 12) {
                Text("Processing Failed")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                // Restart capture
                flowState = .capturing
                viewModel.startGuidance()
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
            }

            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Processing Pipeline

    private func processCapture() {
        flowState = .processing

        Task {
            do {
                // Step 1: Merge meshes
                processingProgress = "Merging face meshes from all angles..."
                guard let merged = await viewModel.finalizeCapture() else {
                    throw ScanError.mergeFailed
                }

                try await Task.sleep(nanoseconds: 500_000_000) // Brief pause for UI feedback

                // Step 2: Bake texture
                processingProgress = "Baking unified texture with lighting correction..."
                guard let bakeResult = await viewModel.bakeTextureFromSequence() else {
                    throw ScanError.bakeFailed
                }

                try await Task.sleep(nanoseconds: 500_000_000)

                // Step 3: Compute 3D metrics
                processingProgress = "Computing skin quality metrics from 3D data..."
                guard let metrics = await viewModel.compute3DMetrics() else {
                    throw ScanError.metricsFailed
                }

                try await Task.sleep(nanoseconds: 500_000_000)

                // Step 4: Save summary
                processingProgress = "Saving results..."
                let summary = Face3DSummary.from(
                    metrics: metrics,
                    previewImage: nil, // Could extract from bakeResult
                    thresholdsVersion: "1.0"
                )
                try saveFace3DSummary(summary)

                // Complete!
                await MainActor.run {
                    flowState = .complete
                }

            } catch {
                await MainActor.run {
                    flowState = .error(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Scan Error

enum ScanError: LocalizedError {
    case mergeFailed
    case bakeFailed
    case metricsFailed

    var errorDescription: String? {
        switch self {
        case .mergeFailed:
            return "Failed to merge face meshes. Please ensure all angles were captured properly."
        case .bakeFailed:
            return "Failed to bake unified texture. Please try scanning again with better lighting."
        case .metricsFailed:
            return "Failed to compute skin metrics. Please try scanning again."
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        Scan3DFlowView()
    }
}
