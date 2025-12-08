//
//  MainTabView.swift
//  Tavi
//
//  Bottom tab navigation with 5 tabs: Home, History, Scan, Insights, Profile
//  Created on 2025-01-10.
//

import SwiftUI
import CoreData

public struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @State private var showScanFlow = false
    
    // Use PersistenceController directly instead of reading from environment
    private var viewContext: NSManagedObjectContext {
        PersistenceController.shared.viewContext
    }

    public enum Tab: Hashable {
        case home
        case history
        case scan
        case insights
        case profile
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content - use custom view switcher instead of TabView
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack {
                        HomeView(selectedTab: $selectedTab, showScanFlow: $showScanFlow)
                    }
                    .environment(\.managedObjectContext, viewContext)
                    
                case .history:
                    NavigationStack {
                        ResultsHistoryView()
                    }
                    .environment(\.managedObjectContext, viewContext)
                    
                case .scan:
                    Color.clear
                    
                case .insights:
                    NavigationStack {
                        InsightsTabView()
                    }
                    .environment(\.managedObjectContext, viewContext)
                    
                case .profile:
                    NavigationStack {
                        ProfileTabView()
                    }
                    .environment(\.managedObjectContext, viewContext)
                }
            }
            .ignoresSafeArea(.keyboard) // Prevent tab bar from moving with keyboard
            .animation(Designs.Animation.quick, value: selectedTab)

            // Custom tab bar overlay (on top)
            CustomTabBar(selectedTab: $selectedTab, showScanFlow: $showScanFlow)
                .ignoresSafeArea(.keyboard)
                .allowsHitTesting(true)
        }
        .sheet(isPresented: $showScanFlow) {
            NavigationStack {
                EmotionalScan3DFlowView()
                    .environment(\.managedObjectContext, viewContext)
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
                icon: SFSymbol.chartBarFill,
                label: "History",
                isSelected: selectedTab == .history
            ) {
                withAnimation {
                    selectedTab = .history
                }
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
                icon: SFSymbol.lightbulbFill,
                label: "Insights",
                isSelected: selectedTab == .insights
            ) {
                withAnimation {
                    selectedTab = .insights
                }
            }
            .frame(maxWidth: .infinity)

            // Tab 5: Profile
            TabBarButton(
                icon: SFSymbol.personFill,
                label: "Profile",
                isSelected: selectedTab == .profile
            ) {
                selectedTab = .profile
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Designs.Spacing.xSmall)
        .padding(.top, Designs.Spacing.xSmall)
        .padding(.bottom, Designs.Spacing.large) // Safe area padding
        .background(
            Rectangle()
                .fill(Designs.Colors.background)
                .shadow(
                    color: Color.black.opacity(Designs.Opacity.veryLight / 2),
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
            VStack(spacing: Designs.Spacing.xxSmall) {
                Image(systemName: icon)
                    .font(isSelected ? AppFont.custom(size: 24, weight: .semibold) : AppFont.navIcon)
                    .foregroundColor(isSelected ? Designs.Colors.primary : Designs.Colors.textTertiary)

                Text(label)
                    .font(.app(size: 10, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? Designs.Colors.primary : Designs.Colors.textTertiary)
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
                    .fill(Designs.Colors.primary)
                    .frame(width: Designs.Sizes.tabBarIcon, height: Designs.Sizes.tabBarIcon)
                    .shadow(
                        color: Designs.Colors.primary.opacity(Designs.Opacity.light),
                        radius: isPressed ? 8 : 12,
                        x: 0,
                        y: isPressed ? 4 : 6
                    )

                Image(systemName: SFSymbol.cameraFill)
                    .font(AppFont.custom(size: 24, weight: .semibold))
                    .foregroundColor(Designs.Colors.secondary)
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(Designs.Animation.quick) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(Designs.Animation.quick) {
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
            VStack(alignment: .center, spacing: Designs.Spacing.xl) {
                // Profile header
                VStack(spacing: Designs.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Designs.Colors.primary.opacity(Designs.Opacity.veryLight))
                            .frame(width: Designs.Sizes.profileIcon, height: Designs.Sizes.profileIcon)

                        Text(String(userName.prefix(1)).uppercased())
                            .font(AppFont.scoreSmall)
                            .foregroundColor(Designs.Colors.primary)
                    }

                    Text(userName)
                        .font(AppFont.pageTitle)
                        .foregroundColor(Designs.Colors.textPrimary)

                    if !userEmail.isEmpty {
                        Text(userEmail)
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }
                }
                .padding(.top, Designs.Spacing.xl)

                // Challenge card (if active)
                if let challenge = GamificationManager.shared.getCurrentChallenge(), challenge.isActive {
                    challengeCard(challenge)
                }

                // Achievements horizontal carousel
                achievementsCarousel

                // Stats section
                VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                    Text("Stats")
                        .font(AppFont.headlineSecondary)
                        .foregroundColor(Designs.Colors.textPrimary)

                    VStack(spacing: Designs.Spacing.sm) {
                        StatRow(label: "Total Scans", value: "\(totalScans)")
                        StatRow(label: "Current Streak", value: currentStreak > 0 ? "\(currentStreak) days" : "-", icon: SFSymbol.flameFill, iconColor: Designs.Colors.secondary)
                        StatRow(label: "Longest Streak", value: longestStreak > 0 ? "\(longestStreak) days" : "-")
                        StatRow(label: "Average Score", value: totalScans > 0 ? "\(Int(averageScore))" : "-")
                        StatRow(label: "Best Score", value: totalScans > 0 ? "\(Int(bestScore))" : "-")
                        if let improvement = thirtyDayImprovement {
                            StatRow(
                                label: "30-Day Improvement",
                                value: improvement > 0 ? "+\(Int(improvement))" : "\(Int(improvement))",
                                icon: improvement > 0 ? SFSymbol.arrowUpRight : "arrow.down.right",
                                iconColor: improvement > 0 ? .green : .red
                            )
                        }
                    }
                    .padding(Designs.Spacing.lg)
                    .background(Designs.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
                }

                Spacer()
            }
            .padding(.horizontal, Designs.Spacing.lg)
            .padding(.bottom, 100) // Extra space for tab bar
        }
        .background(Designs.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: SFSymbol.gearshapeFill)
                        .font(AppFont.metricValue)
                        .foregroundColor(Designs.Colors.textSecondary)
                }
            }
        }
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
            VStack(spacing: Designs.Spacing.xxxSmall) {
                // Solid lavender header
                Designs.Colors.accent
                    .frame(height: Designs.Sizes.frameXXLarge)
                .overlay(
                    HStack(spacing: Designs.Spacing.md) {
                        Image(systemName: SFSymbol.flameFill)
                            .font(AppFont.scoreSmall)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: Designs.Spacing.xxSmall) {
                            Text("30-Day Glow Challenge")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(.white)

                            Text("Day \(challenge.daysCompleted) of 30")
                                .font(AppFont.caption)
                                .foregroundColor(.white.opacity(Designs.Opacity.almostOpaque))
                        }

                        Spacer()
                    }
                    .padding(Designs.Spacing.lg)
                )

                // Progress bar + stats
                VStack(spacing: Designs.Spacing.md) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: Designs.Radius.xSmall)
                                .fill(Color.gray.opacity(Designs.Opacity.light))
                                .frame(height: Designs.Sizes.progressIndicator)

                            RoundedRectangle(cornerRadius: Designs.Radius.xSmall)
                                .fill(Designs.Colors.accent)
                                .frame(
                                    width: geometry.size.width * CGFloat(challenge.progressPercentage) / 100,
                                    height: Designs.Sizes.progressIndicator
                                )
                        }
                    }
                    .frame(height: Designs.Sizes.progressIndicator)

                    HStack {
                        Text("\(Int(challenge.progressPercentage))% complete")
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textPrimary)

                        Spacer()

                        if challenge.skinHealthImprovement > 0 {
                            HStack(spacing: Designs.Spacing.xxSmall) {
                                Image(systemName: SFSymbol.arrowUpRight)
                                    .font(AppFont.custom(size: 11, weight: .bold))
                                Text("+\(challenge.skinHealthImprovement) skin health")
                                    .font(AppFont.footnote)
                            }
                            .foregroundColor(.green)
                        }
                    }
                }
                .padding(Designs.Spacing.lg)
                .background(Designs.Colors.cardBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
            .shadow(
                color: Designs.Shadows.card.color,
                radius: Designs.Shadows.card.radius,
                x: Designs.Shadows.card.x,
                y: Designs.Shadows.card.y
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Achievements Carousel

    private var achievementsCarousel: some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.md) {
            Text("Achievements")
                .font(AppFont.headlineSecondary)
                .foregroundColor(Designs.Colors.textPrimary)
                .padding(.horizontal, Designs.Spacing.lg)

            let achievements = GamificationManager.shared.getAchievements()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Designs.Spacing.md) {
                    ForEach(achievements, id: \.id) { achievement in
                        achievementBadgeCompact(achievement)
                    }
                }
                .padding(.horizontal, Designs.Spacing.lg)
            }
        }
        .padding(.horizontal, -Designs.Spacing.lg) // Offset container padding
    }

    private func achievementBadgeCompact(_ achievement: Achievement) -> some View {
        Button {
            showAchievementDetail = achievement
        } label: {
            VStack(spacing: Designs.Spacing.xSmall) {
                ZStack {
                    Circle()
                        .fill(
                            achievement.isUnlocked
                            ? Designs.ScoreColors.achievementGreenBackground.opacity(Designs.Opacity.light)
                            : Designs.Colors.textSecondary.opacity(Designs.Opacity.veryLight)
                        )
                        .frame(width: Designs.Sizes.iconLarge, height: Designs.Sizes.iconLarge)

                    Image(systemName: achievement.iconName)
                        .font(AppFont.custom(size: 24, weight: .semibold))
                        .foregroundColor(
                            achievement.isUnlocked
                            ? Designs.ScoreColors.achievementGreen
                            : Designs.Colors.textSecondary.opacity(Designs.Opacity.light)
                        )

                    // Unlocked checkmark badge
                    if achievement.isUnlocked {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(Designs.ScoreColors.achievementGreen)
                                    .frame(width: Designs.Sizes.badgeSmall, height: Designs.Sizes.badgeSmall)
                                    .overlay(
                                        Image(systemName: SFSymbol.checkmark)
                                            .font(AppFont.tabBar)
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                        .frame(width: Designs.Sizes.iconLarge, height: Designs.Sizes.iconLarge)
                    }
                }

                Text(achievement.title)
                    .font(AppFont.label)
                    .foregroundColor(
                        achievement.isUnlocked
                        ? Designs.Colors.textPrimary
                        : Designs.Colors.textSecondary
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: Designs.Sizes.frameMedium + 30, height: Designs.Sizes.frameSmall)
            }
            .frame(width: Designs.Sizes.frameXLarge)
        }
        .buttonStyle(PlainButtonStyle())
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
                .font(AppFont.bodySecondary)
                .foregroundColor(Designs.Colors.textSecondary)

            Spacer()

            HStack(spacing: Designs.Spacing.xxSmall) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(AppFont.metricLabel)
                        .foregroundColor(iconColor ?? Designs.Colors.textPrimary)
                }

                Text(value)
                    .font(AppFont.subheadingPrimary)
                    .foregroundColor(iconColor ?? Designs.Colors.textPrimary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
