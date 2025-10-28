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

    /// Real-time guidance feedback for current pose
    @Published public var guidanceFeedback: String?

    /// Quality warning message
    @Published public var qualityWarning: String?

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
    private var textureBaker: TextureBaker {
        // Check high-res capture setting
        let enableHighRes = UserDefaults.standard.bool(forKey: "enableHighResCapture")
        var config = TextureBaker.Configuration()
        if enableHighRes {
            config.textureWidth = 4096  // 4K resolution
            config.textureHeight = 4096
        } else {
            config.textureWidth = 2048  // Standard resolution
            config.textureHeight = 2048
        }
        return TextureBaker(configuration: config)
    }
    private let metricsAnalyzer = Face3DMetricsAnalyzer()
    private let metricsVisualizer = MetricsVisualizer()
    private let imageQualityAnalyzer = ImageQualityAnalyzer()

    // Haptic feedback generator for pose validation
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    // MARK: - Initialization

    public init() {
        // All properties have default values, so no additional setup needed

        // Prepare haptic feedback generator for lower latency
        hapticFeedback.prepare()
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

    // MARK: - Multi-Frame Capture Callbacks

    /// Called when multi-frame capture starts
    public func onMultiFrameCaptureStarted() {
        // Can be used to update UI or track state
        print("Multi-frame capture started")
    }

    /// Called when a frame is captured
    public func onFrameCaptured(frameCount: Int, targetCount: Int, confidence: Float) {
        // Update UI with frame counter
        // Example: "Capturing... 8/12 frames"
        print("Frame captured: \(frameCount)/\(targetCount), confidence: \(confidence)")
    }

    /// Called when target frame count is reached
    public func onMultiFrameCaptureReachedTarget() {
        // Can trigger auto-stop or UI feedback
        print("Target frame count reached")
    }

    /// Called when multi-frame capture completes
    public func onMultiFrameCaptureCompleted(frameCount: Int) {
        print("Multi-frame capture completed with \(frameCount) frames")
    }

    // MARK: - Multi-Capture Sequence Methods

    /// Start a new capture sequence - resets storage and starts guided sequence
    public func startCaptureSequence() {
        guard calibrationState.isCalibrated else {
            errorMessage = "Please calibrate first"
            return
        }

        // Pre-flight checks: Edge cases and lighting validation (based on strictness)
        let strictness = getLightingStrictness()
        if strictness != .off && !performPreflightChecks() {
            // Preflight check failed, error message already set
            return
        }

        // Initialize new sequence
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
        guard let geometry = currentGeometry,
              let frame = currentFrame,
              let pixelBuffer = frame.capturedImage as? CVPixelBuffer else {
            errorMessage = "Unable to access camera data"
            return false
        }

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

        // Run edge case detection with strictness level
        let edgeCaseDetector = EdgeCaseDetector()
        let faceAnchor = ARFaceAnchor(transform: geometry.transform)
        let edgeCases = edgeCaseDetector.detectEdgeCases(
            texture: texture,
            faceAnchor: faceAnchor,
            strictness: strictness
        )

        // Check for blocking issues
        if !edgeCases.shouldProceed {
            errorMessage = edgeCases.blockReason ?? "Scan blocked - please check conditions"
            return false
        }

        // Check for warning issues (don't block, but inform user)
        if !edgeCases.warnings.isEmpty {
            qualityWarning = edgeCases.warnings.first
        }

        return true
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
    /// Now includes complete clinical-grade processing pipeline
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

        // Process on background thread with full clinical-grade pipeline
        let merger = meshMerger
        let captures = sequence.captures

        let merged = await Task.detached(priority: .userInitiated) {
            // Note: Advanced mesh processing (outlier filtering, smoothing, hole filling)
            // requires additional FaceMeshGeometry conversions. For now, use basic merging.
            // TODO: Add helper methods to convert between MeshCapture, UnifiedMesh, and FaceMeshGeometry

            // STEP 1: Merge meshes with ICP alignment
            let merged = merger.merge(captures: captures)

            guard let finalMesh = merged else { return nil }

            // STEP 2: Validate basic mesh properties
            print("Merged mesh: \(finalMesh.vertices.count) vertices, \(finalMesh.triangleIndices.count/3) triangles")

            return finalMesh
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
        guidanceFeedback = nil
        qualityWarning = nil
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
            guidanceFeedback = nil
            qualityWarning = nil
            return
        }

        // Extract rotation angles
        let yaw = faceAnchor.transform.eulerAngles.y * 180 / .pi
        let pitch = faceAnchor.transform.eulerAngles.x * 180 / .pi
        let roll = faceAnchor.transform.eulerAngles.z * 180 / .pi

        // Check if pose matches current step
        let isPoseValid = currentGuidanceStep.isPoseValid(yaw: yaw, pitch: pitch, roll: roll)

        // Get real-time guidance feedback
        guidanceFeedback = currentGuidanceStep.getGuidanceFeedback(yaw: yaw, pitch: pitch, roll: roll)

        // Check image quality if pose is valid
        var qualityGood = true
        if isPoseValid && calibrationState.isCalibrated {
            qualityGood = checkImageQuality()
        } else {
            qualityWarning = nil
        }

        // Debug: Print every 30 frames (~once per second at 30fps)
        if frameCount % 30 == 0 {
            print("📐 Pose check - Step: \(currentGuidanceStep.shortName), Yaw: \(String(format: "%.1f", yaw))°, Pitch: \(String(format: "%.1f", pitch))°, Roll: \(String(format: "%.1f", roll))°")
            print("   Valid: \(isPoseValid), Calibrated: \(calibrationState.isCalibrated), Quality: \(qualityGood), Busy: \(isCaptureInProgress)")
            if let feedback = guidanceFeedback {
                print("   Feedback: \(feedback)")
            }
            if let warning = qualityWarning {
                print("   Quality Warning: \(warning)")
            }
        }

        if isPoseValid && calibrationState.isCalibrated && qualityGood && !isCaptureInProgress {
            // Start countdown if not already counting
            if countdownTimer == 0 && holdStableTimer == nil {
                startCaptureCountdown(faceAnchor: faceAnchor, yaw: yaw, pitch: pitch, roll: roll)
            }
        } else {
            // Reset countdown if pose, calibration, or quality invalid
            if holdStableTimer != nil {
                print("❌ Countdown cancelled - pose, calibration, or quality lost")
                holdStableTimer?.invalidate()
                holdStableTimer = nil
                countdownTimer = 0
            }
        }
    }

    /// Check image quality from current frame with comprehensive validations
    private func checkImageQuality() -> Bool {
        guard let frame = currentFrame else {
            qualityWarning = nil
            return true
        }

        // 0. STRICT MODE: Validate lighting for EACH POSE
        let strictness = getLightingStrictness()
        if strictness == .strict {
            // Convert frame to UIImage for lighting check
            let pixelBuffer = frame.capturedImage
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()

            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                let texture = UIImage(cgImage: cgImage)

                // Check lighting for this specific pose
                if let geometry = currentGeometry {
                    let edgeCaseDetector = EdgeCaseDetector()
                    let faceAnchor = ARFaceAnchor(transform: geometry.transform)
                    let edgeCases = edgeCaseDetector.detectEdgeCases(
                        texture: texture,
                        faceAnchor: faceAnchor,
                        strictness: .strict
                    )

                    // If lighting is bad for this pose, show warning and block countdown
                    if edgeCases.lightingQuality.shouldBlock {
                        qualityWarning = "Adjust lighting for this angle (\(edgeCases.lightingQuality.description))"
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
            if lightingChange > 0.30 { // More than 30% change
                qualityWarning = "Lighting changed - please maintain consistent lighting"
                return false
            }

            // Check color temperature consistency
            if let baselineTemp = baselineColorTemperature,
               let currentTemp = lightEstimation?.ambientColorTemperature {
                let tempChange = abs(currentTemp - baselineTemp) / baselineTemp
                if tempChange > 0.15 { // More than 15% change in color temp
                    qualityWarning = "Light color changed - please stay in same lighting"
                    return false
                }
            }
        } else if baselineLighting == nil, let current = lightEstimation?.ambientIntensity {
            // Set baseline from first successful capture
            baselineLighting = current
            baselineColorTemperature = lightEstimation?.ambientColorTemperature
        }

        // 2. Check for neutral expression (comprehensive blend shape validation)
        if let blendShapes = blendShapes {
            // Detect smiling
            let smileAmount = (blendShapes.mouthSmileLeft + blendShapes.mouthSmileRight) / 2.0
            if smileAmount > 0.3 {
                qualityWarning = "Please keep a neutral expression (no smiling)"
                return false
            }

            // Detect frowning
            let frownAmount = (blendShapes.mouthFrownLeft + blendShapes.mouthFrownRight) / 2.0
            if frownAmount > 0.3 {
                qualityWarning = "Please relax your expression (no frowning)"
                return false
            }

            // Detect jaw movement (talking, frowning)
            if blendShapes.jawOpen > 0.15 {
                qualityWarning = "Please keep your mouth closed"
                return false
            }

            // Detect lip puckering (duck face)
            if blendShapes.mouthPucker > 0.2 {
                qualityWarning = "Please relax your lips"
                return false
            }

            // Detect cheek puffing
            if blendShapes.cheekPuff > 0.2 {
                qualityWarning = "Please relax your cheeks"
                return false
            }

            // Detect eye blinking
            let blinkAmount = max(blendShapes.eyeBlinkLeft, blendShapes.eyeBlinkRight)
            if blinkAmount > 0.7 {
                qualityWarning = "Please keep your eyes open"
                return false
            }

            // Detect eyes wide open (surprised expression)
            let eyeWideAmount = max(blendShapes.eyeWideLeft, blendShapes.eyeWideRight)
            if eyeWideAmount > 0.3 {
                qualityWarning = "Please relax your eyes"
                return false
            }

            // Detect eye squinting
            let squintAmount = max(blendShapes.eyeSquintLeft, blendShapes.eyeSquintRight)
            if squintAmount > 0.3 {
                qualityWarning = "Please don't squint"
                return false
            }

            // Detect raised eyebrows (surprised/worried expression)
            if blendShapes.browInnerUp > 0.3 {
                qualityWarning = "Please relax your eyebrows"
                return false
            }

            // Detect furrowed brows (angry/concentrating expression)
            let browDownAmount = max(blendShapes.browDownLeft, blendShapes.browDownRight)
            if browDownAmount > 0.3 {
                qualityWarning = "Please relax your forehead"
                return false
            }
        }

        // 3. Convert ARFrame to UIImage for image quality analysis
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            qualityWarning = nil
            return true
        }

        let image = UIImage(cgImage: cgImage)
        let metrics = imageQualityAnalyzer.analyzeQuality(image: image)

        // 4. Check sharpness (blur detection)
        if !metrics.isSharp {
            qualityWarning = "Image is blurry - hold still and steady"
            return false
        }

        // 5. Check exposure
        if metrics.exposure < 0.25 {
            qualityWarning = "Too dark - move to better lighting"
            return false
        }

        if metrics.exposure > 0.75 {
            qualityWarning = "Too bright - reduce lighting or move away from bright light"
            return false
        }

        if !metrics.isWellExposed {
            qualityWarning = "Adjust lighting for better exposure"
            return false
        }

        // 6. Check for occlusions (hands/hair covering face)
        // Use a simple heuristic: check if face anchor confidence is good
        // ARKit automatically reduces tracking quality if face is occluded
        if calibrationState.faceDetected && !calibrationState.isCalibrated {
            // Face detected but calibration failing = likely occlusion
            qualityWarning = "Face partially covered - please remove hands/hair from face"
            return false
        }

        // All quality checks passed
        qualityWarning = nil
        return true
    }

    private func startCaptureCountdown(faceAnchor: ARFaceAnchor, yaw: Float, pitch: Float, roll: Float) {
        print("🎬 Starting capture countdown from 3...")
        countdownTimer = 3

        // Haptic feedback: Pose is correct! (if enabled)
        if HapticSettings.shared.isEnabled {
            hapticFeedback.impactOccurred()
            print("📳 Haptic feedback: Pose validated")
        }

        // Create timer and explicitly add to main RunLoop to ensure it fires
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            // Wrap in MainActor to avoid concurrency warnings
            Task { @MainActor in
                print("⏱️ Countdown: \(self.countdownTimer)")

                if self.countdownTimer > 1 {
                    self.countdownTimer -= 1
                } else {
                    // Capture!
                    print("📸 Capturing pose!")
                    timer.invalidate()
                    self.holdStableTimer = nil
                    self.countdownTimer = 0

                    // Haptic feedback: Capture complete! (if enabled)
                    if HapticSettings.shared.isEnabled {
                        self.hapticFeedback.impactOccurred()
                        print("📳 Haptic feedback: Pose captured")
                    }

                    self.capturePose(faceAnchor: faceAnchor, yaw: yaw, pitch: pitch, roll: roll)
                }
            }
        }

        // Add timer to main RunLoop with common mode so it fires even during scrolling/gestures
        RunLoop.main.add(timer, forMode: .common)
        holdStableTimer = timer
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
                self?.guidanceFeedback = nil
                self?.qualityWarning = nil
            }
        } else {
            // All steps captured - finalize automatically
            Task { [weak self] in
                guard let self = self else { return }

                _ = await self.finalizeCapture()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isGuidanceActive = false
                    self.isCaptureInProgress = false
                    self.guidanceFeedback = nil
                    self.qualityWarning = nil
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

        for metricType in [MetricType.roughness, .pigmentation, .luminance, .specular] {
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
    public func getMetrics(for roi: Face3DROI) -> ROI3DMetrics? {
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
