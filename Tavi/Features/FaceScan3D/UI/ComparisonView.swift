//
//  ComparisonView.swift
//  Tavi
//
//  Side-by-side 3D model comparison for before/after visualization
//  Shows progress over time
//

import SwiftUI
import SceneKit
import CoreData

/// Side-by-side 3D comparison view
public struct Comparison3DView: View {
    let beforeSession: SessionResult
    let afterSession: SessionResult

    @State private var rotationAngle: Float = 0
    @State private var showHeatmap: Bool = false
    @State private var selectedMetric: ComparisonMetric = .overall

    public init(beforeSession: SessionResult, afterSession: SessionResult) {
        self.beforeSession = beforeSession
        self.afterSession = afterSession
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            ComparisonHeaderView(
                beforeDate: beforeSession.date,
                afterDate: afterSession.date,
                daysBetween: daysBetween
            )

            // Side-by-side images
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Before image
                    VStack {
                        Text("Before")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Scene3DContainerView(
                            sessionResult: beforeSession,
                            showHeatmap: showHeatmap,
                            metric: selectedMetric,
                            rotationAngle: $rotationAngle
                        )
                    }
                    .frame(width: geometry.size.width / 2)

                    Divider()

                    // After image
                    VStack {
                        Text("After")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Scene3DContainerView(
                            sessionResult: afterSession,
                            showHeatmap: showHeatmap,
                            metric: selectedMetric,
                            rotationAngle: $rotationAngle
                        )
                    }
                    .frame(width: geometry.size.width / 2)
                }
            }
            .frame(height: 300)

            // Synchronized controls
            ComparisonControlsView(
                rotationAngle: $rotationAngle,
                showHeatmap: $showHeatmap,
                selectedMetric: $selectedMetric
            )

            // Metric comparisons
            if let beforeMetrics = decodeMetrics(from: beforeSession),
               let afterMetrics = decodeMetrics(from: afterSession) {
                MetricComparisonList(
                    beforeScan: beforeMetrics,
                    afterScan: afterMetrics
                )
            }
        }
    }

    private var daysBetween: Int {
        Calendar.current.dateComponents([.day], from: beforeSession.date, to: afterSession.date).day ?? 0
    }

    private func decodeMetrics(from session: SessionResult) -> Face3DMetrics? {
        guard let data = session.clinicalMetricsData else { return nil }
        do {
            return try JSONDecoder().decode(Face3DMetrics.self, from: data)
        } catch {
            AppLogger.ui.error("Failed to decode metrics in ComparisonView: \(error)")
            CrashReporter.shared.logError(error, context: ["operation": "json_decode_comparison"])
            return nil
        }
    }
}

/// Comparison header with dates
struct ComparisonHeaderView: View {
    let beforeDate: Date
    let afterDate: Date
    let daysBetween: Int

    var body: some View {
        VStack(spacing: 8) {
            Text("Progress Comparison")
                .font(.title2)
                .bold()

            Text("\(daysBetween) days between scans")
                .font(.subheadline)
                .foregroundColor(.gray)

            HStack {
                Text(beforeDate, style: .date)
                    .font(.caption)
                Image(systemName: "arrow.right")
                    .font(.caption)
                Text(afterDate, style: .date)
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding()
    }
}

/// 3D scene container - displays actual scan images
struct Scene3DContainerView: View {
    let sessionResult: SessionResult
    let showHeatmap: Bool
    let metric: ComparisonMetric
    @Binding var rotationAngle: Float

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.1))

            if let imageData = showHeatmap ? getHeatmapData() : sessionResult.thumbnail,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .rotationEffect(.degrees(Double(rotationAngle)))
                    .padding(8)
            } else {
                // Fallback if no image available
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No image available")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .cornerRadius(10)
        .padding()
    }

    private func getHeatmapData() -> Data? {
        switch metric {
        case .overall:
            return sessionResult.heatmapComposite
        case .texture:
            return sessionResult.heatmapTexture
        case .pigmentation:
            return sessionResult.heatmapPigmentation
        case .moisture:
            return sessionResult.heatmapMoisture
        case .sharpness:
            return sessionResult.heatmapSharpness
        }
    }
}

/// Synchronized controls
struct ComparisonControlsView: View {
    @Binding var rotationAngle: Float
    @Binding var showHeatmap: Bool
    @Binding var selectedMetric: ComparisonMetric

    var body: some View {
        VStack(spacing: 15) {
            // Rotation slider
            VStack {
                Text("Rotation")
                    .font(.caption)
                Slider(value: $rotationAngle, in: -180...180)
                    .padding(.horizontal)
            }

            // View mode toggle
            HStack {
                Text("Heatmap")
                    .font(.caption)
                Toggle("", isOn: $showHeatmap)
                    .labelsHidden()
            }

            // Metric selector
            Picker("Metric", selection: $selectedMetric) {
                ForEach(ComparisonMetric.allCases, id: \.self) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
    }
}

/// Metric comparison list
struct MetricComparisonList: View {
    let beforeScan: Face3DMetrics
    let afterScan: Face3DMetrics

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                MetricComparisonRow(
                    name: "Overall Health",
                    before: 70,
                    after: 78,
                    unit: "/100"
                )

                MetricComparisonRow(
                    name: "Skin Texture",
                    before: 65,
                    after: 72,
                    unit: "/100"
                )

                MetricComparisonRow(
                    name: "Wrinkle Depth",
                    before: 0.45,
                    after: 0.42,
                    unit: "mm",
                    lowerIsBetter: true
                )

                MetricComparisonRow(
                    name: "Hydration",
                    before: 60,
                    after: 68,
                    unit: "/100"
                )

                MetricComparisonRow(
                    name: "Pore Visibility",
                    before: 25,
                    after: 18,
                    unit: "%",
                    lowerIsBetter: true
                )

                MetricComparisonRow(
                    name: "Pigmentation",
                    before: 79,
                    after: 81,
                    unit: "/100"
                )
            }
            .padding()
        }
    }
}

/// Single metric comparison row
struct MetricComparisonRow: View {
    let name: String
    let before: Float
    let after: Float
    let unit: String
    var lowerIsBetter: Bool = false

    var change: Float {
        after - before
    }

    var changePercent: Float {
        guard before > 0 else { return 0 }
        return (change / before) * 100
    }

    var isImproved: Bool {
        lowerIsBetter ? change < 0 : change > 0
    }

    var body: some View {
        HStack {
            // Name
            Text(name)
                .font(.subheadline)

            Spacer()

            // Before value
            Text("\(String(format: "%.1f", before))")
                .font(.caption)
                .foregroundColor(.gray)

            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(.gray)

            // After value
            Text("\(String(format: "%.1f", after))")
                .font(.caption)
                .fontWeight(.semibold)

            Text(unit)
                .font(.caption2)
                .foregroundColor(.gray)

            // Change indicator
            HStack(spacing: 4) {
                Image(systemName: isImproved ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(isImproved ? .green : .red)
                    .font(.caption)

                Text("\(change >= 0 ? "+" : "")\(String(format: "%.1f", changePercent))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isImproved ? .green : .red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

/// Metrics available for comparison
public enum ComparisonMetric: String, CaseIterable {
    case overall = "Overall"
    case texture = "Texture"
    case pigmentation = "Pigmentation"
    case moisture = "Moisture"
    case sharpness = "Sharpness"
}
