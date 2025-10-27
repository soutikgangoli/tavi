//
//  CaptureProgressView.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

// MARK: - Capture Progress View

public struct CaptureProgressView: View {
    let progress: CaptureProgress

    public init(progress: CaptureProgress) {
        self.progress = progress
    }

    public var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Progress indicator
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 8)
                        .frame(width: 120, height: 120)

                    // Progress circle
                    Circle()
                        .trim(from: 0, to: progress.progressPercentage)
                        .stroke(
                            progressColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress.progressPercentage)

                    // Icon or percentage
                    if progress.progressPercentage >= 1.0 {
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.green)
                    } else {
                        Text("\(Int(progress.progressPercentage * 100))%")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }

                // Status text
                VStack(spacing: 8) {
                    Text(progress.description)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    if let hint = progressHint {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)
            }
        }
    }

    private var progressColor: Color {
        switch progress {
        case .failed:
            return .red
        case .completed:
            return .green
        default:
            return .blue
        }
    }

    private var progressHint: String? {
        switch progress {
        case .capturing:
            return "Hold still"
        case .processingBlur:
            return "Analyzing sharpness"
        case .aligning:
            return "Aligning frames"
        case .combining:
            return "Creating final image"
        case .extractingROIs:
            return "Extracting regions"
        default:
            return nil
        }
    }
}

// MARK: - Capture Result View

public struct CaptureResultView: View {
    let result: CaptureResult
    let metrics: MetricsResult?
    let scores: ScoreSummary?
    @Binding var isPresented: Bool
    @State private var showingMetrics = false

    public init(result: CaptureResult, metrics: MetricsResult? = nil, scores: ScoreSummary? = nil, isPresented: Binding<Bool>) {
        self.result = result
        self.metrics = metrics
        self.scores = scores
        self._isPresented = isPresented
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Metrics button (if available)
                    if metrics != nil {
                        Button {
                            showingMetrics = true
                        } label: {
                            HStack {
                                Image(systemName: "chart.bar.doc.horizontal")
                                    .font(.title3)
                                Text("View Skin Analysis")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                    }
                    // Combined image
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Combined Image")
                            .font(.headline)

                        Image(uiImage: UIImage(cgImage: result.combinedImage))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                    }

                    // Statistics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Capture Statistics")
                            .font(.headline)

                        VStack(spacing: 8) {
                            StatRow(label: "Total Frames", value: "\(result.totalFramesCaptured)")
                            StatRow(label: "Sharp Frames Used", value: "\(result.sharpFramesUsed)")
                            StatRow(label: "Capture Time", value: String(format: "%.2fs", result.captureTime))
                            StatRow(label: "Avg Blur Score", value: String(format: "%.1f", result.averageBlurScore))
                            StatRow(label: "ROIs Extracted", value: "\(result.roiImages.count)")
                        }
                    }

                    // ROI Images
                    if !result.roiImages.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Extracted ROIs")
                                .font(.headline)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(result.roiImages, id: \.type.identifier) { roiImage in
                                    VStack(spacing: 8) {
                                        Image(uiImage: UIImage(cgImage: roiImage.image))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .cornerRadius(8)

                                        Text(roiImage.type.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    // Individual frames
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Captured Frames")
                            .font(.headline)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(result.frames.enumerated()), id: \.offset) { index, frame in
                                    VStack(spacing: 4) {
                                        Image(uiImage: UIImage(cgImage: frame.image))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 120)
                                            .cornerRadius(8)

                                        Text("Frame \(index + 1)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)

                                        Text(String(format: "%.1f", frame.blurScore))
                                            .font(.caption2)
                                            .foregroundStyle(frame.isSharp ? .green : .red)
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Capture Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showingMetrics) {
                if let metrics = metrics {
                    MetricsResultView(
                        metrics: metrics,
                        scores: scores,
                        faceImage: result.combinedImage,
                        roiSet: result.roiSet,
                        isPresented: $showingMetrics
                    )
                }
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Preview

#Preview {
    CaptureProgressView(progress: .capturing(frame: 3, total: 5))
}
