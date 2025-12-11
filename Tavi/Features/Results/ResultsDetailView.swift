//
//  ResultsDetailView.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI
import CoreData

/// Detailed view of a single analysis session with all metrics and heatmaps
struct ResultsDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    let session: SessionResult

    @State private var selectedHeatmap: HeatmapType = .composite
    @State private var showingOriginal = false
    @State private var showingDeleteAlert = false
    @State private var clinicalMetrics: Face3DMetrics?
    @State private var isGeneratingPDF = false
    @State private var isPreparingShare = false
    @State private var showSocialSharing = false
    @State private var errorState: ResultsDetailViewErrorState?
    @State private var isDebugSectionExpanded = false  // Collapsible for detailed metrics (Smoothness to Redness)
    @State private var isClinicalDataExpanded = false  // Collapsible for Clinical Data section

    init(session: SessionResult) {
        self.session = session
        // Decode clinical metrics for confidence scores with versioned loader
        // Use a safe approach that won't crash if data is corrupted
        if let data = session.clinicalMetricsData, !data.isEmpty {
            let result = VersionedMetricsLoader.loadFace3DMetrics(from: data)
            if let metrics = result.metrics {
                _clinicalMetrics = State(initialValue: metrics)
                if case .migrated(_, let from, let to) = result {
                    AppLogger.ui.info("Migrated clinical metrics from v\(from.versionString) to v\(to.versionString)")
                }
            } else {
                AppLogger.ui.warning("Failed to load clinical metrics in ResultsDetailView: \(result.userMessage)")
                _clinicalMetrics = State(initialValue: nil)
            }
        } else {
            _clinicalMetrics = State(initialValue: nil)
        }
    }

    var body: some View {
        Group {
            if let error = errorState {
                errorView(error)
            } else {
                contentView
            }
        }
        .navigationTitle("Analysis Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showSocialSharing = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .alert("Delete Session", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSession()
            }
        } message: {
            Text("Are you sure you want to delete this analysis session?")
        }
        .sheet(isPresented: $showSocialSharing) {
            // Decode emotional metrics from session data
            if let emotionalData = session.emotionalMetricsData,
               let decoded = try? JSONDecoder().decode(EmotionalMetrics.self, from: emotionalData) {
                SocialSharingView(
                    emotionalMetrics: decoded,
                    streak: GamificationManager.shared.getStreak(),
                    challenge: GamificationManager.shared.getCurrentChallenge(),
                    recentAchievement: nil
                )
            } else {
                // Fallback if no emotional metrics available
                Text("Unable to load sharing options")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    // MARK: - Content View

    var contentView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Designs.Spacing.xxxl) {
                // Header
                headerSection

                // Face Image with Heatmap Toggle
                imageSection

                // Overall Score Card (Skin Health Score)
                overallScoreCard

                // Aging Indicators Section (Wrinkles & Volume - separate from health score)
                if let metrics = clinicalMetrics {
                    agingIndicatorsSection(metrics)
                }

                // Metrics Grid
                metricsGrid

                // Glow vs Radiance Breakdown (if available)
                if let metrics = clinicalMetrics, let glowAnalysis = metrics.glowAnalysis {
                    glowRadianceBreakdown(glowAnalysis)
                }

                // Full Clinical Breakdown (NEW - shows ALL metrics details)
                if let metrics = clinicalMetrics {
                    fullClinicalBreakdown(metrics)
                }

                // ROI Scores
                roiScoresSection

                // Actions
                actionsSection

                Spacer().frame(height: Designs.Spacing.xxl)
            }
            .padding(.horizontal, Designs.Spacing.lg)
            .padding(.top, Designs.Spacing.lg)
        }
        .background(Designs.Colors.background)
    }

    // MARK: - Error View

    func errorView(_ error: ResultsDetailViewErrorState) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(AppFont.displayLight)
                .foregroundColor(.orange)

            Text("Unable to Load Results")
                .font(.title2)
                .fontWeight(.semibold)

            Text(error.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                errorState = nil
            } label: {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 16)
                    .background(Designs.Colors.info)
                    .cornerRadius(Designs.Radius.medium)
            }
            .padding(.top)
        }
        .padding()
    }

    // MARK: - Header Section

    var headerSection: some View {
        VStack(spacing: Designs.Spacing.sm) {
            Text(session.relativeDate)
                .font(AppFont.headlineSecondary)
                .foregroundColor(Designs.Colors.textPrimary)

            Text(session.formattedDate)
                .font(AppFont.caption)
                .foregroundColor(Designs.Colors.textSecondary)

            Text(session.deviceModel)
                .font(AppFont.caption)
                .foregroundColor(Designs.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(Designs.Spacing.lg)
        .background(Designs.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
        .shadow(
            color: Designs.Shadows.card.color,
            radius: Designs.Shadows.card.radius,
            x: Designs.Shadows.card.x,
            y: Designs.Shadows.card.y
        )
    }

    // MARK: - Image Section

    var imageSection: some View {
        VStack(spacing: Designs.Spacing.md) {
            // Heatmap Selector
            heatmapPicker

            // Image Display
            heatmapImageView
                .frame(height: Designs.Sizes.displayHeight)
                .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))

            // Original/Heatmap Toggle
            HStack {
                Text("Show Original")
                    .font(AppFont.bodySecondary)
                    .foregroundColor(Designs.Colors.textSecondary)
                Spacer()
                Toggle("", isOn: $showingOriginal)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
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

    var heatmapPicker: some View {
        AppleGlassSegmentedPicker(
            selection: $selectedHeatmap,
            options: HeatmapType.allCases
        ) { type in
            Text(type.displayName)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    var heatmapImageView: some View {
        if showingOriginal {
            // Try thumbnail first, fallback to full face image
            if let thumbnail = session.thumbnailImage {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .id("original-\(session.id)")
            } else if let faceImage = session.faceUIImage {
                // Fallback to full face image for older scans
                Image(uiImage: faceImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .id("face-\(session.id)")
            } else {
                placeholderImage
            }
        } else {
            if let heatmapImage = selectedHeatmap.image(from: session) {
                Image(uiImage: heatmapImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .id("heatmap-\(selectedHeatmap.rawValue)-\(session.id)")
            } else {
                // Show original image as fallback when heatmap not available
                if let thumbnail = session.thumbnailImage {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .id("fallback-thumbnail-\(session.id)")
                } else if let faceImage = session.faceUIImage {
                    Image(uiImage: faceImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .id("fallback-face-\(session.id)")
                } else {
                    placeholderImage
                        .id("placeholder-\(selectedHeatmap.rawValue)")
                }
            }
        }
    }

    var placeholderImage: some View {
        Rectangle()
            .fill(Designs.Colors.cardBackground)
            .overlay {
                VStack(spacing: Designs.Spacing.sm) {
                    Image(systemName: "face.smiling")
                        .font(.largeTitle)
                        .foregroundColor(Designs.Colors.textTertiary)
                    Text("No image available")
                        .font(.caption)
                        .foregroundColor(Designs.Colors.textTertiary)
                }
            }
    }

    // MARK: - Overall Score Card

    private var scoreGradient: LinearGradient {
        switch session.overallScore {
        case 80...100: return Designs.Colors.mintGradient
        case 60..<80: return Designs.Colors.warmGradient
        default: return Designs.Colors.peachGradient
        }
    }

    private var scoreInterpretation: String {
        switch session.overallScore {
        case 90...100: return "Your skin health is outstanding. Keep up your excellent routine."
        case 80..<90: return "Your skin health is in great shape. Continue your current routine."
        case 70..<80: return "You're making good progress. Follow recommendations for improvement."
        case 60..<70: return "Your skin health is fair. Implement the suggested actions."
        case 50..<60: return "There's room for improvement. Follow the action plan."
        default: return "Let's work together to improve your skin health."
        }
    }

    var overallScoreCard: some View {
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
                            .trim(from: 0, to: session.overallScore / 100)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: Designs.Sizes.scoreCircleLarge, height: Designs.Sizes.scoreCircleLarge)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 4) {
                            Text("\(Int(session.overallScore))")
                                .font(.scoreFont(size: 64))
                                .foregroundColor(.white)

                            Text("/ 100")
                                .font(AppFont.caption)
                                .foregroundColor(.white.opacity(Designs.Opacity.almostOpaque))
                        }
                    }

                    Text("Your Skin Health Score")
                        .font(.app(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(Designs.Opacity.almostOpaque))
                }
            }

            // Grade and description section
            VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Grade")
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textSecondary)

                        Text(session.grade.rawValue)
                            .font(.scoreFont(size: 32))
                            .foregroundColor(scoreColorForOverall)
                    }

                    Spacer()

                    Text(session.grade.description)
                        .font(AppFont.bodySecondary)
                        .foregroundColor(Designs.Colors.textSecondary)
                }

                Text(scoreInterpretation)
                    .font(AppFont.bodyMedium)
                    .foregroundColor(Designs.Colors.textPrimary)
                    .lineSpacing(4)
            }
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

    private var scoreColorForOverall: Color {
        switch session.overallScore {
        case 80...100: return Designs.ScoreColors.excellent
        case 60..<80: return Designs.ScoreColors.fair
        default: return Designs.ScoreColors.poor
        }
    }

    // MARK: - Metrics Grid

    var metricsGrid: some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.lg) {
            Text("Key Metrics")
                .font(AppFont.sectionHeader)
                .foregroundColor(Designs.Colors.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Designs.Spacing.md) {
                // Use enhanced cards with confidence if available
                if let metrics = clinicalMetrics {
                    // ===== CORE 5 METRICS (IN OVERALL SCORE) =====

                    // 1. SMOOTHNESS (22.4%) - RENAMED FROM "SHARPNESS"
                    ResultsMetricCardWithConfidence(
                        title: "Smoothness",
                        value: session.blurQuality,
                        confidence: Double(metrics.smoothnessConfidence),
                        icon: "waveform.path",
                        isCoreMetric: true
                    )

                    // 2. PIGMENTATION (22.4%)
                    ResultsMetricCardWithConfidence(
                        title: "Pigmentation",
                        value: session.pigmentationAvg,
                        confidence: Double(metrics.pigmentationConfidence),
                        icon: "paintpalette",
                        isCoreMetric: true
                    )

                    // 3. PORES (14.9%) - NEW CARD
                    if let pores = metrics.poreAnalysis {
                        ResultsMetricCardWithConfidence(
                            title: "Pores",
                            value: Double(pores.visibilityScore),
                            confidence: Double(pores.confidence),
                            icon: "circle.grid.cross.fill",
                            isCoreMetric: true
                        )
                    }

                    // 4. DISCOLORATION (14.9%)
                    ResultsMetricCardWithConfidence(
                        title: "Discoloration",
                        value: session.discolorationIndex,
                        confidence: Double(metrics.discolorationConfidence),
                        icon: "circle.lefthalf.filled",
                        isCoreMetric: true
                    )

                    // 5. ACNE (14.9%) - NEW CARD
                    if let acne = metrics.acneAnalysis {
                        ResultsMetricCardWithConfidence(
                            title: "Acne",
                            value: Double(acne.overallScore),
                            confidence: Double(acne.confidence),
                            icon: "allergens",
                            isCoreMetric: true
                        )
                    }

                    // ===== ADDITIONAL INDICATORS (NOT IN OVERALL SCORE) =====

                    // Glow (Composite Health Index)
                    if let glowAnalysis = metrics.glowAnalysis {
                        ResultsMetricCardWithConfidence(
                            title: "Skin Health",
                            value: Double(glowAnalysis.skinHealthScore),
                            confidence: Double(glowAnalysis.confidence),
                            icon: "sparkles",
                            isCoreMetric: false
                        )
                    }

                    // Radiance (Luminosity)
                    if let glowAnalysis = metrics.glowAnalysis {
                        ResultsMetricCardWithConfidence(
                            title: "Radiance",
                            value: Double(glowAnalysis.radianceScore),
                            confidence: Double(glowAnalysis.confidence),
                            icon: "sun.max",
                            isCoreMetric: false
                        )
                    }

                    // Hydration (Proxy Method)
                    ResultsMetricCardWithConfidence(
                        title: "Hydration",
                        value: session.moistureSpecular,
                        confidence: Double(metrics.hydrationConfidence),
                        icon: "drop",
                        isCoreMetric: false
                    )

                    // Redness (if available)
                    if let redness = metrics.rednessAnalysis {
                        ResultsMetricCardWithConfidence(
                            title: "Redness",
                            value: Double(redness.overallScore),
                            confidence: Double(redness.confidence),
                            icon: "flame.fill",
                            isCoreMetric: false
                        )
                    }

                    // Oil Control (if available)
                    if let oilScore = metrics.globalSpecularScore {
                        ResultsMetricCardWithConfidence(
                            title: "Oil Control",
                            value: Double(oilScore),
                            confidence: 70.0,
                            icon: "sparkles",
                            isCoreMetric: false
                        )
                    }

                    // Wrinkles (categorical)
                    if let wrinkleAnalysis = metrics.wrinkleAnalysis {
                        CategoricalMetricCard(
                            title: "Wrinkle Depth",
                            category: wrinkleAnalysis.wrinkleDepth.rawValue,
                            confidence: Double(wrinkleAnalysis.confidence),
                            icon: "waveform.path",
                            color: wrinkleColor(for: wrinkleAnalysis.wrinkleDepth)
                        )
                    }
                } else {
                    // Fallback to basic cards if no clinical metrics
                    ResultsMetricCard(title: "Smoothness", value: session.blurQuality, icon: "waveform.path")
                    ResultsMetricCard(title: "Pigmentation", value: session.pigmentationAvg, icon: "paintpalette")
                    ResultsMetricCard(title: "Discoloration", value: session.discolorationIndex, icon: "circle.lefthalf.filled")
                    ResultsMetricCard(title: "Hydration", value: session.moistureSpecular, icon: "drop")
                }
            }

            // Explanatory text
            if clinicalMetrics != nil {
                Text("Metrics with CORE badge are included in your Overall Score calculation.")
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
                    .padding(.top, Designs.Spacing.sm)
            }
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

    func wrinkleColor(for depth: WrinkleDepth) -> Color {
        switch depth {
        case .fine: return Designs.ScoreColors.excellent     // Green
        case .moderate: return Designs.ScoreColors.fair      // Yellow
        case .deep: return Designs.ScoreColors.poor          // Red
        }
    }

    // MARK: - Glow vs Radiance Breakdown

    func glowRadianceBreakdown(_ analysis: GlowAnalysis) -> some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.lg) {
            Text("Glow vs Radiance Analysis")
                .font(AppFont.sectionHeader)
                .foregroundColor(Designs.Colors.textPrimary)

            Text("Understanding the difference between your skin's overall health and pure luminosity.")
                .font(AppFont.caption)
                .foregroundColor(Designs.Colors.textSecondary)

            // Side-by-side comparison
            HStack(spacing: Designs.Spacing.md) {
                // Glow (Health Index)
                VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Designs.Colors.success.opacity(Designs.Opacity.veryLight))
                                .frame(width: Designs.Sizes.iconSmall, height: Designs.Sizes.iconSmall)
                            Image(systemName: "sparkles")
                                .foregroundColor(Designs.Colors.success)
                                .font(AppFont.footnote)
                        }
                        Text("Glow (Health)")
                            .font(AppFont.subheadingPrimary)
                            .foregroundColor(Designs.Colors.textPrimary)
                    }

                    Text("\(Int(analysis.skinHealthScore))/100")
                        .font(AppFont.title2)
                        .foregroundColor(scoreColorFor(analysis.skinHealthScore))

                    Text("Overall health index")
                        .font(AppFont.footnote)
                        .foregroundColor(Designs.Colors.textSecondary)

                    Divider()
                        .background(Designs.Colors.border)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Components:")
                            .font(AppFont.footnote)
                            .foregroundColor(Designs.Colors.textSecondary)

                        HStack {
                            Text("Smoothness")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(analysis.smoothnessContribution))")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textTertiary)
                        }

                        HStack {
                            Text("Evenness")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(analysis.evennessContribution))")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textTertiary)
                        }

                        HStack {
                            Text("Discoloration")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(analysis.discolorationContribution))")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textTertiary)
                        }

                        HStack {
                            Text("Specular")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(analysis.specularContribution))")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textTertiary)
                        }
                    }
                }
                .padding(Designs.Spacing.md)
                .background(Designs.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))

                // Radiance (Luminosity)
                VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Designs.Colors.warning.opacity(Designs.Opacity.veryLight))
                                .frame(width: Designs.Sizes.iconSmall, height: Designs.Sizes.iconSmall)
                            Image(systemName: "sun.max")
                                .foregroundColor(Designs.Colors.warning)
                                .font(AppFont.footnote)
                        }
                        Text("Radiance")
                            .font(AppFont.subheadingPrimary)
                            .foregroundColor(Designs.Colors.textPrimary)
                    }

                    Text("\(Int(analysis.radianceScore))/100")
                        .font(AppFont.title2)
                        .foregroundColor(scoreColorFor(analysis.radianceScore))

                    Text("Pure luminosity")
                        .font(AppFont.footnote)
                        .foregroundColor(Designs.Colors.textSecondary)

                    Divider()
                        .background(Designs.Colors.border)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Components:")
                            .font(AppFont.footnote)
                            .foregroundColor(Designs.Colors.textSecondary)

                        HStack {
                            Text("LAB L* Lightness")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(analysis.labLightness * 100))")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textTertiary)
                        }

                        HStack {
                            Text("Specular Highlights")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(analysis.specularHighlightRatio * 100))")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textTertiary)
                        }

                        HStack {
                            Text("Luminosity Index")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(analysis.luminosityIndex))")
                                .font(AppFont.footnote)
                                .foregroundColor(Designs.Colors.textTertiary)
                        }
                    }
                }
                .padding(Designs.Spacing.md)
                .background(Designs.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
            }

            // Explanation
            HStack(alignment: .top, spacing: Designs.Spacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.warning)
                Text("**Glow** measures overall skin health (texture + tone + shine), while **Radiance** measures how much light your skin reflects (physics-based brightness).")
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
            }
            .padding(Designs.Spacing.md)
            .background(Designs.Colors.warning.opacity(Designs.Opacity.veryLight))
            .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
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

    /// Helper function to get score-based color
    private func scoreColorFor(_ value: Float) -> Color {
        switch value {
        case 80...100: return Designs.ScoreColors.excellent  // Green
        case 60..<80: return Designs.ScoreColors.fair        // Yellow
        default: return Designs.ScoreColors.poor             // Red
        }
    }

    /// Reusable clinical metric row with simplified colors
    @ViewBuilder
    private func clinicalMetricRow(icon: String, title: String, score: Int, confidence: Int, weight: String, extraInfo: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Designs.Colors.textSecondary)
                Text(title)
                    .font(.headline)
                    .foregroundColor(Designs.Colors.textPrimary)
            }

            HStack {
                Text("Score:")
                    .font(.subheadline)
                    .foregroundColor(Designs.Colors.textSecondary)
                Text("\(score)/100")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Designs.Colors.scoreColor(for: score))
                Spacer()
                Text("\(confidence)%")
                    .font(.caption)
                    .foregroundColor(Designs.Colors.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Designs.Colors.border.opacity(0.3))
                    .cornerRadius(Designs.Radius.small)
            }

            Text("Weight in Overall Score: \(weight)")
                .font(.caption)
                .foregroundColor(Designs.Colors.textSecondary)

            if let extra = extraInfo {
                Text(extra)
                    .font(.caption)
                    .foregroundColor(Designs.Colors.textTertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Designs.Colors.cardBackground)
        .cornerRadius(Designs.Radius.medium)
    }

    /// Reusable additional indicator row (not in overall score)
    @ViewBuilder
    private func additionalIndicatorRow(icon: String, title: String, score: Int?, confidence: Int?, info: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Designs.Colors.textSecondary)
                Text(title)
                    .font(.headline)
                    .foregroundColor(Designs.Colors.textPrimary)
            }

            if let score = score {
                HStack {
                    Text("Score:")
                        .font(.subheadline)
                        .foregroundColor(Designs.Colors.textSecondary)
                    Text("\(score)/100")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Designs.Colors.scoreColor(for: score))
                }
            }

            Text(info)
                .font(.caption)
                .foregroundColor(Designs.Colors.textSecondary)

            if let confidence = confidence {
                Text("\(confidence)% confidence")
                    .font(.caption)
                    .foregroundColor(Designs.Colors.textTertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Designs.Colors.cardBackground)
        .cornerRadius(Designs.Radius.medium)
    }

    // MARK: - Full Clinical Breakdown

    /// Calculate hydration score from ROI metrics
    func calculateHydrationScore(from metrics: Face3DMetrics) -> Float {
        let moistureValues = metrics.roiMetrics.values.map { $0.moistureProxy.moistureIndex }
        guard !moistureValues.isEmpty else { return 0 }
        let avgMoisture = moistureValues.reduce(0, +) / Double(moistureValues.count)
        return Float(avgMoisture * 100)  // Convert 0-1 to 0-100 score
    }

    @ViewBuilder
    func fullClinicalBreakdown(_ metrics: Face3DMetrics) -> some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.lg) {
            // MARK: - Debug Section (Collapsible - Smoothness to Redness)
            DisclosureGroup(
                isExpanded: $isDebugSectionExpanded,
                content: {
                    VStack(alignment: .leading, spacing: Designs.Spacing.lg) {
                        // Skin Health Metrics Header
                        VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                            Text("Skin Health Metrics")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(Designs.Colors.textPrimary)
                                .padding(.top, Designs.Spacing.sm)

                            Text("These high-confidence metrics (70%+ confidence) are included in your Overall Score calculation.")
                                .font(AppFont.caption)
                                .foregroundColor(Designs.Colors.textSecondary)
                        }

                        // 1. Smoothness
                        clinicalMetricRow(
                            icon: "waveform.path",
                            title: "Smoothness",
                            score: Int(metrics.globalRoughnessScore),
                            confidence: Int(metrics.smoothnessConfidence),
                            weight: "22.4%"
                        )

                        // 2. Pigmentation
                        clinicalMetricRow(
                            icon: "paintpalette",
                            title: "Pigmentation",
                            score: Int(metrics.globalPigmentationScore),
                            confidence: Int(metrics.pigmentationConfidence),
                            weight: "22.4%"
                        )

                        // 3. Pores
                        if let pores = metrics.poreAnalysis {
                            clinicalMetricRow(
                                icon: "circle.grid.cross.fill",
                                title: "Pores",
                                score: Int(pores.visibilityScore),
                                confidence: Int(pores.confidence),
                                weight: "14.9%",
                                extraInfo: "Dominant Size: \(pores.dominantSize.rawValue) • Density: \(String(format: "%.1f", pores.density)) pores/cm²"
                            )
                        }

                        // 4. Discoloration
                        clinicalMetricRow(
                            icon: "circle.lefthalf.filled",
                            title: "Discoloration",
                            score: Int(metrics.globalDiscolorationScore),
                            confidence: Int(metrics.discolorationConfidence),
                            weight: "14.9%"
                        )

                        // 5. Acne
                        if let acne = metrics.acneAnalysis {
                            clinicalMetricRow(
                                icon: "allergens",
                                title: "Acne",
                                score: Int(acne.overallScore),
                                confidence: Int(acne.confidence),
                                weight: "14.9%",
                                extraInfo: acne.blemishes.isEmpty ? nil : "Detected: \(acne.blemishes.count) blemishes • Severity: \(acne.severity.rawValue)"
                            )
                        }

                        Divider()
                            .padding(.vertical, Designs.Spacing.sm)

                        // Additional Indicators Header
                        VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                            Text("Additional Indicators")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(Designs.Colors.textPrimary)

                            Text("These metrics provide supplementary insights but aren't included in the Overall Score.")
                                .font(AppFont.caption)
                                .foregroundColor(Designs.Colors.textSecondary)
                        }

                        // Elasticity
                        if let elasticity = metrics.elasticityAnalysis {
                            additionalIndicatorRow(
                                icon: "arrow.clockwise",
                                title: "Elasticity",
                                score: Int(elasticity.overallScore),
                                confidence: elasticity.isTemporal ? Int(elasticity.confidence) : nil,
                                info: "Level: \(elasticity.elasticityLevel.rawValue) • Recovery Rate: \(String(format: "%.2f", elasticity.recoveryRate))"
                            )
                        } else {
                            additionalIndicatorRow(
                                icon: "arrow.clockwise",
                                title: "Elasticity",
                                score: nil,
                                confidence: nil,
                                info: "Requires 2+ scans for temporal analysis"
                            )
                        }

                        // Hydration
                        additionalIndicatorRow(
                            icon: "drop.fill",
                            title: "Hydration",
                            score: Int(calculateHydrationScore(from: metrics)),
                            confidence: Int(metrics.hydrationConfidence),
                            info: "Proxy method based on surface properties"
                        )

                        // Redness
                        if let redness = metrics.rednessAnalysis {
                            additionalIndicatorRow(
                                icon: "flame.fill",
                                title: "Redness",
                                score: Int(redness.overallScore),
                                confidence: Int(redness.confidence),
                                info: "Level: \(redness.rednessLevel.rawValue)"
                            )
                        }

                        // Oil Control
                        if let oilScore = metrics.globalSpecularScore {
                            additionalIndicatorRow(
                                icon: "sparkles",
                                title: "Oil Control",
                                score: Int(oilScore),
                                confidence: nil,
                                info: "Sebum management and shine control"
                            )
                        }
                    }
                },
                label: {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Designs.Colors.textSecondary.opacity(Designs.Opacity.veryLight))
                                .frame(width: Designs.Sizes.iconSmall, height: Designs.Sizes.iconSmall)
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(Designs.Colors.textSecondary)
                                .font(AppFont.footnote)
                        }
                        Text("Debug")
                            .font(AppFont.headlineSecondary)
                            .foregroundColor(Designs.Colors.textPrimary)
                        Spacer()
                    }
                }
            )
            .padding(Designs.Spacing.lg)
            .background(Designs.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))

            // MARK: - Clinical Data (Collapsible - Sun Damage to Scan Quality)
            DisclosureGroup(
                isExpanded: $isClinicalDataExpanded,
                content: {
                    VStack(alignment: .leading, spacing: Designs.Spacing.lg) {
                        // Sun Damage Analysis
                        if let sunDamage = metrics.sunDamageAnalysis {
                            VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange.opacity(Designs.Opacity.veryLight))
                                            .frame(width: Designs.Sizes.iconSmall, height: Designs.Sizes.iconSmall)
                                        Image(systemName: "sun.max.fill")
                                            .foregroundColor(.orange)
                                            .font(AppFont.footnote)
                                    }
                                    Text("Sun Damage Analysis")
                                        .font(AppFont.subheadingPrimary)
                                        .foregroundColor(Designs.Colors.textPrimary)
                                }

                                Text("Protection Score: \(Int(sunDamage.protectionScore))/100")
                                    .font(AppFont.bodySecondary)
                                    .foregroundColor(Designs.Colors.textSecondary)

                                Text("Damage Level: \(sunDamage.damageLevel.rawValue)")
                                    .font(AppFont.bodySecondary)
                                    .foregroundColor(Designs.Colors.textSecondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("• Pigmentation Health: \(Int(sunDamage.pigmentationHealth))%")
                                    Text("• Photoaging Resistance: \(Int(sunDamage.photoagingResistance))%")
                                    Text("• Texture Health: \(Int(sunDamage.textureHealth))%")
                                    Text("• Vascular Health: \(Int(sunDamage.vascularHealth))%")
                                    Text("• Pore Health: \(Int(sunDamage.poreHealth))%")
                                }
                                .font(AppFont.caption)
                                .foregroundColor(Designs.Colors.textSecondary)
                            }
                            .padding(Designs.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Designs.Colors.background)
                            .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.sm))
                        }

                        // Redness Analysis
                        if let redness = metrics.rednessAnalysis {
                            VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.pink.opacity(Designs.Opacity.veryLight))
                                            .frame(width: Designs.Sizes.iconSmall, height: Designs.Sizes.iconSmall)
                                        Image(systemName: "flame.fill")
                                            .foregroundColor(.pink)
                                            .font(AppFont.footnote)
                                    }
                                    Text("Redness Analysis")
                                        .font(AppFont.subheadingPrimary)
                                        .foregroundColor(Designs.Colors.textPrimary)
                                }

                                Text("Overall Score: \(Int(redness.overallScore))/100")
                                    .font(AppFont.bodySecondary)
                                    .foregroundColor(Designs.Colors.textSecondary)

                                Text("Level: \(redness.rednessLevel.rawValue)")
                                    .font(AppFont.bodySecondary)
                                    .foregroundColor(Designs.Colors.textSecondary)

                                Text("Confidence: \(Int(redness.confidence))%")
                                    .font(AppFont.caption)
                                    .foregroundColor(Designs.Colors.textTertiary)
                            }
                            .padding(Designs.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Designs.Colors.background)
                            .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.sm))
                        }

                        // Wrinkle Analysis
                        if let wrinkles = metrics.wrinkleAnalysis {
                            VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.purple.opacity(Designs.Opacity.veryLight))
                                            .frame(width: Designs.Sizes.iconSmall, height: Designs.Sizes.iconSmall)
                                        Image(systemName: "waveform.path")
                                            .foregroundColor(.purple)
                                            .font(AppFont.footnote)
                                    }
                                    Text("Wrinkle Analysis")
                                        .font(AppFont.subheadingPrimary)
                                        .foregroundColor(Designs.Colors.textPrimary)
                                }

                                Text("Overall Score: \(Int(wrinkles.overallScore))/100")
                                    .font(AppFont.bodySecondary)
                                    .foregroundColor(Designs.Colors.textSecondary)

                                Text("Wrinkle Depth: \(wrinkles.wrinkleDepth.rawValue)")
                                    .font(AppFont.bodySecondary)
                                    .foregroundColor(Designs.Colors.textSecondary)

                                Text("Wrinkle Count: \(wrinkles.wrinkleCount) regions")
                                    .font(AppFont.bodySecondary)
                                    .foregroundColor(Designs.Colors.textSecondary)

                                if !wrinkles.regionalScores.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(wrinkles.regionalScores.keys.sorted(), id: \.self) { region in
                                            if let score = wrinkles.regionalScores[region] {
                                                Text("• \(region.capitalized): \(Int(score))/100")
                                            }
                                        }
                                    }
                                    .font(AppFont.caption)
                                    .foregroundColor(Designs.Colors.textSecondary)
                                }

                                Text("Confidence: \(Int(wrinkles.confidence))%")
                                    .font(AppFont.caption)
                                    .foregroundColor(Designs.Colors.textTertiary)
                            }
                            .padding(Designs.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Designs.Colors.background)
                            .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.sm))
                        }

                        // Elasticity Analysis
                        if let elasticity = metrics.elasticityAnalysis {
                            VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(Designs.Opacity.veryLight))
                                            .frame(width: Designs.Sizes.iconSmall, height: Designs.Sizes.iconSmall)
                                        Image(systemName: "arrow.clockwise")
                                            .foregroundColor(.blue)
                                            .font(AppFont.footnote)
                                    }
                                    Text("Skin Elasticity")
                                        .font(AppFont.subheadingPrimary)
                                        .foregroundColor(Designs.Colors.textPrimary)
                                }

                                Text("Overall Score: \(Int(elasticity.overallScore))/100")
                                    .font(AppFont.bodySecondary)
                                    .foregroundColor(Designs.Colors.textSecondary)

                                Text("Elasticity Level: \(elasticity.elasticityLevel.rawValue)")
                                    .font(AppFont.bodySecondary)
                                    .foregroundColor(Designs.Colors.textSecondary)

                                Text("Recovery Rate: \(String(format: "%.2f", elasticity.recoveryRate))")
                                    .font(AppFont.bodySecondary)
                                    .foregroundColor(Designs.Colors.textSecondary)

                                if !elasticity.regionalElasticity.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(Array(elasticity.regionalElasticity.keys.sorted()), id: \.self) { region in
                                            if let score = elasticity.regionalElasticity[region] {
                                                Text("• \(region.rawValue): \(Int(score))/100")
                                            }
                                        }
                                    }
                                    .font(AppFont.caption)
                                    .foregroundColor(Designs.Colors.textSecondary)
                                }
                            }
                            .padding(Designs.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Designs.Colors.background)
                            .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.sm))
                        }

                        // Volume Analysis
                        if let volume = metrics.volumeAnalysis {
                            VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.cyan.opacity(Designs.Opacity.veryLight))
                                            .frame(width: Designs.Sizes.iconSmall, height: Designs.Sizes.iconSmall)
                                        Image(systemName: "cube.fill")
                                            .foregroundColor(.cyan)
                                            .font(AppFont.footnote)
                                    }
                                    Text("Facial Volume Analysis")
                                        .font(AppFont.subheadingPrimary)
                                        .foregroundColor(Designs.Colors.textPrimary)
                                }

                                Text("Overall Score: \(Int(volume.overallScore))/100")
                                    .font(AppFont.bodySecondary)
                                    .foregroundColor(Designs.Colors.textSecondary)

                                if let cheekHollowing = volume.cheekHollowing {
                                    Text("Cheek: \(cheekHollowing.severity.rawValue) hollowing, \(String(format: "%.1f", cheekHollowing.volumeLoss))% loss")
                                        .font(AppFont.caption)
                                        .foregroundColor(Designs.Colors.textSecondary)
                                }

                                if let underEyeBags = volume.underEyeBags {
                                    Text("Under-Eye: \(underEyeBags.severity.rawValue), \(String(format: "%.2f", underEyeBags.protrusion))mm")
                                        .font(AppFont.caption)
                                        .foregroundColor(Designs.Colors.textSecondary)
                                }

                                if let facialSymmetry = volume.facialSymmetry {
                                    Text("Symmetry: \(Int(facialSymmetry.score))/100, \(String(format: "%.2f", facialSymmetry.leftRightDeviation))mm deviation")
                                        .font(AppFont.caption)
                                        .foregroundColor(Designs.Colors.textSecondary)
                                }
                            }
                            .padding(Designs.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Designs.Colors.background)
                            .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.sm))
                        }

                        // Topology Analysis (Scan Quality)
                        if let topology = metrics.topologyAnalysis {
                            VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green.opacity(Designs.Opacity.veryLight))
                                            .frame(width: Designs.Sizes.iconSmall, height: Designs.Sizes.iconSmall)
                                        Image(systemName: "view.3d")
                                            .foregroundColor(.green)
                                            .font(AppFont.footnote)
                                    }
                                    Text("Scan Quality")
                                        .font(AppFont.subheadingPrimary)
                                        .foregroundColor(Designs.Colors.textPrimary)
                                }

                                Text("Quality Score: \(String(format: "%.1f", topology.overallScore))/100")
                                    .font(AppFont.bodySecondary)
                                    .foregroundColor(Designs.Colors.textSecondary)

                                Text("Quality Level: \(topology.qualityLevel.rawValue)")
                                    .font(AppFont.bodySecondary)
                                    .foregroundColor(Designs.Colors.textSecondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("• Manifold: \(topology.isManifold ? "Yes" : "No")")
                                    Text("• Watertight: \(topology.isWatertight ? "Yes" : "No")")
                                    Text("• Triangle Quality: \(String(format: "%.2f", topology.triangleQuality.averageAspectRatio))")
                                }
                                .font(AppFont.caption)
                                .foregroundColor(Designs.Colors.textSecondary)
                            }
                            .padding(Designs.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Designs.Colors.background)
                            .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.sm))
                        }
                    }
                    .padding(.top, Designs.Spacing.sm)
                },
                label: {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Designs.Colors.info.opacity(Designs.Opacity.veryLight))
                                .frame(width: Designs.Sizes.iconSmall, height: Designs.Sizes.iconSmall)
                            Image(systemName: "stethoscope")
                                .foregroundColor(Designs.Colors.info)
                                .font(AppFont.footnote)
                        }
                        Text("Clinical Data")
                            .font(AppFont.headlineSecondary)
                            .foregroundColor(Designs.Colors.textPrimary)
                        Spacer()
                    }
                }
            )
            .padding(Designs.Spacing.lg)
            .background(Designs.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
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

    // MARK: - Aging Indicators Section

    @ViewBuilder
    func agingIndicatorsSection(_ metrics: Face3DMetrics) -> some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.lg) {
            VStack(alignment: .leading, spacing: Designs.Spacing.xs) {
                Text("Aging Indicators")
                    .font(AppFont.sectionHeader)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text("Separate from skin health score")
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
            }

            HStack(spacing: Designs.Spacing.md) {
                // Wrinkles Card
                if let wrinkles = metrics.wrinkleAnalysis {
                    VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Designs.GentlerStreak.accentTeal.opacity(Designs.Opacity.veryLight))
                                    .frame(width: Designs.Sizes.iconMedium, height: Designs.Sizes.iconMedium)

                                Image(systemName: "line.3.horizontal.decrease")
                                    .foregroundColor(Designs.GentlerStreak.accentTeal)
                                    .font(AppFont.cardTitle)
                            }

                            Text("Wrinkles")
                                .font(AppFont.subheadingPrimary)
                                .foregroundColor(Designs.Colors.textPrimary)
                        }

                        Text("\(Int(wrinkles.overallScore))")
                            .font(.scoreFont(size: 32))
                            .foregroundColor(scoreColor(for: Double(wrinkles.overallScore)))

                        Text(wrinkles.wrinkleDepth.rawValue)
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textSecondary)

                        Text("\(wrinkles.wrinkleCount) regions")
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Designs.Spacing.lg)
                    .background(Designs.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
                }

                // Volume Card
                if let volume = metrics.volumeAnalysis {
                    VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Designs.GentlerStreak.accentTeal.opacity(Designs.Opacity.veryLight))
                                    .frame(width: Designs.Sizes.iconMedium, height: Designs.Sizes.iconMedium)

                                Image(systemName: "cube.fill")
                                    .foregroundColor(Designs.GentlerStreak.accentTeal)
                                    .font(AppFont.cardTitle)
                            }

                            Text("Volume")
                                .font(AppFont.subheadingPrimary)
                                .foregroundColor(Designs.Colors.textPrimary)
                        }

                        Text("\(Int(volume.overallScore))")
                            .font(.scoreFont(size: 32))
                            .foregroundColor(scoreColor(for: Double(volume.overallScore)))

                        if let cheekHollowing = volume.cheekHollowing {
                            Text("Loss: \(String(format: "%.1f", cheekHollowing.volumeLoss))%")
                                .font(AppFont.caption)
                                .foregroundColor(Designs.Colors.textSecondary)

                            Text("\(cheekHollowing.severity.rawValue) hollowing")
                                .font(AppFont.caption)
                                .foregroundColor(Designs.Colors.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Designs.Spacing.lg)
                    .background(Designs.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
                }
            }
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

    // MARK: - ROI Scores

    var roiScoresSection: some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.lg) {
            Text("Regional Scores")
                .font(AppFont.sectionHeader)
                .foregroundColor(Designs.Colors.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Designs.Spacing.md) {
                RegionalScoreCard(title: "Left Cheek", value: session.leftCheekScore)
                RegionalScoreCard(title: "Right Cheek", value: session.rightCheekScore)
                RegionalScoreCard(title: "Forehead", value: session.foreheadScore)
                RegionalScoreCard(title: "Chin", value: session.chinScore)
            }
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

    // MARK: - Actions Section

    var actionsSection: some View {
        VStack(spacing: Designs.Spacing.md) {
            // Compare with latest button (if this isn't the latest scan)
            if !isLatestScan {
                NavigationLink {
                    if let latestSession = fetchLatestSession() {
                        Comparison3DView(
                            beforeSession: session,
                            afterSession: latestSession
                        )
                    }
                } label: {
                    HStack(spacing: Designs.Spacing.md) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(AppFont.cardTitle)
                        Text("Compare with Latest Scan")
                            .font(AppFont.headlineSecondary)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Designs.Colors.info)
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
                    .shadow(
                        color: Designs.Shadows.button.color,
                        radius: Designs.Shadows.button.radius,
                        x: Designs.Shadows.button.x,
                        y: Designs.Shadows.button.y
                    )
                }
            }

            // Share button
            Button {
                shareResults()
            } label: {
                HStack(spacing: Designs.Spacing.md) {
                    if isPreparingShare {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(AppFont.cardTitle)
                    }
                    Text(isPreparingShare ? "Preparing..." : "Share Results")
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
            .disabled(isPreparingShare)

            // Delete button
            Button {
                showingDeleteAlert = true
            } label: {
                HStack(spacing: Designs.Spacing.md) {
                    Image(systemName: "trash")
                        .font(AppFont.bodyPrimary)
                    Text("Delete Session")
                        .font(AppFont.subheadingPrimary)
                }
                .foregroundColor(Designs.Colors.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Designs.Colors.error.opacity(Designs.Opacity.veryLight))
                .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
            }
        }
    }

    // Helper to check if this is the latest scan
    var isLatestScan: Bool {
        let request = SessionResult.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)]
        request.fetchLimit = 1

        guard let latestSession = try? viewContext.fetch(request).first else {
            return false
        }

        return latestSession.id == session.id
    }

    // Helper to fetch the latest session
    func fetchLatestSession() -> SessionResult? {
        let request = SessionResult.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)]
        request.fetchLimit = 1

        return try? viewContext.fetch(request).first
    }

    // MARK: - Actions

    func shareResults() {
        Task {
            await performShare()
        }
    }

    func performShare() async {
        // Set loading state
        await MainActor.run {
            isPreparingShare = true
        }

        // Generate share content
        var itemsToShare: [Any] = []

        // 1. Generate summary text with top 3 metrics
        let shareText = generateShareText()
        itemsToShare.append(shareText)

        // 2. Add PDF report if we have clinical metrics
        if let pdfData = await generatePDFReport() {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Tavi_Analysis_\(session.date.formatted(date: .abbreviated, time: .omitted)).pdf")
            try? pdfData.write(to: tempURL)
            itemsToShare.append(tempURL)
        }

        // 3. Add heatmap image if available
        if let heatmapImage = session.thumbnailImage {
            itemsToShare.append(heatmapImage)
        }

        // Present native iOS share sheet on main actor
        await MainActor.run {
            isPreparingShare = false
            let activityVC = UIActivityViewController(
                activityItems: itemsToShare,
                applicationActivities: nil
            )

            // For iPad support
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = rootVC.view
                    popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                rootVC.present(activityVC, animated: true)
            }
        }
    }

    func generateShareText() -> String {
        // Get top 3 metrics
        let metrics: [(name: String, value: Double)] = [
            ("Overall Health", session.overallScore),
            ("Texture Quality", session.textureAvg),
            ("Pigmentation", session.pigmentationAvg),
            ("Moisture", session.moistureSpecular),
            ("Sharpness", session.blurQuality)
        ]

        let topMetrics = metrics.sorted { $0.value > $1.value }.prefix(3)

        var text = "Tavi Skin Analysis Results\n"
        text += "Date: \(session.formattedDate)\n\n"
        text += "Overall Score: \(Int(session.overallScore))/100 (\(session.grade.rawValue))\n\n"
        text += "Top Metrics:\n"

        for (index, metric) in topMetrics.enumerated() {
            let prefix = ["1.", "2.", "3."][index]
            text += "\(prefix) \(metric.name): \(Int(metric.value))%\n"
        }

        text += "\nAnalyzed with Tavi - 3D Skin Analysis"

        return text
    }

    func generatePDFReport() async -> Data? {
        // Set loading state
        await MainActor.run {
            isGeneratingPDF = true
        }

        defer {
            Task { @MainActor in
                isGeneratingPDF = false
            }
        }

        // Only generate PDF if we have clinical metrics
        guard let metricsData = session.clinicalMetricsData else {
            return nil
        }

        // Load metrics with versioned loader
        let result = VersionedMetricsLoader.loadFace3DMetrics(from: metricsData)
        guard let metrics = result.metrics else {
            AppLogger.ui.error("Failed to load clinical metrics for PDF generation: \(result.userMessage)")
            CrashReporter.shared.logError(
                NSError(domain: "ResultsDetailView", code: -1, userInfo: ["message": result.userMessage]),
                context: ["operation": "versioned_load_clinical_pdf"]
            )
            return nil
        }

        // Generate interpreted results for the report
        let interpretedResults = InterpretedResults.from(metrics: metrics)

        // Ensure we have scan quality data
        guard let scanQuality = metrics.scanQuality else {
            return nil
        }

        // Generate PDF report
        let generator = PDFReportGenerator()
        guard let pdfURL = await generator.generateReport(
            scan: metrics,
            interpretedResults: interpretedResults,
            scanQuality: scanQuality,
            userProfile: nil,  // Optional - could load from UserProfile
            recommendations: nil  // Optional - could generate from PersonalizedRecommendationEngine
        ) else {
            return nil
        }

        // Convert URL to Data
        return try? Data(contentsOf: pdfURL)
    }

    func deleteSession() {
        viewContext.delete(session)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            handleError(error, context: "deleting session")
            // Still dismiss even on error - delete was queued
            dismiss()
        }
    }

    // MARK: - Error Handling

    func handleError(_ error: Error, context: String) {
        AppLogger.ui.error("ResultsDetailView error (\(context)): \(error)")
        CrashReporter.shared.logError(error, context: ["view": "ResultsDetailView", "operation": context])
        errorState = ResultsDetailViewErrorState(
            message: "Unable to \(context). Please try again.",
            error: error
        )
    }

    // MARK: - Helpers

    func scoreColor(for score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    func gradeColor(for grade: ScoreGrade) -> Color {
        switch grade {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor, .veryPoor: return .red
        }
    }
}

// MARK: - Error State

struct ResultsDetailViewErrorState {
    let message: String
    let error: Error
}

// MARK: - Metric Card (Light card style matching Wrinkles/Volume cards)

struct ResultsMetricCard: View {

    let title: String
    let value: Double
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Designs.GentlerStreak.accentTeal.opacity(Designs.Opacity.veryLight))
                        .frame(width: Designs.Sizes.iconMedium, height: Designs.Sizes.iconMedium)

                    Image(systemName: icon)
                        .foregroundColor(Designs.GentlerStreak.accentTeal)
                        .font(AppFont.cardTitle)
                }

                Text(title)
                    .font(AppFont.subheadingPrimary)
                    .foregroundColor(Designs.Colors.textPrimary)
            }

            Text("\(Int(value))")
                .font(.scoreFont(size: 32))
                .foregroundColor(scoreColor)

            Text(scoreDescription)
                .font(AppFont.caption)
                .foregroundColor(Designs.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .padding(Designs.Spacing.lg)
        .background(Designs.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
    }

    var scoreColor: Color {
        switch value {
        case 80...100: return Designs.ScoreColors.excellent  // Green
        case 60..<80: return Designs.ScoreColors.fair        // Yellow
        default: return Designs.ScoreColors.poor             // Red
        }
    }

    var scoreDescription: String {
        switch value {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        default: return "Needs attention"
        }
    }
}

// MARK: - Enhanced Metric Card with Confidence (Light card style matching Wrinkles/Volume)

struct ResultsMetricCardWithConfidence: View {

    let title: String
    let value: Double
    let confidence: Double  // 0-100
    let icon: String
    let unit: String?  // Optional unit (%, categorical value, etc.)
    var isCoreMetric: Bool = false  // Badge for core metrics

    init(title: String, value: Double, confidence: Double, icon: String, unit: String? = "%", isCoreMetric: Bool = false) {
        self.title = title
        self.value = value
        self.confidence = confidence
        self.icon = icon
        self.unit = unit
        self.isCoreMetric = isCoreMetric
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(Designs.Opacity.veryLight))
                            .frame(width: Designs.Sizes.iconMedium, height: Designs.Sizes.iconMedium)

                        Image(systemName: icon)
                            .foregroundColor(iconColor)
                            .font(AppFont.cardTitle)
                    }

                    Text(title)
                        .font(AppFont.subheadingPrimary)
                        .foregroundColor(Designs.Colors.textPrimary)
                }

                if unit != nil {
                    Text("\(Int(value))")
                        .font(.scoreFont(size: 32))
                        .foregroundColor(scoreColor)
                } else {
                    Text(displayValue)
                        .font(.scoreFont(size: 28))
                        .foregroundColor(scoreColor)
                }

                Text(scoreDescription)
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.textSecondary)

                // Confidence indicator
                HStack(spacing: 4) {
                    Text("\(Int(confidence))% confidence")
                        .font(AppFont.footnote)
                        .foregroundColor(Designs.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .padding(Designs.Spacing.lg)
            .background(Designs.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))

            // Core metric badge overlay
            if isCoreMetric {
                Text("CORE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Designs.GentlerStreak.accentCoral)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(Designs.Spacing.sm)
            }
        }
    }

    var displayValue: String {
        return "\(Int(value))"
    }

    var iconColor: Color {
        // Unified icon color for clean, professional look
        Designs.GentlerStreak.accentTeal
    }

    var scoreColor: Color {
        switch value {
        case 80...100: return Designs.ScoreColors.excellent  // Green
        case 60..<80: return Designs.ScoreColors.fair        // Yellow
        default: return Designs.ScoreColors.poor             // Red
        }
    }

    var scoreDescription: String {
        switch value {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        default: return "Needs attention"
        }
    }
}

// MARK: - Categorical Metric Card (Light card style matching Wrinkles/Volume)

struct CategoricalMetricCard: View {

    let title: String
    let category: String  // e.g., "Fine Lines", "Moderate", "Deep"
    let confidence: Double  // 0-100
    let icon: String
    let color: Color  // Score-based color for the category value

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Designs.GentlerStreak.accentTeal)  // Unified icon color
                    .font(.title3)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Text(category)
                .font(.scoreFont(size: 24))
                .foregroundColor(color)  // Keep score-based color for text

            Text("\(Int(confidence))% confidence")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(Designs.Radius.medium)
    }
}

// MARK: - Regional Score Card (Fixed height for uniform sizing)

struct RegionalScoreCard: View {

    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForRegion)
                    .foregroundColor(colorForRegion)
                    .font(.title3)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Spacer()

            Text("\(Int(value))")
                .font(.scoreFont(size: 32))
                .foregroundColor(scoreColor)

            Text(scoreDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 110) // Fixed height for uniform cards
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(Designs.Radius.medium)
    }

    var iconForRegion: String {
        switch title.lowercased() {
        case "left cheek": return "chevron.left"
        case "right cheek": return "chevron.right"
        case "forehead": return "arrow.up"
        case "chin": return "arrow.down"
        default: return "face.smiling"
        }
    }

    var colorForRegion: Color {
        // Unified icon color for clean, professional look
        Designs.GentlerStreak.accentTeal
    }

    var scoreColor: Color {
        switch value {
        case 80...100: return Designs.ScoreColors.excellent
        case 60..<80: return Designs.ScoreColors.fair
        default: return Designs.ScoreColors.poor
        }
    }

    var scoreDescription: String {
        switch value {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        default: return "Needs attention"
        }
    }
}

// MARK: - Heatmap Type Extension

// Note: HeatmapType is defined in AnalysisTypes.swift

extension HeatmapType {
    func image(from session: SessionResult) -> UIImage? {
        switch self {
        case .composite:
            guard let data = session.heatmapComposite else { return nil }
            return UIImage(data: data)
        case .sharpness:
            guard let data = session.heatmapSharpness else { return nil }
            return UIImage(data: data)
        case .texture:
            guard let data = session.heatmapTexture else { return nil }
            return UIImage(data: data)
        case .pigmentation:
            guard let data = session.heatmapPigmentation else { return nil }
            return UIImage(data: data)
        case .moisture:
            guard let data = session.heatmapMoisture else { return nil }
            return UIImage(data: data)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        if let session = try? PersistenceController.preview.fetchRecentSessions(limit: 1).first {
            ResultsDetailView(session: session)
                .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
        }
    }
}
