//
//  InsightsTabView.swift
//  Tavi
//
//  Insights tab with dynamic insights, recommendations, and progress trends
//  All data is real from Core Data - no placeholders
//  Created on 2025-01-10.
//

import SwiftUI
import Charts

public struct InsightsTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)],
        animation: .default
    )
    private var sessions: FetchedResults<SessionResult>

    @State private var selectedTimeRange: TimeRange = .oneMonth

    public init() {}

    public var body: some View {
        ZStack {
            // Scenic background
            scenicBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: HeadspaceDesign.Spacing.xl) {
                    // Title
                    titleSection

                    // Content based on scan count
                    if sessions.isEmpty {
                        emptyStateContent
                    } else if sessions.count == 1 {
                        baselineStateContent
                    } else {
                        insightsContent
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, HeadspaceDesign.Spacing.lg)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Scenic Background

    private var scenicBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 245/255, green: 250/255, blue: 255/255),
                Color(red: 255/255, green: 248/255, blue: 240/255),
                Color(red: 250/255, green: 245/255, blue: 255/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Title

    private var titleSection: some View {
        HStack {
            Text("Insights")
                .font(.gilroy(size: 34, weight: .bold))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            Spacer()
        }
        .padding(.top, HeadspaceDesign.Spacing.md)
    }

    // MARK: - Empty State (0 scans)

    private var emptyStateContent: some View {
        VStack(spacing: HeadspaceDesign.Spacing.xl) {
            // Main empty state card
            VStack(spacing: HeadspaceDesign.Spacing.lg) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 56, weight: .light))
                    .foregroundColor(HeadspaceDesign.Colors.primary)

                Text("Start Your Skin Journey")
                    .font(.gilroy(size: 24, weight: .bold))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text("Complete your first scan to get personalized insights and recommendations tailored to your skin health.")
                    .font(.gilroy(size: 16, weight: .regular))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(HeadspaceDesign.Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                    .fill(HeadspaceDesign.Colors.elevatedCard)
                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
            )

            // Feature preview cards
            VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
                Text("What You'll Get")
                    .font(.gilroy(size: 20, weight: .bold))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                featurePreviewCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Progress Tracking",
                    description: "Monitor your skin health over time"
                )

                featurePreviewCard(
                    icon: "lightbulb.fill",
                    title: "Personalized Recommendations",
                    description: "Get tips based on your unique data"
                )

                featurePreviewCard(
                    icon: "target",
                    title: "Areas to Improve",
                    description: "Focus on what matters most"
                )
            }
        }
    }

    private func featurePreviewCard(icon: String, title: String, description: String) -> some View {
        HStack(spacing: HeadspaceDesign.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(HeadspaceDesign.Colors.primary)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.gilroy(size: 16, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text(description)
                    .font(.gilroy(size: 14, weight: .regular))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md)
                .fill(HeadspaceDesign.Colors.elevatedCard)
        )
    }

    // MARK: - Baseline State (1 scan)

    private var baselineStateContent: some View {
        VStack(spacing: HeadspaceDesign.Spacing.xl) {
            // Header
            forYouHeader(text: "Based on your first scan...")

            // Baseline established card
            baselineEstablishedCard

            // Current status - all 8 metrics
            currentStatusCard

            Spacer()
        }
    }

    private func forYouHeader(text: String) -> some View {
        HStack(spacing: HeadspaceDesign.Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(HeadspaceDesign.Colors.primary)

            Text("For You")
                .font(.gilroy(size: 16, weight: .bold))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            Spacer()
        }
        .padding(.vertical, HeadspaceDesign.Spacing.sm)
        .padding(.horizontal, HeadspaceDesign.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.sm)
                .fill(HeadspaceDesign.Colors.primary.opacity(0.1))
        )
    }

    private var baselineEstablishedCard: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.lg) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.green)

                Text("Baseline Established")
                    .font(.gilroy(size: 20, weight: .bold))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Spacer()
            }

            if let session = sessions.first {
                Text("Your first scan is complete! We've established your baseline metrics:")
                    .font(.gilroy(size: 15, weight: .regular))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    baselineMetricRow(label: "Overall Score", value: session.overallScore)
                    if let glowAnalysis = session.skinMetrics?.glowAnalysis {
                        baselineMetricRow(label: "Glow", value: Double(glowAnalysis.glowScore))
                    }
                    // Calculate hydration from ROI moisture proxies
                    if let metrics = session.skinMetrics {
                        let moistureValues = metrics.roiMetrics.values.map { $0.moistureProxy.moistureIndex * 100 }
                        let avgMoisture = moistureValues.reduce(0, +) / Double(moistureValues.count)
                        baselineMetricRow(label: "Hydration", value: avgMoisture)
                    }
                }
                .padding(.vertical, HeadspaceDesign.Spacing.sm)

                Text("Complete another scan to see progress.")
                    .font(.gilroy(size: 14, weight: .medium))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                .fill(HeadspaceDesign.Colors.elevatedCard)
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        )
    }

    private func baselineMetricRow(label: String, value: Double) -> some View {
        HStack {
            Circle()
                .fill(HeadspaceDesign.Colors.primary)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.gilroy(size: 15, weight: .medium))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            Spacer()

            Text("\(Int(value))%")
                .font(.gilroy(size: 15, weight: .semibold))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)
        }
    }

    private var currentStatusCard: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                Text("Your Metrics")
                    .font(.gilroy(size: 18, weight: .bold))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)
            }

            if let session = sessions.first, let metrics = session.skinMetrics {
                VStack(spacing: 16) {
                    // Skin Health Metrics (Included in Overall Score - 5 metrics)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Skin Health (In Overall Score)")
                            .font(.gilroy(size: 14, weight: .semibold))
                            .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                        VStack(spacing: 12) {
                            // 1. Smoothness (22.4%)
                            metricProgressBar(label: "Smoothness", score: Double(metrics.globalRoughnessScore), color: .green)

                            // 2. Pigmentation (22.4%)
                            metricProgressBar(label: "Pigmentation", score: Double(metrics.globalPigmentationScore), color: .purple)

                            // 3. Pores (14.9%)
                            if let pores = metrics.poreAnalysis {
                                metricProgressBar(label: "Pores", score: Double(pores.visibilityScore), color: .gray)
                            }

                            // 4. Discoloration (14.9%)
                            metricProgressBar(label: "Discoloration", score: Double(metrics.globalDiscolorationScore), color: .orange)

                            // 5. Acne (14.9%)
                            if let acne = metrics.acneAnalysis {
                                metricProgressBar(label: "Acne", score: Double(acne.overallScore), color: .red)
                            }
                        }
                    }

                    Divider()

                    // Additional Indicators (Not in Overall Score - 4 metrics)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Indicators")
                            .font(.gilroy(size: 14, weight: .semibold))
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                        VStack(spacing: 12) {
                            // Elasticity (requires 2+ scans)
                            if let elasticity = metrics.elasticityAnalysis {
                                metricProgressBar(label: "Elasticity", score: Double(elasticity.overallScore), color: .blue)
                            }

                            // Hydration (proxy method, 65% confidence)
                            let moistureValues = metrics.roiMetrics.values.map { $0.moistureProxy.moistureIndex * 100 }
                            let avgMoisture = moistureValues.reduce(0, +) / Double(moistureValues.count)
                            metricProgressBar(label: "Hydration", score: avgMoisture, color: .cyan)

                            // Redness (measurement limitations)
                            if let redness = metrics.rednessAnalysis {
                                metricProgressBar(label: "Redness", score: Double(redness.overallScore), color: .pink)
                            }

                            // Oil Control (disabled) - only show if available
                            if let specularScore = metrics.globalSpecularScore {
                                metricProgressBar(label: "Oil Control", score: Double(specularScore), color: .yellow)
                            }
                        }
                    }

                    Divider()

                    // Aging Indicators
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aging Indicators")
                            .font(.gilroy(size: 14, weight: .semibold))
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                        VStack(spacing: 12) {
                            if let wrinkles = metrics.wrinkleAnalysis {
                                metricProgressBar(label: "Wrinkles", score: Double(wrinkles.overallScore), color: .purple)
                            }

                            if let volume = metrics.volumeAnalysis {
                                metricProgressBar(label: "Volume", score: Double(volume.overallScore), color: .indigo)
                            }
                        }
                    }

                    Divider()

                    // Other Indicators
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Other Indicators")
                            .font(.gilroy(size: 14, weight: .semibold))
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                        VStack(spacing: 12) {
                            metricProgressBar(label: "Glow", score: Double(metrics.glowAnalysis?.glowScore ?? 0), color: .yellow)

                            if let sunDamage = metrics.sunDamageAnalysis {
                                metricProgressBar(label: "Sun Protection", score: Double(sunDamage.protectionScore), color: .orange)
                            }
                        }
                    }
                }
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                .fill(HeadspaceDesign.Colors.elevatedCard)
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        )
    }

    private func metricProgressBar(label: String, score: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.gilroy(size: 14, weight: .medium))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                .frame(width: 100, alignment: .leading)

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
                .font(.gilroy(size: 14, weight: .semibold))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                .frame(width: 45, alignment: .trailing)
        }
    }

    // MARK: - Insights Content (2+ scans)

    private var insightsContent: some View {
        VStack(spacing: HeadspaceDesign.Spacing.xl) {
            // Header
            forYouHeader(text: "Based on your \(sessions.count) scans...")

            // 1. BASELINE: Progress trends chart + Top performing metrics
            progressTrendsSection

            // Top performing metrics (if 3+ scans)
            if sessions.count >= 3 {
                topMetricsSection
            }

            // 2. EDUCATIONAL CONTENT: (Moved from bottom)
            educationalContentSection

            // 3. RECOMMENDATIONS: Dynamic insight cards + Product recommendations
            insightCardsSection
        }
    }

    private var insightCardsSection: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.lg) {
            // Premium section header
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(HeadspaceDesign.Colors.primary)

                Text("Recommendations")
                    .font(.gilroy(size: 22, weight: .bold))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Spacer()

                Image(systemName: "crown.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.secondary)
            }
            .padding(.horizontal, HeadspaceDesign.Spacing.sm)

            VStack(spacing: HeadspaceDesign.Spacing.md) {
                // Calculate improvements and declines
                let improvements = calculateImprovements()
                let declines = calculateDeclines()
                let strongMetrics = getTopMetrics()

                // Improvement card
                if !improvements.isEmpty {
                    improvementCard(improvements: improvements)

                    // Add premium recommendations section right after improvement card
                    whatYouShouldBeDoingSection
                }

                // Recommendation card
                if let metric = strongMetrics.first, metric.1 >= 85 {
                    recommendationCard(metric: metric)
                }

                // Area to watch card
                if !declines.isEmpty {
                    areaToWatchCard(declines: declines)
                }

                // If no insights, show steady progress
                if improvements.isEmpty && declines.isEmpty {
                    steadyProgressCard()
                }
            }
        }
    }

    private func improvementCard(improvements: [(String, Double)]) -> some View {
        InsightCard(
            icon: "arrow.up.right",
            iconColor: .green,
            title: generateImprovementTitle(improvements),
            content: generateImprovementText(improvements),
            actionText: "View Details"
        ) {
            AppLogger.ui.info("View Details tapped for improvements: \(improvements.map { $0.0 }.joined(separator: ", "))")
        }
    }

    private func recommendationCard(metric: (String, Double, String)) -> some View {
        let recommendation = generateRecommendation(metric: metric.0, score: metric.1)

        return InsightCard(
            icon: "star.fill",
            iconColor: HeadspaceDesign.Colors.primary,
            title: "Recommendation",
            content: recommendation.message,
            actionText: "Learn More"
        ) {
            AppLogger.ui.info("Learn More tapped for metric: \(metric.0)")
        }
    }

    private func areaToWatchCard(declines: [(String, Double)]) -> some View {
        let areaInfo = generateAreaToWatchText(decline: declines[0])

        return InsightCard(
            icon: "exclamationmark.triangle",
            iconColor: .orange,
            title: "Area to Watch",
            content: areaInfo.message,
            tips: areaInfo.tips,
            actionText: "View Tips"
        ) {
            AppLogger.ui.info("View Tips tapped for declines: \(declines.map { $0.0 }.joined(separator: ", "))")
        }
    }

    private func steadyProgressCard() -> some View {
        InsightCard(
            icon: "chart.line.flattrend.xyaxis",
            iconColor: HeadspaceDesign.Colors.textSecondary,
            title: "Steady Progress",
            content: "Your skin metrics are stable. Keep up your current routine to maintain these results.",
            actionText: nil
        ) {}
    }

    private var progressTrendsSection: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            Text("Progress Trends")
                .font(.gilroy(size: 20, weight: .bold))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            if filteredSessions.count >= 2 {
                progressChart
            } else {
                Text("Not enough data in selected time range")
                    .font(.gilroy(size: 15, weight: .regular))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    .padding(HeadspaceDesign.Spacing.lg)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                            .fill(HeadspaceDesign.Colors.elevatedCard)
                    )
            }
        }
    }

    private var progressChart: some View {
        VStack(spacing: HeadspaceDesign.Spacing.md) {
            // Time range filters
            timeRangeFilters

            // Chart - sort sessions by date to prevent zig-zagging
            Chart {
                ForEach(sortedFilteredSessions) { session in
                    // Overall score line
                    LineMark(
                        x: .value("Date", session.date),
                        y: .value("Score", session.overallScore)
                    )
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)

                    // Glow score line (only if available)
                    if let clinicalData = session.clinicalMetricsData {
                        let result = VersionedMetricsLoader.loadFace3DMetrics(from: clinicalData)
                        if let metrics = result.metrics, let glowAnalysis = metrics.glowAnalysis {
                            LineMark(
                                x: .value("Date", session.date),
                                y: .value("Score", Double(glowAnalysis.glowScore))
                            )
                            .foregroundStyle(Color.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .frame(height: 200)

            // Legend
            HStack(spacing: HeadspaceDesign.Spacing.md) {
                legendItem(color: .green, label: "Overall")
                legendItem(color: .orange, label: "Glow")
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                .fill(HeadspaceDesign.Colors.elevatedCard)
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        )
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
                        .font(.system(size: 13, weight: selectedTimeRange == range ? .semibold : .medium, design: .rounded))
                        .foregroundColor(selectedTimeRange == range ? .white : HeadspaceDesign.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedTimeRange == range ? HeadspaceDesign.Colors.primary : HeadspaceDesign.Colors.elevatedCard)
                        )
                }
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 16, height: 3)

            Text(label)
                .font(.gilroy(size: 12, weight: .medium))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
        }
    }

    private var filteredSessions: [SessionResult] {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        return sessions.filter { $0.date >= cutoffDate }
    }
    
    // Sorted sessions for chart (by date ascending to prevent zig-zagging)
    private var sortedFilteredSessions: [SessionResult] {
        filteredSessions.sorted { $0.date < $1.date }
    }

    private var topMetricsSection: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            HStack {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.secondary)

                Text("Top 3 Metrics")
                    .font(.gilroy(size: 18, weight: .bold))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)
            }

            let topMetrics = getTopMetrics().prefix(3)

            ForEach(Array(topMetrics.enumerated()), id: \.element.0) { index, metric in
                HStack {
                    Text("\(index + 1).")
                        .font(.gilroy(size: 16, weight: .bold))
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                        .frame(width: 30, alignment: .leading)

                    Text(metric.0)
                        .font(.gilroy(size: 16, weight: .medium))
                        .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                    Spacer()

                    Text("\(Int(metric.1))%")
                        .font(.gilroy(size: 16, weight: .bold))
                        .foregroundColor(scoreColor(metric.1))

                    Text("[\(metric.2)]")
                        .font(.gilroy(size: 14, weight: .regular))
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                }
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                .fill(HeadspaceDesign.Colors.elevatedCard)
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        )
    }

    // MARK: - Educational Content

    private var educationalContentSection: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            Text("Educational Content")
                .font(.gilroy(size: 20, weight: .bold))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            educationalArticleRow(icon: "book.fill", title: "Understanding Your Baseline")
            educationalArticleRow(icon: "sparkles", title: "What Affects Glow?")
            educationalArticleRow(icon: "drop.fill", title: "Hydration and Your Skin")
            educationalArticleRow(icon: "sun.max.fill", title: "Protecting Against Sun Damage")
        }
    }

    private func educationalArticleRow(icon: String, title: String) -> some View {
        Button {
            AppLogger.ui.info("Educational article tapped: \(title)")
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(HeadspaceDesign.Colors.primary)
                    .frame(width: 32)

                Text(title)
                    .font(.gilroy(size: 16, weight: .medium))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.textTertiary)
            }
            .padding(HeadspaceDesign.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md)
                    .fill(HeadspaceDesign.Colors.elevatedCard)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helper Functions

    private func calculateImprovements() -> [(String, Double)] {
        guard sessions.count >= 2 else { return [] }

        let latest = sessions[0]
        let previous = sessions[1]
        var improvements: [(String, Double)] = []

        // Check glow
        if let latestGlow = latest.skinMetrics?.glowAnalysis?.glowScore,
           let prevGlow = previous.skinMetrics?.glowAnalysis?.glowScore {
            let change = Double(latestGlow - prevGlow)
            if change > 2 { improvements.append(("Glow", change)) }
        }

        // Check hydration (calculated from moisture proxies)
        if let latestMetrics = latest.skinMetrics,
           let prevMetrics = previous.skinMetrics {
            let latestMoisture = latestMetrics.roiMetrics.values.map { $0.moistureProxy.moistureIndex * 100 }
            let prevMoisture = prevMetrics.roiMetrics.values.map { $0.moistureProxy.moistureIndex * 100 }
            let latestAvg = latestMoisture.reduce(0, +) / Double(latestMoisture.count)
            let prevAvg = prevMoisture.reduce(0, +) / Double(prevMoisture.count)
            let change = latestAvg - prevAvg
            if change > 2 { improvements.append(("Hydration", change)) }
        }

        // Check smoothness (global roughness score)
        if let latestMetrics = latest.skinMetrics,
           let prevMetrics = previous.skinMetrics {
            let change = Double(latestMetrics.globalRoughnessScore - prevMetrics.globalRoughnessScore)
            if change > 2 { improvements.append(("Smoothness", change)) }
        }

        // Sort by largest improvement
        return improvements.sorted { $0.1 > $1.1 }
    }

    private func calculateDeclines() -> [(String, Double)] {
        guard sessions.count >= 2 else { return [] }

        let latest = sessions[0]
        let previous = sessions[1]
        var declines: [(String, Double)] = []

        // Check roughness (global roughness score - lower is worse)
        if let latestMetrics = latest.skinMetrics,
           let prevMetrics = previous.skinMetrics {
            let change = Double(latestMetrics.globalRoughnessScore - prevMetrics.globalRoughnessScore)
            if change < -3 { declines.append(("Roughness", abs(change))) }
        }

        // Check sun damage
        if let latestDamage = latest.skinMetrics?.sunDamageAnalysis?.protectionScore,
           let prevDamage = previous.skinMetrics?.sunDamageAnalysis?.protectionScore {
            let change = Double(latestDamage - prevDamage)
            if change < -3 { declines.append(("Sun Damage", abs(change))) }
        }

        // Check redness
        if let latestRedness = latest.skinMetrics?.rednessAnalysis?.overallScore,
           let prevRedness = previous.skinMetrics?.rednessAnalysis?.overallScore {
            let change = Double(latestRedness - prevRedness)
            if change < -3 { declines.append(("Redness", abs(change))) }
        }

        // Sort by largest decline
        return declines.sorted { $0.1 > $1.1 }
    }

    private func getTopMetrics() -> [(String, Double, String)] {
        guard let latest = sessions.first, let metrics = latest.skinMetrics else {
            return []
        }

        // Calculate hydration from ROI moisture proxies
        let moistureValues = metrics.roiMetrics.values.map { $0.moistureProxy.moistureIndex * 100 }
        let avgMoisture = moistureValues.reduce(0, +) / Double(moistureValues.count)

        let allMetrics: [(String, Double, String)] = [
            ("Overall", latest.overallScore, qualityLabel(latest.overallScore)),
            ("Acne", Double(metrics.acneAnalysis?.overallScore ?? 0), qualityLabel(Double(metrics.acneAnalysis?.overallScore ?? 0))),
            ("Smoothness", Double(metrics.globalRoughnessScore), qualityLabel(Double(metrics.globalRoughnessScore))),
            ("Hydration", avgMoisture, qualityLabel(avgMoisture)),
            ("Glow", Double(metrics.glowAnalysis?.glowScore ?? 0), qualityLabel(Double(metrics.glowAnalysis?.glowScore ?? 0))),
            ("Pigmentation", Double(metrics.globalPigmentationScore), qualityLabel(Double(metrics.globalPigmentationScore))),
            ("Sun Damage", Double(metrics.sunDamageAnalysis?.protectionScore ?? 0), qualityLabel(Double(metrics.sunDamageAnalysis?.protectionScore ?? 0))),
            ("Redness", Double(metrics.rednessAnalysis?.overallScore ?? 0), qualityLabel(Double(metrics.rednessAnalysis?.overallScore ?? 0))),
            ("Roughness", Double(metrics.globalRoughnessScore), qualityLabel(Double(metrics.globalRoughnessScore)))
        ]

        return allMetrics.sorted { $0.1 > $1.1 }
    }

    private func qualityLabel(_ score: Double) -> String {
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

    private func generateImprovementTitle(_ improvements: [(String, Double)]) -> String {
        let totalChange = improvements.reduce(0) { $0 + $1.1 }
        if totalChange > 15 {
            return "Great Improvement Detected"
        } else if totalChange > 8 {
            return "Good Progress"
        } else {
            return "Improvement Detected"
        }
    }

    private func generateImprovementText(_ improvements: [(String, Double)]) -> String {
        let metricTexts = improvements.map { "\($0.0.lowercased()) (+\(Int($0.1))%)" }

        if improvements.count == 1 {
            return "Your skin shows improvement in \(metricTexts[0])!"
        } else if improvements.count == 2 {
            return "Your skin shows improvement in \(metricTexts[0]) and \(metricTexts[1])!"
        } else if let last = metricTexts.last {
            let first = metricTexts.dropLast().joined(separator: ", ")
            return "Your skin shows improvement in \(first), and \(last)!"
        } else {
            return "Your skin shows improvement!"
        }
    }

    private func generateRecommendation(metric: String, score: Double) -> (title: String, message: String) {
        switch metric {
        case "Hydration" where score >= 85:
            return (
                "Your hydration levels are excellent!",
                "Continue using moisturizer twice daily to maintain these results. Also consider sun protection."
            )
        case "Acne" where score >= 85:
            return (
                "Your acne control is excellent!",
                "Maintain your current routine. Continue gentle cleansing and avoid touching your face."
            )
        case "Glow" where score >= 85:
            return (
                "Your skin glow is outstanding!",
                "Keep up your vitamin C routine and stay hydrated. Consider adding antioxidants."
            )
        default:
            return (
                "Keep up the good work!",
                "Your skincare routine is showing positive results. Stay consistent."
            )
        }
    }

    private func generateAreaToWatchText(decline: (String, Double)) -> (message: String, tips: [String]) {
        let metricName = decline.0
        let changeAmount = Int(decline.1)

        switch metricName {
        case "Sun Damage":
            return (
                "Sun damage score decreased by \(changeAmount)% over the past month.",
                [
                    "Apply SPF 30+ daily",
                    "Reapply every 2 hours",
                    "Use vitamin C serum",
                    "Wear protective clothing"
                ]
            )
        case "Roughness":
            return (
                "Roughness increased by \(changeAmount)%. Consider adding exfoliation.",
                [
                    "Gentle exfoliation 2-3 times per week",
                    "Use a chemical exfoliant (AHA/BHA)",
                    "Moisturize immediately after",
                    "Avoid over-exfoliating"
                ]
            )
        default:
            return (
                "\(metricName) decreased by \(changeAmount)%.",
                ["Monitor this metric", "Consider adjusting your routine"]
            )
        }
    }
    
    // MARK: - What You Should Be Doing Section
    
    private var whatYouShouldBeDoingSection: some View {
        VStack(spacing: HeadspaceDesign.Spacing.md) {
            // Pull recommendations from stored scan results (previous scan)
            let recommendations = getStoredRecommendations()
            let products = getStoredProductRecommendations()
            
            // Actionable recommendations card
            if !recommendations.isEmpty {
                recommendationsCard(recommendations: recommendations)
            }
            
            // Product recommendations card
            if !products.isEmpty {
                productsCard(products: products)
            }
        }
    }
    
    private func recommendationsCard(recommendations: [String]) -> some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.primary)
                
                Text("Your Personalized Action Plan")
                    .font(.gilroy(size: 18, weight: .bold))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                
                Spacer()
            }
            
            Text("Based on your latest scan, here's what will help you achieve your best skin:")
                .font(.gilroy(size: 14, weight: .regular))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(recommendations.enumerated()), id: \.offset) { index, rec in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(HeadspaceDesign.Colors.primary)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        
                        Text(rec)
                            .font(.gilroy(size: 15, weight: .regular))
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                .fill(HeadspaceDesign.Colors.elevatedCard)
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        )
    }
    
    private func productsCard(products: [(name: String, category: String)]) -> some View {
        VStack(spacing: 0) {
            // Premium gradient header
            ZStack {
                LinearGradient(
                    colors: [
                        HeadspaceDesign.Colors.primary,
                        HeadspaceDesign.Colors.primary.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 100)

                HStack(spacing: HeadspaceDesign.Spacing.sm) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Premium Recommendations")
                            .font(.gilroy(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text("Curated for your skin")
                            .font(.gilroy(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(HeadspaceDesign.Spacing.lg)
            }

            // Products list on white background
            VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
                Text("These products are specifically chosen to address your skin's unique needs:")
                    .font(.gilroy(size: 14, weight: .regular))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(products.enumerated()), id: \.offset) { index, product in
                        HStack(alignment: .center, spacing: 14) {
                            // Premium number badge
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                HeadspaceDesign.Colors.primary,
                                                HeadspaceDesign.Colors.secondary
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)

                                Text("\(index + 1)")
                                    .font(.gilroy(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(product.name)
                                    .font(.gilroy(size: 16, weight: .bold))
                                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                                Text(product.category.uppercased())
                                    .font(.gilroy(size: 11, weight: .semibold))
                                    .foregroundColor(HeadspaceDesign.Colors.primary)
                                    .tracking(0.5)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(HeadspaceDesign.Colors.textTertiary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md)
                                .fill(HeadspaceDesign.Colors.primary.opacity(0.05))
                        )
                    }
                }
            }
            .padding(HeadspaceDesign.Spacing.lg)
            .background(HeadspaceDesign.Colors.elevatedCard)
        }
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Colors.primary.opacity(0.2),
            radius: 15,
            x: 0,
            y: 8
        )
    }
    
    // MARK: - Recommendation Generation (Pulled from Stored Scan Results)
    
    /// Pull recommendations from the previous scan's stored results
    /// Only falls back to generation if no stored data is available
    private func getStoredRecommendations() -> [String] {
        // Always try to pull from stored results first
        guard sessions.count >= 2 else {
            // No previous scan available - use latest scan as fallback
            AppLogger.ui.debug("⚠️ No previous scan found, using generated recommendations")
            return generateActionableRecommendations()
        }
        
        // Get the previous scan (second most recent) - this is where recommendations were stored
        let previousSession = sessions[1]
        var recommendations: [String] = []
        
        // Priority 1: Get nextSteps from EmotionalMetrics (stored in emotionalMetricsData)
        if let emotionalData = previousSession.emotionalMetricsData, !emotionalData.isEmpty {
            let result = VersionedMetricsLoader.loadEmotionalMetrics(from: emotionalData)
            
            switch result {
            case .success(let metrics, _), .migrated(let metrics, _, _):
                if !metrics.nextSteps.isEmpty {
                    AppLogger.ui.info("✅ Loaded \(metrics.nextSteps.count) recommendations from previous scan's EmotionalMetrics")
                    // Convert ActionableStep to recommendation strings
                    for step in metrics.nextSteps.prefix(4) {
                        let rec = "\(step.action) - \(step.frequency) (\(step.timing))"
                        recommendations.append(rec)
                    }
                } else {
                    AppLogger.ui.debug("⚠️ Previous scan has EmotionalMetrics but no nextSteps")
                }
            case .incompatible(let version, let reason):
                AppLogger.ui.warning("⚠️ Cannot load EmotionalMetrics from previous scan: incompatible version \(version.versionString) - \(reason)")
            case .corrupted(let error):
                AppLogger.ui.warning("⚠️ Cannot load EmotionalMetrics from previous scan: corrupted data - \(error.localizedDescription)")
            case .notFound:
                AppLogger.ui.debug("⚠️ EmotionalMetrics not found in previous scan")
            }
        } else {
            AppLogger.ui.debug("⚠️ Previous scan has no emotionalMetricsData")
        }
        
        // Priority 2: Also check scanQuality recommendations from Face3DMetrics
        if recommendations.count < 4, let clinicalData = previousSession.clinicalMetricsData, !clinicalData.isEmpty {
            let result = VersionedMetricsLoader.loadFace3DMetrics(from: clinicalData)
            
            switch result {
            case .success(let metrics, _), .migrated(let metrics, _, _):
                if let scanQuality = metrics.scanQuality, !scanQuality.recommendations.isEmpty {
                    AppLogger.ui.info("✅ Loaded \(scanQuality.recommendations.count) recommendations from previous scan's scanQuality")
                    for rec in scanQuality.recommendations.prefix(4 - recommendations.count) {
                        recommendations.append(rec)
                    }
                }
            case .incompatible(let version, let reason):
                AppLogger.ui.warning("⚠️ Cannot load Face3DMetrics from previous scan: incompatible version \(version.versionString) - \(reason)")
            case .corrupted(let error):
                AppLogger.ui.warning("⚠️ Cannot load Face3DMetrics from previous scan: corrupted data - \(error.localizedDescription)")
            case .notFound:
                AppLogger.ui.debug("⚠️ Face3DMetrics not found in previous scan")
            }
        }
        
        // Only fallback to generation if we truly have no stored recommendations
        if recommendations.isEmpty {
            AppLogger.ui.info("⚠️ No stored recommendations found, generating from latest scan metrics")
            return generateActionableRecommendations()
        }
        
        AppLogger.ui.info("✅ Using \(recommendations.count) stored recommendations from previous scan")
        return recommendations
    }
    
    /// Fallback: Generate recommendations based on latest scan metrics
    private func generateActionableRecommendations() -> [String] {
        guard let latest = sessions.first, let metrics = latest.skinMetrics else {
            return []
        }
        
        var recommendations: [String] = []
        
        // Check smoothness (roughness score - lower is worse)
        if metrics.globalRoughnessScore < 70 {
            recommendations.append("Add gentle exfoliation 2-3 times per week to improve skin texture")
        }
        
        // Check hydration
        let moistureValues = metrics.roiMetrics.values.map { $0.moistureProxy.moistureIndex * 100 }
        let avgMoisture = moistureValues.reduce(0, +) / Double(moistureValues.count)
        if avgMoisture < 65 {
            recommendations.append("Increase hydration with a daily moisturizer containing hyaluronic acid")
        }
        
        // Check pigmentation
        if metrics.globalPigmentationScore < 70 {
            recommendations.append("Use vitamin C serum in the morning to even out skin tone")
        }
        
        // Check sun damage
        if let sunDamage = metrics.sunDamageAnalysis, sunDamage.protectionScore < 75 {
            recommendations.append("Apply SPF 30+ daily and reapply every 2 hours when outdoors")
        }
        
        // Check pores
        if let pores = metrics.poreAnalysis, pores.visibilityScore < 70 {
            recommendations.append("Use a BHA (salicylic acid) product 2-3 times weekly to minimize pore appearance")
        }
        
        // Check acne
        if let acne = metrics.acneAnalysis, acne.overallScore < 70 {
            recommendations.append("Maintain a consistent cleansing routine with a gentle, non-comedogenic cleanser")
        }
        
        // Check wrinkles
        if let wrinkles = metrics.wrinkleAnalysis, wrinkles.overallScore < 75 {
            recommendations.append("Start using retinol 2-3 times weekly at night to reduce fine lines")
        }
        
        // If no specific issues, provide general maintenance
        if recommendations.isEmpty {
            recommendations.append("Continue your current skincare routine to maintain your skin health")
            recommendations.append("Apply SPF daily to protect against future damage")
        }
        
        return recommendations.prefix(4).map { $0 } // Limit to 4 recommendations
    }
    
    private func getPointersFromPreviousResults() -> [String] {
        guard sessions.count >= 2 else {
            return []
        }
        
        let latest = sessions[0]
        let previous = sessions[1]
        var pointers: [String] = []
        
        // Compare overall score
        let overallChange = latest.overallScore - previous.overallScore
        if overallChange > 5 {
            pointers.append("Your overall skin health improved by \(Int(overallChange)) points since your last scan")
        } else if overallChange < -5 {
            pointers.append("Your overall score decreased by \(Int(abs(overallChange))) points - focus on consistency")
        }
        
        // Compare glow
        if let latestGlow = latest.skinMetrics?.glowAnalysis?.glowScore,
           let prevGlow = previous.skinMetrics?.glowAnalysis?.glowScore {
            let glowChange = latestGlow - prevGlow
            if glowChange > 3 {
                pointers.append("Your skin glow increased significantly - your routine is working!")
            } else if glowChange < -3 {
                pointers.append("Your glow decreased - consider adding antioxidants to your routine")
            }
        }
        
        // Compare smoothness
        if let latestMetrics = latest.skinMetrics,
           let prevMetrics = previous.skinMetrics {
            let smoothnessChange = latestMetrics.globalRoughnessScore - prevMetrics.globalRoughnessScore
            if smoothnessChange > 3 {
                pointers.append("Your skin texture improved - exfoliation is showing results")
            } else if smoothnessChange < -3 {
                pointers.append("Your skin texture needs attention - consider adjusting your exfoliation routine")
            }
        }
        
        return pointers.prefix(3).map { $0 } // Limit to 3 pointers
    }
    
    /// Pull product recommendations from stored scan results
    /// Only falls back to generation if no stored data is available
    private func getStoredProductRecommendations() -> [(name: String, category: String)] {
        // Always try to pull from stored results first
        guard sessions.count >= 2 else {
            // No previous scan available - use latest scan as fallback
            AppLogger.ui.debug("⚠️ No previous scan found, using generated product recommendations")
            return generateProductRecommendations()
        }
        
        // Get the previous scan (second most recent) - this is where recommendations were stored
        let previousSession = sessions[1]
        var products: [(name: String, category: String)] = []
        
        // Extract product info from EmotionalMetrics nextSteps (stored data)
        if let emotionalData = previousSession.emotionalMetricsData, !emotionalData.isEmpty {
            let result = VersionedMetricsLoader.loadEmotionalMetrics(from: emotionalData)
            
            switch result {
            case .success(let metrics, _), .migrated(let metrics, _, _):
                if !metrics.nextSteps.isEmpty {
                    AppLogger.ui.info("✅ Extracting products from \(metrics.nextSteps.count) nextSteps in previous scan")
                    // Extract product-like recommendations from nextSteps
                    for step in metrics.nextSteps.prefix(4) {
                        // Parse action to extract product name and category
                        let action = step.action.lowercased()
                        if action.contains("spf") || action.contains("sunscreen") {
                            products.append(("Broad Spectrum SPF 50", "Sun Protection"))
                        } else if action.contains("moisturizer") || action.contains("moisturizing") {
                            products.append(("Daily Moisturizer", "Hydration"))
                        } else if action.contains("retinol") {
                            products.append(("Retinol Night Cream", "Anti-Aging"))
                        } else if action.contains("vitamin c") {
                            products.append(("Vitamin C Brightening Serum", "Brightening"))
                        } else if action.contains("exfoliat") {
                            products.append(("Gentle Exfoliating Serum", "Exfoliant"))
                        } else if action.contains("cleanser") {
                            products.append(("Gentle Cleanser", "Basic Care"))
                        }
                    }
                }
            case .incompatible(let version, let reason):
                AppLogger.ui.warning("⚠️ Cannot load EmotionalMetrics for products: incompatible version \(version.versionString) - \(reason)")
            case .corrupted(let error):
                AppLogger.ui.warning("⚠️ Cannot load EmotionalMetrics for products: corrupted data - \(error.localizedDescription)")
            case .notFound:
                AppLogger.ui.debug("⚠️ EmotionalMetrics not found for products in previous scan")
            }
        }
        
        // Only fallback to generation if we truly have no stored products
        if products.isEmpty {
            AppLogger.ui.info("⚠️ No stored products found, generating from latest scan metrics")
            return generateProductRecommendations()
        }
        
        AppLogger.ui.info("✅ Using \(products.count) stored product recommendations from previous scan")
        return Array(products.prefix(4)) // Limit to 4 products
    }
    
    /// Fallback: Generate product recommendations based on latest scan metrics
    private func generateProductRecommendations() -> [(name: String, category: String)] {
        guard let latest = sessions.first, let metrics = latest.skinMetrics else {
            return []
        }
        
        var products: [(name: String, category: String)] = []
        
        // Recommend products based on needs
        if metrics.globalRoughnessScore < 70 {
            products.append(("Gentle Exfoliating Serum", "Exfoliant"))
            products.append(("Retinol Night Cream", "Anti-Aging"))
        }
        
        let moistureValues = metrics.roiMetrics.values.map { $0.moistureProxy.moistureIndex * 100 }
        let avgMoisture = moistureValues.reduce(0, +) / Double(moistureValues.count)
        if avgMoisture < 65 {
            products.append(("Hyaluronic Acid Moisturizer", "Hydration"))
            products.append(("Hydrating Face Mask", "Treatment"))
        }
        
        if metrics.globalPigmentationScore < 70 {
            products.append(("Vitamin C Brightening Serum", "Brightening"))
        }
        
        if let sunDamage = metrics.sunDamageAnalysis, sunDamage.protectionScore < 75 {
            products.append(("Broad Spectrum SPF 50", "Sun Protection"))
        }
        
        if let pores = metrics.poreAnalysis, pores.visibilityScore < 70 {
            products.append(("Pore Minimizing Toner", "Pore Care"))
        }
        
        if let acne = metrics.acneAnalysis, acne.overallScore < 70 {
            products.append(("Salicylic Acid Cleanser", "Acne Treatment"))
        }
        
        // If no specific needs, provide general recommendations
        if products.isEmpty {
            products.append(("Daily Moisturizer", "Basic Care"))
            products.append(("SPF 30 Sunscreen", "Sun Protection"))
        }
        
        return Array(products.prefix(4)) // Limit to 4 products
    }
}

// MARK: - Insight Card Component

struct InsightCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let content: String
    var tips: [String]? = nil
    let actionText: String?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.gilroy(size: 18, weight: .bold))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.textTertiary)
            }

            Text(content)
                .font(.gilroy(size: 15, weight: .regular))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let tips = tips {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(iconColor)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)

                            Text(tip)
                                .font(.gilroy(size: 14, weight: .medium))
                                .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, HeadspaceDesign.Spacing.sm)
            }

            if let actionText = actionText {
                Button(action: action) {
                    Text(actionText)
                        .font(.gilroy(size: 15, weight: .semibold))
                        .foregroundColor(HeadspaceDesign.Colors.primary)
                }
                .padding(.top, HeadspaceDesign.Spacing.sm)
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                .fill(HeadspaceDesign.Colors.elevatedCard)
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InsightsTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
