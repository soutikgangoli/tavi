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

    public init() {
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        _showOnboarding = State(initialValue: !hasCompleted)
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
        NavigationLink(value: session) {
            HStack(spacing: HeadspaceDesign.Spacing.lg) {
                // Score circle
                ZStack {
                    Circle()
                        .fill(scoreColor(session.overallScore).opacity(0.12))
                        .frame(width: 64, height: 64)

                    Text("\(Int(session.overallScore))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor(session.overallScore))
                }

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.relativeDate)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                    Text(scoreDescription(session.overallScore))
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.textTertiary)
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
        .buttonStyle(.plain)
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
}
