//
//  HomeView.swift
//  Tavi
//
//  Professional Headspace-inspired home screen
//  Created on 2025-01-03
//

import SwiftUI

/// Professional home screen matching Headspace's clean design
public struct HomeView: View {

    private let capabilities = DeviceCapabilities.current
    @State private var showOnboarding: Bool
    @State private var showScanFlow = false
    @State private var showSettings = false
    @AppStorage("skipOnboarding") private var skipOnboarding: Bool = false

    public init() {
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let skipEnabled = UserDefaults.standard.bool(forKey: "skipOnboarding")
        // Show onboarding only if not completed AND skip is not enabled
        _showOnboarding = State(initialValue: !hasCompleted && !skipEnabled)
    }

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)],
        animation: .default
    )
    private var sessions: FetchedResults<SessionResult>

    private var latestSession: SessionResult? {
        sessions.first
    }

    private var hasScans: Bool {
        sessions.count > 0
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: HeadspaceDesign.Spacing.xl) {
                        // Greeting header
                        greetingSection
                            .padding(.top, HeadspaceDesign.Spacing.md)

                        // Main scan card
                        if let latest = latestSession {
                            latestScanCard(latest)
                        } else {
                            firstScanCard
                        }

                        // Active challenge card
                        if let challenge = GamificationManager.shared.getCurrentChallenge(), challenge.isActive {
                            activeChallengeCard(challenge)
                        }

                        // Progress graph (shows if 2+ scans)
                        if sessions.count >= 2 {
                            ProgressGraphView(sessions: sessions)
                        }

                        // Recent scans
                        if hasScans {
                            recentScansSection
                        }

                        // Tips section
                        tipsCard

                        // Bottom padding for sticky button
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, HeadspaceDesign.Spacing.lg)
                }
                .background(HeadspaceDesign.Colors.background)

                // Sticky scan button
                stickyButton
            }
            .onAppear {
                // Track screen view
                AnalyticsManager.shared.trackScreen("home")
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    }
                }
            }
            .navigationDestination(for: SessionResult.self) { session in
                ResultsDetailView(session: session)
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView()
        }
        .sheet(isPresented: $showScanFlow) {
            NavigationStack {
                EmotionalScan3DFlowView()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Components

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.sm) {
            let userName = UserProfileManager.shared.loadProfile().name ?? "there"
            let greeting = getTimeBasedGreeting()

            Text("\(greeting), \(userName)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            Text("Track your skin health journey")
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func latestScanCard(_ session: SessionResult) -> some View {
        VStack(spacing: 0) {
            // Gradient header
            ZStack {
                HeadspaceDesign.Colors.warmGradient
                    .frame(height: 200)

                VStack(spacing: HeadspaceDesign.Spacing.lg) {
                    // Score circle
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 8)
                            .frame(width: 120, height: 120)

                        Circle()
                            .trim(from: 0, to: CGFloat(session.overallScore / 100))
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))

                        Text("\(Int(session.overallScore))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    Text("Your Skin Health Score")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                }
            }

            // White footer
            VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Last scanned")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                        Text(session.relativeDate)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                    }

                    Spacer()

                    NavigationLink(value: session) {
                        HStack(spacing: 6) {
                            Text("View details")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(HeadspaceDesign.Colors.primary)
                    }
                }
            }
            .padding(HeadspaceDesign.Spacing.xl)
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    private var firstScanCard: some View {
        VStack(spacing: 0) {
            // Gradient section
            HeadspaceDesign.Colors.peachGradient
                .frame(height: 220)
                .overlay(
                    VStack(spacing: HeadspaceDesign.Spacing.lg) {
                        Spacer()

                        Text("Start Your Skin Journey")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("Get your personalized skin health score")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                            .multilineTextAlignment(.center)

                        Spacer()
                    }
                    .padding(HeadspaceDesign.Spacing.xl)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    private var recentScansSection: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.lg) {
            Text("Recent scans")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            VStack(spacing: HeadspaceDesign.Spacing.md) {
                ForEach(Array(sessions.prefix(5)), id: \.id) { session in
                    recentScanListItem(session)
                }
            }
        }
    }

    private func recentScanListItem(_ session: SessionResult) -> some View {
        HStack(spacing: HeadspaceDesign.Spacing.lg) {
            // Date badge (left corner)
            VStack(spacing: 4) {
                Text(formatDayMonth(session.date))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text(formatYear(session.date))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }
            .frame(width: 48)
            .padding(.vertical, 8)
            .background(HeadspaceDesign.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Score circle
            ZStack {
                Circle()
                    .fill(scoreColor(session.overallScore).opacity(0.12))
                    .frame(width: 64, height: 64)

                Text("\(Int(session.overallScore))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor(session.overallScore))
            }

            // Info with trend indicator
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(session.relativeDate)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                    // Trend indicator
                    if let trend = calculateTrend(for: session) {
                        HStack(spacing: 4) {
                            Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                            Text("\(trend > 0 ? "+" : "")\(Int(trend))%")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(trend > 0 ? .green : .red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((trend > 0 ? Color.green : Color.red).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Text(scoreDescription(session.overallScore))
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }

            Spacer()

            // Action buttons (Compare or View)
            if session != latestSession {
                // For older scans: show Compare button
                HStack(spacing: 8) {
                    // Compare button (always compares with latest scan)
                    if let latest = latestSession {
                        NavigationLink {
                            Comparison3DView(
                                beforeSession: session,
                                afterSession: latest
                            )
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Compare")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(HeadspaceDesign.Colors.primary)
                            .frame(width: 60, height: 48)
                            .background(HeadspaceDesign.Colors.primary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // View button
                    NavigationLink(value: session) {
                        VStack(spacing: 2) {
                            Image(systemName: "eye")
                                .font(.system(size: 14, weight: .semibold))
                            Text("View")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(HeadspaceDesign.Colors.secondary)
                        .frame(width: 60, height: 48)
                        .background(HeadspaceDesign.Colors.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            } else {
                // For latest scan: just show arrow to view
                NavigationLink(value: session) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(HeadspaceDesign.Colors.textTertiary)
                }
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    private func activeChallengeCard(_ challenge: GlowChallenge) -> some View {
        VStack(spacing: 0) {
            // Gradient header with progress
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 255/255, green: 159/255, blue: 64/255),  // Orange
                        Color(red: 255/255, green: 102/255, blue: 102/255)  // Red-orange
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 140)

                VStack(spacing: HeadspaceDesign.Spacing.md) {
                    // Title
                    HStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20, weight: .bold))
                        Text("30-Day Glow Challenge")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)

                    // Progress circle
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 8)
                            .frame(width: 70, height: 70)

                        Circle()
                            .trim(from: 0, to: CGFloat(challenge.progressPercentage) / 100)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 70, height: 70)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 2) {
                            Text("\(challenge.daysCompleted)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("days")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            }

            // White info section
            VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
                // Progress bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(challenge.daysRemaining) days remaining")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                        Spacer()

                        Text("\(Int(challenge.progressPercentage))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.primary)
                    }

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 255/255, green: 159/255, blue: 64/255),
                                            Color(red: 255/255, green: 102/255, blue: 102/255)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(challenge.progressPercentage) / 100, height: 8)
                        }
                    }
                    .frame(height: 8)
                }

                // Stats
                HStack(spacing: HeadspaceDesign.Spacing.lg) {
                    // Glow improvement
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Glow Improvement")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                        HStack(spacing: 4) {
                            if challenge.glowImprovement > 0 {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            Text("\(challenge.glowImprovement > 0 ? "+" : "")\(challenge.glowImprovement)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(challenge.glowImprovement > 0 ? .green : HeadspaceDesign.Colors.textPrimary)
                        }
                    }

                    Divider()
                        .frame(height: 40)

                    // Next milestone
                    if let nextMilestone = challenge.nextMilestone {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next Milestone")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                            HStack(spacing: 6) {
                                Text(nextMilestone.emoji)
                                    .font(.system(size: 16))
                                Text(nextMilestone.title)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                            }
                        }
                    }
                }
            }
            .padding(HeadspaceDesign.Spacing.xl)
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    private var tipsCard: some View {
        HStack(spacing: HeadspaceDesign.Spacing.lg) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(HeadspaceDesign.Colors.accent.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(HeadspaceDesign.Colors.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Pro tip")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                Text("Scan in bright, natural light for best results")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)
            }

            Spacer()
        }
        .padding(HeadspaceDesign.Spacing.xl)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    private var stickyButton: some View {
        Button {
            if capabilities.supportsTrueDepth {
                AnalyticsManager.shared.trackAction("tap", target: "scan_now_button")
                AnalyticsManager.shared.trackNavigation(from: "home", to: "scan_flow")
                showScanFlow = true
            }
        } label: {
            HStack(spacing: HeadspaceDesign.Spacing.md) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 20, weight: .semibold))

                Text("Scan Now")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(HeadspaceDesign.Colors.primary)
            .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
            .shadow(
                color: HeadspaceDesign.Shadows.button.color,
                radius: HeadspaceDesign.Shadows.button.radius,
                x: HeadspaceDesign.Shadows.button.x,
                y: HeadspaceDesign.Shadows.button.y
            )
        }
        .padding(.horizontal, HeadspaceDesign.Spacing.lg)
        .padding(.bottom, HeadspaceDesign.Spacing.xxl)
    }

    // MARK: - Helpers

    private func getTimeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 90...100: return Color(red: 76/255, green: 217/255, blue: 100/255)      // Brightest green
        case 80..<90: return Color(red: 101/255, green: 188/255, blue: 126/255)     // Lighter green
        case 50..<80: return Color(red: 149/255, green: 218/255, blue: 176/255)     // Light green
        case 30..<50: return Color(red: 255/255, green: 204/255, blue: 0/255)       // Yellow
        default: return Color(red: 255/255, green: 59/255, blue: 48/255)            // Red
        }
    }

    private func scoreDescription(_ score: Double) -> String {
        switch score {
        case 90...100: return "Excellent condition"
        case 80..<90: return "Very good condition"
        case 50..<80: return "Good condition"
        case 30..<50: return "Needs improvement"
        default: return "Requires attention"
        }
    }

    // Date formatting helpers
    private func formatDayMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func formatYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }

    // Calculate trend compared to previous scan
    private func calculateTrend(for session: SessionResult) -> Double? {
        // Find the scan immediately before this one
        guard let index = sessions.firstIndex(where: { $0.id == session.id }),
              index < sessions.count - 1 else {
            return nil // No previous scan
        }

        let previousSession = sessions[index + 1]
        let scoreDiff = session.overallScore - previousSession.overallScore
        let percentChange = (scoreDiff / previousSession.overallScore) * 100

        return percentChange
    }
}
