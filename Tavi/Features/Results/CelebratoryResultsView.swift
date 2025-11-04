//
//  CelebratoryResultsView.swift
//  Tavi
//
//  Professional results screen matching Headspace quality
//  Created on 2025-01-03
//

import SwiftUI

/// Clean, professional results view - no emojis, Headspace-quality design
public struct CelebratoryResultsView: View {
    let emotionalMetrics: EmotionalMetrics
    let clinicalMetrics: Face3DMetrics?
    let onShareResults: () -> Void
    let onClose: () -> Void
    let saveStatus: SaveStatus?
    let comparisonWarning: String?

    @State private var showScore = false
    @State private var showMetrics = false
    @State private var showActions = false
    @State private var selectedMetricForHelp: MetricType? = nil
    @State private var showFirstTimeBanner = false
    @AppStorage("hasViewedMetricHelp") private var hasViewedMetricHelp = false

    public enum SaveStatus {
        case saving
        case saved
        case failed
        case queued
        case coreDataUnavailable  // Core Data not available, using fallback
    }

    public init(
        emotionalMetrics: EmotionalMetrics,
        clinicalMetrics: Face3DMetrics? = nil,
        saveStatus: SaveStatus? = nil,
        comparisonWarning: String? = nil,
        onShareResults: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {}
    ) {
        self.emotionalMetrics = emotionalMetrics
        self.clinicalMetrics = clinicalMetrics
        self.saveStatus = saveStatus
        self.comparisonWarning = comparisonWarning
        self.onShareResults = onShareResults
        self.onClose = onClose
    }

    public var body: some View {
        ZStack(alignment: .top) {
            // Main content
            ScrollView(showsIndicators: false) {
                VStack(spacing: HeadspaceDesign.Spacing.xxxl) {
                    // Hero section
                    heroSection
                        .opacity(showScore ? 1 : 0)
                        .offset(y: showScore ? 0 : -20)

                    // Save status banner (if applicable)
                    if let saveStatus = saveStatus, saveStatus != .saved {
                        saveStatusBanner(status: saveStatus)
                            .opacity(showScore ? 1 : 0)
                            .offset(y: showScore ? 0 : -10)
                    }

                    // Comparison warning banner (if version mismatch)
                    if let warning = comparisonWarning {
                        comparisonWarningBanner(warning: warning)
                            .opacity(showScore ? 1 : 0)
                            .offset(y: showScore ? 0 : -10)
                    }

                    // Main score card
                    mainScoreCard
                        .opacity(showScore ? 1 : 0)
                        .scaleEffect(showScore ? 1 : 0.95)

                    // Metrics breakdown
                    metricsSection
                        .opacity(showMetrics ? 1 : 0)
                        .offset(y: showMetrics ? 0 : 10)

                    // First-time user banner
                    if showFirstTimeBanner {
                        firstTimeBanner
                            .opacity(showFirstTimeBanner ? 1 : 0)
                            .offset(y: showFirstTimeBanner ? 0 : 10)
                    }

                    // Action plan
                    actionPlanSection
                        .opacity(showActions ? 1 : 0)
                        .offset(y: showActions ? 0 : 10)

                    // Share button
                    shareButton

                    Spacer().frame(height: HeadspaceDesign.Spacing.xxl)
                }
                .padding(.horizontal, HeadspaceDesign.Spacing.lg)
                .padding(.top, 80)
            }
            .background(HeadspaceDesign.Colors.background)

            // Floating close button
            HStack {
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(HeadspaceDesign.Colors.cardBackground)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, HeadspaceDesign.Spacing.lg)
            .padding(.top, HeadspaceDesign.Spacing.md)
        }
        .onAppear {
            animateEntrance()
        }
        .sheet(item: $selectedMetricForHelp) { metricType in
            MetricExplanationView(metric: metricType)
        }
    }

    // MARK: - Components

    private var heroSection: some View {
        VStack(spacing: HeadspaceDesign.Spacing.md) {
            Text(scoreInterpretationTitle)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                .multilineTextAlignment(.center)

            if !emotionalMetrics.personalizedMessage.isEmpty {
                Text(emotionalMetrics.personalizedMessage)
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var mainScoreCard: some View {
        VStack(spacing: 0) {
            // Gradient section with score
            ZStack {
                scoreGradient
                    .frame(height: 260)

                VStack(spacing: HeadspaceDesign.Spacing.xl) {
                    // Score circle
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 10)
                            .frame(width: 160, height: 160)

                        Circle()
                            .trim(from: 0, to: CGFloat(emotionalMetrics.glowScore) / 100)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 160, height: 160)
                            .rotationEffect(.degrees(-90))

                        Text("\(emotionalMetrics.glowScore)")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    Text("Your Skin Health Score")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                }
            }

            // White description section
            VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.sm) {
                Text(scoreInterpretation)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HeadspaceDesign.Spacing.xl)
            .background(HeadspaceDesign.Colors.elevatedCard)
        }
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.xl) {
            // Section header
            Text("Your skin metrics")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            // Metrics
            VStack(spacing: HeadspaceDesign.Spacing.md) {
                metricCard(
                    title: "Radiance",
                    icon: "sparkles",
                    score: emotionalMetrics.radiance,
                    description: "Light reflection quality",
                    metricType: .brightness
                )

                metricCard(
                    title: "Smoothness",
                    icon: "waveform.path",
                    score: emotionalMetrics.smoothness,
                    description: "Surface texture quality",
                    metricType: .roughness
                )

                metricCard(
                    title: "Evenness",
                    icon: "circle.hexagongrid.fill",
                    score: emotionalMetrics.evenness,
                    description: "Tone uniformity",
                    metricType: .pigmentation
                )

                metricCard(
                    title: "Firmness",
                    icon: "arrow.up.circle.fill",
                    score: emotionalMetrics.youthfulness,
                    description: "Skin elasticity",
                    metricType: .wrinkles
                )

                metricCard(
                    title: "Clarity",
                    icon: "drop.fill",
                    score: emotionalMetrics.freshness,
                    description: "Overall vitality",
                    metricType: .hydration
                )

                if emotionalMetrics.sunProtection > 0 {
                    metricCard(
                        title: "Sun Protection",
                        icon: "sun.max.fill",
                        score: emotionalMetrics.sunProtection,
                        description: "UV damage assessment",
                        metricType: .discoloration
                    )
                }
            }
        }
    }

    private var firstTimeBanner: some View {
        HStack(spacing: HeadspaceDesign.Spacing.md) {
            Image(systemName: "lightbulb")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)

            Text("New to skin metrics? Tap ? next to any metric to learn more")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                withAnimation {
                    showFirstTimeBanner = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
    }

    private func metricCard(title: String, icon: String, score: Int, description: String, metricType: MetricType? = nil) -> some View {
        HStack(spacing: HeadspaceDesign.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(metricColor(score).opacity(0.12))
                    .frame(width: 52, height: 52)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(metricColor(score))
            }

            // Content
            VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.sm) {
                HStack {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                    // Help button (if metricType is provided)
                    if let metricType = metricType {
                        Button {
                            selectedMetricForHelp = metricType
                            hasViewedMetricHelp = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    Text("\(score)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(metricColor(score))
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(metricColor(score).opacity(0.15))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(metricColor(score))
                            .frame(width: geometry.size.width * CGFloat(score) / 100, height: 8)
                    }
                }
                .frame(height: 8)

                // Quality indicator badge
                HStack(spacing: 8) {
                    qualityBadge(for: score)

                    Text(description)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                }

                // Improvement suggestion (if score needs improvement)
                if let suggestion = improvementSuggestion(for: score, metricType: metricType) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange.opacity(0.8))

                        Text(suggestion)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(HeadspaceDesign.Spacing.xl)
        .background(HeadspaceDesign.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    private var actionPlanSection: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.xl) {
            // Section header
            Text("Recommended actions")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            // Actions
            if !emotionalMetrics.nextSteps.isEmpty {
                VStack(spacing: HeadspaceDesign.Spacing.md) {
                    ForEach(emotionalMetrics.nextSteps.prefix(3)) { step in
                        actionCard(step: step)
                    }
                }
            } else {
                defaultActionsCard
            }
        }
    }

    private func actionCard(step: ActionableStep) -> some View {
        HStack(spacing: HeadspaceDesign.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(HeadspaceDesign.Colors.primary.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: step.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(HeadspaceDesign.Colors.primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(step.action)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text("\(step.frequency) • \(step.timing)")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(HeadspaceDesign.Spacing.xl)
        .background(HeadspaceDesign.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    private var defaultActionsCard: some View {
        VStack(spacing: HeadspaceDesign.Spacing.md) {
            defaultActionItem(icon: "sun.max.fill", title: "Apply SPF daily", subtitle: "Protect from UV damage")
            defaultActionItem(icon: "drop.fill", title: "Stay hydrated", subtitle: "Drink water & moisturize")
            defaultActionItem(icon: "calendar", title: "Track progress", subtitle: "Weekly scans recommended")
        }
    }

    private func defaultActionItem(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: HeadspaceDesign.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(HeadspaceDesign.Colors.primary.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(HeadspaceDesign.Colors.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }

            Spacer()
        }
    }

    private var shareButton: some View {
        VStack(spacing: HeadspaceDesign.Spacing.md) {
            // Primary: Share results
            Button {
                onShareResults()
            } label: {
                HStack(spacing: HeadspaceDesign.Spacing.md) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Share results")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(HeadspaceDesign.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
                .shadow(
                    color: HeadspaceDesign.Shadows.button.color,
                    radius: HeadspaceDesign.Shadows.button.radius,
                    x: HeadspaceDesign.Shadows.button.x,
                    y: HeadspaceDesign.Shadows.button.y
                )
            }

            // Secondary: Scan again
            Button {
                onClose()
                // User will return to home and can tap "Scan Now" again
            } label: {
                HStack(spacing: HeadspaceDesign.Spacing.md) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .semibold))

                    Text("Scan again")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundColor(HeadspaceDesign.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(HeadspaceDesign.Colors.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
            }
        }
    }

    // MARK: - Helpers

    private var scoreInterpretationTitle: String {
        switch emotionalMetrics.glowScore {
        case 90...100: return "Outstanding results"
        case 80..<90: return "Excellent progress"
        case 70..<80: return "Great work"
        case 60..<70: return "Good progress"
        case 50..<60: return "Keep going"
        default: return "Let's improve together"
        }
    }

    private var scoreGradient: LinearGradient {
        switch emotionalMetrics.glowScore {
        case 80...100: return HeadspaceDesign.Colors.mintGradient
        case 60..<80: return HeadspaceDesign.Colors.warmGradient
        default: return HeadspaceDesign.Colors.peachGradient
        }
    }

    private var scoreInterpretation: String {
        switch emotionalMetrics.glowScore {
        case 90...100: return "Your skin health is outstanding. Keep up your excellent routine to maintain these results."
        case 80..<90: return "Your skin health is in great shape. Continue your current routine for best results."
        case 70..<80: return "You're making good progress. Follow the recommendations below to improve further."
        case 60..<70: return "Your skin health is fair. Implement the actions below to see improvements."
        case 50..<60: return "There's room for improvement. Follow our personalized action plan below."
        default: return "Let's work together to improve your skin health with the action plan below."
        }
    }

    private func metricColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return HeadspaceDesign.Colors.success
        case 60..<80: return HeadspaceDesign.Colors.secondary
        case 40..<60: return HeadspaceDesign.Colors.accent
        default: return HeadspaceDesign.Colors.primary
        }
    }

    /// Quality badge showing assessment level
    @ViewBuilder
    private func qualityBadge(for score: Int) -> some View {
        let (label, color) = qualityLevel(for: score)

        Text(label)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    /// Get quality level label and color for score
    private func qualityLevel(for score: Int) -> (String, Color) {
        switch score {
        case 90...100:
            return ("Excellent", HeadspaceDesign.Colors.success)
        case 75..<90:
            return ("Good", HeadspaceDesign.Colors.success)
        case 60..<75:
            return ("Fair", HeadspaceDesign.Colors.secondary)
        case 40..<60:
            return ("Needs Attention", HeadspaceDesign.Colors.accent)
        default:
            return ("Needs Improvement", HeadspaceDesign.Colors.primary)
        }
    }

    /// Get context-sensitive improvement suggestion based on score and metric type
    private func improvementSuggestion(for score: Int, metricType: MetricType?) -> String? {
        // Only show suggestions for scores below 75
        guard score < 75, let metricType = metricType else { return nil }

        switch metricType {
        case .brightness:
            return "Try vitamin C serums or exfoliating to boost radiance"
        case .roughness:
            return "Regular exfoliation and moisturizing can improve smoothness"
        case .pigmentation:
            return "SPF daily and targeted treatments can help even skin tone"
        case .wrinkles:
            return "Retinol and peptides can help improve skin firmness"
        case .hydration:
            return "Increase water intake and use hydrating serums"
        case .discoloration:
            return "Daily SPF 30+ is essential for preventing UV damage"
        case .pores:
            return "Salicylic acid and niacinamide can help minimize pores"
        case .specular:
            return "Oil-control products and regular cleansing can help"
        case .luminance:
            return "Brightening serums with vitamin C can enhance luminosity"
        }
    }

    // MARK: - Animations

    private func animateEntrance() {
        withAnimation(HeadspaceDesign.Animations.gentle.delay(0.1)) {
            showScore = true
        }

        withAnimation(HeadspaceDesign.Animations.gentle.delay(0.3)) {
            showMetrics = true
        }

        withAnimation(HeadspaceDesign.Animations.gentle.delay(0.5)) {
            showActions = true
        }

        // Show first-time banner after animations complete
        if !hasViewedMetricHelp {
            withAnimation(HeadspaceDesign.Animations.gentle.delay(0.8)) {
                showFirstTimeBanner = true
            }
        }
    }

    // MARK: - Save Status Banner

    @ViewBuilder
    private func saveStatusBanner(status: SaveStatus) -> some View {
        HStack(spacing: 12) {
            // Status icon
            Group {
                switch status {
                case .saving:
                    ProgressView()
                        .tint(HeadspaceDesign.Colors.textSecondary)
                case .saved:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(HeadspaceDesign.Colors.success)
                case .failed, .queued:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                case .coreDataUnavailable:
                    Image(systemName: "externaldrive.fill.badge.exclamationmark")
                        .foregroundColor(.red)
                }
            }
            .frame(width: 20, height: 20)

            // Status message
            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle(for: status))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text(statusMessage(for: status))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(HeadspaceDesign.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md)
                .fill(statusBackgroundColor(for: status))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md)
                .stroke(statusBorderColor(for: status), lineWidth: 1)
        )
    }

    private func statusTitle(for status: SaveStatus) -> String {
        switch status {
        case .saving:
            return "Saving to History"
        case .failed:
            return "Save Failed"
        case .queued:
            return "Queued for Retry"
        case .coreDataUnavailable:
            return "Storage Issue Detected"
        case .saved:
            return ""
        }
    }

    private func statusMessage(for status: SaveStatus) -> String {
        switch status {
        case .saving:
            return "Your results are being saved..."
        case .failed:
            return "Your results are visible but won't appear in history. Will retry automatically."
        case .queued:
            return "Your results will be saved automatically when possible."
        case .coreDataUnavailable:
            return "Device storage unavailable. Results saved to backup file. Tap to export or contact support."
        case .saved:
            return ""
        }
    }

    private func statusBackgroundColor(for status: SaveStatus) -> Color {
        switch status {
        case .saving:
            return HeadspaceDesign.Colors.cardBackground
        case .failed, .queued:
            return Color.orange.opacity(0.1)
        case .coreDataUnavailable:
            return Color.red.opacity(0.1)
        case .saved:
            return .clear
        }
    }

    private func statusBorderColor(for status: SaveStatus) -> Color {
        switch status {
        case .saving:
            return HeadspaceDesign.Colors.border
        case .failed, .queued:
            return Color.orange.opacity(0.3)
        case .coreDataUnavailable:
            return Color.red.opacity(0.4)
        case .saved:
            return .clear
        }
    }

    // MARK: - Comparison Warning Banner

    @ViewBuilder
    private func comparisonWarningBanner(warning: String) -> some View {
        HStack(spacing: 12) {
            // Warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .frame(width: 20, height: 20)

            // Warning message
            VStack(alignment: .leading, spacing: 4) {
                Text("Comparison Unavailable")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text(warning)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(HeadspaceDesign.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
