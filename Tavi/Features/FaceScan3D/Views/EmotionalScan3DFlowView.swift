//
//  EmotionalScan3DFlowView.swift
//  Tavi
//
//  Complete 3D scan flow with emotional metrics and celebrations
//  Created on 2025-10-28.
//

import SwiftUI
import CoreData

/// Complete 3D scan flow with emotional results
public struct EmotionalScan3DFlowView: View {
    @StateObject private var viewModel = FaceScan3DViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    // Use PersistenceController directly instead of reading from environment
    private var viewContext: NSManagedObjectContext {
        PersistenceController.shared.viewContext
    }

    // Gentler Streak theme colors
    private let gsBackground = Designs.GentlerStreak.background
    private let gsTextPrimary = Designs.GentlerStreak.textPrimary
    private let gsTextSecondary = Designs.GentlerStreak.textSecondary
    private let gsAccentCoral = Designs.GentlerStreak.accentCoral
    private let gsAccentTeal = Designs.GentlerStreak.accentTeal
    private let gsCardBackground = Designs.GentlerStreak.cardBackground

    @State private var flowState: FlowState = .preparing(countdown: 3)
    @State private var showResults = false
    @State private var processingProgress: String = ""
    @State private var processingStep: Double = 0  // Changed to Double for smooth progress
    @State private var totalProcessingSteps: Double = 6

    // Weighted progress percentages for each step
    // Steps 1-3 are heavy processing (mesh merge, texture bake, metrics) = 90% of time
    // Steps 4-6 are fast (emotional, gamification, save) = 10% of time
    private let stepWeights: [Int: Double] = [
        1: 0.30,  // Mesh merge: 30%
        2: 0.55,  // Texture bake: 55% (cumulative)
        3: 0.85,  // Metrics analysis: 85% (cumulative)
        4: 0.90,  // Emotional metrics: 90% (cumulative)
        5: 0.95,  // Gamification: 95% (cumulative)
        6: 1.00   // Core Data save: 100% (cumulative)
    ]
    @State private var processingStartTime: Date?
    @StateObject private var timeEstimator = ProcessingTimeEstimator.shared
    @State private var deviceWarningMessage: String?
    @State private var emotionalMetrics: EmotionalMetrics?
    @State private var clinicalMetrics: Face3DMetrics?
    @State private var previousMetrics: EmotionalMetrics?
    @State private var comparisonUnavailableReason: String?
    @State private var showShareSheet = false
    @State private var showAchievementUnlock = false
    @State private var newAchievements: [Achievement] = []
    @State private var cyclingMessageIndex: Int = 0
    @State private var cyclingTimer: Timer?
    @State private var breathingPhase: Double = 0
    @State private var breathingTimer: Timer?

    // Automatic retry state
    @State private var retryCount: Int = 0
    @State private var isAutoRetrying: Bool = false
    @State private var lastError: ScanError?

    // Core Data save error state
    @State private var showSaveErrorAlert = false
    @State private var saveErrorMessage = ""
    @State private var saveRetryCount = 0
    @State private var pendingSaveData: (emotionalMetrics: EmotionalMetrics, clinicalMetrics: Face3DMetrics)?
    @State private var isSaving = false
    @State private var saveSuccessful: Bool?
    @StateObject private var saveQueue = CoreDataSaveQueue.shared
    @StateObject private var fallbackStorage = FallbackStorage.shared

    // Cancellation confirmation
    @State private var showCancelConfirmation = false

    // Data loss confirmation
    @State private var showContinueWithoutSavingConfirmation = false

    // Countdown task reference for proper cancellation
    @State private var countdownTask: Task<Void, Never>?

    // Processing task reference for proper cancellation
    @State private var processingTask: Task<Void, Never>?

    // Flag to prevent double cleanup
    @State private var hasCleanedUp: Bool = false

    // Analytics timing
    @State private var scanStartTime: Date?

    enum FlowState: Equatable {
        case preparing(countdown: Int)  // Grace period with countdown
        case capturing
        case processing
        case saving  // Blocking save state with retry logic
        case complete
        case error(String)
        case autoRetrying(attempt: Int, of: Int, reason: String)  // New state for auto-retry
    }

    public init() {}

    // Weighted progress percentage (0.0 - 1.0)
    // Makes heavy steps (1-3) take more visual progress time
    // so the progress bar feels smooth instead of jumping from 50% to 100%
    private var weightedProgressPercentage: Double {
        let step = Int(processingStep)
        return stepWeights[step] ?? 0.0
    }

    // Time-based progress (0.0 - 1.0)
    // Smooth progress based on actual elapsed time vs estimated total
    // This provides smooth animation that doesn't stagnate at 85%
    private var timeBasedProgress: Double {
        let total = timeEstimator.estimatedTotalSeconds
        guard total > 0 else { return 0 }
        let elapsed = timeEstimator.elapsedSeconds
        // Cap at 0.99 to avoid showing 100% before actually done
        return min(0.99, Double(elapsed) / Double(total))
    }

    // Computed save status for display
    private var computedSaveStatus: CelebratoryResultsView.SaveStatus? {
        // FIXED: Only show red "Storage Issue" banner if fallback save FAILED
        // If fallback is being used BUT save succeeded, treat as .saved (no scary banner)
        if fallbackStorage.isUsingFallback {
            // Check if fallback save succeeded
            if let success = saveSuccessful, success {
                // Fallback save succeeded - show as saved (no red banner)
                return .saved
            } else if saveSuccessful == false {
                // Fallback save failed - show red banner
                return .coreDataUnavailable
            }
            // Still saving to fallback
            return isSaving ? .saving : .coreDataUnavailable
        }

        if isSaving {
            return .saving
        } else if let success = saveSuccessful {
            return success ? .saved : .queued
        } else if saveQueue.hasPendingSaves {
            return .queued
        }
        return nil
    }

    public var body: some View {
        ZStack {
            // Main content based on state
            switch flowState {
            case .preparing(let countdown):
                preparingView(countdown: countdown)

            case .capturing:
                capturingView

            case .processing:
                processingView

            case .saving:
                savingView

            case .autoRetrying(let attempt, let total, let reason):
                autoRetryView(attempt: attempt, total: total, reason: reason)

            case .complete:
                if let metrics = emotionalMetrics {
                    CelebratoryResultsView(
                        emotionalMetrics: metrics,
                        clinicalMetrics: clinicalMetrics,
                        saveStatus: computedSaveStatus,
                        comparisonWarning: comparisonUnavailableReason,
                        onShareResults: {
                            showShareSheet = true
                        },
                        onClose: {
                            dismiss()
                        }
                    )
                }

            case .error(let message):
                errorView(message: message)
            }

            // Achievement unlock overlay
            if showAchievementUnlock {
                AchievementUnlockOverlay(achievements: newAchievements) {
                    showAchievementUnlock = false
                }
            }
        }
        .navigationTitle("3D Face Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if case .preparing = flowState {
                    Button("Cancel") {
                        // Preparing phase - safe to cancel without confirmation
                        cleanupAndDismiss()
                    }
                } else if case .capturing = flowState {
                    Button("Cancel") {
                        // Capturing phase - cancel directly without confirmation
                        cleanupAndDismiss()
                    }
                } else if case .processing = flowState {
                    Button("Cancel") {
                        // Processing phase - show confirmation since work is in progress
                        showCancelConfirmation = true
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let metrics = emotionalMetrics {
                SocialSharingView(
                    emotionalMetrics: metrics,
                    streak: GamificationManager.shared.getStreak(),
                    challenge: GamificationManager.shared.getCurrentChallenge(),
                    recentAchievement: newAchievements.first
                )
            }
        }
        .alert("Save Issue", isPresented: $showSaveErrorAlert) {
            Button("Retry Now") {
                retrySaveToCoreData()
            }
            Button("Export Backup") {
                exportPendingDataToJSON()
            }
            Button("Discard Results", role: .destructive) {
                showContinueWithoutSavingConfirmation = true
            }
            Button("OK", role: .cancel) {
                // Results are queued - automatic retry will handle it
            }
        } message: {
            Text("Your scan results are queued for automatic retry. They will be saved to your history in the background.\n\nOptions:\n• Retry Now - Try saving immediately\n• Export Backup - Save as JSON file for safekeeping\n• OK - Let automatic retry handle it\n• Discard - Permanently delete (cannot be undone)")
        }
        .alert("Permanently Discard Results?", isPresented: $showContinueWithoutSavingConfirmation) {
            Button("Yes, Discard", role: .destructive) {
                pendingSaveData = nil
                saveRetryCount = 0
                saveQueue.clearQueue()
                AppLogger.faceScan.warning("User chose to discard scan results")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you absolutely sure you want to discard your scan results?\n\nThis action CANNOT be undone. Your scan data will be permanently lost and will NOT appear in your history.\n\nConsider exporting a backup instead to keep your data safe.")
        }
        .alert("Cancel Scan?", isPresented: $showCancelConfirmation) {
            Button("Keep Going", role: .cancel) {
                // Do nothing - continue
            }
            Button("Cancel Scan", role: .destructive) {
                // User confirmed cancellation - full cleanup
                cleanupAndDismiss()
            }
        } message: {
            if case .processing = flowState {
                Text("Processing is in progress. If you cancel now, all scan data will be lost and you'll need to start over.\n\nAre you sure you want to cancel?")
            } else {
                let capturedCount = viewModel.capturedPoses.count
                if capturedCount > 0 {
                    Text("You've captured \(capturedCount) pose\(capturedCount == 1 ? "" : "s"). If you cancel now, your progress will be lost and you'll need to start over.\n\nAre you sure you want to cancel?")
                } else {
                    Text("If you cancel now, you'll need to start the scan over.\n\nAre you sure you want to cancel?")
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            // Handle app lifecycle to protect pending saves
            if newPhase == .background && pendingSaveData != nil {
                AppLogger.faceScan.warning("App backgrounded with pending save data")
                // Data persists in saveQueue - will auto-retry on foreground
            }

            if newPhase == .active && saveQueue.hasPendingSaves {
                AppLogger.faceScan.info("App foregrounded - resuming save queue")
                // CoreDataSaveQueue automatically retries on foreground
            }
        }
        .onDisappear {
            // CRITICAL: Full cleanup on view disappear to prevent background tasks
            // Use sync version since onDisappear is synchronous
            performFullCleanupSync()

            if pendingSaveData != nil {
                AppLogger.faceScan.warning("⚠️ View dismissed with unsaved data - but data is safely queued for retry")
            }
        }
    }

    // MARK: - Capturing View

    private var capturingView: some View {
        ZStack {
            FaceScan3DView(
                viewModel: viewModel,
                showDebug: false,
                showMesh: true,
                meshColor: .white,
                wireframeMode: true,
                showCalibration: true,
                onCaptureComplete: { capturedPoses in
                    // All poses captured - start processing pipeline
                    processCapture()
                }
            )

            // Error recovery overlay
            if let errorInfo = viewModel.errorInfo {
                ARKitErrorRecoveryView(
                    errorInfo: errorInfo,
                    partialCaptureCount: viewModel.capturedPoseCount,
                    onRetry: {
                        // Resume with partial captures if available
                        if viewModel.hasPartialCaptures {
                            viewModel.resumeWithPartialCaptures()
                        } else {
                            // Start fresh
                            viewModel.errorInfo = nil
                            viewModel.startGuidance()
                        }
                    },
                    onContinue: viewModel.hasPartialCaptures ? {
                        // Continue with partial captures
                        viewModel.resumeWithPartialCaptures()
                    } : nil,
                    onDismiss: {
                        // Cancel scan and go back
                        viewModel.cancelAutoRecovery()
                        dismiss()
                    }
                )
                .transition(.opacity)
                .zIndex(1000)
            }
        }
    }

    // MARK: - Processing View (Gentler Streak Theme)

    private var processingView: some View {
        ZStack {
            // Gentler Streak warm cream background
            gsBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Processing circle - contained within bounds
                ZStack {
                    // Outer coral glow ring (subtle pulse, contained)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [gsAccentCoral.opacity(0.12), Color.clear],
                                center: .center,
                                startRadius: 70,
                                endRadius: 100
                            )
                        )
                        .frame(width: Designs.Sizes.displayHeightMedium, height: Designs.Sizes.displayHeightMedium)
                        .opacity(0.8 + sin(breathingPhase) * 0.2)

                    // Middle glow ring
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [gsAccentCoral.opacity(0.08), Color.clear],
                                center: .center,
                                startRadius: 80,
                                endRadius: 110
                            )
                        )
                        .frame(width: Designs.Sizes.displayXLarge2, height: Designs.Sizes.displayXLarge2)
                        .opacity(0.7 + sin(breathingPhase * 0.8) * 0.15)

                    // Main white circle (fixed size, no scaling)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white, Color.white.opacity(0.9)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: Designs.Sizes.scoreCircleLarge, height: Designs.Sizes.scoreCircleLarge)
                        .shadow(color: gsAccentCoral.opacity(0.15), radius: Designs.Spacing.medium, x: 0, y: 4)

                    // Center content - seconds remaining with progress ring overlay
                    ZStack {
                        // Progress ring behind - coral color
                        // Progress based on elapsed/total time for smooth animation
                        Circle()
                            .trim(from: 0, to: CGFloat(timeBasedProgress))
                            .stroke(
                                gsAccentCoral,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: Designs.Sizes.achievementIcon, height: Designs.Sizes.achievementIcon)
                            .rotationEffect(.degrees(-90))
                            .animation(Designs.Animation.gentle, value: timeEstimator.elapsedSeconds)

                        // Seconds remaining - coral (more useful than percentage)
                        VStack(spacing: 2) {
                            Text("\(timeEstimator.remainingSeconds)")
                                .font(AppFont.displayLarge)
                                .foregroundColor(gsAccentCoral)
                                .monospacedDigit()

                            // Label
                            Text("sec left")
                                .font(AppFont.footnote)
                                .foregroundColor(gsAccentCoral.opacity(0.6))
                        }
                    }
                }
                .padding(.bottom, Designs.Spacing.xxLarge)

                // Processing messages - dark text
                VStack(spacing: Designs.Spacing.small) {
                    // Main message
                    Text(processingProgress)
                        .font(AppFont.headlinePrimary)
                        .foregroundColor(gsTextPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Designs.Spacing.xxLarge)

                    // Detailed status
                    if let currentPhase = getCurrentProcessingPhase() {
                        Text(currentPhase.getCyclingMessage(index: cyclingMessageIndex))
                            .font(AppFont.caption)
                            .foregroundColor(gsTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Designs.Spacing.xxLarge)
                            .animation(Designs.Animation.standard, value: cyclingMessageIndex)
                            .transition(.opacity)
                    }

                    // Step progress indicator
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.circle.fill")
                            .font(AppFont.metricLabel)
                        Text("Step \(Int(processingStep)) of \(Int(totalProcessingSteps))")
                            .font(AppFont.subheadingPrimary)
                    }
                    .foregroundColor(gsTextSecondary)
                    .padding(.top, Designs.Spacing.xSmall)

                    // Checklist items - directly below step indicator
                    VStack(spacing: Designs.Spacing.xSmall) {
                        processingChecklistItem(icon: "bolt.fill", text: "Keep your phone on")
                        processingChecklistItem(icon: "wand.and.stars", text: "Analyzing your skin")
                        processingChecklistItem(icon: "iphone", text: "Keep the app open")
                    }
                    .padding(.top, Designs.Spacing.medium)
                }
                .padding(.bottom, Designs.Spacing.xLarge)

                Spacer()
            }
        }
        .onAppear {
            // Start the countdown timer (estimates total time and counts down)
            timeEstimator.startCountdown()
            startBreathingAnimation()
            startCyclingMessages()
            processingStartTime = Date()
        }
        .onDisappear {
            stopBreathingAnimation()
            stopCyclingMessages()
        }
    }

    // MARK: - Saving View (Gentler Streak Theme)

    private var savingView: some View {
        ZStack {
            gsBackground.ignoresSafeArea()

            VStack(spacing: Designs.Spacing.xxxLarge) {
                Spacer()

                ProgressView()
                    .scaleEffect(1.5)
                    .tint(gsAccentCoral)

                VStack(spacing: Designs.Spacing.small) {
                    Text("Saving Results...")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(gsTextPrimary)

                    Text("Please wait while we save your scan to history")
                        .font(.subheadline)
                        .foregroundColor(gsTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Designs.Spacing.xxLarge)

                    if saveRetryCount > 0 {
                        HStack(spacing: Designs.Spacing.xxSmall) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                            Text("Retry attempt \(saveRetryCount)/3")
                                .font(.caption)
                        }
                        .foregroundColor(gsAccentCoral)
                        .padding(.top, Designs.Spacing.xSmall)
                    }
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @State private var rotationAngle: Double = 0

    // MARK: - Preparing View (Clean Minimal Design)

    @State private var prepBreathingScale: CGFloat = 1.0
    @State private var prepGlowOpacity: Double = 0.15

    private func preparingView(countdown: Int) -> some View {
        ZStack {
            // Clean white/cream background
            gsBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Breathing circle with countdown
                ZStack {
                    // Outer breathing ring - continuous loop
                    Circle()
                        .stroke(gsAccentCoral.opacity(0.15), lineWidth: 3)
                        .frame(width: 200, height: 200)
                        .scaleEffect(prepBreathingScale)

                    // Middle glow ring
                    Circle()
                        .fill(gsAccentCoral.opacity(prepGlowOpacity))
                        .frame(width: 160, height: 160)
                        .scaleEffect(prepBreathingScale * 0.95)

                    // Inner white circle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 140, height: 140)
                        .shadow(color: gsAccentCoral.opacity(0.2), radius: 20, x: 0, y: 8)

                    // Countdown number
                    Text("\(countdown)")
                        .font(.system(size: 56, weight: .light, design: .rounded))
                        .foregroundColor(gsAccentCoral)
                }

                Spacer().frame(height: 48)

                // Title
                Text("Get Ready")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(gsTextPrimary)

                Spacer().frame(height: 12)

                // Subtitle
                Text("Hold your phone at eye level\nand look straight ahead")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(gsTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Spacer()

                // Bottom action area
                VStack(spacing: 16) {
                    // Skip button
                    Button {
                        flowState = .capturing
                        viewModel.startGuidance()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(gsTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            startCountdown()
            startPrepBreathingAnimation()
        }
        .onDisappear {
            // Animation will stop when view disappears
        }
    }

    private func startPrepBreathingAnimation() {
        // Continuous breathing animation loop
        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            prepBreathingScale = 1.15
            prepGlowOpacity = 0.25
        }
    }

    // Checklist row for card-based layout (kept for potential future use)
    private func gsChecklistRow(icon: String, text: String, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Coral circle with icon
                ZStack {
                    Circle()
                        .fill(gsAccentCoral.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(gsAccentCoral)
                }

                Text(text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(gsTextPrimary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Divider (except for last item)
            if !isLast {
                Rectangle()
                    .fill(gsTextSecondary.opacity(0.1))
                    .frame(height: 1)
                    .padding(.leading, 80)
            }
        }
    }

    // Helper for checklist items - processing view (uses coral for consistency)
    private func prepChecklistItem(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(gsAccentCoral.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(gsAccentCoral)
            }

            Text(text)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(gsTextPrimary)

            Spacer()
        }
    }

    // Compact checklist item for processing view (inline below step indicator)
    private func processingChecklistItem(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(gsAccentCoral.opacity(0.7))

            Text(text)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(gsTextSecondary)
        }
    }

    // MARK: - Countdown Logic

    private func startCountdown() {
        guard case .preparing(let currentCount) = flowState, currentCount > 0 else {
            // Countdown complete - start capturing
            flowState = .capturing
            viewModel.startGuidance()

            // Track scan started
            scanStartTime = Date()
            AnalyticsManager.shared.trackScanStarted()

            return
        }

        // Cancel any existing countdown task to prevent stacking
        countdownTask?.cancel()

        // Continue countdown with proper task reference storage
        countdownTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

            // Check if task was cancelled during sleep
            guard !Task.isCancelled else { return }

            if case .preparing = flowState {  // Only continue if still preparing
                let nextCount = currentCount - 1
                if nextCount > 0 {
                    flowState = .preparing(countdown: nextCount)
                    // Continue countdown (recursive call, but previous task is cancelled first)
                    startCountdown()
                } else {
                    flowState = .capturing
                    viewModel.startGuidance()
                }
            }
        }
    }

    /// Cancel any active countdown task
    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    /// Perform full cleanup of all resources and tasks (async version)
    private func performFullCleanup() async {
        // CRITICAL: Prevent double cleanup which causes FigXPCUtilities errors
        guard !hasCleanedUp else {
            AppLogger.faceScan.info("⏭️ Cleanup already performed, skipping async cleanup")
            return
        }
        hasCleanedUp = true

        AppLogger.faceScan.info("🧹 Performing async cleanup...")

        // STEP 1: Signal cleanup is starting IMMEDIATELY
        // This is checked by AR delegate and ViewModel to prevent any new updates
        // AND triggers SwiftUI to call updateUIViewController which stops AR session
        viewModel.isCleaningUp = true
        viewModel.shouldStopSession = true

        // STEP 2: Cancel processing task
        processingTask?.cancel()
        processingTask = nil

        // STEP 3: Cancel countdown task
        cancelCountdown()

        // STEP 4: Stop all timers
        stopBreathingAnimation()
        stopCyclingMessages()

        // STEP 5: Cancel the time estimator
        timeEstimator.cancelProcessing()

        // STEP 6: Reset ViewModel state SYNCHRONOUSLY
        // This ensures all managers clean up their resources immediately
        viewModel.resetCalibration()

        AppLogger.faceScan.info("✅ Cleanup complete")
    }

    /// Non-async version for synchronous contexts (called from onDisappear)
    /// CRITICAL: Does NOT use semaphores to avoid main thread deadlock
    private func performFullCleanupSync() {
        // CRITICAL: Prevent double cleanup which causes FigXPCUtilities errors
        guard !hasCleanedUp else {
            AppLogger.faceScan.info("⏭️ Cleanup already performed, skipping")
            return
        }
        hasCleanedUp = true

        AppLogger.faceScan.info("🧹 Performing cleanup (onDisappear)...")

        // STEP 1: Signal cleanup is starting IMMEDIATELY
        // This is checked by AR delegate and ViewModel to prevent any new updates
        // AND triggers SwiftUI to call updateUIViewController which stops AR session
        viewModel.isCleaningUp = true
        viewModel.shouldStopSession = true

        // STEP 2: Cancel processing task IMMEDIATELY (will exit at next cancellation check point)
        if let task = processingTask {
            task.cancel()
            processingTask = nil
            AppLogger.faceScan.info("🛑 Processing task cancelled")
        }

        // STEP 3: Cancel countdown task
        cancelCountdown()

        // STEP 4: Stop all timers (immediate, no async)
        stopBreathingAnimation()
        stopCyclingMessages()

        // STEP 5: Cancel the time estimator
        timeEstimator.cancelProcessing()

        // STEP 6: Reset ViewModel state SYNCHRONOUSLY
        // We're already in onDisappear, so the view is going away
        // Reset ensures all managers clean up their resources
        viewModel.resetCalibration()

        AppLogger.faceScan.info("✅ Cleanup complete")
    }

    /// Cleanup and dismiss the view
    private func cleanupAndDismiss() {
        // CRITICAL FIX: Set cleanup flags FIRST before anything else
        // This ensures all async Tasks see these flags immediately
        // AND triggers SwiftUI to call updateUIViewController on ARFaceTrackingViewRepresentable
        // which will stop the AR session IMMEDIATELY (key fix for hang on cancel)
        viewModel.isCleaningUp = true
        viewModel.shouldStopSession = true

        // Cancel processing task - DON'T WAIT for it to complete
        processingTask?.cancel()
        processingTask = nil

        // Cancel other tasks immediately (synchronous, non-blocking)
        cancelCountdown()
        stopBreathingAnimation()
        stopCyclingMessages()
        timeEstimator.cancelProcessing()

        // Mark as cleaned up to prevent double cleanup
        hasCleanedUp = true

        // CRITICAL FIX: Reset ViewModel SYNCHRONOUSLY before dismiss
        // This ensures all managers are cleaned up and no async tasks are spawned
        // The AR session is already stopped via shouldStopSession flag
        viewModel.resetCalibration()

        // Dismiss after cleanup is complete
        AppLogger.faceScan.info("🚪 Dismissing after cleanup")
        dismiss()
    }

    // MARK: - Auto Retry View (Gentler Streak Theme)

    private func autoRetryView(attempt: Int, total: Int, reason: String) -> some View {
        ZStack {
            gsBackground.ignoresSafeArea()

            VStack(spacing: Designs.Spacing.xLarge) {
                Spacer()

                ProgressView()
                    .scaleEffect(1.5)
                    .tint(gsAccentCoral)

                VStack(spacing: Designs.Spacing.small) {
                    Text("Retrying...")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(gsTextPrimary)

                    Text("Attempt \(attempt) of \(total)")
                        .font(.headline)
                        .foregroundColor(gsTextSecondary)

                    Text(reason)
                        .font(.subheadline)
                        .foregroundColor(gsTextSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Designs.Spacing.xxLarge)
                }

                Button {
                    // Cancel auto-retry and show manual error
                    if let error = lastError {
                        retryCount = total  // Force max retries to show error
                        handleScanError(error)
                    }
                } label: {
                    Text("Cancel Retry")
                        .font(.headline)
                        .foregroundColor(gsTextSecondary)
                        .padding(.vertical, Designs.Spacing.xSmall)
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View (Gentler Streak Theme)

    private func errorView(message: String) -> some View {
        ZStack {
            gsBackground.ignoresSafeArea()

            VStack(spacing: Designs.Spacing.xLarge) {
                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(AppFont.scoreDisplay)
                    .foregroundColor(gsAccentCoral)

                VStack(spacing: Designs.Spacing.small) {
                    Text("Oops!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(gsTextPrimary)

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(gsTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Designs.Spacing.xxLarge)
                }

                Button {
                    // Restart capture with grace period
                    flowState = .preparing(countdown: 3)
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, Designs.Spacing.xxLarge)
                        .padding(.vertical, Designs.Spacing.small)
                        .background(gsAccentCoral)
                        .cornerRadius(Designs.Radius.medium)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(gsTextSecondary)
                        .padding(.vertical, Designs.Spacing.xSmall)
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Processing Pipeline

    private func processCapture() {
        flowState = .processing

        // Initialize device-specific time estimation
        deviceWarningMessage = timeEstimator.getProcessingWarning()

        // Log scan processing start with context
        CrashReporter.shared.logUserAction("scan_processing_started")
        CrashReporter.shared.setCustomKey("capture_count", value: viewModel.capturedPoses.count)
        CrashReporter.shared.setCustomKey("device_performance_tier", value: "\(timeEstimator.getPerformanceTier())")

        // Store task reference for cancellation support
        processingTask = Task {
            do {
                // Check for cancellation at start
                guard !Task.isCancelled else {
                    AppLogger.faceScan.info("🛑 Processing cancelled before start")
                    return
                }

                // Step 1: Merge meshes (with timeout protection)
                smoothlyUpdateProgress(to: 1)
                processingProgress = ProcessingPhase.meshMerge.description
                timeEstimator.startPhase(.meshMerge)
                CrashReporter.shared.setCustomKey("processing_step", value: "mesh_merge")

                let adjustedMergeTimeout = timeEstimator.getDeviceAdjustedTimeout(ScanConfiguration.meshMergeTimeout)
                AppLogger.faceScan.debug("📊 Mesh merge timeout: \(Int(adjustedMergeTimeout))s (base: \(Int(ScanConfiguration.meshMergeTimeout))s, tier: \(timeEstimator.getPerformanceTier()))")

                let merged = try await withTimeout(
                    seconds: adjustedMergeTimeout,
                    operation: "Mesh Merge"
                ) {
                    guard let result = await viewModel.finalizeCapture() else {
                        // Use the detailed error message from ViewModel
                        let errorReason = await viewModel.errorMessage ?? "Unknown merge failure"
                        throw ScanError.mergeFailed(reason: errorReason)
                    }
                    return result
                }

                // Log merge success for debugging
                let vertexCount = merged.vertices.count
                let faceCount = merged.triangleIndices.count / 3
                AppLogger.faceScan.info("Mesh merge completed: \(vertexCount) vertices, \(faceCount) faces")

                // Check for cancellation between steps
                guard !Task.isCancelled else {
                    AppLogger.faceScan.info("🛑 Processing cancelled after mesh merge")
                    return
                }

                try await Task.sleep(nanoseconds: 500_000_000)

                // Step 2: Bake texture (with timeout protection)
                smoothlyUpdateProgress(to: 2)
                processingProgress = ProcessingPhase.textureBake.description
                timeEstimator.startPhase(.textureBake)
                CrashReporter.shared.setCustomKey("processing_step", value: "texture_bake")

                // Use resolution-aware base timeout (60s for 2K, 180s for 4K)
                let baseTextureBakeTimeout = ScanConfiguration.getTextureBakeTimeout()
                // Apply device tier scaling with conservative safety margin
                let adjustedBakeTimeout = timeEstimator.getTextureBakeTimeout(baseTextureBakeTimeout)
                AppLogger.faceScan.debug("📊 Texture bake timeout: \(Int(adjustedBakeTimeout))s (base: \(Int(baseTextureBakeTimeout))s, resolution-aware)")

                let bakeResult = try await withTimeout(
                    seconds: adjustedBakeTimeout,
                    operation: "Texture Baking"
                ) {
                    guard let result = await viewModel.bakeTextureFromSequence() else {
                        throw ScanError.bakeFailed(reason: nil)
                    }
                    return result
                }

                // Log bake success for debugging
                AppLogger.faceScan.info("Texture bake completed: \(bakeResult.textureWidth)x\(bakeResult.textureHeight)")

                // Check for cancellation between steps
                guard !Task.isCancelled else {
                    AppLogger.faceScan.info("🛑 Processing cancelled after texture bake")
                    return
                }

                try await Task.sleep(nanoseconds: 500_000_000)

                // Step 3: Compute clinical metrics (with timeout protection)
                smoothlyUpdateProgress(to: 3)
                processingProgress = ProcessingPhase.metricsAnalysis.description
                timeEstimator.startPhase(.metricsAnalysis)
                CrashReporter.shared.setCustomKey("processing_step", value: "metrics_analysis")

                // Attempt metrics computation with timeout protection
                AppLogger.faceScan.info("🔬 Starting metrics computation with timeout...")

                let adjustedMetricsTimeout = timeEstimator.getDeviceAdjustedTimeout(ScanConfiguration.metricsComputationTimeout)
                AppLogger.faceScan.debug("📊 Metrics computation timeout: \(Int(adjustedMetricsTimeout))s (base: \(Int(ScanConfiguration.metricsComputationTimeout))s)")

                let computedClinicalMetrics = try await withTimeout(
                    seconds: adjustedMetricsTimeout,
                    operation: "Metrics Computation"
                ) {
                    guard let result = await viewModel.compute3DMetrics() else {
                        throw ScanError.metricsFailed(analyzer: nil, reason: nil)
                    }
                    return result
                }

                // Check for cancellation between steps
                guard !Task.isCancelled else {
                    AppLogger.faceScan.info("🛑 Processing cancelled after metrics computation")
                    return
                }

                try await Task.sleep(nanoseconds: 500_000_000)

                // Step 4: Convert to emotional metrics
                smoothlyUpdateProgress(to: 4)
                processingProgress = ProcessingPhase.emotionalMetrics.description
                timeEstimator.startPhase(.emotionalMetrics)
                CrashReporter.shared.setCustomKey("processing_step", value: "emotional_metrics")

                let userProfile = UserProfileManager.shared.loadProfile()
                let previousClinicalMetrics = await loadPreviousClinicalMetrics()
                let loadedPreviousMetrics = await loadPreviousMetrics()

                guard let emotional = EmotionalMetricsGenerator.generate(
                    from: computedClinicalMetrics,
                    previousMetrics: previousClinicalMetrics,
                    userProfile: userProfile
                ) else {
                    throw ScanError.metricsGenerationFailed
                }

                // Store both metrics for results view
                self.clinicalMetrics = computedClinicalMetrics
                self.previousMetrics = loadedPreviousMetrics

                // Check for cancellation between steps
                guard !Task.isCancelled else {
                    AppLogger.faceScan.info("🛑 Processing cancelled after emotional metrics")
                    return
                }

                // Step 5: Update gamification
                smoothlyUpdateProgress(to: 5)
                processingProgress = ProcessingPhase.gamification.description
                timeEstimator.startPhase(.gamification)
                CrashReporter.shared.setCustomKey("processing_step", value: "gamification")

                let updatedStreak = GamificationManager.shared.recordScan()

                let challenge = GamificationManager.shared.getCurrentChallenge()
                // Update challenge if active (would need to implement proper update method)

                let glowImprovement: Int
                if let previousClinicalMetrics = previousClinicalMetrics,
                   let previousEmotional = EmotionalMetricsGenerator.generate(from: previousClinicalMetrics) {
                    glowImprovement = emotional.skinHealthScore - previousEmotional.skinHealthScore
                } else {
                    glowImprovement = 0
                }

                let unlockedAchievements = GamificationManager.shared.checkAndUnlockAchievements(
                    totalScans: updatedStreak.totalScans,
                    currentStreak: updatedStreak.currentStreak,
                    skinHealthScore: emotional.skinHealthScore,
                    skinHealthImprovement: glowImprovement,
                    challengeComplete: challenge?.isCompleted ?? false
                )

                // Check for cancellation between steps
                guard !Task.isCancelled else {
                    AppLogger.faceScan.info("🛑 Processing cancelled after gamification")
                    return
                }

                // Step 6: Save to Core Data (with timeout protection)
                smoothlyUpdateProgress(to: 6)
                processingProgress = ProcessingPhase.coreDataSave.description
                timeEstimator.startPhase(.coreDataSave)
                CrashReporter.shared.setCustomKey("processing_step", value: "core_data_save")

                // Try to save with timeout - saveToCoreData() handles its own errors and shows alerts
                // CRITICAL: Use PersistenceController directly to avoid Environment access warnings
                let capturedContext = PersistenceController.shared.viewContext
                // Get face image from bake result
                let faceImage = bakeResult.albedoTexture

                // Check for cancellation before heavy heatmap generation
                guard !Task.isCancelled else {
                    AppLogger.faceScan.info("🛑 Processing cancelled before heatmap generation")
                    return
                }

                // Generate beautiful heatmaps using the face texture
                AppLogger.faceScan.info("📊 Generating beautiful heatmaps from face texture...")

                let heatmapGenerator = HeatmapOverlayGenerator()
                var heatmapDict: [HeatmapType: Data] = [:]

                // Map BeautifulHeatmapType to HeatmapType and generate each
                let mappings: [(BeautifulHeatmapType, HeatmapType)] = [
                    (.overall, .composite),
                    (.sharpness, .sharpness),
                    (.texture, .texture),
                    (.pigmentation, .pigmentation),
                    (.moisture, .moisture)
                ]

                for (beautifulType, heatmapType) in mappings {
                    // CRITICAL: Check cancellation in loop to prevent watchdog timeout
                    guard !Task.isCancelled else {
                        AppLogger.faceScan.info("🛑 Processing cancelled during heatmap generation")
                        return
                    }

                    if let heatmapImage = heatmapGenerator.generateMeshBasedHeatmap(
                        mesh: bakeResult.unifiedMesh,
                        baseTexture: faceImage,
                        metrics: computedClinicalMetrics,
                        metricType: beautifulType
                    ), let imageData = heatmapImage.jpegData(compressionQuality: 0.85) {
                        heatmapDict[heatmapType] = imageData
                        AppLogger.faceScan.debug("✅ Generated \(heatmapType.displayName) mesh-based heatmap")
                    }
                }

                // Capture as immutable for async boundary
                let capturedHeatmapData: [HeatmapType: Data]? = heatmapDict.isEmpty ? nil : heatmapDict
                if let count = capturedHeatmapData?.count {
                    AppLogger.faceScan.info("📊 Successfully generated \(count) beautiful heatmaps")
                }

                do {
                    try await withTimeout(
                        seconds: timeEstimator.getDeviceAdjustedTimeout(ScanConfiguration.coreDataSaveTimeout),
                        operation: "CoreData Save"
                    ) {
                        await saveToCoreData(
                            emotionalMetrics: emotional,
                            clinicalMetrics: computedClinicalMetrics,
                            faceImage: faceImage,
                            heatmapData: capturedHeatmapData,
                            context: capturedContext
                        )
                    }
                } catch {
                    // Timeout error - add to persistent queue and alert user
                    AppLogger.faceScan.error("⚠️ Core Data save timed out: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.saveQueue.enqueueSave(emotionalMetrics: emotional, clinicalMetrics: computedClinicalMetrics)
                        self.pendingSaveData = (emotional, computedClinicalMetrics)
                        self.saveErrorMessage = "Save operation timed out. Your results are queued for automatic retry."
                        self.showSaveErrorAlert = true
                        self.saveSuccessful = false
                    }
                }

                // Check for cancellation before final completion
                guard !Task.isCancelled else {
                    AppLogger.faceScan.info("🛑 Processing cancelled after Core Data save")
                    return
                }

                try await Task.sleep(nanoseconds: 300_000_000)

                // Final cancellation check before completing
                guard !Task.isCancelled else {
                    AppLogger.faceScan.info("🛑 Processing cancelled before completion")
                    return
                }

                // Complete!
                self.emotionalMetrics = emotional
                self.newAchievements = unlockedAchievements
                flowState = .complete

                // Track scan completion
                let duration = scanStartTime.map { Date().timeIntervalSince($0) } ?? 0
                AnalyticsManager.shared.trackScanCompleted(
                    duration: duration,
                    poseCount: viewModel.capturedPoses.count,
                    score: Double(emotional.skinHealthScore)
                )

                // Log success with metrics
                CrashReporter.shared.logUserAction("scan_completed_successfully")
                CrashReporter.shared.setCustomKey("skin_health_score", value: emotional.skinHealthScore)
                CrashReporter.shared.setCustomKey("achievements_unlocked", value: unlockedAchievements.count)

                // Finish processing - saves learned times for future estimates
                timeEstimator.finishProcessing()

                // Stop timers
                stopCyclingMessages()

                // Show achievement unlock if any
                if !unlockedAchievements.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showAchievementUnlock = true
                    }
                }

            } catch let scanError as ScanError {
                // Stop timers on error too
                stopCyclingMessages()
                timeEstimator.cancelProcessing()
                // Log scan error with full context
                CrashReporter.shared.logScanError(
                    scanError,
                    operation: "scan_processing",
                    metrics: ["capture_count": viewModel.capturedPoses.count]
                )

                // Check if error is transient and should auto-retry
                lastError = scanError

                if scanError.isTransient && retryCount < ScanConfiguration.maxAutoRetryAttempts {
                    // Automatic retry for transient errors
                    handleAutoRetry(for: scanError)
                } else {
                    // Show error to user (non-transient or max retries exceeded)
                    handleScanError(scanError)
                }
            } catch let timeoutError as TimeoutError {
                // Log timeout error
                CrashReporter.shared.logError(timeoutError, context: [
                    "operation": "scan_processing",
                    "timeout_type": "processing_timeout"
                ])

                // Handle timeout errors specifically
                flowState = .error("Processing timed out. Please close other apps, ensure good device performance, and try again.")
            } catch {
                // Log unexpected error with full context
                CrashReporter.shared.logError(error, context: [
                    "operation": "scan_processing",
                    "error_type": "unexpected",
                    "capture_count": viewModel.capturedPoses.count
                ])

                // Generic error fallback
                flowState = .error("An unexpected error occurred: \(error.localizedDescription). Please try again.")
            }
        }
    }

    // MARK: - Data Helpers

    private func loadPreviousClinicalMetrics() async -> Face3DMetrics? {
        // Check if Core Data is available - use PersistenceController directly to avoid Environment access warnings
        let context = PersistenceController.shared.viewContext
        guard context.persistentStoreCoordinator != nil else {
            return nil  // Silently skip if Core Data not available
        }

        // Use perform to safely access CoreData from any thread
        return await context.perform {
            // Fetch most recent session from Core Data
            let request = SessionResult.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            request.fetchLimit = 1  // Get most recent session

            do {
                let sessions = try context.fetch(request)
                guard let lastSession = sessions.first,
                      let data = lastSession.clinicalMetricsData else {
                    AppLogger.faceScan.info("ℹ️ No previous clinical metrics found (this is expected for first scan)")
                    return nil
                }

                // Use versioned loader with migration support
                let result = VersionedMetricsLoader.loadFace3DMetrics(from: data)

                switch result {
                case .success(let metrics, let version):
                    AppLogger.faceScan.info("✅ Loaded previous clinical metrics from \(lastSession.date) (v\(version.versionString))")
                    return metrics

                case .migrated(let metrics, let from, let to):
                    AppLogger.faceScan.info("🔄 Migrated clinical metrics from v\(from.versionString) to v\(to.versionString)")
                    return metrics

                case .incompatible(let version, let reason):
                    AppLogger.faceScan.warning("⚠️ Incompatible clinical metrics version v\(version.versionString): \(reason)")
                    DispatchQueue.main.async {
                        self.comparisonUnavailableReason = "Your previous scan is from an older app version and can't be compared"
                    }
                    return nil

                case .corrupted(let error):
                    AppLogger.faceScan.error("❌ Corrupted clinical metrics data: \(error.localizedDescription)")
                    CrashReporter.shared.logError(error, context: ["operation": "json_decode_clinical_versioned"])
                    DispatchQueue.main.async {
                        self.comparisonUnavailableReason = "Your previous scan data appears to be damaged and can't be compared"
                    }
                    return nil

                case .notFound:
                    AppLogger.faceScan.info("ℹ️ No previous clinical metrics found")
                    return nil
                }
            } catch {
                AppLogger.faceScan.error("Failed to fetch previous clinical metrics: \(error)")
                CrashReporter.shared.logError(error, context: ["operation": "fetch_clinical_metrics"])
                return nil
            }
        }
    }

    private func loadPreviousMetrics() async -> EmotionalMetrics? {
        // Check if Core Data is available - use PersistenceController directly to avoid Environment access warnings
        let context = PersistenceController.shared.viewContext
        guard context.persistentStoreCoordinator != nil else {
            return nil  // Silently skip if Core Data not available
        }

        // Use perform to safely access CoreData from any thread
        return await context.perform {
            // Fetch most recent session from Core Data
            let request = SessionResult.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            request.fetchLimit = 1  // Get most recent session

            do {
                let sessions = try context.fetch(request)
                guard let lastSession = sessions.first,
                      let data = lastSession.emotionalMetricsData else {
                    AppLogger.faceScan.info("ℹ️ No previous emotional metrics found (this is expected for first scan)")
                    return nil
                }

                // Use versioned loader with migration support
                let result = VersionedMetricsLoader.loadEmotionalMetrics(from: data)

                switch result {
                case .success(let metrics, let version):
                    AppLogger.faceScan.info("✅ Loaded previous emotional metrics from \(lastSession.date) (v\(version.versionString))")
                    return metrics

                case .migrated(let metrics, let from, let to):
                    AppLogger.faceScan.info("🔄 Migrated emotional metrics from v\(from.versionString) to v\(to.versionString)")
                    return metrics

                case .incompatible(let version, let reason):
                    AppLogger.faceScan.warning("⚠️ Incompatible emotional metrics version v\(version.versionString): \(reason)")
                    DispatchQueue.main.async {
                        self.comparisonUnavailableReason = "Your previous scan is from an older app version and can't be compared"
                    }
                    return nil

                case .corrupted(let error):
                    AppLogger.faceScan.error("❌ Corrupted emotional metrics data: \(error.localizedDescription)")
                    CrashReporter.shared.logError(error, context: ["operation": "json_decode_emotional_versioned"])
                    DispatchQueue.main.async {
                        self.comparisonUnavailableReason = "Your previous scan data appears to be damaged and can't be compared"
                    }
                    return nil

                case .notFound:
                    AppLogger.faceScan.info("ℹ️ No previous emotional metrics found")
                    return nil
                }
            } catch {
                AppLogger.faceScan.error("Failed to fetch previous emotional metrics: \(error)")
                CrashReporter.shared.logError(error, context: ["operation": "fetch_emotional_metrics"])
                return nil
            }
        }
    }

    private func saveToCoreData(emotionalMetrics: EmotionalMetrics, clinicalMetrics: Face3DMetrics, faceImage: CGImage?, heatmapData: [HeatmapType: Data]?, context: NSManagedObjectContext) async {
        isSaving = true
        saveSuccessful = nil

        // Check if context has a persistent store coordinator
        guard context.persistentStoreCoordinator != nil else {
            // Core Data is unavailable - use fallback storage instead
            AppLogger.faceScan.warning("⚠️ Core Data unavailable - using fallback JSON storage")

            do {
                try fallbackStorage.saveSession(emotionalMetrics: emotionalMetrics, clinicalMetrics: clinicalMetrics)
                isSaving = false
                saveSuccessful = true  // Saved to fallback successfully
                AppLogger.faceScan.info("✅ Session saved to fallback storage")
            } catch {
                AppLogger.faceScan.error("❌ Failed to save to fallback storage: \(error)")
                isSaving = false
                saveSuccessful = false
                saveErrorMessage = "Failed to save results. Please export your data."
                showSaveErrorAlert = true
            }
            return
        }

        // Use perform to safely access CoreData from any thread
        let success = await context.perform {
            let session = SessionResult(context: context)
            session.id = UUID()
            session.date = Date()
            session.deviceModel = UIDevice.current.model
            session.deviceOS = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"

            // Save overall and sub-scores
            session.overallScore = Double(emotionalMetrics.skinHealthScore)
            session.textureAvg = Double(emotionalMetrics.smoothness)
            session.pigmentationAvg = Double(emotionalMetrics.evenness)
            session.blurQuality = Double(emotionalMetrics.youthfulness)
            session.moistureSpecular = Double(emotionalMetrics.radiance)
            session.moistureSmoothness = Double(emotionalMetrics.freshness)

            // Save discoloration
            session.discolorationIndex = Double(clinicalMetrics.globalDiscolorationScore)

            // Save regional scores from clinical metrics
            session.leftCheekScore = Self.extractROIScore(for: .leftCheek, from: clinicalMetrics)
            session.rightCheekScore = Self.extractROIScore(for: .rightCheek, from: clinicalMetrics)
            session.foreheadScore = Self.extractROIScore(for: .forehead, from: clinicalMetrics)
            session.chinScore = Self.extractROIScore(for: .chin, from: clinicalMetrics)

            // Save pores and acne scores
            session.poresScore = Double(clinicalMetrics.poreAnalysis?.visibilityScore ?? 0)
            session.acneScore = Double(clinicalMetrics.acneAnalysis?.overallScore ?? 0)

            // Save face image and thumbnail
            if let faceImage = faceImage {
                // Metal textures have origin at bottom-left, UIImage expects top-left
                // Fix orientation by rotating 180 degrees before saving
                let uiFaceImage = UIImage(cgImage: faceImage, scale: 1.0, orientation: .down)
                // Render with correct orientation baked in (JPEG doesn't preserve orientation metadata)
                UIGraphicsBeginImageContextWithOptions(uiFaceImage.size, false, 1.0)
                uiFaceImage.draw(in: CGRect(origin: .zero, size: uiFaceImage.size))
                let correctedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                session.faceImage = correctedImage?.jpegData(compressionQuality: 0.9)
                AppLogger.faceScan.info("💾 Saved face image (\(faceImage.width)x\(faceImage.height))")

                // Generate and save thumbnail (600x600 for sharp display on modern devices)
                if let correctedImage = correctedImage {
                    let thumbnailSize = CGSize(width: 600, height: 600)
                    UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, 1.0)
                    correctedImage.draw(in: CGRect(origin: .zero, size: thumbnailSize))
                    let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    session.thumbnail = thumbnail?.jpegData(compressionQuality: 0.9)
                    AppLogger.faceScan.info("💾 Saved thumbnail (600x600)")
                }
            } else {
                AppLogger.faceScan.warning("⚠️ No face image available to save")
            }

            // Save heatmaps (already resized and converted to Data)
            if let heatmapData = heatmapData {
                if let composite = heatmapData[.composite] {
                    session.heatmapComposite = composite
                    AppLogger.faceScan.info("💾 Saved composite heatmap")
                }
                if let sharpness = heatmapData[.sharpness] {
                    session.heatmapSharpness = sharpness
                    AppLogger.faceScan.info("💾 Saved sharpness heatmap")
                }
                if let texture = heatmapData[.texture] {
                    session.heatmapTexture = texture
                    AppLogger.faceScan.info("💾 Saved texture heatmap")
                }
                if let pigmentation = heatmapData[.pigmentation] {
                    session.heatmapPigmentation = pigmentation
                    AppLogger.faceScan.info("💾 Saved pigmentation heatmap")
                }
                if let moisture = heatmapData[.moisture] {
                    session.heatmapMoisture = moisture
                    AppLogger.faceScan.info("💾 Saved moisture heatmap")
                }
            } else {
                AppLogger.faceScan.warning("⚠️ No heatmaps available to save")
            }

            // Store full emotional metrics as versioned JSON
            do {
                let versionedWrapper = try VersionedEmotionalMetrics(metrics: emotionalMetrics)
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                session.emotionalMetricsData = try encoder.encode(versionedWrapper)
                AppLogger.faceScan.info("💾 Saved emotional metrics with version \(MetricsVersion.current.versionString)")
            } catch {
                AppLogger.faceScan.error("Failed to encode emotional metrics: \(error)")
                CrashReporter.shared.logError(error, context: ["operation": "json_encode_emotional"])
                return false
            }

            // Store full clinical metrics as versioned JSON (for comparisons)
            do {
                let versionedWrapper = try VersionedFace3DMetrics(metrics: clinicalMetrics)
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                session.clinicalMetricsData = try encoder.encode(versionedWrapper)
                AppLogger.faceScan.info("💾 Saved clinical metrics with version \(MetricsVersion.current.versionString)")
            } catch {
                AppLogger.faceScan.error("Failed to encode clinical metrics: \(error)")
                CrashReporter.shared.logError(error, context: ["operation": "json_encode_clinical"])
                return false
            }

            // Save to Core Data
            do {
                try context.save()
                AppLogger.faceScan.debug("✅ Session saved successfully to Core Data!")

                return true
            } catch {
                AppLogger.faceScan.error("❌ Failed to save session: \(error.localizedDescription)")
                if let nserror = error as NSError? {
                    AppLogger.faceScan.error("   Domain: \(nserror.domain), Code: \(nserror.code)")
                    AppLogger.faceScan.error("   UserInfo: \(nserror.userInfo)")
                    // Check for common Core Data save errors
                    if nserror.domain == NSCocoaErrorDomain {
                        switch nserror.code {
                        case 134030: // NSPersistentStoreSaveConflictsError
                            AppLogger.faceScan.error("   Save conflict detected - another save may be in progress")
                        case 134020: // NSManagedObjectValidationError
                            AppLogger.faceScan.error("   Validation error - some required fields may be missing")
                        case 134060: // NSPersistentStoreTimeoutError
                            AppLogger.faceScan.error("   Timeout - Core Data took too long to respond")
                        default:
                            break
                        }
                    }
                }
                CrashReporter.shared.logError(error, context: [
                    "operation": "core_data_save",
                    "retry_count": "\(saveRetryCount)"
                ])
                return false
            }
        }

        isSaving = false
        saveSuccessful = success

        if success {
            // CRITICAL FIX: Process pending changes to ensure @FetchRequest in other views updates immediately
            // Without this, saved sessions won't appear in history/insights until app restart
            await MainActor.run {
                context.processPendingChanges()
                AppLogger.faceScan.debug("✅ Context changes processed - new session should be visible in all views")
            }

            // Clear any pending save data and reset retry count on success
            pendingSaveData = nil
            saveRetryCount = 0
        } else {
            // Add to persistent queue for automatic retry
            saveQueue.enqueueSave(emotionalMetrics: emotionalMetrics, clinicalMetrics: clinicalMetrics)

            // Store pending data for immediate retry option
            pendingSaveData = (emotionalMetrics, clinicalMetrics)
            saveErrorMessage = "Failed to save to device storage. Your results are queued for automatic retry."
            showSaveErrorAlert = true
        }
    }

    private func retrySaveToCoreData() {
        guard let data = pendingSaveData else { return }

        saveRetryCount += 1
        AppLogger.faceScan.info("🔄 Retrying Core Data save (attempt \(saveRetryCount))...")

        // Capture context before async
        // Note: Face image and heatmaps not available during retry - will save without them
        let capturedContext = PersistenceController.shared.viewContext
        Task {
            await saveToCoreData(emotionalMetrics: data.emotionalMetrics, clinicalMetrics: data.clinicalMetrics, faceImage: nil, heatmapData: nil, context: capturedContext)
        }
    }

    private func startChallenge() {
        if let metrics = emotionalMetrics {
            _ = GamificationManager.shared.startNewChallenge(baselineSkinHealthScore: metrics.skinHealthScore)
        }
    }

    /// Extract regional score from Face3DMetrics (static to use in context.perform closure)
    private static func extractROIScore(for region: Face3DROI, from metrics: Face3DMetrics) -> Double {
        // Get ROI metrics for this region
        guard let roiMetrics = metrics.roiMetrics[region] else {
            // Fallback to overall score if ROI not found
            return Double(metrics.overallScore)
        }

        // Compute composite score from multiple factors
        // Weight: smoothness 40%, pigmentation 30%, quality 20%, moisture 10%
        let smoothnessScore = Double(roiMetrics.roughnessScore)  // Higher = smoother
        let pigmentationScore = Double(roiMetrics.pigmentationScore)  // Higher = more even
        let qualityScore = Double(roiMetrics.qualityScore * 100)  // Convert 0-1 to 0-100
        let moistureScore = Double(roiMetrics.moistureProxy.moistureIndex * 100)  // Convert 0-1 to 0-100

        let compositeScore = (smoothnessScore * 0.4) +
                           (pigmentationScore * 0.3) +
                           (qualityScore * 0.2) +
                           (moistureScore * 0.1)

        return min(100, max(0, compositeScore))  // Clamp to 0-100
    }

    /// Resize UIImage to target size (static for use in context.perform closure)
    /// Uses scale 0.0 for automatic screen scale to maintain best quality
    private static func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        let context = UIGraphicsGetCurrentContext()
        context?.interpolationQuality = .high

        image.draw(in: CGRect(origin: .zero, size: size))

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: - Achievement Unlock Overlay

struct AchievementUnlockOverlay: View {
    let achievements: [Achievement]
    let onDismiss: () -> Void

    @State private var showDetails = false

    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(Designs.Opacity.semiTransparent)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Achievement card
            VStack(spacing: Designs.Spacing.large) {
                Image(systemName: "trophy.fill")
                    .font(AppFont.scoreDisplayLarge)
                    .foregroundColor(.orange)

                Text("Achievement Unlocked!")
                    .font(.title)
                    .fontWeight(.bold)

                ForEach(achievements.prefix(1)) { achievement in
                    VStack(spacing: Designs.Spacing.small) {
                        Image(systemName: achievement.iconName)
                            .font(AppFont.scoreDisplay)
                            .foregroundColor(.orange)

                        Text(achievement.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(achievement.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Awesome!")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, Designs.Spacing.xxxLarge)
                        .padding(.vertical, Designs.Spacing.small)
                        .background(Color.blue)
                        .cornerRadius(Designs.Radius.medium)
                }
                .padding(.top, Designs.Spacing.xSmall)
            }
            .padding(Designs.Spacing.xxLarge)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(radius: Designs.Spacing.large)
            )
            .padding(.horizontal, Designs.Spacing.xxxLarge)
            .scaleEffect(showDetails ? 1 : 0.8)
            .opacity(showDetails ? 1 : 0)
        }
        .onAppear {
            withAnimation(Designs.Animation.spring) {
                showDetails = true
            }

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}

// MARK: - EmotionalScan3DFlowView Extension - Error Handling & Time Management

extension EmotionalScan3DFlowView {
    // MARK: - Auto Retry Logic

    private func handleAutoRetry(for error: ScanError) {
        retryCount += 1
        isAutoRetrying = true

        // Calculate exponential backoff delay
        let attemptDelay = min(
            ScanConfiguration.retryBaseDelay * pow(2.0, Double(retryCount - 1)),
            ScanConfiguration.maxRetryDelay
        )

        // Track retry
        AnalyticsManager.shared.trackScanRetry(attempt: retryCount, reason: error.id)

        AppLogger.faceScan.info("🔄 Auto-retrying scan (attempt \(retryCount)/\(ScanConfiguration.maxAutoRetryAttempts)) after \(attemptDelay)s for error: \(error.id)")

        // Update UI to show retry status
        if ScanConfiguration.showRetryProgress {
            flowState = .autoRetrying(
                attempt: retryCount,
                of: ScanConfiguration.maxAutoRetryAttempts,
                reason: error.errorDescription ?? "Unknown error"
            )
        }

        // Schedule retry with exponential backoff
        Task {
            try? await Task.sleep(nanoseconds: UInt64(attemptDelay * 1_000_000_000))

            isAutoRetrying = false
            // Reset to preparing state to restart scan
            flowState = .preparing(countdown: 3)
            AppLogger.faceScan.info("✅ Restarting scan after auto-retry")
        }
    }

    private func handleScanError(_ error: ScanError) {
        // Track scan failure
        let duration = scanStartTime.map { Date().timeIntervalSince($0) } ?? 0
        AnalyticsManager.shared.trackScanFailed(reason: error.id, duration: duration)

        // Reset retry count for next scan
        retryCount = 0
        isAutoRetrying = false

        // Log if max retries were exceeded
        if error.isTransient {
            AppLogger.faceScan.warning("⚠️ Max auto-retries (\(ScanConfiguration.maxAutoRetryAttempts)) exceeded for transient error: \(error.id)")
        }

        // Show error message to user
        switch error {
        case .mergeFailed(let reason):
            let message = reason ?? "Failed to merge 3D face meshes. Please try scanning again with better lighting."
            flowState = .error(message)
        case .bakeFailed:
            flowState = .error("Failed to generate skin texture. Please ensure good, even lighting and try again.")
        case .metricsFailed:
            flowState = .error("Failed to analyze skin metrics. Please rescan with a neutral expression.")
        case .invalidData:
            flowState = .error("Invalid scan data captured. Please hold still and maintain a neutral expression.")
        case .processingTimeout:
            flowState = .error("Processing took too long. Please close other apps and try again.")
        case .arSessionFailed:
            flowState = .error("Face tracking failed. Please restart the app and try again.")
        case .cameraUnavailable:
            flowState = .error("Camera unavailable. Please check camera permissions and try again.")
        case .cancelled:
            flowState = .error("Scan was cancelled.")
        case .processingError(let message):
            flowState = .error("Processing error: \(message)")
        case .trueDepthUnsupported:
            flowState = .error("This device doesn't support TrueDepth scanning. Face ID compatible iPhone required.")
        case .faceNotDetected:
            flowState = .error("No face detected. Please position your face in the frame.")
        case .multipleFacesDetected:
            flowState = .error("Multiple faces detected. Please scan one person at a time.")
        case .lightingTooLow(let current, let required):
            flowState = .error("Lighting too low (\(Int(current*100))%). Move to brighter area (need \(Int(required*100))%).")
        case .lightingTooHigh(let current, let max):
            flowState = .error("Too bright (\(Int(current*100))%). Reduce lighting (max \(Int(max*100))%).")
        case .blurryImage:
            flowState = .error("Image is blurry. Hold device steady.")
        case .occludedFace:
            flowState = .error("Face partially covered. Remove hands/hair from face.")
        case .invalidExpression:
            flowState = .error("Invalid expression. Please maintain neutral expression.")
        case .coreDataSaveFailed(let error):
            flowState = .error("Failed to save scan: \(error.localizedDescription)")
        case .insufficientStorage:
            flowState = .error("Insufficient storage. Please free up space and try again.")
        case .corruptedData:
            flowState = .error("Data corrupted. Please try scanning again.")
        case .metricsGenerationFailed:
            flowState = .error("Failed to generate skin metrics. Please try scanning again with better lighting.")
        }
    }

    // MARK: - Time Management

    /// Get the current processing phase based on the step number
    private func getCurrentProcessingPhase() -> ProcessingPhase? {
        guard processingStep >= 1 && processingStep <= totalProcessingSteps else {
            return nil
        }
        return ProcessingPhase(rawValue: Int(processingStep))
    }

    /// Format countdown time in MM:SS format
    private func formatCountdownTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d remaining", minutes, remainingSeconds)
    }

    /// Format elapsed time since start
    private func formatElapsedTime(since startTime: Date) -> String {
        let elapsed = Int(Date().timeIntervalSince(startTime))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Start the breathing animation for the processing circle
    private func startBreathingAnimation() {
        breathingTimer?.invalidate()

        // FIXED: Use RunLoop.main with .common mode to ensure timer fires
        // even during other animations or UI operations
        let timer = Timer(timeInterval: 0.05, repeats: true) { [self] _ in
            // Smooth sine wave animation (completes full cycle every ~3 seconds)
            breathingPhase += 0.1
            if breathingPhase > .pi * 2 {
                breathingPhase = 0
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        breathingTimer = timer
    }

    /// Stop the breathing animation
    private func stopBreathingAnimation() {
        breathingTimer?.invalidate()
        breathingTimer = nil
    }

    // MARK: - JSON Backup Functions

    /// Create JSON backup before attempting CoreData save (failsafe)
    private func createJSONBackup(_ emotional: EmotionalMetrics, _ clinical: Face3DMetrics) async -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())

        guard let backupDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            AppLogger.faceScan.error("❌ Failed to get document directory for backup")
            return nil
        }

        let taviBackupDir = backupDir
            .appendingPathComponent("Tavi")
            .appendingPathComponent("Backups")

        do {
            try FileManager.default.createDirectory(at: taviBackupDir, withIntermediateDirectories: true)
        } catch {
            AppLogger.faceScan.error("❌ Failed to create backup directory: \(error)")
            return nil
        }

        let backupURL = taviBackupDir.appendingPathComponent("scan_\(timestamp).json")

        do {
            let emotionalData = try JSONEncoder().encode(emotional).base64EncodedString()
            let clinicalData = try JSONEncoder().encode(clinical).base64EncodedString()

            let backup: [String: Any] = [
                "timestamp": timestamp,
                "emotionalMetrics": emotionalData,
                "clinicalMetrics": clinicalData,
                "deviceModel": UIDevice.current.model,
                "deviceOS": "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
            ]

            let data = try JSONSerialization.data(withJSONObject: backup)
            try data.write(to: backupURL)

            AppLogger.faceScan.info("✅ Created backup at: \(backupURL.path)")
            return backupURL
        } catch {
            AppLogger.faceScan.error("❌ Failed to create JSON backup: \(error)")
            return nil
        }
    }

    /// Export pending data to JSON for manual backup
    private func exportPendingDataToJSON() {
        guard let data = pendingSaveData else { return }

        Task {
            guard let backupURL = await createJSONBackup(data.emotionalMetrics, data.clinicalMetrics) else {
                AppLogger.faceScan.error("❌ Failed to create backup URL for export")
                return
            }

            // Share using system share sheet
            let activityVC = UIActivityViewController(
                activityItems: [backupURL],
                applicationActivities: nil
            )

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }

    // MARK: - Cycling Message Timer

    /// Start timer to cycle through processing messages every 3 seconds
    private func startCyclingMessages() {
        cyclingMessageIndex = 0
        cyclingTimer?.invalidate()

        // FIXED: Use RunLoop.main with .common mode for consistency
        // Note: No need for [weak self] in SwiftUI Views (structs don't have retain cycles)
        let timer = Timer(timeInterval: 3.0, repeats: true) { [self] _ in
            withAnimation(Designs.Animation.standard) {
                cyclingMessageIndex += 1
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        cyclingTimer = timer
    }

    /// Stop cycling message timer
    private func stopCyclingMessages() {
        cyclingTimer?.invalidate()
        cyclingTimer = nil
    }

    /// Smoothly animate progress to target step with intermediate values
    private func smoothlyUpdateProgress(to targetStep: Int) {
        withAnimation(Designs.Animation.linear) {
            processingStep = Double(targetStep)
        }
    }
}

// MARK: - Custom Pie Slice Shape

/// A pie slice shape that fills from 0° (top) clockwise based on progress
struct PieSlice: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        // Start from top (270°) and sweep clockwise
        let startAngle = Angle(degrees: -90)
        let endAngle = Angle(degrees: -90 + (360 * Double(progress)))

        // Move to center
        path.move(to: center)

        // Draw line to start of arc
        path.addLine(to: CGPoint(
            x: center.x + radius * CGFloat(cos(startAngle.radians)),
            y: center.y + radius * CGFloat(sin(startAngle.radians))
        ))

        // Draw the arc
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        // Close the path back to center
        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EmotionalScan3DFlowView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
