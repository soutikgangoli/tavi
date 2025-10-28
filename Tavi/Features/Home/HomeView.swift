//
//  HomeView.swift
//  Tavi
//
//  Consumer-friendly home screen with emotional design
//  Created on 2025-10-28.
//

import SwiftUI

/// Main home screen with emotional design and gamification
public struct HomeView: View {

    private let capabilities = DeviceCapabilities.current
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var currentChallenge: GlowChallenge?
    @State private var streak: GlowStreak = GamificationManager.shared.getStreak()
    @State private var recentAchievements: [Achievement] = []
    @State private var showScanFlow = false
    @State private var showShareSheet = false
    @State private var lastEmotionalMetrics: EmotionalMetrics?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)],
        animation: .default
    )
    private var sessions: FetchedResults<SessionResult>

    private var latestSession: SessionResult? {
        sessions.first
    }

    private var previousSession: SessionResult? {
        sessions.count > 1 ? sessions[1] : nil
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Welcome header
                welcomeHeader

                // Streak card
                streakCard

                // Active challenge card (if any)
                if let challenge = currentChallenge, !challenge.isCompleted {
                    challengeProgressCard(challenge)
                }

                // Quick action: Scan now
                scanNowCard

                // Recent achievements
                if !recentAchievements.isEmpty {
                    recentAchievementsSection
                }

                // Latest results summary
                if let latest = latestSession {
                    latestResultsCard(latest)
                }

                // Before/After comparison (if we have 2+ scans)
                if sessions.count >= 2,
                   let latest = latestSession,
                   let previous = previousSession,
                   let latestMetrics = decodeEmotionalMetrics(from: latest),
                   let previousMetrics = decodeEmotionalMetrics(from: previous) {
                    NavigationLink {
                        BeforeAfterView(
                            beforeMetrics: previousMetrics,
                            afterMetrics: latestMetrics,
                            beforeDate: previous.date ?? Date(),
                            afterDate: latest.date ?? Date()
                        )
                    } label: {
                        beforeAfterCTA
                    }
                }

                // Start challenge CTA (if no active challenge)
                if currentChallenge == nil {
                    startChallengeCTA
                }

                // History
                historySection

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Tavi")
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView()
        }
        .sheet(isPresented: $showScanFlow) {
            NavigationStack {
                EmotionalScan3DFlowView()
            }
        }
        .onAppear {
            loadGamificationData()
        }
    }

    // MARK: - Components

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            let userName = UserProfileManager.shared.loadProfile().name ?? "there"
            Text("Hey, \(userName)! 👋")
                .font(.largeTitle)
                .fontWeight(.bold)

            if streak.currentStreak > 0 {
                Text("Keep up your amazing streak!")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                Text("Ready for today's glow check?")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var streakCard: some View {
        HStack(spacing: 16) {
            // Streak emoji and count
            VStack(spacing: 4) {
                Text(streak.streakEmoji)
                    .font(.system(size: 48))

                Text("\(streak.currentStreak)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(streakColor)

                Text("Day Streak")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(height: 80)

            // Streak stats
            VStack(alignment: .leading, spacing: 8) {
                Text(streak.streakMessage)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    StatPill(label: "Best", value: "\(streak.longestStreak)")
                    StatPill(label: "Total", value: "\(streak.totalScans)")
                }

                if !streak.isActiveToday {
                    Text("Scan today to keep your streak!")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [streakColor.opacity(0.2), streakColor.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var streakColor: Color {
        switch streak.currentStreak {
        case 0: return .gray
        case 1...2: return .green
        case 3...6: return .orange
        case 7...13: return .blue
        case 14...29: return .purple
        default: return .pink
        }
    }

    private func challengeProgressCard(_ challenge: GlowChallenge) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🏆 30-Day Glow Challenge")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text("Day \(challenge.daysCompleted)/\(challenge.goalDays)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let milestone = challenge.nextMilestone {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(milestone.emoji)
                            .font(.title2)
                        Text("\(milestone.days - challenge.daysCompleted) to go")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.2))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * challenge.progressPercentage / 100, height: 12)
                }
            }
            .frame(height: 12)

            // Improvement
            HStack {
                Text("Glow Score:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(challenge.baselineGlowScore) → \(challenge.currentGlowScore)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if challenge.glowImprovement > 0 {
                    Text("+\(challenge.glowImprovement)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }

                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var scanNowCard: some View {
        Button {
            if capabilities.supportsTrueDepth {
                showScanFlow = true
            }
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ready for Your Scan?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Track your glow in just 60 seconds")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.blue, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
        }
        .disabled(!capabilities.supportsTrueDepth)
        .opacity(capabilities.supportsTrueDepth ? 1.0 : 0.5)
    }

    private var recentAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Achievements 🎉")
                .font(.title2)
                .fontWeight(.bold)

            ForEach(recentAchievements.prefix(3)) { achievement in
                AchievementRow(achievement: achievement)
            }
        }
    }

    private func latestResultsCard(_ session: SessionResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Latest Scan")
                .font(.title2)
                .fontWeight(.bold)

            NavigationLink {
                // Show full results
                ResultsDetailView(session: session)
            } label: {
                HStack(spacing: 16) {
                    // Score circle
                    ZStack {
                        Circle()
                            .stroke(scoreColor(session.overallScore).opacity(0.3), lineWidth: 6)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(from: 0, to: CGFloat(session.overallScore) / 100)
                            .stroke(scoreColor(session.overallScore), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))

                        Text("\(Int(session.overallScore))")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor(session.overallScore))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.relativeDate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Glow Score")
                            .font(.headline)

                        Text("Tap to view details")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
    }

    private var beforeAfterCTA: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("See Your Progress 📊")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Compare your before & after")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.right.circle.fill")
                .font(.title)
                .foregroundColor(.blue)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
        )
    }

    private var startChallengeCTA: some View {
        Button {
            // Start challenge with current/baseline score
            // For now, just create placeholder
            let baseline = latestSession?.overallScore ?? 50.0
            let challenge = GamificationManager.shared.startNewChallenge(baselineGlowScore: Int(baseline))
            currentChallenge = challenge
        } label: {
            VStack(spacing: 12) {
                Text("🏆")
                    .font(.system(size: 48))

                Text("Start 30-Day Glow Challenge")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Build healthy habits & watch your skin transform")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
            )
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                NavigationLink {
                    ResultsHistoryView()
                } label: {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("No scans yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Start your first scan to begin tracking!")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(sessions.prefix(3)) { session in
                    NavigationLink {
                        ResultsDetailView(session: session)
                    } label: {
                        CompactSessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadGamificationData() {
        streak = GamificationManager.shared.getStreak()
        currentChallenge = GamificationManager.shared.getCurrentChallenge()

        let achievements = GamificationManager.shared.getAchievements()
        recentAchievements = achievements
            .filter { $0.isUnlocked }
            .sorted { $0.unlockedDate ?? Date.distantPast > $1.unlockedDate ?? Date.distantPast }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .cyan
        case 60..<70: return .orange
        default: return .purple
        }
    }

    private func decodeEmotionalMetrics(from session: SessionResult) -> EmotionalMetrics? {
        guard let data = session.emotionalMetricsData else {
            return nil
        }
        return try? JSONDecoder().decode(EmotionalMetrics.self, from: data)
    }
}

// MARK: - Supporting Views

struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
    }
}

struct AchievementRow: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 12) {
            Text(achievement.emoji)
                .font(.title)

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.headline)

                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let date = achievement.unlockedDate {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.1))
        )
    }
}

struct CompactSessionRow: View {
    let session: SessionResult

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.relativeDate)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Score: \(Int(session.overallScore))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
