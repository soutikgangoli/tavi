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

    // MARK: - 3D Metrics Properties

    /// Computed 3D face metrics
    @Published public var face3DMetrics: Face3DMetrics?

    /// Whether metrics are being computed
    @Published public var isComputingMetrics: Bool = false

    /// Metric visualizations
    @Published public var metricVisualizations: [MetricType: MetricVisualization] = [:]

    // MARK: - Private Properties

    private var lastFrameTime: TimeInterval = 0
    private var frameCount: Int = 0
    private var fpsUpdateTime: TimeInterval = 0
    private var lastTransform: simd_float4x4?
    private var stabilityCheckCount: Int = 0
    private var holdStableTimer: Timer?
    private let meshMerger = MeshMerger()
    private let textureCapture = TextureCapture()
    private let textureBaker = TextureBaker()
    private let metricsAnalyzer = Face3DMetricsAnalyzer()
    private let metricsVisualizer = MetricsVisualizer()

    // MARK: - Initialization

    public init() {
        // All properties have default values, so no additional setup needed
    }

    // MARK: - Public Methods

    /// Update geometry from ARFaceAnchor
    public func updateGeometry(faceAnchor: ARFaceAnchor, frame: ARFrame) {
        // Store current frame for texture capture
        self.currentFrame = frame

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

    // MARK: - Multi-Capture Sequence Methods

    /// Start a new capture sequence - resets storage and starts guided sequence
    public func startCaptureSequence() {
        guard calibrationState.isCalibrated else {
            errorMessage = "Please calibrate first"
            return
        }

        // Initialize new sequence
        currentSequence = CaptureSequence()
        mergedMesh = nil

        // Start guidance
        isGuidanceActive = true
        currentGuidanceStep = .lookStraight
        capturedPoses = [:]
        countdownTimer = 0
    }

    /// Capture current frame mesh if calibration is OK
    public func captureStep() -> Bool {
        guard calibrationState.isCalibrated,
              let geometry = currentGeometry,
              let lightEstimation = lightEstimation,
              var sequence = currentSequence else {
            errorMessage = "Cannot capture - calibration or data missing"
            return false
        }

        // Extract rotation angles
        let transform = geometry.transform
        let yaw = transform.eulerAngles.y * 180 / .pi
        let pitch = transform.eulerAngles.x * 180 / .pi
        let roll = transform.eulerAngles.z * 180 / .pi

        // Create capture
        let capture = MeshCapture(
            step: currentGuidanceStep,
            geometry: geometry,
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            lightEstimation: lightEstimation
        )

        // Add to sequence
        sequence.addCapture(capture)
        currentSequence = sequence

        return true
    }

    /// Finalize capture and merge all partial meshes into single face mesh
    public func finalizeCapture() async -> MergedFaceMesh? {
        guard var sequence = currentSequence else {
            errorMessage = "No capture sequence to finalize"
            return nil
        }

        guard !sequence.captures.isEmpty else {
            errorMessage = "No captures in sequence"
            return nil
        }

        isMerging = true

        // Merge on background thread
        let merger = meshMerger
        let captures = sequence.captures

        let merged = await Task.detached(priority: .userInitiated) {
            return merger.merge(captures: captures)
        }.value

        // Update sequence
        sequence.complete()
        currentSequence = sequence

        // Store merged result
        mergedMesh = merged
        isMerging = false

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
        startCaptureSequence()
    }

    /// Stop guidance mode
    public func stopGuidance() {
        isGuidanceActive = false
        capturedPoses = [:]
        countdownTimer = 0
        holdStableTimer?.invalidate()
        holdStableTimer = nil
    }

    /// Reset calibration
    public func resetCalibration() {
        calibrationState = CalibrationState()
        stopGuidance()
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
        if capturedPoses[currentGuidanceStep] != nil {
            return
        }

        // Extract rotation angles
        let yaw = faceAnchor.transform.eulerAngles.y * 180 / .pi
        let pitch = faceAnchor.transform.eulerAngles.x * 180 / .pi
        let roll = faceAnchor.transform.eulerAngles.z * 180 / .pi

        // Check if pose matches current step
        let isPoseValid = currentGuidanceStep.isPoseValid(yaw: yaw, pitch: pitch, roll: roll)

        if isPoseValid && calibrationState.isCalibrated && !isCaptureInProgress {
            // Start countdown if not already counting
            if countdownTimer == 0 && holdStableTimer == nil {
                startCaptureCountdown(faceAnchor: faceAnchor, yaw: yaw, pitch: pitch, roll: roll)
            }
        } else {
            // Reset countdown if pose or calibration invalid
            if holdStableTimer != nil {
                holdStableTimer?.invalidate()
                holdStableTimer = nil
                countdownTimer = 0
            }
        }
    }

    private func startCaptureCountdown(faceAnchor: ARFaceAnchor, yaw: Float, pitch: Float, roll: Float) {
        countdownTimer = 3

        holdStableTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            Task { @MainActor in
                if self.countdownTimer > 1 {
                    self.countdownTimer -= 1
                } else {
                    // Capture!
                    timer.invalidate()
                    self.holdStableTimer = nil
                    self.countdownTimer = 0
                    self.capturePose(faceAnchor: faceAnchor, yaw: yaw, pitch: pitch, roll: roll)
                }
            }
        }
    }

    private func capturePose(faceAnchor: ARFaceAnchor, yaw: Float, pitch: Float, roll: Float) {
        guard let geometry = currentGeometry else { return }

        isCaptureInProgress = true

        // Create captured pose data
        let poseData = CapturedPoseData(
            step: currentGuidanceStep,
            geometry: geometry,
            yaw: yaw,
            pitch: pitch,
            roll: roll
        )

        capturedPoses[currentGuidanceStep] = poseData

        // Add to capture sequence
        if captureStep() {
            // Also capture texture sample if we have current frame
            captureTextureSample(faceAnchor: faceAnchor)

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }

        // Move to next step or finish
        if let nextStepIndex = GuidanceStep.allCases.firstIndex(of: currentGuidanceStep).map({ $0 + 1 }),
           nextStepIndex < GuidanceStep.allCases.count {
            // Move to next step
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.currentGuidanceStep = GuidanceStep.allCases[nextStepIndex]
                self?.isCaptureInProgress = false
            }
        } else {
            // All steps captured - finalize automatically
            Task { [weak self] in
                guard let self = self else { return }

                await self.finalizeCapture()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isGuidanceActive = false
                    self.isCaptureInProgress = false
                }
            }
        }
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
        guard let frame = currentFrame,
              var sequence = currentSequence else {
            return
        }

        // Capture texture sample
        if let sample = textureCapture.captureSample(
            step: currentGuidanceStep.shortName,
            faceAnchor: faceAnchor,
            frame: frame,
            lightEstimation: lightEstimation
        ) {
            sequence.addTextureSample(sample)
            currentSequence = sequence
            print("✅ Captured texture sample for step: \(currentGuidanceStep.shortName)")
        } else {
            print("⚠️ Failed to capture texture sample (quality check failed)")
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
        guard let merged = mergedMesh,
              let sequence = currentSequence,
              !sequence.textureSamples.isEmpty else {
            errorMessage = "No mesh or texture samples to bake"
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
        let avgExposure = samples.isEmpty ? 0.5 : samples.map { $0.exposureScore }.reduce(0, +) / Float(samples.count)

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
    public func compute3DMetrics() async -> Face3DMetrics? {
        guard let result = bakeResult else {
            errorMessage = "No baked result available - bake texture first"
            return nil
        }

        isComputingMetrics = true

        let metrics = await metricsAnalyzer.computeMetrics(
            unifiedMesh: result.unifiedMesh,
            unifiedTexture: result.albedoTexture
        )

        face3DMetrics = metrics
        isComputingMetrics = false

        // Generate visualizations for all metric types
        if let metrics = metrics {
            await generateVisualizations(for: metrics)
        }

        return metrics
    }

    /// Generate visualizations for metrics
    private func generateVisualizations(for metrics: Face3DMetrics) async {
        var visualizations: [MetricType: MetricVisualization] = [:]

        for metricType in [MetricType.roughness, .pigmentation, .luminance, .lightness] {
            let viz = metricsVisualizer.generateVisualization(
                for: metrics,
                type: metricType
            )
            visualizations[metricType] = viz
        }

        metricVisualizations = visualizations
    }

    /// Get visualization for specific metric type
    public func getVisualization(for type: MetricType) -> MetricVisualization? {
        return metricVisualizations[type]
    }

    /// Get metrics for specific ROI
    public func getMetrics(for roi: Face3DROI) -> ROIMetrics? {
        return face3DMetrics?.metrics(for: roi)
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
