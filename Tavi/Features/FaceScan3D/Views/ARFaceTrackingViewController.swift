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
        camera.exposureAdaptationMode = .automatic

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
}

// MARK: - ARSCNViewDelegate

extension ARFaceTrackingViewController: ARSCNViewDelegate {

    public func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return nil }

        // Create face geometry node
        let faceGeometry = ARSCNFaceGeometry(device: sceneView.device!)!
        let node = SCNNode(geometry: faceGeometry)

        // Configure material
        let material = faceGeometry.firstMaterial!
        material.diffuse.contents = UIColor.white.withAlphaComponent(0.8)
        material.lightingModel = .physicallyBased
        material.fillMode = .fill

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

        // Update view model on main thread
        Task { @MainActor in
            viewModel?.updateGeometry(faceAnchor: faceAnchor, frame: frame)
        }
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
