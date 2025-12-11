//
//  InsightsTabView.swift
//  Tavi
//
//  Insights tab with dynamic insights, recommendations, and progress trends
//  All data is real from Core Data - no placeholders
//  Gentler Streak themed
//  Created on 2025-01-10.
//

import SwiftUI
import Charts

public struct InsightsTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // Gentler Streak colors (centralized)
    private let gsBackground = Designs.GentlerStreak.background
    private let gsTextPrimary = Designs.GentlerStreak.textPrimary
    private let gsTextSecondary = Designs.GentlerStreak.textSecondary
    private let gsAccentCoral = Designs.GentlerStreak.accentCoral
    private let gsAccentTeal = Designs.GentlerStreak.accentTeal
    private let gsCardBackground = Designs.GentlerStreak.cardBackground
    private let gsSoftGreen = Designs.GentlerStreak.softGreen
    private let gsSoftYellow = Designs.GentlerStreak.softYellow
    private let gsSoftRed = Designs.GentlerStreak.softRed
    private let gsProgressTrack = Designs.GentlerStreak.progressTrack

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)],
        animation: .default
    )
    private var sessions: FetchedResults<SessionResult>

    @State private var selectedTimeRange: TimeRange = .oneMonth

    public init() {}

    public var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    titleSection

                    if sessions.isEmpty {
                        emptyStateContent
                    } else if sessions.count == 1 {
                        baselineStateContent
                    } else {
                        insightsContent
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Title

    private var titleSection: some View {
        HStack {
            Text("Insights")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(gsTextPrimary)
            Spacer()
        }
        .padding(.top, 16)
    }

    // MARK: - Empty State (0 scans)

    private var emptyStateContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 20) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(gsAccentCoral)

                Text("Start Your Skin Journey")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(gsTextPrimary)

                Text("Complete your first scan to get personalized insights and recommendations tailored to your skin health.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(gsTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(gsCardBackground)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            )

            VStack(alignment: .leading, spacing: 16) {
                Text("What You'll Get")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(gsTextPrimary)

                featurePreviewCard(icon: "chart.line.uptrend.xyaxis", title: "Progress Tracking", description: "Monitor your skin health over time")
                featurePreviewCard(icon: "lightbulb.fill", title: "Personalized Recommendations", description: "Get tips based on your unique data")
                featurePreviewCard(icon: "target", title: "Areas to Improve", description: "Focus on what matters most")
            }
        }
    }

    private func featurePreviewCard(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(gsAccentCoral)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(gsTextPrimary)

                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(gsTextSecondary)
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(gsCardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Baseline State (1 scan)

    private var baselineStateContent: some View {
        VStack(spacing: 24) {
            forYouHeader(text: "Based on your first scan...")
            baselineEstablishedCard
            currentStatusCard
            Spacer()
        }
    }

    private func forYouHeader(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(gsAccentCoral)

            Text("For You")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(gsTextPrimary)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(gsAccentCoral.opacity(0.1))
        )
    }

    private var baselineEstablishedCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(gsSoftGreen)

                Text("Baseline Established")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(gsTextPrimary)

                Spacer()
            }

            if let session = sessions.first {
                Text("Your first scan is complete! We've established your baseline metrics:")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(gsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    baselineMetricRow(label: "Overall Score", value: session.overallScore)
                    if let glowAnalysis = session.skinMetrics?.glowAnalysis {
                        baselineMetricRow(label: "Skin Health", value: Double(glowAnalysis.skinHealthScore))
                    }
                    if let metrics = session.skinMetrics {
                        let moistureValues = metrics.roiMetrics.values.map { $0.moistureProxy.moistureIndex * 100 }
                        let avgMoisture = moistureValues.reduce(0, +) / Double(moistureValues.count)
                        baselineMetricRow(label: "Hydration", value: avgMoisture)
                    }
                }
                .padding(.vertical, 8)

                Text("Complete another scan to see progress.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(gsTextSecondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(gsCardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }

    private func baselineMetricRow(label: String, value: Double) -> some View {
        HStack {
            Circle()
                .fill(gsAccentCoral)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(gsTextPrimary)

            Spacer()

            Text("\(Int(value))%")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(gsTextPrimary)
        }
    }

    private var currentStatusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(gsTextSecondary)

                Text("Your Metrics")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(gsTextPrimary)
            }

            if let session = sessions.first, let metrics = session.skinMetrics {
                VStack(spacing: 16) {
                    // Skin Health Metrics
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Skin Health (In Overall Score)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(gsTextPrimary)

                        VStack(spacing: 12) {
                            metricProgressBar(label: "Smoothness", score: Double(metrics.globalRoughnessScore), color: gsSoftGreen)
                            metricProgressBar(label: "Pigmentation", score: Double(metrics.globalPigmentationScore), color: gsAccentTeal)

                            if let pores = metrics.poreAnalysis {
                                metricProgressBar(label: "Pores", score: Double(pores.visibilityScore), color: gsTextSecondary)
                            }

                            metricProgressBar(label: "Discoloration", score: Double(metrics.globalDiscolorationScore), color: gsSoftYellow)

                            if let acne = metrics.acneAnalysis {
                                metricProgressBar(label: "Acne", score: Double(acne.overallScore), color: gsSoftRed)
                            }
                        }
                    }

                    Divider()

                    // Additional Indicators
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Indicators")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(gsTextSecondary)

                        VStack(spacing: 12) {
                            if let elasticity = metrics.elasticityAnalysis {
                                metricProgressBar(label: "Elasticity", score: Double(elasticity.overallScore), color: gsAccentTeal)
                            }

                            let moistureValues = metrics.roiMetrics.values.map { $0.moistureProxy.moistureIndex * 100 }
                            let avgMoisture = moistureValues.reduce(0, +) / Double(moistureValues.count)
                            metricProgressBar(label: "Hydration", score: avgMoisture, color: gsAccentTeal)

                            if let redness = metrics.rednessAnalysis {
                                metricProgressBar(label: "Redness", score: Double(redness.overallScore), color: gsAccentCoral)
                            }

                            if let specularScore = metrics.globalSpecularScore {
                                metricProgressBar(label: "Oil Control", score: Double(specularScore), color: gsSoftYellow)
                            }
                        }
                    }

                    Divider()

                    // Aging Indicators
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aging Indicators")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(gsTextSecondary)

                        VStack(spacing: 12) {
                            if let wrinkles = metrics.wrinkleAnalysis {
                                metricProgressBar(label: "Wrinkles", score: Double(wrinkles.overallScore), color: gsAccentTeal)
                            }

                            if let volume = metrics.volumeAnalysis {
                                metricProgressBar(label: "Volume", score: Double(volume.overallScore), color: gsAccentTeal)
                            }
                        }
                    }

                    Divider()

                    // Other Indicators
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Other Indicators")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(gsTextSecondary)

                        VStack(spacing: 12) {
                            metricProgressBar(label: "Skin Health", score: Double(metrics.glowAnalysis?.skinHealthScore ?? 0), color: gsSoftYellow)

                            if let sunDamage = metrics.sunDamageAnalysis {
                                metricProgressBar(label: "Sun Protection", score: Double(sunDamage.protectionScore), color: gsSoftYellow)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(gsCardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }

    private func metricProgressBar(label: String, score: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(gsTextPrimary)
                .frame(width: 100, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(gsProgressTrack)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(score / 100))
                }
            }
            .frame(height: 8)

            Text("\(Int(score))%")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(gsTextPrimary)
                .frame(width: 45, alignment: .trailing)
        }
    }

    // MARK: - Insights Content (2+ scans)

    private var insightsContent: some View {
        VStack(spacing: 24) {
            forYouHeader(text: "Based on your \(sessions.count) scans...")
            progressTrendsSection

            if sessions.count >= 3 {
                topMetricsSection
            }

            educationalContentSection
            insightCardsSection
        }
    }

    private var insightCardsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(gsAccentCoral)

                Text("Recommendations")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(gsTextPrimary)

                Spacer()

                Image(systemName: "crown.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(gsSoftYellow)
            }
            .padding(.horizontal, 8)

            VStack(spacing: 16) {
                let improvements = calculateImprovements()
                let declines = calculateDeclines()
                let strongMetrics = getTopMetrics()

                if !improvements.isEmpty {
                    improvementCard(improvements: improvements)
                    whatYouShouldBeDoingSection
                }

                if let metric = strongMetrics.first, metric.1 >= 85 {
                    recommendationCard(metric: metric)
                }

                if !declines.isEmpty {
                    areaToWatchCard(declines: declines)
                }

                if improvements.isEmpty && declines.isEmpty {
                    steadyProgressCard()
                }
            }
        }
    }

    private func improvementCard(improvements: [(String, Double)]) -> some View {
        InsightCardGentler(
            icon: "arrow.up.right",
            iconColor: gsSoftGreen,
            title: generateImprovementTitle(improvements),
            content: generateImprovementText(improvements),
            actionText: "View Details",
            accentColor: gsAccentCoral,
            cardBackground: gsCardBackground,
            textPrimary: gsTextPrimary,
            textSecondary: gsTextSecondary
        ) {
            AppLogger.ui.info("View Details tapped")
        }
    }

    private func recommendationCard(metric: (String, Double, String)) -> some View {
        let recommendation = generateRecommendation(metric: metric.0, score: metric.1)

        return InsightCardGentler(
            icon: "star.fill",
            iconColor: gsAccentCoral,
            title: "Recommendation",
            content: recommendation.message,
            actionText: "Learn More",
            accentColor: gsAccentCoral,
            cardBackground: gsCardBackground,
            textPrimary: gsTextPrimary,
            textSecondary: gsTextSecondary
        ) {
            AppLogger.ui.info("Learn More tapped")
        }
    }

    private func areaToWatchCard(declines: [(String, Double)]) -> some View {
        let areaInfo = generateAreaToWatchText(decline: declines[0])

        return InsightCardGentler(
            icon: "exclamationmark.triangle",
            iconColor: gsSoftYellow,
            title: "Area to Watch",
            content: areaInfo.message,
            tips: areaInfo.tips,
            actionText: "View Tips",
            accentColor: gsAccentCoral,
            cardBackground: gsCardBackground,
            textPrimary: gsTextPrimary,
            textSecondary: gsTextSecondary
        ) {
            AppLogger.ui.info("View Tips tapped")
        }
    }

    private func steadyProgressCard() -> some View {
        InsightCardGentler(
            icon: "chart.line.flattrend.xyaxis",
            iconColor: gsTextSecondary,
            title: "Steady Progress",
            content: "Your skin metrics are stable. Keep up your current routine to maintain these results.",
            actionText: nil,
            accentColor: gsAccentCoral,
            cardBackground: gsCardBackground,
            textPrimary: gsTextPrimary,
            textSecondary: gsTextSecondary
        ) {}
    }

    private var progressTrendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress Trends")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(gsTextPrimary)

            if filteredSessions.count >= 2 {
                progressChart
            } else {
                Text("Not enough data in selected time range")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(gsTextSecondary)
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(gsCardBackground)
                    )
            }
        }
    }

    private var progressChart: some View {
        VStack(spacing: 16) {
            timeRangeFilters

            Chart {
                ForEach(sortedFilteredSessions) { session in
                    LineMark(
                        x: .value("Date", session.date),
                        y: .value("Score", session.overallScore)
                    )
                    .foregroundStyle(gsSoftGreen)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)

                    if let clinicalData = session.clinicalMetricsData {
                        let result = VersionedMetricsLoader.loadFace3DMetrics(from: clinicalData)
                        if let metrics = result.metrics, let glowAnalysis = metrics.glowAnalysis {
                            LineMark(
                                x: .value("Date", session.date),
                                y: .value("Score", Double(glowAnalysis.skinHealthScore))
                            )
                            .foregroundStyle(gsAccentCoral)
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

            HStack(spacing: 16) {
                legendItem(color: gsSoftGreen, label: "Overall")
                legendItem(color: gsAccentCoral, label: "Glow")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(gsCardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }

    private var timeRangeFilters: some View {
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTimeRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 13, weight: selectedTimeRange == range ? .semibold : .medium, design: .rounded))
                        .foregroundColor(selectedTimeRange == range ? .white : gsTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedTimeRange == range ? gsAccentCoral : gsProgressTrack)
                        )
                }
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 16, height: 4)

            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(gsTextSecondary)
        }
    }

    private var filteredSessions: [SessionResult] {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        return sessions.filter { $0.date >= cutoffDate }
    }

    private var sortedFilteredSessions: [SessionResult] {
        filteredSessions.sorted { $0.date < $1.date }
    }

    private var topMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(gsSoftYellow)

                Text("Top 3 Metrics")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(gsTextPrimary)
            }

            let topMetrics = getTopMetrics().prefix(3)

            ForEach(Array(topMetrics.enumerated()), id: \.element.0) { index, metric in
                HStack {
                    Text("\(index + 1).")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(gsTextSecondary)
                        .frame(width: 30, alignment: .leading)

                    Text(metric.0)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(gsTextPrimary)

                    Spacer()

                    Text("\(Int(metric.1))%")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(gentlerScoreColor(metric.1))

                    Text("[\(metric.2)]")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(gsTextSecondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(gsCardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }

    // MARK: - Educational Content

    private var educationalContentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Educational Content")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(gsTextPrimary)

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
                    .foregroundColor(gsAccentCoral)
                    .frame(width: 32)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(gsTextPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(gsTextSecondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(gsCardBackground)
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helper Functions

    private func gentlerScoreColor(_ score: Double) -> Color {
        switch score {
        case 85...100: return gsSoftGreen
        case 70..<85: return gsAccentTeal
        case 50..<70: return gsSoftYellow
        case 30..<50: return gsAccentCoral
        default: return gsSoftRed
        }
    }

    private func calculateImprovements() -> [(String, Double)] {
        guard sessions.count >= 2 else { return [] }

        let latest = sessions[0]
        let previous = sessions[1]
        var improvements: [(String, Double)] = []

        if let latestGlow = latest.skinMetrics?.glowAnalysis?.skinHealthScore,
           let prevGlow = previous.skinMetrics?.glowAnalysis?.skinHealthScore {
            let change = Double(latestGlow - prevGlow)
            if change > 2 { improvements.append(("Skin Health", change)) }
        }

        if let latestMetrics = latest.skinMetrics,
           let prevMetrics = previous.skinMetrics {
            let latestMoisture = latestMetrics.roiMetrics.values.map { $0.moistureProxy.moistureIndex * 100 }
            let prevMoisture = prevMetrics.roiMetrics.values.map { $0.moistureProxy.moistureIndex * 100 }
            let latestAvg = latestMoisture.reduce(0, +) / Double(latestMoisture.count)
            let prevAvg = prevMoisture.reduce(0, +) / Double(prevMoisture.count)
            let change = latestAvg - prevAvg
            if change > 2 { improvements.append(("Hydration", change)) }
        }

        if let latestMetrics = latest.skinMetrics,
           let prevMetrics = previous.skinMetrics {
            let change = Double(latestMetrics.globalRoughnessScore - prevMetrics.globalRoughnessScore)
            if change > 2 { improvements.append(("Smoothness", change)) }
        }

        return improvements.sorted { $0.1 > $1.1 }
    }

    private func calculateDeclines() -> [(String, Double)] {
        guard sessions.count >= 2 else { return [] }

        let latest = sessions[0]
        let previous = sessions[1]
        var declines: [(String, Double)] = []

        if let latestMetrics = latest.skinMetrics,
           let prevMetrics = previous.skinMetrics {
            let change = Double(latestMetrics.globalRoughnessScore - prevMetrics.globalRoughnessScore)
            if change < -3 { declines.append(("Roughness", abs(change))) }
        }

        if let latestDamage = latest.skinMetrics?.sunDamageAnalysis?.protectionScore,
           let prevDamage = previous.skinMetrics?.sunDamageAnalysis?.protectionScore {
            let change = Double(latestDamage - prevDamage)
            if change < -3 { declines.append(("Sun Damage", abs(change))) }
        }

        if let latestRedness = latest.skinMetrics?.rednessAnalysis?.overallScore,
           let prevRedness = previous.skinMetrics?.rednessAnalysis?.overallScore {
            let change = Double(latestRedness - prevRedness)
            if change < -3 { declines.append(("Redness", abs(change))) }
        }

        return declines.sorted { $0.1 > $1.1 }
    }

    private func getTopMetrics() -> [(String, Double, String)] {
        guard let latest = sessions.first, let metrics = latest.skinMetrics else {
            return []
        }

        let moistureValues = metrics.roiMetrics.values.map { $0.moistureProxy.moistureIndex * 100 }
        let avgMoisture = moistureValues.reduce(0, +) / Double(moistureValues.count)

        let allMetrics: [(String, Double, String)] = [
            ("Overall", latest.overallScore, qualityLabel(latest.overallScore)),
            ("Acne", Double(metrics.acneAnalysis?.overallScore ?? 0), qualityLabel(Double(metrics.acneAnalysis?.overallScore ?? 0))),
            ("Smoothness", Double(metrics.globalRoughnessScore), qualityLabel(Double(metrics.globalRoughnessScore))),
            ("Hydration", avgMoisture, qualityLabel(avgMoisture)),
            ("Skin Health", Double(metrics.glowAnalysis?.skinHealthScore ?? 0), qualityLabel(Double(metrics.glowAnalysis?.skinHealthScore ?? 0))),
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
            return ("Your hydration levels are excellent!", "Continue using moisturizer twice daily to maintain these results. Also consider sun protection.")
        case "Acne" where score >= 85:
            return ("Your acne control is excellent!", "Maintain your current routine. Continue gentle cleansing and avoid touching your face.")
        case "Glow" where score >= 85:
            return ("Your skin glow is outstanding!", "Keep up your vitamin C routine and stay hydrated. Consider adding antioxidants.")
        default:
            return ("Keep up the good work!", "Your skincare routine is showing positive results. Stay consistent.")
        }
    }

    private func generateAreaToWatchText(decline: (String, Double)) -> (message: String, tips: [String]) {
        let metricName = decline.0
        let changeAmount = Int(decline.1)

        switch metricName {
        case "Sun Damage":
            return ("Sun damage score decreased by \(changeAmount)% over the past month.", ["Apply SPF 30+ daily", "Reapply every 2 hours", "Use vitamin C serum", "Wear protective clothing"])
        case "Roughness":
            return ("Roughness increased by \(changeAmount)%. Consider adding exfoliation.", ["Gentle exfoliation 2-3 times per week", "Use a chemical exfoliant (AHA/BHA)", "Moisturize immediately after", "Avoid over-exfoliating"])
        default:
            return ("\(metricName) decreased by \(changeAmount)%.", ["Monitor this metric", "Consider adjusting your routine"])
        }
    }

    // MARK: - What You Should Be Doing Section

    private var whatYouShouldBeDoingSection: some View {
        VStack(spacing: 16) {
            let recommendations = getStoredRecommendations()
            let products = getStoredProductRecommendations()

            if !recommendations.isEmpty {
                recommendationsCard(recommendations: recommendations)
            }

            if !products.isEmpty {
                productsCard(products: products)
            }
        }
    }

    private func recommendationsCard(recommendations: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(gsAccentCoral)

                Text("Your Personalized Action Plan")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(gsTextPrimary)

                Spacer()
            }

            Text("Based on your latest scan, here's what will help you achieve your best skin:")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(gsTextSecondary)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(recommendations.enumerated()), id: \.offset) { _, rec in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(gsAccentCoral)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        Text(rec)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(gsTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(gsCardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }

    private func productsCard(products: [(name: String, category: String)]) -> some View {
        VStack(spacing: 0) {
            // Coral gradient header
            ZStack {
                LinearGradient(
                    colors: [gsAccentCoral, gsAccentCoral.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 100)

                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Premium Recommendations")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Curated for your skin")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(20)
            }

            // Products list
            VStack(alignment: .leading, spacing: 16) {
                Text("These products are specifically chosen to address your skin's unique needs:")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(gsTextSecondary)
                    .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(products.enumerated()), id: \.offset) { index, product in
                        HStack(alignment: .center, spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(gsAccentCoral)
                                    .frame(width: 40, height: 40)

                                Text("\(index + 1)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(product.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(gsTextPrimary)

                                Text(product.category.uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(gsAccentCoral)
                                    .tracking(0.5)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(gsTextSecondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(gsAccentCoral.opacity(0.05))
                        )
                    }
                }
            }
            .padding(20)
            .background(gsCardBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: gsAccentCoral.opacity(0.2), radius: 15, x: 0, y: 8)
    }

    // MARK: - Recommendation Generation

    private func getStoredRecommendations() -> [String] {
        guard sessions.count >= 2 else {
            return generateActionableRecommendations()
        }

        let previousSession = sessions[1]
        var recommendations: [String] = []

        if let emotionalData = previousSession.emotionalMetricsData, !emotionalData.isEmpty {
            let result = VersionedMetricsLoader.loadEmotionalMetrics(from: emotionalData)

            switch result {
            case .success(let metrics, _), .migrated(let metrics, _, _):
                if !metrics.nextSteps.isEmpty {
                    for step in metrics.nextSteps.prefix(4) {
                        let rec = "\(step.action) - \(step.frequency) (\(step.timing))"
                        recommendations.append(rec)
                    }
                }
            case .incompatible, .corrupted, .notFound:
                break
            }
        }

        if recommendations.count < 4, let clinicalData = previousSession.clinicalMetricsData, !clinicalData.isEmpty {
            let result = VersionedMetricsLoader.loadFace3DMetrics(from: clinicalData)

            switch result {
            case .success(let metrics, _), .migrated(let metrics, _, _):
                if let scanQuality = metrics.scanQuality, !scanQuality.recommendations.isEmpty {
                    for rec in scanQuality.recommendations.prefix(4 - recommendations.count) {
                        recommendations.append(rec)
                    }
                }
            case .incompatible, .corrupted, .notFound:
                break
            }
        }

        if recommendations.isEmpty {
            return generateActionableRecommendations()
        }

        return recommendations
    }

    private func generateActionableRecommendations() -> [String] {
        guard let latest = sessions.first, let metrics = latest.skinMetrics else {
            return []
        }

        var recommendations: [String] = []

        if metrics.globalRoughnessScore < 70 {
            recommendations.append("Add gentle exfoliation 2-3 times per week to improve skin texture")
        }

        let moistureValues = metrics.roiMetrics.values.map { $0.moistureProxy.moistureIndex * 100 }
        let avgMoisture = moistureValues.reduce(0, +) / Double(moistureValues.count)
        if avgMoisture < 65 {
            recommendations.append("Increase hydration with a daily moisturizer containing hyaluronic acid")
        }

        if metrics.globalPigmentationScore < 70 {
            recommendations.append("Use vitamin C serum in the morning to even out skin tone")
        }

        if let sunDamage = metrics.sunDamageAnalysis, sunDamage.protectionScore < 75 {
            recommendations.append("Apply SPF 30+ daily and reapply every 2 hours when outdoors")
        }

        if let pores = metrics.poreAnalysis, pores.visibilityScore < 70 {
            recommendations.append("Use a BHA (salicylic acid) product 2-3 times weekly to minimize pore appearance")
        }

        if let acne = metrics.acneAnalysis, acne.overallScore < 70 {
            recommendations.append("Maintain a consistent cleansing routine with a gentle, non-comedogenic cleanser")
        }

        if let wrinkles = metrics.wrinkleAnalysis, wrinkles.overallScore < 75 {
            recommendations.append("Start using retinol 2-3 times weekly at night to reduce fine lines")
        }

        if recommendations.isEmpty {
            recommendations.append("Continue your current skincare routine to maintain your skin health")
            recommendations.append("Apply SPF daily to protect against future damage")
        }

        return recommendations.prefix(4).map { $0 }
    }

    private func getStoredProductRecommendations() -> [(name: String, category: String)] {
        guard sessions.count >= 2 else {
            return generateProductRecommendations()
        }

        let previousSession = sessions[1]
        var products: [(name: String, category: String)] = []

        if let emotionalData = previousSession.emotionalMetricsData, !emotionalData.isEmpty {
            let result = VersionedMetricsLoader.loadEmotionalMetrics(from: emotionalData)

            switch result {
            case .success(let metrics, _), .migrated(let metrics, _, _):
                if !metrics.nextSteps.isEmpty {
                    for step in metrics.nextSteps.prefix(4) {
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
            case .incompatible, .corrupted, .notFound:
                break
            }
        }

        if products.isEmpty {
            return generateProductRecommendations()
        }

        return Array(products.prefix(4))
    }

    private func generateProductRecommendations() -> [(name: String, category: String)] {
        guard let latest = sessions.first, let metrics = latest.skinMetrics else {
            return []
        }

        var products: [(name: String, category: String)] = []

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

        if products.isEmpty {
            products.append(("Daily Moisturizer", "Basic Care"))
            products.append(("SPF 30 Sunscreen", "Sun Protection"))
        }

        return Array(products.prefix(4))
    }
}

// MARK: - Insight Card Component (Gentler Streak Style)

struct InsightCardGentler: View {
    let icon: String
    let iconColor: Color
    let title: String
    let content: String
    var tips: [String]? = nil
    let actionText: String?
    let accentColor: Color
    let cardBackground: Color
    let textPrimary: Color
    let textSecondary: Color
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textPrimary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)
            }

            Text(content)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(textSecondary)
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
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 8)
            }

            if let actionText = actionText {
                Button(action: action) {
                    Text(actionText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
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
