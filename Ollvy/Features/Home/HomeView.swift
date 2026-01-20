//
//  HomeView.swift
//  Ollvy
//
//  Gentler Streak inspired home screen - warm, friendly, welcoming
//  Uses centralized Designs.GentlerStreak colors
//  Created on 2025-01-03
//

import SwiftUI
import CoreData

// MARK: - Color Alias for cleaner code
// Uses centralized Designs.GentlerStreak colors
private typealias HomeColors = Designs.GentlerStreak

/// Gentler Streak inspired home screen - warm, friendly design
public struct HomeView: View {

    @Environment(\.managedObjectContext) private var viewContext
    private let capabilities = DeviceCapabilities.current
    @Binding var selectedTab: MainTabView.Tab
    @Binding var showScanFlow: Bool
    @State private var showOnboarding: Bool
    @State private var showSettings = false
    @State private var showChallengeDetail = false
    @State private var errorState: ErrorState?
    @State private var selectedMetricType: UserMetricType?
    @State private var selectedSessionForDetail: SessionResult?
    @State private var expandedMetricName: String? = nil
    @State private var showAllScans: Bool = false  // Expand to show all scans in home view
    @AppStorage(AppDefaultsKey.skipOnboarding) private var skipOnboarding: Bool = false

    // Fallback storage support
    @StateObject private var fallbackStorage = FallbackStorage.shared
    @State private var fallbackSessions: [FallbackStorage.FallbackSession] = []

    public init(selectedTab: Binding<MainTabView.Tab>, showScanFlow: Binding<Bool>) {
        self._selectedTab = selectedTab
        self._showScanFlow = showScanFlow
        let hasCompleted = UserDefaults.standard.bool(forKey: AppDefaultsKey.hasCompletedOnboarding)
        let skipEnabled = UserDefaults.standard.bool(forKey: AppDefaultsKey.skipOnboarding)
        _showOnboarding = State(initialValue: !hasCompleted && !skipEnabled)
    }

    // Fetch all sessions - user can expand to see all on home view
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)],
        animation: .default
    )
    private var sessions: FetchedResults<SessionResult>

    private var latestSession: SessionResult? {
        return sessions.first
    }

    private var latestFallbackSession: FallbackStorage.FallbackSession? {
        return fallbackSessions.first
    }

    private var hasScans: Bool {
        return sessions.count > 0 || fallbackSessions.count > 0
    }

    private var hasCoreDataScans: Bool {
        return sessions.count > 0
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error, context: String) {
        AppLogger.ui.error("HomeView error (\(context)): \(error)")
        CrashReporter.shared.logError(error, context: ["view": "HomeView", "operation": context])
        errorState = ErrorState(
            message: "Unable to load your data. Please try again.",
            error: error
        )
    }

    private struct ErrorState {
        let message: String
        let error: Error
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let error = errorState {
                    errorView(error)
                } else {
                    contentView
                }
            }
            .onAppear {
                AnalyticsManager.shared.trackScreen("home")
                loadFallbackSessionsIfNeeded()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(HomeColors.accentCoral.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(HomeColors.accentCoral)
                        }
                    }
                    .accessibilityLabel(AppStrings.Accessibility.settingsButton)
                }
            }
            .navigationDestination(for: SessionResult.self) { session in
                ResultsDetailView(session: session)
            }
            .sheet(item: $selectedMetricType) { metricType in
                MetricDetailView(metricType: metricType)
            }
            .sheet(item: $selectedSessionForDetail) { (session: SessionResult) in
                // Guard: Only show detail if session is valid (not deleted/faulted)
                if !session.isDeleted && !session.isFault {
                    ResultsDetailView(session: session)
                        .onDisappear {
                            // Clear selection when sheet dismisses to prevent crash on deleted session
                            selectedSessionForDetail = nil
                        }
                } else {
                    // Session was deleted - show placeholder briefly before dismissing
                    Color.clear
                        .onAppear {
                            selectedSessionForDetail = nil
                        }
                }
            }
            .sheet(isPresented: $showChallengeDetail) {
                ChallengeDetailView()
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Content View
    // Different layouts based on scan count:
    // - 0 scans: First-time user experience (welcome + start journey)
    // - 1 scan: Baseline established (show score + encourage second scan)
    // - 2+ scans: Full experience (trends, comparisons, progress graph)

    private var contentView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Different layouts based on scan count
                switch sessions.count {
                case 0:
                    // FIRST TIME USER - Welcome experience
                    firstTimeUserView
                case 1:
                    // ONE SCAN - Baseline established
                    oneTimeUserView
                default:
                    // 2+ SCANS - Full experience with trends
                    returningUserView
                }

                // Bottom padding for tab bar
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.white.ignoresSafeArea())
    }

    // MARK: - First Time User (0 Scans) - Modern Gentler Streak Style

    private var firstTimeUserView: some View {
        VStack(spacing: 28) {
            // Welcome header with warm greeting
            welcomeHeader
                .padding(.top, 16)

            // Hero scan card - main CTA
            modernHeroScanCard

            // Feature highlights - compact pills
            featureHighlightsPills

            // How it works section
            howItWorksSection

            // Fallback storage support
            if fallbackSessions.count > 0 {
                fallbackRecentScansSection
            }
        }
    }

    // MARK: - Modern First-Time User Components

    /// Welcome header with personalized greeting
    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            let userName = UserProfileManager.shared.loadProfile().name ?? "there"

            // Large greeting with emoji
            Text("Welcome \(userName) 👋")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(HomeColors.textPrimary)

            // Main headline - single line, smaller font
            Text("Your Skin Journey Starts Here")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(HomeColors.textSecondary)

            // Subtext
            Text("Get personalized insights in under 60 seconds")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(HomeColors.textSecondary.opacity(0.8))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Modern hero scan card - clean and inviting
    private var modernHeroScanCard: some View {
        Button {
            showScanFlow = true
        } label: {
            VStack(spacing: 24) {
                // Icon with soft glow
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(HomeColors.accentCoral.opacity(0.08))
                        .frame(width: 120, height: 120)

                    // Inner circle
                    Circle()
                        .fill(HomeColors.accentCoral.opacity(0.15))
                        .frame(width: 88, height: 88)

                    // Icon
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(HomeColors.accentCoral)
                }

                // Text content
                VStack(spacing: 8) {
                    Text("Start Your First Scan")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(HomeColors.textPrimary)

                    Text("Discover your skin's unique profile")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(HomeColors.textSecondary)
                }

                // CTA Button - Bright light green
                HStack(spacing: 8) {
                    Text("Begin Scan")
                        .font(.system(size: 17, weight: .semibold))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(red: 72/255, green: 199/255, blue: 142/255)) // Bright light green
                )
                .shadow(color: Color(red: 72/255, green: 199/255, blue: 142/255).opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(HomeColors.cardBackground)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Feature highlights - 8 Metrics in card, other pills below
    private var featureHighlightsPills: some View {
        VStack(spacing: 16) {
            // 8 Metrics in a separate card box
            expandableMetricsCard
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(HomeColors.cardBackground)
                        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                )

            // Other feature pills in horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    featurePill(icon: "chart.line.uptrend.xyaxis", text: "Track Progress", color: HomeColors.softGreen)
                    featurePill(icon: "lightbulb.fill", text: "AI Insights", color: HomeColors.softYellow)
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, -20)
            .padding(.leading, 20)
        }
    }

    /// 8 Metrics section - 2 tags per row in a grid, tap to expand bubble
    private var expandableMetricsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("8 Skin Metrics")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(HomeColors.textPrimary)

            // 2-column grid of metric tags
            VStack(spacing: 10) {
                // Row 1
                HStack(spacing: 10) {
                    metricTag(icon: "waveform.path", name: "Smoothness", color: HomeColors.accentTeal,
                              description: "Measures skin texture uniformity by analyzing surface variation patterns.")
                    metricTag(icon: "drop.fill", name: "Hydration", color: HomeColors.softGreen,
                              description: "Estimates moisture levels by analyzing skin's light reflection and surface properties.")
                }
                // Row 2
                HStack(spacing: 10) {
                    metricTag(icon: "sparkles", name: "Glow", color: HomeColors.softYellow,
                              description: "Evaluates skin radiance and luminosity based on light diffusion patterns.")
                    metricTag(icon: "circle.hexagongrid.fill", name: "Evenness", color: HomeColors.accentCoral,
                              description: "Detects color variations and pigmentation irregularities across skin regions.")
                }
                // Row 3
                HStack(spacing: 10) {
                    metricTag(icon: "circle.fill", name: "Acne", color: HomeColors.softRed,
                              description: "Identifies active breakouts, inflammation, and blemish patterns.")
                    metricTag(icon: "sun.max.fill", name: "Sun Damage", color: HomeColors.softYellow,
                              description: "Assesses UV-related skin changes including dark spots and photo-aging signs.")
                }
                // Row 4
                HStack(spacing: 10) {
                    metricTag(icon: "heart.fill", name: "Redness", color: HomeColors.softRed,
                              description: "Measures skin redness and irritation levels in different facial zones.")
                    metricTag(icon: "circle.dotted", name: "Pores", color: HomeColors.accentTeal,
                              description: "Analyzes pore visibility and density, particularly in the T-zone area.")
                }
            }
        }
    }

    /// Metric tag - looks like simple pill tag, expands to curved square bubble on tap
    private func metricTag(icon: String, name: String, color: Color, description: String) -> some View {
        let isExpanded = expandedMetricName == name

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                if expandedMetricName == name {
                    expandedMetricName = nil
                } else {
                    expandedMetricName = name
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: isExpanded ? 8 : 0) {
                // Tag content (icon + name) - left aligned with fixed icon width
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(color)
                        .frame(width: 20, alignment: .center) // Fixed width for icon alignment

                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(HomeColors.textPrimary)

                    Spacer()
                }

                // Expanded description
                if isExpanded {
                    Text(description)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(HomeColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: isExpanded ? 16 : 12)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: isExpanded ? 16 : 12)
                            .stroke(HomeColors.textSecondary.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Individual feature pill
    private func featurePill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(HomeColors.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(HomeColors.cardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
    }

    /// How it works section - simple 3-step process
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How It Works")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(HomeColors.textPrimary)

            VStack(spacing: 0) {
                howItWorksStep(number: 1, icon: "camera.fill", title: "Scan", description: "Quick face scan using your camera", isLast: false)
                howItWorksStep(number: 2, icon: "cpu", title: "Analyze", description: "AI processes 8 skin metrics", isLast: false)
                howItWorksStep(number: 3, icon: "sparkles", title: "Discover", description: "Get personalized recommendations", isLast: true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(HomeColors.cardBackground)
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            )
        }
    }

    /// Individual step in how it works
    private func howItWorksStep(number: Int, icon: String, title: String, description: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Step indicator with line
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(HomeColors.accentCoral.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Text("\(number)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(HomeColors.accentCoral)
                }

                if !isLast {
                    Rectangle()
                        .fill(HomeColors.progressTrack)
                        .frame(width: 2, height: 32)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(HomeColors.accentTeal)

                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(HomeColors.textPrimary)
                }

                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(HomeColors.textSecondary)
            }
            .padding(.bottom, isLast ? 0 : 16)

            Spacer()
        }
    }

    // MARK: - One Scan User (Baseline Established) - Modern Design

    private var oneTimeUserView: some View {
        VStack(spacing: 28) {
            // Welcome header with score context
            oneScanWelcomeHeader
                .padding(.top, 16)

            // Score display card - modern style
            if let latest = latestSession {
                modernScoreCard(latest)
            }

            // Second scan encouragement - prominent CTA
            modernSecondScanCard

            // Quick insights preview
            quickInsightsPreview

            // Fallback storage support
            if fallbackSessions.count > 0 {
                fallbackRecentScansSection
            }
        }
    }

    // MARK: - Returning User (2+ Scans) - Modern Design

    private var returningUserView: some View {
        VStack(spacing: 28) {
            if let latest = latestSession {
                // Welcome header with progress context
                returningUserWelcomeHeader(session: latest)
                    .padding(.top, 16)

                // Score display card - modern style
                modernScoreCard(latest)

                // Quick action pills
                modernQuickActions

                // Recent activity section
                recentActivitySection

                // Progress graph (2+ scans)
                ProgressGraphView(sessions: Array(sessions))
            }
        }
    }

    // MARK: - Modern One-Scan Components

    /// Welcome header for one-scan users
    private var oneScanWelcomeHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            let userName = UserProfileManager.shared.loadProfile().name ?? "there"

            Text("Great job \(userName)! 🎉")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(HomeColors.textPrimary)

            Text("Your Baseline is Set")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(HomeColors.textSecondary)

            Text("Scan again to start tracking your skin's progress")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(HomeColors.textSecondary.opacity(0.8))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Welcome header for returning users (2+ scans)
    private func returningUserWelcomeHeader(session: SessionResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let userName = UserProfileManager.shared.loadProfile().name ?? "there"

            Text("Welcome back \(userName) 👋")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(HomeColors.textPrimary)

            Text(generateHeadline(for: session))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(HomeColors.textSecondary)

            if let trend = calculateTrend(for: session), trend != 0 {
                HStack(spacing: 6) {
                    Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                    Text(trend > 0 ? "+\(Int(trend))% from last scan" : "\(Int(trend))% from last scan")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(trend > 0 ? HomeColors.softGreen : HomeColors.softRed)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Modern score card - clean design matching first-time user style
    private func modernScoreCard(_ session: SessionResult) -> some View {
        VStack(spacing: 20) {
            // Score circle with glow
            ZStack {
                // Outer glow
                Circle()
                    .fill(scoreColor(session.overallScore).opacity(0.08))
                    .frame(width: 140, height: 140)

                // Inner circle
                Circle()
                    .fill(scoreColor(session.overallScore).opacity(0.15))
                    .frame(width: 110, height: 110)

                // Score text
                VStack(spacing: 2) {
                    Text("\(Int(session.overallScore))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(HomeColors.textPrimary)

                    Text("/ 100")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(HomeColors.textSecondary)
                }
            }

            // Label and date
            VStack(spacing: 6) {
                Text("Skin Analysis Score")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(HomeColors.textPrimary)

                Text("Scanned \(session.relativeDate.lowercased())")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(HomeColors.textSecondary)
            }

            // View details button
            Button {
                selectedSessionForDetail = session
            } label: {
                HStack(spacing: 8) {
                    Text("View Full Results")
                        .font(.system(size: 15, weight: .semibold))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(HomeColors.accentCoral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(HomeColors.accentCoral.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(HomeColors.cardBackground)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }

    /// Modern second scan encouragement card
    private var modernSecondScanCard: some View {
        Button {
            showScanFlow = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(HomeColors.accentTeal.opacity(0.15))
                        .frame(width: 52, height: 52)

                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(HomeColors.accentTeal)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Take Second Scan")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(HomeColors.textPrimary)

                    Text("See how your skin changes over time")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(HomeColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(HomeColors.textSecondary)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(HomeColors.cardBackground)
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Key metrics breakdown for one-scan users
    private var quickInsightsPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Results Breakdown")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(HomeColors.textPrimary)

            if let latest = latestSession, let metrics = latest.skinMetrics {
                VStack(spacing: 10) {
                    // Show top 3 key metrics from the scan
                    metricBreakdownRow(
                        name: "Smoothness",
                        score: Int(metrics.globalRoughnessScore),
                        icon: "waveform.path",
                        color: HomeColors.accentTeal
                    )
                    metricBreakdownRow(
                        name: "Hydration",
                        score: Int(metrics.hydrationEstimate?.overallScore ?? 0),
                        icon: "drop.fill",
                        color: HomeColors.softGreen
                    )
                    metricBreakdownRow(
                        name: "Evenness",
                        score: Int(metrics.globalPigmentationScore),
                        icon: "circle.hexagongrid.fill",
                        color: HomeColors.accentCoral
                    )

                    // View all metrics button
                    Button {
                        selectedSessionForDetail = latest
                    } label: {
                        HStack {
                            Text("View All 8 Metrics")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(HomeColors.accentCoral)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(HomeColors.accentCoral.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(HomeColors.cardBackground)
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                )
            } else {
                // Fallback if metrics not available
                VStack(spacing: 12) {
                    insightPreviewRow(icon: "chart.line.uptrend.xyaxis", title: "Track Progress", description: "Your second scan unlocks comparison charts", color: HomeColors.softGreen)
                    insightPreviewRow(icon: "lightbulb.fill", title: "Get Insights", description: "Personalized recommendations based on your data", color: HomeColors.softYellow)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(HomeColors.cardBackground)
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                )
            }
        }
    }

    /// Metric breakdown row with score bar
    private func metricBreakdownRow(name: String, score: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)

            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(HomeColors.textPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 90, alignment: .leading)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(HomeColors.progressTrack)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(score) / 100, height: 8)
                }
            }
            .frame(height: 8)

            Text("\(score)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(HomeColors.textPrimary)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }

    /// Individual insight preview row (fallback)
    private func insightPreviewRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(HomeColors.textPrimary)

                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(HomeColors.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Modern Returning User Components

    /// Quick actions as horizontal tags (like feature pills)
    private var modernQuickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // New Scan tag
                Button {
                    showScanFlow = true
                } label: {
                    actionTag(icon: "camera.viewfinder", text: "New Scan", color: HomeColors.accentCoral)
                }

                // Insights tag
                Button {
                    selectedTab = .insights
                } label: {
                    actionTag(icon: "chart.bar.fill", text: "Insights", color: HomeColors.softYellow)
                }

                // Compare tag (only if 2+ scans)
                if sessions.count >= 2 {
                    Button {
                        selectedTab = .history
                    } label: {
                        actionTag(icon: "arrow.left.arrow.right", text: "Compare", color: HomeColors.accentTeal)
                    }
                }

                // History tag
                Button {
                    selectedTab = .history
                } label: {
                    actionTag(icon: "clock.fill", text: "History", color: HomeColors.softGreen)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, -20)
        .padding(.leading, 20)
    }

    /// Simple action tag pill
    private func actionTag(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(HomeColors.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(HomeColors.cardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
    }

    /// Recent activity section for returning users
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Scans")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(HomeColors.textPrimary)

                Spacer()

                Button {
                    selectedTab = .history
                } label: {
                    Text("View All")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(HomeColors.accentCoral)
                }
            }

            VStack(spacing: 10) {
                ForEach(Array(sessions.prefix(3)), id: \.id) { session in
                    recentActivityRow(session)
                }
            }
        }
    }

    /// Individual recent activity row with more detail
    private func recentActivityRow(_ session: SessionResult) -> some View {
        Button {
            selectedSessionForDetail = session
        } label: {
            HStack(spacing: 14) {
                // Score badge
                ZStack {
                    Circle()
                        .fill(scoreColor(session.overallScore).opacity(0.12))
                        .frame(width: 48, height: 48)

                    Text("\(Int(session.overallScore))")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor(session.overallScore))
                }

                // Date and score context
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.relativeDate)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(HomeColors.textPrimary)

                    // Show key metric or comparison
                    if let previousSession = getPreviousSession(before: session) {
                        let change = session.overallScore - previousSession.overallScore
                        HStack(spacing: 4) {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                            Text(change >= 0 ? "+\(Int(change)) pts" : "\(Int(change)) pts")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(change >= 0 ? HomeColors.softGreen : HomeColors.softRed)
                    } else {
                        Text(formattedTime(session.date))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(HomeColors.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(HomeColors.textSecondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(HomeColors.cardBackground)
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Get previous session for comparison
    private func getPreviousSession(before session: SessionResult) -> SessionResult? {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }),
              index + 1 < sessions.count else {
            return nil
        }
        return sessions[index + 1]
    }

    /// Format time helper
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Legacy Greeting (kept for compatibility)

    private func gentlerGreetingSection(session: SessionResult) -> some View {
        returningUserWelcomeHeader(session: session)
    }

    // MARK: - Legacy Second Scan Card (redirects to modern)

    private var secondScanEncouragementCard: some View {
        modernSecondScanCard
    }

    // MARK: - Error View

    private func errorView(_ error: ErrorState) -> some View {
        VStack(spacing: 20) {
            Image(systemName: SFSymbol.exclamationTriangle)
                .font(.system(size: 60, weight: .regular))
                .foregroundColor(HomeColors.softYellow)

            Text(AppStrings.Errors.somethingWentWrong)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(HomeColors.textPrimary)

            Text(error.message)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(HomeColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                errorState = nil
            } label: {
                Text(AppStrings.Buttons.tryAgain)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 16)
                    .background(HomeColors.accentCoral)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top)
        }
        .padding()
        .background(HomeColors.background)
    }

    // MARK: - Gentler Streak Style Components

    /// Gentler Streak style greeting - "Hi Alex," with headline below
    private var gentlerGreetingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let userName = UserProfileManager.shared.loadProfile().name ?? "there"

            Text("Hi \(userName),")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(HomeColors.textSecondary)

            if hasCoreDataScans, let latest = latestSession {
                Text(generateHeadline(for: latest))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(HomeColors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Ready to Start Your\nSkin Journey?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(HomeColors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if hasCoreDataScans, let latest = latestSession {
                Text(generateSubheadline(for: latest))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(HomeColors.textSecondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Generate dynamic headline based on score
    private func generateHeadline(for session: SessionResult) -> String {
        let score = session.overallScore
        switch score {
        case 85...100: return "Your Skin is Glowing!"
        case 70..<85: return "Looking Good Today"
        case 50..<70: return "Room for Improvement"
        default: return "Time to Focus on Care"
        }
    }

    /// Generate subheadline with context
    private func generateSubheadline(for session: SessionResult) -> String {
        if let trend = calculateTrend(for: session), trend != 0 {
            if trend > 0 {
                return "Your skin improved by \(Int(trend))% since last scan."
            } else {
                return "Your skin needs a little extra care this week."
            }
        }
        return "Keep tracking to see your progress over time."
    }

    /// Main score card with segmented progress bar (Gentler Streak style)
    private func mainScoreCard(_ session: SessionResult) -> some View {
        VStack(spacing: 20) {
            // Segmented progress bar
            segmentedProgressBar(score: session.overallScore)

            // Score breakdown in white card
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Skin Analysis Score")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(HomeColors.textSecondary)

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(session.overallScore))")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(HomeColors.textPrimary)

                            Text("/ 100")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(HomeColors.textSecondary)
                        }
                    }

                    Spacer()

                    // View details button
                    Button {
                        selectedSessionForDetail = session
                    } label: {
                        Image(systemName: "eye")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(HomeColors.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(HomeColors.progressTrack)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(HomeColors.cardBackground)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            )
        }
    }

    /// Segmented progress bar like Gentler Streak
    private func segmentedProgressBar(score: Double) -> some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let segmentCount = 4
            let segmentWidth = (totalWidth - CGFloat(segmentCount - 1) * 4) / CGFloat(segmentCount)

            HStack(spacing: 4) {
                // Segment 1: Gray (low)
                RoundedRectangle(cornerRadius: 8)
                    .fill(score >= 25 ? HomeColors.progressTrack : HomeColors.progressTrack.opacity(0.5))
                    .frame(width: segmentWidth, height: 12)

                // Segment 2: Green (good)
                RoundedRectangle(cornerRadius: 8)
                    .fill(score >= 50 ? HomeColors.softGreen : HomeColors.progressTrack)
                    .frame(width: segmentWidth * 1.5, height: 12)

                // Segment 3: Yellow/Orange (medium) - longer
                RoundedRectangle(cornerRadius: 8)
                    .fill(score >= 75 ? HomeColors.softYellow : HomeColors.progressTrack)
                    .frame(width: segmentWidth, height: 12)

                // Segment 4: Red/Coral (needs attention) with warning icon
                ZStack(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(score < 50 ? HomeColors.softRed : HomeColors.progressTrack)
                        .frame(height: 12)

                    // Warning indicator at end if score is low
                    if score < 50 {
                        ZStack {
                            Circle()
                                .fill(HomeColors.softRed)
                                .frame(width: 24, height: 24)
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 12)
                    }
                }
                .frame(width: segmentWidth * 0.8)
            }
        }
        .frame(height: 24)
    }

    /// Quick action pills - "Today's Recommendations" style
    private var quickActionPills: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Recommendations")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(HomeColors.textPrimary)

            HStack(spacing: 12) {
                // Scan pill
                Button {
                    showScanFlow = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(HomeColors.accentTeal)
                        Text("New Scan")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(HomeColors.textPrimary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(HomeColors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(HomeColors.cardBackground)
                            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                    )
                }

                // History pill
                Button {
                    selectedTab = .history
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(HomeColors.accentCoral)
                        Text("History")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(HomeColors.textPrimary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(HomeColors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(HomeColors.cardBackground)
                            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                    )
                }
            }
        }
    }

    /// Wellness section - shows recent scans or first scan prompt
    private var wellnessSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Wellness")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(HomeColors.textPrimary)

                Spacer()

                if hasCoreDataScans {
                    Button {
                        // Options menu
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(HomeColors.textSecondary)
                    }
                }
            }

            if sessions.count > 0 {
                // Recent scans as wellness cards
                recentScansWellnessCards
            } else if fallbackSessions.count > 0 {
                fallbackRecentScansSection
            } else {
                // First scan card
                firstScanWellnessCard
            }
        }
    }

    /// Recent scans as Gentler Streak style wellness cards
    private var recentScansWellnessCards: some View {
        VStack(spacing: 12) {
            ForEach(Array(sessions.prefix(3)), id: \.id) { session in
                NavigationLink(value: session) {
                    wellnessCard(session)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // View all button - show if more than 3 scans
            if sessions.count > 3 {
                Button {
                    selectedTab = .history
                } label: {
                    Text("View All")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(HomeColors.accentCoral)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(HomeColors.cardBackground)
                                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                        )
                }
            }
        }
    }

    /// Individual wellness card
    private func wellnessCard(_ session: SessionResult) -> some View {
        HStack(spacing: 16) {
            // Title and date
            VStack(alignment: .leading, spacing: 4) {
                Text(session.relativeDate == "Today" ? "Today's Scan" : session.relativeDate)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(HomeColors.textPrimary)

                Text("Score: \(Int(session.overallScore))/100")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(HomeColors.textSecondary)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(HomeColors.textSecondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(HomeColors.cardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
    }

    /// First scan wellness card
    private var firstScanWellnessCard: some View {
        VStack(spacing: 16) {
            // Start Your Wellbeing Journey card
            Button {
                showScanFlow = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start Your")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(HomeColors.textPrimary)
                        Text("Skin Analysis Journey")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(HomeColors.textPrimary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(HomeColors.textSecondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(HomeColors.cardBackground)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Info card
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(HomeColors.accentCoral.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(HomeColors.accentCoral)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick & Easy")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(HomeColors.textPrimary)
                    Text("Your first scan takes under a minute")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(HomeColors.textSecondary)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(HomeColors.cardBackground)
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            )
        }
    }

    // MARK: - Legacy Components (keeping for compatibility)

    private var greetingSection: some View {
        gentlerGreetingSection
    }

    private var dateHeaderSection: some View {
        gentlerGreetingSection
    }

    /// Status widgets row (challenge + last scan info)
    private var statusWidgetsRow: some View {
        HStack(spacing: 16) {
            // Left: Challenge status
            challengeStatusWidget
                .frame(maxWidth: .infinity)

            // Right: Last scan info
            lastScanWidget
                .frame(maxWidth: .infinity)
        }
    }

    /// Challenge status widget
    private var challengeStatusWidget: some View {
        Group {
            if let challenge = GamificationManager.shared.getCurrentChallenge(), challenge.isActive {
                // Active challenge
                Button {
                    showChallengeDetail = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: SFSymbol.flameFill)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(HomeColors.accentCoral)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppStrings.Home.active)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(HomeColors.textPrimary)

                            let progress = Int((Double(challenge.daysCompleted) / Double(challenge.goalDays)) * 100)
                            Text("\(challenge.daysCompleted) \(AppStrings.Home.days) • \(progress)% done")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(HomeColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: SFSymbol.chevronDown)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(HomeColors.textSecondary)
                    }
                    .padding(16)
                    .background(HomeColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
            } else {
                // No active challenge - show start button
                Button {
                    startChallenge()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: SFSymbol.flameFill)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(HomeColors.accentCoral)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppStrings.Home.startChallenge)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(HomeColors.textPrimary)

                            Text(AppStrings.Home.thirtyDayGlow)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(HomeColors.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(HomeColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
            }
        }
    }

    /// Last scan info widget
    private var lastScanWidget: some View {
        HStack(spacing: 8) {
            Image(systemName: SFSymbol.calendar)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(HomeColors.accentTeal)

            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.Home.lastScan)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(HomeColors.textPrimary)

                if let lastScan = latestSession {
                    Text(formatRelativeDate(lastScan.date))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(HomeColors.textSecondary)
                } else {
                    Text(AppStrings.EmptyStates.noScansYet)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(HomeColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(HomeColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    /// Hero rings section - 1 large overall ring + 3 smaller metric rings
    private var heroRingsSection: some View {
        VStack(spacing: 20) {
            if let latest = latestSession {
                // Large Overall Score Ring
                Button {
                    selectedMetricType = .overall
                } label: {
                    largeHeroRing(
                        score: latest.overallScore,
                        label: AppStrings.Home.overallHealth,
                        color: HomeColors.accentCoral
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // 3 Smaller Metric Rings
                HStack(spacing: 16) {
                    // Ring 1: Smoothness
                    Button {
                        selectedMetricType = .smoothness
                    } label: {
                        smallHeroRing(
                            score: latest.textureAvg,
                            label: AppStrings.Metrics.smoothness,
                            color: HomeColors.softGreen
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Ring 2: Evenness
                    Button {
                        selectedMetricType = .pigmentation
                    } label: {
                        smallHeroRing(
                            score: latest.pigmentationAvg,
                            label: AppStrings.Metrics.evenness,
                            color: HomeColors.softYellow
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Ring 3: Radiance (from clinical metrics)
                    Button {
                        selectedMetricType = .overall  // Will open overall detail for now
                    } label: {
                        smallHeroRing(
                            score: getRadianceScore(from: latest),
                            label: "Radiance",
                            color: HomeColors.accentTeal
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // View All Metrics Button
                Button {
                    selectedSessionForDetail = latest
                } label: {
                    HStack {
                        Text(AppStrings.Home.viewAllMetrics)
                            .font(.system(size: 15, weight: .medium))

                        Image(systemName: SFSymbol.arrowRight)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(HomeColors.accentCoral)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(HomeColors.accentCoral.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 16)
    }

    /// Large hero ring for overall score
    private func largeHeroRing(score: Double, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 12)
                    .frame(width: 140, height: 140)

                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(score / 100))
                    .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: score)

                // Score text
                VStack(spacing: 2) {
                    Text("\(Int(score))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(HomeColors.textPrimary)

                    Text("%")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(HomeColors.textSecondary)
                }
            }

            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(HomeColors.textPrimary)
        }
    }

    /// Small hero ring for individual metrics
    private func smallHeroRing(score: Double, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                    .frame(width: 70, height: 70)

                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(score / 100))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: score)

                // Score text
                Text("\(Int(score))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(HomeColors.textPrimary)
            }

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(HomeColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    /// Extract radiance score from clinical metrics
    private func getRadianceScore(from session: SessionResult) -> Double {
        // Try to extract radiance from clinical metrics
        if let data = session.clinicalMetricsData {
            let result = VersionedMetricsLoader.loadFace3DMetrics(from: data)
            if let metrics = result.metrics,
               let glowAnalysis = metrics.glowAnalysis {
                return Double(glowAnalysis.radianceScore)
            }
        }

        // Fallback: use moistureSpecular as proxy for radiance (specular = shininess/glow)
        return session.moistureSpecular
    }

    /// Latest scan summary card
    private var latestScanSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let latest = latestSession {
                HStack {
                    Text(generateSummaryTitle(latest))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(HomeColors.textPrimary)

                    Spacer()

                    Button {
                        selectedSessionForDetail = latest
                    } label: {
                        Image(systemName: SFSymbol.arrowUpRight)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(HomeColors.accentCoral)
                    }
                }

                Text(generateSummaryText(latest))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(HomeColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("\(AppStrings.Home.overallScorePrefix) \(Int(latest.overallScore))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(HomeColors.textPrimary)

                    if let trend = calculateTrend(for: latest), trend != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: trend > 0 ? SFSymbol.arrowUpRight : "arrow.down.right")
                                .font(.system(size: 11, weight: .bold))
                            Text("\(trend > 0 ? "+" : "")\(Int(trend))")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(trend > 0 ? HomeColors.softGreen : HomeColors.softRed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((trend > 0 ? HomeColors.softGreen : HomeColors.softRed).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(20)
        .background(HomeColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    /// Start challenge action
    private func startChallenge() {
        guard let latest = latestSession else {
            return
        }

        // Use overall score as baseline for challenge
        _ = GamificationManager.shared.startNewChallenge(baselineSkinHealthScore: Int(latest.overallScore))
    }

    private func latestScanCard(_ session: SessionResult) -> some View {
        NavigationLink(value: session) {
            VStack(spacing: 0) {
                // Gentle gradient header (Gentler Streak style)
                ZStack {
                    LinearGradient(
                        colors: [gentlerScoreColor(session.overallScore), gentlerScoreColor(session.overallScore).opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 200)

                    VStack(spacing: 20) {
                        // Score circle
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 8)
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
                        .accessibilityLabel("Skin Analysis Score")
                        .accessibilityValue("\(Int(session.overallScore)) out of 100, \(scoreDescription(session.overallScore))")

                        Text("Your Skin Analysis Score")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .accessibilityHidden(true)
                    }
                }

                // White footer (Gentler Streak style)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Last scanned")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(HomeColors.textSecondary)

                            Text(session.relativeDate)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(HomeColors.textPrimary)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Text("View details")
                                .font(.system(size: 15, weight: .semibold))

                            Image(systemName: SFSymbol.chevronRight)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(HomeColors.accentCoral)
                    }
                }
                .padding(24)
                .background(HomeColors.cardBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    deleteSession(session)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityLabel("Latest scan from \(session.relativeDate)")
        .accessibilityHint("Tap to view complete results. Swipe left to delete.")
    }

    // MARK: - Legacy First Scan Card (kept for backwards compatibility)
    // The new modern design is in firstTimeUserView above

    private var firstScanCard: some View {
        // Redirect to modern design components
        VStack(spacing: 20) {
            modernHeroScanCard
            howItWorksSection
        }
    }

    private var recentScansSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(AppStrings.Home.recentScans)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(HomeColors.textPrimary)

                Spacer()

                // Show count badge if more than 5 scans
                if sessions.count > 5 {
                    Text("\(sessions.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(HomeColors.accentCoral)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(HomeColors.accentCoral.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            VStack(spacing: 16) {
                // Show 5 or all sessions based on expanded state
                let displayedSessions = showAllScans ? Array(sessions) : Array(sessions.prefix(5))
                ForEach(displayedSessions, id: \.id) { session in
                    recentScanListItem(session)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    deleteSession(session)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }

            // View More / Show Less button - only show if more than 5 scans
            if sessions.count > 5 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAllScans.toggle()
                    }
                } label: {
                    HStack {
                        Text(showAllScans ? "Show Less" : "View All")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(HomeColors.accentCoral)

                        Image(systemName: showAllScans ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(HomeColors.accentCoral)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(HomeColors.accentCoral.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func recentScanListItem(_ session: SessionResult) -> some View {
        NavigationLink(value: session) {
            HStack(alignment: .center, spacing: 16) {
                // Date badge (left corner) - compact
                VStack(spacing: 2) {
                    Text(formatDayMonth(session.date))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(HomeColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(formatYear(session.date))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(HomeColors.textSecondary)
                        .lineLimit(1)
                }
                .frame(width: 50, alignment: .center)
                .padding(.vertical, 8)
                .background(HomeColors.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Main content area
                VStack(alignment: .leading, spacing: 6) {
                    // First line: "Skin Score" label on left, score number on right
                    HStack(spacing: 8) {
                        Text(AppStrings.Home.skinScore)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(HomeColors.textSecondary)

                        Spacer()

                        Text("\(Int(session.overallScore))")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(gentlerScoreColor(session.overallScore))
                            .lineLimit(1)
                    }

                    // Second line: Date (e.g., "Today") on left, percentage in box on right
                    HStack(spacing: 8) {
                        Text(session.relativeDate)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(HomeColors.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        // Percentage in a box
                        HStack(spacing: 4) {
                            if let trend = calculateTrend(for: session), trend != 0 {
                                Image(systemName: trend > 0 ? SFSymbol.arrowUpRight : "arrow.down.right")
                                    .font(.system(size: 10, weight: .bold))
                                Text("\(trend > 0 ? "+" : "")\(Int(trend))%")
                                    .font(.system(size: 12, weight: .medium))
                            } else {
                                Text("\(Int(session.overallScore))%")
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }
                        .foregroundColor(gentlerScoreColor(session.overallScore))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(gentlerScoreColor(session.overallScore).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Chevron indicator
                Image(systemName: SFSymbol.chevronRight)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(HomeColors.textSecondary)
            }
            .frame(minHeight: 80)
            .padding(16)
            .background(HomeColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func activeChallengeCard(_ challenge: GlowChallenge) -> some View {
        VStack(spacing: 0) {
            // Coral header with white text and progress
            ZStack {
                HomeColors.accentCoral
                    .frame(height: 140)

                VStack(spacing: 16) {
                    // Title
                    HStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18, weight: .medium))
                        Text("30-Day Glow Challenge")
                            .font(.system(size: 18, weight: .semibold))
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
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            }

            // White info section
            VStack(alignment: .leading, spacing: 16) {
                // Progress bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(challenge.daysRemaining) days remaining")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(HomeColors.textPrimary)

                        Spacer()

                        Text("\(Int(challenge.progressPercentage))%")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(HomeColors.accentCoral)
                    }

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(HomeColors.progressTrack)
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(HomeColors.accentCoral)
                                .frame(width: geometry.size.width * CGFloat(challenge.progressPercentage) / 100, height: 8)
                        }
                    }
                    .frame(height: 8)
                }

                // Stats
                HStack(spacing: 20) {
                    // Glow improvement
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Glow Improvement")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(HomeColors.textSecondary)

                        HStack(spacing: 4) {
                            if challenge.skinHealthImprovement > 0 {
                                Image(systemName: SFSymbol.arrowUpRight)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(HomeColors.softGreen)
                            }
                            Text("\(challenge.skinHealthImprovement > 0 ? "+" : "")\(challenge.skinHealthImprovement)")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(challenge.skinHealthImprovement > 0 ? HomeColors.softGreen : HomeColors.textPrimary)
                        }
                    }

                    Divider()
                        .frame(height: 40)

                    // Next milestone
                    if let nextMilestone = challenge.nextMilestone {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next Milestone")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(HomeColors.textSecondary)

                            HStack(spacing: 6) {
                                Image(systemName: nextMilestone.iconName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(HomeColors.accentCoral)
                                Text(nextMilestone.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(HomeColors.textPrimary)
                            }
                        }
                    }
                }
            }
            .padding(24)
            .background(HomeColors.cardBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var tipsCard: some View {
        HStack(spacing: 20) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(HomeColors.softYellow.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: SFSymbol.lightbulbFill)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(HomeColors.softYellow)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Pro tip")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(HomeColors.textSecondary)

                Text("Scan in bright, natural light for best results")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(HomeColors.textPrimary)
            }

            Spacer()
        }
        .padding(24)
        .background(HomeColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Helpers

    private func getTimeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return AppStrings.Home.goodMorning
        case 12..<17: return AppStrings.Home.goodAfternoon
        default: return AppStrings.Home.goodEvening
        }
    }

    /// Gentler Streak style score color - softer, warmer colors
    /// - Below 30: Red (poor)
    /// - 30-70: Yellow (fair)
    /// - 70-89: Green (good)
    /// - 90-100: Bright green (excellent)
    private func gentlerScoreColor(_ score: Double) -> Color {
        switch score {
        case 90...100: return Color(red: 0.18, green: 0.82, blue: 0.35)  // Bright green (90-100)
        case 70..<90: return HomeColors.softGreen    // Green (70-89)
        case 30..<70: return HomeColors.softYellow   // Yellow (30-70)
        default: return HomeColors.softRed           // Red (below 30)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        // Use Gentler Streak colors for consistency
        return gentlerScoreColor(score)
    }

    private func scoreDescription(_ score: Double) -> String {
        switch score {
        case 90...100: return AppStrings.Home.excellentCondition
        case 80..<90: return AppStrings.Home.veryGoodCondition
        case 50..<80: return AppStrings.Home.goodCondition
        case 30..<50: return AppStrings.Home.needsImprovementCondition
        default: return AppStrings.Home.requiresAttention
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

        return scoreDiff // Return raw diff, not percentage
    }

    // Format relative date: "2 days ago", "Today", "Yesterday"
    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: date, to: now)

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let days = components.day, days > 0 {
            if days == 1 {
                return "Yesterday"
            } else if days < 7 {
                return "\(days) days ago"
            } else if days < 30 {
                let weeks = days / 7
                return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
        } else {
            return "Today"
        }
    }

    // Formatted today's date for header
    private var formattedTodayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: Date())
    }

    // Generate summary title based on score change
    private func generateSummaryTitle(_ session: SessionResult) -> String {
        if sessions.count == 1 {
            return AppStrings.Home.baselineScan
        }

        guard let trend = calculateTrend(for: session) else {
            return AppStrings.Home.latestScan
        }

        if trend > 5 {
            return AppStrings.Home.greatProgress
        } else if trend > 0 {
            return AppStrings.Home.goodProgress
        } else if trend == 0 {
            return AppStrings.Home.steadyProgress
        } else if trend > -5 {
            return AppStrings.Home.minorDecline
        } else {
            return AppStrings.Home.needsAttention
        }
    }

    // Generate summary text based on metric changes
    private func generateSummaryText(_ session: SessionResult) -> String {
        // Special case: first scan (baseline)
        if sessions.count == 1 {
            return AppStrings.Home.baselineScanDescription
        }

        // Get previous scan for comparison
        guard let index = sessions.firstIndex(where: { $0.id == session.id }),
              index < sessions.count - 1 else {
            return AppStrings.Home.latestResultsReady
        }

        let previousSession = sessions[index + 1]

        // Calculate changes for key metrics using ACTUAL SessionResult properties
        var improvements: [String] = []
        var declines: [String] = []

        // Smoothness (textureAvg)
        let smoothnessChange = session.textureAvg - previousSession.textureAvg
        if smoothnessChange > 2 {
            improvements.append("smoothness (+\(Int(smoothnessChange))%)")
        } else if smoothnessChange < -2 {
            declines.append("smoothness (\(Int(smoothnessChange))%)")
        }

        // Hydration (moistureSpecular)
        let hydrationChange = session.moistureSpecular - previousSession.moistureSpecular
        if hydrationChange > 2 {
            improvements.append("hydration (+\(Int(hydrationChange))%)")
        } else if hydrationChange < -2 {
            declines.append("hydration (\(Int(hydrationChange))%)")
        }

        // Evenness (pigmentationAvg)
        let evennessChange = session.pigmentationAvg - previousSession.pigmentationAvg
        if evennessChange > 2 {
            improvements.append("evenness (+\(Int(evennessChange))%)")
        } else if evennessChange < -2 {
            declines.append("evenness (\(Int(evennessChange))%)")
        }

        // Build summary text
        let relativeDate = formatRelativeDate(session.date)

        if !improvements.isEmpty {
            let improvementText = improvements.joined(separator: " and ")
            if !declines.isEmpty {
                let declineText = declines.joined(separator: " and ")
                return "Your latest scan from \(relativeDate) shows improvement in \(improvementText), but \(declineText) decreased."
            } else {
                return "Your latest scan from \(relativeDate) shows improvement in \(improvementText). Keep up your skincare routine!"
            }
        } else if !declines.isEmpty {
            let declineText = declines.joined(separator: " and ")
            return "Your latest scan from \(relativeDate) shows \(declineText) decreased. Consider adjusting your skincare routine."
        } else {
            return "Your skin metrics are stable from \(relativeDate). Maintain your current routine."
        }
    }

    // MARK: - Fallback Storage Support

    /// Load sessions from fallback storage if Core Data is unavailable
    private func loadFallbackSessionsIfNeeded() {
        // Only load from fallback if Core Data is empty or unavailable
        guard sessions.isEmpty || fallbackStorage.isUsingFallback else {
            AppLogger.ui.debug("Core Data has sessions - skipping fallback load")
            return
        }

        fallbackSessions = fallbackStorage.loadAllSessions()

        if !fallbackSessions.isEmpty {
            AppLogger.ui.info("✅ Loaded \(fallbackSessions.count) sessions from fallback storage")
        }
    }

    private var fallbackStorageNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: SFSymbol.infoCircleFill)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(HomeColors.accentTeal)

            VStack(alignment: .leading, spacing: 4) {
                Text("Showing Saved Results")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(HomeColors.textPrimary)

                Text("Your scan history is temporarily stored. Results are saved and will sync when available.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(HomeColors.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(HomeColors.accentTeal.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fallbackLatestScanCard(_ session: FallbackStorage.FallbackSession) -> some View {
        VStack(spacing: 0) {
            // Gentle gradient header (Gentler Streak style)
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        gentlerScoreColor(session.overallScore),
                        gentlerScoreColor(session.overallScore).opacity(0.7)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 120)

                VStack(spacing: 8) {
                    Text("Latest Scan")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))

                    Text("\(Int(session.overallScore))")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(scoreDescription(session.overallScore))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
            }

            // Content (white card)
            VStack(alignment: .leading, spacing: 16) {
                Text(session.relativeDate)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(HomeColors.textSecondary)

                Text("Tap 'Start New Scan' below to see your latest results and track progress")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(HomeColors.textSecondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(HomeColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Fallback Storage Views

    private var fallbackProgressChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Progress")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(HomeColors.textPrimary)

            // Simple line chart
            GeometryReader { geometry in
                let chartData = fallbackSessions.sorted { $0.date < $1.date }
                let maxScore = chartData.map { $0.overallScore }.max() ?? 100
                let minScore = chartData.map { $0.overallScore }.min() ?? 0
                let scoreRange = max(maxScore - minScore, 20) // At least 20 point range
                let width = geometry.size.width
                let height = geometry.size.height

                ZStack(alignment: .bottomLeading) {
                    // Grid lines
                    ForEach(0..<5) { i in
                        Path { path in
                            let y = CGFloat(i) * height / 4
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                        .stroke(HomeColors.progressTrack, lineWidth: 1)
                    }

                    // Line chart
                    Path { path in
                        for (index, session) in chartData.enumerated() {
                            let x = width * CGFloat(index) / CGFloat(max(chartData.count - 1, 1))
                            let normalizedScore = (session.overallScore - minScore) / scoreRange
                            let y = height * (1 - CGFloat(normalizedScore))

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(HomeColors.accentCoral, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    // Data points
                    ForEach(Array(chartData.enumerated()), id: \.element.id) { index, session in
                        let x = width * CGFloat(index) / CGFloat(max(chartData.count - 1, 1))
                        let normalizedScore = (session.overallScore - minScore) / scoreRange
                        let y = height * (1 - CGFloat(normalizedScore))

                        Circle()
                            .fill(gentlerScoreColor(session.overallScore))
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }
                }
            }
            .frame(height: 120)
            .padding(.vertical, 8)
        }
        .padding(20)
        .background(HomeColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private var fallbackRecentScansSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Recent scans")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(HomeColors.textPrimary)

            VStack(spacing: 16) {
                ForEach(Array(fallbackSessions.prefix(5)), id: \.id) { session in
                    fallbackScanListItem(session)
                }
            }
        }
    }

    private func fallbackScanListItem(_ session: FallbackStorage.FallbackSession) -> some View {
        HStack(alignment: .center, spacing: 20) {
            // Date badge - always show day/month number
            VStack(spacing: 4) {
                Text(formatDayNumber(session.date))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(HomeColors.textPrimary)

                Text(formatMonthShort(session.date))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(HomeColors.textSecondary)
            }
            .frame(width: 48)
            .padding(.vertical, 8)
            .background(HomeColors.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Score circle
            ZStack {
                Circle()
                    .fill(gentlerScoreColor(session.overallScore).opacity(0.15))
                    .frame(width: 64, height: 64)

                Text("\(Int(session.overallScore))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(gentlerScoreColor(session.overallScore))
            }
            .frame(width: 64, height: 64)

            // Info - show date and time
            VStack(alignment: .leading, spacing: 4) {
                Text(formatRelativeDateForFallback(session.date))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(HomeColors.textPrimary)

                Text(formatTime(session.date))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(HomeColors.textSecondary)
            }

            Spacer()

            Image(systemName: SFSymbol.chevronRight)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(HomeColors.textSecondary)
        }
        .padding(16)
        .background(HomeColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    /// Format time as "3:45 PM"
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Format just the day number (e.g., "5")
    private func formatDayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    /// Format just the month short name (e.g., "Nov")
    private func formatMonthShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    /// Format relative date: "Today", "Yesterday", or actual date like "3rd November"
    private func formatRelativeDateForFallback(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM"
            let monthName = formatter.string(from: date)

            // Add ordinal suffix (st, nd, rd, th)
            let day = calendar.component(.day, from: date)
            let suffix: String
            switch day {
            case 1, 21, 31: suffix = "st"
            case 2, 22: suffix = "nd"
            case 3, 23: suffix = "rd"
            default: suffix = "th"
            }
            return "\(day)\(suffix) \(monthName)"
        }
    }

    // MARK: - Session Management

    private func deleteSession(_ session: SessionResult) {
        // Guard against already deleted/faulted sessions to prevent crash
        guard !session.isDeleted && !session.isFault else {
            AppLogger.ui.warning("HomeView: Attempted to delete already deleted session")
            return
        }

        withAnimation {
            viewContext.delete(session)
            do {
                try viewContext.save()
            } catch {
                AppLogger.ui.error("HomeView: Failed to delete session - \(error)")
                CrashReporter.shared.logError(error, context: ["view": "HomeView", "operation": "deleteSession"])
            }
        }
    }
}
