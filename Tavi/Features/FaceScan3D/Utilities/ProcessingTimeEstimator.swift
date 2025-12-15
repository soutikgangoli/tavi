//
//  ProcessingTimeEstimator.swift
//  Tavi
//
//  Device-aware processing time estimation for 3D face scans
//  Provides accurate time estimates based on device capabilities
//  Learns from actual processing times to improve future estimates
//

import Foundation
import Metal

/// Processing step in the scan pipeline
public enum ProcessingPhase: Int, CaseIterable {
    case meshMerge = 1
    case textureBake = 2
    case metricsAnalysis = 3
    case emotionalMetrics = 4
    case gamification = 5
    case coreDataSave = 6

    var description: String {
        switch self {
        case .meshMerge: return "Merging your 3D face scan... ✨"
        case .textureBake: return "Creating your skin texture map... 🎨"
        case .metricsAnalysis: return "Analyzing your skin 🔬"
        case .emotionalMetrics: return "Calculating your Skin Health Index... 🌟"
        case .gamification: return "Updating your progress... 🎉"
        case .coreDataSave: return "Saving your results... 💾"
        }
    }

    /// UserDefaults key for storing learned times for this phase
    var learnedTimeKey: String {
        return "\(AppDefaultsKey.processingTimePrefix)\(self.rawValue)"
    }

    /// Cycling messages for each phase (returns different message each time)
    func getCyclingMessage(index: Int) -> String {
        switch self {
        case .meshMerge:
            let messages = [
                "Merging 50+ captures into your 3D model",
                "Aligning facial geometry with precision",
                "Reconstructing your face in 3D space",
                "Combining multiple angles for accuracy",
                "Calculating spatial relationships between vertices",
                "Blending depth information from each pose",
                "Optimizing mesh topology for smooth surfaces",
                "Correcting for micro-movements during capture",
                "Building a unified coordinate system",
                "Removing duplicate vertices and artifacts",
                "Averaging overlapping regions for consistency",
                "Computing surface normals and curvature"
            ]
            return messages[index % messages.count]
        case .textureBake:
            let messages = [
                "Processing 4K resolution skin texture",
                "Mapping skin details onto your 3D model",
                "Blending texture samples for clarity",
                "Creating photorealistic skin representation",
                "Analyzing color information from multiple angles",
                "Correcting for lighting variations across captures",
                "Stitching together texture patches seamlessly",
                "Reducing shadows and specular highlights",
                "Normalizing color temperature across the face",
                "Enhancing fine details like pores and texture",
                "Applying anti-aliasing for smooth edges",
                "Generating UV coordinates for optimal mapping"
            ]
            return messages[index % messages.count]
        case .metricsAnalysis:
            let messages = [
                "Analyzing 50,000+ data points across your face",
                "Measuring pore size and distribution patterns",
                "Detecting fine lines and texture variations",
                "Evaluating skin tone uniformity and pigmentation",
                "Assessing hydration levels and skin quality",
                "Mapping facial contours and symmetry",
                "Quantifying surface roughness at microscale",
                "Identifying areas of redness or inflammation",
                "Measuring skin elasticity and firmness",
                "Detecting sun damage and hyperpigmentation",
                "Analyzing sebum distribution and shine",
                "Evaluating collagen density indicators",
                "Measuring wrinkle depth and distribution",
                "Assessing overall skin clarity and radiance",
                "Computing texture entropy across regions"
            ]
            return messages[index % messages.count]
        case .emotionalMetrics:
            let messages = [
                "Computing your personalized Skin Health Index",
                "Comparing with your previous scan results",
                "Calculating improvement percentage",
                "Generating personalized recommendations",
                "Identifying your strongest skin attributes",
                "Detecting patterns in your skin's progress",
                "Weighting metrics by clinical importance",
                "Factoring in environmental and lifestyle data",
                "Computing age-adjusted baseline comparisons",
                "Translating technical metrics to friendly scores",
                "Highlighting areas showing improvement"
            ]
            return messages[index % messages.count]
        case .gamification:
            let messages = [
                "Updating achievements and milestones",
                "Checking for new unlocks and rewards",
                "Calculating your consistency streak",
                "Updating your progress towards goals"
            ]
            return messages[index % messages.count]
        case .coreDataSave:
            let messages = [
                "Encrypting and saving your results securely",
                "Writing scan data to device storage",
                "Creating timestamped history entry",
                "Backing up metrics for future comparison"
            ]
            return messages[index % messages.count]
        }
    }

    /// Detailed explanation with interesting facts
    var detailedDescription: String {
        // Default message (will be overridden by cycling)
        return getCyclingMessage(index: 0)
    }

    /// Quality explanation - why this step takes time (nil if step is fast)
    var qualityExplanation: String? {
        switch self {
        case .meshMerge:
            return "Taking time to ensure millimeter-accurate results"
        case .textureBake:
            return "Ensuring every detail is captured clearly"
        case .metricsAnalysis:
            return "Analyzing your skin with clinical-grade precision…"
        case .emotionalMetrics:
            return "Calculating your unique skin profile"
        case .gamification, .coreDataSave:
            return nil  // These are fast, no explanation needed
        }
    }
}

/// Device performance tier for time estimation
public enum DevicePerformanceTier: CustomStringConvertible {
    case flagship      // iPhone 15 Pro - fastest
    case high          // iPhone 14 Pro, 13 Pro
    case standard      // iPhone 12 Pro
    case legacy        // iPhone 11 Pro, X/XS/XR

    public var description: String {
        return deviceDescription
    }

    /// Performance multiplier relative to baseline (iPhone 15 Pro = 1.0)
    /// Used for time ESTIMATES (optimistic)
    var performanceMultiplier: Double {
        switch self {
        case .flagship: return 1.0
        case .high: return 1.15
        case .standard: return 1.35
        case .legacy: return 1.65
        }
    }

    /// Timeout multiplier for SAFETY margins (more conservative than estimates)
    /// Used for timeout values to prevent premature cancellation
    /// These are larger than performanceMultiplier to provide adequate buffer
    var timeoutMultiplier: Double {
        switch self {
        case .flagship: return 1.2    // 20% buffer for newest devices
        case .high: return 1.4        // 40% buffer for recent devices
        case .standard: return 1.7    // 70% buffer for older Pro models
        case .legacy: return 2.2      // 120% buffer for legacy devices
        }
    }

    /// User-friendly device description
    var deviceDescription: String {
        switch self {
        case .flagship: return "Latest iPhone"
        case .high: return "Recent iPhone"
        case .standard: return "iPhone 12 Pro"
        case .legacy: return "Older iPhone"
        }
    }

    /// Warning message for longer processing times
    var processingWarning: String? {
        switch self {
        case .flagship, .high:
            return nil
        case .standard:
            return "Processing may take 3-4 minutes on iPhone 12 Pro"
        case .legacy:
            return "Processing may take 4-5 minutes on older devices"
        }
    }
}

/// Accurate time estimation for processing steps based on device capabilities
/// Learns from actual processing times to improve future estimates
@MainActor
public class ProcessingTimeEstimator: ObservableObject {

    // MARK: - Singleton for Tracking

    /// Shared instance for tracking actual times across scans
    public static let shared = ProcessingTimeEstimator()

    // MARK: - Baseline Times (iPhone 15 Pro performance)

    /// Baseline processing times in seconds for each phase (iPhone 15 Pro)
    /// These are initial estimates that get refined with actual measurements
    private let baselineTimes: [ProcessingPhase: Double] = [
        .meshMerge: 18.0,         // Mesh merging - actual ~10-25s
        .textureBake: 15.0,       // Texture baking - actual ~8-20s
        .metricsAnalysis: 35.0,   // Metrics computation - actual ~20-50s (longest step)
        .emotionalMetrics: 6.0,   // Emotional metrics calculation - actual ~3-10s
        .gamification: 2.0,       // Gamification updates - actual ~1-3s
        .coreDataSave: 4.0        // Core Data save - actual ~2-6s
    ]

    /// Buffer percentage to add to estimates (ensures countdown doesn't go negative)
    private let estimateBufferPercent: Double = 0.15  // 15% buffer

    /// Maximum number of historical times to keep for averaging
    private let maxHistoricalSamples = 5

    /// Key for storing scan count
    private let scanCountKey = AppDefaultsKey.processingTimeScanCount

    /// Key for storing last known device tier (to detect changes)
    private let deviceTierKey = "tavi.processingTime.deviceTier"

    private let deviceCalibrator = DeviceCalibrator()
    private var currentDevice: DeviceInfo?
    private var performanceTier: DevicePerformanceTier

    // MARK: - Live Tracking State

    /// Currently active phase being tracked
    private var activePhase: ProcessingPhase?

    /// Start time of active phase
    private var phaseStartTime: Date?

    /// Accumulated actual times for current scan (for learning)
    private var currentScanActualTimes: [ProcessingPhase: Double] = [:]

    /// Published remaining time for UI binding
    @Published public var remainingSeconds: Int = 0

    /// Published current phase for UI
    @Published public var currentPhase: ProcessingPhase?

    /// Timer for countdown
    private var countdownTimer: Timer?

    // MARK: - Initialization

    public init() {
        self.currentDevice = deviceCalibrator.getCurrentDevice()
        self.performanceTier = Self.determinePerformanceTier(device: currentDevice)

        // Check if device tier changed since last run - reset learned times if so
        let lastTier = UserDefaults.standard.string(forKey: deviceTierKey)
        let currentTierName = performanceTier.deviceDescription
        if lastTier != currentTierName {
            if lastTier != nil {
                AppLogger.faceScan.info("📱 Device tier changed from '\(lastTier!)' to '\(currentTierName)' - resetting learned times")
                resetLearnedTimes()
            }
            UserDefaults.standard.set(currentTierName, forKey: deviceTierKey)
        }
    }

    /// Create a non-shared instance (for backward compatibility)
    public static func createInstance() -> ProcessingTimeEstimator {
        return ProcessingTimeEstimator()
    }

    // MARK: - Public API

    /// Get estimated time remaining from a specific processing step
    /// - Parameters:
    ///   - currentPhase: The current processing phase
    ///   - includeCurrentPhase: Whether to include the current phase in the estimate
    /// - Returns: Estimated seconds remaining
    public func estimateTimeRemaining(
        from currentPhase: ProcessingPhase,
        includeCurrentPhase: Bool = true
    ) -> Int {
        var totalSeconds: Double = 0

        let startPhase = includeCurrentPhase ? currentPhase.rawValue : currentPhase.rawValue + 1

        for phase in ProcessingPhase.allCases where phase.rawValue >= startPhase {
            totalSeconds += getLearnedOrBaselineTime(for: phase)
        }

        // Add buffer to prevent countdown going negative
        totalSeconds *= (1.0 + estimateBufferPercent)

        return Int(totalSeconds.rounded())
    }

    /// Get estimated time for a specific phase (with learning)
    /// - Parameter phase: The processing phase
    /// - Returns: Estimated seconds for this phase
    public func estimatePhaseTime(_ phase: ProcessingPhase) -> Int {
        let time = getLearnedOrBaselineTime(for: phase)
        return Int((time * (1.0 + estimateBufferPercent)).rounded())
    }

    /// Get total estimated processing time for entire pipeline
    /// - Returns: Total estimated seconds
    public func estimateTotalTime() -> Int {
        return estimateTimeRemaining(from: .meshMerge, includeCurrentPhase: true)
    }

    /// Get device performance tier
    public func getPerformanceTier() -> DevicePerformanceTier {
        return performanceTier
    }

    /// Get device-specific processing warning message
    public func getProcessingWarning() -> String? {
        return performanceTier.processingWarning
    }

    /// Get device-adjusted timeout value
    /// - Parameter baseTimeout: Base timeout value for flagship devices
    /// - Returns: Adjusted timeout scaled by device performance
    public func getDeviceAdjustedTimeout(_ baseTimeout: TimeInterval) -> TimeInterval {
        return baseTimeout * performanceTier.performanceMultiplier
    }

    /// Get device-adjusted timeout specifically for texture baking
    /// Uses more conservative timeoutMultiplier to prevent premature cancellation
    /// - Parameter baseTimeout: Base timeout value (should be from ScanConfiguration.getTextureBakeTimeout())
    /// - Returns: Adjusted timeout with safety buffer for device tier
    public func getTextureBakeTimeout(_ baseTimeout: TimeInterval) -> TimeInterval {
        return baseTimeout * performanceTier.timeoutMultiplier
    }

    /// Get user-friendly time range description
    /// - Returns: Human-readable time estimate (e.g., "2-3 minutes")
    public func getTimeRangeDescription() -> String {
        let totalSeconds = estimateTotalTime()
        let minutes = totalSeconds / 60

        // Add ±15% range for variability
        let minMinutes = max(1, Int(Double(minutes) * 0.85))
        let maxMinutes = Int(Double(minutes) * 1.15)

        if minMinutes == maxMinutes {
            return "\(minMinutes) minute\(minMinutes == 1 ? "" : "s")"
        } else {
            return "\(minMinutes)-\(maxMinutes) minutes"
        }
    }

    // MARK: - Live Countdown Management

    /// Total elapsed time since processing started
    @Published public var elapsedSeconds: Int = 0

    /// Estimated total time (updated as phases complete)
    @Published public var estimatedTotalSeconds: Int = 0

    /// Progress percentage (0-100)
    @Published public var progressPercent: Double = 0

    /// Processing start time
    private var processingStartTime: Date?

    /// Start the processing countdown timer
    /// Call this when processing begins
    public func startCountdown() {
        // Reset state
        currentScanActualTimes = [:]
        activePhase = nil
        phaseStartTime = nil
        processingStartTime = Date()
        elapsedSeconds = 0

        // Calculate initial total estimated time
        estimatedTotalSeconds = estimateTotalTime()
        remainingSeconds = estimatedTotalSeconds
        progressPercent = 0

        // Start countdown timer that ticks every second
        // FIXED: Use RunLoop.main with .common mode to ensure timer fires
        // even during animations or gesture tracking
        countdownTimer?.invalidate()

        // Create timer on main thread and add to common modes
        // This prevents the timer from getting stuck during UI operations
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Use Task to properly access MainActor-isolated properties
            // The timer fires on main thread but Swift needs explicit MainActor context
            Task { @MainActor in
                // Update elapsed time
                if let start = self.processingStartTime {
                    self.elapsedSeconds = Int(Date().timeIntervalSince(start))
                }

                // SMART COUNTDOWN: Use phase-based progress instead of pure time-based
                // This prevents the timer from getting "stuck" when processing takes longer
                self.updateSmartCountdown()
            }
        }

        // CRITICAL: Add timer to RunLoop.main with .common mode
        // .common includes both .default and .tracking modes, ensuring
        // the timer fires even during scrolling, animations, or other UI activity
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer

        AppLogger.faceScan.info("⏱️ Processing started. Initial estimate: \(self.estimatedTotalSeconds)s")
    }

    /// Smart countdown that uses phase-based progress
    /// Prevents getting stuck by dynamically adjusting estimates
    private func updateSmartCountdown() {
        guard let currentPhase = activePhase else {
            // No active phase yet - just decrement normally
            if remainingSeconds > 1 {
                remainingSeconds -= 1
            }
            return
        }

        // Calculate phase-based progress (each phase is worth ~16.67% for 6 phases)
        let totalPhases = Double(ProcessingPhase.allCases.count)
        let completedPhases = Double(currentPhase.rawValue - 1)

        // Calculate progress within current phase based on elapsed time
        var phaseProgress: Double = 0
        if let startTime = phaseStartTime {
            let phaseElapsed = Date().timeIntervalSince(startTime)
            let phaseEstimate = getLearnedOrBaselineTime(for: currentPhase)
            // Cap phase progress at 95% to leave room for completion
            phaseProgress = min(0.95, phaseElapsed / max(phaseEstimate, 1))
        }

        // Total progress = completed phases + current phase progress
        let totalProgress = (completedPhases + phaseProgress) / totalPhases

        // Update progress percent (cap at 95% to leave room for final steps)
        progressPercent = min(95, totalProgress * 100)

        // Calculate remaining seconds based on progress
        // If we're at 50% progress, remaining should be ~50% of total estimate
        let progressFraction = totalProgress
        let estimatedRemaining = Double(estimatedTotalSeconds) * (1.0 - progressFraction)

        // Smooth transition - don't let remaining jump around too much
        let targetRemaining = max(5, Int(estimatedRemaining))

        // FIXED: Prevent oscillation by using a dead zone and always decrementing
        // The countdown should always go down (or stay same), never up
        // This prevents the 54->51->54 oscillation issue
        let difference = remainingSeconds - targetRemaining

        if difference > 5 {
            // We're way behind estimate - catch up faster (decrement by 2)
            remainingSeconds -= 2
        } else if remainingSeconds > 5 {
            // Normal countdown - always decrement by 1
            // Never increase the countdown even if estimate changed
            remainingSeconds -= 1
        }
        // Keep at 5 minimum until finishProcessing() is called
    }

    /// Stop the countdown timer
    public func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    /// Mark the start of a processing phase
    /// - Parameter phase: The phase that is starting
    public func startPhase(_ phase: ProcessingPhase) {
        // Record end of previous phase if any
        if let previousPhase = activePhase, let startTime = phaseStartTime {
            let actualDuration = Date().timeIntervalSince(startTime)
            currentScanActualTimes[previousPhase] = actualDuration

            // Log actual vs estimated for debugging
            let estimated = getLearnedOrBaselineTime(for: previousPhase)
            let diff = actualDuration - estimated
            let diffSign = diff >= 0 ? "+" : ""
            AppLogger.faceScan.debug("⏱️ Phase \(previousPhase.rawValue) done: \(String(format: "%.1f", actualDuration))s (est: \(String(format: "%.1f", estimated))s, \(diffSign)\(String(format: "%.1f", diff))s)")
        }

        // Start tracking new phase
        activePhase = phase
        phaseStartTime = Date()
        currentPhase = phase

        // NOTE: We no longer recalculate remaining time here
        // The countdown now decrements linearly by 1 every second
        // This prevents the countdown from getting stuck

        AppLogger.faceScan.info("⏱️ Starting phase \(phase.rawValue): \(phase.description)")
    }

    /// Update remaining time using ACTUAL elapsed time for completed phases
    private func updateRemainingTimeAccurate() {
        guard let currentPhase = activePhase else { return }

        // Calculate time spent in current phase so far
        var currentPhaseElapsed: Double = 0
        if let startTime = phaseStartTime {
            currentPhaseElapsed = Date().timeIntervalSince(startTime)
        }

        // Estimate remaining time for current phase
        let currentPhaseEstimate = getLearnedOrBaselineTime(for: currentPhase)
        let currentPhaseRemaining = max(0, currentPhaseEstimate - currentPhaseElapsed)

        // Add estimates for future phases only
        var futureEstimate: Double = 0
        for phase in ProcessingPhase.allCases where phase.rawValue > currentPhase.rawValue {
            futureEstimate += getLearnedOrBaselineTime(for: phase)
        }

        // Total remaining = current phase remaining + future phases
        let totalRemaining = currentPhaseRemaining + futureEstimate

        // Add small buffer (10%) to avoid hitting 0 before done
        let bufferedRemaining = totalRemaining * 1.10

        remainingSeconds = max(0, Int(bufferedRemaining.rounded()))

        // Calculate accurate total estimate based on actual elapsed + remaining
        let actualElapsed = Double(elapsedSeconds)
        estimatedTotalSeconds = Int((actualElapsed + bufferedRemaining).rounded())

        // Update progress percentage
        if estimatedTotalSeconds > 0 {
            progressPercent = min(99, (actualElapsed / Double(estimatedTotalSeconds)) * 100)
        }
    }

    /// Mark the end of processing and save learned times
    public func finishProcessing() {
        // Record final phase
        if let phase = activePhase, let startTime = phaseStartTime {
            let duration = Date().timeIntervalSince(startTime)
            currentScanActualTimes[phase] = duration
            AppLogger.faceScan.debug("⏱️ Final phase \(phase.rawValue) completed in \(String(format: "%.1f", duration))s")
        }

        // Calculate total actual time
        let totalActual = processingStartTime.map { Date().timeIntervalSince($0) } ?? 0

        // Save learned times for future accuracy
        saveLearnedTimes()

        // Stop countdown
        stopCountdown()

        // Smoothly animate to completion (96 -> 97 -> 98 -> 99 -> 100)
        // This prevents a jarring jump from wherever we were to 100%
        Task { @MainActor in
            // Quick countdown from current remaining to 0
            for remaining in stride(from: min(self.remainingSeconds, 4), through: 0, by: -1) {
                self.remainingSeconds = remaining
                self.progressPercent = 96 + Double(4 - remaining)
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second per tick
            }
            self.remainingSeconds = 0
            self.progressPercent = 100
        }

        // Log accuracy report
        let initialEstimate = estimateTotalTime()
        let accuracy = totalActual > 0 ? (1.0 - abs(Double(initialEstimate) - totalActual) / totalActual) * 100 : 0
        AppLogger.faceScan.info("⏱️ Processing complete! Actual: \(String(format: "%.1f", totalActual))s, Initial estimate: \(initialEstimate)s, Accuracy: \(String(format: "%.0f", accuracy))%")

        // Reset state
        activePhase = nil
        phaseStartTime = nil
        currentPhase = nil
        processingStartTime = nil

        // Increment scan count
        let scanCount = UserDefaults.standard.integer(forKey: scanCountKey)
        UserDefaults.standard.set(scanCount + 1, forKey: scanCountKey)

        AppLogger.faceScan.info("⏱️ Saved timing data. Total scans: \(scanCount + 1)")
    }

    /// Cancel processing (don't save learned times)
    public func cancelProcessing() {
        stopCountdown()
        activePhase = nil
        phaseStartTime = nil
        currentPhase = nil
        processingStartTime = nil
        remainingSeconds = 0
        elapsedSeconds = 0
        progressPercent = 0
        currentScanActualTimes = [:]
    }

    // MARK: - Learning System

    /// Get learned time or baseline with device adjustment
    private func getLearnedOrBaselineTime(for phase: ProcessingPhase) -> Double {
        // Check if we have learned times for this phase
        if let learnedTimes = UserDefaults.standard.array(forKey: phase.learnedTimeKey) as? [Double],
           !learnedTimes.isEmpty {
            // Use weighted average (more recent times weighted higher)
            let average = weightedAverage(learnedTimes)
            return average
        }

        // Fall back to baseline with device multiplier
        let baseTime = baselineTimes[phase] ?? 10.0
        return baseTime * performanceTier.performanceMultiplier
    }

    /// Calculate weighted average (recent values weighted more)
    private func weightedAverage(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }

        var weightedSum: Double = 0
        var weightSum: Double = 0

        for (index, value) in values.enumerated() {
            // More recent values (higher index) get higher weight
            let weight = Double(index + 1)
            weightedSum += value * weight
            weightSum += weight
        }

        return weightedSum / weightSum
    }

    /// Save actual times to UserDefaults for future estimates
    private func saveLearnedTimes() {
        for (phase, actualTime) in currentScanActualTimes {
            var times = UserDefaults.standard.array(forKey: phase.learnedTimeKey) as? [Double] ?? []

            // Add new time
            times.append(actualTime)

            // Keep only last N samples
            if times.count > maxHistoricalSamples {
                times = Array(times.suffix(maxHistoricalSamples))
            }

            UserDefaults.standard.set(times, forKey: phase.learnedTimeKey)

            AppLogger.faceScan.debug("💾 Saved learned time for phase \(phase.rawValue): \(String(format: "%.1f", actualTime))s (history: \(times.count) samples)")
        }
    }

    /// Get number of completed scans (for showing learning status)
    public func getCompletedScanCount() -> Int {
        return UserDefaults.standard.integer(forKey: scanCountKey)
    }

    /// Check if we have enough data for accurate estimates
    public func hasLearnedEstimates() -> Bool {
        return getCompletedScanCount() >= 2
    }

    /// Reset all learned times (for debugging)
    public func resetLearnedTimes() {
        for phase in ProcessingPhase.allCases {
            UserDefaults.standard.removeObject(forKey: phase.learnedTimeKey)
        }
        UserDefaults.standard.set(0, forKey: scanCountKey)
        AppLogger.faceScan.info("🔄 Reset all learned processing times")
    }

    // MARK: - Device Performance Detection

    private static func determinePerformanceTier(device: DeviceInfo?) -> DevicePerformanceTier {
        // First check GPU name for newest devices (A19, A18 chips)
        // This handles cases where TrueDepth version detection is outdated
        if let gpuName = MTLCreateSystemDefaultDevice()?.name {
            if gpuName.contains("A19") || gpuName.contains("A18") || gpuName.contains("A17") {
                return .flagship
            }
        }

        guard let device = device else {
            return .standard // Default to standard if unknown
        }

        switch device.trueDepthVersion {
        case .v6:  // iPhone 15 Pro
            return .flagship

        case .v5, .v4:  // iPhone 14 Pro, 13 Pro
            return .high

        case .v3:  // iPhone 12 Pro
            return .standard

        case .v2, .v1:  // iPhone 11 Pro, X/XS/XR
            return .legacy

        case .none:
            return .legacy
        }
    }
}

// MARK: - Time Formatting Helpers

extension ProcessingTimeEstimator {

    /// Format seconds into human-readable time (e.g., "2:30" or "45 sec")
    public static func formatTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) sec"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }

    /// Format seconds with approximate language (e.g., "About 2 minutes")
    public static func formatApproximateTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "Less than a minute"
        } else if seconds < 90 {
            return "About 1 minute"
        } else {
            let minutes = (seconds + 30) / 60  // Round to nearest minute
            return "About \(minutes) minutes"
        }
    }
}
