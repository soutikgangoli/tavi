//
//  ChallengeDetailView.swift
//  Tavi
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
                VStack(spacing: HeadspaceDesign.Spacing.xl) {
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
                .padding(.horizontal, HeadspaceDesign.Spacing.lg)
            }
            .background(HeadspaceDesign.Colors.background)
            .navigationTitle("Glow Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)
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
                    HeadspaceDesign.Colors.accent,  // Orange
                    HeadspaceDesign.Colors.primary  // Red-orange
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 180)
            .overlay(
                VStack(spacing: HeadspaceDesign.Spacing.md) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)

                    Text("30-Day Glow Challenge")
                        .font(.gilroy(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("Started \(formatDate(challenge.startDate))")
                        .font(.gilroy(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
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
                    .background(HeadspaceDesign.Colors.textSecondary.opacity(0.2))

                statItem(
                    title: "Progress",
                    value: "\(Int(challenge.progressPercentage))%",
                    subtitle: "complete"
                )

                Divider()
                    .frame(maxHeight: 60)
                    .background(HeadspaceDesign.Colors.textSecondary.opacity(0.2))

                statItem(
                    title: "Glow",
                    value: challenge.glowImprovement > 0 ? "+\(challenge.glowImprovement)" : "\(challenge.glowImprovement)",
                    subtitle: "improvement"
                )
            }
            .padding(.vertical, HeadspaceDesign.Spacing.lg)
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

    private func statItem(title: String, value: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.gilroy(size: 12, weight: .medium))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)

            Text(value)
                .font(.gilroy(size: 28, weight: .bold))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            Text(subtitle)
                .font(.gilroy(size: 11, weight: .regular))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func progressSection(_ challenge: GlowChallenge) -> some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            HStack {
                Text("\(challenge.daysRemaining) days remaining")
                    .font(.gilroy(size: 18, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Spacer()

                if challenge.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Completed!")
                            .font(.gilroy(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.green)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(HeadspaceDesign.Colors.textSecondary.opacity(0.15))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    HeadspaceDesign.Colors.accent,
                                    HeadspaceDesign.Colors.primary
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
            .frame(height: 12)
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(HeadspaceDesign.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    private func calendarSection(_ challenge: GlowChallenge) -> some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            Text("Daily Check-Ins")
                .font(.gilroy(size: 20, weight: .bold))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            // Calendar grid (30 days)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(1...30, id: \.self) { day in
                    calendarDay(day: day, challenge: challenge)
                }
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(HeadspaceDesign.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
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
                            HeadspaceDesign.Colors.accent,
                            HeadspaceDesign.Colors.primary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [
                            HeadspaceDesign.Colors.textSecondary.opacity(0.1),
                            HeadspaceDesign.Colors.textSecondary.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 44)

            if isCheckedIn {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("\(day)")
                    .font(.system(size: 14, weight: isToday ? .bold : .medium, design: .rounded))
                    .foregroundColor(
                        isToday
                        ? HeadspaceDesign.Colors.primary
                        : HeadspaceDesign.Colors.textSecondary
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? HeadspaceDesign.Colors.primary : Color.clear, lineWidth: 2)
        )
    }

    private func glowChartSection(_ challenge: GlowChallenge) -> some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            HStack {
                Text("Glow Improvement")
                    .font(.gilroy(size: 20, weight: .bold))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Spacer()

                HStack(spacing: 4) {
                    if challenge.glowImprovement > 0 {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                    } else if challenge.glowImprovement < 0 {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.red)
                    }

                    Text("\(challenge.glowImprovement > 0 ? "+" : "")\(challenge.glowImprovement)")
                        .font(.gilroy(size: 20, weight: .bold))
                        .foregroundColor(
                            challenge.glowImprovement > 0 ? .green :
                            challenge.glowImprovement < 0 ? .red :
                            HeadspaceDesign.Colors.textPrimary
                        )
                }
            }

            // Simple bar chart showing baseline vs current
            HStack(alignment: .bottom, spacing: HeadspaceDesign.Spacing.lg) {
                barChartItem(
                    label: "Baseline",
                    value: challenge.baselineGlowScore,
                    maxValue: 100,
                    color: HeadspaceDesign.Colors.textSecondary.opacity(0.4)
                )

                barChartItem(
                    label: "Current",
                    value: challenge.currentGlowScore,
                    maxValue: 100,
                    color: HeadspaceDesign.Colors.secondary
                )
            }
            .frame(height: 150)
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(HeadspaceDesign.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    private func barChartItem(label: String, value: Int, maxValue: Int, color: Color) -> some View {
        VStack(spacing: HeadspaceDesign.Spacing.sm) {
            // Bar
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(HeadspaceDesign.Colors.textSecondary.opacity(0.1))
                    .frame(maxWidth: .infinity, maxHeight: 150)

                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(maxWidth: .infinity, maxHeight: CGFloat(value) / CGFloat(maxValue) * 150)
            }

            Text("\(value)")
                .font(.gilroy(size: 18, weight: .bold))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            Text(label)
                .font(.gilroy(size: 14, weight: .medium))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func milestonesSection(_ challenge: GlowChallenge) -> some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            Text("Milestones")
                .font(.gilroy(size: 20, weight: .bold))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            VStack(spacing: HeadspaceDesign.Spacing.md) {
                ForEach(ChallengeMilestone.allMilestones, id: \.days) { milestone in
                    milestoneRow(milestone: milestone, challenge: challenge)
                }
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(HeadspaceDesign.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    private func milestoneRow(milestone: ChallengeMilestone, challenge: GlowChallenge) -> some View {
        let isUnlocked = challenge.daysCompleted >= milestone.days
        let isNext = !isUnlocked && (challenge.nextMilestone?.days == milestone.days)

        return HStack(spacing: HeadspaceDesign.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        isUnlocked
                        ? LinearGradient(
                            colors: [
                                HeadspaceDesign.Colors.accent,
                                HeadspaceDesign.Colors.primary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                HeadspaceDesign.Colors.textSecondary.opacity(0.2),
                                HeadspaceDesign.Colors.textSecondary.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                if isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text(milestone.emoji)
                        .font(.system(size: 22))
                }
            }

            // Title and subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.gilroy(size: 16, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text("Day \(milestone.days) • \(milestone.reward)")
                    .font(.gilroy(size: 14, weight: .regular))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }

            Spacer()

            if isNext {
                Text("Next")
                    .font(.gilroy(size: 12, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(HeadspaceDesign.Colors.primary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(HeadspaceDesign.Spacing.md)
        .background(
            isUnlocked || isNext
            ? HeadspaceDesign.Colors.background
            : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md))
    }

    private var emptyState: some View {
        VStack(spacing: HeadspaceDesign.Spacing.lg) {
            Image(systemName: "flame.fill")
                .font(.system(size: 64))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)

            Text("No Active Challenge")
                .font(.gilroy(size: 24, weight: .bold))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            Text("Complete your first scan to start the 30-day glow challenge")
                .font(.gilroy(size: 16, weight: .regular))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
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
