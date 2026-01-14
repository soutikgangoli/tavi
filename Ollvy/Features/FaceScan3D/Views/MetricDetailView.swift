//
//  MetricDetailView.swift
//  Ollvy
//
//  Detailed view for individual metrics (Overall, Glow, Hydration)
//  Shows large ring, history chart, breakdown, and timeline
//  Created on 2025-01-10.
//

import SwiftUI
import Charts

public enum UserMetricType: String, CaseIterable, Identifiable {
    case overall = "Overall Score"
    case smoothness = "Smoothness"
    case hydration = "Hydration"
    case pigmentation = "Evenness"
    case wrinkles = "Wrinkles"
    case elasticity = "Elasticity"
    case volume = "Volume"

    public var id: String { rawValue }

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
            return Designs.Colors.metricOverallColors
        case .smoothness:
            return Designs.Colors.metricOverallColors
        case .hydration:
            return Designs.Colors.metricHydrationColors
        case .pigmentation:
            return Designs.Colors.metricPigmentationColors
        case .wrinkles:
            return Designs.Colors.metricWrinklesColors
        case .elasticity:
            return Designs.Colors.metricElasticityColors
        case .volume:
            return Designs.Colors.metricVolumeColors
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

public struct MetricDetailView: View {
    let metricType: UserMetricType

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)],
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

    public var body: some View {
        ZStack {
            // Scenic background
            scenicBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: Designs.Spacing.xl) {
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
                    .padding(.horizontal, Designs.Spacing.lg)

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
                Designs.Colors.background,
                Designs.Colors.cardBackground,
                Designs.Colors.background
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
                    .font(AppFont.metricValue)
                    .foregroundColor(Designs.Colors.textPrimary)
                    .frame(width: Designs.Sizes.iconMedium, height: Designs.Sizes.iconMedium)
            }

            Spacer()

            VStack(spacing: Designs.Spacing.xxSmall) {
                Text(metricType.rawValue)
                    .font(AppFont.title3)
                    .foregroundColor(Designs.Colors.textPrimary)

                if let date = latestSession?.date {
                    Text("Today, \(formattedDate(date))")
                        .font(AppFont.caption)
                        .foregroundColor(Designs.Colors.textSecondary)
                }
            }

            Spacer()

            Button {
                showingInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(AppFont.metricValue)
                    .foregroundColor(Designs.Colors.textSecondary)
                    .frame(width: Designs.Sizes.iconMedium, height: Designs.Sizes.iconMedium)
            }
        }
        .padding(.horizontal, Designs.Spacing.lg)
        .padding(.top, Designs.Spacing.md)
    }

    // MARK: - Large Hero Ring

    private var largeHeroRing: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.white.opacity(Designs.Opacity.semiOpaque))
                .frame(width: Designs.Sizes.metricChart, height: Designs.Sizes.metricChart)
                .shadow(color: Color.black.opacity(Designs.Opacity.veryLight / 2), radius: Designs.Spacing.lg, x: 0, y: Designs.Spacing.small)

            Circle()
                .fill(Color.white)
                .frame(width: Designs.Sizes.metricChartSmall, height: Designs.Sizes.metricChartSmall)

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
                .frame(width: Designs.Sizes.metricChartSmall, height: Designs.Sizes.metricChartSmall)
                .rotationEffect(.degrees(-90))
                .animation(Designs.Animation.gentleSpring, value: latestScore)

            // Score text
            VStack(spacing: 4) {
                if sessions.isEmpty {
                    Text("—")
                        .font(.scoreFont(size: 56))
                        .foregroundColor(Designs.Colors.textTertiary)
                } else {
                    Text("\(Int(latestScore))%")
                        .font(.scoreFont(size: 56))
                        .foregroundColor(Designs.Colors.textPrimary)

                    Text(qualityLabel(for: latestScore))
                        .font(.app(size: 16, weight: .medium))
                        .foregroundColor(Designs.Colors.textSecondary)
                }
            }
        }
        .padding(.vertical, Designs.Spacing.xl)
    }

    // MARK: - Normal Range

    private var normalRangeIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "equal")
                .font(AppFont.metricLabel)
                .foregroundColor(Designs.Colors.textTertiary)

            Text("Normal range")
                .font(AppFont.caption)
                .foregroundColor(Designs.Colors.textSecondary)

            Text(metricType.normalRange)
                .font(AppFont.label)
                .foregroundColor(Designs.Colors.textPrimary)
        }
        .padding(.horizontal, Designs.Spacing.lg)
        .padding(.vertical, Designs.Spacing.sm)
        .background(
            Capsule()
                .fill(Color.white.opacity(Designs.Opacity.semiTransparent))
        )
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(Designs.Animations.smooth) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.app(size: 15, weight: selectedTab == tab ? .semibold : .medium, design: .rounded))
                        .foregroundColor(selectedTab == tab ? Designs.Colors.primary : Designs.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Designs.Spacing.small)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.white : Color.clear)
                        )
                }
            }
        }
                .padding(Designs.Spacing.xxSmall)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(Designs.Opacity.semiOpaque))
        )
        .padding(.horizontal, Designs.Spacing.lg)
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
        VStack(spacing: Designs.Spacing.xl) {
            VStack(spacing: Designs.Spacing.lg) {
                Image(systemName: "chart.bar.xaxis")
                    .font(AppFont.scoreMedium)
                    .foregroundColor(Designs.Colors.textTertiary)

                Text("No scan data yet")
                    .font(AppFont.headlinePrimary)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text("Complete your first scan to start tracking your \(metricType.rawValue.lowercased()).")
                    .font(AppFont.bodySecondary)
                    .foregroundColor(Designs.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Designs.Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: Designs.Radius.lg)
                    .fill(Color.white.opacity(Designs.Opacity.semiTransparent))
            )

            // Preview of what they'll see
            VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                Text("What you'll see here:")
                    .font(AppFont.subheadingPrimary)
                    .foregroundColor(Designs.Colors.textPrimary)

                previewChartPlaceholder
            }
        }
        .padding(.vertical, Designs.Spacing.xl)
    }

    private var previewChartPlaceholder: some View {
        VStack(spacing: Designs.Spacing.sm) {
            // Mock chart preview
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(metricType.gradientColors[0].opacity(Designs.Opacity.medium))
                        .frame(width: Designs.Sizes.frameWidthTiny, height: CGFloat.random(in: Designs.Sizes.frameMedium...Designs.Sizes.achievementIcon))
                }
            }
            .frame(height: Designs.Sizes.achievementIcon)

            Text("Your \(metricType.rawValue.lowercased()) progress over time")
                .font(AppFont.caption)
                .foregroundColor(Designs.Colors.textSecondary)
        }
        .padding(Designs.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Designs.Radius.lg)
                .fill(Color.white.opacity(Designs.Opacity.semiOpaque))
        )
    }

    private var baselineStateView: some View {
        VStack(spacing: Designs.Spacing.xl) {
            // Single point "chart"
            singlePointChart

            // Baseline message
            VStack(spacing: Designs.Spacing.md) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(AppFont.title)
                    .foregroundColor(Designs.Colors.textTertiary)

                Text("This is your baseline scan")
                    .font(AppFont.headlineSecondary)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text("Complete another scan to see your progress trend over time.")
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Designs.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Designs.Radius.lg)
                    .fill(Color.white.opacity(Designs.Opacity.semiTransparent))
            )
        }
        .padding(.vertical, Designs.Spacing.xl)
    }

    private var singlePointChart: some View {
        VStack(spacing: Designs.Spacing.md) {
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
                .frame(height: Designs.Sizes.metricChart)

                Text("Current: \(Int(latestScore))%")
                    .font(AppFont.headline)
                    .foregroundColor(Designs.Colors.textPrimary)
            }
        }
        .padding(Designs.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Designs.Radius.lg)
                .fill(Color.white.opacity(Designs.Opacity.semiTransparent))
        )
    }

    private var chartView: some View {
        VStack(spacing: Designs.Spacing.lg) {
            // Time range filters
            timeRangeFilters

            // Chart
            if filteredSessions.isEmpty {
                emptyTimeRangeView
            } else {
                mainChart
            }
        }
        .padding(.vertical, Designs.Spacing.md)
    }

    private var timeRangeFilters: some View {
        HStack(spacing: Designs.Spacing.sm) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(Designs.Animations.smooth) {
                        selectedTimeRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.app(size: 14, weight: selectedTimeRange == range ? .semibold : .medium, design: .rounded))
                        .foregroundColor(selectedTimeRange == range ? .white : Designs.Colors.textSecondary)
                        .padding(.horizontal, Designs.Spacing.medium)
                        .padding(.vertical, Designs.Spacing.xSmall)
                        .background(
                            Capsule()
                                .fill(selectedTimeRange == range ? Designs.Colors.primary : Color.white.opacity(Designs.Opacity.semiOpaque))
                        )
                }
            }
        }
    }

    private var mainChart: some View {
        VStack(spacing: Designs.Spacing.md) {
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
                    .foregroundStyle(Designs.Colors.textTertiary.opacity(Designs.Opacity.semiOpaque))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
            }
            .chartYScale(domain: 0...100)
            .frame(height: Designs.Sizes.displayHeightChart)

            // Stats row (matching Apple Fitness design)
            HStack(spacing: Designs.Spacing.xl) {
                statItem(label: "Highest", value: Int(highestScore))
                statItem(label: "Lowest", value: Int(lowestScore))
                statItem(label: "Average", value: Int(averageScore))
            }
            .padding(.top, Designs.Spacing.sm)
        }
        .padding(Designs.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Designs.Radius.lg)
                .fill(Color.white.opacity(Designs.Opacity.semiTransparent))
        )
    }

    private func statItem(label: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(AppFont.pageTitle)
                .foregroundColor(Designs.Colors.textPrimary)

            Text(label)
                    .font(AppFont.footnote)
                .foregroundColor(Designs.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyTimeRangeView: some View {
        VStack(spacing: Designs.Spacing.md) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(AppFont.custom(size: 40, weight: .light))
                .foregroundColor(Designs.Colors.textTertiary)

            Text("No scans in this time range")
                .font(AppFont.headlineSecondary)
                .foregroundColor(Designs.Colors.textPrimary)

            Text("Try selecting a different time range or complete a new scan.")
                .font(AppFont.caption)
                .foregroundColor(Designs.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Designs.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: Designs.Radius.lg)
                .fill(Color.white.opacity(Designs.Opacity.semiTransparent))
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
        VStack(alignment: .leading, spacing: Designs.Spacing.lg) {
            Text("Metrics Breakdown")
                .font(AppFont.headlinePrimary)
                .foregroundColor(Designs.Colors.textPrimary)

            // Try to use full Face3DMetrics first (contains ALL calculated metrics)
            if let metrics = session.face3DMetrics {
                // SKIN ANALYSIS METRICS (included in Overall Score - 5 metrics only)
                Text("Skin Analysis Metrics (In Overall Score)")
                    .font(AppFont.subheadingPrimary)
                    .foregroundColor(Designs.Colors.textPrimary)
                    .padding(.top, Designs.Spacing.xSmall)

                Text("These 5 high-confidence metrics (70%+ confidence) are included in your Overall Score.")
                    .font(AppFont.footnote)
                    .foregroundColor(Designs.Colors.textSecondary)
                    .padding(.bottom, 4)

                // 1. Smoothness (22.4%)
                MetricBar(
                    label: "Smoothness (22.4%)",
                    score: Double(metrics.globalRoughnessScore),
                    color: Designs.Colors.metricOverallColors[0]
                )

                // 2. Pigmentation (22.4%)
                MetricBar(
                    label: "Pigmentation (22.4%)",
                    score: Double(metrics.globalPigmentationScore),
                    color: Designs.Colors.metricOverallColors[1]
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
                        color: Designs.Colors.accent
                    )
                }

                // ADDITIONAL INDICATORS (Not in Overall Score)
                Divider()
                    .padding(.vertical, 8)

                Text("Additional Indicators (Not in Overall Score)")
                    .font(AppFont.subheadingPrimary)
                    .foregroundColor(Designs.Colors.textSecondary)

                Text("These metrics provide supplementary insights but aren't included in the Overall Score due to measurement limitations.")
                    .font(AppFont.footnote)
                    .foregroundColor(Designs.Colors.textSecondary)
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
                    color: Designs.Colors.metricHydrationColors[0]
                )

                // Redness (measurement limitations)
                if let redness = metrics.rednessAnalysis {
                    MetricBar(
                        label: "Redness (measurement limitations)",
                        score: Double(redness.overallScore),
                        color: Color(red: 255/255, green: 140/255, blue: 157/255)
                    )
                }

                // Oil Control
                if let specularScore = metrics.globalSpecularScore {
                    MetricBar(
                        label: "Oil Control",
                        score: Double(specularScore),
                        color: Color(red: 255/255, green: 215/255, blue: 0/255)
                    )
                }

                // AGING INDICATORS (separate from Skin Analysis Score)
                Divider()
                    .padding(.vertical, 8)

                Text("Aging Indicators")
                    .font(AppFont.subheadingPrimary)
                    .foregroundColor(Designs.Colors.textSecondary)

                if let wrinkles = metrics.wrinkleAnalysis {
                    MetricBar(
                        label: "Wrinkles",
                        score: Double(wrinkles.overallScore),
                        color: Designs.Colors.metricWrinklesColors[0]
                    )
                }

                if let volume = metrics.volumeAnalysis {
                    MetricBar(
                        label: "Volume",
                        score: Double(volume.overallScore),
                        color: Designs.Colors.metricVolumeColors[0]
                    )
                }

                // OTHER INDICATORS
                Divider()
                    .padding(.vertical, 8)

                Text("Other Indicators")
                    .font(AppFont.subheadingPrimary)
                    .foregroundColor(Designs.Colors.textSecondary)

                MetricBar(
                    label: "Skin Analysis (Composite)",
                    score: Double(metrics.glowAnalysis?.skinHealthScore ?? 0),
                    color: Designs.Colors.secondary
                )

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
                MetricBar(label: "Evenness", score: session.pigmentationAvg, color: Designs.Colors.secondary)
                MetricBar(label: "Sharpness", score: session.blurQuality, color: Color(red: 149/255, green: 165/255, blue: 166/255))
                MetricBar(label: "Discoloration", score: 100 - session.discolorationIndex, color: Designs.Colors.accent)
            }
        }
        .padding(.vertical, Designs.Spacing.lg)
    }

    private var singleMetricBreakdownView: some View {
        VStack(spacing: Designs.Spacing.lg) {
            Text("Score Ranges")
                .font(AppFont.headlinePrimary)
                .foregroundColor(Designs.Colors.textPrimary)

            ScoreRangeLegend()
        }
        .padding(Designs.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Designs.Radius.lg)
                .fill(Color.white.opacity(Designs.Opacity.semiTransparent))
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
        VStack(alignment: .leading, spacing: Designs.Spacing.md) {
            Text("Scan History")
                .font(AppFont.headlinePrimary)
                .foregroundColor(Designs.Colors.textPrimary)

            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                historyRow(session: session, index: index)
            }
        }
        .padding(.vertical, Designs.Spacing.lg)
    }

    private func historyRow(session: SessionResult, index: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate(session.date))
                    .font(AppFont.subheadingPrimary)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text(relativeDate(session.date))
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
            }

            Spacer()

            Text("\(Int(getScore(for: session)))%")
                .font(AppFont.headlinePrimary)
                .foregroundColor(scoreColor(getScore(for: session)))

            if index < sessions.count - 1 {
                let previousScore = getScore(for: sessions[index + 1])
                let currentScore = getScore(for: session)
                let trend = currentScore - previousScore

                if abs(trend) > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(AppFont.captionSmall)
                        Text("\(trend > 0 ? "+" : "")\(Int(trend))")
                            .font(AppFont.label)
                    }
                    .foregroundColor(trend > 0 ? .green : .red)
                }
            }
        }
        .padding(Designs.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Designs.Radius.md)
                .fill(Color.white.opacity(Designs.Opacity.semiTransparent))
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
        case .wrinkles:
            // Get wrinkle score from Face3DMetrics if available
            if let metrics = session.face3DMetrics, let wrinkles = metrics.wrinkleAnalysis {
                return Double(wrinkles.overallScore)
            }
            return 0
        case .elasticity:
            // Get elasticity score from Face3DMetrics if available
            if let metrics = session.face3DMetrics, let elasticity = metrics.elasticityAnalysis {
                return Double(elasticity.overallScore)
            }
            return 0
        case .volume:
            // Get volume score from Face3DMetrics if available
            if let metrics = session.face3DMetrics, let volume = metrics.volumeAnalysis {
                return Double(volume.overallScore)
            }
            return 0
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
        // - Below 30: Red (poor)
        // - 30-70: Yellow (fair)
        // - 70-89: Green (good)
        // - 90-100: Bright green (excellent)
        switch score {
        case 90...100: return Designs.ScoreColors.excellent  // Bright green
        case 70..<90: return Designs.ScoreColors.good        // Green
        case 30..<70: return Designs.ScoreColors.warning     // Yellow
        default: return Designs.ScoreColors.poor             // Red
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

private struct MetricBar: View {
    let label: String
    let score: Double
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(AppFont.bodySecondary)
                .foregroundColor(Designs.Colors.textPrimary)
                .frame(width: Designs.Sizes.frameWidthMedium, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(Designs.Opacity.light))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(score / 100))
                }
            }
            .frame(height: Designs.Sizes.progressIndicator)

            Text("\(Int(score))%")
                .font(AppFont.caption)
                .foregroundColor(Designs.Colors.textPrimary)
                .frame(width: Designs.Sizes.frameWidthSmall, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }
}

struct ScoreRangeLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.md) {
            legendRow(color: Designs.ScoreColors.excellent, label: "Excellent", range: "85 - 100%")
            legendRow(color: Designs.ScoreColors.good, label: "Good", range: "70 - 84%")
            legendRow(color: Designs.ScoreColors.fair, label: "Fair", range: "50 - 69%")
            legendRow(color: Designs.ScoreColors.warning, label: "Needs Improvement", range: "0 - 49%")
        }
    }

    private func legendRow(color: Color, label: String, range: String) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: Designs.Sizes.indicatorXSmall, height: Designs.Sizes.indicatorXSmall)

            Text(label)
                .font(AppFont.bodySecondary)
                .foregroundColor(Designs.Colors.textPrimary)

            Spacer()

            Text(range)
                .font(AppFont.caption)
                .foregroundColor(Designs.Colors.textSecondary)
        }
    }
}

// MARK: - Metric Info Sheet

struct MetricInfoSheet: View {
    let metricType: UserMetricType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Designs.Spacing.lg) {
                    // What is this metric?
                    sectionHeader("What is \(metricType.rawValue)?")
                    Text(metricDescription)
                        .font(AppFont.bodyPrimary)
                        .foregroundColor(Designs.Colors.textSecondary)

                    // What affects this?
                    sectionHeader("What Affects This Metric?")
                    VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                        ForEach(affectingFactors, id: \.self) { factor in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text(factor)
                            }
                            .font(AppFont.bodyPrimary)
                            .foregroundColor(Designs.Colors.textSecondary)
                        }
                    }

                    // Normal Range
                    sectionHeader("Normal Range")
                    Text(metricType.normalRange)
                        .font(AppFont.subheadingPrimary)
                        .foregroundColor(Designs.Colors.textPrimary)
                }
                .padding(Designs.Spacing.lg)
            }
            .background(Designs.Colors.background)
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
            .font(AppFont.headlineSecondary)
            .foregroundColor(Designs.Colors.textPrimary)
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
