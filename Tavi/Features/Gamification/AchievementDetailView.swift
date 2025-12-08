//
//  AchievementDetailView.swift
//  Tavi
//
//  Detail view for individual achievements
//  Created on 2025-01-10
//

import SwiftUI

public struct AchievementDetailView: View {

    @Environment(\.dismiss) private var dismiss
    let achievement: Achievement

    public init(achievement: Achievement) {
        self.achievement = achievement
    }

    public var body: some View {
        VStack(spacing: Designs.Spacing.xl) {
            Spacer()

            // Large achievement icon
            ZStack {
                Circle()
                    .fill(
                        achievement.isUnlocked
                        ? Designs.ScoreColors.achievementGreenBackground.opacity(Designs.Opacity.light)
                        : Designs.Colors.textSecondary.opacity(Designs.Opacity.veryLight)
                    )
                    .frame(width: Designs.Sizes.achievementIcon, height: Designs.Sizes.achievementIcon)

                Image(systemName: achievement.iconName)
                    .font(.app(size: 56, weight: .semibold))
                    .foregroundColor(
                        achievement.isUnlocked
                        ? Designs.ScoreColors.achievementGreen
                        : Designs.Colors.textSecondary.opacity(Designs.Opacity.light)
                    )

                // Unlock animation overlay if unlocked
                if achievement.isUnlocked {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Designs.ScoreColors.achievementGreen.opacity(Designs.Opacity.semiOpaque),
                                    Designs.ScoreColors.achievementGreen.opacity(0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: Designs.Sizes.achievementIcon + 16, height: Designs.Sizes.achievementIcon + 16)
                }
            }

            // Title and description
            VStack(spacing: Designs.Spacing.md) {
                Text(achievement.title)
                    .font(AppFont.pageTitle)
                    .foregroundColor(Designs.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(achievement.description)
                    .font(AppFont.bodyPrimary)
                    .foregroundColor(Designs.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Designs.Spacing.xl)

            // Status section
            VStack(spacing: Designs.Spacing.md) {
                if achievement.isUnlocked {
                    // Unlocked state
                    if let unlockedDate = achievement.unlockedDate {
                        VStack(spacing: Designs.Spacing.sm) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.app(size: 20, weight: .semibold))
                                Text("Unlocked")
                                    .font(AppFont.headlineSecondary)
                            }
                            .foregroundColor(.green)

                            Text(formatUnlockDate(unlockedDate))
                                .font(AppFont.caption)
                                .foregroundColor(Designs.Colors.textSecondary)
                        }
                        .padding(Designs.Spacing.lg)
                        .frame(maxWidth: .infinity)
                        .background(.green.opacity(Designs.Opacity.veryLight))
                        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
                    }
                } else {
                    // Locked state
                    VStack(spacing: Designs.Spacing.sm) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.app(size: 18, weight: .semibold))
                            Text("Locked")
                                .font(AppFont.headlineSecondary)
                        }
                        .foregroundColor(Designs.Colors.textSecondary)

                        Text(getProgressText())
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }
                    .padding(Designs.Spacing.lg)
                    .frame(maxWidth: .infinity)
                    .background(Designs.Colors.textSecondary.opacity(Designs.Opacity.veryLight))
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
                }
            }
            .padding(.horizontal, Designs.Spacing.xl)

            Spacer()

            // Close button
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(AppFont.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Designs.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
            }
            .padding(.horizontal, Designs.Spacing.xl)
            .padding(.bottom, Designs.Spacing.xl)
        }
        .background(Designs.Colors.background)
    }

    // MARK: - Helpers

    private func formatUnlockDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return "Unlocked on \(formatter.string(from: date))"
    }

    private func getProgressText() -> String {
        switch achievement.category {
        case .scanning:
            if achievement.id == "first_scan" {
                return "Complete your first scan to unlock"
            } else if achievement.id == "week_warrior" {
                return "Complete 7 scans to unlock"
            } else if achievement.id == "monthly_master" {
                return "Complete 30 scans to unlock"
            }
        case .streaks:
            if achievement.id == "on_fire" {
                return "Maintain a 3-day streak to unlock"
            } else if achievement.id == "unstoppable" {
                return "Maintain a 7-day streak to unlock"
            } else if achievement.id == "century_club" {
                return "Maintain a 30-day streak to unlock"
            }
        case .improvement:
            if achievement.id == "glow_getter" {
                return "Improve glow by 10 points to unlock"
            } else if achievement.id == "radiance_rising" {
                return "Improve overall score by 20 points to unlock"
            } else if achievement.id == "transformation_master" {
                return "Improve overall score by 40 points to unlock"
            }
        case .challenges:
            return "Complete the 30-day challenge to unlock"
        }

        return "Keep scanning to unlock"
    }
}

#Preview {
    AchievementDetailView(
        achievement: Achievement(
            id: "first_scan",
            title: "First Scan",
            description: "Complete your very first skin scan",
            iconName: "checkmark.seal.fill",
            category: .scanning,
            isUnlocked: true,
            unlockedDate: Date()
        )
    )
}
