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
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var flowState: FlowState = .preparing(countdown: 3)
    @State private var showResults = false
    @State private var processingProgress: String = ""
    @State private var processingStep: Int = 0
    @State private var totalProcessingSteps: Int = 6
    @State private var estimatedTimeRemaining: String = ""
    @State private var processingStartTime: Date?
    @State private var currentStepStartTime: Date?
    @State private var timeRemainingSeconds: Int = 0
    @State private var timeEstimator = ProcessingTimeEstimator()
    @State private var deviceWarningMessage: String?
    @State private var emotionalMetrics: EmotionalMetrics?
    @State private var clinicalMetrics: Face3DMetrics?
    @State private var previousMetrics: EmotionalMetrics?
    @State private var comparisonUnavailableReason: String?
    @State private var showShareSheet = false
    @State private var showAchievementUnlock = false
    @State private var newAchievements: [Achievement] = []

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
        // Check if Core Data is unavailable (highest priority)
        if fallbackStorage.isUsingFallback {
            return .coreDataUnavailable
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
                        // Capturing phase - show confirmation to prevent accidental data loss
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
        .onChange(of: scenePhase) { oldPhase, newPhase in
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
        VStack(spacing: 40) {
            Spacer()

            // Processing circle - fills radially like a clock/pie chart
            ZStack {
                // Background circle (light gray)
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 160, height: 160)

                // Progress pie fill (like clock hand sweeping)
                Circle()
                    .trim(from: 0, to: CGFloat(processingStep) / CGFloat(totalProcessingSteps))
                    .fill(
                        AngularGradient(
                            colors: [.blue, .cyan, .blue],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        )
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: processingStep)

                // White background circle for percentage text
                Circle()
                    .fill(Color(uiColor: .systemBackground))
                    .frame(width: 120, height: 120)

                // Percentage text in center
                Text("\(Int((Double(processingStep) / Double(totalProcessingSteps)) * 100))%")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 16) {
                // Main processing message
                Text(processingProgress)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Detailed info - what's actually happening
                if let currentPhase = getCurrentProcessingPhase() {
                    Text(currentPhase.detailedDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Time remaining
                if timeRemainingSeconds > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.subheadline)
                        Text(formatTimeRemaining(timeRemainingSeconds))
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.secondary)
                } else if timeRemainingSeconds < 0 {
                    // Show "Almost done" when time estimate is exceeded
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.subheadline)
                        Text("Almost done...")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }

                // Quality explanation - why it takes time (only for slow steps)
                if let currentPhase = getCurrentProcessingPhase(),
                   let explanation = currentPhase.qualityExplanation {
                    Text(explanation)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }

                // Device-specific warning (if applicable)
                if let warning = deviceWarningMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)

                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
                }

                // Background processing warning
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Text("Please keep the app open during processing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            startTimeCountdown()
        }
    }

    // MARK: - Saving View

    private var savingView: some View {
        VStack(spacing: 40) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)

            VStack(spacing: 12) {
                Text("Saving Results...")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Please wait while we save your scan to history")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if saveRetryCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                        Text("Retry attempt \(saveRetryCount)/3")
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                    .padding(.top, 8)
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
            // Background blur
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Countdown circle
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 8)
                        .frame(width: 180, height: 180)

                    Circle()
                        .trim(from: 0, to: CGFloat(countdown) / 3.0)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: countdown)

                    Text("\(countdown)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(spacing: 16) {
                    Text("Get Ready!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "face.smiling")
                                .foregroundColor(.cyan)
                            Text("Keep a neutral expression")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "light.max")
                                .foregroundColor(.yellow)
                            Text("Ensure good lighting")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "figure.stand")
                                .foregroundColor(.green)
                            Text("Hold device at eye level")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }

                        // Processing time estimate
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                            Text("Processing will take \(timeEstimator.getTimeRangeDescription())")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 32)
                }

                // Skip button
                Button {
                    flowState = .capturing
                    viewModel.startGuidance()
                } label: {
                    Text("Skip")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(25)
                }
                .padding(.bottom, 40)

                Spacer()
            }
        }
        .onAppear {
            startCountdown()
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
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)

            VStack(spacing: 12) {
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
                    .padding(.horizontal, 32)
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
                    .padding(.vertical, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            VStack(spacing: 12) {
                Text("Oops!")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                // Restart capture with grace period
                flowState = .preparing(countdown: 3)
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
            }

            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
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
                processingStep = 1
                processingProgress = ProcessingPhase.meshMerge.description
                timeRemainingSeconds = timeEstimator.estimateTimeRemaining(from: .meshMerge)
                CrashReporter.shared.setCustomKey("processing_step", value: "mesh_merge")

                let merged = try await withTimeout(
                    seconds: timeEstimator.getDeviceAdjustedTimeout(ScanConfiguration.meshMergeTimeout),
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
                processingStep = 2
                processingProgress = ProcessingPhase.textureBake.description
                timeRemainingSeconds = timeEstimator.estimateTimeRemaining(from: .textureBake)
                CrashReporter.shared.setCustomKey("processing_step", value: "texture_bake")

                let bakeResult = try await withTimeout(
                    seconds: timeEstimator.getDeviceAdjustedTimeout(ScanConfiguration.textureBakeTimeout),
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
                processingStep = 3
                processingProgress = ProcessingPhase.metricsAnalysis.description
                timeRemainingSeconds = timeEstimator.estimateTimeRemaining(from: .metricsAnalysis)
                CrashReporter.shared.setCustomKey("processing_step", value: "metrics_analysis")

                // Attempt metrics computation with timeout protection
                AppLogger.faceScan.info("🔬 Starting metrics computation with timeout...")

                let computedClinicalMetrics = try await withTimeout(
                    seconds: timeEstimator.getDeviceAdjustedTimeout(ScanConfiguration.metricsComputationTimeout),
                    operation: "Metrics Computation"
                ) {
                    guard let result = await viewModel.compute3DMetrics() else {
                        throw ScanError.metricsFailed(analyzer: nil, reason: nil)
                    }
                    return result
                }

                try await Task.sleep(nanoseconds: 500_000_000)

                // Step 4: Convert to emotional metrics
                processingStep = 4
                processingProgress = ProcessingPhase.emotionalMetrics.description
                timeRemainingSeconds = timeEstimator.estimateTimeRemaining(from: .emotionalMetrics)
                CrashReporter.shared.setCustomKey("processing_step", value: "emotional_metrics")

                let userProfile = UserProfileManager.shared.loadProfile()
                let previousClinicalMetrics = await loadPreviousClinicalMetrics()
                let loadedPreviousMetrics = await loadPreviousMetrics()

                let emotional = EmotionalMetricsGenerator.generate(
                    from: computedClinicalMetrics,
                    previousMetrics: previousClinicalMetrics,
                    userProfile: userProfile
                )

                // Store both metrics for results view
                self.clinicalMetrics = computedClinicalMetrics
                self.previousMetrics = loadedPreviousMetrics

                // Step 5: Update gamification
                processingStep = 5
                processingProgress = ProcessingPhase.gamification.description
                timeRemainingSeconds = timeEstimator.estimateTimeRemaining(from: .gamification)
                CrashReporter.shared.setCustomKey("processing_step", value: "gamification")

                let updatedStreak = GamificationManager.shared.recordScan()

                let challenge = GamificationManager.shared.getCurrentChallenge()
                // Update challenge if active (would need to implement proper update method)

                let glowImprovement = previousClinicalMetrics != nil
                    ? emotional.glowScore - EmotionalMetricsGenerator.generate(from: previousClinicalMetrics!).glowScore
                    : 0

                let unlockedAchievements = GamificationManager.shared.checkAndUnlockAchievements(
                    totalScans: updatedStreak.totalScans,
                    currentStreak: updatedStreak.currentStreak,
                    glowScore: emotional.glowScore,
                    glowImprovement: glowImprovement,
                    challengeComplete: challenge?.isCompleted ?? false
                )

                // Step 6: Save to Core Data (with timeout protection)
                processingStep = 6
                processingProgress = ProcessingPhase.coreDataSave.description
                timeRemainingSeconds = timeEstimator.estimateTimeRemaining(from: .coreDataSave)
                CrashReporter.shared.setCustomKey("processing_step", value: "core_data_save")

                // Try to save with timeout - saveToCoreData() handles its own errors and shows alerts
                do {
                    try await withTimeout(
                        seconds: timeEstimator.getDeviceAdjustedTimeout(ScanConfiguration.coreDataSaveTimeout),
                        operation: "CoreData Save"
                    ) {
                        await saveToCoreData(
                            emotionalMetrics: emotional,
                            clinicalMetrics: computedClinicalMetrics
                        )
                    }
                } catch {
                    // Timeout error - add to persistent queue and alert user
                    AppLogger.faceScan.error("⚠️ Core Data save timed out: \(error.localizedDescription)")
                    await MainActor.run {
                        saveQueue.enqueueSave(emotionalMetrics: emotional, clinicalMetrics: computedClinicalMetrics)
                        pendingSaveData = (emotional, computedClinicalMetrics)
                        saveErrorMessage = "Save operation timed out. Your results are queued for automatic retry."
                        showSaveErrorAlert = true
                        saveSuccessful = false
                    }
                }

                try await Task.sleep(nanoseconds: 300_000_000)

                // Complete!
                await MainActor.run {
                    self.emotionalMetrics = emotional
                    self.newAchievements = unlockedAchievements
                    flowState = .complete

                    // Track scan completion
                    let duration = scanStartTime.map { Date().timeIntervalSince($0) } ?? 0
                    AnalyticsManager.shared.trackScanCompleted(
                        duration: duration,
                        poseCount: viewModel.capturedPoses.count,
                        score: emotional.glowScore
                    )

                    // Log success with metrics
                    CrashReporter.shared.logUserAction("scan_completed_successfully")
                    CrashReporter.shared.setCustomKey("glow_score", value: emotional.glowScore)
                    CrashReporter.shared.setCustomKey("achievements_unlocked", value: unlockedAchievements.count)

                    // Show achievement unlock if any
                    if !unlockedAchievements.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            showAchievementUnlock = true
                        }
                    }
                }

            } catch let scanError as ScanError {
                // Log scan error with full context
                CrashReporter.shared.logScanError(
                    scanError,
                    operation: "scan_processing",
                    metrics: ["capture_count": viewModel.capturedPoses.count]
                )

                // Check if error is transient and should auto-retry
                await MainActor.run {
                    lastError = scanError

                    if scanError.isTransient && retryCount < ScanConfiguration.maxAutoRetryAttempts {
                        // Automatic retry for transient errors
                        handleAutoRetry(for: scanError)
                    } else {
                        // Show error to user (non-transient or max retries exceeded)
                        handleScanError(scanError)
                    }
                }
            } catch let timeoutError as TimeoutError {
                // Log timeout error
                CrashReporter.shared.logError(timeoutError, context: [
                    "operation": "scan_processing",
                    "timeout_type": "processing_timeout"
                ])

                // Handle timeout errors specifically
                await MainActor.run {
                    flowState = .error("Processing timed out. Please close other apps, ensure good device performance, and try again.")
                }
            } catch {
                // Log unexpected error with full context
                CrashReporter.shared.logError(error, context: [
                    "operation": "scan_processing",
                    "error_type": "unexpected",
                    "capture_count": viewModel.capturedPoses.count
                ])

                // Generic error fallback
                await MainActor.run {
                    flowState = .error("An unexpected error occurred: \(error.localizedDescription). Please try again.")
                }
            }
        }
    }

    // MARK: - Data Helpers

    private func loadPreviousClinicalMetrics() async -> Face3DMetrics? {
        // Check if Core Data is available - capture context early to avoid Environment access warnings
        let context = viewContext
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
                guard let sessions = try context.fetch(request),
                      let lastSession = sessions.first,
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
                    Task { @MainActor in
                        self.comparisonUnavailableReason = "Previous scan (v\(version.versionString)) is incompatible: \(reason)"
                    }
                    return nil

                case .corrupted(let error):
                    AppLogger.faceScan.error("❌ Corrupted clinical metrics data: \(error.localizedDescription)")
                    CrashReporter.shared.logError(error, context: ["operation": "json_decode_clinical_versioned"])
                    Task { @MainActor in
                        self.comparisonUnavailableReason = "Previous scan data is corrupted"
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
        // Check if Core Data is available - capture context early to avoid Environment access warnings
        let context = viewContext
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
                guard let sessions = try context.fetch(request),
                      let lastSession = sessions.first,
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
                    Task { @MainActor in
                        self.comparisonUnavailableReason = "Previous scan (v\(version.versionString)) is incompatible: \(reason)"
                    }
                    return nil

                case .corrupted(let error):
                    AppLogger.faceScan.error("❌ Corrupted emotional metrics data: \(error.localizedDescription)")
                    CrashReporter.shared.logError(error, context: ["operation": "json_decode_emotional_versioned"])
                    Task { @MainActor in
                        self.comparisonUnavailableReason = "Previous scan data is corrupted"
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

    private func saveToCoreData(emotionalMetrics: EmotionalMetrics, clinicalMetrics: Face3DMetrics) async {
        await MainActor.run {
            isSaving = true
            saveSuccessful = nil
        }

        // Check if context has a persistent store coordinator - capture context early to avoid Environment access warnings
        let context = viewContext
        guard context.persistentStoreCoordinator != nil else {
            // Core Data is unavailable - use fallback storage instead
            AppLogger.faceScan.warning("⚠️ Core Data unavailable - using fallback JSON storage")

            do {
                try await fallbackStorage.saveSession(emotionalMetrics: emotionalMetrics, clinicalMetrics: clinicalMetrics)
                await MainActor.run {
                    isSaving = false
                    saveSuccessful = true  // Saved to fallback successfully
                }
                AppLogger.faceScan.info("✅ Session saved to fallback storage")
            } catch {
                AppLogger.faceScan.error("❌ Failed to save to fallback storage: \(error)")
                await MainActor.run {
                    isSaving = false
                    saveSuccessful = false
                    saveErrorMessage = "Failed to save results. Please export your data."
                    showSaveErrorAlert = true
                }
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
            session.overallScore = Double(emotionalMetrics.glowScore)
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
                AppLogger.faceScan.info("✅ Session saved successfully to Core Data!")
                return true
            } catch {
                AppLogger.faceScan.error("❌ Failed to save session: \(error.localizedDescription)")
                CrashReporter.shared.logError(error, context: [
                    "operation": "core_data_save",
                    "retry_count": "\(saveRetryCount)"
                ])
                return false
            }
        }

        await MainActor.run {
            isSaving = false
            saveSuccessful = success

            if success {
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
    }

    private func retrySaveToCoreData() {
        guard let data = pendingSaveData else { return }

        saveRetryCount += 1
        AppLogger.faceScan.info("🔄 Retrying Core Data save (attempt \(saveRetryCount))...")

        Task {
            await saveToCoreData(emotionalMetrics: data.emotionalMetrics, clinicalMetrics: data.clinicalMetrics)
        }
    }

    private func startChallenge() {
        if let metrics = emotionalMetrics {
            _ = GamificationManager.shared.startNewChallenge(baselineGlowScore: metrics.glowScore)
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
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Achievement card
            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 80))

                Text("Achievement Unlocked!")
                    .font(.title)
                    .fontWeight(.bold)

                ForEach(achievements.prefix(1)) { achievement in
                    VStack(spacing: 12) {
                        Text(achievement.emoji)
                            .font(.system(size: 64))

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
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(radius: 20)
            )
            .padding(.horizontal, 40)
            .scaleEffect(showDetails ? 1 : 0.8)
            .opacity(showDetails ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showDetails = true
            }

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

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

            await MainActor.run {
                isAutoRetrying = false
                // Reset to preparing state to restart scan
                flowState = .preparing(countdown: 3)
                AppLogger.faceScan.info("✅ Restarting scan after auto-retry")
            }
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
        }
    }

    // MARK: - Time Management

    /// Get the current processing phase based on the step number
    private func getCurrentProcessingPhase() -> ProcessingPhase? {
        guard processingStep >= 1 && processingStep <= totalProcessingSteps else {
            return nil
        }
        return ProcessingPhase(rawValue: processingStep)
    }

    /// Format seconds into human-readable time string
    private func formatTimeRemaining(_ seconds: Int) -> String {
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds > 0 {
                return "\(minutes)m \(remainingSeconds)s remaining"
            } else {
                return "\(minutes)m remaining"
            }
        } else if seconds > 0 {
            return "\(seconds)s remaining"
        } else {
            return "Almost done..."
        }
    }

    /// Start the real-time countdown timer
    private func startTimeCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            Task { @MainActor in
                if timeRemainingSeconds > 0 {
                    timeRemainingSeconds -= 1
                } else {
                    timer.invalidate()
                }

                // Stop timer if we're no longer processing
                if case .processing = flowState {
                    // Continue
                } else {
                    timer.invalidate()
                }
            }
        }
    }

    // MARK: - JSON Backup Functions

    /// Create JSON backup before attempting CoreData save (failsafe)
    private func createJSONBackup(_ emotional: EmotionalMetrics, _ clinical: Face3DMetrics) async -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())

        let backupDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tavi")
            .appendingPathComponent("Backups")

        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        let backupURL = backupDir.appendingPathComponent("scan_\(timestamp).json")

        let backup: [String: Any] = [
            "timestamp": timestamp,
            "emotionalMetrics": try! JSONEncoder().encode(emotional).base64EncodedString(),
            "clinicalMetrics": try! JSONEncoder().encode(clinical).base64EncodedString(),
            "deviceModel": UIDevice.current.model,
            "deviceOS": "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        ]

        let data = try! JSONSerialization.data(withJSONObject: backup)
        try! data.write(to: backupURL)

        AppLogger.faceScan.info("✅ Created backup at: \(backupURL.path)")
        return backupURL
    }

    /// Export pending data to JSON for manual backup
    private func exportPendingDataToJSON() {
        guard let data = pendingSaveData else { return }

        Task {
            let backupURL = await createJSONBackup(data.emotionalMetrics, data.clinicalMetrics)

            // Share using system share sheet
            await MainActor.run {
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
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EmotionalScan3DFlowView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
