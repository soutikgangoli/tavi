//
//  Face3DMetricsResultsView.swift
//  Tavi
//
//  Display 3D face metrics results with visualizations
//  Created on 2025-10-27.
//

import SwiftUI

/// Complete results view for 3D face metrics
public struct Face3DMetricsResultsView: View {
    @ObservedObject var viewModel: FaceScan3DViewModel

    @State private var selectedMetricType: VisualizerMetricType = .roughness
    @State private var selectedROI: Face3DROI?
    @State private var showHeatmap: Bool = true

    public init(viewModel: FaceScan3DViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // 3D Viewer button
                view3DButton

                // Global metrics
                globalMetricsSection

                // Metric type selector
                metricTypePicker

                // Visualization (heatmap)
                if showHeatmap {
                    heatmapSection
                }

                // Per-ROI metrics
                roiMetricsSection

                // Export and save buttons
                actionButtons
            }
            .padding()
        }
        .navigationTitle("3D Skin Metrics")
        .overlay {
            if viewModel.isComputingMetrics {
                ProgressView("Computing metrics...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
            }
        }
    }

    // MARK: - 3D Viewer Button

    private var view3DButton: some View {
        NavigationLink(destination: Face3DViewer(viewModel: viewModel)) {
            HStack {
                Image(systemName: "cube.transparent")
                    .font(.title2)
                Text("View in 3D")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(12)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "face.smiling")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("3D Face Analysis Complete")
                .font(.title2)
                .fontWeight(.bold)

            if let metrics = viewModel.face3DMetrics {
                Text("\(metrics.vertexCount) vertices • \(metrics.triangleCount) triangles")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Processed in \(String(format: "%.1f", metrics.processingTime))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - Global Metrics

    private var globalMetricsSection: some View {
        Group {
            if let metrics = viewModel.face3DMetrics {
                VStack(alignment: .leading, spacing: 16) {
                    // Overall Score (prominent)
                    VStack(spacing: 8) {
                        Text("Overall Skin Quality")
                            .font(.headline)

                        HStack(spacing: 12) {
                            Text(String(format: "%.1f", metrics.overallScore))
                                .font(.gilroy(size: 48, weight: .bold))
                                .foregroundColor(colorForScore(metrics.overallScore))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("out of 10")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(metrics.scoreInterpretation)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(colorForScore(metrics.overallScore))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(colorForScore(metrics.overallScore).opacity(0.15))
                    .cornerRadius(12)

                    Divider()

                    // Individual Scores
                    Text("Detailed Scores")
                        .font(.headline)

                    VStack(spacing: 12) {
                        ScoreCardWithExplanation(
                            title: "Smoothness",
                            score: metrics.globalRoughnessScore,
                            icon: "waveform.path",
                            color: .orange,
                            explanation: MetricExplanations.shortSummary(for: "Roughness", score: metrics.globalRoughnessScore)
                        )

                        ScoreCardWithExplanation(
                            title: "Even Pigmentation",
                            score: metrics.globalPigmentationScore,
                            icon: "paintpalette",
                            color: .purple,
                            explanation: MetricExplanations.shortSummary(for: "Pigmentation", score: metrics.globalPigmentationScore)
                        )

                        ScoreCardWithExplanation(
                            title: "Uniform Tone",
                            score: metrics.globalDiscolorationScore,
                            icon: "face.smiling",
                            color: .blue,
                            explanation: MetricExplanations.shortSummary(for: "Discoloration", score: metrics.globalDiscolorationScore)
                        )

                        if let specularScore = metrics.globalSpecularScore {
                            ScoreCardWithExplanation(
                                title: "Matte Finish",
                                score: specularScore,
                                icon: "sparkles",
                                color: .cyan,
                                explanation: MetricExplanations.shortSummary(for: "Specular", score: specularScore)
                            )
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Metric Type Picker

    private var metricTypePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visualization")
                .font(.headline)

            Menu {
                Menu("Raw Metrics") {
                    Button("Roughness") { selectedMetricType = .roughness }
                    Button("Pigmentation") { selectedMetricType = .pigmentation }
                    Button("Luminance") { selectedMetricType = .luminance }
                    Button("Lightness") { selectedMetricType = .lightness }
                    if viewModel.face3DMetrics?.globalSpecularProxy != nil {
                        Button("Specular/Oiliness") { selectedMetricType = .specular }
                    }
                }

                Menu("Scores") {
                    Button("Smoothness Score") { selectedMetricType = .roughnessScore }
                    Button("Pigmentation Score") { selectedMetricType = .pigmentationScore }
                    if viewModel.face3DMetrics?.globalSpecularScore != nil {
                        Button("Specular Score") { selectedMetricType = .specularScore }
                    }
                }
            } label: {
                HStack {
                    Text(selectedMetricType.displayName)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }

            Toggle("Show Heatmap", isOn: $showHeatmap)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        Group {
            if let viz = viewModel.getVisualization(for: selectedMetricType),
               let heatmap = viz.heatmapImage {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(selectedMetricType.displayName) Heatmap")
                        .font(.headline)

                    Image(uiImage: heatmap)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)

                    // Legend
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 20, height: 20)
                        Text("Low")
                            .font(.caption)

                        Spacer()

                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 20, height: 20)
                        Text("Medium")
                            .font(.caption)

                        Spacer()

                        Circle()
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                        Text("High")
                            .font(.caption)
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - ROI Metrics

    private var roiMetricsSection: some View {
        Group {
            if let metrics = viewModel.face3DMetrics {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Region Analysis")
                        .font(.headline)

                    ForEach(Face3DROI.allCases, id: \.self) { roi in
                        if let roiMetrics = metrics.metrics(for: roi) {
                            ROIMetricRow(
                                roi: roi,
                                metrics: roiMetrics,
                                metricType: selectedMetricType,
                                isSelected: selectedROI == roi
                            )
                            .onTapGesture {
                                selectedROI = selectedROI == roi ? nil : roi
                            }
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Save summary
            Button(action: saveSummary) {
                Label("Save to History", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            // Export JSON
            Button(action: exportMetrics) {
                Label("Export as JSON", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text("Save creates a compact summary in your scan history")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func saveSummary() {
        guard let metrics = viewModel.face3DMetrics else { return }

        // Create preview thumbnail from baked texture
        let previewImage = viewModel.bakeResult.map { UIImage(cgImage: $0.albedoTexture) }

        // Create and save summary
        let summary = Face3DSummary.from(
            metrics: metrics,
            previewImage: previewImage,
            thresholdsVersion: "1.0"
        )

        Face3DSummaryManager.save(summary)

        AppLogger.metrics.info("✅ Saved summary to history (ID: \(summary.id))")
    }

    private func exportMetrics() {
        guard let metrics = viewModel.face3DMetrics else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(metrics)

            // Save to Documents
            guard let documentsPath = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first else {
                throw NSError(domain: "com.tavi.app", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to access Documents directory"])
            }

            let filename = "face3d_metrics_\(Int(Date().timeIntervalSince1970)).json"
            let fileURL = documentsPath.appendingPathComponent(filename)

            try jsonData.write(to: fileURL)

            AppLogger.metrics.info("✅ Exported metrics to: \(fileURL.path)")

        } catch {
            AppLogger.metrics.warning("⚠️ Export failed: \(error)")
        }
    }

    // MARK: - Helpers

    private func colorForScore(_ score: Float) -> Color {
        switch score {
        case 8.0...10.0:
            return .green
        case 6.0..<8.0:
            return .blue
        case 4.0..<6.0:
            return .yellow
        case 2.0..<4.0:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Metric Card

private struct MetricCard: View {
    let title: String
    let value: Float
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(String(format: "%.2f", value))
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value))
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Score Card

private struct ScoreCard: View {
    let title: String
    let score: Float
    let icon: String
    let color: Color

    private var scoreColor: Color {
        switch score {
        case 8.0...10.0:
            return .green
        case 6.0..<8.0:
            return .blue
        case 4.0..<6.0:
            return .yellow
        case 2.0..<4.0:
            return .orange
        default:
            return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(scoreColor)
                            .frame(width: geometry.size.width * CGFloat(score / 10.0))
                    }
                }
                .frame(height: 8)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", score))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor)

                Text("/ 10")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(scoreColor.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Score Card with Explanation

private struct ScoreCardWithExplanation: View {
    let title: String
    let score: Float
    let icon: String
    let color: Color
    let explanation: String

    private var scoreColor: Color {
        switch score {
        case 8.0...10.0:
            return .green
        case 6.0..<8.0:
            return .blue
        case 4.0..<6.0:
            return .yellow
        case 2.0..<4.0:
            return .orange
        default:
            return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(scoreColor)
                                .frame(width: geometry.size.width * CGFloat(score / 10.0))
                        }
                    }
                    .frame(height: 8)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f", score))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor)

                    Text("/ 10")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Explanation text
            Text(explanation)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(scoreColor.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - ROI Metric Row

struct ROIMetricRow: View {
    let roi: Face3DROI
    let metrics: ROI3DMetrics
    let metricType: MetricType
    let isSelected: Bool

    private var value: Float {
        return metricType.getValue(from: metrics)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(roi.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text(String(format: "%.3f", value))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(colorForValue(value))
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForValue(value))
                        .frame(width: geometry.size.width * CGFloat(value))
                }
            }
            .frame(height: 8)

            if isSelected {
                // Detailed metrics
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    Text("Raw Metrics")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    metricDetail("Roughness", metrics.roughnessProxy)
                    metricDetail("Pigmentation", metrics.pigmentationIndex)
                    if let specular = metrics.specularProxy {
                        metricDetail("Specular/Oiliness", specular)
                    }
                    metricDetail("Luminance", metrics.averageLuminance)
                    metricDetail("Lightness (L*)", metrics.averageLightness / 100.0)

                    Divider()

                    Text("Scores")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    scoreDetail("Smoothness", metrics.roughnessScore)
                    scoreDetail("Even Pigmentation", metrics.pigmentationScore)
                    if let specularScore = metrics.specularScore {
                        scoreDetail("Matte Finish", specularScore)
                    }

                    Divider()

                    Text("\(metrics.pixelCount) pixels analyzed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }

    private func metricDetail(_ label: String, _ value: Float) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.3f", value))
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    private func scoreDetail(_ label: String, _ score: Float) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.1f / 10", score))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(scoreColor(score))
        }
    }

    private func scoreColor(_ score: Float) -> Color {
        switch score {
        case 8.0...10.0:
            return .green
        case 6.0..<8.0:
            return .blue
        case 4.0..<6.0:
            return .yellow
        case 2.0..<4.0:
            return .orange
        default:
            return .red
        }
    }

    private func colorForValue(_ value: Float) -> Color {
        if value < 0.33 {
            return .green
        } else if value < 0.67 {
            return .yellow
        } else {
            return .red
        }
    }
}
