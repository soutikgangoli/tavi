//
//  ComparisonView.swift
//  Tavi
//
//  Side-by-side 3D model comparison for before/after visualization
//  Shows progress over time
//

import SwiftUI
import SceneKit

/// Side-by-side 3D comparison view
public struct Comparison3DView: View {
    let beforeScan: Face3DMetrics
    let afterScan: Face3DMetrics
    let beforeDate: Date
    let afterDate: Date

    @State private var rotationAngle: Float = 0
    @State private var showHeatmap: Bool = false
    @State private var selectedMetric: ComparisonMetric = .overall

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            ComparisonHeaderView(
                beforeDate: beforeDate,
                afterDate: afterDate,
                daysBetween: daysBetween
            )

            // Side-by-side 3D models
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Before model
                    VStack {
                        Text("Before")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Scene3DContainerView(
                            metrics: beforeScan,
                            showHeatmap: showHeatmap,
                            metric: selectedMetric,
                            rotationAngle: $rotationAngle
                        )
                    }
                    .frame(width: geometry.size.width / 2)

                    Divider()

                    // After model
                    VStack {
                        Text("After")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Scene3DContainerView(
                            metrics: afterScan,
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
            MetricComparisonList(
                beforeScan: beforeScan,
                afterScan: afterScan
            )
        }
    }

    private var daysBetween: Int {
        Calendar.current.dateComponents([.day], from: beforeDate, to: afterDate).day ?? 0
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

/// 3D scene container
struct Scene3DContainerView: View {
    let metrics: Face3DMetrics
    let showHeatmap: Bool
    let metric: ComparisonMetric
    @Binding var rotationAngle: Float

    var body: some View {
        // Would use SceneKit/RealityKit here
        // For now, placeholder
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.1))

            VStack {
                Image(systemName: "face.smiling")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(Double(rotationAngle)))

                if showHeatmap {
                    Text("\(metric.rawValue) Heatmap")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .cornerRadius(10)
        .padding()
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
    case roughness = "Texture"
    case wrinkles = "Wrinkles"
    case hydration = "Hydration"
    case pores = "Pores"
    case pigmentation = "Pigmentation"
}
