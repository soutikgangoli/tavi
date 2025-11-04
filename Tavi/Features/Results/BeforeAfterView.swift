//
//  BeforeAfterView.swift
//  Tavi
//
//  Before/After comparison view with slider
//  Created on 2025-10-28.
//

import SwiftUI

/// Before/After comparison view with visual progress
public struct BeforeAfterView: View {
    let beforeMetrics: EmotionalMetrics
    let afterMetrics: EmotionalMetrics
    let beforeDate: Date
    let afterDate: Date

    @State private var sliderPosition: CGFloat = 0.5
    @State private var isDragging = false

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Skin Health Index Comparison
                glowScoreComparison

                // Metrics Improvement Chart
                metricsComparisonChart

                // Timeline
                progressTimeline

                // Detailed Changes
                detailedChangesSection

                // Share Button
                shareButton
            }
            .padding()
        }
        .navigationTitle("Your Progress")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Components

    private var headerSection: some View {
        VStack(spacing: 12) {
            let improvement = afterMetrics.glowScore - beforeMetrics.glowScore
            let daysBetween = Calendar.current.dateComponents([.day], from: beforeDate, to: afterDate).day ?? 0

            if improvement > 0 {
                Text("🎉")
                    .font(.system(size: 64))

                Text("You Improved \(improvement) Points!")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("in \(daysBetween) days")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                Text("💪")
                    .font(.system(size: 64))

                Text("Keep Going!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Stay consistent to see results")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 20)
    }

    private var glowScoreComparison: some View {
        HStack(spacing: 40) {
            // Before
            VStack(spacing: 8) {
                Text("Before")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: CGFloat(beforeMetrics.glowScore) / 100)
                        .stroke(Color.gray, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    Text("\(beforeMetrics.glowScore)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.gray)
                }
                .accessibilityLabel("Before score")
                .accessibilityValue("\(beforeMetrics.glowScore) out of 100")

                Text(beforeDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Arrow
            VStack {
                Image(systemName: "arrow.right")
                    .font(.title)
                    .foregroundColor(.green)
                    .fontWeight(.bold)

                let improvement = afterMetrics.glowScore - beforeMetrics.glowScore
                if improvement > 0 {
                    Text("+\(improvement)")
                        .font(.headline)
                        .foregroundColor(.green)
                } else if improvement < 0 {
                    Text("\(improvement)")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
            }

            // After
            VStack(spacing: 8) {
                Text("After")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.2), lineWidth: 8)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: CGFloat(afterMetrics.glowScore) / 100)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    Text("\(afterMetrics.glowScore)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.green)
                }
                .accessibilityLabel("After score")
                .accessibilityValue("\(afterMetrics.glowScore) out of 100, improved by \(afterMetrics.glowScore - beforeMetrics.glowScore) points")

                Text(afterDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var metricsComparisonChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Breakdown")
                .font(.title2)
                .fontWeight(.bold)

            ComparisonBar(
                title: "Radiance",
                emoji: "✨",
                before: beforeMetrics.radiance,
                after: afterMetrics.radiance,
                color: .yellow
            )

            ComparisonBar(
                title: "Smoothness",
                emoji: "🧈",
                before: beforeMetrics.smoothness,
                after: afterMetrics.smoothness,
                color: .blue
            )

            ComparisonBar(
                title: "Evenness",
                emoji: "🌟",
                before: beforeMetrics.evenness,
                after: afterMetrics.evenness,
                color: .purple
            )

            ComparisonBar(
                title: "Youthfulness",
                emoji: "🌸",
                before: beforeMetrics.youthfulness,
                after: afterMetrics.youthfulness,
                color: .pink
            )

            ComparisonBar(
                title: "Freshness",
                emoji: "🌿",
                before: beforeMetrics.freshness,
                after: afterMetrics.freshness,
                color: .green
            )
        }
    }

    private var progressTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Journey")
                .font(.title2)
                .fontWeight(.bold)

            HStack(alignment: .top, spacing: 12) {
                // Timeline line
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 12, height: 12)

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .frame(height: 40)

                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                }

                // Content
                VStack(alignment: .leading, spacing: 40) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Started Tracking")
                            .font(.headline)

                        Text(beforeDate.formatted(date: .long, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Baseline: \(beforeMetrics.glowScore)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.headline)

                        Text(afterDate.formatted(date: .long, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Current: \(afterMetrics.glowScore)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
    }

    private var detailedChangesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What Changed")
                .font(.title2)
                .fontWeight(.bold)

            // Show improvements
            if !afterMetrics.improvements.isEmpty {
                ForEach(afterMetrics.improvements) { improvement in
                    ChangeCard(
                        emoji: improvement.emoji,
                        title: improvement.title,
                        change: "+\(improvement.percentChange)%",
                        isPositive: true
                    )
                }
            }

            // Show new concerns (if any)
            let newConcerns = afterMetrics.concerns.filter { concern in
                !beforeMetrics.concerns.contains { $0.title == concern.title }
            }

            if !newConcerns.isEmpty {
                ForEach(newConcerns) { concern in
                    ChangeCard(
                        emoji: concern.emoji,
                        title: concern.title,
                        change: "New area to work on",
                        isPositive: false
                    )
                }
            }

            // If nothing changed
            if afterMetrics.improvements.isEmpty && newConcerns.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Keep up your routine! Results take time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
    }

    private var shareButton: some View {
        Button {
            // Share action
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share My Progress")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .accessibilityLabel("Share my progress")
        .accessibilityHint("Opens share sheet to share your before and after comparison")
    }
}

// MARK: - Supporting Views

struct ComparisonBar: View {
    let title: String
    let emoji: String
    let before: Int
    let after: Int
    let color: Color

    private var change: Int {
        after - before
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(emoji)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if change > 0 {
                    Text("+\(change)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                } else if change < 0 {
                    Text("\(change)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Before bar (gray)
            HStack(spacing: 4) {
                Text("Before:")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 50, alignment: .leading)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray)
                            .frame(width: geometry.size.width * CGFloat(before) / 100, height: 6)
                    }
                }
                .frame(height: 6)

                Text("\(before)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }

            // After bar (colored)
            HStack(spacing: 4) {
                Text("After:")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 50, alignment: .leading)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.2))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geometry.size.width * CGFloat(after) / 100, height: 6)
                    }
                }
                .frame(height: 6)

                Text("\(after)")
                    .font(.caption2)
                    .foregroundColor(color)
                    .frame(width: 30, alignment: .trailing)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

struct ChangeCard: View {
    let emoji: String
    let title: String
    let change: String
    let isPositive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(change)
                    .font(.caption)
                    .foregroundColor(isPositive ? .green : .orange)
            }

            Spacer()

            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .foregroundColor(isPositive ? .green : .orange)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill((isPositive ? Color.green : Color.orange).opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BeforeAfterView(
            beforeMetrics: EmotionalMetrics(
                glowScore: 75,
                primaryInsight: "Your skin is on the right track! 💪",
                celebration: "Great starting point!",
                improvements: [],
                concerns: [],
                personalizedMessage: "Let's get started!",
                nextSteps: [],
                timeEstimate: "See results in 4 weeks",
                radiance: 72,
                smoothness: 70,
                evenness: 75,
                youthfulness: 78,
                freshness: 73,
                sunProtection: 70
            ),
            afterMetrics: EmotionalMetrics(
                glowScore: 87,
                primaryInsight: "Your skin looks amazing! 🌟",
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
                concerns: [],
                personalizedMessage: "Keep it up!",
                nextSteps: [],
                timeEstimate: "See more results in 2 weeks",
                radiance: 85,
                smoothness: 88,
                evenness: 82,
                youthfulness: 90,
                freshness: 86,
                sunProtection: 85
            ),
            beforeDate: Date().addingTimeInterval(-14 * 24 * 60 * 60),
            afterDate: Date()
        )
    }
}
