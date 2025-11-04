//
//  FaceScan3DViewModel.swift
//  Tavi
//
//  ViewModel for 3D face scanning with ARKit
//  Created on 2025-10-27.
//

import Foundation
import ARKit
import Combine
import SwiftUI
import UIKit
import CoreImage
import os.log
import BackgroundTasks  // For background processing support

// MARK: - Haptic Feedback Settings

/// Shared settings for haptic feedback
@MainActor
private class HapticSettings: ObservableObject {
    @AppStorage("enableHapticFeedback") var isEnabled: Bool = true
    static let shared = HapticSettings()
}

@MainActor
public class FaceScan3DViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Current face mesh geometry (updated each frame)
    @Published public var currentGeometry: FaceMeshGeometry?

    /// Current light estimation data
    @Published public var lightEstimation: LightEstimation?

    /// Current blend shapes
    @Published public var blendShapes: FaceBlendShapes?

    /// Whether face tracking is currently active
    @Published public var isTracking: Bool = false

    /// Whether a face is currently detected
    @Published public var faceDetected: Bool = false

    /// Error message if tracking fails
    @Published public var errorMessage: String?

    /// Frame rate for debug display
    @Published public var currentFPS: Double = 0

    // MARK: - Calibration Properties

    /// Current calibration state
    @Published public var calibrationState: CalibrationState = CalibrationState()

    /// Current guidance step
    @Published public var currentGuidanceStep: GuidanceStep = .lookStraight

    /// Whether guidance mode is active
    @Published public var isGuidanceActive: Bool = false

    /// Captured poses for each step
    @Published public var capturedPoses: [GuidanceStep: CapturedPoseData] = [:]

    /// Countdown timer (0 = not counting)
    @Published public var countdownTimer: Int = 0

    /// Whether capture is in progress
    @Published public var isCaptureInProgress: Bool = false

    /// Tolerance counter for brief validation failures during countdown
    private var countdownToleranceFrames: Int = 0

    /// Real-time guidance feedback for current pose
    @Published public var guidanceFeedback: String?

    /// Quality warning message
    @Published public var qualityWarning: String?

    /// Track previous warning for haptic feedback
    private var previousQualityWarning: String?

    /// Whether current pose matches target direction
    @Published public var isPoseCorrect: Bool = false

    /// Baseline lighting for consistency checks
    private var baselineLighting: CGFloat?

    /// Baseline color temperature for consistency checks
    private var baselineColorTemperature: CGFloat?

    // MARK: - Multi-Capture Sequence Properties

    /// Current capture sequence
    @Published public var currentSequence: CaptureSequence?

    /// Merged face mesh from all captures
    @Published public var mergedMesh: MergedFaceMesh?

    /// Whether sequence is being processed/merged
    @Published public var isMerging: Bool = false

    // MARK: - Texture Capture Properties

    /// Baked texture result (unified mesh + albedo texture)
    @Published public var bakeResult: TextureBakeResult?

    /// Whether texture is being baked
    @Published public var isBaking: Bool = false

    /// Current ARFrame (needed for texture capture)
    private var currentFrame: ARFrame?

    /// Current ARFaceAnchor (needed for edge case detection)
    private var currentFaceAnchor: ARFaceAnchor?

    // MARK: - 3D Metrics Properties

    /// Computed 3D face metrics
    @Published public var face3DMetrics: Face3DMetrics?

    /// Whether metrics are being computed
    @Published public var isComputingMetrics: Bool = false

    /// Metric visualizations
    @Published public var metricVisualizations: [VisualizerMetricType: MetricVisualization] = [:]

    // MARK: - Edge Case Override

    /// User chose to continue anyway despite warnings
    @Published public var continueAnywayOverride: Bool = false

    // MARK: - Private Properties

    private var lastFrameTime: TimeInterval = 0
    private var frameCount: Int = 0
    private var fpsUpdateTime: TimeInterval = 0
    private var lastTransform: simd_float4x4?
    private var stabilityCheckCount: Int = 0
    private var holdStableTimer: Timer?
    private let meshMerger = MeshMerger()
    private let streamingMerger = StreamingMeshMerger()

    // Quality check throttling to prevent FPS drops
    private var qualityCheckFrameCounter: Int = 0
    private var lastQualityCheckResult: Bool = true

    // Reusable CIContext to avoid expensive allocations
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // Reusable EdgeCaseDetector to avoid repeated instantiation
    private let edgeCaseDetector = EdgeCaseDetector()
    private let textureCapture = TextureCapture()
    private var textureBaker: TextureBaker {
        // Check high-res capture setting
        let enableHighRes = UserDefaults.standard.bool(forKey: "enableHighResCapture")
        var config = TextureBaker.Configuration()
        if enableHighRes {
            config.textureWidth = ScanConfiguration.highResTextureWidth
            config.textureHeight = ScanConfiguration.highResTextureHeight
        } else {
            config.textureWidth = ScanConfiguration.standardTextureWidth
            config.textureHeight = ScanConfiguration.standardTextureHeight
        }
        return TextureBaker(configuration: config)
    }
    private let metricsAnalyzer = Face3DMetricsAnalyzer()
    private let metricsVisualizer = MetricsVisualizer()
    private let imageQualityAnalyzer = ImageQualityAnalyzer()

    // Haptic feedback generator for pose validation
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    // Memory warning observer
    private var memoryWarningObserver: NSObjectProtocol?

    // MARK: - Initialization

    public init() {
        // All properties have default values, so no additional setup needed

        // Prepare haptic feedback generator for lower latency
        hapticFeedback.prepare()

        // Register for memory warnings to prevent out-of-memory crashes
        setupMemoryWarningObserver()
    }

    deinit {
        AppLogger.faceScan.info("🧹 FaceScan3DViewModel deallocating - cleaning up resources")

        // Invalidate timer to prevent retain cycle and memory leak
        holdStableTimer?.invalidate()
        holdStableTimer = nil

        // Remove memory warning observer
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    /// Update geometry from ARFaceAnchor
    public func updateGeometry(faceAnchor: ARFaceAnchor, frame: ARFrame) {
        // Store current frame for texture capture
        self.currentFrame = frame

        // Store current face anchor for edge case detection
        self.currentFaceAnchor = faceAnchor

        // Update geometry
        self.currentGeometry = FaceMeshGeometry(faceAnchor: faceAnchor)

        // Update blend shapes
        self.blendShapes = FaceBlendShapes(faceAnchor: faceAnchor)

        // Update light estimation
        self.lightEstimation = LightEstimation(frame: frame)

        // Update tracking state
        self.faceDetected = true
        self.isTracking = true

        // Update calibration state
        updateCalibrationState(faceAnchor: faceAnchor, frame: frame)

        // Calculate FPS
        updateFPS()

        // Check if we should auto-capture during guidance
        if isGuidanceActive && !isCaptureInProgress {
            checkGuidancePoseAndCapture(faceAnchor: faceAnchor)
        }
    }

    /// Called when face tracking is lost
    public func faceTrackingLost() {
        self.faceDetected = false
        self.currentGeometry = nil
        self.blendShapes = nil
    }

    /// Called when session starts
    public func sessionStarted() {
        self.isTracking = true
        self.errorMessage = nil
    }

    /// Called when session fails
    public func sessionFailed(error: Error) {
        self.isTracking = false
        self.errorMessage = "ARKit session failed: \(error.localizedDescription)"
    }

    /// Called when session is interrupted
    public func sessionInterrupted() {
        self.isTracking = false
        self.errorMessage = "ARKit session interrupted"
    }

    /// Called when session interruption ends
    public func sessionInterruptionEnded() {
        self.isTracking = true
        self.errorMessage = nil
    }

    // MARK: - Multi-Frame Capture Callbacks

    /// Called when multi-frame capture starts
    public func onMultiFrameCaptureStarted() {
        // Can be used to update UI or track state
        AppLogger.faceScan.info("Multi-frame capture started")
    }

    /// Called when a frame is captured
    public func onFrameCaptured(frameCount: Int, targetCount: Int, confidence: Float) {
        // Update UI with frame counter
        // Example: "Capturing... 8/12 frames"
        AppLogger.faceScan.debug("Frame captured: \(frameCount)/\(targetCount), confidence: \(confidence)")
    }

    /// Called when target frame count is reached
    public func onMultiFrameCaptureReachedTarget() {
        // Can trigger auto-stop or UI feedback
        AppLogger.faceScan.info("Target frame count reached")
    }

    /// Called when multi-frame capture completes
    public func onMultiFrameCaptureCompleted(frameCount: Int) {
        AppLogger.faceScan.info("Multi-frame capture completed with \(frameCount) frames")
    }

    // MARK: - Multi-Capture Sequence Methods

    /// Start a new capture sequence - resets storage and starts guided sequence
    public func startCaptureSequence() {
        AppLogger.faceScan.info("📋 startCaptureSequence() called. Calibrated: \(self.calibrationState.isCalibrated)")

        // Clear error messages from previous scans
        errorMessage = nil

        AppLogger.faceScan.info("✅ Creating new CaptureSequence...")
        // ALWAYS initialize sequence first (critical - prevents "no sequence" error)
        currentSequence = CaptureSequence()
        mergedMesh = nil

        // Reset baseline lighting for consistency checks
        baselineLighting = nil
        baselineColorTemperature = nil

        // Start guidance
        isGuidanceActive = true
        currentGuidanceStep = .lookStraight
        capturedPoses = [:]
        countdownTimer = 0

        AppLogger.faceScan.info("✅ Sequence initialized! Active: \(self.isGuidanceActive), Step: \(self.currentGuidanceStep.shortName), Calibrated: \(self.calibrationState.isCalibrated)")

        // Pre-flight checks: Edge cases and lighting validation (based on strictness)
        // NON-BLOCKING: Only warn, don't prevent capture (user can still proceed)
        let strictness = getLightingStrictness()
        if strictness != .off {
            _ = performPreflightChecks() // Check but don't block
        }
    }

    /// Get lighting strictness from settings
    private func getLightingStrictness() -> LightingStrictnessLevel {
        let rawValue = UserDefaults.standard.string(forKey: "lightingStrictness") ?? "Strict"
        switch rawValue {
        case "Strict": return .strict
        case "Relaxed": return .relaxed
        case "Off": return .off
        default: return .strict
        }
    }

    /// Perform pre-flight checks before starting scan
    /// Returns false if blocking issues detected
    private func performPreflightChecks() -> Bool {
        // Edge case detection
        guard let faceAnchor = currentFaceAnchor,
              let frame = currentFrame else {
            errorMessage = "Unable to access camera data"
            return false
        }

        let pixelBuffer = frame.capturedImage

        // Convert pixel buffer to UIImage for edge case detection
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            errorMessage = "Unable to process camera image"
            return false
        }
        let texture = UIImage(cgImage: cgImage)

        // Get lighting strictness from settings
        let strictness = getLightingStrictness()

        // Run edge case detection with strictness level (use reusable instance)
        let edgeCases = edgeCaseDetector.detectEdgeCases(
            texture: texture,
            faceAnchor: faceAnchor,
            strictness: strictness
        )

        // Check for blocking issues (unless user overrode)
        if !edgeCases.shouldProceed && !continueAnywayOverride {
            errorMessage = edgeCases.blockReason ?? "Scan blocked - please check conditions"
            return false
        }

        // Check for warning issues (don't block, but inform user)
        if !edgeCases.warnings.isEmpty {
            qualityWarning = edgeCases.warnings.first
        }

        // If user overrode, clear error message
        if continueAnywayOverride {
            errorMessage = nil
        }

        return true
    }

    /// Capture current frame mesh if calibration is OK
    public func captureStep() -> Bool {
        AppLogger.faceScan.info("🔍 captureStep() ENTRY - checking preconditions...")
        AppLogger.faceScan.info("🔍 currentGeometry exists: \(self.currentGeometry != nil)")
        AppLogger.faceScan.info("🔍 lightEstimation exists: \(self.lightEstimation != nil)")
        AppLogger.faceScan.info("🔍 currentSequence exists: \(self.currentSequence != nil)")

        // RELAXED: Don't check calibration here - we already validated during countdown
        // Brief calibration loss during capture shouldn't block it
        guard let geometry = self.currentGeometry,
              let lightEstimation = self.lightEstimation,
              self.currentSequence != nil else {
            self.errorMessage = "Cannot capture - geometry or data missing"
            AppLogger.faceScan.error("❌ captureStep GUARD FAILED - hasGeometry: \(self.currentGeometry != nil), hasLight: \(self.lightEstimation != nil), hasSequence: \(self.currentSequence != nil)")
            return false
        }

        AppLogger.faceScan.info("✅ captureStep() guard passed - proceeding with capture...")

        // Extract rotation angles
        let transform = geometry.transform
        let yaw = transform.eulerAngles.y * 180 / .pi
        let pitch = transform.eulerAngles.x * 180 / .pi
        let roll = transform.eulerAngles.z * 180 / .pi

        // Create capture
        let capture = MeshCapture(
            step: self.currentGuidanceStep,
            geometry: geometry,
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            lightEstimation: lightEstimation
        )

        // CRITICAL FIX v4: Now that CaptureSequence is a class (reference type),
        // mutations work directly without extract-modify-reassign
        AppLogger.faceScan.info("🔍 About to call addCapture() on sequence...")
        self.currentSequence!.addCapture(capture)
        AppLogger.faceScan.info("🔍 addCapture() call completed!")

        let captureCount = self.currentSequence!.captures.count
        AppLogger.faceScan.info("✅ Added capture to sequence. Total captures now: \(captureCount)")
        AppLogger.faceScan.info("📊 Sequence update - Step: \(self.currentGuidanceStep.shortName), Total captures: \(captureCount), Vertices: \(capture.vertices.count)")

        return true
    }

    /// Finalize capture and merge all partial meshes into single face mesh
    /// Now includes complete clinical-grade processing pipeline
    public func finalizeCapture() async -> MergedFaceMesh? {
        // IMPORTANT: Keep screen on during processing (2 min avg)
        // This prevents iOS from suspending the app since beginBackgroundTask only gives ~30s
        let previousIdleTimerState = await UIApplication.shared.isIdleTimerDisabled
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = true
            AppLogger.mesh.info("🔋 Screen will stay on during processing (~2 minutes)")
        }

        defer {
            // Restore screen sleep setting when done
            Task { @MainActor in
                UIApplication.shared.isIdleTimerDisabled = previousIdleTimerState
                AppLogger.mesh.info("🔋 Screen sleep restored")
            }
        }

        // DEBUG: Log sequence state before accessing
        AppLogger.mesh.info("🔍 DEBUG: finalizeCapture called. Current sequence exists: \(self.currentSequence != nil)")
        if let seq = self.currentSequence {
            AppLogger.mesh.info("🔍 DEBUG: Sequence has \(seq.captures.count) captures")
        }

        guard let sequence = self.currentSequence else {
            let msg = "No capture sequence found! Guidance Active: \(self.isGuidanceActive). This is a bug - sequence should have been created when guidance started."
            AppLogger.mesh.error("❌ MERGE FAILED: \(msg)")
            await MainActor.run {
                self.errorMessage = msg
            }
            return nil
        }

        let captureCount = sequence.captures.count
        AppLogger.mesh.info("🔍 DEBUG: After guard, sequence has \(captureCount) captures")

        guard !sequence.captures.isEmpty else {
            let msg = "No captures in sequence (count: \(captureCount))"
            AppLogger.mesh.error("❌ MERGE FAILED: \(msg)")
            AppLogger.mesh.error("🔍 DEBUG: capturedPoses dict has \(self.capturedPoses.count) entries")
            self.errorMessage = msg
            return nil
        }

        AppLogger.mesh.info("🔄 Starting mesh merge with \(captureCount) captures")
        AppLogger.mesh.info("   Captured poses: \(sequence.captures.map { $0.step }.joined(separator: ", "))")

        // Validate captures have geometry
        let emptyCaptures = sequence.captures.filter { $0.vertices.isEmpty }
        if !emptyCaptures.isEmpty {
            AppLogger.mesh.error("❌ Found \(emptyCaptures.count) captures with 0 vertices!")
            await MainActor.run {
                self.errorMessage = "Invalid captures detected: \(emptyCaptures.count) poses have no geometry. This is a bug - please report."
            }
            return nil
        }

        self.isMerging = true

        // Calculate total vertices to decide on merger strategy
        let totalVertices = sequence.captures.reduce(0) { $0 + $1.vertices.count }
        let threshold = ScanConfiguration.streamingMeshThreshold
        let useStreaming = totalVertices > threshold

        if useStreaming {
            AppLogger.mesh.info("🌊 Using streaming merger for \(totalVertices) vertices (threshold: \(threshold))")
        } else {
            AppLogger.mesh.info("⚡️ Using standard merger for \(totalVertices) vertices")
        }

        // Process on background thread with full clinical-grade pipeline
        let merger = self.meshMerger
        let streamMerger = self.streamingMerger
        let captures = sequence.captures

        let merged: MergedFaceMesh?
        if useStreaming {
            // Use streaming merger for large meshes
            do {
                merged = try await streamMerger.merge(captures: captures) { progress, message in
                    Task { @MainActor in
                        AppLogger.mesh.debug("Streaming merge progress: \(Int(progress * 100))% - \(message)")
                    }
                }
            } catch {
                AppLogger.mesh.error("❌ Streaming merge failed: \(error.localizedDescription)")
                AppLogger.mesh.error("   Captures: \(captures.count), Total vertices: \(totalVertices)")
                AppLogger.mesh.error("   Pose coverage: \(captures.map { $0.step }.joined(separator: ", "))")

                CrashReporter.shared.logError(
                    error,
                    context: [
                        "operation": "streaming_mesh_merge",
                        "vertex_count": totalVertices,
                        "capture_count": captures.count
                    ]
                )
                await MainActor.run {
                    self.isMerging = false
                    self.errorMessage = "Merge failed (\(captures.count) poses): \(error.localizedDescription). Try scanning again with steady poses."
                }
                return nil
            }
        } else {
            // Use standard merger for smaller meshes
            merged = await Task.detached(priority: .userInitiated) { () -> MergedFaceMesh? in
                // Note: Advanced mesh processing (outlier filtering, smoothing, hole filling)
                // requires additional FaceMeshGeometry conversions. For now, use basic merging.
                //
                // Design decision: Keep mesh types separate for clarity and type safety:
                // - MeshCapture: Raw ARKit capture data
                // - UnifiedMesh: Merged multi-view representation
                // - FaceMeshGeometry: Final processed mesh for analysis
                //
                // The current architecture handles conversions at appropriate boundaries
                // Adding helper methods would add complexity without significant benefit

                // STEP 1: Merge meshes with ICP alignment
                AppLogger.mesh.info("🔧 Calling standard merger.merge() with \(captures.count) captures")
                let merged = merger.merge(captures: captures)

                guard let finalMesh = merged else {
                    let totalVertices = captures.reduce(0) { $0 + $1.vertices.count }
                    let totalTriangles = captures.reduce(0) { $0 + $1.triangleIndices.count / 3 }
                    AppLogger.mesh.error("❌ Standard merger returned nil!")
                    AppLogger.mesh.error("   Captures: \(captures.count), Vertices: \(totalVertices), Triangles: \(totalTriangles)")
                    AppLogger.mesh.error("   Pose coverage: \(captures.map { $0.step }.joined(separator: ", "))")

                    // Set detailed error for user
                    await MainActor.run {
                        self.errorMessage = "Merge failed: \(captures.count) poses captured but alignment unsuccessful. Try scanning again with better lighting and steady poses."
                    }
                    return nil
                }

                // STEP 2: Validate basic mesh properties
                AppLogger.mesh.info("✅ Merged mesh: \(finalMesh.vertices.count) vertices, \(finalMesh.triangleIndices.count/3) triangles")

                return finalMesh
            }.value
        }

        guard let merged = merged else {
            AppLogger.mesh.error("❌ MERGE FAILED: Final merged mesh is nil")
            AppLogger.mesh.error("   This usually indicates alignment failure or insufficient overlap between poses")
            await MainActor.run {
                self.errorMessage = "Merge failed: Unable to align face meshes. Ensure good lighting and follow pose instructions carefully."
                self.isMerging = false
            }
            return nil
        }

        // Update sequence
        sequence.complete()
        self.currentSequence = sequence

        // Deactivate guidance now that finalize is complete
        await MainActor.run {
            self.isGuidanceActive = false
            AppLogger.faceScan.info("✅ Finalize complete - guidance deactivated")
        }

        // Store merged result
        self.mergedMesh = merged
        self.isMerging = false

        return merged
    }

    /// Export current sequence to specified format
    public func exportSequence(format: MeshExporter.ExportFormat) throws -> Data {
        guard let sequence = currentSequence else {
            throw NSError(domain: "FaceScan3D", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No sequence to export"
            ])
        }

        return try MeshExporter.export(sequence: sequence, format: format)
    }

    /// Export merged mesh to specified format
    public func exportMergedMesh(format: MeshExporter.ExportFormat) throws -> Data {
        guard let mesh = mergedMesh else {
            throw NSError(domain: "FaceScan3D", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No merged mesh to export"
            ])
        }

        return try MeshExporter.export(mesh: mesh, format: format)
    }

    // MARK: - Calibration Methods

    /// Start guidance mode
    public func startGuidance() {
        AppLogger.faceScan.info("🎯 startGuidance() called")
        startCaptureSequence()
        AppLogger.faceScan.info("✅ startCaptureSequence() completed. Sequence exists: \(self.currentSequence != nil)")
    }

    /// Stop guidance mode
    public func stopGuidance() {
        isGuidanceActive = false
        capturedPoses = [:]
        countdownTimer = 0
        guidanceFeedback = nil
        clearQualityWarning()
        holdStableTimer?.invalidate()
        holdStableTimer = nil
    }

    /// Reset calibration
    public func resetCalibration() {
        calibrationState = CalibrationState()
        continueAnywayOverride = false  // Reset override when starting new session
        errorMessage = nil
        stopGuidance()

        // Clear sequence and mesh data for fresh start
        currentSequence = nil
        mergedMesh = nil

        AppLogger.faceScan.info("✅ Calibration and scan data reset")
    }

    // MARK: - Private Methods

    private func updateFPS() {
        let currentTime = CACurrentMediaTime()

        // Update frame counter
        frameCount += 1

        // Calculate FPS every second
        if currentTime - fpsUpdateTime >= 1.0 {
            currentFPS = Double(frameCount) / (currentTime - fpsUpdateTime)
            frameCount = 0
            fpsUpdateTime = currentTime
        }

        lastFrameTime = currentTime
    }

    private func updateCalibrationState(faceAnchor: ARFaceAnchor, frame: ARFrame) {
        // Update face detected
        calibrationState.faceDetected = true

        // Update lighting
        calibrationState.updateLighting(from: lightEstimation)

        // Update distance
        calibrationState.updateDistance(from: faceAnchor.transform)

        // Update stability
        if let lastTransform = lastTransform {
            let movement = calculateMovement(from: lastTransform, to: faceAnchor.transform)
            calibrationState.updateStability(movement: movement)
        }

        lastTransform = faceAnchor.transform
    }

    private func calculateMovement(from oldTransform: simd_float4x4, to newTransform: simd_float4x4) -> Float {
        // Calculate translation difference
        let oldPosition = oldTransform.columns.3
        let newPosition = newTransform.columns.3

        let dx = newPosition.x - oldPosition.x
        let dy = newPosition.y - oldPosition.y
        let dz = newPosition.z - oldPosition.z

        return sqrt(dx * dx + dy * dy + dz * dz)
    }

    private func checkGuidancePoseAndCapture(faceAnchor: ARFaceAnchor) {
        // Skip if already captured this step
        if capturedPoses[self.currentGuidanceStep] != nil {
            guidanceFeedback = nil
            clearQualityWarning()
            return
        }

        // CONTINUOUS CALIBRATION: Update distance and lighting during capture
        // Update distance
        self.calibrationState.updateDistance(from: faceAnchor.transform)

        // Update lighting
        self.calibrationState.updateLighting(from: self.lightEstimation)

        // Check for distance/lighting issues and show warnings
        if !self.calibrationState.distance.isValid {
            self.qualityWarning = self.calibrationState.distance.message
        } else if !self.calibrationState.lighting.isValid {
            self.qualityWarning = self.calibrationState.lighting.message
        } else {
            clearQualityWarning()
        }

        // Extract rotation angles
        let yaw = faceAnchor.transform.eulerAngles.y * 180 / .pi
        let pitch = faceAnchor.transform.eulerAngles.x * 180 / .pi
        let roll = faceAnchor.transform.eulerAngles.z * 180 / .pi

        // Check if pose matches current step
        let isPoseValid = self.currentGuidanceStep.isPoseValid(yaw: yaw, pitch: pitch, roll: roll)

        // Update published pose correctness for UI
        let wasPoseCorrect = self.isPoseCorrect
        self.isPoseCorrect = isPoseValid

        // Get real-time guidance feedback
        self.guidanceFeedback = self.currentGuidanceStep.getGuidanceFeedback(yaw: yaw, pitch: pitch, roll: roll)

        // Check image quality if pose is valid
        var qualityGood = true
        if isPoseValid {
            // Always check quality when pose is valid, regardless of calibration
            qualityGood = self.checkImageQuality()
        }

        // HAPTIC FEEDBACK: Provide haptic when positioning becomes correct
        if isPoseValid && !wasPoseCorrect && self.calibrationState.isCalibrated && qualityGood {
            // Pose just became valid - give success haptic
            if HapticSettings.shared.isEnabled {
                HapticManager.shared.success()
            }
        }

        // Debug: Log every 30 frames (~once per second at 30fps)
        if frameCount % 30 == 0 {
            let distance = abs(faceAnchor.transform.columns.3.z)
            AppLogger.faceScan.debug("Pose check - Step: \(self.currentGuidanceStep.shortName), Yaw: \(String(format: "%.1f", yaw))°, Pitch: \(String(format: "%.1f", pitch))°, Roll: \(String(format: "%.1f", roll))°, Distance: \(String(format: "%.2f", distance))m")
            AppLogger.faceScan.debug("Valid: \(isPoseValid), Calibrated: \(self.calibrationState.isCalibrated) (Distance: \(self.calibrationState.distance.rawValue)), Quality: \(qualityGood), Busy: \(self.isCaptureInProgress)")
            if let feedback = self.guidanceFeedback {
                AppLogger.faceScan.debug("Feedback: \(feedback)")
            }
            if let warning = self.qualityWarning {
                AppLogger.faceScan.warning("Quality Warning: \(warning)")
            }
        }

        if isPoseValid && self.calibrationState.isCalibrated && qualityGood && !self.isCaptureInProgress {
            // Start countdown if not already counting
            if self.countdownTimer == 0 && self.holdStableTimer == nil {
                startCaptureCountdown(faceAnchor: faceAnchor, yaw: yaw, pitch: pitch, roll: roll)
            }

            // Reset tolerance counter when conditions are good
            self.countdownToleranceFrames = 0
        } else {
            // Log WHY countdown isn't starting (every 60 frames = ~2 seconds)
            if frameCount % 60 == 0 && self.countdownTimer == 0 {
                var reasons: [String] = []
                if !isPoseValid { reasons.append("Pose invalid") }
                if !self.calibrationState.isCalibrated {
                    var issues: [String] = []
                    if !self.calibrationState.lighting.isValid { issues.append("L=\(self.calibrationState.lighting.rawValue)") }
                    if !self.calibrationState.distance.isValid { issues.append("D=\(self.calibrationState.distance.rawValue)") }
                    if !self.calibrationState.stability.isValid { issues.append("S=\(self.calibrationState.stability == .moving ? "moving" : "stable")") }
                    reasons.append("Not calibrated: \(issues.joined(separator: " "))")
                }
                if !qualityGood { reasons.append("Quality poor") }
                if self.isCaptureInProgress { reasons.append("Capture busy") }
                if !reasons.isEmpty {
                    AppLogger.faceScan.info("⏸️ Countdown blocked: \(reasons.joined(separator: ", "))")
                }
            }

            // Allow brief deviations during countdown (tolerance)
            if self.holdStableTimer != nil {
                // UX FIX: During countdown, ONLY check pose validity
                // Don't cancel for calibration/quality - user has already positioned correctly
                // Only cancel if they significantly change the pose angle

                if !isPoseValid {
                    // Pose changed significantly - count tolerance frames
                    self.countdownToleranceFrames += 1

                    if self.countdownToleranceFrames < ScanConfiguration.countdownToleranceFrames {
                        // Still within tolerance - don't cancel countdown
                        AppLogger.faceScan.debug("⚠️ Brief pose deviation during countdown (tolerance: \(self.countdownToleranceFrames)/\(ScanConfiguration.countdownToleranceFrames))")
                        return
                    }

                    // Exceeded tolerance - cancel countdown
                    AppLogger.faceScan.warning("🚫 COUNTDOWN CANCELLED at \(self.countdownTimer) - Pose changed significantly for 0.5s")

                    self.holdStableTimer?.invalidate()
                    self.holdStableTimer = nil
                    self.countdownTimer = 0
                    self.countdownToleranceFrames = 0

                    // CRITICAL FIX: Clear guidanceFeedback to allow fresh start
                    // Without this, old feedback persists and confuses restart logic
                    self.guidanceFeedback = nil
                } else {
                    // Pose is still valid - reset tolerance counter
                    // This means brief deviations are forgiven as long as user returns to pose
                    self.countdownToleranceFrames = 0
                }

                // CRITICAL FIX: After cancellation, DON'T return early
                // Allow the next frame to immediately try starting a new countdown
                // (removed the return that was preventing restart)
            }
        }
    }

    /// Check image quality from current frame with comprehensive validations
    private func checkImageQuality() -> Bool {
        guard let frame = currentFrame else {
            qualityWarning = nil
            return true
        }

        // PERFORMANCE OPTIMIZATION: Throttle quality checks to prevent FPS drops
        // Only run expensive image processing every N frames instead of every frame (60fps → 6fps checks)
        qualityCheckFrameCounter += 1
        if qualityCheckFrameCounter < ScanConfiguration.qualityCheckInterval {
            // Return cached result from last check
            return lastQualityCheckResult
        }
        qualityCheckFrameCounter = 0  // Reset counter

        // 0. STRICT MODE: Validate lighting for EACH POSE
        let strictness = getLightingStrictness()
        if strictness == .strict {
            // Convert frame to UIImage for lighting check
            // OPTIMIZATION: Reuse CIContext instead of creating new one each frame
            let pixelBuffer = frame.capturedImage
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

            if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                let texture = UIImage(cgImage: cgImage)

                // Check lighting for this specific pose
                if let faceAnchor = currentFaceAnchor {
                    let edgeCases = edgeCaseDetector.detectEdgeCases(
                        texture: texture,
                        faceAnchor: faceAnchor,
                        strictness: .strict
                    )

                    // If lighting is bad for this pose, show warning and block countdown
                    if edgeCases.lightingQuality.shouldBlock {
                        AppLogger.faceScan.warning("❌ Quality check failed: Lighting blocked (\(edgeCases.lightingQuality.description))")
                        qualityWarning = "Adjust lighting for this angle (\(edgeCases.lightingQuality.description))"
                        lastQualityCheckResult = false
                        return false
                    } else if edgeCases.lightingQuality != .optimal {
                        qualityWarning = "Lighting could be better (\(edgeCases.lightingQuality.description))"
                        // Still allow capture, just warn
                    }
                }
            }
        }

        // 1. Check lighting consistency across captures
        if let baseline = baselineLighting,
           let current = lightEstimation?.ambientIntensity {
            let lightingChange = abs(current - baseline) / baseline
            if !ScanConfiguration.isLightingChangeAcceptable(lightingChange) {
                AppLogger.faceScan.warning("❌ Quality check failed: Lighting consistency (\(Int(lightingChange * 100))% change)")
                qualityWarning = "Lighting changed - please maintain consistent lighting"
                lastQualityCheckResult = false
                return false
            }

            // Check color temperature consistency
            if let baselineTemp = baselineColorTemperature,
               let currentTemp = lightEstimation?.ambientColorTemperature {
                let tempChange = abs(currentTemp - baselineTemp) / baselineTemp
                if !ScanConfiguration.isColorTempChangeAcceptable(tempChange) {
                    AppLogger.faceScan.warning("❌ Quality check failed: Color temperature consistency (\(Int(tempChange * 100))% change)")
                    qualityWarning = "Light color changed - please stay in same lighting"
                    lastQualityCheckResult = false
                    return false
                }
            }
        } else if baselineLighting == nil, let current = lightEstimation?.ambientIntensity {
            // Set baseline from first successful capture
            baselineLighting = current
            baselineColorTemperature = lightEstimation?.ambientColorTemperature
            AppLogger.faceScan.info("✅ Baseline lighting set: \(Int(current)) lux")
        }

        // 2. Check for neutral expression (comprehensive blend shape validation)
        if let blendShapes = blendShapes {
            // Detect smiling - SKIP for lookDown (false positives from facial geometry changes)
            if self.currentGuidanceStep != .lookDown {
                let smileAmount = (blendShapes.mouthSmileLeft + blendShapes.mouthSmileRight) / 2.0
                if Double(smileAmount) > ScanConfiguration.maxSmileThreshold {
                    AppLogger.faceScan.warning("❌ Quality check failed: Smiling detected (\(String(format: "%.2f", smileAmount)))")
                    setQualityWarning("Please keep a neutral expression (no smiling)")
                    lastQualityCheckResult = false
                    return false
                }
            }

            // Detect frowning
            let frownAmount = (blendShapes.mouthFrownLeft + blendShapes.mouthFrownRight) / 2.0
            if Double(frownAmount) > ScanConfiguration.maxSmileThreshold {
                AppLogger.faceScan.warning("❌ Quality check failed: Frowning detected (\(String(format: "%.2f", frownAmount)))")
                setQualityWarning("Please relax your expression (no frowning)")
                lastQualityCheckResult = false
                return false
            }

            // Detect jaw movement (talking, frowning)
            if Double(blendShapes.jawOpen) > ScanConfiguration.maxJawOpenThreshold {
                AppLogger.faceScan.warning("❌ Quality check failed: Jaw open (\(String(format: "%.2f", blendShapes.jawOpen)))")
                setQualityWarning("Please keep your mouth closed")
                lastQualityCheckResult = false
                return false
            }

            // Detect lip puckering (duck face)
            if Double(blendShapes.mouthPucker) > ScanConfiguration.maxMouthPuckerThreshold {
                AppLogger.faceScan.warning("❌ Quality check failed: Mouth pucker (\(String(format: "%.2f", blendShapes.mouthPucker)))")
                setQualityWarning("Please relax your lips")
                lastQualityCheckResult = false
                return false
            }

            // Detect cheek puffing
            if Double(blendShapes.cheekPuff) > ScanConfiguration.maxCheekPuffThreshold {
                AppLogger.faceScan.warning("❌ Quality check failed: Cheek puff (\(String(format: "%.2f", blendShapes.cheekPuff)))")
                setQualityWarning("Please relax your cheeks")
                lastQualityCheckResult = false
                return false
            }

            // Detect eye blinking
            let blinkAmount = max(blendShapes.eyeBlinkLeft, blendShapes.eyeBlinkRight)
            if Double(blinkAmount) > ScanConfiguration.blinkDetectionThreshold {
                AppLogger.faceScan.warning("❌ Quality check failed: Eye blink (\(String(format: "%.2f", blinkAmount)))")
                setQualityWarning("Please keep your eyes open")
                lastQualityCheckResult = false
                return false
            }

            // Detect eyes wide open (surprised expression)
            let eyeWideAmount = max(blendShapes.eyeWideLeft, blendShapes.eyeWideRight)
            if Double(eyeWideAmount) > ScanConfiguration.maxEyeWideThreshold {
                AppLogger.faceScan.warning("❌ Quality check failed: Eyes wide (\(String(format: "%.2f", eyeWideAmount)))")
                setQualityWarning("Please relax your eyes")
                lastQualityCheckResult = false
                return false
            }

            // Detect eye squinting - SKIP for lookDown (eyes naturally appear more closed)
            if self.currentGuidanceStep != .lookDown {
                let squintAmount = max(blendShapes.eyeSquintLeft, blendShapes.eyeSquintRight)
                if Double(squintAmount) > ScanConfiguration.maxSquintThreshold {
                    AppLogger.faceScan.warning("❌ Quality check failed: Eye squint (\(String(format: "%.2f", squintAmount)))")
                    setQualityWarning("Please don't squint")
                    lastQualityCheckResult = false
                    return false
                }
            }

            // Detect raised eyebrows (surprised/worried expression)
            if Double(blendShapes.browInnerUp) > ScanConfiguration.maxBrowMovementThreshold {
                AppLogger.faceScan.warning("❌ Quality check failed: Brows raised (\(String(format: "%.2f", blendShapes.browInnerUp)))")
                setQualityWarning("Please relax your eyebrows")
                lastQualityCheckResult = false
                return false
            }

            // Detect furrowed brows (angry/concentrating expression)
            let browDownAmount = max(blendShapes.browDownLeft, blendShapes.browDownRight)
            if Double(browDownAmount) > ScanConfiguration.maxBrowMovementThreshold {
                AppLogger.faceScan.warning("❌ Quality check failed: Brows furrowed (\(String(format: "%.2f", browDownAmount)))")
                setQualityWarning("Please relax your forehead")
                lastQualityCheckResult = false
                return false
            }
        }

        // 3. Convert ARFrame to UIImage for exposure analysis only
        // PERFORMANCE: Skip expensive sharpness checks during continuous validation
        // ARKit's tracking quality already handles motion blur detection
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            qualityWarning = nil
            lastQualityCheckResult = true
            return true
        }

        let image = UIImage(cgImage: cgImage)

        // OPTIMIZATION: Only check exposure, not sharpness (sharpness is very expensive)
        // ARKit already detects poor tracking from motion blur
        let exposure = imageQualityAnalyzer.calculateExposure(image: image)

        // 4. Check exposure
        if exposure < ScanConfiguration.underexposureThreshold {
            AppLogger.faceScan.warning("❌ Quality check failed: Underexposed (\(String(format: "%.2f", exposure)))")
            qualityWarning = "Too dark - move to better lighting"
            lastQualityCheckResult = false
            return false
        }

        if exposure > ScanConfiguration.overexposureThreshold {
            AppLogger.faceScan.warning("❌ Quality check failed: Overexposed (\(String(format: "%.2f", exposure)))")
            qualityWarning = "Too bright - reduce lighting or move away from bright light"
            lastQualityCheckResult = false
            return false
        }

        // Check if exposure is within acceptable range (ideal ± deviation)
        let exposureDeviation = abs(exposure - ScanConfiguration.idealExposure)
        if exposureDeviation > ScanConfiguration.maxExposureDeviation {
            AppLogger.faceScan.warning("❌ Quality check failed: Poor exposure (\(String(format: "%.2f", exposure)))")
            qualityWarning = "Adjust lighting for better exposure"
            lastQualityCheckResult = false
            return false
        }

        // 6. Check for occlusions (hands/hair covering face)
        // Use a simple heuristic: check if face anchor confidence is good
        // ARKit automatically reduces tracking quality if face is occluded
        if calibrationState.faceDetected && !calibrationState.isCalibrated {
            // Face detected but calibration failing = likely occlusion
            AppLogger.faceScan.warning("❌ Quality check failed: Possible occlusion (face detected but not calibrated)")
            qualityWarning = "Face partially covered - please remove hands/hair from face"
            lastQualityCheckResult = false
            return false
        }

        // All quality checks passed
        AppLogger.faceScan.debug("✅ All quality checks passed")
        qualityWarning = nil
        lastQualityCheckResult = true
        return true
    }

    private func startCaptureCountdown(faceAnchor: ARFaceAnchor, yaw: Float, pitch: Float, roll: Float) {
        AppLogger.faceScan.info("Starting capture countdown from 3")
        countdownTimer = 3

        // UX: No haptic on countdown start (user requested - too many haptics)
        // Haptic only fires when picture is actually captured

        // Create timer and explicitly add to main RunLoop to ensure it fires
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] timer in
            // Capture weak self again inside the Task to prevent race condition
            Task { @MainActor [weak self] in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                AppLogger.faceScan.info("🔔 Timer fired! Current countdown: \(self.countdownTimer), holdStableTimer exists: \(self.holdStableTimer != nil)")

                // Check if countdown was cancelled externally
                if self.holdStableTimer == nil {
                    AppLogger.faceScan.warning("⚠️ Countdown was cancelled externally - stopping timer")
                    timer.invalidate()
                    return
                }

                // CHECK POSE VALIDITY - cancel countdown if pose changed
                guard let currentAnchor = self.currentFaceAnchor else {
                    AppLogger.faceScan.warning("⚠️ No face anchor - cancelling countdown")
                    timer.invalidate()
                    self.holdStableTimer = nil
                    self.countdownTimer = 0
                    self.guidanceFeedback = "Face lost - please reposition"
                    return
                }

                let currentYaw = currentAnchor.transform.eulerAngles.y * 180 / .pi
                let currentPitch = currentAnchor.transform.eulerAngles.x * 180 / .pi
                let currentRoll = currentAnchor.transform.eulerAngles.z * 180 / .pi

                // Verify pose is still valid for current step
                if !self.currentGuidanceStep.isPoseValid(yaw: currentYaw, pitch: currentPitch, roll: currentRoll) {
                    AppLogger.faceScan.warning("⚠️ Pose changed - cancelling countdown and restarting")
                    AppLogger.faceScan.warning("⚠️ Current pose: yaw=\(currentYaw)°, pitch=\(currentPitch)°, roll=\(currentRoll)°")
                    AppLogger.faceScan.warning("⚠️ Step: \(self.currentGuidanceStep.shortName) requires specific pose - user moved")
                    timer.invalidate()
                    self.holdStableTimer = nil
                    self.countdownTimer = 0
                    self.guidanceFeedback = self.currentGuidanceStep.getGuidanceFeedback(yaw: currentYaw, pitch: currentPitch, roll: currentRoll)
                    return
                }

                if self.countdownTimer > 1 {
                    self.countdownTimer -= 1
                    self.guidanceFeedback = "Hold still! \(self.countdownTimer)..."
                    AppLogger.faceScan.info("⏱️ Countdown: \(self.countdownTimer)")
                } else {
                    // Capture!
                    AppLogger.faceScan.info("📸 Countdown reached 1 - CAPTURING POSE NOW!")
                    timer.invalidate()
                    self.holdStableTimer = nil
                    self.countdownTimer = 0

                    // UX: Single medium haptic when picture successfully captures
                    if HapticSettings.shared.isEnabled {
                        HapticManager.shared.medium()
                        AppLogger.faceScan.debug("Haptic feedback: Picture captured (MEDIUM)")
                    }

                    self.capturePose(faceAnchor: currentAnchor, yaw: currentYaw, pitch: currentPitch, roll: currentRoll)
                }
            }
        }

        // Add timer to main RunLoop with common mode so it fires even during scrolling/gestures
        RunLoop.main.add(timer, forMode: .common)
        holdStableTimer = timer
    }

    private func capturePose(faceAnchor: ARFaceAnchor, yaw: Float, pitch: Float, roll: Float) {
        AppLogger.faceScan.info("🎯 capturePose() CALLED for step: \(self.currentGuidanceStep.shortName)")
        AppLogger.faceScan.info("🎯 Current sequence exists: \(self.currentSequence != nil), Geometry exists: \(self.currentGeometry != nil)")

        guard let geometry = self.currentGeometry else {
            AppLogger.faceScan.error("❌ capturePose ABORTED: No geometry!")
            return
        }

        self.isCaptureInProgress = true

        // Create captured pose data
        let poseData = CapturedPoseData(
            step: self.currentGuidanceStep,
            geometry: geometry,
            yaw: yaw,
            pitch: pitch,
            roll: roll
        )

        capturedPoses[self.currentGuidanceStep] = poseData

        // Capture multiple frames per pose for better quality and merge success
        // Capture 3 frames immediately to get stable data
        var captureSuccess = 0
        for i in 0..<3 {
            AppLogger.faceScan.info("🎯 Calling captureStep() attempt \(i+1)/3...")
            let success = captureStep()
            AppLogger.faceScan.info("🎯 captureStep() attempt \(i+1)/3 returned: \(success)")
            if success {
                captureSuccess += 1
                AppLogger.faceScan.info("✅ Multi-frame capture \(i+1)/3 succeeded")
            } else {
                AppLogger.faceScan.error("❌ Multi-frame capture \(i+1)/3 FAILED")
            }
        }

        if captureSuccess > 0 {
            // Also capture texture sample if we have current frame
            captureTextureSample(faceAnchor: faceAnchor)

            // UX: No haptic for individual frames (user already got haptic when countdown=0)
            // This prevents 3 rapid haptics which is too much

            AppLogger.faceScan.info("📸 Captured \(captureSuccess)/3 frames for pose \(self.currentGuidanceStep.shortName)")
        } else {
            AppLogger.faceScan.error("❌ Failed to capture any frames for pose")
        }

        // TESTING MODE: Complete after first capture only
        // TODO: Remove this before production - this is for testing skin analysis
        AppLogger.faceScan.info("🧪 TESTING MODE: Completing scan after first capture")
        AppLogger.faceScan.info("🧪 Current sequence has \(self.currentSequence?.captures.count ?? 0) captures")

        // Small delay to let UI update
        DispatchQueue.main.asyncAfter(deadline: .now() + ScanConfiguration.calibrationRetryDelay) { [weak self] in
            self?.isCaptureInProgress = false
            self?.guidanceFeedback = "Testing mode - scan complete!"
            AppLogger.faceScan.info("🧪 Capture complete flag set. Sequence has \(self?.currentSequence?.captures.count ?? 0) captures")
        }

        // Original production code (commented out for testing):
        /*
        // Move to next step or finish
        let currentStep = self.currentGuidanceStep
        if let nextStepIndex = GuidanceStep.allCases.firstIndex(of: currentStep).map({ $0 + 1 }),
           nextStepIndex < GuidanceStep.allCases.count {
            // Move to next step
            DispatchQueue.main.asyncAfter(deadline: .now() + ScanConfiguration.resultsDisplayDelay) { [weak self] in
                self?.currentGuidanceStep = GuidanceStep.allCases[nextStepIndex]
                self?.isCaptureInProgress = false
                self?.guidanceFeedback = nil
                self?.qualityWarning = nil
            }
        } else {
            // All steps captured - keep guidance active until View calls finalizeCapture()
            // Don't deactivate guidance here - let the View handle finalization
            AppLogger.faceScan.info("✅ All 7 poses captured! Waiting for View to call finalizeCapture()")
            self.isCaptureInProgress = false
            self.guidanceFeedback = "All poses captured!"
        }
        */
    }

    // MARK: - Geometry Export

    /// Export current geometry to OBJ format
    public func exportToOBJ() -> String? {
        guard let geometry = currentGeometry else { return nil }

        var obj = "# Tavi Face Mesh Export\n"
        obj += "# Vertices: \(geometry.vertexCount)\n"
        obj += "# Triangles: \(geometry.triangleCount)\n\n"

        // Write vertices
        for vertex in geometry.vertices {
            obj += "v \(vertex.x) \(vertex.y) \(vertex.z)\n"
        }

        obj += "\n"

        // Write normals
        for normal in geometry.normals {
            obj += "vn \(normal.x) \(normal.y) \(normal.z)\n"
        }

        obj += "\n"

        // Write texture coordinates
        for texCoord in geometry.textureCoordinates {
            obj += "vt \(texCoord.x) \(texCoord.y)\n"
        }

        obj += "\n"

        // Write faces (triangles)
        for i in stride(from: 0, to: geometry.triangleIndices.count, by: 3) {
            let i0 = Int(geometry.triangleIndices[i]) + 1
            let i1 = Int(geometry.triangleIndices[i + 1]) + 1
            let i2 = Int(geometry.triangleIndices[i + 2]) + 1
            obj += "f \(i0)/\(i0)/\(i0) \(i1)/\(i1)/\(i1) \(i2)/\(i2)/\(i2)\n"
        }

        return obj
    }

    // MARK: - Texture Capture and Baking API

    /// Capture texture sample from current frame
    private func captureTextureSample(faceAnchor: ARFaceAnchor) {
        guard let frame = self.currentFrame,
              self.currentSequence != nil else {
            return
        }

        // Capture texture sample
        if let sample = self.textureCapture.captureSample(
            step: self.currentGuidanceStep.shortName,
            faceAnchor: faceAnchor,
            frame: frame,
            lightEstimation: self.lightEstimation
        ) {
            // CRITICAL FIX v4: Now that CaptureSequence is a class (reference type),
            // mutations work directly without extract-modify-reassign
            self.currentSequence!.addTextureSample(sample)

            AppLogger.faceScan.info("✅ Added texture sample to sequence. Total samples now: \(self.currentSequence!.textureSamples.count)")
            AppLogger.faceScan.info("📊 Texture update - Step: \(self.currentGuidanceStep.shortName), Total samples: \(self.currentSequence!.textureSamples.count)")
        } else {
            AppLogger.faceScan.warning("Failed to capture texture sample (quality check failed)")
        }
    }

    /// Bake unified texture from all captured samples
    public func bakeUnifiedTexture(
        from unifiedMesh: MergedFaceMesh,
        samples: [PoseSample]
    ) async -> TextureBakeResult? {

        guard !samples.isEmpty else {
            errorMessage = "No texture samples available"
            return nil
        }

        isBaking = true

        let result = await textureBaker.bakeUnifiedTexture(
            from: unifiedMesh,
            samples: samples
        )

        bakeResult = result
        isBaking = false

        return result
    }

    /// Bake texture using current sequence samples
    public func bakeTextureFromSequence() async -> TextureBakeResult? {
        // Debug logging to understand which component is missing
        if mergedMesh == nil {
            AppLogger.mesh.error("🔴 TextureBake FAILED: mergedMesh is nil")
            errorMessage = "No merged mesh available for texture baking"
            return nil
        }

        if currentSequence == nil {
            AppLogger.mesh.error("🔴 TextureBake FAILED: currentSequence is nil")
            errorMessage = "No capture sequence available"
            return nil
        }

        guard let sequence = currentSequence else {
            return nil
        }

        if sequence.textureSamples.isEmpty {
            AppLogger.mesh.error("🔴 TextureBake FAILED: textureSamples is empty (count: \(sequence.textureSamples.count))")
            AppLogger.mesh.error("   - capturedPoses count: \(capturedPoses.count)")
            AppLogger.mesh.error("   - sequence.captures count: \(sequence.captures.count)")
            errorMessage = "No texture samples captured during scan"
            return nil
        }

        AppLogger.mesh.info("✅ TextureBake STARTING: mergedMesh=\(mergedMesh != nil), samples=\(sequence.textureSamples.count)")

        guard let merged = mergedMesh else {
            return nil
        }

        return await bakeUnifiedTexture(from: merged, samples: sequence.textureSamples)
    }

    /// Export textured mesh as OBJ + MTL + PNG
    public func exportOBJ(
        unifiedMesh: UnifiedMesh,
        texture: CGImage,
        metadata: FaceScanMetadata
    ) throws -> URL {
        let outputDir = try ExportManager.createExportDirectory()
        return try MeshTextureExporter.exportOBJ(
            unifiedMesh: unifiedMesh,
            texture: texture,
            metadata: metadata,
            outputDirectory: outputDir
        )
    }

    /// Export textured mesh as glTF 2.0 + PNG
    public func exportGLTF(
        unifiedMesh: UnifiedMesh,
        texture: CGImage,
        metadata: FaceScanMetadata
    ) throws -> URL {
        let outputDir = try ExportManager.createExportDirectory()
        return try MeshTextureExporter.exportGLTF(
            unifiedMesh: unifiedMesh,
            texture: texture,
            metadata: metadata,
            outputDirectory: outputDir
        )
    }

    /// Export textured mesh as USDZ
    public func exportUSDZ(
        unifiedMesh: UnifiedMesh,
        texture: CGImage,
        metadata: FaceScanMetadata
    ) throws -> URL {
        let outputDir = try ExportManager.createExportDirectory()
        return try MeshTextureExporter.exportUSDZ(
            unifiedMesh: unifiedMesh,
            texture: texture,
            metadata: metadata,
            outputDirectory: outputDir
        )
    }

    /// Generate metadata from current sequence
    public func generateMetadata() -> FaceScanMetadata? {
        guard let sequence = currentSequence else { return nil }

        let samples = sequence.textureSamples
        let captures = sequence.captures

        guard !captures.isEmpty else { return nil }

        // Calculate statistics
        let avgAmbient = captures.map { $0.ambientIntensity }.reduce(0, +) / CGFloat(captures.count)
        let avgTemp = captures.map { $0.colorTemperature }.reduce(0, +) / CGFloat(captures.count)
        let avgDist = captures.map { $0.distanceFromCamera }.reduce(0, +) / Float(captures.count)

        let avgSharpness = samples.isEmpty ? 0 : samples.map { $0.focusSharpness }.reduce(0, +) / Float(samples.count)
        let avgExposure = samples.isEmpty ? ScanConfiguration.idealExposure : samples.map { $0.exposureScore }.reduce(0, +) / Float(samples.count)

        let deviceModel = UIDevice.current.model
        let iOSVersion = UIDevice.current.systemVersion

        return FaceScanMetadata(
            deviceModel: deviceModel,
            iOSVersion: iOSVersion,
            hasTrueDepth: true,
            totalPoses: captures.count,
            captureSteps: captures.map { $0.step },
            totalDuration: sequence.duration,
            headTransforms: captures.map { $0.transform },
            minAmbientIntensity: sequence.metadata.minLighting ?? 0,
            maxAmbientIntensity: sequence.metadata.maxLighting ?? 0,
            avgAmbientIntensity: avgAmbient,
            avgColorTemperature: avgTemp,
            minDistance: sequence.metadata.minDistance ?? 0,
            maxDistance: sequence.metadata.maxDistance ?? 0,
            avgDistance: avgDist,
            calibrationPassed: calibrationState.isCalibrated,
            lightingCondition: calibrationState.lighting.rawValue,
            distanceCondition: calibrationState.distance.rawValue,
            avgFocusSharpness: avgSharpness,
            avgExposureScore: avgExposure,
            textureCoverage: bakeResult?.coveragePercentage ?? 0,
            processingTime: (bakeResult?.processingTime ?? 0) + (mergedMesh?.mergeTimestamp ?? 0) - sequence.startTime
        )
    }

    /// ShareLink wrapper for exporting
    public func shareExport(at url: URL) -> some View {
        return ExportResultView(exportURL: url)
    }

    // MARK: - 3D Metrics API

    /// Compute 3D face metrics from baked result
    /// This function runs the heavy computation off the main actor to avoid blocking UI
    public func compute3DMetrics() async -> Face3DMetrics? {
        guard let result = bakeResult else {
            errorMessage = "No baked result available - bake texture first"
            return nil
        }

        // Update UI state on main actor
        await MainActor.run {
            isComputingMetrics = true
        }

        AppLogger.faceScan.info("🔬 Starting metrics computation...")
        AppLogger.faceScan.debug("About to call computeMetrics (off main actor)")

        // Capture references before detaching
        let analyzer = self.metricsAnalyzer
        let unifiedMesh = result.unifiedMesh
        let unifiedTexture = result.albedoTexture

        // Run heavy computation off main actor to avoid blocking UI and timeout issues
        let metrics = await Task.detached {
            AppLogger.faceScan.debug("Inside Task.detached, calling computeMetrics")
            let result = await analyzer.computeMetrics(
                unifiedMesh: unifiedMesh,
                unifiedTexture: unifiedTexture
            )
            AppLogger.faceScan.debug("computeMetrics completed in Task.detached, returning \(result != nil ? "non-nil" : "nil")")
            return result
        }.value

        AppLogger.faceScan.debug("Task.detached completed, metrics = \(metrics != nil ? "non-nil" : "nil")")

        if metrics == nil {
            AppLogger.faceScan.warning("⚠️ Metrics computation returned nil")
        }

        // Update state on main actor
        await MainActor.run {
            AppLogger.faceScan.debug("Back on main actor, setting face3DMetrics")
            face3DMetrics = metrics
            isComputingMetrics = false
        }

        AppLogger.faceScan.debug("About to return metrics from compute3DMetrics")
        return metrics
    }

    /// Generate visualizations for metrics
    private func generateVisualizations(for metrics: Face3DMetrics) async {
        var visualizations: [VisualizerMetricType: MetricVisualization] = [:]

        for metricType in [VisualizerMetricType.roughness, .pigmentation, .luminance, .specular] {
            let viz = metricsVisualizer.generateVisualization(
                for: metrics,
                type: metricType
            )
            visualizations[metricType] = viz
        }

        metricVisualizations = visualizations
    }

    /// Get visualization for specific metric type
    public func getVisualization(for type: VisualizerMetricType) -> MetricVisualization? {
        return metricVisualizations[type]
    }

    /// Get metrics for specific ROI
    public func getMetrics(for roi: Face3DROI) -> ROI3DMetrics? {
        return face3DMetrics?.metrics(for: roi)
    }

    // MARK: - Memory Management

    /// Set up observer for memory warnings
    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: MemoryMonitor.memoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }

        AppLogger.faceScan.info("Memory warning observer registered")
    }

    /// Handle memory warning by clearing large cached data
    private func handleMemoryWarning() {
        AppLogger.faceScan.warning("Handling memory warning - clearing caches")

        // Clear large texture data
        if bakeResult != nil {
            AppLogger.faceScan.info("Clearing bakeResult (~67MB)")
            bakeResult = nil
        }

        // Clear merged mesh data
        if mergedMesh != nil {
            AppLogger.faceScan.info("Clearing mergedMesh (~30MB)")
            mergedMesh = nil
        }

        // Clear capture sequence (BUT NOT if actively capturing!)
        if currentSequence != nil && !isGuidanceActive {
            AppLogger.faceScan.info("Clearing currentSequence (~100MB)")
            currentSequence = nil
        } else if currentSequence != nil && isGuidanceActive {
            AppLogger.faceScan.warning("⚠️ Not clearing currentSequence - guidance is active!")
        }

        // Clear visualizations
        if !metricVisualizations.isEmpty {
            AppLogger.faceScan.info("Clearing metric visualizations")
            metricVisualizations.removeAll()
        }

        AppLogger.faceScan.info("Memory cleared successfully")
    }

    // MARK: - Haptic Feedback Helpers

    /// Set quality warning with haptic feedback if it's a new/different warning
    private func setQualityWarning(_ warning: String) {
        // Only trigger haptic if this is a NEW warning (different from previous)
        if previousQualityWarning != warning {
            if HapticSettings.shared.isEnabled {
                HapticManager.shared.warning()
            }
            previousQualityWarning = warning
        }
        qualityWarning = warning
    }

    /// Clear quality warning
    private func clearQualityWarning() {
        qualityWarning = nil
        previousQualityWarning = nil
    }
}

// MARK: - simd_float4x4 Extension

extension simd_float4x4 {
    /// Extract Euler angles (rotation) from transform matrix
    var eulerAngles: SIMD3<Float> {
        // Extract rotation from transform matrix
        let x = atan2(self[2][1], self[2][2])
        let y = atan2(-self[2][0], sqrt(self[2][1] * self[2][1] + self[2][2] * self[2][2]))
        let z = atan2(self[1][0], self[0][0])

        return SIMD3<Float>(x, y, z)
    }
}
