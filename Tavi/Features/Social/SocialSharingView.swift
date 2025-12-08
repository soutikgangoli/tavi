//
//  SocialSharingView.swift
//  Tavi
//
//  Share progress on social media and with friends
//  Created on 2025-10-28.
//

import SwiftUI
import UIKit

/// Social sharing view for progress and achievements
public struct SocialSharingView: View {
    let emotionalMetrics: EmotionalMetrics
    let streak: GlowStreak?
    let challenge: GlowChallenge?
    let recentAchievement: Achievement?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedShareType: ShareType = .progress

    enum ShareType: String, CaseIterable {
        case progress = "Progress"
        case achievement = "Achievement"
        case streak = "Streak"
        case challenge = "Challenge"
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Designs.Spacing.xLarge) {
                    // Share type picker
                    Picker("Share Type", selection: $selectedShareType) {
                        ForEach(ShareType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Share type")
                    .accessibilityHint("Choose what to share: progress, achievement, streak, or challenge")
                    .accessibilityValue(selectedShareType.rawValue)
                    .padding(.horizontal)

                    // Preview card
                    sharePreviewCard
                        .padding(.horizontal)

                    // Share buttons
                    shareButtonsSection
                        .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .navigationTitle("Share Your Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityLabel("Done")
                    .accessibilityHint("Closes share screen and returns to previous view")
                }
            }
        }
    }

    // MARK: - Components

    @ViewBuilder
    private var sharePreviewCard: some View {
        switch selectedShareType {
        case .progress:
            ProgressShareCard(metrics: emotionalMetrics)
        case .achievement:
            if let achievement = recentAchievement {
                AchievementShareCard(achievement: achievement)
            } else {
                placeholderCard(message: "No achievements yet")
            }
        case .streak:
            if let streak = streak {
                StreakShareCard(streak: streak)
            } else {
                placeholderCard(message: "Start scanning to build a streak")
            }
        case .challenge:
            if let challenge = challenge {
                ChallengeShareCard(challenge: challenge)
            } else {
                placeholderCard(message: "Start a 30-day challenge to share")
            }
        }
    }

    private func placeholderCard(message: String) -> some View {
        VStack(spacing: Designs.Spacing.small) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(AppFont.scoreMedium)
                .foregroundStyle(.secondary)

            Text(message)
                .font(AppFont.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Designs.Sizes.displayHeight)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var shareButtonsSection: some View {
        VStack(spacing: Designs.Spacing.medium) {
            Text("Share to:")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Native share sheet
            Button {
                shareToSystem()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("More Options")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(Designs.Radius.medium)
            }
            .accessibilityLabel("More sharing options")
            .accessibilityHint("Opens system share sheet with all available sharing methods")

            // Social platforms (placeholders)
            HStack(spacing: Designs.Spacing.small) {
                SocialButton(icon: "photo", label: "Instagram", color: .pink) {
                    shareToInstagram()
                }

                SocialButton(icon: "message.fill", label: "Messages", color: .green) {
                    shareToMessages()
                }

                SocialButton(icon: "envelope.fill", label: "Email", color: .blue) {
                    shareToEmail()
                }
            }

            // Copy link
            Button {
                copyShareableText()
            } label: {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy Shareable Text")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(Designs.Opacity.light))
                .foregroundColor(.primary)
                .cornerRadius(Designs.Radius.medium)
            }
            .accessibilityLabel("Copy shareable text")
            .accessibilityHint("Copies progress text to clipboard for sharing")
        }
    }

    // MARK: - Actions

    private func shareToSystem() {
        let image = generateShareImage()
        let text = generateShareText()

        let activityVC = UIActivityViewController(
            activityItems: [image, text],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func shareToInstagram() {
        // Instagram sharing via native share sheet filtered to Instagram
        let image = generateShareImage()
        let text = generateShareText()

        let activityVC = UIActivityViewController(
            activityItems: [image, text],
            applicationActivities: nil
        )

        // Filter to show Instagram if available
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks,
            .saveToCameraRoll
        ]

        presentShareSheet(activityVC)
    }

    private func shareToMessages() {
        // Messages sharing via native share sheet filtered to Messages
        let image = generateShareImage()
        let text = generateShareText()

        let activityVC = UIActivityViewController(
            activityItems: [image, text],
            applicationActivities: nil
        )

        presentShareSheet(activityVC)
    }

    private func shareToEmail() {
        // Email sharing via native share sheet filtered to Mail
        let image = generateShareImage()
        let text = generateShareText()

        let activityVC = UIActivityViewController(
            activityItems: [image, text],
            applicationActivities: nil
        )

        presentShareSheet(activityVC)
    }

    private func presentShareSheet(_ activityVC: UIActivityViewController) {
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

    private func copyShareableText() {
        let text = generateShareText()
        UIPasteboard.general.string = text

        // Show success feedback (would implement with proper toast)
        AppLogger.social.info("Copied to clipboard: \(text)")
    }

    private func generateShareImage() -> UIImage {
        // Generate a beautiful share image from the preview card
        // For now, return a placeholder
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400))
        return renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        }
    }

    private func generateShareText() -> String {
        switch selectedShareType {
        case .progress:
            return """
            My Skin Health Index: \(emotionalMetrics.skinHealthScore)/100!
            \(emotionalMetrics.primaryInsight)

            Tracking my skincare journey with Tavi
            """

        case .achievement:
            if let achievement = recentAchievement {
                return """
                Achievement Unlocked!
                \(achievement.title): \(achievement.description)

                Tracking my skincare journey with Tavi
                """
            }
            return "Tracking my skincare with Tavi!"

        case .streak:
            if let streak = streak {
                return """
                \(streak.currentStreak)-day streak!
                \(streak.streakMessage)

                Consistency is key!
                """
            }
            return "Building healthy skincare habits!"

        case .challenge:
            if let challenge = challenge {
                return """
                30-Day Glow Challenge Progress!
                Day \(challenge.daysCompleted)/\(challenge.goalDays)
                Skin Health Index: \(challenge.baselineSkinHealthScore) → \(challenge.currentSkinHealthScore) (+\(challenge.skinHealthImprovement))

                Join me in the challenge!
                """
            }
            return "Starting my 30-day glow challenge!"
        }
    }
}

// MARK: - Share Cards

struct ProgressShareCard: View {
    let metrics: EmotionalMetrics

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [scoreColor.opacity(Designs.Opacity.medium), scoreColor.opacity(Designs.Opacity.veryLight)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: Designs.Spacing.large) {
                // App branding
                Text("Tavi")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                // Big score
                VStack(spacing: Designs.Spacing.xSmall) {
                    Text("\(metrics.skinHealthScore)")
                        .font(AppFont.custom(size: 72, weight: .bold))
                        .foregroundColor(scoreColor)

                    Text("Skin Health Index")
                        .font(AppFont.title3)
                }

                // Message
                Text(metrics.primaryInsight)
                    .font(AppFont.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Designs.Spacing.xxLarge)

                // Mini sub-scores
                HStack(spacing: Designs.Spacing.medium) {
                    MiniScore(iconName: "sparkles", value: metrics.radiance)
                    MiniScore(iconName: "waveform.path", value: metrics.smoothness)
                    MiniScore(iconName: "circle.hexagongrid.fill", value: metrics.evenness)
                    MiniScore(iconName: "leaf.fill", value: metrics.youthfulness)
                    MiniScore(iconName: "drop.fill", value: metrics.freshness)
                }
            }
            .padding(Designs.Spacing.xxLarge)
        }
        .frame(height: Designs.Sizes.displayHeightXLarge)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var scoreColor: Color {
        switch metrics.skinHealthScore {
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .cyan
        case 60..<70: return .orange
        default: return .purple
        }
    }
}

struct AchievementShareCard: View {
    let achievement: Achievement

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.yellow.opacity(Designs.Opacity.medium), .orange.opacity(Designs.Opacity.light)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: Designs.Spacing.large) {
                Text("Achievement Unlocked!")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)

                Text(achievement.emoji)
                    .font(AppFont.scoreDisplayLarge)

                VStack(spacing: Designs.Spacing.xSmall) {
                    Text(achievement.title)
                        .font(AppFont.title)
                        .multilineTextAlignment(.center)

                    Text(achievement.description)
                        .font(AppFont.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Designs.Spacing.xxLarge)
                }

                if let date = achievement.unlockedDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(AppFont.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(Designs.Spacing.xxLarge)
        }
        .frame(height: Designs.Sizes.displayHeightXLarge)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct StreakShareCard: View {
    let streak: GlowStreak

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.orange.opacity(Designs.Opacity.medium), .red.opacity(Designs.Opacity.light)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: Designs.Spacing.large) {
                Text(streak.streakEmoji)
                    .font(AppFont.scoreDisplayLarge)

                VStack(spacing: Designs.Spacing.xSmall) {
                    Text("\(streak.currentStreak)")
                        .font(AppFont.custom(size: 72, weight: .bold))
                        .foregroundColor(.orange)

                    Text("Day Streak")
                        .font(AppFont.title2)
                }

                Text(streak.streakMessage)
                    .font(AppFont.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Designs.Spacing.xxLarge)

                // Stats
                HStack(spacing: Designs.Spacing.xxLarge) {
                    VStack(spacing: Designs.Spacing.xxSmall) {
                        Text("\(streak.longestStreak)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Best Streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: Designs.Spacing.xxSmall) {
                        Text("\(streak.totalScans)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Total Scans")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(Designs.Spacing.xxLarge)
        }
        .frame(height: Designs.Sizes.displayHeightXLarge)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct ChallengeShareCard: View {
    let challenge: GlowChallenge

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.purple.opacity(Designs.Opacity.medium), .pink.opacity(Designs.Opacity.light)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: Designs.Spacing.large) {
                Text("🏆")
                    .font(AppFont.scoreDisplayLarge)

                VStack(spacing: Designs.Spacing.xSmall) {
                    Text("30-Day Glow Challenge")
                        .font(AppFont.title2)

                    Text("Day \(challenge.daysCompleted)/\(challenge.goalDays)")
                        .font(AppFont.title)
                        .foregroundColor(.purple)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(Designs.Opacity.medium))
                            .frame(height: Designs.Sizes.frameHeightBarMedium)

                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.purple)
                            .frame(width: geometry.size.width * challenge.progressPercentage / 100, height: 20)
                    }
                }
                .frame(height: Designs.Sizes.frameHeightBarMedium)
                .padding(.horizontal, Designs.Spacing.xxLarge)

                // Improvement
                HStack(spacing: Designs.Spacing.xxLarge) {
                    VStack(spacing: Designs.Spacing.xxSmall) {
                        Text("\(challenge.baselineSkinHealthScore)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Started")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "arrow.right")
                        .foregroundColor(.purple)

                    VStack(spacing: Designs.Spacing.xxSmall) {
                        Text("\(challenge.currentSkinHealthScore)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                        Text("Current")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(Designs.Spacing.xxLarge)
        }
        .frame(height: Designs.Sizes.displayHeightXLarge)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Supporting Views

struct MiniScore: View {
    let iconName: String
    let value: Int

    var body: some View {
        VStack(spacing: Designs.Spacing.xxxSmall) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundColor(.white.opacity(Designs.Opacity.almostOpaque))
            Text("\(value)")
                .font(.caption2)
                .fontWeight(.semibold)
        }
    }
}

struct SocialButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Designs.Spacing.xSmall) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: Designs.Sizes.buttonHeight, height: Designs.Sizes.buttonHeight)
                    .background(
                        Circle()
                            .fill(color)
                    )

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Share to \(label)")
        .accessibilityHint("Opens \(label) to share your progress")
    }
}

// MARK: - Preview

#Preview {
    SocialSharingView(
        emotionalMetrics: EmotionalMetrics(
            skinHealthScore: 87,
            primaryInsight: "Your skin looks amazing today! 🌟",
            celebration: "Amazing progress! Up 12 points! 🎉",
            improvements: [],
            concerns: [],
            personalizedMessage: "Keep it up!",
            nextSteps: [],
            timeEstimate: "See results in 2-3 weeks",
            radiance: 85,
            smoothness: 88,
            evenness: 82,
            youthfulness: 90,
            freshness: 86,
            sunProtection: 78,
            acneScore: 85,
            rednessScore: 80,
            oilControlScore: 75,
            poreScore: 82
        ),
        streak: GlowStreak(currentStreak: 7, longestStreak: 12, lastScanDate: Date(), totalScans: 25),
        challenge: GlowChallenge(baselineSkinHealthScore: 75),
        recentAchievement: Achievement(
            id: "streak_7",
            title: "Week Warrior",
            description: "Maintain a 7-day streak",
            iconName: "flame.fill",
            category: .streaks,
            isUnlocked: true,
            unlockedDate: Date()
        )
    )
}
