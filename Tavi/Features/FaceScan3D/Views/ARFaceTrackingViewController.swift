//
//  ARFaceTrackingViewController.swift
//  Tavi
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

    /// Cached light estimation to avoid repeated allocations
    private var cachedLightEstimation: LightEstimation?

    /// Previous frame count to detect changes
    private var previousFrameCount: Int = 0

    /// Previous confidence to detect changes
    private var previousConfidence: Float = 0

    // MARK: - Lifecycle

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
        sceneView.session.pause()
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
        guard anchor is ARFaceAnchor else { return nil }

        // Safely unwrap Metal device
        guard let device = sceneView.device else {
            print("ERROR: Metal device not available")
            viewModel?.sessionFailed(error: NSError(
                domain: "ARFaceTracking",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Your device does not support face tracking"]
            ))
            return nil
        }

        // Safely create face geometry
        guard let faceGeometry = ARSCNFaceGeometry(device: device) else {
            print("ERROR: Failed to create face geometry")
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
            print("ERROR: Face geometry has no material")
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
        guard let faceAnchor = anchor as? ARFaceAnchor,
              let faceGeometry = node.geometry as? ARSCNFaceGeometry,
              let frame = sceneView.session.currentFrame else {
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

                // Batch both updates in single Task to reduce allocation overhead
                Task { [weak viewModel] in
                    await MainActor.run {
                        viewModel?.onFrameCaptured(
                            frameCount: currentFrameCount,
                            targetCount: targetFrameCount,
                            confidence: confidence
                        )

                        if reachedTarget {
                            viewModel?.onMultiFrameCaptureReachedTarget()
                        }
                    }
                }
            }
        }

        // Always update view model with current geometry for real-time display
        // CRITICAL FIX: Extract light estimation data BEFORE Task to prevent ARFrame retention
        // ARFrames are heavy objects (11-13 retained frames causes memory warnings)
        // The Task closure capturing frame strongly causes the retention leak

        // OPTIMIZATION: Reuse cached light estimation object instead of creating new one each frame
        if cachedLightEstimation == nil {
            cachedLightEstimation = LightEstimation(frame: frame)
        } else {
            // Update existing object with new frame data (reduces allocations)
            cachedLightEstimation = LightEstimation(frame: frame)
        }

        guard let lightEstimation = cachedLightEstimation else { return }

        // For actual capture operations, we DO need the frame (but NOT during guidance)
        // OPTIMIZATION: Only pass frame during actual capture to reduce memory pressure
        let isCapturing = viewModel?.captureManager.isCaptureInProgress ?? false
        let frameRef = isCapturing ? frame : nil  // Only during capture, NOT guidance

        Task { [weak viewModel, faceAnchor, lightEstimation, frameRef] in
            await MainActor.run {
                // Pass extracted light data for tracking, optional frame only during capture
                viewModel?.updateGeometry(faceAnchor: faceAnchor, lightEstimation: lightEstimation, captureFrame: frameRef)
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
        guard anchor is ARFaceAnchor else { return }

        Task { @MainActor in
            viewModel?.faceTrackingLost()
        }
    }
}

// MARK: - ARSessionDelegate

extension ARFaceTrackingViewController: ARSessionDelegate {

    public func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            viewModel?.sessionFailed(error: error)
        }
    }

    public func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            viewModel?.sessionInterrupted()
        }
    }

    public func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            viewModel?.sessionInterruptionEnded()
        }

        // Restart tracking
        startFaceTracking()
    }
}
