//
//  MetricsResultView.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

// MARK: - Metrics Result View

public struct MetricsResultView: View {
    let metrics: MetricsResult
    let scores: ScoreSummary?
    let faceImage: CGImage?
    let roiSet: FaceROISet?
    @Binding var isPresented: Bool
    @State private var showingScores = false

    public init(
        metrics: MetricsResult,
        scores: ScoreSummary? = nil,
        faceImage: CGImage? = nil,
        roiSet: FaceROISet? = nil,
        isPresented: Binding<Bool>
    ) {
        self.metrics = metrics
        self.scores = scores
        self.faceImage = faceImage
        self.roiSet = roiSet
        self._isPresented = isPresented
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Scores button (if available)
                    if scores != nil {
                        Button {
                            showingScores = true
                        } label: {
                            HStack {
                                Image(systemName: "chart.bar.doc.horizontal.fill")
                                    .font(.title3)
                                Text("View Analysis Scores (0-100%)")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color.purple)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                    }

                    // Overall Score Card
                    overallScoreCard

                    // Individual ROI Metrics
                    ForEach(Array(metrics.roiMetrics.keys.sorted(by: { $0.displayName < $1.displayName })), id: \.self) { roiType in
                        if let roiMetrics = metrics.roiMetrics[roiType] {
                            ROIMetricsCard(roiType: roiType, metrics: roiMetrics)
                        }
                    }

                    // Discoloration Analysis
                    discolorationCard

                    // Detailed Breakdown
                    if let avgMetrics = metrics.averageMetrics {
                        detailedBreakdown(avgMetrics)
                    }
                }
                .padding()
            }
            .navigationTitle("Skin Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showingScores) {
                if let scores = scores {
                    ScoreSummaryView(
                        scores: scores,
                        faceImage: faceImage,
                        roiSet: roiSet,
                        isPresented: $showingScores
                    )
                }
            }
        }
    }

    private var overallScoreCard: some View {
        VStack(spacing: 16) {
            Text("Overall Skin Quality")
                .font(.headline)

            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 150, height: 150)

                // Progress circle
                Circle()
                    .trim(from: 0, to: metrics.overallQualityScore)
                    .stroke(
                        qualityColor(metrics.overallQualityScore),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))

                // Score text
                VStack(spacing: 4) {
                    Text("\(Int(metrics.overallQualityScore * 100))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(qualityColor(metrics.overallQualityScore))

                    Text("Quality Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(qualityDescription(metrics.overallQualityScore))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private var discolorationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skin Tone Uniformity")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discoloration Index")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.1f%%", (1.0 - metrics.discolorationIndex) * 100))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(discolorationColor(metrics.discolorationIndex))
                }

                Spacer()

                Circle()
                    .fill(discolorationColor(metrics.discolorationIndex))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: discolorationIcon(metrics.discolorationIndex))
                            .font(.title2)
                            .foregroundStyle(.white)
                    )
            }

            Text(discolorationDescription(metrics.discolorationIndex))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private func detailedBreakdown(_ avgMetrics: ROIMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Average Metrics")
                .font(.headline)

            MetricBar(
                label: "Sharpness",
                value: avgMetrics.blurScore,
                color: .blue,
                icon: "camera.aperture"
            )

            MetricBar(
                label: "Texture Smoothness",
                value: 1.0 - avgMetrics.textureEnergy,
                color: .green,
                icon: "waveform"
            )

            MetricBar(
                label: "Pigmentation Evenness",
                value: 1.0 - avgMetrics.labVariance,
                color: .orange,
                icon: "paintpalette"
            )

            MetricBar(
                label: "Moisture Index",
                value: avgMetrics.moistureProxy.moistureIndex,
                color: .cyan,
                icon: "drop"
            )
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private func qualityColor(_ score: Double) -> Color {
        switch score {
        case 0.7...1.0: return .green
        case 0.4..<0.7: return .orange
        default: return .red
        }
    }

    private func qualityDescription(_ score: Double) -> String {
        switch score {
        case 0.8...1.0: return "Excellent skin quality"
        case 0.6..<0.8: return "Good skin quality"
        case 0.4..<0.6: return "Moderate skin quality"
        default: return "Consider recapture or skincare attention"
        }
    }

    private func discolorationColor(_ index: Double) -> Color {
        switch index {
        case 0.0..<0.3: return .green
        case 0.3..<0.6: return .orange
        default: return .red
        }
    }

    private func discolorationIcon(_ index: Double) -> String {
        switch index {
        case 0.0..<0.3: return "checkmark"
        case 0.3..<0.6: return "exclamationmark"
        default: return "exclamationmark.triangle"
        }
    }

    private func discolorationDescription(_ index: Double) -> String {
        switch index {
        case 0.0..<0.3: return "Very uniform skin tone across all regions"
        case 0.3..<0.6: return "Moderate variation in skin tone"
        default: return "Significant skin tone variation detected"
        }
    }
}

// MARK: - ROI Metrics Card

struct ROIMetricsCard: View {
    let roiType: ROIType
    let metrics: ROIMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(roiType.displayName)
                    .font(.headline)

                Spacer()

                Text(String(format: "%.0f", metrics.qualityScore * 100))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(scoreColor(metrics.qualityScore))
            }

            Divider()

            VStack(spacing: 8) {
                MetricRow(
                    label: "Sharpness",
                    value: metrics.blurScore,
                    icon: "camera.aperture",
                    color: .blue
                )

                MetricRow(
                    label: "Texture",
                    value: metrics.textureEnergy,
                    icon: "waveform",
                    color: .green,
                    inverted: true
                )

                MetricRow(
                    label: "Pigmentation",
                    value: metrics.labVariance,
                    icon: "paintpalette",
                    color: .orange,
                    inverted: true
                )

                Divider()

                HStack {
                    Image(systemName: "drop")
                        .foregroundStyle(.cyan)
                        .frame(width: 20)

                    Text("Moisture Index")
                        .font(.subheadline)

                    Spacer()

                    Text(String(format: "%.1f%%", metrics.moistureProxy.moistureIndex * 100))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Specular")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", metrics.moistureProxy.specularRatio * 100))
                            .font(.caption)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smoothness")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", metrics.moistureProxy.smoothnessLowFreq * 100))
                            .font(.caption)
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0.7...1.0: return .green
        case 0.4..<0.7: return .orange
        default: return .red
        }
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let label: String
    let value: Double
    let icon: String
    let color: Color
    var inverted: Bool = false

    var displayValue: Double {
        inverted ? (1.0 - value) : value
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(String(format: "%.1f%%", displayValue * 100))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(valueColor(displayValue))
        }
    }

    private func valueColor(_ val: Double) -> Color {
        switch val {
        case 0.7...1.0: return .green
        case 0.4..<0.7: return .orange
        default: return .red
        }
    }
}

// MARK: - Metric Bar

struct MetricBar: View {
    let label: String
    let value: Double
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 20)

                Text(label)
                    .font(.subheadline)

                Spacer()

                Text(String(format: "%.0f%%", value * 100))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * value, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Preview

#Preview {
    MetricsResultView(
        metrics: MetricsResult(
            roiMetrics: [
                .leftCheek: ROIMetrics(
                    blurScore: 0.85,
                    textureEnergy: 0.35,
                    labVariance: 0.25,
                    moistureProxy: MoistureProxy(
                        specularRatio: 0.15,
                        smoothnessLowFreq: 0.72
                    ),
                    roiType: .leftCheek
                ),
                .rightCheek: ROIMetrics(
                    blurScore: 0.82,
                    textureEnergy: 0.38,
                    labVariance: 0.28,
                    moistureProxy: MoistureProxy(
                        specularRatio: 0.12,
                        smoothnessLowFreq: 0.68
                    ),
                    roiType: .rightCheek
                )
            ],
            discolorationIndex: 0.22,
            timestamp: Date()
        ),
        roiSet: nil,
        isPresented: .constant(true)
    )
}
