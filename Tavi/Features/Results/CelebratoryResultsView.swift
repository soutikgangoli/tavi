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

    @State private var showScore = false
    @State private var showMetrics = false
    @State private var showActions = false

    public init(
        emotionalMetrics: EmotionalMetrics,
        clinicalMetrics: Face3DMetrics? = nil,
        onShareResults: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {}
    ) {
        self.emotionalMetrics = emotionalMetrics
        self.clinicalMetrics = clinicalMetrics
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

                    // Main score card
                    mainScoreCard
                        .opacity(showScore ? 1 : 0)
                        .scaleEffect(showScore ? 1 : 0.95)

                    // Metrics breakdown
                    metricsSection
                        .opacity(showMetrics ? 1 : 0)
                        .offset(y: showMetrics ? 0 : 10)

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
            .background(Color.white)
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
                    description: "Light reflection quality"
                )

                metricCard(
                    title: "Smoothness",
                    icon: "waveform.path",
                    score: emotionalMetrics.smoothness,
                    description: "Surface texture quality"
                )

                metricCard(
                    title: "Evenness",
                    icon: "circle.hexagongrid.fill",
                    score: emotionalMetrics.evenness,
                    description: "Tone uniformity"
                )

                metricCard(
                    title: "Firmness",
                    icon: "arrow.up.circle.fill",
                    score: emotionalMetrics.youthfulness,
                    description: "Skin elasticity"
                )

                metricCard(
                    title: "Clarity",
                    icon: "drop.fill",
                    score: emotionalMetrics.freshness,
                    description: "Overall vitality"
                )

                if emotionalMetrics.sunProtection > 0 {
                    metricCard(
                        title: "Sun Protection",
                        icon: "sun.max.fill",
                        score: emotionalMetrics.sunProtection,
                        description: "UV damage assessment"
                    )
                }
            }
        }
    }

    private func metricCard(title: String, icon: String, score: Int, description: String) -> some View {
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

                Text(description)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }
        }
        .padding(HeadspaceDesign.Spacing.xl)
        .background(Color.white)
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
        .background(Color.white)
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
    }
}
