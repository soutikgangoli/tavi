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

    @State private var flowState: FlowState = .capturing
    @State private var showResults = false
    @State private var processingProgress: String = ""
    @State private var emotionalMetrics: EmotionalMetrics?
    @State private var clinicalMetrics: Face3DMetrics?
    @State private var showShareSheet = false
    @State private var showAchievementUnlock = false
    @State private var newAchievements: [Achievement] = []

    enum FlowState: Equatable {
        case capturing
        case processing
        case complete
        case error(String)
    }

    public init() {}

    public var body: some View {
        ZStack {
            // Main content based on state
            switch flowState {
            case .capturing:
                capturingView

            case .processing:
                processingView

            case .complete:
                if let metrics = emotionalMetrics {
                    CelebratoryResultsView(
                        emotionalMetrics: metrics,
                        clinicalMetrics: clinicalMetrics,
                        previousMetrics: loadPreviousMetrics(),
                        onStartChallenge: {
                            startChallenge()
                        },
                        onShareResults: {
                            showShareSheet = true
                        },
                        onViewProducts: {
                            // Navigate to products (placeholder)
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
                if flowState == .capturing {
                    Button("Cancel") {
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
    }

    // MARK: - Capturing View

    private var capturingView: some View {
        FaceScan3DView(
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
        .environmentObject(viewModel)
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Processing animation
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: rotationAngle)

                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            .onAppear {
                rotationAngle = 360
            }

            VStack(spacing: 12) {
                Text("Processing Your Scan")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(processingProgress)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    @State private var rotationAngle: Double = 0

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
                // Restart capture
                flowState = .capturing
                viewModel.startGuidance()
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

        // Log scan processing start with context
        CrashReporter.shared.logUserAction("scan_processing_started")
        CrashReporter.shared.setCustomKey("capture_count", value: viewModel.capturedPoses.count)

        Task {
            do {
                // Step 1: Merge meshes (with timeout protection)
                processingProgress = "Merging your 3D face scan... ✨"
                CrashReporter.shared.setCustomKey("processing_step", value: "mesh_merge")

                let merged = try await withTimeout(
                    seconds: ScanConfiguration.meshMergeTimeout,
                    operation: "Mesh Merge"
                ) {
                    guard let result = await viewModel.finalizeCapture() else {
                        throw ScanError.mergeFailed
                    }
                    return result
                }

                try await Task.sleep(nanoseconds: 500_000_000)

                // Step 2: Bake texture (with timeout protection)
                processingProgress = "Creating your skin texture map... 🎨"
                CrashReporter.shared.setCustomKey("processing_step", value: "texture_bake")

                let bakeResult = try await withTimeout(
                    seconds: ScanConfiguration.textureBakeTimeout,
                    operation: "Texture Baking"
                ) {
                    guard let result = await viewModel.bakeTextureFromSequence() else {
                        throw ScanError.bakeFailed
                    }
                    return result
                }

                try await Task.sleep(nanoseconds: 500_000_000)

                // Step 3: Compute clinical metrics (with timeout protection)
                processingProgress = "Analyzing your skin... 🔬"
                CrashReporter.shared.setCustomKey("processing_step", value: "metrics_analysis")

                let computedClinicalMetrics = try await withTimeout(
                    seconds: ScanConfiguration.metricsComputationTimeout,
                    operation: "Metrics Computation"
                ) {
                    guard let result = await viewModel.compute3DMetrics() else {
                        throw ScanError.metricsFailed
                    }
                    return result
                }

                try await Task.sleep(nanoseconds: 500_000_000)

                // Step 4: Convert to emotional metrics
                processingProgress = "Calculating your Skin Health Index... 🌟"
                CrashReporter.shared.setCustomKey("processing_step", value: "emotional_metrics")

                let userProfile = UserProfileManager.shared.loadProfile()
                let previousClinicalMetrics = await loadPreviousClinicalMetrics()

                let emotional = EmotionalMetricsGenerator.generate(
                    from: computedClinicalMetrics,
                    previousMetrics: previousClinicalMetrics,
                    userProfile: userProfile
                )

                // Store both metrics for results view
                self.clinicalMetrics = computedClinicalMetrics

                // Step 5: Update gamification
                processingProgress = "Updating your progress... 🎉"
                CrashReporter.shared.setCustomKey("processing_step", value: "gamification")

                let updatedStreak = GamificationManager.shared.recordScan()

                var challenge = GamificationManager.shared.getCurrentChallenge()
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
                processingProgress = "Saving your results... 💾"
                CrashReporter.shared.setCustomKey("processing_step", value: "core_data_save")

                try await withTimeout(
                    seconds: ScanConfiguration.coreDataSaveTimeout,
                    operation: "CoreData Save"
                ) {
                    await saveToCoreData(
                        emotionalMetrics: emotional,
                        clinicalMetrics: clinicalMetrics
                    )
                }

                try await Task.sleep(nanoseconds: 300_000_000)

                // Complete!
                await MainActor.run {
                    self.emotionalMetrics = emotional
                    self.newAchievements = unlockedAchievements
                    flowState = .complete

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

                // Handle specific scan errors with tailored recovery suggestions
                await MainActor.run {
                    switch scanError {
                    case .mergeFailed:
                        flowState = .error("Failed to merge 3D face meshes. Please try scanning again with better lighting.")
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
        // Use perform to safely access CoreData from any thread
        return await viewContext.perform {
            // Fetch most recent session from Core Data
            let request = SessionResult.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            request.fetchLimit = 1  // Get most recent session

            guard let sessions = try? self.viewContext.fetch(request),
                  let lastSession = sessions.first,
                  let data = lastSession.clinicalMetricsData,
                  let metrics = try? JSONDecoder().decode(Face3DMetrics.self, from: data) else {
                print("ℹ️ No previous clinical metrics found (this is expected for first scan)")
                return nil
            }

            print("✅ Loaded previous clinical metrics from \(lastSession.date ?? Date())")
            return metrics
        }
    }

    private func loadPreviousMetrics() async -> EmotionalMetrics? {
        // Use perform to safely access CoreData from any thread
        return await viewContext.perform {
            // Fetch most recent session from Core Data
            let request = SessionResult.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            request.fetchLimit = 1  // Get most recent session

            guard let sessions = try? self.viewContext.fetch(request),
                  let lastSession = sessions.first,
                  let data = lastSession.emotionalMetricsData,
                  let metrics = try? JSONDecoder().decode(EmotionalMetrics.self, from: data) else {
                print("ℹ️ No previous emotional metrics found (this is expected for first scan)")
                return nil
            }

            print("✅ Loaded previous emotional metrics from \(lastSession.date ?? Date())")
            return metrics
        }
    }

    private func saveToCoreData(emotionalMetrics: EmotionalMetrics, clinicalMetrics: Face3DMetrics) async {
        // Use perform to safely access CoreData from any thread
        await viewContext.perform {
            let session = SessionResult(context: self.viewContext)
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

            // Store full emotional metrics as JSON
            if let emotionalData = try? JSONEncoder().encode(emotionalMetrics) {
                session.emotionalMetricsData = emotionalData
            }

            // Store full clinical metrics as JSON (for comparisons)
            if let clinicalData = try? JSONEncoder().encode(clinicalMetrics) {
                session.clinicalMetricsData = clinicalData
            }

            // Save to Core Data
            do {
                try self.viewContext.save()
                print("✅ Session saved successfully!")
            } catch {
                print("❌ Failed to save session: \(error)")
            }
        }
    }

    private func startChallenge() {
        if let metrics = emotionalMetrics {
            let challenge = GamificationManager.shared.startNewChallenge(baselineGlowScore: metrics.glowScore)
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
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EmotionalScan3DFlowView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
