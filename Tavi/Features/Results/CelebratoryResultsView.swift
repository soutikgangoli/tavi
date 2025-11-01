//
//  CelebratoryResultsView.swift
//  Tavi
//
//  Beautiful, emotional results view that users will LOVE
//  Created on 2025-10-28.
//  All build errors fixed - 2025-10-31
//

import SwiftUI

/// Celebratory results view with emotional design
public struct CelebratoryResultsView: View {
    let emotionalMetrics: EmotionalMetrics
    let clinicalMetrics: Face3DMetrics?
    let previousMetrics: EmotionalMetrics?
    let onStartChallenge: () -> Void
    let onShareResults: () -> Void
    let onViewProducts: () -> Void

    @State private var showConfetti = false
    @State private var showGlowScore = false
    @State private var showSubScores = false
    @State private var showImprovements = false
    @State private var showNextSteps = false
    @State private var showScanDetails = false
    @State private var showDebugCalculations = false

    public init(
        emotionalMetrics: EmotionalMetrics,
        clinicalMetrics: Face3DMetrics? = nil,
        previousMetrics: EmotionalMetrics? = nil,
        onStartChallenge: @escaping () -> Void = {},
        onShareResults: @escaping () -> Void = {},
        onViewProducts: @escaping () -> Void = {}
    ) {
        self.emotionalMetrics = emotionalMetrics
        self.clinicalMetrics = clinicalMetrics
        self.previousMetrics = previousMetrics
        self.onStartChallenge = onStartChallenge
        self.onShareResults = onShareResults
        self.onViewProducts = onViewProducts
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header celebration
                celebrationHeader
                    .opacity(showGlowScore ? 1 : 0)
                    .offset(y: showGlowScore ? 0 : -20)

                // Big Skin Health Index Score
                glowScoreCard
                    .opacity(showGlowScore ? 1 : 0)
                    .scaleEffect(showGlowScore ? 1 : 0.8)

                // Improvements (if any)
                if !emotionalMetrics.improvements.isEmpty {
                    improvementsSection
                        .opacity(showImprovements ? 1 : 0)
                        .offset(y: showImprovements ? 0 : 20)
                }

                // Sub-scores
                subScoresSection
                    .opacity(showSubScores ? 1 : 0)
                    .offset(y: showSubScores ? 0 : 20)

                // Concerns (framed positively)
                if !emotionalMetrics.concerns.isEmpty {
                    concernsSection
                }

                // Next Steps
                nextStepsSection
                    .opacity(showNextSteps ? 1 : 0)
                    .offset(y: showNextSteps ? 0 : 20)

                // Product Recommendations Placeholder
                productRecommendationsSection

                // Challenge CTA
                if previousMetrics == nil {
                    challengeCTA
                }

                // Share Button
                shareButton

                // Clinical Info (expandable dropdown)
                if let clinicalMetrics = clinicalMetrics {
                    ClinicalInfoView(
                        emotionalMetrics: emotionalMetrics,
                        clinicalMetrics: clinicalMetrics
                    )
                }

                // DEBUG: Calculation Breakdown (for debugging score differences)
                if let clinicalMetrics = clinicalMetrics {
                    debugCalculationSection(clinicalMetrics: clinicalMetrics)
                }

                // Scan Metadata (for transparency)
                scanMetadataSection

                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(gradientBackground)
        .onAppear {
            animateEntrance()
        }
    }

    // MARK: - Components

    private var gradientBackground: some View {
        LinearGradient(
            colors: [
                glowColor.opacity(0.1),
                Color(uiColor: .systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var glowColor: Color {
        switch emotionalMetrics.glowScore {
        case 85...100: return Color(red: 0.0, green: 0.8, blue: 0.2)  // Bright green
        case 70..<85: return Color(red: 0.6, green: 0.9, blue: 0.3)   // Light green
        case 50..<70: return Color(red: 1.0, green: 0.8, blue: 0.0)   // Yellow
        case 25..<50: return Color(red: 1.0, green: 0.6, blue: 0.0)   // Dark yellow/orange
        default: return Color(red: 1.0, green: 0.3, blue: 0.2)        // Red
        }
    }

    private var celebrationHeader: some View {
        VStack(spacing: 12) {
            Text(emotionalMetrics.primaryInsight)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)

            Text(emotionalMetrics.celebration)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    private var glowScoreCard: some View {
        VStack(spacing: 16) {
            // Big score circle
            ZStack {
                Circle()
                    .stroke(glowColor.opacity(0.2), lineWidth: 12)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: CGFloat(emotionalMetrics.glowScore) / 100)
                    .stroke(
                        glowColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(emotionalMetrics.glowScore)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(glowColor)

                    Text("Skin Health Index")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Overall health score")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Your overall skin health index is \(emotionalMetrics.glowScore) out of 100")

            // Personalized message
            Text(emotionalMetrics.personalizedMessage)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .accessibilityElement(children: .contain)
    }

    private var improvementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("Improvements")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            ForEach(emotionalMetrics.improvements) { improvement in
                ImprovementCard(improvement: improvement)
            }
        }
    }

    private var subScoresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Skin Metrics")
                .font(.title2)
                .fontWeight(.bold)

            Text("A comprehensive analysis of your skin's key health indicators.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                MetricDetailRow(
                    title: "Radiance",
                    emoji: "✨",
                    score: emotionalMetrics.radiance,
                    color: .yellow,
                    description: "Light reflection and natural luminosity"
                )

                MetricDetailRow(
                    title: "Smoothness",
                    emoji: "🧈",
                    score: emotionalMetrics.smoothness,
                    color: .blue,
                    description: "Surface texture and refinement quality"
                )

                MetricDetailRow(
                    title: "Evenness",
                    emoji: "🌟",
                    score: emotionalMetrics.evenness,
                    color: .purple,
                    description: "Tone uniformity and pigmentation balance"
                )

                MetricDetailRow(
                    title: "Youthfulness",
                    emoji: "🌸",
                    score: emotionalMetrics.youthfulness,
                    color: .pink,
                    description: "Firmness and elasticity assessment"
                )

                MetricDetailRow(
                    title: "Freshness",
                    emoji: "🌿",
                    score: emotionalMetrics.freshness,
                    color: .green,
                    description: "Clarity and overall vitality"
                )

                // Only show Sun Protection if enabled in settings
                if clinicalMetrics?.sunDamageAnalysis != nil {
                    MetricDetailRow(
                        title: "Sun Protection",
                        emoji: "☀️",
                        score: emotionalMetrics.sunProtection,
                        color: .orange,
                        description: "Protection from UV damage and photoaging"
                    )
                }
            }
        }
    }

    private var concernsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.orange)
                Text("Areas for Improvement")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            ForEach(emotionalMetrics.concerns) { concern in
                ConcernCard(concern: concern)
            }
        }
    }

    private var nextStepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundColor(.blue)
                Text("Your Action Plan")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Text("Personalized recommendations for optimal results.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(emotionalMetrics.nextSteps) { step in
                ActionStepCard(step: step)
            }

            // Time estimate
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.green)
                Text(emotionalMetrics.timeEstimate)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.1))
            )
        }
    }

    private var productRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bag.fill")
                    .foregroundColor(.pink)
                Text("Product Recommendations")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Personalized product recommendations")
                        .font(.headline)

                    Text("Based on your skin analysis, we'll recommend the perfect products for your routine")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Coming Soon")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.pink.opacity(0.2))
                    .foregroundColor(.pink)
                    .cornerRadius(8)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
    }

    private var challengeCTA: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("🏆")
                    .font(.system(size: 64))
                    .accessibilityHidden(true)

                Text("Start Your 30-Day Glow Challenge")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Track your progress with daily check-ins and evidence-based skincare habits.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button(action: onStartChallenge) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .accessibilityHidden(true)
                    Text("Start 30-Day Challenge")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.orange, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .accessibilityLabel("Start 30-Day Glow Challenge")
            .accessibilityHint("Begin tracking your skin health progress with daily check-ins")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var shareButton: some View {
        Button(action: onShareResults) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .accessibilityHidden(true)
                Text("Share My Progress")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(12)
        }
        .accessibilityLabel("Share my progress")
        .accessibilityHint("Share your skin health results with others")
    }

    private func debugCalculationSection(clinicalMetrics: Face3DMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsible header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showDebugCalculations.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "hammer.fill")
                        .foregroundColor(.orange)
                    Text("Debug: Score Calculations")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)

                    Spacer()

                    Image(systemName: showDebugCalculations ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable debug content
            if showDebugCalculations {
                debugCalculationContent(clinicalMetrics: clinicalMetrics)
                    .padding([.horizontal, .bottom])
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 2)
        )
    }

    private func debugCalculationContent(clinicalMetrics: Face3DMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This shows exactly how your scores were calculated. Use this to understand why results differ between scans.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            Divider()

            // Skin Health Index Calculation
            debugGlowScoreSection(clinicalMetrics: clinicalMetrics)

            Divider()

            // Radiance Calculation
            debugRadianceSection(clinicalMetrics: clinicalMetrics)

            Divider()

            // Other Sub-Scores
            debugSubScoresSection(clinicalMetrics: clinicalMetrics)

            Divider()

            // Clinical Raw Data
            debugRawDataSection(clinicalMetrics: clinicalMetrics)
        }
    }

    private func debugGlowScoreSection(clinicalMetrics: Face3DMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Skin Health Index (Overall Score)")
                .font(.headline)
                .foregroundColor(.orange)

            if let glowAnalysis = clinicalMetrics.glowAnalysis {
                Text("✓ Using GlowAnalyzer (Physics-based)")
                    .font(.caption)
                    .foregroundColor(.green)

                DebugFormulaRow(
                    label: "Glow Score",
                    formula: "From GlowAnalyzer.glowScore",
                    value: "\(Int(glowAnalysis.glowScore.rounded()))",
                    rawValue: String(format: "%.2f", glowAnalysis.glowScore)
                )
            } else {
                LegacyGlowScoreView(clinicalMetrics: clinicalMetrics)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    private func debugRadianceSection(clinicalMetrics: Face3DMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Radiance Score")
                .font(.headline)
                .foregroundColor(.yellow)

            if let glowAnalysis = clinicalMetrics.glowAnalysis {
                    Text("✓ Using GlowAnalyzer (Physics-based)")
                        .font(.caption)
                        .foregroundColor(.green)

                    DebugFormulaRow(
                        label: "Radiance",
                        formula: "From GlowAnalyzer.radianceScore",
                        value: "\(Int(glowAnalysis.radianceScore.rounded()))",
                        rawValue: String(format: "%.2f", glowAnalysis.radianceScore)
                    )
                } else {
                LegacyRadianceScoreView(clinicalMetrics: clinicalMetrics)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }

    private func debugSubScoresSection(clinicalMetrics: Face3DMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Other Sub-Scores (Direct Mappings)")
                .font(.headline)

            DebugFormulaRow(
                label: "Smoothness",
                formula: "= globalRoughnessScore",
                value: "\(emotionalMetrics.smoothness)",
                rawValue: String(format: "%.2f", clinicalMetrics.globalRoughnessScore)
            )

            DebugFormulaRow(
                label: "Evenness",
                formula: "= globalPigmentationScore",
                value: "\(emotionalMetrics.evenness)",
                rawValue: String(format: "%.2f", clinicalMetrics.globalPigmentationScore)
            )

            DebugFormulaRow(
                label: "Youthfulness",
                formula: "= globalRoughnessScore (smoothness indicator)",
                value: "\(emotionalMetrics.youthfulness)",
                rawValue: String(format: "%.2f", clinicalMetrics.globalRoughnessScore)
            )

            DebugFormulaRow(
                label: "Freshness",
                formula: "(evenness × 0.5) + (smoothness × 0.5)",
                value: "\(emotionalMetrics.freshness)",
                rawValue: String(format: "%.2f", (clinicalMetrics.globalPigmentationScore * 0.5 + clinicalMetrics.globalRoughnessScore * 0.5))
            )

            if let sunDamage = clinicalMetrics.sunDamageAnalysis {
                DebugFormulaRow(
                    label: "Sun Protection",
                    formula: "= sunDamageAnalysis.protectionScore",
                    value: "\(emotionalMetrics.sunProtection)",
                    rawValue: String(format: "%.2f", sunDamage.protectionScore)
                )
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }

    private func debugRawDataSection(clinicalMetrics: Face3DMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Raw Clinical Data")
                .font(.headline)

            DebugDataRow(label: "Global Roughness", value: String(format: "%.2f", clinicalMetrics.globalRoughnessScore))
            DebugDataRow(label: "Global Pigmentation", value: String(format: "%.2f", clinicalMetrics.globalPigmentationScore))
            DebugDataRow(label: "Global Discoloration", value: String(format: "%.2f", clinicalMetrics.globalDiscolorationScore))
            if let specular = clinicalMetrics.globalSpecularScore {
                DebugDataRow(label: "Global Specular", value: String(format: "%.2f", specular))
            }
            DebugDataRow(label: "Total Vertices", value: "\(clinicalMetrics.vertexCount)")
            DebugDataRow(label: "Total Faces", value: "\(clinicalMetrics.triangleCount)")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var scanMetadataSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsible header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showScanDetails.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text("Scan Details")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: showScanDetails ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable content
            if showScanDetails {
                VStack(spacing: 8) {
                    HStack {
                        Text("Device:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(UIDevice.current.model)
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("iOS Version:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(UIDevice.current.systemVersion)
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Scan Date:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Date(), style: .date)
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("TrueDepth Camera:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("Available")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }

                    Divider()
                        .padding(.vertical, 4)

                    Text("Note: Results may vary slightly between iPhone models due to TrueDepth camera quality differences.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .italic()
                }
                .padding([.horizontal, .bottom])
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
    }

    // MARK: - Animations

    private func animateEntrance() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            showGlowScore = true
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            showImprovements = true
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
            showSubScores = true
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6)) {
            showNextSteps = true
        }

        // Show confetti for high scores
        if emotionalMetrics.glowScore >= 85 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showConfetti = true
            }
        }
    }
}

// MARK: - Supporting Views

struct ImprovementCard: View {
    let improvement: EmotionalImprovement

    var body: some View {
        HStack(spacing: 16) {
            Text(improvement.emoji)
                .font(.system(size: 40))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(improvement.title)
                        .font(.headline)

                    Text("+\(improvement.percentChange)%")
                        .font(.headline)
                        .foregroundColor(.green)
                }

                Text(improvement.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(improvement.sinceDays) days of progress")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .foregroundColor(.green)
                .font(.title3)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.1))
        )
    }
}

struct SubScoreRow: View {
    let title: String
    let emoji: String
    let score: Int
    let color: Color

    var body: some View {
        HStack {
            Text(emoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geometry.size.width * CGFloat(score) / 100, height: 8)
                    }
                }
                .frame(height: 8)
            }

            Text("\(score)")
                .font(.headline)
                .foregroundColor(color)
                .frame(width: 40, alignment: .trailing)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

struct MetricDetailRow: View {
    let title: String
    let emoji: String
    let score: Int
    let color: Color
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(emoji)
                    .font(.title2)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    // Compact emotional summary - score dependent
                    Text(compactEmotionalSummary)
                        .font(.caption)
                        .foregroundStyle(summaryColor)
                }

                Spacer()

                Text("\(score)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(score) / 100, height: 8)
                }
            }
            .frame(height: 8)
            .accessibilityLabel("\(title) progress: \(score) percent")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(score) out of 100. \(compactEmotionalSummary)")
    }

    // MARK: - Compact Summaries (Different from Clinical Breakdown)

    /// Returns compact, score-dependent summary for main results
    private var compactEmotionalSummary: String {
        switch title {
        case "Radiance":
            switch score {
            case 80...100: return "Glowing and luminous"
            case 60...79: return "Good glow, can improve"
            case 40...59: return "Needs radiance boost"
            default: return "Requires attention"
            }
        case "Smoothness":
            switch score {
            case 80...100: return "Silky and refined"
            case 60...79: return "Pretty smooth"
            case 40...59: return "Some roughness detected"
            default: return "Texture needs work"
            }
        case "Evenness":
            switch score {
            case 80...100: return "Beautifully balanced tone"
            case 60...79: return "Mostly even"
            case 40...59: return "Noticeable variation"
            default: return "Uneven tone"
            }
        case "Youthfulness":
            switch score {
            case 80...100: return "Firm and resilient"
            case 60...79: return "Holding up well"
            case 40...59: return "Early aging signs"
            default: return "Visible aging"
            }
        case "Freshness":
            switch score {
            case 80...100: return "Hydrated and vibrant"
            case 60...79: return "Decent vitality"
            case 40...59: return "Looking tired"
            default: return "Needs hydration"
            }
        case "Sun Protection":
            switch score {
            case 80...100: return "Well protected"
            case 60...79: return "Some sun exposure"
            case 40...59: return "Sun damage detected"
            default: return "Significant UV damage"
            }
        default:
            return description // Fallback to original description
        }
    }

    /// Returns color for the summary text based on score
    private var summaryColor: Color {
        switch score {
        case 80...100: return .primary
        case 60...79: return .secondary
        case 40...59: return .orange
        default: return .red
        }
    }
}

struct ConcernCard: View {
    let concern: EmotionalConcern

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(concern.emoji)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(concern.title)
                        .font(.headline)

                    Text(concern.severity.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(severityColor.opacity(0.2))
                        .foregroundColor(severityColor)
                        .cornerRadius(4)
                }

                Spacer()
            }

            Text(concern.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Solution:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(concern.solution)
                    .font(.subheadline)
            }

            Text(concern.encouragement)
                .font(.caption)
                .foregroundColor(.green)
                .italic()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var severityColor: Color {
        switch concern.severity {
        case .none: return .green
        case .mild: return .orange
        case .moderate: return .red
        }
    }
}

struct ActionStepCard: View {
    let step: ActionableStep

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: step.icon)
                .font(.title2)
                .foregroundColor(priorityColor)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(priorityColor.opacity(0.2))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(step.action)
                    .font(.headline)

                HStack {
                    Text(step.frequency)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(step.timing)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(step.expectedResult)
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var priorityColor: Color {
        switch step.priority {
        case .critical: return .red
        case .important: return .orange
        case .optional: return .blue
        }
    }
}

// MARK: - Debug Helper Views

struct DebugFormulaRow: View {
    let label: String
    let formula: String
    let value: String
    let rawValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(value)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("raw: \(rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Text(formula)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding(.vertical, 4)
    }
}

struct DebugDataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Legacy Score Views

struct LegacyGlowScoreView: View {
    let clinicalMetrics: Face3DMetrics

    var body: some View {
        let smoothness = clinicalMetrics.globalRoughnessScore
        let evenness = clinicalMetrics.globalPigmentationScore
        let discoloration = clinicalMetrics.globalDiscolorationScore
        let specular = clinicalMetrics.globalSpecularScore ?? 50.0
        let score = (smoothness * 0.4) + (evenness * 0.3) + (discoloration * 0.2) + (specular * 0.1)

        VStack(alignment: .leading, spacing: 8) {
            Text("⚠ Using Legacy Fallback Formula")
                .font(.caption)
                .foregroundColor(.orange)

            Text("Formula: (smoothness × 0.4) + (evenness × 0.3) + (discoloration × 0.2) + (specular × 0.1)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)

            DebugFormulaRow(
                label: "Smoothness",
                formula: "40% weight",
                value: String(format: "%.2f", smoothness * 0.4),
                rawValue: String(format: "%.2f", smoothness)
            )

            DebugFormulaRow(
                label: "Evenness",
                formula: "30% weight",
                value: String(format: "%.2f", evenness * 0.3),
                rawValue: String(format: "%.2f", evenness)
            )

            DebugFormulaRow(
                label: "Discoloration",
                formula: "20% weight",
                value: String(format: "%.2f", discoloration * 0.2),
                rawValue: String(format: "%.2f", discoloration)
            )

            DebugFormulaRow(
                label: "Specular",
                formula: "10% weight",
                value: String(format: "%.2f", specular * 0.1),
                rawValue: String(format: "%.2f", specular)
            )

            Divider()

            HStack {
                Text("Total Score:")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                Text("\(Int(score.rounded()))")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Text("(raw: \(String(format: "%.2f", score)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct LegacyRadianceScoreView: View {
    let clinicalMetrics: Face3DMetrics

    var body: some View {
        let evenness = clinicalMetrics.globalPigmentationScore
        let shine = clinicalMetrics.globalSpecularScore ?? 50.0
        let radiance = (evenness * 0.6 + shine * 0.4)

        VStack(alignment: .leading, spacing: 8) {
            Text("⚠ Using Legacy Fallback Formula")
                .font(.caption)
                .foregroundColor(.orange)

            Text("Formula: (evenness × 0.6) + (shine × 0.4)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)

            DebugFormulaRow(
                label: "Evenness",
                formula: "60% weight",
                value: String(format: "%.2f", evenness * 0.6),
                rawValue: String(format: "%.2f", evenness)
            )

            DebugFormulaRow(
                label: "Shine",
                formula: "40% weight",
                value: String(format: "%.2f", shine * 0.4),
                rawValue: String(format: "%.2f", shine)
            )

            Divider()

            HStack {
                Text("Radiance:")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                Text("\(Int(radiance.rounded()))")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
                Text("(raw: \(String(format: "%.2f", radiance)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CelebratoryResultsView(
            emotionalMetrics: EmotionalMetrics(
                glowScore: 87,
                primaryInsight: "Your skin looks amazing today! 🌟",
                celebration: "Amazing progress! Up 12 points! 🎉",
                improvements: [
                    EmotionalImprovement(
                        title: "Smoother skin texture",
                        emoji: "✨",
                        percentChange: 12,
                        message: "Your skin feels noticeably smoother!",
                        sinceDays: 14
                    )
                ],
                concerns: [
                    EmotionalConcern(
                        title: "Fine lines around eyes",
                        emoji: "👁️",
                        severity: .mild,
                        message: "Let's work on reducing these",
                        solution: "Try an eye cream with retinol",
                        encouragement: "Most people see results in 2-3 weeks!"
                    )
                ],
                personalizedMessage: "Hey Sarah! Your routine is paying off! Keep up the great work! 💪",
                nextSteps: [
                    ActionableStep(
                        action: "Apply SPF 30+ sunscreen",
                        frequency: "Every morning",
                        timing: "After moisturizer",
                        expectedResult: "Prevent new damage, maintain current glow",
                        priority: .critical,
                        icon: "sun.max.fill"
                    )
                ],
                timeEstimate: "See noticeable results in 2-3 weeks",
                radiance: 85,
                smoothness: 88,
                evenness: 82,
                youthfulness: 90,
                freshness: 86,
                sunProtection: 78
            )
        )
    }
}
