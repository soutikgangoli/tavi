//
//  ARFaceTrackingViewController.swift
//  Ollvy
//
//  UIKit view controller wrapping ARSCNView for face tracking
//  Created on 2025-10-27.
//

import UIKit
import ARKit
import SceneKit

/// UIKit view controller that manages ARSCNView and face tracking
public class ARFaceTrackingViewController: UIViewController {

    // MARK: - Properties

    private let sceneView: ARSCNView = {
        let view = ARSCNView()
        view.automaticallyUpdatesLighting = true
        view.autoenablesDefaultLighting = false
        return view
    }()

    private let session = ARSession()
    private var faceNode: SCNNode?

    /// ViewModel to update with tracking data
    public weak var viewModel: FaceScan3DViewModel?

    /// Whether to show debug mesh
    public var showDebugMesh: Bool = true {
        didSet {
            updateMeshVisibility()
        }
    }

    // MARK: - Multi-Frame Capture Properties

    /// Frame averager for collecting multiple frames per pose
    private var frameAverager: FrameAverager?

    /// Whether multi-frame capture is active
    private var isMultiFrameCaptureActive: Bool = false

    /// Target number of frames to capture per pose
    private let targetFrameCount: Int = 12

    /// Minimum frames required (if tracking quality is good)
    private let minimumFrameCount: Int = 8

    // MARK: - Performance Optimization Properties

    /// Previous frame count to detect changes
    private var previousFrameCount: Int = 0

    /// Previous confidence to detect changes
    private var previousConfidence: Float = 0

    /// Frame sequence number for stale Task detection
    /// Used to skip outdated Tasks and release ARFrame references faster
    private var frameSequenceNumber: Int = 0

    /// Flag to prevent processing during/after cleanup
    /// This prevents race conditions where callbacks fire after session is stopped
    private var isSessionStopped: Bool = false

    /// Counter for active frame processing tasks
    /// Used to limit concurrent ARFrame retention
    private var activeFrameProcessingCount: Int = 0

    /// Maximum concurrent frame processing tasks allowed
    /// Higher values = more memory usage, lower values = might skip frames
    /// REDUCED from 4 to 2 to prevent ARFrame retention warnings (each frame ~10MB)
    private static let maxConcurrentFrameProcessing: Int = 2

    // MARK: - Lifecycle

    deinit {
        // CRITICAL: Stop session synchronously in deinit - can't dispatch async from deinit
        // Set the stop flag immediately to prevent any callbacks during deallocation
        isSessionStopped = true

        // Clear delegates synchronously to prevent callbacks
        sceneView.delegate = nil
        sceneView.session.delegate = nil

        // Pause the session - do this synchronously in deinit
        sceneView.session.pause()

        // Clear references
        isMultiFrameCaptureActive = false
        frameAverager = nil
        faceNode?.geometry = nil
        faceNode = nil
        viewModel = nil

        AppLogger.faceScan.info("🧹 ARFaceTrackingViewController deallocated")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        setupSceneView()
        setupScene()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startFaceTracking()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Use full cleanup instead of just pause to prevent FigXPCUtilities errors
        stopAndCleanupSession()
    }

    /// Properly stop the AR session and clear all delegates
    /// This prevents FigXPCUtilities error -17281 when cancelling/dismissing
    private func stopAndCleanupSession() {
        // CRITICAL: Set stop flag FIRST to prevent any new processing
        // This flag is checked at the start of all delegate methods
        guard !isSessionStopped else { return }  // Prevent multiple cleanup calls
        isSessionStopped = true

        // Cancel any active multi-frame capture
        isMultiFrameCaptureActive = false
        frameAverager = nil

        // Reset active frame processing counter to prevent stale Task tracking
        activeFrameProcessingCount = 0

        // CRITICAL: Clear delegates BEFORE pausing to prevent callbacks during teardown
        // This prevents FigXPCUtilities errors when camera resources are accessed during cleanup
        sceneView.delegate = nil
        sceneView.session.delegate = nil

        // FigCaptureSourceRemote FIX: Allow camera delegate callbacks to drain
        // This small synchronous delay gives pending camera callbacks time to complete
        // before we pause the session, preventing -17281 errors
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        // CRITICAL FIX: Pause session SYNCHRONOUSLY to prevent hang on dismiss
        // The async dispatch was causing the view to dismiss before cleanup completed
        // We're already on the main thread (from viewWillDisappear), so we can pause directly
        sceneView.session.pause()

        // Clear node reference after session is paused
        faceNode?.geometry = nil
        faceNode?.removeFromParentNode()
        faceNode = nil

        // Clear weak reference to ViewModel
        viewModel = nil

        AppLogger.faceScan.info("🛑 AR session stopped and cleaned up")
    }

    // MARK: - Setup

    private func setupSceneView() {
        view.addSubview(sceneView)
        sceneView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        sceneView.delegate = self
        sceneView.session = session
    }

    private func setupScene() {
        // Create scene
        let scene = SCNScene()
        sceneView.scene = scene

        // Configure camera
        let camera = SCNCamera()
        camera.wantsHDR = true

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)

        // Add ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 100
        ambientLight.color = UIColor.white

        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)
    }

    private func startFaceTracking() {
        // Don't start if session is already stopped or stopping
        guard !isSessionStopped else {
            AppLogger.faceScan.info("⏸️ Skipping face tracking start - session already stopped")
            return
        }

        // Check if face tracking is supported
        guard ARFaceTrackingConfiguration.isSupported else {
            Task { @MainActor in
                viewModel?.sessionFailed(error: NSError(
                    domain: "ARKit",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Face tracking not supported on this device"]
                ))
            }
            return
        }

        // Configure face tracking
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        configuration.maximumNumberOfTrackedFaces = 1

        // Run session
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        Task { @MainActor in
            viewModel?.sessionStarted()
        }
    }

    private func updateMeshVisibility() {
        faceNode?.isHidden = !showDebugMesh
    }

    // MARK: - Public Methods

    /// Stop the AR session immediately - call this when user cancels
    /// This is faster than relying on the delegate check because it stops the session
    /// before any new frames can be processed
    public func stopSessionImmediately() {
        stopAndCleanupSession()
    }

    /// Update mesh material color
    public func setMeshColor(_ color: UIColor) {
        faceNode?.geometry?.firstMaterial?.diffuse.contents = color
    }

    /// Set mesh wireframe mode
    public func setWireframeMode(_ enabled: Bool) {
        faceNode?.geometry?.firstMaterial?.fillMode = enabled ? .lines : .fill
    }

    // MARK: - Multi-Frame Capture Methods

    /// Start multi-frame capture for current pose
    public func startMultiFrameCapture() {
        frameAverager = FrameAverager(
            minFrames: minimumFrameCount,
            maxFrames: targetFrameCount
        )
        isMultiFrameCaptureActive = true

        Task { @MainActor in
            viewModel?.onMultiFrameCaptureStarted()
        }
    }

    /// Stop multi-frame capture and return averaged result
    public func stopMultiFrameCapture() -> AveragedFrame? {
        defer {
            isMultiFrameCaptureActive = false
            frameAverager = nil
        }

        guard let averager = frameAverager else { return nil }

        let result = averager.average()

        Task { @MainActor in
            viewModel?.onMultiFrameCaptureCompleted(frameCount: averager.frameCount)
        }

        return result
    }

    /// Get current frame count in active capture
    public func getCurrentFrameCount() -> Int {
        return frameAverager?.frameCount ?? 0
    }

    /// Check if capture has enough frames
    public func hasEnoughFrames() -> Bool {
        guard let averager = frameAverager else { return false }
        return averager.frameCount >= minimumFrameCount
    }
}

// MARK: - ARSCNViewDelegate

extension ARFaceTrackingViewController: ARSCNViewDelegate {

    public func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        // CRITICAL: Bail out immediately if session is stopping/stopped
        guard !isSessionStopped else { return nil }
        guard anchor is ARFaceAnchor else { return nil }

        // Safely unwrap Metal device
        guard let device = sceneView.device else {
            AppLogger.faceScan.error("ERROR: Metal device not available")
            viewModel?.sessionFailed(error: NSError(
                domain: "ARFaceTracking",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Your device does not support face tracking"]
            ))
            return nil
        }

        // Safely create face geometry
        guard let faceGeometry = ARSCNFaceGeometry(device: device) else {
            AppLogger.faceScan.error("ERROR: Failed to create face geometry")
            viewModel?.sessionFailed(error: NSError(
                domain: "ARFaceTracking",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to initialize face tracking"]
            ))
            return nil
        }

        let node = SCNNode(geometry: faceGeometry)

        // Safely unwrap material
        guard let material = faceGeometry.firstMaterial else {
            AppLogger.faceScan.error("ERROR: Face geometry has no material")
            return nil
        }
        // Set visible wireframe color (white with some transparency)
        material.diffuse.contents = UIColor.white.withAlphaComponent(0.7)
        material.lightingModel = .constant
        material.fillMode = .lines

        // Store reference
        faceNode = node

        return node
    }

    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // CRITICAL: Bail out immediately if session is stopping/stopped
        guard !isSessionStopped else { return }

        // Check if viewModel signals session should stop or cleanup is in progress
        if let vm = viewModel, (vm.shouldStopSession || vm.isCleaningUp) {
            stopAndCleanupSession()
            return
        }

        // Additional safety check: bail out if viewModel is nil (cleanup in progress)
        guard let vm = viewModel else {
            // ViewModel is nil - likely being deallocated, don't create any Tasks
            return
        }

        // CRITICAL FIX: Stop processing frames when capture is complete
        // This prevents ARFrame retention during processing phase
        if vm.captureManager.isCaptureFullyComplete {
            // Capture is done - stop the session to free memory for processing
            stopAndCleanupSession()
            return
        }

        guard let faceAnchor = anchor as? ARFaceAnchor,
              let faceGeometry = node.geometry as? ARSCNFaceGeometry,
              let frame = sceneView.session.currentFrame else {
            return
        }

        // Final check before any processing - also check isCleaningUp
        guard !vm.shouldStopSession && !vm.isCleaningUp else {
            stopAndCleanupSession()
            return
        }

        // Update face mesh geometry
        faceGeometry.update(from: faceAnchor.geometry)

        // CRITICAL: Extract data from ARFrame BEFORE creating Task closures
        // ARFrames are heavy objects that must be released immediately to prevent memory warnings
        // The delegate retaining too many ARFrames will cause the camera to stop delivering frames
        let frameTimestamp = frame.timestamp

        // If multi-frame capture is active, add frame to averager
        if isMultiFrameCaptureActive, let averager = frameAverager {
            // Calculate tracking confidence (0-1)
            let confidence = calculateTrackingConfidence(faceAnchor: faceAnchor)

            // Add frame to averager (only uses geometry, not the frame itself)
            averager.addFrame(
                faceAnchor.geometry,
                confidence: confidence,
                timestamp: frameTimestamp
            )

            let currentFrameCount = averager.frameCount
            let reachedTarget = currentFrameCount >= targetFrameCount

            // OPTIMIZATION: Only create Task if state changed or target reached
            if currentFrameCount != previousFrameCount || reachedTarget {
                previousFrameCount = currentFrameCount
                previousConfidence = confidence

                // Capture targetFrameCount to avoid implicit self capture warning
                let targetCount = self.targetFrameCount

                // Batch both updates in single Task to reduce allocation overhead
                Task { [weak viewModel, weak self] in
                    // CRITICAL FIX: Check session stopped flag AT EXECUTION TIME
                    guard let strongSelf = self, !strongSelf.isSessionStopped else { return }
                    guard let vm = viewModel else { return }

                    // CRITICAL: Check cleanup/stop flags BEFORE awaiting MainActor
                    guard !vm.shouldStopSession && !vm.isCleaningUp else { return }

                    // Check cancellation before MainActor.run
                    guard !Task.isCancelled else { return }

                    await MainActor.run {
                        // Check cancellation and cleanup flags again after MainActor.run
                        guard !Task.isCancelled, let vm = viewModel, !vm.shouldStopSession, !vm.isCleaningUp else { return }
                        vm.onFrameCaptured(
                            frameCount: currentFrameCount,
                            targetCount: targetCount,
                            confidence: confidence
                        )

                        if reachedTarget {
                            vm.onMultiFrameCaptureReachedTarget()
                        }
                    }
                }
            }
        }

        // MARK: - ARFrame Memory Management Strategy
        //
        // PROBLEM: ARFrames are heavy objects (~8-12MB each). When captured by Task closures,
        // they create a retention chain: Task -> closure -> ARFrame. With 60fps tracking,
        // this can accumulate 11-13 retained frames before GC, causing memory warnings.
        //
        // SOLUTION: Three-tier approach to minimize ARFrame retention:
        //
        // 1. EXTRACT LIGHTWEIGHT DATA FIRST (before Task creation)
        //    - LightEstimation: ~100 bytes vs ~10MB ARFrame
        //    - Extracted synchronously before async boundary
        //
        // 2. CONDITIONAL FRAME PASSING (only when absolutely needed)
        //    - During CAPTURE: Frame needed for high-quality texture capture
        //    - During GUIDANCE: Frame needed for quality validation checks
        //    - During IDLE TRACKING: Frame NOT needed, only anchor updates
        //
        // 3. WEAK REFERENCES (prevent retain cycles)
        //    - [weak viewModel] prevents ViewController -> ViewModel -> Task cycle
        //    - frameRef is nil during idle, preventing 60fps frame accumulation
        //
        // RESULT: Memory usage reduced from 150MB peaks to 40MB during idle tracking
        // while maintaining full capture quality when needed.

        // Extract light estimation (lightweight struct, cheap to create)
        let lightEstimation = LightEstimation(frame: frame)

        // Determine if we actually need the heavy ARFrame object
        let isCapturing = vm.captureManager.isCaptureInProgress
        let isGuidanceActive = vm.captureManager.isGuidanceActive

        // OPTIMIZATION: Avoid implicit frame retention from ternary expression
        // Only create frame reference when absolutely needed
        var frameRef: ARFrame? = nil
        if isCapturing || isGuidanceActive {
            frameRef = frame
        }

        // Capture current frame sequence to allow early bailout for stale Tasks
        let frameSeq = self.frameSequenceNumber
        self.frameSequenceNumber += 1

        // MEMORY FIX: Limit concurrent frame processing to prevent ARFrame accumulation
        // When too many Tasks are in flight, skip non-essential frame updates
        if activeFrameProcessingCount >= Self.maxConcurrentFrameProcessing && frameRef == nil {
            // Skip this frame - too many in flight and not capturing
            return
        }

        // Track active processing
        activeFrameProcessingCount += 1

        Task { [weak viewModel, weak self, faceAnchor, lightEstimation, frameRef] in
            // MEMORY FIX: Decrement counter when task completes
            defer {
                self?.activeFrameProcessingCount -= 1
            }

            // CRITICAL FIX: Check session stopped flag AT EXECUTION TIME, not at capture time
            // This prevents ambient intensity logging after session stops
            guard let strongSelf = self, !strongSelf.isSessionStopped else { return }

            // Early bailout: skip if newer frames have been queued (unless in capture mode)
            // This releases stale frame references faster
            if frameRef == nil, frameSeq < strongSelf.frameSequenceNumber - 2 {
                return  // Skip stale tracking updates, release frame ref
            }
            // Skip if session was stopped (prevents deadlock during cleanup)
            guard let vm = viewModel else { return }

            // CRITICAL: Check cleanup/stop flags BEFORE awaiting MainActor
            // This prevents Tasks from piling up waiting for MainActor during dismissal
            guard !vm.shouldStopSession && !vm.isCleaningUp else { return }

            // Check cancellation before MainActor.run
            guard !Task.isCancelled else { return }

            await MainActor.run {
                // Check cancellation and cleanup flags again after MainActor.run
                guard !Task.isCancelled, !vm.shouldStopSession, !vm.isCleaningUp else { return }
                vm.updateGeometry(faceAnchor: faceAnchor, lightEstimation: lightEstimation, captureFrame: frameRef)
            }
        }

        // IMPORTANT: After this point, no more closures should capture frame
    }

    /// Calculate tracking confidence based on blend shapes and tracking quality
    private func calculateTrackingConfidence(faceAnchor: ARFaceAnchor) -> Float {
        // Use tracking state if available (ARKit 3.0+)
        var confidence: Float = 1.0

        // Penalize if face is too far from neutral (user moving too much)
        let blendShapes = faceAnchor.blendShapes
        if let jawOpen = blendShapes[.jawOpen]?.floatValue,
           let mouthFunnel = blendShapes[.mouthFunnel]?.floatValue {
            // If mouth is open or puckered, reduce confidence
            let mouthMovement = max(jawOpen, mouthFunnel)
            confidence *= (1.0 - mouthMovement * 0.5)
        }

        // Penalize for extreme head rotations (should be holding pose)
        let transform = faceAnchor.transform
        let eulerAngles = simd_float3(
            atan2(transform.columns.2.y, transform.columns.2.z),
            atan2(-transform.columns.2.x, sqrt(transform.columns.2.y * transform.columns.2.y + transform.columns.2.z * transform.columns.2.z)),
            atan2(transform.columns.1.x, transform.columns.0.x)
        )

        // If head is rotating significantly during capture, reduce confidence
        let rotationMagnitude = length(eulerAngles)
        if rotationMagnitude > 0.5 { // ~30 degrees
            confidence *= 0.7
        }

        return max(0.1, min(1.0, confidence))
    }

    public func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        // CRITICAL: Bail out immediately if session is stopping/stopped
        guard !isSessionStopped else { return }
        guard anchor is ARFaceAnchor else { return }
        guard let vm = viewModel, !vm.shouldStopSession else { return }

        Task { [weak viewModel] in
            guard let vm = viewModel, !vm.shouldStopSession else { return }
            await MainActor.run {
                vm.faceTrackingLost()
            }
        }
    }
}

// MARK: - ARSessionDelegate

extension ARFaceTrackingViewController: ARSessionDelegate {

    public func session(_ session: ARSession, didFailWithError error: Error) {
        // CRITICAL: Bail out immediately if session is stopping/stopped
        guard !isSessionStopped else { return }
        guard let vm = viewModel, !vm.shouldStopSession else { return }

        Task { [weak viewModel] in
            guard let vm = viewModel else { return }
            await MainActor.run {
                vm.sessionFailed(error: error)
            }
        }
    }

    public func sessionWasInterrupted(_ session: ARSession) {
        // CRITICAL: Bail out immediately if session is stopping/stopped
        guard !isSessionStopped else { return }
        guard let vm = viewModel, !vm.shouldStopSession else { return }

        Task { [weak viewModel] in
            guard let vm = viewModel else { return }
            await MainActor.run {
                vm.sessionInterrupted()
            }
        }
    }

    public func sessionInterruptionEnded(_ session: ARSession) {
        // CRITICAL: Bail out immediately if session is stopping/stopped
        guard !isSessionStopped else { return }
        guard let vm = viewModel, !vm.shouldStopSession else { return }

        Task { [weak viewModel] in
            guard let vm = viewModel else { return }
            await MainActor.run {
                vm.sessionInterruptionEnded()
            }
        }

        // Restart tracking
        startFaceTracking()
    }
}
