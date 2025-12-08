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

    @State private var flowState: FlowState = .preparing(countdown: 3)
    @State private var showResults = false
    @State private var processingProgress: String = ""
    @State private var processingStep: Double = 0  // Changed to Double for smooth progress
    @State private var totalProcessingSteps: Double = 6
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
                        dismiss()
                    }
                } else if case .capturing = flowState {
                    Button("Cancel") {
                        // Capturing phase - cancel directly without confirmation
                        viewModel.resetCalibration()
                        dismiss()
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
            Button("Keep Scanning", role: .cancel) {
                // Do nothing - continue scanning
            }
            Button("Cancel Scan", role: .destructive) {
                // User confirmed cancellation
                viewModel.resetCalibration()
                dismiss()
            }
        } message: {
            let capturedCount = viewModel.capturedPoses.count
            if capturedCount > 0 {
                Text("You've captured \(capturedCount) pose\(capturedCount == 1 ? "" : "s"). If you cancel now, your progress will be lost and you'll need to start over.\n\nAre you sure you want to cancel?")
            } else {
                Text("If you cancel now, you'll need to start the scan over.\n\nAre you sure you want to cancel?")
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

    // MARK: - Processing View

    private var processingView: some View {
        ZStack {
            // Blue gradient background - matching preparing screen
            LinearGradient(
                colors: [
                    Color(red: 95/255, green: 111/255, blue: 230/255),  // #5F6FE6
                    Color(red: 80/255, green: 200/255, blue: 220/255)   // Cyan
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Processing circle - contained within bounds
                ZStack {
                    // Outer glow ring (subtle pulse, contained)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(Designs.Opacity.veryLight + 0.02), Color.clear],
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
                                colors: [Color.white.opacity(0.08), Color.clear],
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
                                colors: [Color.white, Color.white.opacity(Designs.Opacity.almostOpaque)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: Designs.Sizes.scoreCircleLarge, height: Designs.Sizes.scoreCircleLarge)
                        .shadow(color: Color.white.opacity(Designs.Opacity.medium), radius: Designs.Spacing.medium, x: 0, y: 0)

                    // Center content - percentage with progress ring overlay
                    ZStack {
                        // Progress ring behind
                        Circle()
                            .trim(from: 0, to: CGFloat(processingStep) / CGFloat(totalProcessingSteps))
                            .stroke(
                                Color(red: 95/255, green: 111/255, blue: 230/255),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: Designs.Sizes.achievementIcon, height: Designs.Sizes.achievementIcon)
                            .rotationEffect(.degrees(-90))
                            .animation(Designs.Animation.gentle, value: processingStep)

                        // Percentage text
                        VStack(spacing: 2) {
                            Text("\(Int((processingStep / totalProcessingSteps) * 100))%")
                                .font(AppFont.displayLarge)
                                .foregroundColor(Color(red: 95/255, green: 111/255, blue: 230/255))

                            // Step indicator
                            Text("\(Int(processingStep))/\(Int(totalProcessingSteps))")
                                .font(AppFont.footnote)
                                .foregroundColor(Color(red: 95/255, green: 111/255, blue: 230/255).opacity(Designs.Opacity.semiTransparent))
                        }
                    }
                }
                .padding(.bottom, Designs.Spacing.xxLarge)

                // Processing messages - white text like preparing screen
                VStack(spacing: Designs.Spacing.small) {
                    // Main message (white header) - REDUCED SIZE
                    Text(processingProgress)
                        .font(AppFont.headlinePrimary)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Designs.Spacing.xxLarge)

                    // Detailed status (white subtext with slight transparency) - REDUCED SIZE + CYCLING
                    if let currentPhase = getCurrentProcessingPhase() {
                        Text(currentPhase.getCyclingMessage(index: cyclingMessageIndex))
                            .font(AppFont.caption)
                            .foregroundColor(.white.opacity(Designs.Opacity.almostOpaque))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Designs.Spacing.xxLarge)
                            .animation(Designs.Animation.standard, value: cyclingMessageIndex)
                            .transition(.opacity)
                    }

                    // Countdown timer - shows estimated time remaining (counts DOWN)
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(AppFont.metricLabel)
                        if timeEstimator.remainingSeconds > 0 {
                            Text(formatCountdownTime(timeEstimator.remainingSeconds))
                                .font(AppFont.subheadingPrimary)
                                .monospacedDigit()
                        } else {
                            Text("Almost done...")
                                .font(AppFont.caption)
                        }
                    }
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.top, Designs.Spacing.xSmall)

                    // Show learning indicator for first few scans
                    if !timeEstimator.hasLearnedEstimates() {
                        Text("Estimate improves with each scan")
                            .font(AppFont.micro)
                            .foregroundColor(.white.opacity(Designs.Opacity.semiOpaque + 0.1))
                            .padding(.top, Designs.Spacing.xxxSmall)
                    }
                }
                .padding(.bottom, Designs.Spacing.xLarge)

                Spacer()

                // Bottom checklist - white circles and text like preparing screen
                VStack(spacing: Designs.Spacing.small) {
                    prepChecklistItem(icon: "checkmark.circle.fill", text: "Please keep your phone on for the analysis")
                    prepChecklistItem(icon: "wand.and.stars", text: "Analyzing your skin")
                    prepChecklistItem(icon: "iphone", text: "Keep the app open")
                }
                .padding(.horizontal, Designs.Spacing.xxLarge)
                .padding(.bottom, Designs.Spacing.xLarge)
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

    // MARK: - Saving View

    private var savingView: some View {
        VStack(spacing: Designs.Spacing.xxxLarge) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)

            VStack(spacing: Designs.Spacing.small) {
                Text("Saving Results...")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Please wait while we save your scan to history")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Designs.Spacing.xxLarge)

                if saveRetryCount > 0 {
                    HStack(spacing: Designs.Spacing.xxSmall) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                        Text("Retry attempt \(saveRetryCount)/3")
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                    .padding(.top, Designs.Spacing.xSmall)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    @State private var rotationAngle: Double = 0

    // MARK: - Preparing View

    private func preparingView(countdown: Int) -> some View {
        ZStack {
            // OLD DESIGN - Gradient background (blue to cyan)
            LinearGradient(
                colors: [
                    Color(red: 95/255, green: 111/255, blue: 230/255),  // #5F6FE6
                    Color(red: 80/255, green: 200/255, blue: 220/255)   // Cyan
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Large breathing circle with countdown (matches HTML preview)
                ZStack {
                    // Outer glow rings
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(Designs.Opacity.veryLight + 0.05), Color.clear],
                                center: .center,
                                startRadius: 80,
                                endRadius: 120
                            )
                        )
                        .frame(width: Designs.Sizes.frameXXXLarge, height: Designs.Sizes.frameXXXLarge)
                        .scaleEffect(countdown == 3 ? 1.0 : 1.2)
                        .opacity(countdown == 3 ? 1.0 : 0.5)
                        .animation(Designs.Animation.pulse, value: countdown)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.08), Color.clear],
                                center: .center,
                                startRadius: 120,
                                endRadius: 160
                            )
                        )
                        .frame(width: Designs.Sizes.displayXXLarge, height: Designs.Sizes.displayXXLarge)
                        .scaleEffect(countdown == 3 ? 1.0 : 1.15)
                        .opacity(countdown == 3 ? 1.0 : 0.3)
                        .animation(Designs.Animation.breathe, value: countdown)

                    // Main white breathing circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white, Color.white.opacity(Designs.Opacity.semiTransparent + 0.15)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: Designs.Sizes.scoreCircleLarge, height: Designs.Sizes.scoreCircleLarge)
                        .scaleEffect(countdown == 3 ? 1.0 : 1.15)
                        .animation(Designs.Animation.slowPulse, value: countdown)
                        .shadow(color: Color.white.opacity(Designs.Opacity.medium), radius: Designs.Radius.xLarge, x: 0, y: 0)

                    // Countdown number
                    Text("\(countdown)")
                        .font(AppFont.scoreDisplayLarge)
                        .foregroundColor(Color(red: 95/255, green: 111/255, blue: 230/255))  // #5F6FE6
                }
                .padding(.vertical, Designs.Spacing.large)

                // Title and subtitle
                VStack(spacing: Designs.Spacing.small) {
                    Text("Preparing scan")
                        .font(AppFont.title)
                        .foregroundColor(.white)

                    Text("Take a deep breath")
                        .font(AppFont.headlineSecondary)
                        .foregroundColor(.white.opacity(Designs.Opacity.almostTransparent))
                }
                .padding(.bottom, Designs.Spacing.xLarge)

                Spacer()

                // Checklist
                VStack(spacing: 14) {
                    prepChecklistItem(icon: "checkmark", text: "Find bright, natural lighting")
                    prepChecklistItem(icon: "checkmark", text: "Remove glasses if wearing")
                    prepChecklistItem(icon: "iphone", text: "Hold device at eye level")
                }
                .padding(.horizontal, Designs.Spacing.xxLarge)
                .padding(.bottom, Designs.Spacing.medium)

                // Skip countdown button
                Button {
                    flowState = .capturing
                    viewModel.startGuidance()
                } label: {
                    Text("Skip")
                        .font(AppFont.subheadingPrimary)
                        .foregroundColor(.white.opacity(Designs.Opacity.semiTransparent))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Designs.Spacing.medium)
                        .background(Color.white.opacity(Designs.Opacity.veryLight + 0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, Designs.Spacing.xxLarge)
                .padding(.bottom, Designs.Spacing.xLarge)
            }
        }
        .onAppear {
            startCountdown()
        }
    }

    // Helper for checklist items with white background circles
    private func prepChecklistItem(icon: String, text: String) -> some View {
        HStack(spacing: Designs.Spacing.large) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(Designs.Opacity.light + 0.05))
                        .frame(width: Designs.Sizes.cardIcon, height: Designs.Sizes.cardIcon)

                Image(systemName: icon)
                    .font(AppFont.metricValue)
                    .foregroundColor(.white)
            }

            Text(text)
                .font(AppFont.bodyMedium)
                .foregroundColor(.white)

            Spacer()
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

        // Continue countdown
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
            if case .preparing = flowState {  // Only continue if still preparing
                let nextCount = currentCount - 1
                if nextCount > 0 {
                    flowState = .preparing(countdown: nextCount)
                    // CRITICAL: Recursively call startCountdown to continue the countdown
                    startCountdown()
                } else {
                    flowState = .capturing
                    viewModel.startGuidance()
                }
            }
        }
    }

    // MARK: - Auto Retry View

    private func autoRetryView(attempt: Int, total: Int, reason: String) -> some View {
        VStack(spacing: Designs.Spacing.xLarge) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)

            VStack(spacing: Designs.Spacing.small) {
                Text("Retrying...")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Attempt \(attempt) of \(total)")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
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
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Designs.Spacing.xSmall)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: Designs.Spacing.xLarge) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(AppFont.scoreDisplay)
                .foregroundColor(.orange)

            VStack(spacing: Designs.Spacing.small) {
                Text("Oops!")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                    .background(Color.blue)
                    .cornerRadius(Designs.Radius.medium)
            }

            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Designs.Spacing.xSmall)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
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

        Task {
            do {
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

                try await Task.sleep(nanoseconds: 500_000_000)

                // Step 2: Bake texture (with timeout protection)
                smoothlyUpdateProgress(to: 2)
                processingProgress = ProcessingPhase.textureBake.description
                timeEstimator.startPhase(.textureBake)
                CrashReporter.shared.setCustomKey("processing_step", value: "texture_bake")

                let adjustedBakeTimeout = timeEstimator.getDeviceAdjustedTimeout(ScanConfiguration.textureBakeTimeout)
                AppLogger.faceScan.debug("📊 Texture bake timeout: \(Int(adjustedBakeTimeout))s (base: \(Int(ScanConfiguration.textureBakeTimeout))s)")

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

                // Step 6: Save to Core Data (with timeout protection)
                smoothlyUpdateProgress(to: 6)
                processingProgress = ProcessingPhase.coreDataSave.description
                timeEstimator.startPhase(.coreDataSave)
                CrashReporter.shared.setCustomKey("processing_step", value: "core_data_save")

                // Try to save with timeout - saveToCoreData() handles its own errors and shows alerts
                // CRITICAL: Use PersistenceController directly to avoid Environment access warnings
                let capturedContext = PersistenceController.shared.viewContext
                do {
                    try await withTimeout(
                        seconds: timeEstimator.getDeviceAdjustedTimeout(ScanConfiguration.coreDataSaveTimeout),
                        operation: "CoreData Save"
                    ) {
                        await saveToCoreData(
                            emotionalMetrics: emotional,
                            clinicalMetrics: computedClinicalMetrics,
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

                try await Task.sleep(nanoseconds: 300_000_000)

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

    private func saveToCoreData(emotionalMetrics: EmotionalMetrics, clinicalMetrics: Face3DMetrics, context: NSManagedObjectContext) async {
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
        let capturedContext = PersistenceController.shared.viewContext
        Task {
            await saveToCoreData(emotionalMetrics: data.emotionalMetrics, clinicalMetrics: data.clinicalMetrics, context: capturedContext)
        }
    }

    private func startChallenge() {
        if let metrics = emotionalMetrics {
            _ = GamificationManager.shared.startNewChallenge(baselineSkinHealthScore: metrics.skinHealthScore)
        }
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
        breathingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            DispatchQueue.main.async {
                // Smooth sine wave animation (completes full cycle every ~3 seconds)
                breathingPhase += 0.1
                if breathingPhase > .pi * 2 {
                    breathingPhase = 0
                }
            }
        }
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

        // Note: No need for [weak self] in SwiftUI Views (structs don't have retain cycles)
        cyclingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(Designs.Animation.standard) {
                cyclingMessageIndex += 1
            }
        }
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
