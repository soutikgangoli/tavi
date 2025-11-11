//
//  MainTabView.swift
//  Tavi
//
//  Bottom tab navigation with 5 tabs: Home, History, Scan, Insights, Profile
//  Created on 2025-01-10.
//

import SwiftUI

public struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab: Tab = .home
    @State private var showScanFlow = false

    public enum Tab {
        case home
        case history
        case scan
        case insights
        case profile
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            TabView(selection: $selectedTab) {
                // Tab 1: Home
                NavigationStack {
                    HomeView(selectedTab: $selectedTab)
                }
                .tag(Tab.home)

                // Tab 2: History
                NavigationStack {
                    ResultsHistoryView()
                }
                .tag(Tab.history)

                // Tab 3: Scan (handled by center button, no content needed)
                Color.clear
                    .tag(Tab.scan)

                // Tab 4: Insights
                NavigationStack {
                    InsightsTabView()
                }
                .tag(Tab.insights)

                // Tab 5: Profile
                NavigationStack {
                    ProfileTabView()
                }
                .tag(Tab.profile)
            }
            .environment(\.managedObjectContext, viewContext)
            .tabViewStyle(.automatic)
            .ignoresSafeArea(.keyboard) // Prevent tab bar from moving with keyboard

            // Custom tab bar overlay
            CustomTabBar(selectedTab: $selectedTab, showScanFlow: $showScanFlow)
                .ignoresSafeArea(.keyboard)
        }
        .sheet(isPresented: $showScanFlow) {
            NavigationStack {
                EmotionalScan3DFlowView()
            }
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    @Binding var showScanFlow: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Tab 1: Home
            TabBarButton(
                icon: "house.fill",
                label: "Home",
                isSelected: selectedTab == .home
            ) {
                selectedTab = .home
            }
            .frame(maxWidth: .infinity)

            // Tab 2: History
            TabBarButton(
                icon: "chart.bar.fill",
                label: "History",
                isSelected: selectedTab == .history
            ) {
                selectedTab = .history
            }
            .frame(maxWidth: .infinity)

            // Tab 3: Scan (Center elevated button)
            CenterScanButton {
                showScanFlow = true
            }
            .frame(maxWidth: .infinity)
            .offset(y: -10) // Elevate above tab bar

            // Tab 4: Insights
            TabBarButton(
                icon: "lightbulb.fill",
                label: "Insights",
                isSelected: selectedTab == .insights
            ) {
                selectedTab = .insights
            }
            .frame(maxWidth: .infinity)

            // Tab 5: Profile
            TabBarButton(
                icon: "person.fill",
                label: "Profile",
                isSelected: selectedTab == .profile
            ) {
                selectedTab = .profile
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 20) // Safe area padding
        .background(
            Rectangle()
                .fill(HeadspaceDesign.Colors.background)
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 8,
                    x: 0,
                    y: -2
                )
        )
    }
}

// MARK: - Tab Bar Button

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? HeadspaceDesign.Colors.primary : HeadspaceDesign.Colors.textTertiary)

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? HeadspaceDesign.Colors.primary : HeadspaceDesign.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Center Scan Button

struct CenterScanButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(HeadspaceDesign.Colors.primary)
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: HeadspaceDesign.Colors.primary.opacity(0.4),
                        radius: isPressed ? 8 : 12,
                        x: 0,
                        y: isPressed ? 4 : 6
                    )

                Image(systemName: "camera.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.secondary)
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Profile Tab

struct ProfileTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)],
        predicate: nil,
        animation: .default
    )
    private var sessions: FetchedResults<SessionResult>

    @State private var showChallengeDetail = false
    @State private var showAchievementDetail: Achievement?
    @State private var showSettings = false
    @State private var showNotifications = false
    @State private var showPrivacy = false
    @State private var showAbout = false

    private var userName: String {
        UserProfileManager.shared.loadProfile().name ?? "User"
    }

    private var userEmail: String {
        UserProfileManager.shared.loadProfile().email ?? ""
    }

    private var totalScans: Int {
        sessions.count
    }

    private var averageScore: Double {
        guard !sessions.isEmpty else { return 0 }
        let sum = sessions.reduce(0.0) { $0 + $1.overallScore }
        return sum / Double(sessions.count)
    }

    private var bestScore: Double {
        sessions.map { $0.overallScore }.max() ?? 0
    }

    private var currentStreak: Int {
        GamificationManager.shared.getStreak().currentStreak
    }

    private var longestStreak: Int {
        GamificationManager.shared.getStreak().longestStreak
    }

    private var thirtyDayImprovement: Double? {
        guard sessions.count >= 2 else { return nil }
        let calendar = Calendar.current
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) else {
            return nil
        }

        let oldScans = sessions.filter { $0.date <= thirtyDaysAgo }
        guard let oldestRelevant = oldScans.last,
              let latest = sessions.first else {
            return nil
        }

        return latest.overallScore - oldestRelevant.overallScore
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: HeadspaceDesign.Spacing.xl) {
                // Profile header
                VStack(spacing: HeadspaceDesign.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(HeadspaceDesign.Colors.primary.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Text(String(userName.prefix(1)).uppercased())
                            .font(.gilroy(size: 36, weight: .bold))
                            .foregroundColor(HeadspaceDesign.Colors.primary)
                    }

                    Text(userName)
                        .font(.gilroy(size: 24, weight: .bold))
                        .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                    if !userEmail.isEmpty {
                        Text(userEmail)
                            .font(.gilroy(size: 14, weight: .regular))
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    }
                }
                .padding(.top, HeadspaceDesign.Spacing.xl)

                // Challenge card (if active)
                if let challenge = GamificationManager.shared.getCurrentChallenge(), challenge.isActive {
                    challengeCard(challenge)
                }

                // Achievements grid
                achievementsGrid

                // Stats section
                VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
                    Text("Stats")
                        .font(.gilroy(size: 18, weight: .bold))
                        .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                    VStack(spacing: HeadspaceDesign.Spacing.sm) {
                        StatRow(label: "Total Scans", value: "\(totalScans)")
                        StatRow(label: "Current Streak", value: currentStreak > 0 ? "\(currentStreak) days" : "-", icon: "flame.fill", iconColor: HeadspaceDesign.Colors.secondary)
                        StatRow(label: "Longest Streak", value: longestStreak > 0 ? "\(longestStreak) days" : "-")
                        StatRow(label: "Average Score", value: totalScans > 0 ? "\(Int(averageScore))" : "-")
                        StatRow(label: "Best Score", value: totalScans > 0 ? "\(Int(bestScore))" : "-")
                        if let improvement = thirtyDayImprovement {
                            StatRow(
                                label: "30-Day Improvement",
                                value: improvement > 0 ? "+\(Int(improvement))" : "\(Int(improvement))",
                                icon: improvement > 0 ? "arrow.up.right" : "arrow.down.right",
                                iconColor: improvement > 0 ? .green : .red
                            )
                        }
                    }
                    .padding(HeadspaceDesign.Spacing.lg)
                    .background(HeadspaceDesign.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
                }

                // Settings section
                VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
                    Text("Settings")
                        .font(.gilroy(size: 18, weight: .bold))
                        .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                    VStack(spacing: 0) {
                        SettingsRow(icon: "gearshape.fill", label: "Settings") {
                            showSettings = true
                        }
                        Divider().padding(.leading, 52)
                        SettingsRow(icon: "bell.fill", label: "Notifications") {
                            showNotifications = true
                        }
                        Divider().padding(.leading, 52)
                        SettingsRow(icon: "lock.fill", label: "Privacy & Data") {
                            showPrivacy = true
                        }
                        Divider().padding(.leading, 52)
                        SettingsRow(icon: "info.circle.fill", label: "About & Help") {
                            showAbout = true
                        }
                    }
                    .background(HeadspaceDesign.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
                }

                Spacer()
            }
            .padding(.horizontal, HeadspaceDesign.Spacing.lg)
            .padding(.bottom, 100) // Extra space for tab bar
        }
        .background(HeadspaceDesign.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showChallengeDetail) {
            ChallengeDetailView()
        }
        .sheet(item: $showAchievementDetail) { achievement in
            AchievementDetailView(achievement: achievement)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsSettingsView()
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacySettingsView()
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
    }

    // MARK: - Challenge Card

    private func challengeCard(_ challenge: GlowChallenge) -> some View {
        Button {
            showChallengeDetail = true
        } label: {
            VStack(spacing: 0) {
                // Solid lavender header
                HeadspaceDesign.Colors.accent
                    .frame(height: 100)
                .overlay(
                    HStack(spacing: HeadspaceDesign.Spacing.md) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("30-Day Glow Challenge")
                                .font(.gilroy(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            Text("Day \(challenge.daysCompleted) of 30")
                                .font(.gilroy(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }

                        Spacer()
                    }
                    .padding(HeadspaceDesign.Spacing.lg)
                )

                // Progress bar + stats
                VStack(spacing: HeadspaceDesign.Spacing.md) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(HeadspaceDesign.Colors.accent)
                                .frame(
                                    width: geometry.size.width * CGFloat(challenge.progressPercentage) / 100,
                                    height: 8
                                )
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("\(Int(challenge.progressPercentage))% complete")
                            .font(.gilroy(size: 14, weight: .semibold))
                            .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                        Spacer()

                        if challenge.glowImprovement > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .bold))
                                Text("+\(challenge.glowImprovement) glow")
                                    .font(.gilroy(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.green)
                        }
                    }
                }
                .padding(HeadspaceDesign.Spacing.lg)
                .background(HeadspaceDesign.Colors.cardBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
            .shadow(
                color: HeadspaceDesign.Shadows.card.color,
                radius: HeadspaceDesign.Shadows.card.radius,
                x: HeadspaceDesign.Shadows.card.x,
                y: HeadspaceDesign.Shadows.card.y
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Achievements Grid

    private var achievementsGrid: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            Text("Achievements")
                .font(.gilroy(size: 18, weight: .bold))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            let achievements = GamificationManager.shared.getAchievements()

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: HeadspaceDesign.Spacing.md),
                GridItem(.flexible(), spacing: HeadspaceDesign.Spacing.md)
            ], spacing: HeadspaceDesign.Spacing.md) {
                ForEach(achievements, id: \.id) { achievement in
                    achievementBadge(achievement)
                }
            }
        }
    }

    private func achievementBadge(_ achievement: Achievement) -> some View {
        Button {
            showAchievementDetail = achievement
        } label: {
            VStack(spacing: HeadspaceDesign.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(
                            achievement.isUnlocked
                            ? Color(red: 0.6, green: 0.9, blue: 0.7).opacity(0.2)  // Pastel green background
                            : HeadspaceDesign.Colors.textSecondary.opacity(0.1)
                        )
                        .frame(width: 64, height: 64)

                    Image(systemName: achievement.iconName)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(
                            achievement.isUnlocked
                            ? Color(red: 0.3, green: 0.8, blue: 0.5)  // Pastel green icon
                            : HeadspaceDesign.Colors.textSecondary.opacity(0.4)
                        )
                }

                Text(achievement.title)
                    .font(.gilroy(size: 14, weight: .semibold))
                    .foregroundColor(
                        achievement.isUnlocked
                        ? HeadspaceDesign.Colors.textPrimary
                        : HeadspaceDesign.Colors.textSecondary
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 36)

                if achievement.isUnlocked, let date = achievement.unlockedDate {
                    Text(formatUnlockDate(date))
                        .font(.gilroy(size: 11, weight: .regular))
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                } else {
                    Text("Locked")
                        .font(.gilroy(size: 11, weight: .regular))
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                }
            }
            .padding(HeadspaceDesign.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(HeadspaceDesign.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatUnlockDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Profile Helper Views

private struct StatRow: View {
    let label: String
    let value: String
    var icon: String? = nil
    var iconColor: Color? = nil

    var body: some View {
        HStack {
            Text(label)
                .font(.gilroy(size: 15, weight: .regular))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)

            Spacer()

            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor ?? HeadspaceDesign.Colors.textPrimary)
                }

                Text(value)
                    .font(.gilroy(size: 16, weight: .semibold))
                    .foregroundColor(iconColor ?? HeadspaceDesign.Colors.textPrimary)
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: HeadspaceDesign.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    .frame(width: 28)

                Text(label)
                    .font(.gilroy(size: 16, weight: .regular))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.textTertiary)
            }
            .padding(.vertical, HeadspaceDesign.Spacing.md)
            .padding(.horizontal, HeadspaceDesign.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
