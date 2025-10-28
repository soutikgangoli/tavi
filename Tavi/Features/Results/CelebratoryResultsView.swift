//
//  CelebratoryResultsView.swift
//  Tavi
//
//  Beautiful, emotional results view that users will LOVE
//  Created on 2025-10-28.
//

import SwiftUI

/// Celebratory results view with emotional design
public struct CelebratoryResultsView: View {
    let emotionalMetrics: EmotionalMetrics
    let previousMetrics: EmotionalMetrics?
    let onStartChallenge: () -> Void
    let onShareResults: () -> Void
    let onViewProducts: () -> Void

    @State private var showConfetti = false
    @State private var showGlowScore = false
    @State private var showSubScores = false
    @State private var showImprovements = false
    @State private var showNextSteps = false

    public init(
        emotionalMetrics: EmotionalMetrics,
        previousMetrics: EmotionalMetrics? = nil,
        onStartChallenge: @escaping () -> Void = {},
        onShareResults: @escaping () -> Void = {},
        onViewProducts: @escaping () -> Void = {}
    ) {
        self.emotionalMetrics = emotionalMetrics
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

                // Big Glow Score
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
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .cyan
        case 60..<70: return .orange
        default: return .purple
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

                    Text("Glow Score")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

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

            VStack(spacing: 12) {
                SubScoreRow(title: "Radiance", emoji: "✨", score: emotionalMetrics.radiance, color: .yellow)
                SubScoreRow(title: "Smoothness", emoji: "🧈", score: emotionalMetrics.smoothness, color: .blue)
                SubScoreRow(title: "Evenness", emoji: "🌟", score: emotionalMetrics.evenness, color: .purple)
                SubScoreRow(title: "Youthfulness", emoji: "🌸", score: emotionalMetrics.youthfulness, color: .pink)
                SubScoreRow(title: "Freshness", emoji: "🌿", score: emotionalMetrics.freshness, color: .green)
            }
        }
    }

    private var concernsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.orange)
                Text("Let's Improve These")
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

            Text("Follow these steps to boost your glow:")
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

                Text("Start Your 30-Day Glow Challenge")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Track your progress, build healthy habits, and watch your skin transform!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button(action: onStartChallenge) {
                HStack {
                    Image(systemName: "trophy.fill")
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
                Text("Share My Progress")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(12)
        }
    }

    private var scanMetadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Scan Details")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

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
        }
        .padding()
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
                freshness: 86
            )
        )
    }
}
