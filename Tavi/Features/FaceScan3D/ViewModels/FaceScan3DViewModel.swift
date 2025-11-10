//
//  FaceScan3DViewModel.swift
//  Tavi
//
//  Thin coordinator ViewModel that delegates to specialized managers
//  Refactored from monolithic implementation on 2025-11-04
//

import Foundation
import ARKit
import Combine
import SwiftUI
import UIKit
import os.log

/// Type alias for captured pose data
public typealias CapturedPose = CapturedPoseData

/// Type alias for texture samples
public typealias TextureSample = PoseSample

/// Thin coordinator ViewModel that delegates to specialized managers
/// This refactored version addresses the monolithic ViewModel issue by separating concerns
@MainActor
public class FaceScan3DViewModel: ObservableObject {
    // MARK: - Manager Dependencies

    /// Handles calibration state and quality validation
    public let calibrationManager = CalibrationManager()

    /// Handles capture sequences and pose guidance
    public let captureManager = CaptureSequenceManager()

    /// Handles mesh merging, texture baking, and export
    public let processingPipeline = ProcessingPipeline()

    /// Handles metrics computation and visualization
    public let metricsOrchestrator = MetricsOrchestrator()

    // MARK: - Published Properties (UI State)

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

    /// Error message if tracking fails (legacy)
    @Published public var errorMessage: String?

    /// Detailed error information with recovery guidance
    @Published public var errorInfo: ARKitErrorInfo?

    /// Frame rate for debug display
    @Published public var currentFPS: Double = 0

    /// Cached angle values for debug display (updated from managers)
    @Published public var cachedYaw: Float = 0
    @Published public var cachedPitch: Float = 0
    @Published public var cachedRoll: Float = 0

    // MARK: - Manager State Passthrough Properties
    // These properties expose manager state for SwiftUI binding compatibility

    /// Current calibration state (from CalibrationManager)
    public var calibrationState: CalibrationState {
        calibrationManager.calibrationState
    }

    /// Quality warning message (from CalibrationManager)
    public var qualityWarning: String? {
        calibrationManager.qualityWarning
    }

    /// Whether current pose matches guidance target (from CalibrationManager)
    public var isPoseCorrect: Bool {
        get { calibrationManager.isPoseCorrect }
        set { calibrationManager.isPoseCorrect = newValue }
    }

    /// Override to continue despite calibration warnings (from CalibrationManager)
    public var continueAnywayOverride: Bool {
        get { calibrationManager.continueAnywayOverride }
        set { calibrationManager.continueAnywayOverride = newValue }
    }

    /// Current guidance step (from CaptureSequenceManager)
    public var currentGuidanceStep: GuidanceStep {
        captureManager.currentGuidanceStep
    }

    /// Whether guidance mode is active (from CaptureSequenceManager)
    public var isGuidanceActive: Bool {
        captureManager.isGuidanceActive
    }

    /// Dictionary of captured poses by guidance step (from CaptureSequenceManager)
    public var capturedPoses: [GuidanceStep: CapturedPose] {
        captureManager.capturedPoses
    }

    /// Countdown timer for auto-capture (from CaptureSequenceManager)
    public var countdownTimer: Int {
        captureManager.countdownTimer
    }

    /// Whether capture is currently in progress (from CaptureSequenceManager)
    public var isCaptureInProgress: Bool {
        captureManager.isCaptureInProgress
    }

    /// Guidance feedback message for user (from CaptureSequenceManager)
    public var guidanceFeedback: String? {
        captureManager.guidanceFeedback
    }

    /// Current face angles for debug display
    public var currentYaw: Float {
        cachedYaw
    }

    public var currentPitch: Float {
        cachedPitch
    }

    public var currentRoll: Float {
        cachedRoll
    }

    /// Current capture sequence (from CaptureSequenceManager)
    public var currentSequence: CaptureSequence? {
        captureManager.currentSequence
    }

    /// Merged mesh result (from ProcessingPipeline)
    public var mergedMesh: MergedFaceMesh? {
        processingPipeline.mergedMesh
    }

    /// Whether mesh merging is in progress (from ProcessingPipeline)
    public var isMerging: Bool {
        processingPipeline.isMerging
    }

    /// Texture bake result (from ProcessingPipeline)
    public var bakeResult: TextureBakeResult? {
        processingPipeline.bakeResult
    }

    /// Whether texture baking is in progress (from ProcessingPipeline)
    public var isBaking: Bool {
        processingPipeline.isBaking
    }

    /// Computed 3D metrics (from MetricsOrchestrator)
    public var face3DMetrics: Face3DMetrics? {
        metricsOrchestrator.face3DMetrics
    }

    /// Whether metrics computation is in progress (from MetricsOrchestrator)
    public var isComputingMetrics: Bool {
        metricsOrchestrator.isComputingMetrics
    }

    /// Available metric visualizations (from MetricsOrchestrator)
    public var metricVisualizations: [VisualizerMetricType: MetricVisualization] {
        metricsOrchestrator.metricVisualizations
    }

    // MARK: - Private Properties

    // CRITICAL: Do NOT store ARFrame with strong reference - it causes memory retention warnings
    // ARSession will warn: "delegate is retaining N ARFrames" and stop camera delivery
    // Use weak reference so ARSession can properly manage frame lifecycle
    private weak var currentFrame: ARFrame?
    private var currentFaceAnchor: ARFaceAnchor?
    private var lastFrameTime: TimeInterval = 0
    private var frameCount: Int = 0
    private var fpsUpdateTime: TimeInterval = 0
    private var memoryWarningObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        setupMemoryWarningObserver()
        setupPropertyForwarding()
    }

    deinit {
        AppLogger.faceScan.info("🧹 FaceScan3DViewModel deallocating")

        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API (ARKit Integration)

    /// Update geometry from ARFaceAnchor (optimized to prevent ARFrame retention)
    /// - Parameters:
    ///   - faceAnchor: Current face anchor from ARKit
    ///   - lightEstimation: Extracted light data (prevents frame retention)
    ///   - captureFrame: Optional ARFrame, ONLY provided during active capture (to minimize retention)
    public func updateGeometry(faceAnchor: ARFaceAnchor, lightEstimation: LightEstimation?, captureFrame: ARFrame? = nil) {
        // CRITICAL: Only store frame reference during active capture operations
        // Most of the time (real-time tracking), this will be nil to prevent memory leak
        // ARFrames are heavy objects - retaining 11-13 of them causes memory warnings
        self.currentFrame = captureFrame
        self.currentFaceAnchor = faceAnchor

        // Update geometry
        self.currentGeometry = FaceMeshGeometry(faceAnchor: faceAnchor)
        self.blendShapes = FaceBlendShapes(faceAnchor: faceAnchor)
        self.lightEstimation = lightEstimation

        // Update tracking state
        self.faceDetected = true
        self.isTracking = true

        // Update calibration through manager (uses extracted light data, no frame needed)
        calibrationManager.updateCalibrationLightweight(
            faceAnchor: faceAnchor,
            lightEstimation: lightEstimation
        )

        // Calculate FPS
        updateFPS()

        // Check if we should auto-capture during guidance
        if captureManager.isGuidanceActive && !captureManager.isCaptureInProgress {
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

        // Analyze error and provide recovery guidance
        let hadPartialCaptures = !captureManager.capturedPoses.isEmpty
        let errorInfo = ARKitErrorAnalyzer.analyze(
            error: error,
            hadPartialCaptures: hadPartialCaptures
        )

        self.errorInfo = errorInfo
        self.errorMessage = errorInfo.message  // Legacy compatibility

        // Log error with details
        AppLogger.faceScan.error("🚨 ARKit session failed: \(errorInfo.type) - \(errorInfo.message)")

        // If recoverable and auto-recovery enabled, schedule retry
        if errorInfo.type.isRecoverable, let delay = errorInfo.type.autoRecoveryDelay {
            scheduleAutoRecovery(after: delay)
        }
    }

    /// Called when session is interrupted
    public func sessionInterrupted() {
        self.isTracking = false

        let errorInfo = ARKitErrorAnalyzer.analyzeInterruption()
        self.errorInfo = errorInfo
        self.errorMessage = errorInfo.message

        AppLogger.faceScan.warning("⚠️ ARKit session interrupted")
    }

    /// Called when session interruption ends
    public func sessionInterruptionEnded() {
        self.isTracking = true
        self.errorMessage = nil
        self.errorInfo = nil

        AppLogger.faceScan.info("✅ ARKit session interruption ended")
    }

    // MARK: - Auto Recovery

    private var recoveryTask: Task<Void, Never>?

    /// Schedule automatic recovery attempt
    private func scheduleAutoRecovery(after delay: TimeInterval) {
        // Cancel any existing recovery task
        recoveryTask?.cancel()

        recoveryTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            // Clear error and let tracking resume
            AppLogger.faceScan.info("🔄 Auto-recovering from error...")
            self.errorInfo = nil
            self.errorMessage = nil
            self.isTracking = true
        }
    }

    /// Cancel any pending auto-recovery
    public func cancelAutoRecovery() {
        recoveryTask?.cancel()
        recoveryTask = nil
    }

    // MARK: - Partial Capture Preservation

    /// Check if there are partial captures that can be preserved
    public var hasPartialCaptures: Bool {
        return !captureManager.capturedPoses.isEmpty
    }

    /// Get count of captured poses
    public var capturedPoseCount: Int {
        return captureManager.capturedPoses.count
    }

    /// Clear partial captures (user wants to start fresh)
    public func clearPartialCaptures() {
        captureManager.capturedPoses = [:]
        AppLogger.faceScan.info("🗑️ Cleared partial captures")
    }

    /// Resume scan with partial captures intact
    public func resumeWithPartialCaptures() {
        // Clear error but keep captured poses
        self.errorInfo = nil
        self.errorMessage = nil
        self.isTracking = true

        AppLogger.faceScan.info("▶️ Resuming scan with \(self.capturedPoseCount) poses preserved")
    }

    // MARK: - Public API (Scan Lifecycle)

    /// Start a new capture sequence
    public func startCaptureSequence() {
        AppLogger.faceScan.info("📋 Starting new capture sequence")

        // Clear errors
        errorMessage = nil

        // Delegate to capture manager
        captureManager.startCaptureSequence()

        // Pre-flight checks if strictness enabled
        let strictness = getLightingStrictness()
        if strictness != .off {
            performPreflightChecks()
        }
    }

    /// Start guidance mode
    public func startGuidance() {
        AppLogger.faceScan.info("🚀 ViewModel.startGuidance() called - starting capture sequence")
        startCaptureSequence()
        AppLogger.faceScan.info("✅ Guidance started - isGuidanceActive: \(captureManager.isGuidanceActive), currentStep: \(captureManager.currentGuidanceStep.shortName)")
    }

    /// Stop guidance mode
    public func stopGuidance() {
        captureManager.stopGuidance()
    }

    /// Reset calibration and scan data
    public func resetCalibration() {
        calibrationManager.reset()
        captureManager.resetSequence()
        processingPipeline.reset()
        metricsOrchestrator.reset()
        errorMessage = nil
        AppLogger.faceScan.info("✅ Full reset complete")
    }

    /// Finalize capture and merge meshes
    public func finalizeCapture() async -> MergedFaceMesh? {
        guard let sequence = captureManager.currentSequence else {
            errorMessage = "No capture sequence found"
            return nil
        }

        let merged = await processingPipeline.finalizeCapture(sequence: sequence)

        if merged != nil {
            // Complete the sequence
            captureManager.completeSequence()
        } else {
            errorMessage = "Merge failed - try scanning again"
        }

        return merged
    }

    /// Bake unified texture from captured samples
    public func bakeTextureFromSequence() async -> TextureBakeResult? {
        guard let merged = processingPipeline.mergedMesh else {
            errorMessage = "No merged mesh available"
            return nil
        }

        guard let sequence = captureManager.currentSequence else {
            errorMessage = "No capture sequence available"
            return nil
        }

        if sequence.textureSamples.isEmpty {
            AppLogger.faceScan.error("❌ bakeTextureFromSequence: No texture samples captured! Total captures: \(sequence.captures.count), but 0 texture samples.")
            errorMessage = "No texture samples captured"
            return nil
        }
        
        AppLogger.faceScan.info("🎨 bakeTextureFromSequence: Starting bake with \(sequence.textureSamples.count) texture samples from \(sequence.captures.count) captures")

        return await processingPipeline.bakeUnifiedTexture(
            from: merged,
            samples: sequence.textureSamples
        )
    }

    /// Compute 3D metrics from baked result
    public func compute3DMetrics() async -> Face3DMetrics? {
        guard let result = processingPipeline.bakeResult else {
            errorMessage = "No baked result available - bake texture first"
            return nil
        }

        return await metricsOrchestrator.compute3DMetrics(from: result)
    }

    /// Capture current step (manual capture trigger)
    public func captureStep() -> Bool {
        guard let geometry = currentGeometry,
              let lightEstimation = lightEstimation,
              let faceAnchor = currentFaceAnchor,
              let frame = currentFrame else {
            AppLogger.faceScan.warning("captureStep called but required data missing")
            return false
        }

        // CRITICAL: Use camera-relative angles for accurate pose validation
        let eulerAngles = faceAnchor.eulerAnglesRelativeToCamera()
        let yaw = eulerAngles.y * 180 / .pi
        let pitch = eulerAngles.x * 180 / .pi
        let roll = eulerAngles.z * 180 / .pi

        captureManager.capturePose(
            faceAnchor: faceAnchor,
            frame: frame,
            geometry: geometry,
            lightEstimation: lightEstimation,
            yaw: yaw,
            pitch: pitch,
            roll: roll
        )

        return true
    }

    /// Bake unified texture directly (alternative API)
    public func bakeUnifiedTexture(from mesh: MergedFaceMesh, samples: [TextureSample]) async -> TextureBakeResult? {
        return await processingPipeline.bakeUnifiedTexture(from: mesh, samples: samples)
    }

    /// Multi-frame capture started callback
    public func onMultiFrameCaptureStarted() {
        AppLogger.faceScan.info("📸 Multi-frame capture started")
        captureManager.onMultiFrameCaptureStarted()
    }

    /// Frame captured callback with progress
    public func onFrameCaptured(frameCount: Int, targetCount: Int, confidence: Float) {
        AppLogger.faceScan.info("📸 Frame \(frameCount)/\(targetCount) captured (confidence: \(confidence))")
        captureManager.onFrameCaptured(frameCount: frameCount, targetCount: targetCount, confidence: confidence)
    }

    /// Multi-frame capture reached target callback
    public func onMultiFrameCaptureReachedTarget() {
        AppLogger.faceScan.info("✅ Multi-frame capture reached target")
        captureManager.onMultiFrameCaptureReachedTarget()
    }

    /// Multi-frame capture completed callback
    public func onMultiFrameCaptureCompleted(frameCount: Int) {
        AppLogger.faceScan.info("✅ Multi-frame capture completed with \(frameCount) frames")
        captureManager.onMultiFrameCaptureCompleted(frameCount: frameCount)
    }

    /// Generate metadata from current scan
    public func generateMetadata() -> FaceScanMetadata? {
        guard let sequence = captureManager.currentSequence else {
            return nil
        }

        return metricsOrchestrator.generateMetadata(
            sequence: sequence,
            bakeResult: processingPipeline.bakeResult,
            mergedMesh: processingPipeline.mergedMesh,
            calibrationState: calibrationManager.calibrationState
        )
    }

    // MARK: - Export API

    /// Export sequence to format
    public func exportSequence(format: MeshExporter.ExportFormat) throws -> Data {
        guard let sequence = captureManager.currentSequence else {
            throw NSError(domain: "FaceScan3D", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No sequence to export"
            ])
        }
        return try processingPipeline.exportSequence(sequence: sequence, format: format)
    }

    /// Export merged mesh to format
    public func exportMergedMesh(format: MeshExporter.ExportFormat) throws -> Data {
        return try processingPipeline.exportMergedMesh(format: format)
    }

    /// Export textured mesh as OBJ
    public func exportOBJ(
        unifiedMesh: UnifiedMesh,
        texture: CGImage,
        metadata: FaceScanMetadata
    ) throws -> URL {
        return try processingPipeline.exportOBJ(
            unifiedMesh: unifiedMesh,
            texture: texture,
            metadata: metadata
        )
    }

    /// Export textured mesh as glTF
    public func exportGLTF(
        unifiedMesh: UnifiedMesh,
        texture: CGImage,
        metadata: FaceScanMetadata
    ) throws -> URL {
        return try processingPipeline.exportGLTF(
            unifiedMesh: unifiedMesh,
            texture: texture,
            metadata: metadata
        )
    }

    /// Export textured mesh as USDZ
    public func exportUSDZ(
        unifiedMesh: UnifiedMesh,
        texture: CGImage,
        metadata: FaceScanMetadata
    ) throws -> URL {
        return try processingPipeline.exportUSDZ(
            unifiedMesh: unifiedMesh,
            texture: texture,
            metadata: metadata
        )
    }

    /// Share exported file using system share sheet
    @ViewBuilder
    public func shareExport(at url: URL) -> some View {
        if #available(iOS 16.0, *) {
            ShareLink(item: url) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        } else {
            Button(action: {
                let activityVC = UIActivityViewController(
                    activityItems: [url],
                    applicationActivities: nil
                )
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(activityVC, animated: true)
                }
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }

    // MARK: - Metrics API

    /// Get visualization for metric type
    public func getVisualization(for type: VisualizerMetricType) -> MetricVisualization? {
        return metricsOrchestrator.getVisualization(for: type)
    }

    /// Get metrics for ROI
    public func getMetrics(for roi: Face3DROI) -> ROI3DMetrics? {
        return metricsOrchestrator.getMetrics(for: roi)
    }

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

        // Write faces
        for i in stride(from: 0, to: geometry.triangleIndices.count, by: 3) {
            let i0 = Int(geometry.triangleIndices[i]) + 1
            let i1 = Int(geometry.triangleIndices[i + 1]) + 1
            let i2 = Int(geometry.triangleIndices[i + 2]) + 1
            obj += "f \(i0)/\(i0)/\(i0) \(i1)/\(i1)/\(i1) \(i2)/\(i2)/\(i2)\n"
        }

        return obj
    }

    // MARK: - Private Methods

    private func updateFPS() {
        let currentTime = CACurrentMediaTime()
        frameCount += 1

        if currentTime - fpsUpdateTime >= 1.0 {
            currentFPS = Double(frameCount) / (currentTime - fpsUpdateTime)
            frameCount = 0
            fpsUpdateTime = currentTime
        }

        lastFrameTime = currentTime
    }

    private func checkGuidancePoseAndCapture(faceAnchor: ARFaceAnchor) {
        guard let frame = currentFrame,
              let geometry = currentGeometry,
              let lightEstimation = lightEstimation else {
            if frameCount % 30 == 0 {
                AppLogger.faceScan.debug("⚠️ checkGuidancePoseAndCapture: Missing required data - frame=\(currentFrame != nil), geometry=\(currentGeometry != nil), lightEstimation=\(lightEstimation != nil)")
            }
            return
        }

        // Check image quality through calibration manager
        let qualityGood = calibrationManager.checkImageQuality(
            frame: frame,
            faceAnchor: faceAnchor,
            blendShapes: blendShapes,
            lightEstimation: lightEstimation,
            currentGuidanceStep: captureManager.currentGuidanceStep
        )

        // Check pose and handle countdown through capture manager
        var isPoseCorrect = calibrationManager.isPoseCorrect
        _ = captureManager.checkGuidancePoseAndCapture(
            faceAnchor: faceAnchor,
            frame: frame,
            isPoseCorrect: &isPoseCorrect,
            isCalibrated: calibrationManager.calibrationState.isCalibrated,
            qualityGood: qualityGood,
            frameCount: frameCount
        )

        // Update calibration manager's isPoseCorrect
        calibrationManager.isPoseCorrect = isPoseCorrect

        // Handle countdown completion - check the trigger flag
        if captureManager.shouldTriggerCapture {
            // Reset the trigger flag
            captureManager.shouldTriggerCapture = false

            // Trigger the capture
            AppLogger.faceScan.info("🎯 Triggering capture after countdown completion")
            performCapture(faceAnchor: faceAnchor, frame: frame, geometry: geometry)
        }
    }

    private func performCapture(faceAnchor: ARFaceAnchor, frame: ARFrame, geometry: FaceMeshGeometry) {
        guard let lightEstimation = lightEstimation else { return }

        // CRITICAL: Use camera-relative angles for accurate pose validation
        let eulerAngles = faceAnchor.eulerAnglesRelativeToCamera()
        let yaw = eulerAngles.y * 180 / .pi
        let pitch = eulerAngles.x * 180 / .pi
        let roll = eulerAngles.z * 180 / .pi

        captureManager.capturePose(
            faceAnchor: faceAnchor,
            frame: frame,
            geometry: geometry,
            lightEstimation: lightEstimation,
            yaw: yaw,
            pitch: pitch,
            roll: roll
        )
    }

    private func getLightingStrictness() -> LightingStrictnessLevel {
        let rawValue = UserDefaults.standard.string(forKey: "lightingStrictness") ?? "Strict"
        switch rawValue {
        case "Strict": return .strict
        case "Relaxed": return .relaxed
        case "Off": return .off
        default: return .strict
        }
    }

    private func performPreflightChecks() {
        guard let faceAnchor = currentFaceAnchor,
              let frame = currentFrame else {
            return
        }

        let strictness = getLightingStrictness()
        let success = calibrationManager.performPreflightChecks(
            faceAnchor: faceAnchor,
            frame: frame,
            strictness: strictness
        )

        if !success && !calibrationManager.continueAnywayOverride {
            errorMessage = "Pre-flight checks failed - please check conditions"
        }
    }

    // MARK: - Property Forwarding Setup

    private func setupPropertyForwarding() {
        // Forward manager objectWillChange to ViewModel's objectWillChange
        // This ensures SwiftUI views re-render when manager state changes

        // Subscribe to specific angle property changes
        calibrationManager.$currentYaw
            .sink { [weak self] yaw in
                guard let self = self, !self.isGuidanceActive else { return }
                AppLogger.faceScan.debug("🔴 ViewModel received yaw from CalibrationManager: \(yaw)")
                self.cachedYaw = yaw
            }
            .store(in: &cancellables)

        calibrationManager.$currentPitch
            .sink { [weak self] pitch in
                guard let self = self, !self.isGuidanceActive else { return }
                self.cachedPitch = pitch
            }
            .store(in: &cancellables)

        calibrationManager.$currentRoll
            .sink { [weak self] roll in
                guard let self = self, !self.isGuidanceActive else { return }
                self.cachedRoll = roll
            }
            .store(in: &cancellables)

        captureManager.$currentYaw
            .sink { [weak self] yaw in
                guard let self = self, self.isGuidanceActive else { return }
                self.cachedYaw = yaw
            }
            .store(in: &cancellables)

        captureManager.$currentPitch
            .sink { [weak self] pitch in
                guard let self = self, self.isGuidanceActive else { return }
                self.cachedPitch = pitch
            }
            .store(in: &cancellables)

        captureManager.$currentRoll
            .sink { [weak self] roll in
                guard let self = self, self.isGuidanceActive else { return }
                self.cachedRoll = roll
            }
            .store(in: &cancellables)

        // Forward general objectWillChange
        calibrationManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        captureManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        processingPipeline.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        metricsOrchestrator.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        AppLogger.faceScan.info("✅ Property forwarding setup complete")
    }

    // MARK: - Memory Management

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

    private func handleMemoryWarning() {
        AppLogger.faceScan.warning("Handling memory warning - clearing caches")

        // Delegate memory cleanup to managers
        processingPipeline.reset()
        metricsOrchestrator.clearVisualizations()

        // Only clear sequence if not actively capturing
        if !captureManager.isGuidanceActive {
            captureManager.resetSequence()
        }

        AppLogger.faceScan.info("Memory cleared successfully")
    }
}
