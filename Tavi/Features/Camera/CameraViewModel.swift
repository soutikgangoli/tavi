//
//  CameraViewModel.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import Combine
import UIKit
import CoreVideo

@MainActor
class CameraViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isCapturing = false
    @Published var currentCameraPosition: CameraPosition = .front
    @Published var isExposureLocked = false
    @Published var errorMessage: String?
    @Published var currentResolution: String = "Not available"
    @Published var currentFrameRate: String = "Not available"
    @Published var latestFrame: UIImage?

    // MARK: - Calibration Properties

    @Published var currentMetrics: CalibrationMetrics?
    @Published var isCalibrated = false

    // MARK: - Face Detection Properties

    @Published var detectedFaces: [FaceDetectionResult] = []
    @Published var showFaceLandmarks = false
    @Published var faceDetectionEnabled = true

    // MARK: - ROI Properties

    @Published var faceROIs: [FaceROISet] = []
    @Published var showROIs = false
    @Published var extractedROIs: [ExtractedROIImage] = []

    // MARK: - Capture Properties

    @Published var captureController: CaptureController!
    @Published var captureInProgress = false
    @Published var lastCaptureResult: CaptureResult?

    // MARK: - Metrics Properties

    @Published var lastMetricsResult: MetricsResult?
    @Published var metricsInProgress = false

    // MARK: - Scoring Properties

    @Published var lastScoreSummary: ScoreSummary?

    // MARK: - Session Properties

    @Published var sessionSaved = false
    @Published var saveInProgress = false

    // MARK: - Private Properties

    private let storageManager = StorageManager.shared
    private let heatmapGenerator = HeatmapGenerator()

    private let cameraSession = CameraSession()
    private let faceDetector = FaceDetector()
    private let roiBuilder = ROIBuilder(configuration: .default)
    private let metricsComputer = MetricsComputer(configuration: .default)
    private let scoringEngine = ScoringEngine(constants: .default)
    private var cancellables = Set<AnyCancellable>()
    private var frameProcessingQueue = DispatchQueue(label: "com.tavi.frameProcessing", qos: .userInitiated)
    private var latestPixelBuffer: CVPixelBuffer?

    // MARK: - Initialization

    init() {
        captureController = CaptureController(
            configuration: .default,
            faceDetector: faceDetector,
            roiBuilder: roiBuilder
        )
        setupBindings()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Observe camera session state
        cameraSession.$isRunning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isCapturing)

        cameraSession.$currentPosition
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentCameraPosition)

        cameraSession.$isExposureLocked
            .receive(on: DispatchQueue.main)
            .assign(to: &$isExposureLocked)

        cameraSession.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    self?.errorMessage = self?.errorDescription(for: error)
                }
            }
            .store(in: &cancellables)

        // Subscribe to frame updates (optional: for preview or debugging)
        cameraSession.framePublisher
            .receive(on: frameProcessingQueue)
            .compactMap { [weak self] pixelBuffer -> UIImage? in
                self?.convertToUIImage(pixelBuffer: pixelBuffer)
            }
            .throttle(for: .milliseconds(100), scheduler: frameProcessingQueue, latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                self?.latestFrame = image
            }
            .store(in: &cancellables)

        // Subscribe to calibration metrics
        cameraSession.metricsPublisher
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.currentMetrics = metrics
            }
            .store(in: &cancellables)

        // Subscribe to frames for face detection
        cameraSession.framePublisher
            .receive(on: frameProcessingQueue)
            .sink { [weak self] pixelBuffer in
                guard let self = self else { return }

                // Store latest pixel buffer for capture
                self.latestPixelBuffer = pixelBuffer

                // Throttled face detection
                if self.faceDetectionEnabled {
                    self.detectFaces(in: pixelBuffer)
                }
            }
            .store(in: &cancellables)
    }

    private func errorDescription(for error: CameraSessionError) -> String {
        switch error {
        case .deviceNotAvailable:
            return "Camera device not available"
        case .configurationFailed:
            return "Failed to configure camera"
        case .authorizationDenied:
            return "Camera access denied. Please enable in Settings."
        case .inputAddFailed:
            return "Failed to add camera input"
        case .outputAddFailed:
            return "Failed to add camera output"
        }
    }

    private func convertToUIImage(pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func updateCameraInfo() {
        if let resolution = cameraSession.getCurrentResolution() {
            currentResolution = "\(Int(resolution.width))x\(Int(resolution.height))"
        }

        if let frameRate = cameraSession.getCurrentFrameRate() {
            currentFrameRate = "\(Int(frameRate)) fps"
        }
    }

    // MARK: - Public Methods

    func startCapture() {
        Task {
            do {
                try await cameraSession.start(position: .front)
                updateCameraInfo()
            } catch {
                errorMessage = "Failed to start camera: \(error.localizedDescription)"
            }
        }
    }

    func stopCapture() {
        cameraSession.stop()
        latestFrame = nil
        currentResolution = "Not available"
        currentFrameRate = "Not available"
    }

    func switchCamera() {
        Task {
            do {
                try await cameraSession.switchCamera()
                updateCameraInfo()
                isCalibrated = false // Reset calibration when switching cameras
            } catch {
                errorMessage = "Failed to switch camera: \(error.localizedDescription)"
            }
        }
    }

    func toggleExposureLock() {
        if isExposureLocked {
            cameraSession.unlockExposureAndWhiteBalance()
            isCalibrated = false
        } else {
            cameraSession.lockExposureAndWhiteBalance()
        }
    }

    func calibrate() {
        guard let metrics = currentMetrics,
              metrics.calibrationStatus == .good else {
            errorMessage = "Cannot calibrate - conditions not optimal"
            return
        }

        // Lock exposure and white balance
        cameraSession.lockExposureAndWhiteBalance()
        isCalibrated = true

        // Haptic feedback for successful calibration
        HapticManager.shared.calibrationSuccess()
    }

    func toggleFaceLandmarks() {
        showFaceLandmarks.toggle()
    }

    func toggleFaceDetection() {
        faceDetectionEnabled.toggle()
        if !faceDetectionEnabled {
            detectedFaces = []
            faceROIs = []
        }
    }

    func toggleROIs() {
        showROIs.toggle()
        if !showROIs {
            faceROIs = []
            extractedROIs = []
        }
    }

    // MARK: - ROI Extraction

    func extractROIsFromCurrentFrame() async {
        guard !faceROIs.isEmpty,
              let latestFrame = latestFrame,
              let cgImage = latestFrame.cgImage else {
            errorMessage = "No face ROIs available"
            return
        }

        do {
            var allExtractedROIs: [ExtractedROIImage] = []

            for roiSet in faceROIs {
                let extracted = try roiBuilder.extractROIImages(from: cgImage, using: roiSet)
                allExtractedROIs.append(contentsOf: extracted)
            }

            extractedROIs = allExtractedROIs

        } catch {
            errorMessage = "Failed to extract ROIs: \(error.localizedDescription)"
        }
    }

    // MARK: - Face Detection

    private func detectFaces(in pixelBuffer: CVPixelBuffer) {
        Task {
            do {
                // Determine orientation based on camera position
                let orientation: CGImagePropertyOrientation = currentCameraPosition == .front ? .leftMirrored : .right

                let faces = try await faceDetector.detectFaces(in: pixelBuffer, orientation: orientation)

                // Compute ROIs if enabled
                var roiSets: [FaceROISet] = []
                if showROIs, let imageSize = getImageSize() {
                    for face in faces {
                        if let roiSet = try? roiBuilder.computeROIs(for: face, imageSize: imageSize) {
                            roiSets.append(roiSet)
                        }
                    }
                }

                await MainActor.run {
                    self.detectedFaces = faces
                    self.faceROIs = roiSets
                }
            } catch {
                // Silently fail face detection to avoid spamming errors
                await MainActor.run {
                    self.detectedFaces = []
                    self.faceROIs = []
                }
            }
        }
    }

    func getCameraSession() -> CameraSession {
        return cameraSession
    }

    func getImageSize() -> CGSize? {
        return cameraSession.getCurrentResolution()
    }

    // MARK: - Multi-Frame Capture

    func startMultiFrameCapture() async {
        guard !captureInProgress else {
            errorMessage = "Capture already in progress"
            return
        }

        captureInProgress = true

        do {
            let result = try await captureController.startCapture { [weak self] in
                await self?.latestPixelBuffer
            }

            lastCaptureResult = result
            extractedROIs = result.roiImages

            // Haptic feedback for successful capture
            HapticManager.shared.captureComplete()

            // Automatically compute metrics after successful capture
            await computeMetrics(for: result.roiImages)

        } catch {
            errorMessage = "Capture failed: \(error.localizedDescription)"
        }

        captureInProgress = false
    }

    func cancelCapture() {
        captureController.cancelCapture()
        captureInProgress = false
    }

    // MARK: - Metrics Computation

    func computeMetrics(for roiImages: [ExtractedROIImage]) async {
        guard !metricsInProgress else {
            errorMessage = "Metrics computation already in progress"
            return
        }

        metricsInProgress = true

        do {
            // Compute metrics on background thread
            let metrics = try await Task.detached(priority: .userInitiated) { [weak self] in
                guard let self = self else { throw MetricsError.insufficientROIs }
                return try self.metricsComputer.computeMetrics(for: roiImages)
            }.value

            lastMetricsResult = metrics

            // Compute scores from metrics
            let scores = await Task.detached(priority: .userInitiated) { [weak self] in
                guard let self = self else { return nil }
                return self.scoringEngine.computeScores(from: metrics)
            }.value

            lastScoreSummary = scores

        } catch {
            errorMessage = "Metrics computation failed: \(error.localizedDescription)"
        }

        metricsInProgress = false
    }

    // MARK: - Session Saving

    /// Save the current analysis session to Core Data
    func saveSession() async {
        guard let scores = lastScoreSummary,
              let captureResult = lastCaptureResult,
              !saveInProgress else {
            errorMessage = "No analysis results to save"
            return
        }

        saveInProgress = true
        sessionSaved = false

        do {
            // Get the base face image from capture result
            guard let faceImage = captureResult.alignedFaceImage else {
                throw NSError(domain: "CameraViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No face image available"])
            }

            // Generate heatmaps for all metrics
            let heatmaps = try await generateHeatmaps(
                faceImage: faceImage,
                metricsResult: lastMetricsResult
            )

            // Save to Core Data
            try storageManager.saveSession(
                scores: scores,
                faceImage: faceImage,
                heatmaps: heatmaps
            )

            sessionSaved = true

        } catch {
            errorMessage = "Failed to save session: \(error.localizedDescription)"
        }

        saveInProgress = false
    }

    /// Generate heatmaps for all metrics
    private func generateHeatmaps(
        faceImage: CGImage,
        metricsResult: MetricsResult?
    ) async throws -> [HeatmapMetric: CGImage] {
        guard let metricsResult = metricsResult else {
            return [:]
        }

        var heatmaps: [HeatmapMetric: CGImage] = [:]

        // Generate on background thread
        let generatedHeatmaps = try await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return [:] }

            var result: [HeatmapMetric: CGImage] = [:]

            // Generate composite heatmap
            if let composite = try? self.heatmapGenerator.generateCompositeHeatmap(
                baseImage: faceImage,
                metrics: metricsResult
            ) {
                result[.composite] = composite
            }

            // Generate individual metric heatmaps
            if let sharpness = try? self.heatmapGenerator.generateMetricHeatmap(
                baseImage: faceImage,
                metrics: metricsResult,
                metric: .sharpness
            ) {
                result[.sharpness] = sharpness
            }

            if let texture = try? self.heatmapGenerator.generateMetricHeatmap(
                baseImage: faceImage,
                metrics: metricsResult,
                metric: .texture
            ) {
                result[.texture] = texture
            }

            if let pigmentation = try? self.heatmapGenerator.generateMetricHeatmap(
                baseImage: faceImage,
                metrics: metricsResult,
                metric: .pigmentation
            ) {
                result[.pigmentation] = pigmentation
            }

            if let moisture = try? self.heatmapGenerator.generateMetricHeatmap(
                baseImage: faceImage,
                metrics: metricsResult,
                metric: .moisture
            ) {
                result[.moisture] = moisture
            }

            return result
        }.value

        return generatedHeatmaps
    }
}
