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
    @State private var selectedMetricForHelp: AnalysisMetricType? = nil
    @State private var showFirstTimeBanner = false
    @State private var animatedScore: CGFloat = 0  // For smooth circle animation
    @AppStorage(AppDefaultsKey.hasViewedMetricHelp) private var hasViewedMetricHelp = false

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
                VStack(spacing: Designs.Spacing.xxxl) {
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

                    // NEW: Summary component - immediately below the score
                    summarySection
                        .opacity(showScore ? 1 : 0)
                        .offset(y: showScore ? 0 : 10)

                    // NEW: Key Metrics with circular progress rings
                    keyMetricsSection
                        .opacity(showMetrics ? 1 : 0)
                        .offset(y: showMetrics ? 0 : 10)

                    // First-time user banner
                    if showFirstTimeBanner {
                        firstTimeBanner
                            .opacity(showFirstTimeBanner ? 1 : 0)
                            .offset(y: showFirstTimeBanner ? 0 : 10)
                    }

                    // NEW: Detailed Skin Profile (merged metrics + clinical diagnosis)
                    detailedSkinProfileSection
                        .opacity(showActions ? 1 : 0)
                        .offset(y: showActions ? 0 : 10)

                    // Action plan
                    actionPlanSection
                        .opacity(showActions ? 1 : 0)
                        .offset(y: showActions ? 0 : 10)

                    // Recommended Products (MOVED TO BOTTOM)
                    recommendedProductsSection
                        .opacity(showActions ? 1 : 0)
                        .offset(y: showActions ? 0 : 10)

                    // Share button
                    shareButton

                    Spacer().frame(height: Designs.Spacing.xxl)
                }
                .padding(.horizontal, Designs.Spacing.lg)
                .padding(.top, 80)
            }
            .background(Designs.Colors.background)

            // Floating close button
            HStack {
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: SFSymbol.xmark)
                        .font(AppFont.headline)
                        .foregroundColor(Designs.Colors.textSecondary)
                        .frame(width: Designs.Sizes.iconXSmall, height: Designs.Sizes.iconXSmall)
                        .background(Designs.Colors.cardBackground)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, Designs.Spacing.lg)
            .padding(.top, Designs.Spacing.md)
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
        VStack(spacing: Designs.Spacing.md) {
            Text(scoreInterpretationTitle)
                .font(.app(size: 32, weight: .bold))
                .foregroundColor(Designs.Colors.textPrimary)
                .multilineTextAlignment(.center)

            if !emotionalMetrics.personalizedMessage.isEmpty {
                Text(emotionalMetrics.personalizedMessage)
                    .font(.app(size: 18, weight: .regular))
                    .foregroundColor(Designs.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var mainScoreCard: some View {
        VStack(spacing: 0) {
            // Gradient section with score
            ZStack {
                scoreGradient
                    .frame(height: Designs.Sizes.displayHeightLarge)

                VStack(spacing: Designs.Spacing.xl) {
                    // Score circle
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(Designs.Opacity.light), lineWidth: 10)
                            .frame(width: Designs.Sizes.scoreCircleLarge, height: Designs.Sizes.scoreCircleLarge)

                        Circle()
                            .trim(from: 0, to: animatedScore / 100)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: Designs.Sizes.scoreCircleLarge, height: Designs.Sizes.scoreCircleLarge)
                            .rotationEffect(.degrees(-90))
                            .animation(Designs.Animation.slowEaseOut, value: animatedScore)

                        Text("\(Int(animatedScore))")
                            .font(.scoreFont(size: 64))
                            .foregroundColor(.white)
                            .animation(Designs.Animation.slowEaseOut, value: animatedScore)
                    }

                    Text("Your Skin Health Score")
                        .font(.app(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(Designs.Opacity.almostOpaque))
                }
            }

            // YELLOW description section (was white-on-white!)
            VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                Text(scoreInterpretation)
                    .font(AppFont.bodyMedium)
                    .foregroundColor(Designs.Colors.textPrimary)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Designs.Spacing.xl)
            .background(Designs.Colors.primary.opacity(Designs.Opacity.medium))
        }
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
        .shadow(
            color: Designs.Shadows.card.color,
            radius: Designs.Shadows.card.radius,
            x: Designs.Shadows.card.x,
            y: Designs.Shadows.card.y
        )
    }

    // MARK: - Summary Section (NEW - "The Grip")

    private var summarySection: some View {
        VStack(spacing: Designs.Spacing.md) {
            Text(dynamicSummaryText)
                .font(AppFont.headlineSecondary)
                .foregroundColor(Designs.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(Designs.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(Designs.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
        .shadow(
            color: Designs.Shadows.card.color,
            radius: Designs.Shadows.card.radius,
            x: Designs.Shadows.card.x,
            y: Designs.Shadows.card.y
        )
    }

    /// Dynamic 1-2 sentence summary based on metrics
    private var dynamicSummaryText: String {
        // Identify strengths (scores >= 75)
        let strengths: [(String, Int)] = [
            ("hydration", emotionalMetrics.freshness),
            ("texture", emotionalMetrics.smoothness),
            ("radiance", emotionalMetrics.radiance),
            ("tone evenness", emotionalMetrics.evenness),
            ("wrinkle control", emotionalMetrics.youthfulness)
        ].filter { $0.1 >= 75 }

        // Identify areas needing attention (scores < 60)
        let needsAttention: [(String, Int)] = [
            ("hydration", emotionalMetrics.freshness),
            ("texture", emotionalMetrics.smoothness),
            ("radiance", emotionalMetrics.radiance),
            ("tone evenness", emotionalMetrics.evenness),
            ("wrinkle control", emotionalMetrics.youthfulness)
        ].filter { $0.1 < 60 }

        // Build summary based on analysis
        let overallScore = emotionalMetrics.skinHealthScore

        if overallScore >= 80 {
            if let topStrength = strengths.max(by: { $0.1 < $1.1 }) {
                return "Excellent results! Your \(topStrength.0) is outstanding. Keep up your current routine to maintain these results."
            }
            return "Excellent results! Your skin health is in great shape across all metrics."
        } else if overallScore >= 60 {
            let strengthText = strengths.first.map { "Your \($0.0) is high" } ?? "Good foundation"
            let attentionText = needsAttention.first.map { ", but \($0.0) needs attention" } ?? ""
            return "\(strengthText)\(attentionText). Follow the recommendations below for improvement."
        } else {
            if let focus = needsAttention.min(by: { $0.1 < $1.1 }) {
                return "Focus on improving \(focus.0) first. Small consistent steps will show results over time."
            }
            return "Let's work together on improving your skin health. Start with the action plan below."
        }
    }

    // MARK: - Key Metrics Section (NEW - Circular Progress Rings)

    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.lg) {
            Text("Key Metrics")
                .font(AppFont.sectionHeader)
                .foregroundColor(Designs.Colors.textPrimary)

            // Horizontal row of circular progress rings
            HStack(spacing: Designs.Spacing.lg) {
                circularMetricRing(
                    title: "Lines & Wrinkles",
                    score: emotionalMetrics.youthfulness,
                    icon: "arrow.up.circle.fill"
                )

                circularMetricRing(
                    title: "Texture",
                    score: emotionalMetrics.smoothness,
                    icon: "waveform.path"
                )

                circularMetricRing(
                    title: "Hydration",
                    score: emotionalMetrics.freshness,
                    icon: "drop.fill"
                )

                circularMetricRing(
                    title: "Radiance",
                    score: emotionalMetrics.radiance,
                    icon: "sparkles"
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(Designs.Spacing.xl)
        .background(Designs.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
        .shadow(
            color: Designs.Shadows.card.color,
            radius: Designs.Shadows.card.radius,
            x: Designs.Shadows.card.x,
            y: Designs.Shadows.card.y
        )
    }

    /// Individual circular progress ring for key metrics
    private func circularMetricRing(title: String, score: Int, icon: String) -> some View {
        VStack(spacing: Designs.Spacing.sm) {
            // Circular progress ring
            ZStack {
                Circle()
                    .stroke(metricColor(score).opacity(Designs.Opacity.light), lineWidth: 6)
                    .frame(width: Designs.Sizes.metricRingMedium, height: Designs.Sizes.metricRingMedium)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(metricColor(score), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: Designs.Sizes.metricRingMedium, height: Designs.Sizes.metricRingMedium)
                    .rotationEffect(.degrees(-90))

                Text("\(score)")
                    .font(AppFont.headlineSecondary)
                    .foregroundColor(metricColor(score))
            }

            // Title
            Text(title)
                .font(AppFont.caption)
                .foregroundColor(Designs.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Detailed Skin Profile (MERGED - Metrics + Clinical Diagnosis)

    @State private var expandedProfileMetric: String? = nil

    private var detailedSkinProfileSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("Detailed Skin Profile")
                .font(AppFont.sectionHeader)
                .foregroundColor(Designs.Colors.textPrimary)
                .padding(.horizontal, Designs.Spacing.lg)
                .padding(.top, Designs.Spacing.lg)
                .padding(.bottom, Designs.Spacing.md)

            // Expandable metric rows
            VStack(spacing: 0) {
                profileMetricRow(
                    title: "Texture",
                    icon: SFSymbol.waveformPath,
                    score: emotionalMetrics.smoothness,
                    diagnosis: "Surface texture quality measured by analyzing pore size distribution, surface smoothness, and uniformity. We measure micro-variations in the skin surface to assess overall skin refinement.",
                    metricId: "profile_texture",
                    metricType: .roughness
                )

                Divider().padding(.horizontal, Designs.Spacing.lg)

                profileMetricRow(
                    title: "Hydration",
                    icon: "drop.fill",
                    score: emotionalMetrics.freshness,
                    diagnosis: "Overall skin vitality measured by analyzing hydration markers and surface moisture levels. Higher scores indicate well-hydrated, healthy-looking skin with good moisture balance.",
                    metricId: "profile_hydration",
                    metricType: .hydration
                )

                Divider().padding(.horizontal, Designs.Spacing.lg)

                profileMetricRow(
                    title: "Radiance",
                    icon: SFSymbol.sparkles,
                    score: emotionalMetrics.radiance,
                    diagnosis: "Light reflection quality measured by analyzing light reflection patterns, skin luminosity, and color vibrance across different facial zones. Higher scores indicate healthier, more luminous skin.",
                    metricId: "profile_radiance",
                    metricType: .brightness
                )

                Divider().padding(.horizontal, Designs.Spacing.lg)

                profileMetricRow(
                    title: "Tone Evenness",
                    icon: "circle.hexagongrid.fill",
                    score: emotionalMetrics.evenness,
                    diagnosis: "Skin tone uniformity calculated by measuring color consistency, detecting hyperpigmentation, and analyzing color distribution across facial regions.",
                    metricId: "profile_evenness",
                    metricType: .pigmentation
                )

                Divider().padding(.horizontal, Designs.Spacing.lg)

                profileMetricRow(
                    title: "Redness Control",
                    icon: SFSymbol.heartFill,
                    score: emotionalMetrics.rednessScore,
                    diagnosis: "Skin redness detected by analyzing red channel intensity, inflammation patterns, and vascular visibility across facial regions. Higher scores indicate calmer, less inflamed skin.",
                    metricId: "profile_redness",
                    metricType: .discoloration
                )

                Divider().padding(.horizontal, Designs.Spacing.lg)

                profileMetricRow(
                    title: "Acne",
                    icon: "circle.fill",
                    score: emotionalMetrics.acneScore,
                    diagnosis: "Breakout assessment based on detecting surface irregularities, inflammation markers, and breakout patterns. We analyze texture variations and color changes associated with active acne. Higher scores indicate clearer skin.",
                    metricId: "profile_acne",
                    metricType: .pigmentation
                )

                Divider().padding(.horizontal, Designs.Spacing.lg)

                profileMetricRow(
                    title: "Lines & Wrinkles",
                    icon: "arrow.up.circle.fill",
                    score: emotionalMetrics.youthfulness,
                    diagnosis: "Wrinkle assessment using advanced 3D mesh analysis to detect surface irregularities and depth variations. Wrinkle severity is calculated by measuring the depth, length, and density of facial creases across 50,000+ data points. Higher scores indicate fewer, shallower wrinkles.",
                    metricId: "profile_wrinkles",
                    metricType: .wrinkles
                )

                Divider().padding(.horizontal, Designs.Spacing.lg)

                profileMetricRow(
                    title: "Shine Detection",
                    icon: "sparkle",
                    score: emotionalMetrics.oilControlScore,
                    diagnosis: "Surface shine measured by analyzing specular highlights and reflection patterns. Detects areas with high reflectance that may indicate oiliness or product application. Higher scores indicate less shine and better matteness.",
                    metricId: "profile_shine",
                    metricType: .hydration
                )

                Divider().padding(.horizontal, Designs.Spacing.lg)

                profileMetricRow(
                    title: "Pore Visibility",
                    icon: "circle.grid.3x3.fill",
                    score: emotionalMetrics.poreScore,
                    diagnosis: "Pore size and visibility measured using high-frequency texture analysis. We detect enlarged pores, pore density, and size distribution across different facial zones. Higher scores indicate smaller, less visible pores.",
                    metricId: "profile_pores",
                    metricType: .pores
                )
            }
            .padding(.bottom, Designs.Spacing.md)
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

    /// Expandable profile metric row showing score and clinical diagnosis
    private func profileMetricRow(title: String, icon: String, score: Int, diagnosis: String, metricId: String, metricType: AnalysisMetricType) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tappable header row
            Button {
                withAnimation(Designs.Animation.spring) {
                    expandedProfileMetric = expandedProfileMetric == metricId ? nil : metricId
                }
            } label: {
                HStack(spacing: Designs.Spacing.md) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(metricColor(score).opacity(Designs.Opacity.veryLight))
                            .frame(width: Designs.Sizes.iconMedium, height: Designs.Sizes.iconMedium)

                        Image(systemName: icon)
                            .font(AppFont.cardTitle)
                            .foregroundColor(metricColor(score))
                    }

                    // Title and quality badge
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(AppFont.subheadingPrimary)
                            .foregroundColor(Designs.Colors.textPrimary)

                        qualityBadge(for: score)
                    }

                    Spacer()

                    // Score
                    Text("\(score)")
                        .font(AppFont.title2)
                        .foregroundColor(metricColor(score))

                    // Chevron
                    Image(systemName: expandedProfileMetric == metricId ? SFSymbol.chevronUp : SFSymbol.chevronDown)
                        .font(AppFont.metricLabel)
                        .foregroundColor(Designs.Colors.textSecondary)
                }
                .padding(Designs.Spacing.lg)
            }

            // Expanded diagnosis content
            if expandedProfileMetric == metricId {
                VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                    // Diagnosis text
                    Text(diagnosis)
                        .font(AppFont.caption)
                        .foregroundColor(Designs.Colors.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    // Improvement suggestion (if applicable)
                    if let suggestion = improvementSuggestion(for: score, metricType: metricType) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: SFSymbol.lightbulbFill)
                                .font(AppFont.caption)
                                .foregroundColor(Designs.Colors.warning)

                            Text(suggestion)
                                .font(AppFont.caption)
                                .foregroundColor(Designs.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(Designs.Spacing.md)
                        .background(Designs.Colors.warning.opacity(Designs.Opacity.veryLight))
                        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
                    }

                    // Help button
                    Button {
                        selectedMetricForHelp = metricType
                        hasViewedMetricHelp = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: SFSymbol.questionmarkCircle)
                                .font(AppFont.caption)
                            Text("Learn more about \(title.lowercased())")
                                .font(AppFont.footnote)
                        }
                        .foregroundColor(Designs.Colors.primary)
                    }
                }
                .padding(.horizontal, Designs.Spacing.lg)
                .padding(.bottom, Designs.Spacing.lg)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var firstTimeBanner: some View {
        HStack(spacing: Designs.Spacing.md) {
            Image(systemName: SFSymbol.lightbulb)
                .font(AppFont.metricValue)
                .foregroundColor(Designs.Colors.textSecondary)

            Text("New to skin metrics? Tap any metric to see details and tips")
                .font(AppFont.bodySecondary)
                .foregroundColor(Designs.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                withAnimation {
                    showFirstTimeBanner = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(AppFont.metricLabel)
                    .foregroundColor(Designs.Colors.textSecondary)
            }
        }
        .padding(Designs.Spacing.lg)
        .background(Designs.Colors.info.opacity(Designs.Opacity.veryLight))
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
    }

    private var actionPlanSection: some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.xl) {
            // Section header
            Text("Recommended actions")
                .font(AppFont.sectionHeader)
                .foregroundColor(Designs.Colors.textPrimary)

            // Actions
            if !emotionalMetrics.nextSteps.isEmpty {
                VStack(spacing: Designs.Spacing.md) {
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
        HStack(spacing: Designs.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(Designs.Colors.primary.opacity(Designs.Opacity.veryLight))
                    .frame(width: Designs.Sizes.cardIcon, height: Designs.Sizes.cardIcon)

                Image(systemName: step.icon)
                    .font(AppFont.sectionHeader)
                    .foregroundColor(Designs.Colors.primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(step.action)
                    .font(AppFont.subheadingPrimary)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text("\(step.frequency) • \(step.timing)")
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(Designs.Spacing.xl)
        .background(Designs.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
        .shadow(
            color: Designs.Shadows.card.color,
            radius: Designs.Shadows.card.radius,
            x: Designs.Shadows.card.x,
            y: Designs.Shadows.card.y
        )
    }

    private var defaultActionsCard: some View {
        VStack(spacing: Designs.Spacing.md) {
            defaultActionItem(icon: "sun.max.fill", title: "Apply SPF daily", subtitle: "Protect from UV damage")
            defaultActionItem(icon: "drop.fill", title: "Stay hydrated", subtitle: "Drink water & moisturize")
            defaultActionItem(icon: "calendar", title: "Track progress", subtitle: "Weekly scans recommended")
        }
    }

    private func defaultActionItem(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: Designs.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Designs.Colors.primary.opacity(Designs.Opacity.veryLight))
                    .frame(width: Designs.Sizes.cardIcon, height: Designs.Sizes.cardIcon)

                Image(systemName: icon)
                    .font(AppFont.sectionHeader)
                    .foregroundColor(Designs.Colors.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFont.subheadingPrimary)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text(subtitle)
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
            }

            Spacer()
        }
    }

    private var shareButton: some View {
        VStack(spacing: Designs.Spacing.md) {
            // Primary: Share results
            Button {
                onShareResults()
            } label: {
                HStack(spacing: Designs.Spacing.md) {
                    Image(systemName: "square.and.arrow.up")
                        .font(AppFont.cardTitle)

                    Text("Share results")
                        .font(AppFont.headlineSecondary)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Designs.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
                .shadow(
                    color: Designs.Shadows.button.color,
                    radius: Designs.Shadows.button.radius,
                    x: Designs.Shadows.button.x,
                    y: Designs.Shadows.button.y
                )
            }

            // Secondary: Scan again
            Button {
                onClose()
                // User will return to home and can tap "Scan Now" again
            } label: {
                HStack(spacing: Designs.Spacing.md) {
                    Image(systemName: "camera.fill")
                        .font(AppFont.bodyPrimary)

                    Text("Scan again")
                        .font(AppFont.subheadingPrimary)
                }
                .foregroundColor(Designs.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Designs.Colors.primary.opacity(Designs.Opacity.veryLight))
                .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
            }
        }
    }

    // MARK: - Recommended Products Section

    private var recommendedProductsSection: some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.md) {
            Text("Recommended Products")
                .font(AppFont.title2)
                .foregroundColor(Designs.Colors.textPrimary)

            Text("Based on your skin analysis")
                .font(.app(size: 14, weight: .regular))
                .foregroundColor(Designs.Colors.textSecondary)

            VStack(spacing: Designs.Spacing.md) {
                productCard(
                    name: "Hydrating Serum",
                    category: "Moisturizer",
                    reason: "For improved hydration",
                    priority: "High"
                )

                productCard(
                    name: "Retinol Night Cream",
                    category: "Anti-Aging",
                    reason: "To reduce fine lines",
                    priority: "Medium"
                )

                productCard(
                    name: "Vitamin C Brightening Serum",
                    category: "Brightening",
                    reason: "For more even skin tone",
                    priority: "Medium"
                )
            }

            Text("Note: Product recommendations are placeholder examples")
                .font(.app(size: 12, weight: .regular))
                .foregroundColor(Designs.Colors.textTertiary)
                .padding(.top, 8)
        }
        .padding(Designs.Spacing.lg)
        .background(Designs.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
    }

    private func productCard(name: String, category: String, reason: String, priority: String) -> some View {
        HStack(spacing: Designs.Spacing.md) {
            // Placeholder product image
            RoundedRectangle(cornerRadius: 8)
                .fill(Designs.Colors.primary.opacity(Designs.Opacity.veryLight))
                .frame(width: Designs.Sizes.metricRingMedium, height: Designs.Sizes.metricRingMedium)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(AppFont.navIcon)
                        .foregroundColor(Designs.Colors.primary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.app(size: 15, weight: .semibold))
                    .foregroundColor(Designs.Colors.textPrimary)

                Text(category)
                    .font(.app(size: 13, weight: .medium))
                    .foregroundColor(Designs.Colors.textSecondary)

                Text(reason)
                    .font(.app(size: 12, weight: .regular))
                    .foregroundColor(Designs.Colors.textTertiary)
            }

            Spacer()

            VStack {
                Text(priority)
                    .font(.app(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priority == "High" ? Designs.Colors.warning : Designs.Colors.info)
                    .clipShape(Capsule())
            }
        }
        .padding(Designs.Spacing.md)
        .background(Designs.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
    }

    // MARK: - Helpers

    private var scoreInterpretationTitle: String {
        switch emotionalMetrics.skinHealthScore {
        case 90...100: return "Outstanding results"
        case 80..<90: return "Excellent progress"
        case 70..<80: return "Great work"
        case 60..<70: return "Good progress"
        case 50..<60: return "Keep going"
        default: return "Let's improve together"
        }
    }

    private var scoreGradient: LinearGradient {
        switch emotionalMetrics.skinHealthScore {
        case 80...100: return Designs.Colors.mintGradient
        case 60..<80: return Designs.Colors.warmGradient
        default: return Designs.Colors.peachGradient
        }
    }

    private var scoreInterpretation: String {
        switch emotionalMetrics.skinHealthScore {
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
        case 80...100: return Designs.Colors.success
        case 60..<80: return Designs.Colors.secondary
        case 40..<60: return Designs.Colors.accent
        default: return Designs.Colors.primary
        }
    }

    /// Quality badge showing assessment level
    @ViewBuilder
    private func qualityBadge(for score: Int) -> some View {
        let (label, color) = qualityLevel(for: score)

        Text(label)
            .font(AppFont.microBold)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(Designs.Opacity.veryLight + 0.05))
            .clipShape(Capsule())
    }

    /// Get quality level label and color for score
    private func qualityLevel(for score: Int) -> (String, Color) {
        switch score {
        case 90...100:
            return ("Excellent", Designs.Colors.success)
        case 75..<90:
            return ("Good", Designs.Colors.success)
        case 60..<75:
            return ("Fair", Designs.Colors.secondary)
        case 40..<60:
            return ("Needs Attention", Designs.Colors.accent)
        default:
            return ("Needs Improvement", Designs.Colors.primary)
        }
    }

    /// Get context-sensitive improvement suggestion based on score and metric type
    private func improvementSuggestion(for score: Int, metricType: AnalysisMetricType?) -> String? {
        // Only show suggestions for scores below 75
        guard score < 75, let metricType = metricType else { return nil }

        switch metricType {
        case .brightness:
            if score < 40 {
                return "Apply 15-20% L-ascorbic acid vitamin C serum every morning. Your radiance score of \(score) needs targeted treatment."
            } else if score < 60 {
                return "Add a 10-15% vitamin C serum every morning. You'll see improvement in 3-4 weeks."
            } else {
                return "Maintain with 10% vitamin C serum. Your radiance is already good!"
            }
        case .roughness:
            if score < 40 {
                return "Start with 2% salicylic acid cleanser daily + 5% glycolic acid 3x weekly. Your texture score of \(score) needs targeted treatment."
            } else if score < 60 {
                return "Add a 5-7% glycolic acid toner 2-3x weekly at night. You'll see improvement in 3-4 weeks."
            } else {
                return "Maintain with gentle exfoliation 1-2x weekly. Your texture is already good!"
            }
        case .pigmentation:
            if score < 40 {
                return "Apply 15-20% vitamin C serum every morning + SPF 50+ daily. Your tone evenness score of \(score) needs targeted treatment."
            } else if score < 60 {
                return "Apply 10-15% vitamin C serum every morning + SPF 30+ daily. You'll see improvement in 4-6 weeks."
            } else {
                return "Maintain with daily SPF 30+ and vitamin C. Your tone is already even!"
            }
        case .wrinkles:
            if score < 50 {
                return "Start with 0.5% retinol serum 3-4x weekly at night + peptide serum daily. Your wrinkle score of \(score) needs targeted treatment."
            } else if score < 70 {
                return "Use 0.5% retinol serum 2-3x weekly at night + peptide serum. You'll see improvement in 6-8 weeks."
            } else {
                return "Maintain with retinol 1-2x weekly. Your skin firmness is already good!"
            }
        case .hydration:
            if score < 50 {
                return "Apply hyaluronic acid serum (5% concentration) morning and night on damp skin + ceramide moisturizer. Your hydration score of \(score) needs improvement."
            } else if score < 70 {
                return "Apply hyaluronic acid serum morning and night on damp skin. You'll see improvement in 2-3 weeks."
            } else {
                return "Maintain with hyaluronic acid as needed. Your hydration is already good!"
            }
        case .discoloration:
            if score < 40 {
                return "Apply SPF 50+ daily (most important) + brightening serum with 2% hydroquinone or 10% azelaic acid. Your discoloration score of \(score) needs targeted treatment."
            } else if score < 60 {
                return "Apply SPF 30+ daily + brightening serum with arbutin or kojic acid. You'll see fading in 4-6 weeks."
            } else {
                return "Maintain with daily SPF 30+. SPF prevents new spots from forming."
            }
        case .pores:
            if score < 40 {
                return "Use 2% salicylic acid cleanser daily + 10% niacinamide serum twice daily. Your pore visibility score of \(score) needs targeted treatment."
            } else if score < 60 {
                return "Use 2% salicylic acid cleanser daily + 10% niacinamide serum. You'll see improvement in 3-4 weeks."
            } else {
                return "Maintain with 5% niacinamide serum daily. Your pores are already well-controlled!"
            }
        case .specular:
            if score < 50 {
                return "Use oil-control cleanser with salicylic acid + mattifying serum with niacinamide. Your shine control score of \(score) needs improvement."
            } else if score < 70 {
                return "Use oil-control products and regular cleansing. You'll see improvement in 2-3 weeks."
            } else {
                return "Maintain with regular cleansing. Your oil control is already good!"
            }
        case .luminance:
            if score < 40 {
                return "Apply 15-20% vitamin C serum every morning + brightening serum. Your brightness score of \(score) needs targeted treatment."
            } else if score < 60 {
                return "Add a 10-15% vitamin C serum every morning. You'll see improvement in 3-4 weeks."
            } else {
                return "Maintain with 10% vitamin C serum. Your brightness is already good!"
            }
        }
    }

    // MARK: - Animations

    private func animateEntrance() {
        withAnimation(Designs.Animations.gentle.delay(0.1)) {
            showScore = true
        }

        // Animate score circle from 0 to target value
        withAnimation(Designs.Animation.slowEaseOut.delay(0.3)) {
            animatedScore = CGFloat(emotionalMetrics.skinHealthScore)
        }

        withAnimation(Designs.Animations.gentle.delay(0.3)) {
            showMetrics = true
        }

        withAnimation(Designs.Animations.gentle.delay(0.5)) {
            showActions = true
        }

        // Show first-time banner after animations complete
        if !hasViewedMetricHelp {
            withAnimation(Designs.Animations.gentle.delay(0.8)) {
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
                        .tint(Designs.Colors.textSecondary)
                case .saved:
                    Image(systemName: SFSymbol.checkmarkCircleFill)
                        .foregroundColor(Designs.Colors.success)
                case .failed, .queued:
                    Image(systemName: SFSymbol.exclamationTriangleFill)
                        .foregroundColor(Designs.Colors.warning)
                case .coreDataUnavailable:
                    Image(systemName: "externaldrive.fill.badge.exclamationmark")
                        .foregroundColor(Designs.Colors.error)
                }
            }
            .frame(width: Designs.Sizes.iconTiny, height: Designs.Sizes.iconTiny)

            // Status message
            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle(for: status))
                    .font(AppFont.bodyMedium)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text(statusMessage(for: status))
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(Designs.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Designs.Radius.md)
                .fill(statusBackgroundColor(for: status))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Designs.Radius.md)
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
            return "Device storage unavailable. Results saved to backup file. Tap here to export."
        case .saved:
            return ""
        }
    }

    private func statusBackgroundColor(for status: SaveStatus) -> Color {
        switch status {
        case .saving:
            return Designs.Colors.cardBackground
        case .failed, .queued:
            return Designs.Colors.warning.opacity(Designs.Opacity.veryLight)
        case .coreDataUnavailable:
            return Designs.Colors.error.opacity(Designs.Opacity.veryLight)
        case .saved:
            return .clear
        }
    }

    private func statusBorderColor(for status: SaveStatus) -> Color {
        switch status {
        case .saving:
            return Designs.Colors.border
        case .failed, .queued:
            return Designs.Colors.warning.opacity(Designs.Opacity.medium)
        case .coreDataUnavailable:
            return Designs.Colors.error.opacity(Designs.Opacity.semiOpaque)
        case .saved:
            return .clear
        }
    }

    // MARK: - Comparison Warning Banner

    @ViewBuilder
    private func comparisonWarningBanner(warning: String) -> some View {
        HStack(spacing: 12) {
            // Warning icon
            Image(systemName: SFSymbol.exclamationTriangleFill)
                .foregroundColor(Designs.Colors.warning)
                .frame(width: Designs.Sizes.iconTiny, height: Designs.Sizes.iconTiny)

            // Warning message
            VStack(alignment: .leading, spacing: 4) {
                Text("Comparison Unavailable")
                    .font(AppFont.bodyMedium)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text(warning)
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(Designs.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Designs.Radius.md)
                .fill(Designs.Colors.warning.opacity(Designs.Opacity.veryLight))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Designs.Radius.md)
                .stroke(Designs.Colors.warning.opacity(Designs.Opacity.medium), lineWidth: Designs.Border.width)
        )
    }
}
