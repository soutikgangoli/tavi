//
//  FaceScan3DViewModelRefactored.swift
//  Tavi
//
//  Thin coordinator ViewModel that delegates to specialized managers
//  This is the refactored version - original kept for backward compatibility
//  Created on 2025-11-04.
//

import Foundation
import ARKit
import Combine
import SwiftUI
import UIKit
import os.log

/// Thin coordinator ViewModel that delegates to specialized managers
/// This refactored version addresses the monolithic ViewModel issue by separating concerns
@MainActor
public class FaceScan3DViewModelRefactored: ObservableObject {
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

    /// Error message if tracking fails
    @Published public var errorMessage: String?

    /// Frame rate for debug display
    @Published public var currentFPS: Double = 0

    // MARK: - Private Properties

    private var currentFrame: ARFrame?
    private var currentFaceAnchor: ARFaceAnchor?
    private var lastFrameTime: TimeInterval = 0
    private var frameCount: Int = 0
    private var fpsUpdateTime: TimeInterval = 0
    private var memoryWarningObserver: NSObjectProtocol?

    // MARK: - Initialization

    public init() {
        setupMemoryWarningObserver()
    }

    deinit {
        AppLogger.faceScan.info("🧹 FaceScan3DViewModelRefactored deallocating")

        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API (ARKit Integration)

    /// Update geometry from ARFaceAnchor
    public func updateGeometry(faceAnchor: ARFaceAnchor, frame: ARFrame) {
        // Store current frame and anchor
        self.currentFrame = frame
        self.currentFaceAnchor = faceAnchor

        // Update geometry
        self.currentGeometry = FaceMeshGeometry(faceAnchor: faceAnchor)
        self.blendShapes = FaceBlendShapes(faceAnchor: faceAnchor)
        self.lightEstimation = LightEstimation(frame: frame)

        // Update tracking state
        self.faceDetected = true
        self.isTracking = true

        // Update calibration through manager
        calibrationManager.updateCalibration(
            faceAnchor: faceAnchor,
            frame: frame,
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
        startCaptureSequence()
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
            errorMessage = "No texture samples captured"
            return nil
        }

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
        let feedback = captureManager.checkGuidancePoseAndCapture(
            faceAnchor: faceAnchor,
            frame: frame,
            isPoseCorrect: &isPoseCorrect,
            isCalibrated: calibrationManager.calibrationState.isCalibrated,
            qualityGood: qualityGood,
            frameCount: frameCount
        )

        // Update calibration manager's isPoseCorrect
        calibrationManager.isPoseCorrect = isPoseCorrect

        // Handle countdown completion (when timer reaches 0)
        if captureManager.countdownTimer == 0 && isPoseCorrect && qualityGood {
            // Check if we just completed a countdown
            // The capture manager will have set guidanceFeedback to indicate capture
            if let feedback = feedback, feedback.contains("Testing mode") {
                // Capture was triggered by countdown completion
                performCapture(faceAnchor: faceAnchor, frame: frame, geometry: geometry)
            }
        }
    }

    private func performCapture(faceAnchor: ARFaceAnchor, frame: ARFrame, geometry: FaceMeshGeometry) {
        guard let lightEstimation = lightEstimation else { return }

        let yaw = faceAnchor.transform.eulerAngles.y * 180 / .pi
        let pitch = faceAnchor.transform.eulerAngles.x * 180 / .pi
        let roll = faceAnchor.transform.eulerAngles.z * 180 / .pi

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
