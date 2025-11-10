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

struct InsightsTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)],
        animation: .default
    )
    private var sessions: FetchedResults<SessionResult>

    @State private var selectedTimeRange: TimeRange = .oneMonth

    var body: some View {
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

                    // Educational content (always visible)
                    educationalContentSection

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
                .font(.system(size: 34, weight: .bold, design: .rounded))
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
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text("Complete your first scan to get personalized insights and recommendations tailored to your skin health.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(HeadspaceDesign.Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                    .fill(Color.white.opacity(0.7))
                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
            )

            // Feature preview cards
            VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
                Text("What You'll Get")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
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
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text(description)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md)
                .fill(Color.white.opacity(0.7))
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
                .font(.system(size: 16, weight: .bold, design: .rounded))
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
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Spacer()
            }

            if let session = sessions.first {
                Text("Your first scan is complete! We've established your baseline metrics:")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
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
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                .fill(Color.white.opacity(0.7))
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        )
    }

    private func baselineMetricRow(label: String, value: Double) -> some View {
        HStack {
            Circle()
                .fill(HeadspaceDesign.Colors.primary)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            Spacer()

            Text("\(Int(value))%")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)
            }

            if let session = sessions.first, let metrics = session.skinMetrics {
                VStack(spacing: 12) {
                    metricProgressBar(label: "Smoothness", score: Double(metrics.globalRoughnessScore), color: .green)

                    // Calculate hydration from ROI moisture proxies
                    let moistureValues = metrics.roiMetrics.values.map { $0.moistureProxy.moistureIndex * 100 }
                    let avgMoisture = moistureValues.reduce(0, +) / Double(moistureValues.count)
                    metricProgressBar(label: "Hydration", score: avgMoisture, color: .blue)

                    metricProgressBar(label: "Glow", score: Double(metrics.glowAnalysis?.glowScore ?? 0), color: .orange)
                    metricProgressBar(label: "Pigmentation", score: Double(metrics.globalPigmentationScore), color: .purple)
                    metricProgressBar(label: "Acne", score: Double(metrics.acneAnalysis?.overallScore ?? 0), color: .red)
                    metricProgressBar(label: "Sun Damage", score: Double(metrics.sunDamageAnalysis?.protectionScore ?? 0), color: .yellow)
                    metricProgressBar(label: "Redness", score: Double(metrics.rednessAnalysis?.overallScore ?? 0), color: .pink)
                    metricProgressBar(label: "Roughness", score: Double(metrics.globalRoughnessScore), color: .brown)
                }
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                .fill(Color.white.opacity(0.7))
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        )
    }

    private func metricProgressBar(label: String, score: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
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
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                .frame(width: 45, alignment: .trailing)
        }
    }

    // MARK: - Insights Content (2+ scans)

    private var insightsContent: some View {
        VStack(spacing: HeadspaceDesign.Spacing.xl) {
            // Header
            forYouHeader(text: "Based on your \(sessions.count) scans...")

            // Dynamic insight cards
            insightCardsSection

            // Progress trends chart
            progressTrendsSection

            // Top performing metrics (if 3+ scans)
            if sessions.count >= 3 {
                topMetricsSection
            }
        }
    }

    private var insightCardsSection: some View {
        VStack(spacing: HeadspaceDesign.Spacing.md) {
            // Calculate improvements and declines
            let improvements = calculateImprovements()
            let declines = calculateDeclines()
            let strongMetrics = getTopMetrics()

            // Improvement card
            if !improvements.isEmpty {
                improvementCard(improvements: improvements)
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
            iconColor: Color(red: 95/255, green: 111/255, blue: 230/255),
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
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            if filteredSessions.count >= 2 {
                progressChart
            } else {
                Text("Not enough data in selected time range")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    .padding(HeadspaceDesign.Spacing.lg)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                            .fill(Color.white.opacity(0.7))
                    )
            }
        }
    }

    private var progressChart: some View {
        VStack(spacing: HeadspaceDesign.Spacing.md) {
            // Time range filters
            timeRangeFilters

            // Chart
            Chart {
                ForEach(filteredSessions) { session in
                    // Overall score line
                    LineMark(
                        x: .value("Date", session.date),
                        y: .value("Score", session.overallScore)
                    )
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    // Glow score line
                    if let glow = session.skinMetrics?.glowScore {
                        LineMark(
                            x: .value("Date", session.date),
                            y: .value("Score", glow)
                        )
                        .foregroundStyle(Color.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }

                    // Hydration score line
                    if let hydration = session.skinMetrics?.hydrationScore {
                        LineMark(
                            x: .value("Date", session.date),
                            y: .value("Score", hydration)
                        )
                        .foregroundStyle(Color.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .frame(height: 200)

            // Legend
            HStack(spacing: HeadspaceDesign.Spacing.md) {
                legendItem(color: .green, label: "Overall")
                legendItem(color: .orange, label: "Glow")
                legendItem(color: .blue, label: "Hydration")
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                .fill(Color.white.opacity(0.7))
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
                                .fill(selectedTimeRange == range ? HeadspaceDesign.Colors.primary : Color.white.opacity(0.5))
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
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
        }
    }

    private var filteredSessions: [SessionResult] {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        return sessions.filter { $0.date >= cutoffDate }
    }

    private var topMetricsSection: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            HStack {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 252/255, green: 188/255, blue: 78/255))

                Text("Top 3 Metrics")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)
            }

            let topMetrics = getTopMetrics().prefix(3)

            ForEach(Array(topMetrics.enumerated()), id: \.element.0) { index, metric in
                HStack {
                    Text("\(index + 1).")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                        .frame(width: 30, alignment: .leading)

                    Text(metric.0)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                    Spacer()

                    Text("\(Int(metric.1))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor(metric.1))

                    Text("[\(metric.2)]")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                }
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                .fill(Color.white.opacity(0.7))
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        )
    }

    // MARK: - Educational Content

    private var educationalContentSection: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            Text("Educational Content")
                .font(.system(size: 20, weight: .bold, design: .rounded))
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
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.textTertiary)
            }
            .padding(HeadspaceDesign.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md)
                    .fill(Color.white.opacity(0.7))
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

        var allMetrics: [(String, Double, String)] = [
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
        } else {
            let first = metricTexts.dropLast().joined(separator: ", ")
            let last = metricTexts.last!
            return "Your skin shows improvement in \(first), and \(last)!"
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
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.textTertiary)
            }

            Text(content)
                .font(.system(size: 15, weight: .regular, design: .rounded))
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
                                .font(.system(size: 14, weight: .medium, design: .rounded))
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
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.primary)
                }
                .padding(.top, HeadspaceDesign.Spacing.sm)
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                .fill(Color.white.opacity(0.7))
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
