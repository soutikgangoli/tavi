//
//  ProgressTracking.swift
//  Ollvy
//
//  Track and visualize progress over time with charts and comparisons
//

import SwiftUI

/// Progress tracking data
struct ProgressData {
    let metric: String
    let history: [DataPoint]
    let trend: TrendDirection
    let percentChange: Float
}

struct DataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Float
}

enum TrendDirection {
    case up, down, stable
}

/// Progress tracking view
struct ProgressTrackingView: View {
    let progressData: [ProgressData]
    let temporal: TemporalComparison?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Progress Tracking")
                    .font(.title)
                    .bold()

                if let temporal = temporal {
                    // Since last scan summary
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Since Last Scan (\(temporal.daysSinceLastScan) days ago)")
                            .font(.headline)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Improvements")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                ForEach(temporal.improvementAreas, id: \.self) { area in
                                    Text("• \(area)")
                                        .font(.caption)
                                }
                            }

                            Spacer()

                            VStack(alignment: .leading) {
                                Text("Declines")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                ForEach(temporal.declineAreas, id: \.self) { area in
                                    Text("• \(area)")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }

                // Charts for each metric
                ForEach(progressData, id: \.metric) { data in
                    MetricChartView(data: data)
                }
            }
            .padding()
        }
    }
}

/// Individual metric chart
struct MetricChartView: View {
    let data: ProgressData

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(data.metric)
                    .font(.headline)

                Spacer()

                // Trend indicator
                HStack(spacing: 4) {
                    Image(systemName: trendIcon)
                        .foregroundColor(trendColor)
                    Text("\(String(format: "%.1f", abs(data.percentChange)))%")
                        .font(.caption)
                        .foregroundColor(trendColor)
                }
            }

            // Simple line chart
            GeometryReader { geometry in
                Path { path in
                    guard !data.history.isEmpty else { return }

                    let maxValue = data.history.map { $0.value }.max() ?? 100
                    let minValue = data.history.map { $0.value }.min() ?? 0
                    let range = maxValue - minValue

                    let width = geometry.size.width
                    let height = geometry.size.height

                    for (index, point) in data.history.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(max(data.history.count - 1, 1))
                        let normalizedValue = (point.value - minValue) / max(range, 1)
                        let y = height * (1 - CGFloat(normalizedValue))

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.blue, lineWidth: 2)
            }
            .frame(height: 100)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }

    private var trendIcon: String {
        switch data.trend {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    private var trendColor: Color {
        switch data.trend {
        case .up: return .green
        case .down: return .red
        case .stable: return .gray
        }
    }
}
