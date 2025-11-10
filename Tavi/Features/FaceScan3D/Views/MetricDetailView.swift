//
//  MetricDetailView.swift
//  Tavi
//
//  Detailed view for individual metrics (Overall, Glow, Hydration)
//  Shows large ring, history chart, breakdown, and timeline
//  Created on 2025-01-10.
//

import SwiftUI
import Charts

enum MetricType: String, CaseIterable, Identifiable {
    case overall = "Overall Score"
    case smoothness = "Smoothness"
    case hydration = "Hydration"
    case pigmentation = "Evenness"
    case wrinkles = "Wrinkles"
    case elasticity = "Elasticity"
    case volume = "Volume"

    var id: String { rawValue }

    var normalRange: String {
        switch self {
        case .overall: return "80 - 100%"
        case .smoothness: return "75 - 100%"
        case .hydration: return "70 - 100%"
        case .pigmentation: return "75 - 100%"
        case .wrinkles: return "80 - 100%"
        case .elasticity: return "75 - 100%"
        case .volume: return "N/A"
        }
    }

    var icon: String {
        switch self {
        case .overall: return "chart.bar.fill"
        case .smoothness: return "waveform.path"
        case .hydration: return "drop.fill"
        case .pigmentation: return "circle.hexagongrid.fill"
        case .wrinkles: return "line.3.horizontal.decrease"
        case .elasticity: return "arrow.up.and.down.circle"
        case .volume: return "cube.fill"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .overall:
            return [Color(red: 101/255, green: 188/255, blue: 126/255), Color(red: 142/255, green: 218/255, blue: 176/255)]
        case .smoothness:
            return [Color(red: 101/255, green: 188/255, blue: 126/255), Color(red: 142/255, green: 218/255, blue: 176/255)]
        case .hydration:
            return [Color(red: 95/255, green: 158/255, blue: 255/255), Color(red: 142/255, green: 188/255, blue: 255/255)]
        case .pigmentation:
            return [Color(red: 252/255, green: 188/255, blue: 78/255), Color(red: 255/255, green: 199/255, blue: 95/255)]
        case .wrinkles:
            return [Color(red: 180/255, green: 140/255, blue: 200/255), Color(red: 200/255, green: 170/255, blue: 220/255)]
        case .elasticity:
            return [Color(red: 255/255, green: 150/255, blue: 100/255), Color(red: 255/255, green: 180/255, blue: 130/255)]
        case .volume:
            return [Color(red: 120/255, green: 180/255, blue: 255/255), Color(red: 150/255, green: 200/255, blue: 255/255)]
        }
    }
}

enum TimeRange: String, CaseIterable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"

    var days: Int {
        switch self {
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .oneYear: return 365
        }
    }
}

struct MetricDetailView: View {
    let metricType: MetricType

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)],
        animation: .default
    )
    private var sessions: FetchedResults<SessionResult>

    @State private var selectedTab: Tab = .overview
    @State private var selectedTimeRange: TimeRange = .oneMonth
    @State private var showingInfo = false

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case breakdown = "Breakdown"
        case history = "History"
    }

    private var latestSession: SessionResult? {
        sessions.first
    }

    private var latestScore: Double {
        guard let session = latestSession else { return 0 }
        return getScore(for: session)
    }

    private var filteredSessions: [SessionResult] {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        return sessions.filter { $0.date >= cutoffDate }
    }

    private var averageScore: Double {
        let scores = filteredSessions.compactMap { getScore(for: $0) }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    private var highestScore: Double {
        let scores = filteredSessions.compactMap { getScore(for: $0) }
        return scores.max() ?? 0
    }

    private var lowestScore: Double {
        let scores = filteredSessions.compactMap { getScore(for: $0) }
        return scores.min() ?? 0
    }

    var body: some View {
        ZStack {
            // Scenic background
            scenicBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: HeadspaceDesign.Spacing.xl) {
                    // Header with back button
                    headerSection

                    // Large hero ring
                    largeHeroRing

                    // Normal range indicator
                    normalRangeIndicator

                    // Tab selector
                    tabSelector

                    // Tab content
                    Group {
                        switch selectedTab {
                        case .overview:
                            overviewTabContent
                        case .breakdown:
                            breakdownTabContent
                        case .history:
                            historyTabContent
                        }
                    }
                    .padding(.horizontal, HeadspaceDesign.Spacing.lg)

                    Spacer(minLength: 100)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingInfo) {
            MetricInfoSheet(metricType: metricType)
        }
    }

    // MARK: - Scenic Background

    private var scenicBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 240/255, green: 248/255, blue: 255/255),
                Color(red: 255/255, green: 252/255, blue: 245/255),
                Color(red: 245/255, green: 250/255, blue: 255/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            VStack(spacing: 4) {
                Text(metricType.rawValue)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                if let date = latestSession?.date {
                    Text("Today, \(formattedDate(date))")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                }
            }

            Spacer()

            Button {
                showingInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, HeadspaceDesign.Spacing.lg)
        .padding(.top, HeadspaceDesign.Spacing.md)
    }

    // MARK: - Large Hero Ring

    private var largeHeroRing: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 200, height: 200)
                .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)

            Circle()
                .fill(Color.white)
                .frame(width: 180, height: 180)

            // Progress ring
            Circle()
                .trim(from: 0, to: sessions.isEmpty ? 0 : CGFloat(latestScore / 100))
                .stroke(
                    LinearGradient(
                        colors: metricType.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: latestScore)

            // Score text
            VStack(spacing: 4) {
                if sessions.isEmpty {
                    Text("—")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textTertiary)
                } else {
                    Text("\(Int(latestScore))%")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                    Text(qualityLabel(for: latestScore))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                }
            }
        }
        .padding(.vertical, HeadspaceDesign.Spacing.xl)
    }

    // MARK: - Normal Range

    private var normalRangeIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "equal")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(HeadspaceDesign.Colors.textTertiary)

            Text("Normal range")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)

            Text(metricType.normalRange)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)
        }
        .padding(.horizontal, HeadspaceDesign.Spacing.lg)
        .padding(.vertical, HeadspaceDesign.Spacing.sm)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.7))
        )
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(HeadspaceDesign.Animations.smooth) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .medium, design: .rounded))
                        .foregroundColor(selectedTab == tab ? HeadspaceDesign.Colors.primary : HeadspaceDesign.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.white : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.5))
        )
        .padding(.horizontal, HeadspaceDesign.Spacing.lg)
    }

    // MARK: - Overview Tab

    @ViewBuilder
    private var overviewTabContent: some View {
        if sessions.isEmpty {
            emptyStateView
        } else if sessions.count == 1 {
            baselineStateView
        } else {
            chartView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: HeadspaceDesign.Spacing.xl) {
            VStack(spacing: HeadspaceDesign.Spacing.lg) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(HeadspaceDesign.Colors.textTertiary)

                Text("No scan data yet")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text("Complete your first scan to start tracking your \(metricType.rawValue.lowercased()).")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(HeadspaceDesign.Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                    .fill(Color.white.opacity(0.7))
            )

            // Preview of what they'll see
            VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
                Text("What you'll see here:")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                previewChartPlaceholder
            }
        }
        .padding(.vertical, HeadspaceDesign.Spacing.xl)
    }

    private var previewChartPlaceholder: some View {
        VStack(spacing: HeadspaceDesign.Spacing.sm) {
            // Mock chart preview
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(metricType.gradientColors[0].opacity(0.3))
                        .frame(width: 30, height: CGFloat.random(in: 40...120))
                }
            }
            .frame(height: 120)

            Text("Your \(metricType.rawValue.lowercased()) progress over time")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                .fill(Color.white.opacity(0.5))
        )
    }

    private var baselineStateView: some View {
        VStack(spacing: HeadspaceDesign.Spacing.xl) {
            // Single point "chart"
            singlePointChart

            // Baseline message
            VStack(spacing: HeadspaceDesign.Spacing.md) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(HeadspaceDesign.Colors.textTertiary)

                Text("This is your baseline scan")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text("Complete another scan to see your progress trend over time.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(HeadspaceDesign.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                    .fill(Color.white.opacity(0.7))
            )
        }
        .padding(.vertical, HeadspaceDesign.Spacing.xl)
    }

    private var singlePointChart: some View {
        VStack(spacing: HeadspaceDesign.Spacing.md) {
            if let session = sessions.first {
                Chart {
                    PointMark(
                        x: .value("Date", session.date),
                        y: .value("Score", getScore(for: session))
                    )
                    .foregroundStyle(metricType.gradientColors[0])
                    .symbolSize(200)
                }
                .chartYScale(domain: 0...100)
                .frame(height: 200)

                Text("Current: \(Int(latestScore))%")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                .fill(Color.white.opacity(0.7))
        )
    }

    private var chartView: some View {
        VStack(spacing: HeadspaceDesign.Spacing.lg) {
            // Time range filters
            timeRangeFilters

            // Chart
            if filteredSessions.isEmpty {
                emptyTimeRangeView
            } else {
                mainChart
            }
        }
        .padding(.vertical, HeadspaceDesign.Spacing.md)
    }

    private var timeRangeFilters: some View {
        HStack(spacing: HeadspaceDesign.Spacing.sm) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(HeadspaceDesign.Animations.smooth) {
                        selectedTimeRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 14, weight: selectedTimeRange == range ? .semibold : .medium, design: .rounded))
                        .foregroundColor(selectedTimeRange == range ? .white : HeadspaceDesign.Colors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedTimeRange == range ? HeadspaceDesign.Colors.primary : Color.white.opacity(0.5))
                        )
                }
            }
        }
    }

    private var mainChart: some View {
        VStack(spacing: HeadspaceDesign.Spacing.md) {
            Chart {
                ForEach(filteredSessions) { session in
                    LineMark(
                        x: .value("Date", session.date),
                        y: .value("Score", getScore(for: session))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: metricType.gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("Date", session.date),
                        y: .value("Score", getScore(for: session))
                    )
                    .foregroundStyle(metricType.gradientColors[0])
                }

                // Average line
                RuleMark(y: .value("Average", averageScore))
                    .foregroundStyle(HeadspaceDesign.Colors.textTertiary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
            }
            .chartYScale(domain: 0...100)
            .frame(height: 250)

            // Stats row (matching Apple Fitness design)
            HStack(spacing: HeadspaceDesign.Spacing.xl) {
                statItem(label: "Highest", value: Int(highestScore))
                statItem(label: "Lowest", value: Int(lowestScore))
                statItem(label: "Average", value: Int(averageScore))
            }
            .padding(.top, HeadspaceDesign.Spacing.sm)
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                .fill(Color.white.opacity(0.7))
        )
    }

    private func statItem(label: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyTimeRangeView: some View {
        VStack(spacing: HeadspaceDesign.Spacing.md) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(HeadspaceDesign.Colors.textTertiary)

            Text("No scans in this time range")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            Text("Try selecting a different time range or complete a new scan.")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(HeadspaceDesign.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                .fill(Color.white.opacity(0.7))
        )
    }

    // MARK: - Breakdown Tab

    @ViewBuilder
    private var breakdownTabContent: some View {
        if metricType == .overall, let session = latestSession {
            overallBreakdownView(session: session)
        } else {
            singleMetricBreakdownView
        }
    }

    private func overallBreakdownView(session: SessionResult) -> some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.lg) {
            Text("Metrics Breakdown")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            // Try to use full Face3DMetrics first (contains ALL calculated metrics)
            if let metrics = session.face3DMetrics {
                // SKIN HEALTH METRICS (included in Overall Score - 5 metrics only)
                Text("Skin Health Metrics (In Overall Score)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                    .padding(.top, 8)

                Text("These 5 high-confidence metrics (70%+ confidence) are included in your Overall Score.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    .padding(.bottom, 4)

                // 1. Smoothness (22.4%)
                MetricBar(
                    label: "Smoothness (22.4%)",
                    score: Double(metrics.globalRoughnessScore),
                    color: Color(red: 101/255, green: 188/255, blue: 126/255)
                )

                // 2. Pigmentation (22.4%)
                MetricBar(
                    label: "Pigmentation (22.4%)",
                    score: Double(metrics.globalPigmentationScore),
                    color: Color(red: 142/255, green: 218/255, blue: 176/255)
                )

                // 3. Pores (14.9%)
                if let pores = metrics.poreAnalysis {
                    MetricBar(
                        label: "Pores (14.9%)",
                        score: Double(pores.visibilityScore),
                        color: Color(red: 149/255, green: 165/255, blue: 166/255)
                    )
                }

                // 4. Discoloration (14.9%)
                MetricBar(
                    label: "Discoloration (14.9%)",
                    score: Double(metrics.globalDiscolorationScore),
                    color: Color(red: 255/255, green: 179/255, blue: 102/255)
                )

                // 5. Acne (14.9%)
                if let acne = metrics.acneAnalysis {
                    MetricBar(
                        label: "Acne (14.9%)",
                        score: Double(acne.overallScore),
                        color: Color(red: 255/255, green: 102/255, blue: 102/255)
                    )
                }

                // ADDITIONAL INDICATORS (Not in Overall Score)
                Divider()
                    .padding(.vertical, 8)

                Text("Additional Indicators (Not in Overall Score)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                Text("These metrics provide supplementary insights but aren't included in the Overall Score due to measurement limitations.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    .padding(.bottom, 4)

                // Elasticity (requires 2+ scans)
                if let elasticity = metrics.elasticityAnalysis {
                    MetricBar(
                        label: "Elasticity (requires 2+ scans)",
                        score: Double(elasticity.overallScore),
                        color: Color(red: 30/255, green: 144/255, blue: 255/255)
                    )
                }

                // Hydration (proxy method, ~65% confidence)
                let hydrationScore: Double = {
                    let roiScores = metrics.roiMetrics.values.map { Double($0.moistureProxy.moistureIndex) * 100 }
                    guard !roiScores.isEmpty else { return 0 }
                    return roiScores.reduce(0, +) / Double(roiScores.count)
                }()
                MetricBar(
                    label: "Hydration (proxy method)",
                    score: hydrationScore,
                    color: Color(red: 95/255, green: 158/255, blue: 255/255)
                )

                // Redness (measurement limitations)
                if let redness = metrics.rednessAnalysis {
                    MetricBar(
                        label: "Redness (measurement limitations)",
                        score: Double(redness.overallScore),
                        color: Color(red: 255/255, green: 140/255, blue: 157/255)
                    )
                }

                // Oil Control (disabled)
                if let specularScore = metrics.globalSpecularScore {
                    MetricBar(
                        label: "Oil Control (disabled)",
                        score: Double(specularScore),
                        color: Color(red: 255/255, green: 215/255, blue: 0/255)
                    )
                }

                // AGING INDICATORS (separate from Skin Health Score)
                Divider()
                    .padding(.vertical, 8)

                Text("Aging Indicators")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                if let wrinkles = metrics.wrinkleAnalysis {
                    MetricBar(
                        label: "Wrinkles",
                        score: Double(wrinkles.overallScore),
                        color: Color(red: 180/255, green: 140/255, blue: 200/255)
                    )
                }

                if let volume = metrics.volumeAnalysis {
                    MetricBar(
                        label: "Volume",
                        score: Double(volume.overallScore),
                        color: Color(red: 120/255, green: 180/255, blue: 255/255)
                    )
                }

                // OTHER INDICATORS
                Divider()
                    .padding(.vertical, 8)

                Text("Other Indicators")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                MetricBar(
                    label: "Glow (Composite)",
                    score: Double(metrics.glowAnalysis?.glowScore ?? 0),
                    color: Color(red: 252/255, green: 188/255, blue: 78/255)
                )

                if let sunDamage = metrics.sunDamageAnalysis {
                    MetricBar(
                        label: "Sun Protection",
                        score: Double(sunDamage.protectionScore),
                        color: Color(red: 255/255, green: 199/255, blue: 95/255)
                    )
                }

                if let topology = metrics.topologyAnalysis {
                    MetricBar(
                        label: "Mesh Quality",
                        score: Double(topology.overallScore),
                        color: Color(red: 60/255, green: 179/255, blue: 113/255)
                    )
                }

            } else {
                // Fallback to basic averaged metrics (for older scans without Face3DMetrics)
                MetricBar(label: "Smoothness", score: session.textureAvg, color: Color(red: 101/255, green: 188/255, blue: 126/255))
                MetricBar(label: "Hydration", score: session.moistureSpecular, color: Color(red: 95/255, green: 158/255, blue: 255/255))
                MetricBar(label: "Evenness", score: session.pigmentationAvg, color: Color(red: 252/255, green: 188/255, blue: 78/255))
                MetricBar(label: "Sharpness", score: session.blurQuality, color: Color(red: 149/255, green: 165/255, blue: 166/255))
                MetricBar(label: "Discoloration", score: 100 - session.discolorationIndex, color: Color(red: 255/255, green: 102/255, blue: 102/255))
            }
        }
        .padding(.vertical, HeadspaceDesign.Spacing.lg)
    }

    private var singleMetricBreakdownView: some View {
        VStack(spacing: HeadspaceDesign.Spacing.lg) {
            Text("Score Ranges")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            ScoreRangeLegend()
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                .fill(Color.white.opacity(0.7))
        )
    }

    // MARK: - History Tab

    @ViewBuilder
    private var historyTabContent: some View {
        if sessions.isEmpty {
            emptyStateView
        } else {
            historyListView
        }
    }

    private var historyListView: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            Text("Scan History")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                historyRow(session: session, index: index)
            }
        }
        .padding(.vertical, HeadspaceDesign.Spacing.lg)
    }

    private func historyRow(session: SessionResult, index: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate(session.date))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text(relativeDate(session.date))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }

            Spacer()

            Text("\(Int(getScore(for: session)))%")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(scoreColor(getScore(for: session)))

            if index < sessions.count - 1 {
                let previousScore = getScore(for: sessions[index + 1])
                let currentScore = getScore(for: session)
                let trend = currentScore - previousScore

                if abs(trend) > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                        Text("\(trend > 0 ? "+" : "")\(Int(trend))")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(trend > 0 ? .green : .red)
                }
            }
        }
        .padding(HeadspaceDesign.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md)
                .fill(Color.white.opacity(0.7))
        )
    }

    // MARK: - Helper Functions

    private func getScore(for session: SessionResult) -> Double {
        switch metricType {
        case .overall:
            return session.overallScore
        case .smoothness:
            return session.textureAvg
        case .hydration:
            return session.moistureSpecular
        case .pigmentation:
            return session.pigmentationAvg
        }
    }

    private func qualityLabel(for score: Double) -> String {
        switch score {
        case 85...100: return "Excellent"
        case 70..<85: return "Good"
        case 50..<70: return "Fair"
        default: return "Needs Improvement"
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 85...100: return .green
        case 70..<85: return Color(red: 101/255, green: 188/255, blue: 126/255)
        case 50..<70: return .yellow
        default: return .orange
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date, to: Date())

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let days = components.day, days < 7 {
            return "\(days) days ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Supporting Views

struct MetricBar: View {
    let label: String
    let score: Double
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                .frame(width: 110, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(score / 100))
                }
            }
            .frame(height: 8)

            Text("\(Int(score))%")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }
}

struct ScoreRangeLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            legendRow(color: .green, label: "Excellent", range: "85 - 100%")
            legendRow(color: Color(red: 101/255, green: 188/255, blue: 126/255), label: "Good", range: "70 - 84%")
            legendRow(color: .yellow, label: "Fair", range: "50 - 69%")
            legendRow(color: .orange, label: "Needs Improvement", range: "0 - 49%")
        }
    }

    private func legendRow(color: Color, label: String, range: String) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Text(label)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            Spacer()

            Text(range)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
        }
    }
}

// MARK: - Metric Info Sheet

struct MetricInfoSheet: View {
    let metricType: MetricType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.lg) {
                    // What is this metric?
                    sectionHeader("What is \(metricType.rawValue)?")
                    Text(metricDescription)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                    // What affects this?
                    sectionHeader("What Affects This Metric?")
                    VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.sm) {
                        ForEach(affectingFactors, id: \.self) { factor in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text(factor)
                            }
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                        }
                    }

                    // Normal Range
                    sectionHeader("Normal Range")
                    Text(metricType.normalRange)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                }
                .padding(HeadspaceDesign.Spacing.lg)
            }
            .background(HeadspaceDesign.Colors.background)
            .navigationTitle("About \(metricType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(HeadspaceDesign.Colors.textPrimary)
    }

    private var metricDescription: String {
        switch metricType {
        case .overall:
            return "Your overall skin health score is calculated using 5 high-confidence metrics (70%+ confidence): Smoothness (22.4%), Pigmentation (22.4%), Pores (14.9%), Discoloration (14.9%), and Acne (14.9%). Additional indicators (Elasticity, Hydration, Oil Control, Redness) are displayed separately due to measurement limitations but aren't included in the Overall Score."
        case .smoothness:
            return "Smoothness measures the texture quality of your skin surface, including fine lines, pores, and overall surface consistency. Higher scores indicate smoother, more refined skin texture."
        case .hydration:
            return "Hydration reflects your skin's moisture levels and water content. Well-hydrated skin appears plump, supple, and resilient, while dehydrated skin may look dull or feel tight."
        case .pigmentation:
            return "Evenness measures the uniformity of your skin tone and pigmentation. Higher scores indicate more consistent coloring without dark spots, redness, or uneven patches."
        case .wrinkles:
            return "Wrinkles analysis measures the depth and distribution of lines on your face, categorized as fine lines, moderate wrinkles, or deep wrinkles. This metric uses 3D depth measurement to detect creases and folds. Higher scores indicate fewer or shallower wrinkles."
        case .elasticity:
            return "Elasticity measures your skin's ability to bounce back and recover from deformation. The recovery rate (0-1 scale) indicates how quickly your skin returns to its original shape. Higher scores suggest better collagen health and skin firmness."
        case .volume:
            return "Volume analysis measures facial structure changes including cheek protrusion (in mm), volume loss percentage, under-eye bags, and facial symmetry. These measurements track structural changes in your face over time, distinct from skin surface quality."
        }
    }

    private var affectingFactors: [String] {
        switch metricType {
        case .overall:
            return [
                "Sleep quality and duration",
                "Hydration and water intake",
                "Sun exposure and protection",
                "Skincare routine consistency",
                "Diet and nutrition",
                "Stress levels"
            ]
        case .smoothness:
            return [
                "Exfoliation frequency",
                "Moisturizer usage",
                "Sun damage and aging",
                "Genetics",
                "Skincare product quality"
            ]
        case .hydration:
            return [
                "Water intake",
                "Environmental humidity",
                "Weather conditions",
                "Moisturizer effectiveness",
                "Time of day"
            ]
        case .pigmentation:
            return [
                "Sun exposure",
                "Skincare products with brightening ingredients",
                "Genetics and skin type",
                "Hormonal changes",
                "Post-inflammatory response"
            ]
        case .wrinkles:
            return [
                "Sun exposure and UV damage",
                "Natural aging process",
                "Facial expressions and muscle movement",
                "Smoking and lifestyle factors",
                "Collagen production",
                "Retinol and anti-aging treatments"
            ]
        case .elasticity:
            return [
                "Collagen and elastin production",
                "Age and natural degradation",
                "UV exposure",
                "Hydration levels",
                "Nutrition (vitamin C, protein)",
                "Facial massage and treatments"
            ]
        case .volume:
            return [
                "Natural aging and fat pad loss",
                "Bone density changes",
                "Weight fluctuations",
                "Genetics and facial structure",
                "Sleep position",
                "Facial fillers or treatments"
            ]
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MetricDetailView(metricType: .overall)
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
