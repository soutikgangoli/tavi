//
//  DebugViewModel.swift
//  Ollvy
//
//  Created on 2025-10-27.
//

import Foundation
import Combine
import UIKit
import CoreVideo
import SwiftUI
import ARKit

@MainActor
class DebugViewModel: ObservableObject {

    // MARK: - Published Properties

    // Calibration Metrics
    @Published var currentMetrics: CalibrationMetrics?
    @Published var histogram: [Int] = Array(repeating: 0, count: 256)
    @Published var averageLuma: Double = 0.0
    @Published var blurScore: Double = 0.0

    // Camera Events
    @Published var exposureLockEvents: [CameraEvent] = []
    @Published var whiteBalanceLockEvents: [CameraEvent] = []
    @Published var isExposureLocked = false
    @Published var isWhiteBalanceLocked = false

    // Face Detection
    @Published var detectedFaces: [FaceDetectionResult] = []
    @Published var showFaceBounds = true
    @Published var showLandmarks = true
    @Published var usingARKitAngles = false // Indicates if angles are from ARKit (accurate) vs Vision (approximate)

    // ROI Data
    @Published var faceROIs: [FaceROISet] = []
    @Published var selectedROI: (FaceROISet, ROIType)?
    @Published var showROIMetrics = false

    // Performance Metrics
    @Published var currentFPS: Double = 0.0
    @Published var processingLatency: Double = 0.0
    @Published var frameCount: Int = 0
    @Published var averageLatency: Double = 0.0

    // Frame Data
    @Published var latestFrame: UIImage?

    // MARK: - Private Properties

    private let cameraSession: CameraSession
    private let faceDetector = FaceDetector()
    private let roiBuilder = ROIBuilder()
    private var cancellables = Set<AnyCancellable>()

    // FPS Tracking
    private var lastFrameTime = Date()
    private var fpsBuffer: [Double] = []
    private let fpsBufferSize = 30

    // Latency Tracking
    private var latencyBuffer: [Double] = []
    private let latencyBufferSize = 30

    // Frame Processing
    private var frameProcessingQueue = DispatchQueue(label: "com.ollvy.debug.frameProcessing", qos: .userInitiated)
    private var latestPixelBuffer: CVPixelBuffer?

    // MARK: - Initialization

    init(cameraSession: CameraSession) {
        self.cameraSession = cameraSession
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Subscribe to calibration metrics
        // FIXED: Defer @Published updates to avoid "Publishing changes from within view updates"
        cameraSession.metricsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                DispatchQueue.main.async {
                    self?.currentMetrics = metrics
                    self?.histogram = metrics.histogram
                    self?.averageLuma = metrics.averageLuma
                }
            }
            .store(in: &cancellables)

        // Subscribe to exposure lock state
        // FIXED: Defer @Published updates to avoid "Publishing changes from within view updates"
        cameraSession.$isExposureLocked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLocked in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if self.isExposureLocked != isLocked {
                        self.isExposureLocked = isLocked
                        self.addExposureLockEvent(isLocked: isLocked)
                    }
                }
            }
            .store(in: &cancellables)

        // Subscribe to frames for face detection and FPS tracking
        cameraSession.framePublisher
            .receive(on: frameProcessingQueue)
            .sink { [weak self] pixelBuffer in
                guard let self = self else { return }
                self.latestPixelBuffer = pixelBuffer

                // Track FPS
                self.trackFPS()

                // Process frame for face detection
                // Note: ARFaceAnchor will be passed separately via updateFrame() from DebugScreen
                self.processFrame(pixelBuffer, arFaceAnchor: nil)
            }
            .store(in: &cancellables)
    }

    // MARK: - FPS Tracking

    private func trackFPS() {
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastFrameTime)
        lastFrameTime = now

        if deltaTime > 0 {
            let fps = 1.0 / deltaTime

            // Add to buffer
            fpsBuffer.append(fps)
            if fpsBuffer.count > fpsBufferSize {
                fpsBuffer.removeFirst()
            }

            // Calculate average FPS
            let averageFPS = fpsBuffer.reduce(0, +) / Double(fpsBuffer.count)

            Task { @MainActor in
                self.currentFPS = averageFPS
                self.frameCount += 1
            }
        }
    }

    // MARK: - Frame Processing

    /// Process frame with optional ARFaceAnchor for accurate angle detection
    /// - Parameters:
    ///   - pixelBuffer: The camera frame buffer
    ///   - arFaceAnchor: Optional ARFaceAnchor from ARKit session (provides accurate 3D angles)
    func processFrame(_ pixelBuffer: CVPixelBuffer, arFaceAnchor: ARFaceAnchor? = nil) {
        let startTime = Date()

        Task {
            var faces: [FaceDetectionResult] = []
            var usingARKit = false

            // Priority 1: Use ARKit if available (accurate 3D angles)
            if let faceAnchor = arFaceAnchor {
                let arFace = faceDetector.detectFaceFromARKit(faceAnchor: faceAnchor)
                faces = [arFace]
                usingARKit = true
                AppLogger.faceScan.debug("Debug: Using ARKit angles - Yaw: \(arFace.yaw ?? 0)°, Pitch: \(arFace.pitch ?? 0)°, Roll: \(arFace.roll ?? 0)°")
            }
            // Priority 2: Fall back to Vision-based detection (approximate angles from landmarks)
            else if let cgImage = convertToCGImage(pixelBuffer: pixelBuffer) {
                faces = faceDetector.detectFaces(in: cgImage)
                usingARKit = false
                if let face = faces.first {
                    if face.yaw != nil || face.pitch != nil || face.roll != nil {
                        AppLogger.faceScan.debug("Debug: Using Vision approximate angles - Yaw: \(face.yaw ?? 0)°, Pitch: \(face.pitch ?? 0)°, Roll: \(face.roll ?? 0)°")
                    } else {
                        AppLogger.faceScan.debug("Debug: Vision angles unavailable (missing landmarks)")
                    }
                }
            }

            // Compute ROIs
            var roiSets: [FaceROISet] = []
            if let imageSize = getImageSize() {
                for face in faces {
                    if let roiSet = try? roiBuilder.computeROIs(for: face, imageSize: imageSize) {
                        roiSets.append(roiSet)
                    }
                }
            }

            // Calculate processing latency
            let latency = Date().timeIntervalSince(startTime) * 1000 // Convert to ms

            // Update UI on main thread
            await MainActor.run {
                self.detectedFaces = faces
                self.faceROIs = roiSets
                self.usingARKitAngles = usingARKit
                self.trackLatency(latency)
            }

            // Convert to UIImage for display
            if let uiImage = convertToUIImage(pixelBuffer: pixelBuffer) {
                await MainActor.run {
                    self.latestFrame = uiImage
                }
            }
        }
    }

    private func trackLatency(_ latency: Double) {
        latencyBuffer.append(latency)
        if latencyBuffer.count > latencyBufferSize {
            latencyBuffer.removeFirst()
        }

        processingLatency = latency
        averageLatency = latencyBuffer.reduce(0, +) / Double(latencyBuffer.count)
    }

    private func convertToUIImage(pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func convertToCGImage(pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }

    private func getImageSize() -> CGSize? {
        return cameraSession.getCurrentResolution()
    }

    // MARK: - Camera Event Tracking

    private func addExposureLockEvent(isLocked: Bool) {
        let event = CameraEvent(
            timestamp: Date(),
            type: isLocked ? .exposureLocked : .exposureUnlocked
        )

        exposureLockEvents.insert(event, at: 0)

        // Keep only last 20 events
        if exposureLockEvents.count > 20 {
            exposureLockEvents.removeLast()
        }
    }

    func addWhiteBalanceLockEvent(isLocked: Bool) {
        isWhiteBalanceLocked = isLocked

        let event = CameraEvent(
            timestamp: Date(),
            type: isLocked ? .whiteBalanceLocked : .whiteBalanceUnlocked
        )

        whiteBalanceLockEvents.insert(event, at: 0)

        // Keep only last 20 events
        if whiteBalanceLockEvents.count > 20 {
            whiteBalanceLockEvents.removeLast()
        }
    }

    // MARK: - ROI Selection

    func selectROI(roiSet: FaceROISet, roiType: ROIType, at point: CGPoint) {
        selectedROI = (roiSet, roiType)
        showROIMetrics = true
    }

    func dismissROIMetrics() {
        showROIMetrics = false
        selectedROI = nil
    }

    // MARK: - Public Update Methods

    /// Update with ARFaceAnchor for accurate angle detection
    /// Call this from DebugScreen when ARFaceAnchor is available
    func updateWithARFaceAnchor(_ faceAnchor: ARFaceAnchor, pixelBuffer: CVPixelBuffer) {
        processFrame(pixelBuffer, arFaceAnchor: faceAnchor)
    }

    // MARK: - Toggles

    func toggleFaceBounds() {
        showFaceBounds.toggle()
    }

    func toggleLandmarks() {
        showLandmarks.toggle()
    }

    // MARK: - Blur Score (Placeholder - would need implementation)

    func updateBlurScore(_ score: Double) {
        blurScore = score
    }

    // MARK: - Reset

    func resetStats() {
        frameCount = 0
        fpsBuffer.removeAll()
        latencyBuffer.removeAll()
        exposureLockEvents.removeAll()
        whiteBalanceLockEvents.removeAll()
    }
}

// MARK: - Camera Event Model

struct CameraEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: CameraEventType

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    var relativeTime: String {
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 1 {
            return String(format: "%.0f ms ago", interval * 1000)
        } else if interval < 60 {
            return String(format: "%.1f sec ago", interval)
        } else {
            return String(format: "%.1f min ago", interval / 60)
        }
    }
}

enum CameraEventType {
    case exposureLocked
    case exposureUnlocked
    case whiteBalanceLocked
    case whiteBalanceUnlocked

    var displayName: String {
        switch self {
        case .exposureLocked: return "Exposure Locked"
        case .exposureUnlocked: return "Exposure Unlocked"
        case .whiteBalanceLocked: return "WB Locked"
        case .whiteBalanceUnlocked: return "WB Unlocked"
        }
    }

    var icon: String {
        switch self {
        case .exposureLocked: return "lock.fill"
        case .exposureUnlocked: return "lock.open.fill"
        case .whiteBalanceLocked: return "sun.max.fill"
        case .whiteBalanceUnlocked: return "sun.max"
        }
    }

    var color: Color {
        switch self {
        case .exposureLocked, .whiteBalanceLocked:
            return .green
        case .exposureUnlocked, .whiteBalanceUnlocked:
            return .orange
        }
    }
}
