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
        ScrollView {
            VStack(spacing: 24) {
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
            }
            .padding()
        }
    }

    // MARK: - Error View

    func errorView(_ error: ResultsDetailViewErrorState) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
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
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top)
        }
        .padding()
    }

    // MARK: - Header Section

    var headerSection: some View {
        VStack(spacing: 8) {
            Text(session.relativeDate)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(session.formattedDate)
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(session.deviceModel)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Image Section

    var imageSection: some View {
        CardView {
            VStack(spacing: 12) {
                // Heatmap Selector
                heatmapPicker

                // Image Display
                heatmapImageView
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Original/Heatmap Toggle
                Toggle("Show Original", isOn: $showingOriginal)
                    .toggleStyle(.switch)
            }
        }
    }

    var heatmapPicker: some View {
        Picker("Heatmap Type", selection: $selectedHeatmap) {
            ForEach(HeatmapType.allCases, id: \.self) { type in
                Text(type.displayName)
                    .tag(type)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedHeatmap) { _ in
            // Force view update when heatmap changes
        }
    }

    @ViewBuilder
    var heatmapImageView: some View {
        if showingOriginal {
            if let thumbnail = session.thumbnailImage {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .id("original-\(session.id)")
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
                placeholderImage
                    .id("placeholder-\(selectedHeatmap.rawValue)")
            }
        }
    }

    var placeholderImage: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "face.smiling")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Overall Score Card

    var overallScoreCard: some View {
        VStack(spacing: 12) {
            Text("Overall Skin Health")
                .font(.headline)
                .foregroundColor(HeadspaceDesign.Colors.secondary)

            HStack(spacing: 16) {
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(HeadspaceDesign.Colors.secondary.opacity(0.3), lineWidth: 12)

                    Circle()
                        .trim(from: 0, to: session.overallScore / 100)
                        .stroke(HeadspaceDesign.Colors.secondary, lineWidth: 12)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        Text("\(Int(session.overallScore))")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.yellow)

                        Text("/ 100")
                            .font(.caption)
                            .foregroundColor(HeadspaceDesign.Colors.secondary.opacity(0.8))
                    }
                }
                .frame(width: 120, height: 120)

                // Grade
                VStack(alignment: .leading, spacing: 8) {
                    Text("Grade")
                        .font(.caption)
                        .foregroundColor(HeadspaceDesign.Colors.secondary.opacity(0.8))

                    Text(session.grade.rawValue)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(HeadspaceDesign.Colors.secondary)

                    Text(session.grade.description)
                        .font(.caption)
                        .foregroundColor(HeadspaceDesign.Colors.secondary.opacity(0.8))
                }
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(HeadspaceDesign.Colors.primary)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    // MARK: - Metrics Grid

    var metricsGrid: some View {
        VStack(spacing: 12) {
            Text("Key Metrics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
                            title: "Glow",
                            value: Double(glowAnalysis.glowScore),
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
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    func wrinkleColor(for depth: WrinkleDepth) -> Color {
        switch depth {
        case .fine: return .green
        case .moderate: return .orange
        case .deep: return .red
        }
    }

    // MARK: - Glow vs Radiance Breakdown

    func glowRadianceBreakdown(_ analysis: GlowAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Glow vs Radiance Analysis")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Understanding the difference between your skin's overall health and pure luminosity.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Side-by-side comparison
            HStack(spacing: 16) {
                // Glow (Health Index)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.orange)
                        Text("Glow (Health)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text("\(Int(analysis.glowScore))/100")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)

                    Text("Overall health index")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Components:")
                            .font(.caption)
                            .fontWeight(.semibold)

                        HStack {
                            Text("Smoothness")
                                .font(.caption2)
                            Spacer()
                            Text("\(Int(analysis.smoothnessContribution))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Evenness")
                                .font(.caption2)
                            Spacer()
                            Text("\(Int(analysis.evennessContribution))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Discoloration")
                                .font(.caption2)
                            Spacer()
                            Text("\(Int(analysis.discolorationContribution))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Specular")
                                .font(.caption2)
                            Spacer()
                            Text("\(Int(analysis.specularContribution))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                )

                // Radiance (Luminosity)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sun.max")
                            .foregroundColor(.yellow)
                        Text("Radiance (Brightness)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text("\(Int(analysis.radianceScore))/100")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)

                    Text("Pure luminosity")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Components:")
                            .font(.caption)
                            .fontWeight(.semibold)

                        HStack {
                            Text("LAB L* Lightness")
                                .font(.caption2)
                            Spacer()
                            Text("\(Int(analysis.labLightness * 100))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Specular Highlights")
                                .font(.caption2)
                            Spacer()
                            Text("\(Int(analysis.specularHighlightRatio * 100))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Luminosity Index")
                                .font(.caption2)
                            Spacer()
                            Text("\(Int(analysis.luminosityIndex))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.1))
                )
            }

            // Explanation
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                Text("**Glow** measures overall skin health (texture + tone + shine), while **Radiance** measures how much light your skin reflects (physics-based brightness).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
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
        VStack(alignment: .leading, spacing: 24) {
            // MARK: - Skin Health Metrics (Included in Overall Score)
            VStack(alignment: .leading, spacing: 16) {
                Text("Skin Health Metrics")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("These high-confidence metrics (70%+ confidence) are included in your Overall Score calculation.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)

                // 1. Smoothness (22.4% weight, 85% confidence)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "waveform.path")
                            .foregroundColor(.green)
                        Text("Smoothness")
                            .font(.headline)
                    }

                    HStack {
                        Text("Score: \(Int(metrics.globalRoughnessScore))/100")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(metrics.smoothnessConfidence))% confidence")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Text("Weight in Overall Score: 22.4%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // 2. Pigmentation (22.4% weight, 80% confidence)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.purple)
                        Text("Pigmentation")
                            .font(.headline)
                    }

                    HStack {
                        Text("Score: \(Int(metrics.globalPigmentationScore))/100")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(metrics.pigmentationConfidence))% confidence")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Text("Weight in Overall Score: 22.4%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // 3. Pores (14.9% weight, 70-90% confidence)
                if let pores = metrics.poreAnalysis {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "circle.grid.cross.fill")
                                .foregroundColor(.gray)
                            Text("Pores")
                                .font(.headline)
                        }

                        HStack {
                            Text("Score: \(Int(pores.visibilityScore))/100")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(pores.confidence))% confidence")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }

                        Text("Weight in Overall Score: 14.9%")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Dominant Size: \(pores.dominantSize.rawValue) • Density: \(String(format: "%.1f", pores.density)) pores/cm²")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // 4. Discoloration (14.9% weight, 80% confidence)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "circle.hexagongrid")
                            .foregroundColor(.orange)
                        Text("Discoloration")
                            .font(.headline)
                    }

                    HStack {
                        Text("Score: \(Int(metrics.globalDiscolorationScore))/100")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(metrics.discolorationConfidence))% confidence")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Text("Weight in Overall Score: 14.9%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // 5. Acne (14.9% weight, 75-85% confidence)
                if let acne = metrics.acneAnalysis {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "circle.hexagongrid.fill")
                                .foregroundColor(.red)
                            Text("Acne")
                                .font(.headline)
                        }

                        HStack {
                            Text("Score: \(Int(acne.overallScore))/100")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(acne.confidence))% confidence")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }

                        Text("Weight in Overall Score: 14.9%")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !acne.blemishes.isEmpty {
                            Text("Detected: \(acne.blemishes.count) blemishes • Severity: \(acne.severity.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }

            Divider()
                .padding(.vertical, 8)

            // MARK: - Additional Indicators (Not in Overall Score)
            VStack(alignment: .leading, spacing: 16) {
                Text("Additional Indicators")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("These metrics provide supplementary insights but aren't included in the Overall Score calculation due to measurement limitations.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)

                // Elasticity
                if let elasticity = metrics.elasticityAnalysis {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                            Text("Elasticity")
                                .font(.headline)
                        }

                        Text("Score: \(Int(elasticity.overallScore))/100")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Level: \(elasticity.elasticityLevel.rawValue) • Recovery Rate: \(String(format: "%.2f", elasticity.recoveryRate))")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if elasticity.isTemporal {
                            Text("\(Int(elasticity.confidence))% confidence")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Requires 2+ scans for temporal analysis")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                            Text("Elasticity")
                                .font(.headline)
                        }

                        Text("Not yet available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Elasticity requires comparing multiple scans over time to measure skin firmness changes.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Hydration
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundColor(.cyan)
                        Text("Hydration")
                            .font(.headline)
                    }

                    Text("Score: \(Int(calculateHydrationScore(from: metrics)))/100")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Proxy method based on surface properties • \(Int(metrics.hydrationConfidence))% confidence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Redness
                if let redness = metrics.rednessAnalysis {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.pink)
                            Text("Redness")
                                .font(.headline)
                        }

                        Text("Score: \(Int(redness.overallScore))/100")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Level: \(redness.rednessLevel.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(Int(redness.confidence))% confidence")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Oil Control
                if let oilScore = metrics.globalSpecularScore {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                            Text("Oil Control")
                                .font(.headline)
                        }

                        Text("Score: \(Int(oilScore))/100")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Sebum management and shine control")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }

            Divider()
                .padding(.vertical, 8)

            // MARK: - Other Clinical Data (Wrinkles, Volume, Sun Damage, etc.)
            VStack(alignment: .leading, spacing: 16) {
                Text("Other Clinical Data")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

            // Sun Damage Analysis
            if let sunDamage = metrics.sunDamageAnalysis {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.orange)
                        Text("Sun Damage Analysis")
                            .font(.headline)
                    }

                    Text("Protection Score: \(Int(sunDamage.protectionScore))/100")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Damage Level: \(sunDamage.damageLevel.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Components:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("• Pigmentation Health: \(Int(sunDamage.pigmentationHealth))%")
                            .font(.caption)
                        Text("• Photoaging Resistance: \(Int(sunDamage.photoagingResistance))%")
                            .font(.caption)
                        Text("• Texture Health: \(Int(sunDamage.textureHealth))%")
                            .font(.caption)
                        Text("• Vascular Health: \(Int(sunDamage.vascularHealth))%")
                            .font(.caption)
                        Text("• Pore Health: \(Int(sunDamage.poreHealth))%")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Redness Analysis
            if let redness = metrics.rednessAnalysis {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.pink)
                        Text("Redness Analysis")
                            .font(.headline)
                    }

                    Text("Overall Score: \(Int(redness.overallScore))/100")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Level: \(redness.rednessLevel.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Confidence: \(Int(redness.confidence))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Wrinkle Analysis (Expanded)
            if let wrinkles = metrics.wrinkleAnalysis {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "waveform.path")
                            .foregroundColor(.purple)
                        Text("Wrinkle Analysis")
                            .font(.headline)
                    }

                    Text("Overall Score: \(Int(wrinkles.overallScore))/100")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Wrinkle Depth: \(wrinkles.wrinkleDepth.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Wrinkle Count: \(wrinkles.wrinkleCount) regions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if !wrinkles.regionalScores.isEmpty {
                        Text("Regional Scores:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(wrinkles.regionalScores.keys.sorted(), id: \.self) { region in
                                if let score = wrinkles.regionalScores[region] {
                                    Text("• \(region.capitalized): \(Int(score))/100")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    Text("Confidence: \(Int(wrinkles.confidence))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Elasticity Analysis
            if let elasticity = metrics.elasticityAnalysis {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                        Text("Skin Elasticity")
                            .font(.headline)
                    }

                    Text("Overall Score: \(Int(elasticity.overallScore))/100")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Elasticity Level: \(elasticity.elasticityLevel.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Recovery Rate: \(String(format: "%.2f", elasticity.recoveryRate))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if !elasticity.regionalElasticity.isEmpty {
                        Text("Regional Elasticity:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(elasticity.regionalElasticity.keys.sorted()), id: \.self) { region in
                                if let score = elasticity.regionalElasticity[region] {
                                    Text("• \(region.rawValue): \(Int(score))/100")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Volume Analysis
            if let volume = metrics.volumeAnalysis {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "cube.fill")
                            .foregroundColor(.cyan)
                        Text("Facial Volume Analysis")
                            .font(.headline)
                    }

                    Text("Overall Score: \(Int(volume.overallScore))/100")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Divider()

                    // Cheek Hollowing
                    if let cheekHollowing = volume.cheekHollowing {
                        Text("Cheek Hollowing")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("• Severity: \(cheekHollowing.severity.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Score: \(Int(cheekHollowing.score))/100")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Volume Loss: \(String(format: "%.1f", cheekHollowing.volumeLoss))%")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()
                    }

                    // Under-Eye Bags
                    if let underEyeBags = volume.underEyeBags {
                        Text("Under-Eye Bags")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("• Severity: \(underEyeBags.severity.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Score: \(Int(underEyeBags.score))/100")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Protrusion: \(String(format: "%.2f", underEyeBags.protrusion))mm")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()
                    }

                    // Facial Symmetry
                    if let facialSymmetry = volume.facialSymmetry {
                        Text("Facial Symmetry")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("• Score: \(Int(facialSymmetry.score))/100")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Left-Right Deviation: \(String(format: "%.2f", facialSymmetry.leftRightDeviation))mm")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Topology Analysis (Scan Quality)
            if let topology = metrics.topologyAnalysis {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "view.3d")
                            .foregroundColor(.green)
                        Text("Scan Quality")
                            .font(.headline)
                    }

                    Text("Quality Score: \(String(format: "%.1f", topology.overallScore))/100")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Quality Level: \(topology.qualityLevel.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Technical Details:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("• Manifold: \(topology.isManifold ? "Yes" : "No")")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Watertight: \(topology.isWatertight ? "Yes" : "No")")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("• Triangle Quality: \(String(format: "%.2f", topology.triangleQuality.averageAspectRatio))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        }
        .padding(.vertical)
    }

    // MARK: - Aging Indicators Section

    @ViewBuilder
    func agingIndicatorsSection(_ metrics: Face3DMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Aging Indicators")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Separate from skin health score")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                // Wrinkles Card
                if let wrinkles = metrics.wrinkleAnalysis {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease")
                                .foregroundColor(.purple)
                                .font(.title3)

                            Text("Wrinkles")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Text("\(Int(wrinkles.overallScore))")
                            .font(.scoreFont(size: 32))
                            .foregroundColor(.purple)

                        Text(wrinkles.wrinkleDepth.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(wrinkles.wrinkleCount) regions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // Volume Card
                if let volume = metrics.volumeAnalysis {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "cube.fill")
                                .foregroundColor(.cyan)
                                .font(.title3)

                            Text("Volume")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Text("\(Int(volume.overallScore))")
                            .font(.scoreFont(size: 32))
                            .foregroundColor(.cyan)

                        if let cheekHollowing = volume.cheekHollowing {
                            Text("Loss: \(String(format: "%.1f", cheekHollowing.volumeLoss))%")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("\(cheekHollowing.severity.rawValue) hollowing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.vertical)
    }

    // MARK: - ROI Scores

    var roiScoresSection: some View {
        VStack(spacing: 12) {
            Text("Regional Scores")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ResultsMetricCard(title: "Left Cheek", value: session.leftCheekScore, icon: "face.smiling")
                ResultsMetricCard(title: "Right Cheek", value: session.rightCheekScore, icon: "face.smiling")
                ResultsMetricCard(title: "Forehead", value: session.foreheadScore, icon: "face.smiling")
                ResultsMetricCard(title: "Chin", value: session.chinScore, icon: "face.smiling")
            }
        }
    }

    // MARK: - Actions Section

    var actionsSection: some View {
        VStack(spacing: 12) {
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
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.headline)
                        Text("Compare with Latest Scan")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }

            PrimaryButton(title: isPreparingShare ? "Preparing..." : "Share Results") {
                shareResults()
            }
            .disabled(isPreparingShare)
            .overlay {
                if isPreparingShare {
                    ProgressView()
                        .tint(.white)
                }
            }

            Button {
                showingDeleteAlert = true
            } label: {
                Text("Delete Session")
                    .font(.headline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
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

// MARK: - Metric Card

struct ResultsMetricCard: View {

    let title: String
    let value: Double
    let icon: String

    var body: some View {
        CardView {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(scoreColor)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(Int(value))%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor)
            }
            .padding(.vertical, 8)
        }
    }

    var scoreColor: Color {
        switch value {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

// MARK: - Enhanced Metric Card with Confidence

struct ResultsMetricCardWithConfidence: View {

    let title: String
    let value: Double
    let confidence: Double  // 0-100
    let icon: String
    let unit: String?  // Optional unit (%, categorical value, etc.)
    var isCoreMetric: Bool = false  // NEW: Badge for core metrics

    init(title: String, value: Double, confidence: Double, icon: String, unit: String? = "%", isCoreMetric: Bool = false) {
        self.title = title
        self.value = value
        self.confidence = confidence
        self.icon = icon
        self.unit = unit
        self.isCoreMetric = isCoreMetric
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CardView {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundColor(scoreColor)

                        Spacer()

                        // Confidence badge
                        Text("\(Int(confidence))% confidence")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(confidenceColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(confidenceColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let unit = unit {
                    Text("\(Int(value))\(unit)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(displayValue)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(scoreColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Confidence bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(confidenceColor)
                            .frame(width: geometry.size.width * CGFloat(confidence / 100), height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(.vertical, 8)
        }

            // Core metric badge overlay
            if isCoreMetric {
                Text("CORE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.blue)
                    .cornerRadius(4)
                    .offset(x: 8, y: 8)
            }
        }
    }

    var displayValue: String {
        // For categorical values (no unit)
        return "\(Int(value))"
    }

    var scoreColor: Color {
        switch value {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    var confidenceColor: Color {
        switch confidence {
        case 75...100: return .green
        case 50..<75: return .orange
        default: return .yellow
        }
    }
}

// MARK: - Categorical Metric Card (for wrinkles, etc.)

struct CategoricalMetricCard: View {

    let title: String
    let category: String  // e.g., "Fine Lines", "Moderate", "Deep"
    let confidence: Double  // 0-100
    let icon: String
    let color: Color

    var body: some View {
        CardView {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)

                    Spacer()

                    // Confidence badge
                    Text("\(Int(confidence))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(confidenceColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(confidenceColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(category)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Confidence bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(confidenceColor)
                            .frame(width: geometry.size.width * CGFloat(confidence / 100), height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(.vertical, 8)
        }
    }

    var confidenceColor: Color {
        switch confidence {
        case 75...100: return .green
        case 50..<75: return .orange
        default: return .yellow
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
