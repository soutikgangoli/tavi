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
    @State private var isMetricsExpanded: Bool = false
    @AppStorage(AppDefaultsKey.skipOnboarding) private var skipOnboarding: Bool = false

    // Fallback storage support
    @StateObject private var fallbackStorage = FallbackStorage.shared
    @State private var fallbackSessions: [FallbackStorage.FallbackSession] = []

    public init(selectedTab: Binding<MainTabView.Tab>, showScanFlow: Binding<Bool>) {
        self._selectedTab = selectedTab
        self._showScanFlow = showScanFlow
        let hasCompleted = UserDefaults.standard.bool(forKey: AppDefaultsKey.hasCompletedOnboarding)
        let skipEnabled = UserDefaults.standard.bool(forKey: AppDefaultsKey.skipOnboarding)
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
            .navigationTitle("Ollvy")
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
                    .accessibilityLabel(AppStrings.Accessibility.settingsButton)
                    .accessibilityHint(AppStrings.Accessibility.settingsHint)
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
            VStack(spacing: Designs.Spacing.lg) {
                // Header: Show date header if has scans, greeting if empty
                if hasCoreDataScans {
                    dateHeaderSection
                        .padding(.top, Designs.Spacing.sm)
                } else {
                    greetingSection
                        .padding(.top, Designs.Spacing.sm)
                        .padding(.bottom, Designs.Spacing.md)
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
                Spacer().frame(height: Designs.Sizes.frameXXLarge)
            }
            .padding(.horizontal, Designs.Spacing.lg)
        }
        .background(Designs.Colors.background)
    }

    // MARK: - Error View

    private func errorView(_ error: ErrorState) -> some View {
        VStack(spacing: 20) {
            Image(systemName: SFSymbol.exclamationTriangle)
                .font(AppFont.custom(size: 60, weight: .regular))
                .foregroundColor(.orange)

            Text(AppStrings.Errors.somethingWentWrong)
                .font(AppFont.title2)

            Text(error.message)
                .font(AppFont.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                errorState = nil
            } label: {
                Text(AppStrings.Buttons.tryAgain)
                    .font(AppFont.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 16)
                    .background(Designs.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
            }
            .padding(.top)
        }
        .padding()
    }

    // MARK: - Components

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.md) {
            let userName = UserProfileManager.shared.loadProfile().name ?? "there"
            let greeting = getTimeBasedGreeting()

            VStack(alignment: .leading, spacing: Designs.Spacing.xSmall) {
                Text("\(greeting), \(userName)!")
                    .font(AppFont.largeTitle)
                    .foregroundColor(Designs.Colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                Text(AppStrings.Home.readyToDiscover)
                    .font(AppFont.bodyMedium)
                    .foregroundColor(Designs.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Date header for has-data state (replaces greeting)
    private var dateHeaderSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: Designs.Spacing.xs) {
                Text("\(AppStrings.TimeRanges.today), \(formattedTodayDate)")
                    .font(AppFont.pageTitle)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text(AppStrings.Home.trackYourJourney)
                    .font(AppFont.bodyPrimary)
                    .foregroundColor(Designs.Colors.textSecondary)
            }

            Spacer()

            // Profile icon
            Button {
                selectedTab = .profile
            } label: {
                ZStack {
                    Circle()
                        .fill(Designs.Colors.primary.opacity(Designs.Opacity.medium))
                        .frame(width: Designs.Sizes.iconMedium, height: Designs.Sizes.iconMedium)

                    if let userName = UserProfileManager.shared.loadProfile().name {
                        Text(String(userName.prefix(1)).uppercased())
                            .font(AppFont.cardTitle)
                            .foregroundColor(Designs.Colors.primary)
                    } else {
                        Image(systemName: SFSymbol.personFill)
                            .font(AppFont.metricValue)
                            .foregroundColor(Designs.Colors.primary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Status widgets row (challenge + last scan info)
    private var statusWidgetsRow: some View {
        HStack(spacing: Designs.Spacing.md) {
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
                    HStack(spacing: Designs.Spacing.sm) {
                        Image(systemName: SFSymbol.flameFill)
                            .font(AppFont.metricValue)
                            .foregroundColor(Designs.Colors.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppStrings.Home.active)
                                .font(AppFont.label)
                                .foregroundColor(Designs.Colors.textPrimary)

                            let progress = Int((Double(challenge.daysCompleted) / Double(challenge.goalDays)) * 100)
                            Text("\(challenge.daysCompleted) \(AppStrings.Home.days) • \(progress)% done")
                                .font(AppFont.captionSmall)
                                .foregroundColor(Designs.Colors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: SFSymbol.chevronDown)
                            .font(AppFont.captionSmall)
                            .foregroundColor(Designs.Colors.textTertiary)
                    }
                    .padding(Designs.Spacing.md)
                    .background(Designs.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
                }
            } else {
                // No active challenge - show start button
                Button {
                    startChallenge()
                } label: {
                    HStack(spacing: Designs.Spacing.sm) {
                        Image(systemName: SFSymbol.flameFill)
                            .font(AppFont.metricValue)
                            .foregroundColor(Designs.Colors.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppStrings.Home.startChallenge)
                                .font(AppFont.label)
                                .foregroundColor(Designs.Colors.textPrimary)

                            Text(AppStrings.Home.thirtyDayGlow)
                                .font(AppFont.captionSmall)
                                .foregroundColor(Designs.Colors.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(Designs.Spacing.md)
                    .background(Designs.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
                }
            }
        }
    }

    /// Last scan info widget
    private var lastScanWidget: some View {
        HStack(spacing: Designs.Spacing.sm) {
            Image(systemName: SFSymbol.calendar)
                .font(AppFont.cardTitle)
                .foregroundColor(Designs.Colors.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.Home.lastScan)
                    .font(AppFont.label)
                    .foregroundColor(Designs.Colors.textPrimary)

                if let lastScan = latestSession {
                    Text(formatRelativeDate(lastScan.date))
                        .font(AppFont.captionSmall)
                        .foregroundColor(Designs.Colors.textSecondary)
                } else {
                    Text(AppStrings.EmptyStates.noScansYet)
                        .font(AppFont.captionSmall)
                        .foregroundColor(Designs.Colors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(Designs.Spacing.md)
        .background(Designs.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
    }

    /// Hero rings section - 1 large overall ring + 3 smaller metric rings
    private var heroRingsSection: some View {
        VStack(spacing: Designs.Spacing.lg) {
            if let latest = latestSession {
                // Large Overall Score Ring
                Button {
                    selectedMetricType = .overall
                } label: {
                    largeHeroRing(
                        score: latest.overallScore,
                        label: AppStrings.Home.overallHealth,
                        color: Designs.Colors.primary
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // 3 Smaller Metric Rings
                HStack(spacing: Designs.Spacing.md) {
                    // Ring 1: Smoothness
                    Button {
                        selectedMetricType = .smoothness
                    } label: {
                        smallHeroRing(
                            score: latest.textureAvg,
                            label: AppStrings.Metrics.smoothness,
                            color: Designs.ScoreColors.good
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
                            color: Designs.Colors.secondary  // Yellow
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
                            color: Designs.ScoreColors.pinkAccent
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
                            .font(AppFont.subheadingSecondary)

                        Image(systemName: SFSymbol.arrowRight)
                            .font(AppFont.label)
                    }
                    .foregroundColor(Designs.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Designs.Spacing.small)
                    .background(Designs.Colors.primary.opacity(Designs.Opacity.veryLight))
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.sm))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, Designs.Spacing.md)
    }

    /// Large hero ring for overall score
    private func largeHeroRing(score: Double, label: String, color: Color) -> some View {
        VStack(spacing: Designs.Spacing.sm) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(color.opacity(Designs.Opacity.light), lineWidth: 12)
                    .frame(width: Designs.Sizes.achievementIconLarge, height: Designs.Sizes.achievementIconLarge)

                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(score / 100))
                    .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: Designs.Sizes.achievementIconLarge, height: Designs.Sizes.achievementIconLarge)
                    .rotationEffect(.degrees(-90))
                    .animation(Designs.Animation.pulse, value: score)

                // Score text
                VStack(spacing: 2) {
                    Text("\(Int(score))")
                        .font(.scoreFont(size: 48))
                        .foregroundColor(Designs.Colors.textPrimary)

                    Text("%")
                        .font(AppFont.cardTitle)
                        .foregroundColor(Designs.Colors.textSecondary)
                }
            }

            Text(label)
                .font(AppFont.subheadingPrimary)
                .foregroundColor(Designs.Colors.textPrimary)
        }
    }

    /// Small hero ring for individual metrics
    private func smallHeroRing(score: Double, label: String, color: Color) -> some View {
        VStack(spacing: Designs.Spacing.xs) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(color.opacity(Designs.Opacity.light), lineWidth: 6)
                    .frame(width: Designs.Sizes.achievementIconSmall, height: Designs.Sizes.achievementIconSmall)

                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(score / 100))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: Designs.Sizes.achievementIconSmall, height: Designs.Sizes.achievementIconSmall)
                    .rotationEffect(.degrees(-90))
                    .animation(Designs.Animation.slow, value: score)

                // Score text
                Text("\(Int(score))")
                    .font(.scoreFont(size: 20))
                    .foregroundColor(Designs.Colors.textPrimary)
            }

            Text(label)
                .font(AppFont.caption)
                .foregroundColor(Designs.Colors.textSecondary)
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
        VStack(alignment: .leading, spacing: Designs.Spacing.md) {
            if let latest = latestSession {
                HStack {
                    Text(generateSummaryTitle(latest))
                        .font(AppFont.headlineSecondary)
                        .foregroundColor(Designs.Colors.textPrimary)

                    Spacer()

                    Button {
                        selectedSessionForDetail = latest
                    } label: {
                        Image(systemName: SFSymbol.arrowUpRight)
                            .font(AppFont.metricLabel)
                            .foregroundColor(Designs.Colors.primary)
                    }
                }

                Text(generateSummaryText(latest))
                    .font(AppFont.bodySecondary)
                    .foregroundColor(Designs.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("\(AppStrings.Home.overallScorePrefix) \(Int(latest.overallScore))")
                        .font(AppFont.subheadingPrimary)
                        .foregroundColor(Designs.Colors.textPrimary)

                    if let trend = calculateTrend(for: latest), trend != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: trend > 0 ? SFSymbol.arrowUpRight : "arrow.down.right")
                                .font(AppFont.custom(size: 11, weight: .bold))
                            Text("\(trend > 0 ? "+" : "")\(Int(trend))")
                                .font(AppFont.footnote)
                        }
                        .foregroundColor(trend > 0 ? Designs.ScoreColors.excellent : Designs.Colors.error)
                        .padding(.horizontal, Designs.Spacing.xSmall)
                        .padding(.vertical, Designs.Spacing.xxSmall)
                        .background((trend > 0 ? Designs.ScoreColors.excellent : Designs.Colors.error).opacity(Designs.Opacity.veryLight))
                        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.tiny))
                    }
                }
            }
        }
        .padding(Designs.Spacing.lg)
        .background(Designs.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
        .shadow(
            color: Designs.Shadows.card.color,
            radius: Designs.Shadows.card.radius,
            x: Designs.Shadows.card.x,
            y: Designs.Shadows.card.y
        )
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
                // Gradient header
                ZStack {
                    Designs.Colors.warmGradient
                        .frame(height: Designs.Sizes.displayHeight - 100)

                    VStack(spacing: Designs.Spacing.lg) {
                        // Score circle
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(Designs.Opacity.light), lineWidth: 8)
                                .frame(width: Designs.Sizes.achievementIcon, height: Designs.Sizes.achievementIcon)

                            Circle()
                                .trim(from: 0, to: CGFloat(session.overallScore / 100))
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: Designs.Sizes.achievementIcon, height: Designs.Sizes.achievementIcon)
                                .rotationEffect(.degrees(-90))

                            Text("\(Int(session.overallScore))")
                                .font(.scoreFont(size: 48))
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel("Skin Health Score")
                        .accessibilityValue("\(Int(session.overallScore)) out of 100, \(scoreDescription(session.overallScore))")

                        Text("Your Skin Health Score")
                            .font(AppFont.bodyMedium)
                            .foregroundColor(.white.opacity(Designs.Opacity.almostTransparent))
                            .accessibilityHidden(true)
                    }
                }

                // White footer
                VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Last scanned")
                                .font(AppFont.caption)
                                .foregroundColor(Designs.Colors.textSecondary)

                            Text(session.relativeDate)
                                .font(AppFont.subheadingPrimary)
                                .foregroundColor(Designs.Colors.textPrimary)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Text("View details")
                                .font(AppFont.subheadingPrimary)

                            Image(systemName: SFSymbol.chevronRight)
                                .font(AppFont.label)
                        }
                        .foregroundColor(Designs.Colors.primary)
                    }
                }
                .padding(Designs.Spacing.xl)
                .background(Designs.Colors.elevatedCard)
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

    private var firstScanCard: some View {
        VStack(spacing: Designs.Spacing.lg) {
            // Hero CTA Card - Most prominent, first thing they see
            heroCTACard
                .padding(.top, Designs.Spacing.md)

            // The Science Section
            scienceBehindGlowCard

            // Quick Benefits Card - Compact, shows value
            quickBenefitsCard
        }
    }

    /// Hero CTA Card - Prominent call-to-action for first scan
    private var heroCTACard: some View {
        VStack(spacing: 0) {
            // Main content area
            ZStack {
                // White background
                Color.white

                // Thick yellow border
                RoundedRectangle(cornerRadius: Designs.Radius.lg)
                    .stroke(Designs.Colors.primary, lineWidth: 4)

                VStack(spacing: Designs.Spacing.lg) {
                    ZStack {
                        // White circle with yellow border
                        Circle()
                            .fill(Color.white)
                            .frame(width: Designs.Sizes.profileIcon, height: Designs.Sizes.profileIcon)
                            .overlay(
                                Circle()
                                    .stroke(Designs.Colors.primary, lineWidth: 4)
                            )

                        Image(systemName: SFSymbol.cameraFill)
                            .font(AppFont.custom(size: 44, weight: .semibold))
                            .foregroundColor(Designs.Colors.primary)
                    }

                    VStack(spacing: 8) {
                        Text(AppStrings.Home.startYourFirstScan)
                            .font(AppFont.title2)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)

                        Text(AppStrings.Home.getCompleteAnalysis)
                            .font(AppFont.bodySecondary)
                            .foregroundColor(.black.opacity(Designs.Opacity.semiTransparent))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Designs.Spacing.md)
                    }
                }
                .padding(Designs.Spacing.xl)
            }
            .frame(height: Designs.Sizes.displayXLarge2)

            // Single dominant CTA button
            Button {
                showScanFlow = true
            } label: {
                VStack(spacing: 8) {
                    HStack {
                        Text(AppStrings.Home.startYourScan)
                            .font(AppFont.headlinePrimary)

                        Image(systemName: SFSymbol.arrowRight)
                            .font(AppFont.cardTitle)
                    }
                    .foregroundColor(.white)

                    Text(AppStrings.Home.poweredByBiometrics)
                        .font(AppFont.footnote)
                        .foregroundColor(.white.opacity(Designs.Opacity.almostOpaque))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Designs.Spacing.large)
                .background(Designs.Colors.primary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Designs.Radius.lg)
                .stroke(Designs.Colors.primary, lineWidth: 4)
        )
        .shadow(
            color: Designs.Shadows.card.color,
            radius: Designs.Shadows.card.radius,
            x: Designs.Shadows.card.x,
            y: Designs.Shadows.card.y
        )
    }
    
    /// The Science Behind Your Glow Section
    private var scienceBehindGlowCard: some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.md) {
            HStack {
                Image(systemName: SFSymbol.waveformPath)
                    .font(AppFont.navIcon)
                    .foregroundColor(Designs.Colors.primary)

                Text(AppStrings.Home.scienceBehindGlow)
                    .font(AppFont.headlinePrimary)
                    .foregroundColor(Designs.Colors.textPrimary)
            }

            Text(AppStrings.Home.clinicalGradeImaging)
                .font(AppFont.bodyPrimary)
                .foregroundColor(Designs.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Designs.Spacing.lg)
        .background(Designs.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
        .shadow(
            color: Designs.Shadows.card.color,
            radius: Designs.Shadows.card.radius,
            x: Designs.Shadows.card.x,
            y: Designs.Shadows.card.y
        )
    }

    /// Quick Benefits Card - Shows key value propositions with expandable metrics
    private var quickBenefitsCard: some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.md) {
            Text(AppStrings.Home.whatYoullGet)
                .font(AppFont.headlinePrimary)
                .foregroundColor(Designs.Colors.textPrimary)

            VStack(spacing: Designs.Spacing.md) {
                // Expandable 8 Metrics row
                Button {
                    withAnimation(Designs.Animation.standard) {
                        isMetricsExpanded.toggle()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                        HStack(spacing: Designs.Spacing.md) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(AppFont.metricValue)
                                .foregroundColor(Designs.Colors.primary)
                                .frame(width: Designs.Sizes.iconXSmall)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(AppStrings.Home.eightSkinMetrics)
                                    .font(AppFont.subheadingPrimary)
                                    .foregroundColor(Designs.Colors.textPrimary)

                                Text(AppStrings.Home.comprehensiveAnalysis)
                                    .font(AppFont.caption)
                                    .foregroundColor(Designs.Colors.textSecondary)
                            }

                            Spacer()

                            Image(systemName: isMetricsExpanded ? SFSymbol.chevronUp : SFSymbol.chevronDown)
                                .font(AppFont.metricLabel)
                                .foregroundColor(Designs.Colors.textSecondary)
                        }

                        // Expanded metrics list
                        if isMetricsExpanded {
                            VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                                Divider()
                                    .padding(.vertical, Designs.Spacing.xxSmall)

                                metricDetailRow(icon: "waveform.path", name: AppStrings.Metrics.smoothness)
                                metricDetailRow(icon: "drop.fill", name: AppStrings.Metrics.hydration)
                                metricDetailRow(icon: "sparkles", name: "Glow")
                                metricDetailRow(icon: "circle.hexagongrid.fill", name: AppStrings.Metrics.pigmentation)
                                metricDetailRow(icon: "circle.fill", name: AppStrings.Metrics.acne)
                                metricDetailRow(icon: "sun.max.fill", name: "Sun Damage")
                                metricDetailRow(icon: "heart.fill", name: AppStrings.Metrics.redness)
                                metricDetailRow(icon: "square.grid.3x3.fill", name: "Roughness")
                            }
                            .padding(.leading, 42)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())

                benefitRow(icon: "checkmark.circle.fill", title: AppStrings.Home.progressTracking, description: AppStrings.Home.seeImprovements)
                benefitRow(icon: "checkmark.circle.fill", title: AppStrings.Home.personalizedInsights, description: AppStrings.Home.recommendationsTailored)
            }
        }
        .padding(Designs.Spacing.lg)
        .background(Designs.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
        .shadow(
            color: Designs.Shadows.card.color,
            radius: Designs.Shadows.card.radius,
            x: Designs.Shadows.card.x,
            y: Designs.Shadows.card.y
        )
    }

    /// Individual metric detail row for expanded view
    private func metricDetailRow(icon: String, name: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(AppFont.caption)
                .foregroundColor(Designs.Colors.primary)
                .frame(width: Designs.Sizes.iconTiny)

            Text(name)
                .font(AppFont.caption)
                .foregroundColor(Designs.Colors.textPrimary)

            Spacer()
        }
    }

    /// Individual benefit row with icon and text
    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: Designs.Spacing.md) {
            Image(systemName: icon)
                .font(AppFont.metricValue)
                .foregroundColor(Designs.Colors.primary)
                .frame(width: Designs.Sizes.iconXSmall)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFont.subheadingPrimary)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text(description)
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
            }

            Spacer()
        }
    }

    private var recentScansSection: some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.lg) {
            Text(AppStrings.Home.recentScans)
                .font(AppFont.sectionHeader)
                .foregroundColor(Designs.Colors.textPrimary)

            VStack(spacing: Designs.Spacing.md) {
                ForEach(Array(sessions.prefix(5)), id: \.id) { session in
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

            // View All button - only show if more than 5 scans
            if sessions.count > 5 {
                Button {
                    selectedTab = .history
                } label: {
                    HStack {
                        Text(AppStrings.Home.viewAllScans(sessions.count))
                            .font(AppFont.subheadingPrimary)
                            .foregroundColor(Designs.Colors.primary)

                        Image(systemName: SFSymbol.arrowRight)
                            .font(AppFont.metricLabel)
                            .foregroundColor(Designs.Colors.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Designs.Colors.primary.opacity(Designs.Opacity.veryLight))
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
                }
            }
        }
    }

    private func recentScanListItem(_ session: SessionResult) -> some View {
        NavigationLink(value: session) {
            HStack(alignment: .center, spacing: Designs.Spacing.md) {
                // Date badge (left corner) - compact
                VStack(spacing: 2) {
                    Text(formatDayMonth(session.date))
                        .font(AppFont.label)
                        .foregroundColor(Designs.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(formatYear(session.date))
                        .font(AppFont.tabBar)
                        .foregroundColor(Designs.Colors.textSecondary)
                        .lineLimit(1)
                }
                .frame(width: Designs.Sizes.badgeMedium + 20, alignment: .center)
                .padding(.vertical, Designs.Spacing.xSmall)
                .background(Designs.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Main content area
                VStack(alignment: .leading, spacing: 6) {
                    // First line: "Skin Score" label on left, score number on right
                    HStack(spacing: 8) {
                        Text(AppStrings.Home.skinScore)
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textSecondary)
                        
                        Spacer()
                        
                        Text("\(Int(session.overallScore))")
                            .font(.scoreFont(size: 32))
                            .foregroundColor(scoreColor(session.overallScore))
                            .lineLimit(1)
                    }

                    // Second line: Date (e.g., "Today") on left, percentage in box on right
                    HStack(spacing: 8) {
                        Text(session.relativeDate)
                            .font(AppFont.subheadingSecondary)
                            .foregroundColor(Designs.Colors.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Percentage in a box
                        HStack(spacing: 4) {
                            if let trend = calculateTrend(for: session), trend != 0 {
                                Image(systemName: trend > 0 ? SFSymbol.arrowUpRight : "arrow.down.right")
                                    .font(AppFont.microBold)
                                Text("\(trend > 0 ? "+" : "")\(Int(trend))%")
                                    .font(AppFont.captionSmall)
                            } else {
                                Text("\(Int(session.overallScore))%")
                                    .font(AppFont.captionSmall)
                            }
                        }
                        .foregroundColor(scoreColor(session.overallScore))
                        .padding(.horizontal, Designs.Spacing.xSmall)
                        .padding(.vertical, Designs.Spacing.xxSmall)
                        .background(scoreColor(session.overallScore).opacity(Designs.Opacity.medium))
                        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.tiny))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Chevron indicator
                Image(systemName: SFSymbol.chevronRight)
                    .font(AppFont.metricLabel)
                    .foregroundColor(Designs.Colors.textTertiary)
            }
            .frame(minHeight: 80)
            .padding(Designs.Spacing.md)
            .background(Designs.Colors.elevatedCard)
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

    private func activeChallengeCard(_ challenge: GlowChallenge) -> some View {
        VStack(spacing: 0) {
            // Yellow header with black text and progress
            ZStack {
                Designs.Colors.primary  // Bumble yellow
                    .frame(height: Designs.Sizes.achievementIconLarge)

                VStack(spacing: Designs.Spacing.md) {
                    // Title
                    HStack {
                        Image(systemName: "flame.fill")
                            .font(AppFont.metricValue)
                        Text("30-Day Glow Challenge")
                            .font(AppFont.headlineSecondary)
                    }
                    .foregroundColor(Designs.Colors.secondary)

                    // Progress circle
                    ZStack {
                        Circle()
                            .stroke(Designs.Colors.secondary.opacity(Designs.Opacity.medium), lineWidth: 8)
                            .frame(width: Designs.Sizes.achievementIconSmall, height: Designs.Sizes.achievementIconSmall)

                        Circle()
                            .trim(from: 0, to: CGFloat(challenge.progressPercentage) / 100)
                            .stroke(Designs.Colors.secondary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: Designs.Sizes.achievementIconSmall, height: Designs.Sizes.achievementIconSmall)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 2) {
                            Text("\(challenge.daysCompleted)")
                                .font(.scoreFont(size: 24))
                                .foregroundColor(Designs.Colors.secondary)
                            Text("days")
                                .font(AppFont.tabBar)
                                .foregroundColor(Designs.Colors.secondary.opacity(Designs.Opacity.almostOpaque))
                        }
                    }
                }
            }

            // White info section
            VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                // Progress bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(challenge.daysRemaining) days remaining")
                            .font(AppFont.label)
                            .foregroundColor(Designs.Colors.textPrimary)

                        Spacer()

                        Text("\(Int(challenge.progressPercentage))%")
                            .font(AppFont.label)
                            .foregroundColor(Designs.Colors.primary)
                    }

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(Designs.Opacity.light))
                                .frame(height: Designs.Sizes.indicatorTiny)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Designs.Colors.accent)  // Lavender
                                .frame(width: geometry.size.width * CGFloat(challenge.progressPercentage) / 100, height: 8)
                        }
                    }
                    .frame(height: 8)
                }

                // Stats
                HStack(spacing: Designs.Spacing.lg) {
                    // Glow improvement
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Glow Improvement")
                            .font(AppFont.captionSmall)
                            .foregroundColor(Designs.Colors.textSecondary)

                        HStack(spacing: 4) {
                            if challenge.skinHealthImprovement > 0 {
                                Image(systemName: SFSymbol.arrowUpRight)
                                    .font(AppFont.captionSmall)
                                    .foregroundColor(Designs.ScoreColors.excellent)
                            }
                            Text("\(challenge.skinHealthImprovement > 0 ? "+" : "")\(challenge.skinHealthImprovement)")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(challenge.skinHealthImprovement > 0 ? Designs.ScoreColors.excellent : Designs.Colors.textPrimary)
                        }
                    }

                    Divider()
                        .frame(height: Designs.Sizes.frameMedium)

                    // Next milestone
                    if let nextMilestone = challenge.nextMilestone {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next Milestone")
                                .font(AppFont.captionSmall)
                                .foregroundColor(Designs.Colors.textSecondary)

                            HStack(spacing: 6) {
                                Image(systemName: nextMilestone.iconName)
                                    .font(AppFont.bodyPrimary)
                                    .foregroundColor(Designs.Colors.primary)
                                Text(nextMilestone.title)
                                    .font(AppFont.caption)
                                    .foregroundColor(Designs.Colors.textPrimary)
                            }
                        }
                    }
                }
            }
            .padding(Designs.Spacing.xl)
            .background(Designs.Colors.elevatedCard)
        }
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
        .shadow(
            color: Designs.Shadows.card.color,
            radius: Designs.Shadows.card.radius,
            x: Designs.Shadows.card.x,
            y: Designs.Shadows.card.y
        )
    }

    private var tipsCard: some View {
        HStack(spacing: Designs.Spacing.lg) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(Designs.Colors.accent.opacity(Designs.Opacity.veryLight + 0.02))
                        .frame(width: Designs.Sizes.cardIcon, height: Designs.Sizes.cardIcon)

                Image(systemName: SFSymbol.lightbulbFill)
                    .font(AppFont.sectionHeader)
                    .foregroundColor(Designs.Colors.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Pro tip")
                    .font(AppFont.label)
                    .foregroundColor(Designs.Colors.textSecondary)

                Text("Scan in bright, natural light for best results")
                    .font(AppFont.bodyMedium)
                    .foregroundColor(Designs.Colors.textPrimary)
            }

            Spacer()
        }
        .padding(Designs.Spacing.xl)
        .background(Designs.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
        .shadow(
            color: Designs.Shadows.card.color,
            radius: Designs.Shadows.card.radius,
            x: Designs.Shadows.card.x,
            y: Designs.Shadows.card.y
        )
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

    private func scoreColor(_ score: Double) -> Color {
        return Designs.ScoreColors.color(for: Int(score))
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
                .font(AppFont.metricValue)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Showing Saved Results")
                    .font(.app(size: 16, weight: .semibold))
                    .foregroundColor(Designs.Colors.textPrimary)

                Text("Your scan history is temporarily stored. Results are saved and will sync when available.")
                    .font(.app(size: 14))
                    .foregroundColor(Designs.Colors.textSecondary)
            }

            Spacer()
        }
                .padding(Designs.Spacing.medium)
        .background(Color.blue.opacity(Designs.Opacity.veryLight))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fallbackLatestScanCard(_ session: FallbackStorage.FallbackSession) -> some View {
        VStack(spacing: 0) {
            // Gradient header
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        scoreColor(session.overallScore),
                        scoreColor(session.overallScore).opacity(Designs.Opacity.semiTransparent)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 120)

                VStack(spacing: 8) {
                    Text("Latest Scan")
                        .font(AppFont.caption)
                        .foregroundColor(.white.opacity(Designs.Opacity.almostOpaque))

                    Text("\(Int(session.overallScore))")
                        .font(.scoreFont(size: 56))
                        .foregroundColor(.white)

                    Text(scoreDescription(session.overallScore))
                        .font(AppFont.bodyMedium)
                        .foregroundColor(.white.opacity(Designs.Opacity.almostOpaque))
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 16) {
                Text(session.relativeDate)
                    .font(AppFont.subheadline)
                    .foregroundColor(Designs.Colors.textSecondary)

                Text("Tap 'Start New Scan' below to see your latest results and track progress")
                    .font(AppFont.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
            }
                .padding(Designs.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Designs.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(Designs.Opacity.veryLight / 1.67), radius: Designs.Spacing.small, x: 0, y: Designs.Spacing.xxSmall)
    }

    // MARK: - Fallback Storage Views

    private var fallbackProgressChart: some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.md) {
            Text("Your Progress")
                .font(AppFont.sectionHeader)
                .foregroundColor(Designs.Colors.textPrimary)

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
                        .stroke(Designs.Colors.textSecondary.opacity(Designs.Opacity.veryLight), lineWidth: Designs.Border.width)
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
                    .stroke(Designs.Colors.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    // Data points
                    ForEach(Array(chartData.enumerated()), id: \.element.id) { index, session in
                        let x = width * CGFloat(index) / CGFloat(max(chartData.count - 1, 1))
                        let normalizedScore = (session.overallScore - minScore) / scoreRange
                        let y = height * (1 - CGFloat(normalizedScore))

                        Circle()
                            .fill(scoreColor(session.overallScore))
                            .frame(width: Designs.Sizes.indicatorTiny, height: Designs.Sizes.indicatorTiny)
                            .position(x: x, y: y)
                    }
                }
            }
            .frame(height: 120)
            .padding(.vertical, Designs.Spacing.sm)
        }
        .padding(Designs.Spacing.lg)
        .background(Designs.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
    }

    private var fallbackRecentScansSection: some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.lg) {
            Text("Recent scans")
                .font(AppFont.sectionHeader)
                .foregroundColor(Designs.Colors.textPrimary)

            VStack(spacing: Designs.Spacing.md) {
                ForEach(Array(fallbackSessions.prefix(5)), id: \.id) { session in
                    fallbackScanListItem(session)
                }
            }
        }
    }

    private func fallbackScanListItem(_ session: FallbackStorage.FallbackSession) -> some View {
        HStack(alignment: .center, spacing: Designs.Spacing.lg) {
            // Date badge - always show day/month number
            VStack(spacing: 4) {
                Text(formatDayNumber(session.date))
                    .font(AppFont.label)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text(formatMonthShort(session.date))
                    .font(AppFont.tabBar)
                    .foregroundColor(Designs.Colors.textSecondary)
            }
            .frame(width: Designs.Sizes.cardIcon)
            .padding(.vertical, 8)
            .background(Designs.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Score circle
            ZStack {
                Circle()
                    .fill(scoreColor(session.overallScore).opacity(Designs.Opacity.veryLight + 0.02))
                    .frame(width: Designs.Sizes.frameLarge, height: Designs.Sizes.frameLarge)

                Text("\(Int(session.overallScore))")
                    .font(.scoreFont(size: 24))
                    .foregroundColor(scoreColor(session.overallScore))
            }
            .frame(width: 64, height: 64)

            // Info - show date and time
            VStack(alignment: .leading, spacing: 4) {
                Text(formatRelativeDateForFallback(session.date))
                    .font(AppFont.headline)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text(formatTime(session.date))
                    .font(AppFont.footnote)
                    .foregroundColor(Designs.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: SFSymbol.chevronRight)
                .font(AppFont.metricLabel)
                .foregroundColor(Designs.Colors.textSecondary.opacity(Designs.Opacity.semiOpaque))
        }
        .padding(Designs.Spacing.md)
        .background(Designs.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
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
