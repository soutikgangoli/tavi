//
//  MainTabView.swift
//  Ollvy
//
//  Bottom tab navigation with 5 tabs: Home, History, Scan, Insights, Profile
//  Created on 2025-01-10.
//

import SwiftUI
import CoreData

public struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @State private var showScanFlow: Bool = false

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
            // Tab content - keep all views instantiated for instant switching
            // Using ZStack with opacity instead of switch to prevent view recreation
            ZStack {
                // Home tab
                NavigationStack {
                    HomeView(selectedTab: $selectedTab, showScanFlow: $showScanFlow)
                }
                .environment(\.managedObjectContext, viewContext)
                .opacity(selectedTab == .home ? 1 : 0)
                .zIndex(selectedTab == .home ? 1 : 0)
                .allowsHitTesting(selectedTab == .home)

                // History tab
                NavigationStack {
                    ResultsHistoryView()
                }
                .environment(\.managedObjectContext, viewContext)
                .opacity(selectedTab == .history ? 1 : 0)
                .zIndex(selectedTab == .history ? 1 : 0)
                .allowsHitTesting(selectedTab == .history)

                // Scan tab placeholder
                Color.clear
                    .opacity(selectedTab == .scan ? 1 : 0)
                    .zIndex(selectedTab == .scan ? 1 : 0)
                    .allowsHitTesting(selectedTab == .scan)

                // Insights tab
                NavigationStack {
                    InsightsTabView()
                }
                .environment(\.managedObjectContext, viewContext)
                .opacity(selectedTab == .insights ? 1 : 0)
                .zIndex(selectedTab == .insights ? 1 : 0)
                .allowsHitTesting(selectedTab == .insights)

                // Profile tab
                NavigationStack {
                    ProfileTabView()
                }
                .environment(\.managedObjectContext, viewContext)
                .opacity(selectedTab == .profile ? 1 : 0)
                .zIndex(selectedTab == .profile ? 1 : 0)
                .allowsHitTesting(selectedTab == .profile)
            }
            .ignoresSafeArea(.keyboard) // Prevent tab bar from moving with keyboard

            // Custom tab bar overlay (on top) - hide when scan is shown
            if !showScanFlow {
                CustomTabBar(selectedTab: $selectedTab, showScanFlow: $showScanFlow)
                    .ignoresSafeArea(.keyboard)
                    .allowsHitTesting(true)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $showScanFlow) {
            NavigationStack {
                EmotionalScan3DFlowView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showScanFlow)
    }
}

// MARK: - Custom Tab Bar (Apple Liquid Glass Design)
// Floating glass tab bar with frosted blur effect and smooth animations

struct CustomTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    @Binding var showScanFlow: Bool

    @Namespace private var tabAnimation

    // Bright green accent color
    private let accentGreen = Designs.GentlerStreak.accentCoral
    private let textPrimary = Designs.GentlerStreak.textPrimary
    private let textSecondary = Color(red: 140/255, green: 140/255, blue: 145/255)

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Floating liquid glass tab bar
            HStack(spacing: 0) {
                // Tab 1: Home
                LiquidGlassTabButton(
                    icon: "house.fill",
                    label: "Home",
                    isSelected: selectedTab == .home,
                    namespace: tabAnimation,
                    accentColor: accentGreen,
                    secondaryColor: textSecondary
                ) {
                    selectTab(.home)
                }

                // Tab 2: History
                LiquidGlassTabButton(
                    icon: "clock.fill",
                    label: "History",
                    isSelected: selectedTab == .history,
                    namespace: tabAnimation,
                    accentColor: accentGreen,
                    secondaryColor: textSecondary
                ) {
                    selectTab(.history)
                }

                // Tab 3: Scan (Center floating button)
                LiquidGlassCenterButton(accentColor: accentGreen) {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    showScanFlow = true
                }

                // Tab 4: Insights
                LiquidGlassTabButton(
                    icon: "chart.bar.fill",
                    label: "Insights",
                    isSelected: selectedTab == .insights,
                    namespace: tabAnimation,
                    accentColor: accentGreen,
                    secondaryColor: textSecondary
                ) {
                    selectTab(.insights)
                }

                // Tab 5: Profile
                LiquidGlassTabButton(
                    icon: "person.fill",
                    label: "Profile",
                    isSelected: selectedTab == .profile,
                    namespace: tabAnimation,
                    accentColor: accentGreen,
                    secondaryColor: textSecondary
                ) {
                    selectTab(.profile)
                }
            }
            .frame(height: 72)
            .background(
                // Perfect Liquid Glass Effect
                ZStack {
                    // Base frosted glass
                    Capsule()
                        .fill(.ultraThinMaterial)

                    // Inner light refraction layer
                    Capsule()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.4), location: 0.0),
                                    .init(color: Color.white.opacity(0.15), location: 0.3),
                                    .init(color: Color.clear, location: 0.5),
                                    .init(color: Color.black.opacity(0.03), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(1)

                    // Specular highlight (top-left light source)
                    Capsule()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.0)
                                ],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .padding(2)

                    // Glass edge definition
                    Capsule()
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.7), location: 0.0),
                                    .init(color: Color.white.opacity(0.3), location: 0.4),
                                    .init(color: Color.white.opacity(0.15), location: 0.6),
                                    .init(color: Color.black.opacity(0.08), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.75
                        )
                }
                // Layered shadows for floating depth
                .shadow(color: Color.black.opacity(0.06), radius: 1, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(Color.clear)
    }

    private func selectTab(_ tab: MainTabView.Tab) {
        guard selectedTab != tab else { return }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selectedTab = tab
        }
    }
}

// MARK: - Liquid Glass Tab Button (Apple Vision Pro Style)

struct LiquidGlassTabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let accentColor: Color
    let secondaryColor: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: isSelected ? 22 : 20, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? accentColor : secondaryColor)
                    .shadow(color: isSelected ? accentColor.opacity(0.35) : .clear, radius: 5, x: 0, y: 0)
                    .frame(height: 26)

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? accentColor : secondaryColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                Group {
                    if isSelected {
                        // Perfect liquid glass pill
                        ZStack {
                            // White glass base
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color.white.opacity(0.98), location: 0.0),
                                            .init(color: Color.white.opacity(0.9), location: 0.4),
                                            .init(color: Color.white.opacity(0.8), location: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            // Top specular shine
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color.white, location: 0.0),
                                            .init(color: Color.white.opacity(0.5), location: 0.15),
                                            .init(color: Color.clear, location: 0.4)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .padding(.horizontal, 6)
                                .padding(.top, 1)
                                .padding(.bottom, 24)

                            // Subtle accent tint
                            Capsule()
                                .fill(accentColor.opacity(0.06))

                            // Inner depth shadow
                            Capsule()
                                .stroke(Color.black.opacity(0.04), lineWidth: 1.5)
                                .blur(radius: 0.5)
                                .padding(0.5)

                            // Crisp border with accent
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color.white, location: 0.0),
                                            .init(color: Color.white.opacity(0.6), location: 0.25),
                                            .init(color: accentColor.opacity(0.25), location: 0.75),
                                            .init(color: accentColor.opacity(0.35), location: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        }
                        .shadow(color: accentColor.opacity(0.12), radius: 6, x: 0, y: 2)
                        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
                        .matchedGeometryEffect(id: "selectedTab", in: namespace)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                    }
                }
            )
            .scaleEffect(isPressed ? 0.94 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isPressed { isPressed = true } }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Liquid Glass Center Button (Floating Scan Button)

struct LiquidGlassCenterButton: View {
    let accentColor: Color
    let action: () -> Void
    @State private var isPressed = false
    @State private var glowAnimation = false

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                // Outer glow ring (animated pulse)
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 62, height: 62)
                    .scaleEffect(glowAnimation ? 1.15 : 1.0)
                    .opacity(glowAnimation ? 0.0 : 0.6)

                // Glass outer ring
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 58, height: 58)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                // Inner green circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor,
                                accentColor.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .shadow(color: accentColor.opacity(0.5), radius: 12, x: 0, y: 4)
                    .overlay(
                        // Inner highlight
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                            .frame(width: 46, height: 46)
                    )

                // Camera icon
                Image(systemName: "camera.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            }
            .scaleEffect(isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                }
                .onEnded { _ in isPressed = false }
        )
        .onAppear {
            // Subtle continuous glow pulse
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
        }
    }
}

// MARK: - Segmented Tab Button (iOS Segmented Control Style) - Legacy

struct SegmentedTabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let accentColor: Color
    let secondaryColor: Color
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: isSelected ? 20 : 18, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? accentColor : secondaryColor)
                    .frame(height: 22)

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? accentColor : secondaryColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(accentColor.opacity(0.15))
                            .matchedGeometryEffect(id: "selectedTab", in: namespace)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Gentler Streak Style Tab Button

struct GentlerTabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let accentColor: Color
    let textColor: Color
    let secondaryColor: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: isSelected ? 22 : 20, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? accentColor : secondaryColor)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .frame(height: 24)

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? accentColor : secondaryColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(isPressed ? 0.85 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        // Bouncy animations
        .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: isSelected)
        .animation(.spring(response: 0.2, dampingFraction: 0.5, blendDuration: 0), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Gentler Streak Center Scan Button

struct GentlerCenterButton: View {
    let accentColor: Color
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                // Coral circle with subtle shadow
                Circle()
                    .fill(accentColor)
                    .frame(width: 48, height: 48)
                    .shadow(color: accentColor.opacity(0.35), radius: 10, x: 0, y: 4)

                // Camera icon
                Image(systemName: "camera.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.82 : 1.0)
            // Bouncy animation
            .animation(.spring(response: 0.25, dampingFraction: 0.45, blendDuration: 0), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Profile Tab (Gentler Streak Theme)

struct ProfileTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // PERFORMANCE: Limit fetch to most recent 100 sessions for stats
    // This balances accuracy with startup performance
    @FetchRequest(fetchRequest: ProfileTabView.sessionsFetchRequest)
    private var sessions: FetchedResults<SessionResult>

    private static var sessionsFetchRequest: NSFetchRequest<SessionResult> {
        let request = NSFetchRequest<SessionResult>(entityName: "SessionResult")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)]
        request.fetchLimit = 100  // Reasonable limit for stats calculation
        return request
    }

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

    // Gentler Streak theme colors
    private let gsBackground = Designs.GentlerStreak.background
    private let gsTextPrimary = Designs.GentlerStreak.textPrimary
    private let gsTextSecondary = Designs.GentlerStreak.textSecondary
    private let gsAccentCoral = Designs.GentlerStreak.accentCoral
    private let gsAccentTeal = Designs.GentlerStreak.accentTeal
    private let gsCardBackground = Designs.GentlerStreak.cardBackground

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 24) {
                // Profile header - Gentler Streak style
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(gsAccentCoral.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Text(String(userName.prefix(1)).uppercased())
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(gsAccentCoral)
                    }

                    Text(userName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(gsTextPrimary)

                    if !userEmail.isEmpty {
                        Text(userEmail)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(gsTextSecondary)
                    }
                }
                .padding(.top, 24)

                // Challenge card (if active)
                if let challenge = GamificationManager.shared.getCurrentChallenge(), challenge.isActive {
                    gentlerChallengeCard(challenge)
                }

                // Achievements horizontal carousel
                gentlerAchievementsCarousel

                // Stats section - Gentler Streak style
                VStack(alignment: .leading, spacing: 16) {
                    Text("Stats")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(gsTextPrimary)

                    if totalScans == 0 {
                        // Empty state for stats
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(gsAccentTeal.opacity(0.12))
                                    .frame(width: 60, height: 60)

                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(gsAccentTeal)
                            }

                            Text("No stats yet")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(gsTextPrimary)

                            Text("Complete your first scan to see your stats")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(gsTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(gsCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                    } else {
                        // Stats with data
                        VStack(spacing: 12) {
                            GentlerStatRow(label: "Total Scans", value: "\(totalScans)", accentColor: gsAccentCoral, textPrimary: gsTextPrimary, textSecondary: gsTextSecondary)
                            if currentStreak > 0 {
                                GentlerStatRow(label: "Current Streak", value: "\(currentStreak) days", icon: "flame.fill", iconColor: gsAccentCoral, accentColor: gsAccentCoral, textPrimary: gsTextPrimary, textSecondary: gsTextSecondary)
                            }
                            if longestStreak > 0 {
                                GentlerStatRow(label: "Longest Streak", value: "\(longestStreak) days", accentColor: gsAccentCoral, textPrimary: gsTextPrimary, textSecondary: gsTextSecondary)
                            }
                            GentlerStatRow(label: "Average Score", value: "\(Int(averageScore))", accentColor: gsAccentCoral, textPrimary: gsTextPrimary, textSecondary: gsTextSecondary)
                            GentlerStatRow(label: "Best Score", value: "\(Int(bestScore))", accentColor: gsAccentCoral, textPrimary: gsTextPrimary, textSecondary: gsTextSecondary)
                            if let improvement = thirtyDayImprovement {
                                GentlerStatRow(
                                    label: "30-Day Change",
                                    value: improvement > 0 ? "+\(Int(improvement))" : "\(Int(improvement))",
                                    icon: improvement > 0 ? "arrow.up.right" : "arrow.down.right",
                                    iconColor: improvement > 0 ? Designs.GentlerStreak.softGreen : Designs.GentlerStreak.softRed,
                                    accentColor: gsAccentCoral,
                                    textPrimary: gsTextPrimary,
                                    textSecondary: gsTextSecondary
                                )
                            }
                        }
                        .padding(16)
                        .background(gsCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Extra space for tab bar
        }
        .background(Color.white.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(gsAccentCoral.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(gsAccentCoral)
                    }
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

}

// MARK: - Gentler Streak Profile Helper Views

private struct GentlerStatRow: View {
    let label: String
    let value: String
    var icon: String? = nil
    var iconColor: Color? = nil
    let accentColor: Color
    let textPrimary: Color
    let textSecondary: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(textSecondary)

            Spacer()

            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor ?? textPrimary)
                }

                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor ?? textPrimary)
            }
        }
    }
}

// MARK: - Gentler Streak Challenge Card

extension ProfileTabView {
    func gentlerChallengeCard(_ challenge: GlowChallenge) -> some View {
        Button {
            showChallengeDetail = true
        } label: {
            VStack(spacing: 0) {
                // Coral header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("30-Day Skin Challenge")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Day \(challenge.daysCompleted) of 30")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()
                }
                .padding(16)
                .background(gsAccentCoral)

                // Progress section
                VStack(spacing: 12) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Designs.GentlerStreak.progressTrack)
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(gsAccentCoral)
                                .frame(
                                    width: geometry.size.width * CGFloat(challenge.progressPercentage) / 100,
                                    height: 8
                                )
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("\(Int(challenge.progressPercentage))% complete")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(gsTextSecondary)

                        Spacer()

                        if challenge.skinHealthImprovement > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .bold))
                                Text("+\(challenge.skinHealthImprovement) skin score")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(Designs.GentlerStreak.softGreen)
                        }
                    }
                }
                .padding(16)
                .background(gsCardBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    var gentlerAchievementsCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(gsTextPrimary)
                .padding(.horizontal, 20)

            let achievements = GamificationManager.shared.getAchievements()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(achievements, id: \.id) { achievement in
                        gentlerAchievementBadge(achievement)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, -20)
    }

    func gentlerAchievementBadge(_ achievement: Achievement) -> some View {
        Button {
            showAchievementDetail = achievement
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            achievement.isUnlocked
                            ? gsAccentCoral.opacity(0.15)
                            : gsTextSecondary.opacity(0.1)
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: achievement.iconName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(
                            achievement.isUnlocked
                            ? gsAccentCoral
                            : gsTextSecondary.opacity(0.4)
                        )

                    if achievement.isUnlocked {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(Designs.GentlerStreak.softGreen)
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                        .frame(width: 56, height: 56)
                    }
                }

                Text(achievement.title)
                    .font(.system(size: 12, weight: achievement.isUnlocked ? .semibold : .regular))
                    .foregroundColor(achievement.isUnlocked ? gsTextPrimary : gsTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 70, height: 32)
            }
            .frame(width: 80)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
