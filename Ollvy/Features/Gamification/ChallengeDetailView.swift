//
//  ChallengeDetailView.swift
//  Ollvy
//
//  Full detail view for 30-Day Glow Challenge
//  Created on 2025-01-10
//

import SwiftUI

public struct ChallengeDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var challenge: GlowChallenge?

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Designs.Spacing.xl) {
                    if let challenge = challenge {
                        // Header Section
                        headerSection(challenge)

                        // Progress Section
                        progressSection(challenge)

                        // Calendar Grid Section
                        calendarSection(challenge)

                        // Glow Improvement Chart Section
                        glowChartSection(challenge)

                        // Milestones Section
                        milestonesSection(challenge)

                        // Bottom padding
                        Spacer(minLength: 40)
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, Designs.Spacing.lg)
            }
            .background(Designs.Colors.background)
            .navigationTitle("Glow Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(AppFont.navIcon)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            loadChallenge()
        }
    }

    // MARK: - Components

    private func headerSection(_ challenge: GlowChallenge) -> some View {
        VStack(spacing: 0) {
            // Gradient header
            LinearGradient(
                colors: [
                    Designs.Colors.accent,  // Orange
                    Designs.Colors.primary  // Red-orange
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: Designs.Sizes.displayHeightMedium - 20)
            .overlay(
                VStack(spacing: Designs.Spacing.md) {
                    Image(systemName: "flame.fill")
                        .font(AppFont.scoreMedium)
                        .foregroundColor(.white)

                    Text("30-Day Glow Challenge")
                        .font(AppFont.title2)
                        .foregroundColor(.white)

                    Text("Started \(formatDate(challenge.startDate))")
                        .font(AppFont.caption)
                        .foregroundColor(.white.opacity(Designs.Opacity.almostOpaque))
                }
            )

            // Stats Row
            HStack(spacing: 0) {
                statItem(
                    title: "Days",
                    value: "\(challenge.daysCompleted)",
                    subtitle: "of 30"
                )

                Divider()
                    .frame(maxHeight: 60)
                    .background(Designs.Colors.textSecondary.opacity(Designs.Opacity.light))

                statItem(
                    title: "Progress",
                    value: "\(Int(challenge.progressPercentage))%",
                    subtitle: "complete"
                )

                Divider()
                    .frame(maxHeight: 60)
                    .background(Designs.Colors.textSecondary.opacity(Designs.Opacity.light))

                statItem(
                    title: "Skin Analysis",
                    value: challenge.skinHealthImprovement > 0 ? "+\(challenge.skinHealthImprovement)" : "\(challenge.skinHealthImprovement)",
                    subtitle: "improvement"
                )
            }
            .padding(.vertical, Designs.Spacing.lg)
            .background(Designs.Colors.elevatedCard)
        }
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
        .shadow(
            color: Designs.Shadows.card.color,
            radius: Designs.Shadows.card.radius,
            x: Designs.Shadows.card.x,
            y: Designs.Shadows.card.y
        )
    }

    private func statItem(title: String, value: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(AppFont.captionSmall)
                .foregroundColor(Designs.Colors.textSecondary)

            Text(value)
                .font(AppFont.pageTitle)
                .foregroundColor(Designs.Colors.textPrimary)

            Text(subtitle)
                .font(AppFont.micro)
                .foregroundColor(Designs.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func progressSection(_ challenge: GlowChallenge) -> some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.md) {
            HStack {
                Text("\(challenge.daysRemaining) days remaining")
                    .font(AppFont.headlineSecondary)
                    .foregroundColor(Designs.Colors.textPrimary)

                Spacer()

                if challenge.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(AppFont.bodyPrimary)
                        Text("Completed!")
                            .font(AppFont.label)
                    }
                    .foregroundColor(.green)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Designs.Colors.textSecondary.opacity(Designs.Opacity.veryLight + 0.05))
                        .frame(height: Designs.Sizes.frameHeightBar)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Designs.Colors.accent,
                                    Designs.Colors.primary
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * CGFloat(challenge.progressPercentage) / 100,
                            height: 12
                        )
                }
            }
            .frame(height: Designs.Sizes.frameHeightBar)
        }
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

    private func calendarSection(_ challenge: GlowChallenge) -> some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.md) {
            Text("Daily Check-Ins")
                .font(AppFont.headlinePrimary)
                .foregroundColor(Designs.Colors.textPrimary)

            // Calendar grid (30 days)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(1...30, id: \.self) { day in
                    calendarDay(day: day, challenge: challenge)
                }
            }
        }
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

    private func calendarDay(day: Int, challenge: GlowChallenge) -> some View {
        let isCheckedIn = day <= challenge.daysCompleted
        let isToday = day == challenge.daysCompleted + 1

        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isCheckedIn
                    ? LinearGradient(
                        colors: [
                            Designs.Colors.accent,
                            Designs.Colors.primary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [
                            Designs.Colors.textSecondary.opacity(Designs.Opacity.veryLight),
                            Designs.Colors.textSecondary.opacity(Designs.Opacity.veryLight / 2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: Designs.Sizes.iconMedium)

            if isCheckedIn {
                Image(systemName: "checkmark")
                    .font(AppFont.metricLabel)
                    .foregroundColor(.white)
            } else {
                Text("\(day)")
                    .font(.app(size: 14, weight: isToday ? .bold : .medium, design: .rounded))
                    .foregroundColor(
                        isToday
                        ? Designs.Colors.primary
                        : Designs.Colors.textSecondary
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? Designs.Colors.primary : Color.clear, lineWidth: 2)
        )
    }

    private func glowChartSection(_ challenge: GlowChallenge) -> some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.md) {
            HStack {
                Text("Glow Improvement")
                    .font(AppFont.headlinePrimary)
                    .foregroundColor(Designs.Colors.textPrimary)

                Spacer()

                HStack(spacing: 4) {
                    if challenge.skinHealthImprovement > 0 {
                        Image(systemName: "arrow.up.right")
                            .font(AppFont.metricLabel)
                            .foregroundColor(Designs.ScoreColors.excellent)
                    } else if challenge.skinHealthImprovement < 0 {
                        Image(systemName: "arrow.down.right")
                            .font(AppFont.metricLabel)
                            .foregroundColor(Designs.Colors.error)
                    }

                    Text("\(challenge.skinHealthImprovement > 0 ? "+" : "")\(challenge.skinHealthImprovement)")
                        .font(AppFont.headlinePrimary)
                        .foregroundColor(
                            challenge.skinHealthImprovement > 0 ? Designs.ScoreColors.excellent :
                            challenge.skinHealthImprovement < 0 ? Designs.Colors.error :
                            Designs.Colors.textPrimary
                        )
                }
            }

            // Simple bar chart showing baseline vs current
            HStack(alignment: .bottom, spacing: Designs.Spacing.lg) {
                barChartItem(
                    label: "Baseline",
                    value: challenge.baselineSkinHealthScore,
                    maxValue: 100,
                    color: Designs.Colors.textSecondary.opacity(Designs.Opacity.light)
                )

                barChartItem(
                    label: "Current",
                    value: challenge.currentSkinHealthScore,
                    maxValue: 100,
                    color: Designs.Colors.secondary
                )
            }
            .frame(height: Designs.Sizes.displayHeight / 2)
        }
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

    private func barChartItem(label: String, value: Int, maxValue: Int, color: Color) -> some View {
        VStack(spacing: Designs.Spacing.sm) {
            // Bar
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Designs.Colors.textSecondary.opacity(Designs.Opacity.veryLight))
                    .frame(maxWidth: .infinity, maxHeight: 150)

                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(maxWidth: .infinity, maxHeight: CGFloat(value) / CGFloat(maxValue) * 150)
            }

            Text("\(value)")
                .font(AppFont.headlineSecondary)
                .foregroundColor(Designs.Colors.textPrimary)

            Text(label)
                .font(AppFont.caption)
                .foregroundColor(Designs.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func milestonesSection(_ challenge: GlowChallenge) -> some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.md) {
            Text("Milestones")
                .font(AppFont.headlinePrimary)
                .foregroundColor(Designs.Colors.textPrimary)

            VStack(spacing: Designs.Spacing.md) {
                ForEach(ChallengeMilestone.allMilestones, id: \.days) { milestone in
                    milestoneRow(milestone: milestone, challenge: challenge)
                }
            }
        }
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

    private func milestoneRow(milestone: ChallengeMilestone, challenge: GlowChallenge) -> some View {
        let isUnlocked = challenge.daysCompleted >= milestone.days
        let isNext = !isUnlocked && (challenge.nextMilestone?.days == milestone.days)

        return HStack(spacing: Designs.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        isUnlocked
                        ? LinearGradient(
                            colors: [
                                Designs.Colors.accent,
                                Designs.Colors.primary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                Designs.Colors.textSecondary.opacity(Designs.Opacity.light),
                                Designs.Colors.textSecondary.opacity(Designs.Opacity.veryLight)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                        .frame(width: Designs.Sizes.cardIcon, height: Designs.Sizes.cardIcon)

                if isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(AppFont.navIcon)
                        .foregroundColor(.white)
                } else {
                    Text(milestone.emoji)
                        .font(AppFont.sectionHeader)
                }
            }

            // Title and subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(AppFont.subheadingPrimary)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text("Day \(milestone.days) • \(milestone.reward)")
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
            }

            Spacer()

            if isNext {
                Text("Next")
                    .font(AppFont.captionSmall)
                    .foregroundColor(Designs.Colors.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Designs.Colors.primary.opacity(Designs.Opacity.veryLight + 0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(Designs.Spacing.md)
        .background(
            isUnlocked || isNext
            ? Designs.Colors.background
            : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
    }

    private var emptyState: some View {
        VStack(spacing: Designs.Spacing.lg) {
            Image(systemName: "flame.fill")
                .font(AppFont.scoreDisplay)
                .foregroundColor(Designs.Colors.textSecondary)

            Text("No Active Challenge")
                .font(AppFont.title2)
                .foregroundColor(Designs.Colors.textPrimary)

            Text("Complete your first scan to start the 30-day glow challenge")
                .font(AppFont.bodyPrimary)
                .foregroundColor(Designs.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 100)
    }

    // MARK: - Helpers

    private func loadChallenge() {
        challenge = GamificationManager.shared.getCurrentChallenge()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    ChallengeDetailView()
}
