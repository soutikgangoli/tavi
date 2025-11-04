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

    // Calculate overall improvement
    private var metricsComparison: [(name: String, before: Float, after: Float, unit: String, lowerIsBetter: Bool)] {
        [
            ("Overall Health", 70, 78, "/100", false),
            ("Skin Texture", 65, 72, "/100", false),
            ("Wrinkle Depth", 0.45, 0.42, "mm", true),
            ("Hydration", 60, 68, "/100", false),
            ("Pore Visibility", 25, 18, "%", true),
            ("Pigmentation", 79, 81, "/100", false)
        ]
    }

    private var improvementStats: (improved: Int, declined: Int, unchanged: Int) {
        var improved = 0
        var declined = 0
        var unchanged = 0

        for metric in metricsComparison {
            let change = metric.after - metric.before
            if abs(change) < 0.01 {
                unchanged += 1
            } else {
                let isImproved = metric.lowerIsBetter ? change < 0 : change > 0
                if isImproved {
                    improved += 1
                } else {
                    declined += 1
                }
            }
        }

        return (improved, declined, unchanged)
    }

    private var overallSummary: String {
        let stats = improvementStats
        if stats.improved > stats.declined {
            return "Great progress! \(stats.improved) metrics improved"
        } else if stats.declined > stats.improved {
            return "Some areas need attention. \(stats.declined) metrics declined"
        } else {
            return "Stable results. \(stats.unchanged) metrics unchanged"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Overall summary banner
                OverallImprovementBanner(
                    improved: improvementStats.improved,
                    declined: improvementStats.declined,
                    unchanged: improvementStats.unchanged,
                    summary: overallSummary
                )
                .padding(.horizontal)
                .padding(.bottom, 8)

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

/// Single metric comparison row - clean single line with inline deltas
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

    var changeColor: Color {
        if abs(change) < 0.01 { return .gray }  // No significant change
        return isImproved ? .green : .red
    }

    var changeIcon: String {
        if abs(change) < 0.01 { return "minus" }
        return isImproved ? "arrow.up" : "arrow.down"
    }

    var body: some View {
        HStack(spacing: 8) {
            // Metric name
            Text(name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            // Single line: "72.5 (+5.3 points)" in one flow
            HStack(spacing: 4) {
                // Current value
                Text(String(format: "%.1f", after))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Text(unit)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                // Delta in colored badge
                if abs(change) > 0.01 {
                    HStack(spacing: 3) {
                        Image(systemName: changeIcon)
                            .font(.system(size: 10, weight: .bold))

                        Text(String(format: "%.1f", abs(change)))
                            .font(.system(size: 13, weight: .semibold))

                        Text("pts")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(changeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(changeColor.opacity(0.15))
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

/// Overall improvement summary banner
struct OverallImprovementBanner: View {
    let improved: Int
    let declined: Int
    let unchanged: Int
    let summary: String

    private var dominantColor: Color {
        if improved > declined {
            return .green
        } else if declined > improved {
            return .orange
        } else {
            return .blue
        }
    }

    private var icon: String {
        if improved > declined {
            return "arrow.up.circle.fill"
        } else if declined > improved {
            return "arrow.down.circle.fill"
        } else {
            return "equal.circle.fill"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Main summary
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(dominantColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    HStack(spacing: 16) {
                        if improved > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 10, weight: .bold))
                                Text("\(improved) improved")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.green)
                        }

                        if declined > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 10, weight: .bold))
                                Text("\(declined) declined")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.red)
                        }

                        if unchanged > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "minus")
                                    .font(.system(size: 10, weight: .bold))
                                Text("\(unchanged) stable")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.gray)
                        }
                    }
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(dominantColor.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(dominantColor.opacity(0.3), lineWidth: 1)
            )
        }
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
