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
            VStack(spacing: HeadspaceDesign.Spacing.md) {
                HStack {
                    Text("Progress Over Time")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                    Spacer()

                    // Period selector
                    HStack(spacing: 4) {
                        ForEach(ProgressTimePeriod.allCases, id: \.self) { period in
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedPeriod = period
                                    selectedSession = nil
                                }
                            } label: {
                                Text(period.rawValue)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(selectedPeriod == period ? .white : HeadspaceDesign.Colors.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedPeriod == period ? HeadspaceDesign.Colors.primary : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .padding(4)
                    .background(HeadspaceDesign.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Stats summary
                if hasData {
                    statsRow
                }
            }
            .padding(HeadspaceDesign.Spacing.xl)
            .background(HeadspaceDesign.Colors.elevatedCard)

            // Chart
            if hasData {
                chartView
                    .frame(height: 220)
                    .padding(.horizontal, HeadspaceDesign.Spacing.lg)
                    .padding(.vertical, HeadspaceDesign.Spacing.xl)
                    .background(HeadspaceDesign.Colors.elevatedCard)
            } else {
                emptyState
                    .frame(height: 220)
                    .padding(HeadspaceDesign.Spacing.xl)
                    .background(HeadspaceDesign.Colors.elevatedCard)
            }
        }
        .background(HeadspaceDesign.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    private var statsRow: some View {
        HStack(spacing: HeadspaceDesign.Spacing.xl) {
            // Trend
            VStack(alignment: .leading, spacing: 4) {
                Text("Trend")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                HStack(spacing: 4) {
                    if let trend = calculateTrend() {
                        Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(trend > 0 ? .green : .red)

                        Text("\(trend > 0 ? "+" : "")\(String(format: "%.1f", trend))%")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(trend > 0 ? .green : .red)
                    }
                }
            }

            Divider()
                .frame(height: 40)

            // Average score
            VStack(alignment: .leading, spacing: 4) {
                Text("Average")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                Text("\(Int(averageScore))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)
            }

            Divider()
                .frame(height: 40)

            // Best score
            VStack(alignment: .leading, spacing: 4) {
                Text("Best")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)

                    Text("\(Int(bestScore))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                }
            }
        }
    }

    @ViewBuilder
    private var chartView: some View {
        if #available(iOS 16.0, *) {
            Chart {
                ForEach(sortedSessions, id: \.id) { session in
                    // Line mark: X=Date/Time, Y=Score
                    LineMark(
                        x: .value("Date", session.date),
                        y: .value("Score", session.overallScore)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 99/255, green: 179/255, blue: 237/255),  // Light blue
                                Color(red: 56/255, green: 149/255, blue: 211/255)   // Darker blue
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    // Area under line: X=Date/Time, Y=Score
                    AreaMark(
                        x: .value("Date", session.date),
                        y: .value("Score", session.overallScore)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 99/255, green: 179/255, blue: 237/255).opacity(0.3),
                                Color(red: 99/255, green: 179/255, blue: 237/255).opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Data points: X=Date/Time, Y=Score
                    PointMark(
                        x: .value("Date", session.date),
                        y: .value("Score", session.overallScore)
                    )
                    .foregroundStyle(Color.white)
                    .symbolSize(selectedSession?.id == session.id ? 150 : 80)
                    .annotation(position: .top, spacing: 8) {
                        if selectedSession?.id == session.id {
                            VStack(spacing: 4) {
                                Text("\(Int(session.overallScore))")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)

                                Text(formatDate(session.date))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 56/255, green: 149/255, blue: 211/255))
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            )
                        }
                    }
                }
            }
            .chartYScale(domain: 0...100)  // Y-axis is Score (0-100)
            .chartXAxis {
                // X-axis shows time + date in format: "5:22 PM (13 May)"
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                    AxisTick()
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            VStack(spacing: 2) {
                                Text(formatTime(date))
                                    .font(.system(size: 10, weight: .medium))
                                Text(formatDateShort(date))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .chartYAxis {
                // Y-axis shows score values (0, 25, 50, 75, 100)
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel()
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
                                    // X-axis has dates
                                    if let date: Date = proxy.value(atX: location.x) {
                                        // Find closest session
                                        if let closestSession = sortedSessions.min(by: {
                                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                        }) {
                                            selectedSession = closestSession
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
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .frame(width: 30, alignment: .trailing)

                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 1)
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
                .stroke(Color.blue, lineWidth: 2)

                // Data points
                ForEach(Array(sortedSessions.enumerated()), id: \.element.id) { index, session in
                    let x = 30 + (geometry.size.width - 30) * CGFloat(index) / CGFloat(max(1, sortedSessions.count - 1))
                    let y = geometry.size.height * CGFloat(1 - session.overallScore / 100)

                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: HeadspaceDesign.Spacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(HeadspaceDesign.Colors.textTertiary)

            Text("Not enough data yet")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            Text("Complete at least 2 scans to see your progress")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    private func calculateTrend() -> Double? {
        guard sortedSessions.count >= 2 else { return nil }

        let first = sortedSessions.first!.overallScore
        let last = sortedSessions.last!.overallScore

        return ((last - first) / first) * 100
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
    let sampleSessions: [SessionResult] = (0..<10).map { i in
        let context = PersistenceController.preview.viewContext
        let session = SessionResult(context: context)
        session.id = UUID()
        session.date = Calendar.current.date(byAdding: .day, value: -i * 3, to: Date())!
        session.overallScore = Double.random(in: 60...90)
        return session
    }

    return ProgressGraphView(sessions: sampleSessions)
        .padding()
}
