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
    @Binding var selectedTab: MainTabView.Tab
    @State private var showOnboarding: Bool
    @State private var showSettings = false
    @State private var showChallengeDetail = false
    @State private var errorState: ErrorState?
    @State private var selectedMetricType: MetricType?
    @State private var selectedSessionForDetail: SessionResult?
    @AppStorage("skipOnboarding") private var skipOnboarding: Bool = false

    // Fallback storage support
    @StateObject private var fallbackStorage = FallbackStorage.shared
    @State private var fallbackSessions: [FallbackStorage.FallbackSession] = []

    public init(selectedTab: Binding<MainTabView.Tab>) {
        self._selectedTab = selectedTab
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
        return sessions.first
    }

    /// Latest scan from fallback storage (when Core Data is empty)
    private var latestFallbackSession: FallbackStorage.FallbackSession? {
        return fallbackSessions.first
    }

    private var hasScans: Bool {
        // Check both Core Data and fallback storage
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
                // Track screen view
                AnalyticsManager.shared.trackScreen("home")

                // Load fallback sessions if Core Data is unavailable
                loadFallbackSessionsIfNeeded()
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
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Opens app settings and preferences")
                }
            }
            .navigationDestination(for: SessionResult.self) { session in
                ResultsDetailView(session: session)
            }
            .sheet(item: $selectedMetricType) { metricType in
                MetricDetailView(metricType: metricType)
            }
            .sheet(item: $selectedSessionForDetail) { session in
                ResultsDetailView(session: session)
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

    private var contentView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: HeadspaceDesign.Spacing.lg) {
                // Header: Show date header if has scans, greeting if empty
                if hasCoreDataScans {
                    dateHeaderSection
                        .padding(.top, HeadspaceDesign.Spacing.md)
                } else {
                    greetingSection
                        .padding(.top, HeadspaceDesign.Spacing.md)
                }

                // Status widgets row: Only show if has scans
                if hasCoreDataScans {
                    statusWidgetsRow
                }

                // Hero rings: Only show if has scans
                if hasCoreDataScans {
                    heroRingsSection
                }

                // Latest scan summary: Only show if has scans
                if hasCoreDataScans {
                    latestScanSummaryCard
                }

                // Progress graph: Only show if 2+ scans
                if sessions.count >= 2 {
                    ProgressGraphView(sessions: Array(sessions))
                } else if fallbackSessions.count >= 2 {
                    fallbackProgressChart
                }

                // Active challenge card (old implementation - kept for fallback)
                if let challenge = GamificationManager.shared.getCurrentChallenge(), challenge.isActive, !hasCoreDataScans {
                    activeChallengeCard(challenge)
                }

                // Recent scans - main content
                if sessions.count > 0 {
                    recentScansSection
                } else if fallbackSessions.count > 0 {
                    fallbackRecentScansSection
                } else {
                    // Only show "first scan" card if NO scans exist
                    firstScanCard
                }

                // Bottom padding for tab bar
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, HeadspaceDesign.Spacing.lg)
        }
        .background(HeadspaceDesign.Colors.background)
    }

    // MARK: - Error View

    private func errorView(_ error: ErrorState) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.semibold)

            Text(error.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                errorState = nil
            } label: {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 16)
                    .background(HeadspaceDesign.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
            }
            .padding(.top)
        }
        .padding()
    }

    // MARK: - Components

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.sm) {
            let userName = UserProfileManager.shared.loadProfile().name ?? "there"
            let greeting = getTimeBasedGreeting()

            Text("\(greeting), \(userName)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            Text("Track your skin health journey")
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Date header for has-data state (replaces greeting)
    private var dateHeaderSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.xs) {
                Text("Today, \(formattedTodayDate)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text("Track your skin health journey")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }

            Spacer()

            // Profile icon
            Button {
                selectedTab = .profile
            } label: {
                ZStack {
                    Circle()
                        .fill(HeadspaceDesign.Colors.primary.opacity(0.15))
                        .frame(width: 44, height: 44)

                    if let userName = UserProfileManager.shared.loadProfile().name {
                        Text(String(userName.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.primary)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(HeadspaceDesign.Colors.primary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Status widgets row (challenge + last scan info)
    private var statusWidgetsRow: some View {
        HStack(spacing: HeadspaceDesign.Spacing.md) {
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
                    HStack(spacing: HeadspaceDesign.Spacing.sm) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(red: 255/255, green: 159/255, blue: 64/255))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Active")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                            let progress = Int((Double(challenge.daysCompleted) / Double(challenge.goalDays)) * 100)
                            Text("\(challenge.daysCompleted) days • \(progress)% done")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(HeadspaceDesign.Colors.textTertiary)
                    }
                    .padding(HeadspaceDesign.Spacing.md)
                    .background(HeadspaceDesign.Colors.elevatedCard)
                    .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md))
                }
            } else {
                // No active challenge - show start button
                Button {
                    startChallenge()
                } label: {
                    HStack(spacing: HeadspaceDesign.Spacing.sm) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(red: 255/255, green: 159/255, blue: 64/255))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start Challenge")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                            Text("30-Day Glow")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(HeadspaceDesign.Spacing.md)
                    .background(HeadspaceDesign.Colors.elevatedCard)
                    .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md))
                }
            }
        }
    }

    /// Last scan info widget
    private var lastScanWidget: some View {
        HStack(spacing: HeadspaceDesign.Spacing.sm) {
            Image(systemName: "calendar")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Last Scan")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                if let lastScan = latestSession {
                    Text(formatRelativeDate(lastScan.date))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                } else {
                    Text("No scans yet")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(HeadspaceDesign.Spacing.md)
        .background(HeadspaceDesign.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md))
    }

    /// Hero rings section - 1 large overall ring + 3 smaller metric rings
    private var heroRingsSection: some View {
        VStack(spacing: HeadspaceDesign.Spacing.lg) {
            if let latest = latestSession {
                // Large Overall Score Ring
                Button {
                    selectedMetricType = .overall
                } label: {
                    largeHeroRing(
                        score: latest.overallScore,
                        label: "Overall Health",
                        color: HeadspaceDesign.Colors.primary
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // 3 Smaller Metric Rings
                HStack(spacing: HeadspaceDesign.Spacing.md) {
                    // Ring 1: Smoothness
                    Button {
                        selectedMetricType = .smoothness
                    } label: {
                        smallHeroRing(
                            score: latest.textureAvg,
                            label: "Smoothness",
                            color: Color(red: 101/255, green: 188/255, blue: 126/255)  // Green
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Ring 2: Evenness
                    Button {
                        selectedMetricType = .pigmentation
                    } label: {
                        smallHeroRing(
                            score: latest.pigmentationAvg,
                            label: "Evenness",
                            color: Color(red: 252/255, green: 188/255, blue: 78/255)  // Yellow
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
                            color: Color(red: 255/255, green: 159/255, blue: 243/255)  // Pink
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // View All Metrics Button
                Button {
                    selectedSessionForDetail = latest
                } label: {
                    HStack {
                        Text("View All Metrics")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(HeadspaceDesign.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(HeadspaceDesign.Colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.sm))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, HeadspaceDesign.Spacing.md)
    }

    /// Large hero ring for overall score
    private func largeHeroRing(score: Double, label: String, color: Color) -> some View {
        VStack(spacing: HeadspaceDesign.Spacing.sm) {
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
                        .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                    Text("%")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                }
            }

            Text(label)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)
        }
    }

    /// Small hero ring for individual metrics
    private func smallHeroRing(score: Double, label: String, color: Color) -> some View {
        VStack(spacing: HeadspaceDesign.Spacing.xs) {
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
                    .animation(.easeInOut(duration: 0.8), value: score)

                // Score text
                Text("\(Int(score))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)
            }

            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
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
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            if let latest = latestSession {
                HStack {
                    Text(generateSummaryTitle(latest))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                    Spacer()

                    Button {
                        selectedSessionForDetail = latest
                    } label: {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(HeadspaceDesign.Colors.primary)
                    }
                }

                Text(generateSummaryText(latest))
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("Overall Score: \(Int(latest.overallScore))")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                    if let trend = calculateTrend(for: latest), trend != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 11, weight: .bold))
                            Text("\(trend > 0 ? "+" : "")\(Int(trend))")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(trend > 0 ? .green : .red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((trend > 0 ? Color.green : Color.red).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(HeadspaceDesign.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    /// Start challenge action
    private func startChallenge() {
        guard let latest = latestSession else {
            return
        }

        // Use overall score as baseline for challenge
        _ = GamificationManager.shared.startNewChallenge(baselineGlowScore: Int(latest.overallScore))
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
                    .accessibilityLabel("Skin Health Score")
                    .accessibilityValue("\(Int(session.overallScore)) out of 100, \(scoreDescription(session.overallScore))")

                    Text("Your Skin Health Score")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                        .accessibilityHidden(true)
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
                    .accessibilityLabel("View scan details")
                    .accessibilityHint("Shows complete results and metrics for your latest scan")
                }
            }
            .padding(HeadspaceDesign.Spacing.xl)
            .background(HeadspaceDesign.Colors.elevatedCard)
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
        VStack(spacing: HeadspaceDesign.Spacing.lg) {
            // Benefits Hero Card (COMPACT - fits on first screen)
            benefitsHeroCard

            // Challenge Invitation Card (NEW - fits on first screen)
            challengeInvitationCard

            // 8 Metrics Feature Cards
            metricsFeatureCards

            // Technology Card
            technologyCard

            // Pro Tips Card
            tipsCard
        }
    }

    /// Benefits Hero Card - highlights key user benefits (COMPACT for first screen)
    private var benefitsHeroCard: some View {
        VStack(spacing: 0) {
            // Gradient header (compact)
            HeadspaceDesign.Colors.peachGradient
                .frame(height: 100)
                .overlay(
                    VStack(spacing: HeadspaceDesign.Spacing.sm) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Discover Your Skin Health")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(HeadspaceDesign.Spacing.lg)
                )

            // Benefits list (compact - 2 benefits inline)
            HStack(spacing: HeadspaceDesign.Spacing.md) {
                compactBenefitBadge(icon: "chart.line.uptrend.xyaxis", text: "Track Progress")
                compactBenefitBadge(icon: "star.fill", text: "Personalized")
            }
            .padding(HeadspaceDesign.Spacing.lg)
            .background(HeadspaceDesign.Colors.elevatedCard)
        }
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    /// Compact benefit badge for inline display
    private func compactBenefitBadge(icon: String, text: String) -> some View {
        HStack(spacing: HeadspaceDesign.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(HeadspaceDesign.Colors.primary)

            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, HeadspaceDesign.Spacing.sm)
        .padding(.vertical, HeadspaceDesign.Spacing.sm)
        .background(HeadspaceDesign.Colors.primary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.sm))
    }

    /// Challenge Invitation Card - encourages users to start 30-day challenge
    private var challengeInvitationCard: some View {
        VStack(spacing: 0) {
            // Gradient header with flame icon
            LinearGradient(
                colors: [
                    Color(red: 255/255, green: 159/255, blue: 64/255),  // Orange
                    Color(red: 255/255, green: 102/255, blue: 102/255)  // Red-orange
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 90)
            .overlay(
                VStack(spacing: HeadspaceDesign.Spacing.sm) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text("30-Day Glow Challenge")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(HeadspaceDesign.Spacing.lg)
            )

            // Benefits and CTA
            VStack(spacing: HeadspaceDesign.Spacing.md) {
                // Quick benefits
                VStack(spacing: HeadspaceDesign.Spacing.sm) {
                    challengeBenefitRow(icon: "checkmark.circle.fill", text: "Track daily progress")
                    challengeBenefitRow(icon: "checkmark.circle.fill", text: "Unlock achievements")
                    challengeBenefitRow(icon: "checkmark.circle.fill", text: "See glow improvements")
                }

                // CTA Button
                Text("Complete your first scan to start")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, HeadspaceDesign.Spacing.sm)
            }
            .padding(HeadspaceDesign.Spacing.lg)
            .background(HeadspaceDesign.Colors.elevatedCard)
        }
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    /// Individual challenge benefit row
    private func challengeBenefitRow(icon: String, text: String) -> some View {
        HStack(spacing: HeadspaceDesign.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(red: 255/255, green: 159/255, blue: 64/255))

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            Spacer()
        }
    }

    /// Individual benefit row with icon and text
    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: HeadspaceDesign.Spacing.md) {
            ZStack {
                Circle()
                    .fill(HeadspaceDesign.Colors.primary.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text(description)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }

            Spacer()
        }
    }

    /// 8 Metrics Feature Cards - grid showing what the app measures
    private var metricsFeatureCards: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            Text("8 Skin Health Metrics")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            VStack(spacing: HeadspaceDesign.Spacing.md) {
                // Row 1
                HStack(spacing: HeadspaceDesign.Spacing.md) {
                    metricCard(icon: "waveform.path", title: "Smoothness", color: HeadspaceDesign.Colors.primary)
                    metricCard(icon: "drop.fill", title: "Hydration", color: Color(red: 95/255, green: 158/255, blue: 255/255))
                }

                // Row 2
                HStack(spacing: HeadspaceDesign.Spacing.md) {
                    metricCard(icon: "sparkles", title: "Glow", color: Color(red: 252/255, green: 188/255, blue: 78/255))
                    metricCard(icon: "circle.hexagongrid.fill", title: "Pigmentation", color: Color(red: 200/255, green: 140/255, blue: 100/255))
                }

                // Row 3
                HStack(spacing: HeadspaceDesign.Spacing.md) {
                    metricCard(icon: "circle.fill", title: "Acne", color: Color(red: 255/255, green: 102/255, blue: 102/255))
                    metricCard(icon: "sun.max.fill", title: "Sun Damage", color: Color(red: 255/255, green: 159/255, blue: 64/255))
                }

                // Row 4
                HStack(spacing: HeadspaceDesign.Spacing.md) {
                    metricCard(icon: "heart.fill", title: "Redness", color: Color(red: 255/255, green: 82/255, blue: 82/255))
                    metricCard(icon: "square.grid.3x3.fill", title: "Roughness", color: Color(red: 149/255, green: 165/255, blue: 166/255))
                }
            }
        }
    }

    /// Individual metric card
    private func metricCard(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: HeadspaceDesign.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HeadspaceDesign.Spacing.lg)
        .background(HeadspaceDesign.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    /// Technology/Features Card
    private var technologyCard: some View {
        VStack(spacing: 0) {
            // Gradient header
            HeadspaceDesign.Colors.coolGradient
                .frame(height: 120)
                .overlay(
                    VStack(spacing: HeadspaceDesign.Spacing.sm) {
                        Image(systemName: "camera.metering.center.weighted")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Advanced 3D Face Scanning")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(HeadspaceDesign.Spacing.xl)
                )

            // Features list
            VStack(spacing: HeadspaceDesign.Spacing.md) {
                featureHighlight(icon: "rotate.3d", text: "5-pose capture for complete coverage")
                featureHighlight(icon: "checkmark.seal.fill", text: "Clinical-grade accuracy (83-92%)")
                featureHighlight(icon: "lock.shield.fill", text: "Privacy-first • Data stays on device")
            }
            .padding(HeadspaceDesign.Spacing.xl)
            .background(HeadspaceDesign.Colors.elevatedCard)
        }
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    /// Individual feature highlight
    private func featureHighlight(icon: String, text: String) -> some View {
        HStack(spacing: HeadspaceDesign.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(HeadspaceDesign.Colors.secondary)
                .frame(width: 28)

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
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

            // View All button - only show if more than 5 scans
            if sessions.count > 5 {
                Button {
                    selectedTab = .history
                } label: {
                    HStack {
                        Text("View All Scans (\(sessions.count))")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.primary)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(HeadspaceDesign.Colors.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(HeadspaceDesign.Colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md))
                }
            }
        }
    }

    private func recentScanListItem(_ session: SessionResult) -> some View {
        HStack(alignment: .center, spacing: HeadspaceDesign.Spacing.lg) {
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
            .frame(width: 64, height: 64)

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
                        .accessibilityLabel("Compare with latest scan")
                        .accessibilityHint("Shows side-by-side comparison of this scan with your most recent scan")
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
                    .accessibilityLabel("View scan details")
                    .accessibilityHint("Opens detailed results for this scan")
                }
            } else {
                // For latest scan: just show arrow to view
                NavigationLink(value: session) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(HeadspaceDesign.Colors.textTertiary)
                }
                .accessibilityLabel("View latest scan")
                .accessibilityHint("Opens detailed results for your most recent scan")
            }
        }
        .frame(minHeight: 100)
        .padding(HeadspaceDesign.Spacing.lg)
        .background(HeadspaceDesign.Colors.elevatedCard)
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
                                Image(systemName: nextMilestone.iconName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(HeadspaceDesign.Colors.primary)
                                Text(nextMilestone.title)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                            }
                        }
                    }
                }
            }
            .padding(HeadspaceDesign.Spacing.xl)
            .background(HeadspaceDesign.Colors.elevatedCard)
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
        .background(HeadspaceDesign.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color,
            radius: HeadspaceDesign.Shadows.card.radius,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
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
            return "Baseline Scan"
        }

        guard let trend = calculateTrend(for: session) else {
            return "Latest Scan"
        }

        if trend > 5 {
            return "Great Progress!"
        } else if trend > 0 {
            return "Good Progress"
        } else if trend == 0 {
            return "Steady Progress"
        } else if trend > -5 {
            return "Minor Decline"
        } else {
            return "Needs Attention"
        }
    }

    // Generate summary text based on metric changes
    private func generateSummaryText(_ session: SessionResult) -> String {
        // Special case: first scan (baseline)
        if sessions.count == 1 {
            return "This is your baseline scan. Complete another scan to track progress and see improvements over time."
        }

        // Get previous scan for comparison
        guard let index = sessions.firstIndex(where: { $0.id == session.id }),
              index < sessions.count - 1 else {
            return "Your latest scan results are ready to review."
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
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Showing Saved Results")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text("Your scan history is temporarily stored. Results are saved and will sync when available.")
                    .font(.system(size: 14))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fallbackLatestScanCard(_ session: FallbackStorage.FallbackSession) -> some View {
        VStack(spacing: 0) {
            // Gradient header
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        scoreColor(session.overallScore),
                        scoreColor(session.overallScore).opacity(0.7)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 120)

                VStack(spacing: 8) {
                    Text("Latest Scan")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))

                    Text("\(Int(session.overallScore))")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(scoreDescription(session.overallScore))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 16) {
                Text(session.relativeDate)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                Text("Tap 'Start New Scan' below to see your latest results and track progress")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(HeadspaceDesign.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    // MARK: - Fallback Storage Views

    private var fallbackProgressChart: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
            Text("Your Progress")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

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
                        .stroke(HeadspaceDesign.Colors.textSecondary.opacity(0.1), lineWidth: 1)
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
                    .stroke(HeadspaceDesign.Colors.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    // Data points
                    ForEach(Array(chartData.enumerated()), id: \.element.id) { index, session in
                        let x = width * CGFloat(index) / CGFloat(max(chartData.count - 1, 1))
                        let normalizedScore = (session.overallScore - minScore) / scoreRange
                        let y = height * (1 - CGFloat(normalizedScore))

                        Circle()
                            .fill(scoreColor(session.overallScore))
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }
                }
            }
            .frame(height: 120)
            .padding(.vertical, HeadspaceDesign.Spacing.sm)
        }
        .padding(HeadspaceDesign.Spacing.lg)
        .background(HeadspaceDesign.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
    }

    private var fallbackRecentScansSection: some View {
        VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.lg) {
            Text("Recent scans")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

            VStack(spacing: HeadspaceDesign.Spacing.md) {
                ForEach(Array(fallbackSessions.prefix(5)), id: \.id) { session in
                    fallbackScanListItem(session)
                }
            }
        }
    }

    private func fallbackScanListItem(_ session: FallbackStorage.FallbackSession) -> some View {
        HStack(alignment: .center, spacing: HeadspaceDesign.Spacing.lg) {
            // Date badge - always show day/month number
            VStack(spacing: 4) {
                Text(formatDayNumber(session.date))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text(formatMonthShort(session.date))
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
            .frame(width: 64, height: 64)

            // Info - show date and time
            VStack(alignment: .leading, spacing: 4) {
                Text(formatRelativeDateForFallback(session.date))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text(formatTime(session.date))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(HeadspaceDesign.Colors.textSecondary.opacity(0.5))
        }
        .padding(HeadspaceDesign.Spacing.md)
        .background(HeadspaceDesign.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md))
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
}
