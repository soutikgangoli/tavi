//
//  HeatmapView.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

// MARK: - Heatmap View

public struct HeatmapView: View {
    let faceImage: CGImage
    let scores: ScoreSummary
    let roiSet: FaceROISet
    @Binding var isPresented: Bool

    @State private var showingHeatmap = true
    @State private var selectedMetric: HeatmapMetric = .composite
    @State private var isGenerating = false
    @State private var heatmapImages: [HeatmapMetric: CGImage] = [:]
    @State private var errorMessage: String?

    private let generator = HeatmapGenerator()

    public init(
        faceImage: CGImage,
        scores: ScoreSummary,
        roiSet: FaceROISet,
        isPresented: Binding<Bool>
    ) {
        self.faceImage = faceImage
        self.scores = scores
        self.roiSet = roiSet
        self._isPresented = isPresented
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Image display
                GeometryReader { geometry in
                    ZStack {
                        if showingHeatmap, let heatmap = heatmapImages[selectedMetric] {
                            Image(uiImage: UIImage(cgImage: heatmap))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Image(uiImage: UIImage(cgImage: faceImage))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        if isGenerating {
                            ProgressView("Generating heatmap...")
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Controls
                VStack(spacing: 16) {
                    // Toggle button
                    Button {
                        withAnimation {
                            showingHeatmap.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: showingHeatmap ? "photo" : "map")
                                .font(.title3)
                            Text(showingHeatmap ? "Show Original" : "Show Heatmap")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(showingHeatmap ? Color.orange : Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }

                    // Metric selector
                    if showingHeatmap {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Metric")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(HeatmapMetric.allCases, id: \.self) { metric in
                                        MetricButton(
                                            metric: metric,
                                            isSelected: selectedMetric == metric,
                                            action: {
                                                selectedMetric = metric
                                                generateHeatmapIfNeeded(for: metric)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Color legend
                    if showingHeatmap {
                        ColorLegend()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Error message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(UIColor.systemGroupedBackground))
            }
            .navigationTitle("Heatmap Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .task {
            await generateInitialHeatmap()
        }
    }

    private func generateInitialHeatmap() async {
        await generateHeatmap(for: selectedMetric)
    }

    private func generateHeatmapIfNeeded(for metric: HeatmapMetric) {
        guard heatmapImages[metric] == nil else { return }

        Task {
            await generateHeatmap(for: metric)
        }
    }

    private func generateHeatmap(for metric: HeatmapMetric) async {
        guard heatmapImages[metric] == nil else { return }

        isGenerating = true
        errorMessage = nil

        do {
            let scores = self.scores
            let faceImage = self.faceImage
            let roiSet = self.roiSet
            let generator = self.generator

            let heatmap = try await Task.detached(priority: .userInitiated) {
                var metricMap: [ROIType: Double] = [:]

                for (roiType, roiScores) in scores.roiScores {
                    let value: Double
                    switch metric {
                    case .composite:
                        value = roiScores.compositeScore
                    case .sharpness:
                        value = roiScores.sharpnessScore
                    case .texture:
                        value = roiScores.textureScore
                    case .pigmentation:
                        value = roiScores.pigmentationScore
                    case .moisture:
                        value = roiScores.moistureScore
                    }
                    metricMap[roiType] = value
                }

                return try generator.generateHeatmap(
                    faceImage: faceImage,
                    metricMap: metricMap,
                    roiSet: roiSet
                )
            }.value

            heatmapImages[metric] = heatmap

        } catch {
            errorMessage = "Failed to generate heatmap: \(error.localizedDescription)"
        }

        isGenerating = false
    }
}

// MARK: - Metric Button

struct MetricButton: View {
    let metric: HeatmapMetric
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: metric.icon)
                    .font(.title3)

                Text(metric.displayName)
                    .font(.caption2)
            }
            .frame(width: 80, height: 60)
            .background(isSelected ? Color.blue : Color(UIColor.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(12)
        }
    }
}

// MARK: - Color Legend

struct ColorLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color Scale")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                // Gradient bar
                LinearGradient(
                    colors: [
                        Color(red: 0, green: 0, blue: 1),      // Blue
                        Color(red: 0, green: 1, blue: 1),      // Cyan
                        Color(red: 0, green: 1, blue: 0),      // Green
                        Color(red: 1, green: 1, blue: 0),      // Yellow
                        Color(red: 1, green: 0, blue: 0)       // Red
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 24)
                .cornerRadius(4)
            }

            HStack {
                Text("0% (Low)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("50%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("100% (High)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    // Note: Preview requires actual image data
    Text("Heatmap View")
}
