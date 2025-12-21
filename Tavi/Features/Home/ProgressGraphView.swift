//
//  ProgressGraphView.swift
//  Tavi
//
//  Line chart showing glow score progression over time
//  Created on 2025-11-04.
//

import SwiftUI
import Charts

/// Time period filter for progress graph
public enum ProgressTimePeriod: String, CaseIterable {
    case week = "7D"
    case month = "30D"
    case all = "All"

    var displayName: String {
        switch self {
        case .week: return "7 Days"
        case .month: return "30 Days"
        case .all: return "All Time"
        }
    }

    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .all: return nil
        }
    }
}

/// Progress graph showing glow score over time
public struct ProgressGraphView: View {
    let sessions: [SessionResult]
    @State private var selectedPeriod: ProgressTimePeriod = .month
    @State private var selectedSession: SessionResult?

    public init(sessions: [SessionResult]) {
        self.sessions = sessions
    }

    private var filteredSessions: [SessionResult] {
        guard let days = selectedPeriod.days else {
            return sessions
        }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return sessions.filter { $0.date >= cutoffDate }
    }

    private var sortedSessions: [SessionResult] {
        filteredSessions.sorted { $0.date < $1.date }
    }

    private var hasData: Bool {
        sortedSessions.count >= 2
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header with period selector
            VStack(spacing: Designs.Spacing.md) {
                HStack {
                    Text("Progress Over Time")
                        .font(AppFont.title3)
                        .foregroundColor(Designs.Colors.textPrimary)

                    Spacer()

                    // Period selector
                    HStack(spacing: Designs.Spacing.xxSmall) {
                        ForEach(ProgressTimePeriod.allCases, id: \.self) { period in
                            Button {
                                withAnimation(Designs.Animation.standard) {
                                    selectedPeriod = period
                                    selectedSession = nil
                                }
                            } label: {
                                Text(period.rawValue)
                                    .font(AppFont.label)
                                    .foregroundColor(selectedPeriod == period ? .white : Designs.Colors.textSecondary)
                                    .padding(.horizontal, Designs.Spacing.small)
                                    .padding(.vertical, Designs.Spacing.xxSmall)
                                    .background(selectedPeriod == period ? Designs.Colors.primary : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.tiny))
                            }
                        }
                    }
                    .padding(Designs.Spacing.xxSmall)
                    .background(Designs.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.small))
                }

                // Stats summary
                if hasData {
                    statsRow
                }
            }
            .padding(Designs.Spacing.xl)
            .background(Designs.Colors.elevatedCard)

            // Chart
            if hasData {
                chartView
                    .id(selectedPeriod) // Force re-render when period changes
                    .frame(height: Designs.Sizes.graphHeight)
                    .padding(.horizontal, Designs.Spacing.lg)
                    .padding(.vertical, Designs.Spacing.xl)
                    .background(Designs.Colors.elevatedCard)
            } else {
                emptyState
                    .frame(height: Designs.Sizes.graphHeight)
                    .padding(Designs.Spacing.xl)
                    .background(Designs.Colors.elevatedCard)
            }
        }
        .background(Designs.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
        .shadow(
            color: Designs.Shadows.card.color,
            radius: Designs.Shadows.card.radius,
            x: Designs.Shadows.card.x,
            y: Designs.Shadows.card.y
        )
    }

    private var statsRow: some View {
        HStack(spacing: Designs.Spacing.xl) {
            // Trend
            VStack(alignment: .leading, spacing: Designs.Spacing.xxSmall) {
                Text("Trend")
                    .font(AppFont.captionSmall)
                    .foregroundColor(Designs.Colors.textSecondary)

                HStack(spacing: Designs.Spacing.xxSmall) {
                    if let trend = calculateTrend() {
                        Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(AppFont.caption)
                            .foregroundColor(trend > 0 ? .green : .red)

                        Text("\(trend > 0 ? "+" : "")\(String(format: "%.1f", trend))%")
                            .font(AppFont.bodyMedium)
                            .foregroundColor(trend > 0 ? .green : .red)
                    }
                }
            }

            Divider()
                .frame(height: Designs.Sizes.graphBarHeight)

            // Average score
            VStack(alignment: .leading, spacing: Designs.Spacing.xxSmall) {
                Text("Average")
                    .font(AppFont.captionSmall)
                    .foregroundColor(Designs.Colors.textSecondary)

                Text("\(Int(averageScore))")
                    .font(AppFont.bodyMedium)
                    .foregroundColor(Designs.Colors.textPrimary)
            }

            Divider()
                .frame(height: Designs.Sizes.graphBarHeight)

            // Best score
            VStack(alignment: .leading, spacing: Designs.Spacing.xxSmall) {
                Text("Best")
                    .font(AppFont.captionSmall)
                    .foregroundColor(Designs.Colors.textSecondary)

                HStack(spacing: Designs.Spacing.xxSmall) {
                    Image(systemName: "star.fill")
                        .font(AppFont.captionSmall)
                        .foregroundColor(.yellow)

                    Text("\(Int(bestScore))")
                        .font(AppFont.bodyMedium)
                        .foregroundColor(Designs.Colors.textPrimary)
                }
            }
        }
    }

    @ViewBuilder
    private var chartView: some View {
        if #available(iOS 16.0, *) {
            Chart {
                // Use enumerated to get index for equidistant X-axis spacing
                ForEach(Array(sortedSessions.enumerated()), id: \.element.id) { index, session in
                    // Line mark: X=Scan Index (equidistant), Y=Score
                    LineMark(
                        x: .value("Scan", index),
                        y: .value("Score", session.overallScore)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Designs.ScoreColors.graphBlueLight,
                                Designs.ScoreColors.graphBlueDark
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    // Area under line: X=Scan Index (equidistant), Y=Score
                    AreaMark(
                        x: .value("Scan", index),
                        y: .value("Score", session.overallScore)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Designs.ScoreColors.graphBlueLight.opacity(0.3),
                                Designs.ScoreColors.graphBlueLight.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Data points: X=Scan Index (equidistant), Y=Score
                    PointMark(
                        x: .value("Scan", index),
                        y: .value("Score", session.overallScore)
                    )
                    .foregroundStyle(Color.white)
                    .symbolSize(selectedSession?.id == session.id ? 150 : 80)
                    .annotation(position: .top, spacing: Designs.Spacing.xSmall) {
                        if selectedSession?.id == session.id {
                            VStack(spacing: Designs.Spacing.xxSmall) {
                                Text("\(Int(session.overallScore))")
                                    .font(AppFont.bodyMedium)
                                    .foregroundColor(.white)

                                Text(formatDate(session.date))
                                    .font(AppFont.captionSmall)
                                    .foregroundColor(.white.opacity(Designs.Opacity.almostOpaque))
                            }
                            .padding(.horizontal, Designs.Spacing.small)
                            .padding(.vertical, Designs.Spacing.xSmall)
                            .background(
                                RoundedRectangle(cornerRadius: Designs.Radius.small)
                                    .fill(Designs.ScoreColors.graphBlueDark)
                                    .shadow(color: .black.opacity(Designs.Opacity.veryLight), radius: Designs.Spacing.xxSmall, y: Designs.Border.widthThick)
                            )
                        }
                    }
                }
            }
            .chartYScale(domain: 0...100)  // Y-axis is Score (0-100)
            .chartXScale(domain: 0...(max(1, sortedSessions.count - 1)))  // X-axis is scan index
            .chartXAxis {
                // X-axis shows scan number with date label - equidistant spacing
                let totalScans = sortedSessions.count
                let desiredMarks = min(totalScans, 5)  // Show up to 5 labels
                AxisMarks(values: .automatic(desiredCount: desiredMarks)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.3))
                    AxisTick(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.white.opacity(0.5))
                    if let index = value.as(Int.self), index >= 0 && index < sortedSessions.count {
                        let session = sortedSessions[index]
                        AxisValueLabel {
                            VStack(spacing: Designs.Spacing.xxxSmall) {
                                Text(formatTime(session.date))
                                    .font(AppFont.captionSmall)
                                    .foregroundColor(.white)
                                Text(formatDateShort(session.date))
                                    .font(AppFont.micro)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }
            .chartYAxis {
                // Y-axis shows score values (0, 25, 50, 75, 100)
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.3))
                    AxisTick(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.white.opacity(0.5))
                    AxisValueLabel()
                        .foregroundStyle(Color.white)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let location = value.location
                                    // X-axis now has scan indices
                                    if let scanIndex: Int = proxy.value(atX: location.x) {
                                        // Find session at this index (clamped to valid range)
                                        let clampedIndex = max(0, min(scanIndex, sortedSessions.count - 1))
                                        if clampedIndex < sortedSessions.count {
                                            selectedSession = sortedSessions[clampedIndex]
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    // Keep selection visible for a moment
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        selectedSession = nil
                                    }
                                }
                        )
                }
            }
        } else {
            // Fallback for iOS 15
            legacyChartView
        }
    }

    private var legacyChartView: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid lines
                VStack(spacing: 0) {
                    ForEach(0..<5) { i in
                        HStack {
                            Text("\(100 - i * 25)")
                                .font(AppFont.captionSmall)
                                .foregroundColor(.gray)
                                .frame(width: Designs.Sizes.frameWidthTiny, alignment: .trailing)

                            Rectangle()
                                .fill(Designs.Colors.border.opacity(Designs.Opacity.light))
                                .frame(height: Designs.Sizes.frameHeightBarXSmall)
                        }

                        if i < 4 {
                            Spacer()
                        }
                    }
                }

                // Line chart
                Path { path in
                    let points = sortedSessions.enumerated().map { index, session -> CGPoint in
                        let x = 30 + (geometry.size.width - 30) * CGFloat(index) / CGFloat(max(1, sortedSessions.count - 1))
                        let y = geometry.size.height * CGFloat(1 - session.overallScore / 100)
                        return CGPoint(x: x, y: y)
                    }

                    guard let first = points.first else { return }
                    path.move(to: first)

                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(Designs.Colors.info, lineWidth: Designs.Border.widthThick)

                // Data points
                ForEach(Array(sortedSessions.enumerated()), id: \.element.id) { index, session in
                    let x = 30 + (geometry.size.width - 30) * CGFloat(index) / CGFloat(max(1, sortedSessions.count - 1))
                    let y = geometry.size.height * CGFloat(1 - session.overallScore / 100)

                    Circle()
                        .fill(Designs.Colors.info)
                        .frame(width: Designs.Sizes.progressIndicatorSmall, height: Designs.Sizes.progressIndicatorSmall)
                        .position(x: x, y: y)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Designs.Spacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(AppFont.scoreMedium)
                .foregroundColor(Designs.Colors.textTertiary)

            Text("Not enough data yet")
                .font(AppFont.headline)
                .foregroundColor(Designs.Colors.textPrimary)

            Text("Complete at least 2 scans to see your progress")
                .font(AppFont.caption)
                .foregroundColor(Designs.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    private func calculateTrend() -> Double? {
        guard sortedSessions.count >= 2,
              let first = sortedSessions.first,
              let last = sortedSessions.last else {
            return nil
        }

        return ((last.overallScore - first.overallScore) / first.overallScore) * 100
    }

    private var averageScore: Double {
        guard !sortedSessions.isEmpty else { return 0 }
        return sortedSessions.map(\.overallScore).reduce(0, +) / Double(sortedSessions.count)
    }

    private var bestScore: Double {
        sortedSessions.map(\.overallScore).max() ?? 0
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    /// Format time as "5:22 PM"
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    /// Format date as "(13 May)" or just "13 May"
    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "(\(formatter.string(from: date)))"
    }
}

#Preview {
    // Create sample data
    let sampleSessions: [SessionResult] = (0..<10).compactMap { i in
        let context = PersistenceController.preview.viewContext
        let session = SessionResult(context: context)
        session.id = UUID()
        guard let date = Calendar.current.date(byAdding: .day, value: -i * 3, to: Date()) else {
            return nil
        }
        session.date = date
        session.overallScore = Double.random(in: 60...90)
        return session
    }

    return ProgressGraphView(sessions: sampleSessions)
        .padding()
}
