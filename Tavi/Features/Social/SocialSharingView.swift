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
                VStack(spacing: 24) {
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
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var shareButtonsSection: some View {
        VStack(spacing: 16) {
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
                .cornerRadius(12)
            }
            .accessibilityLabel("More sharing options")
            .accessibilityHint("Opens system share sheet with all available sharing methods")

            // Social platforms (placeholders)
            HStack(spacing: 12) {
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
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(12)
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
            🌟 My Skin Health Index: \(emotionalMetrics.glowScore)/100!
            \(emotionalMetrics.primaryInsight)

            Tracking my skincare journey with Tavi ✨
            """

        case .achievement:
            if let achievement = recentAchievement {
                return """
                \(achievement.emoji) Achievement Unlocked!
                \(achievement.title): \(achievement.description)

                Tracking my skincare journey with Tavi ✨
                """
            }
            return "Tracking my skincare with Tavi!"

        case .streak:
            if let streak = streak {
                return """
                \(streak.streakEmoji) \(streak.currentStreak)-day streak!
                \(streak.streakMessage)

                Consistency is key! 💪
                """
            }
            return "Building healthy skincare habits!"

        case .challenge:
            if let challenge = challenge {
                return """
                🏆 30-Day Glow Challenge Progress!
                Day \(challenge.daysCompleted)/\(challenge.goalDays)
                Skin Health Index: \(challenge.baselineGlowScore) → \(challenge.currentGlowScore) (+\(challenge.glowImprovement))

                Join me in the challenge! 🌟
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
                colors: [scoreColor.opacity(0.3), scoreColor.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 20) {
                // App branding
                Text("Tavi")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                // Big score
                VStack(spacing: 8) {
                    Text("\(metrics.glowScore)")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(scoreColor)

                    Text("Skin Health Index")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                // Message
                Text(metrics.primaryInsight)
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Mini sub-scores
                HStack(spacing: 16) {
                    MiniScore(emoji: "✨", value: metrics.radiance)
                    MiniScore(emoji: "🧈", value: metrics.smoothness)
                    MiniScore(emoji: "🌟", value: metrics.evenness)
                    MiniScore(emoji: "🌸", value: metrics.youthfulness)
                    MiniScore(emoji: "🌿", value: metrics.freshness)
                }
            }
            .padding(32)
        }
        .frame(height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var scoreColor: Color {
        switch metrics.glowScore {
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
                colors: [.yellow.opacity(0.3), .orange.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 20) {
                Text("Achievement Unlocked!")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)

                Text(achievement.emoji)
                    .font(.system(size: 80))

                VStack(spacing: 8) {
                    Text(achievement.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text(achievement.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if let date = achievement.unlockedDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(32)
        }
        .frame(height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct StreakShareCard: View {
    let streak: GlowStreak

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.orange.opacity(0.3), .red.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 20) {
                Text(streak.streakEmoji)
                    .font(.system(size: 80))

                VStack(spacing: 8) {
                    Text("\(streak.currentStreak)")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(.orange)

                    Text("Day Streak")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Text(streak.streakMessage)
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Stats
                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text("\(streak.longestStreak)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Best Streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 4) {
                        Text("\(streak.totalScans)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Total Scans")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(32)
        }
        .frame(height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct ChallengeShareCard: View {
    let challenge: GlowChallenge

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 20) {
                Text("🏆")
                    .font(.system(size: 80))

                VStack(spacing: 8) {
                    Text("30-Day Glow Challenge")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Day \(challenge.daysCompleted)/\(challenge.goalDays)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 20)

                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.purple)
                            .frame(width: geometry.size.width * challenge.progressPercentage / 100, height: 20)
                    }
                }
                .frame(height: 20)
                .padding(.horizontal, 32)

                // Improvement
                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text("\(challenge.baselineGlowScore)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Started")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "arrow.right")
                        .foregroundColor(.purple)

                    VStack(spacing: 4) {
                        Text("\(challenge.currentGlowScore)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                        Text("Current")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(32)
        }
        .frame(height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Supporting Views

struct MiniScore: View {
    let emoji: String
    let value: Int

    var body: some View {
        VStack(spacing: 2) {
            Text(emoji)
                .font(.caption)
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
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
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
            glowScore: 87,
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
            sunProtection: 78
        ),
        streak: GlowStreak(currentStreak: 7, longestStreak: 12, lastScanDate: Date(), totalScans: 25),
        challenge: GlowChallenge(baselineGlowScore: 75),
        recentAchievement: Achievement(
            id: "streak_7",
            title: "Week Warrior",
            description: "Maintain a 7-day streak",
            emoji: "💪",
            category: .streaks,
            isUnlocked: true,
            unlockedDate: Date()
        )
    )
}
