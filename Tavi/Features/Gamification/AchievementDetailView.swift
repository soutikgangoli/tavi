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
        VStack(spacing: HeadspaceDesign.Spacing.xl) {
            Spacer()

            // Large achievement icon
            ZStack {
                Circle()
                    .fill(
                        achievement.isUnlocked
                        ? HeadspaceDesign.Colors.primary.opacity(0.15)
                        : HeadspaceDesign.Colors.textSecondary.opacity(0.1)
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: achievement.iconName)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(
                        achievement.isUnlocked
                        ? HeadspaceDesign.Colors.primary
                        : HeadspaceDesign.Colors.textSecondary.opacity(0.4)
                    )

                // Unlock animation overlay if unlocked
                if achievement.isUnlocked {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    HeadspaceDesign.Colors.primary.opacity(0.5),
                                    HeadspaceDesign.Colors.primary.opacity(0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 136, height: 136)
                }
            }

            // Title and description
            VStack(spacing: HeadspaceDesign.Spacing.md) {
                Text(achievement.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(achievement.description)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, HeadspaceDesign.Spacing.xl)

            // Status section
            VStack(spacing: HeadspaceDesign.Spacing.md) {
                if achievement.isUnlocked {
                    // Unlocked state
                    if let unlockedDate = achievement.unlockedDate {
                        VStack(spacing: HeadspaceDesign.Spacing.sm) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Unlocked")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.green)

                            Text(formatUnlockDate(unlockedDate))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                        }
                        .padding(HeadspaceDesign.Spacing.lg)
                        .frame(maxWidth: .infinity)
                        .background(.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md))
                    }
                } else {
                    // Locked state
                    VStack(spacing: HeadspaceDesign.Spacing.sm) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Locked")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                        Text(getProgressText())
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    }
                    .padding(HeadspaceDesign.Spacing.lg)
                    .frame(maxWidth: .infinity)
                    .background(HeadspaceDesign.Colors.textSecondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md))
                }
            }
            .padding(.horizontal, HeadspaceDesign.Spacing.xl)

            Spacer()

            // Close button
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(HeadspaceDesign.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md))
            }
            .padding(.horizontal, HeadspaceDesign.Spacing.xl)
            .padding(.bottom, HeadspaceDesign.Spacing.xl)
        }
        .background(HeadspaceDesign.Colors.background)
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
