//
//  CameraSession.swift
//  Tavi
//
//  Created on 2025-10-27.
//

@preconcurrency import AVFoundation
@preconcurrency import CoreVideo
@preconcurrency import CoreMedia
import Combine
import UIKit

// Thread-safe wrapper for CVPixelBuffer to work with Swift 6 concurrency
// CVPixelBuffer is thread-safe but not marked as Sendable in Swift 6
struct SendablePixelBuffer: @unchecked Sendable {
    let buffer: CVPixelBuffer
}

public enum CameraPosition: Sendable {
    case front
    case back
}

public enum CameraSessionError: Error {
    case deviceNotAvailable
    case configurationFailed
    case authorizationDenied
    case inputAddFailed
    case outputAddFailed
}

@MainActor
public class CameraSession: NSObject {

    // MARK: - Published Properties

    @Published public private(set) var currentPosition: CameraPosition = .front
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var isExposureLocked: Bool = false
    @Published public private(set) var error: CameraSessionError?

    // MARK: - Frame Publisher

    nonisolated private let frameSubject = PassthroughSubject<SendablePixelBuffer, Never>()
    public var framePublisher: AnyPublisher<CVPixelBuffer, Never> {
        frameSubject.map { $0.buffer }.eraseToAnyPublisher()
    }

    // MARK: - Calibration Metrics Publisher

    nonisolated private let metricsSubject = PassthroughSubject<CalibrationMetrics, Never>()
    public var metricsPublisher: AnyPublisher<CalibrationMetrics, Never> {
        metricsSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    nonisolated private let captureSession = AVCaptureSession()
    nonisolated(unsafe) private var videoDeviceInput: AVCaptureDeviceInput?
    nonisolated private let videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.tavi.camera.session")
    private let metricsQueue = DispatchQueue(label: "com.tavi.camera.metrics", qos: .userInitiated)
    nonisolated(unsafe) private var currentDevice: AVCaptureDevice?

    // MARK: - Initialization

    public override init() {
        super.init()
        setupVideoOutput()
    }

    // MARK: - Private Setup Methods

    private func setupVideoOutput() {
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
    }

    nonisolated private func selectBestDevice(for position: CameraPosition) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType]

        switch position {
        case .front:
            // Prefer TrueDepth camera if available
            deviceTypes = [.builtInTrueDepthCamera, .builtInWideAngleCamera]
        case .back:
            // Prefer wide angle camera for back
            deviceTypes = [.builtInWideAngleCamera, .builtInDualCamera, .builtInTripleCamera]
        }

        let cameraPosition: AVCaptureDevice.Position = position == .front ? .front : .back

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: cameraPosition
        )

        return discoverySession.devices.first
    }

    nonisolated private func configureCameraForHighQuality(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        // Try to find the best format (4K 30fps or 1080p 30fps)
        let preferredFormats = device.formats.filter { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let ranges = format.videoSupportedFrameRateRanges

            // Check if format supports 30fps
            let supports30fps = ranges.contains { range in
                range.minFrameRate <= 30 && range.maxFrameRate >= 30
            }

            // Prefer 4K (3840x2160) or 1080p (1920x1080)
            let is4K = dimensions.width == 3840 && dimensions.height == 2160
            let is1080p = dimensions.width == 1920 && dimensions.height == 1080

            return (is4K || is1080p) && supports30fps
        }

        // Sort by resolution (4K first, then 1080p)
        let sortedFormats = preferredFormats.sorted { format1, format2 in
            let dims1 = CMVideoFormatDescriptionGetDimensions(format1.formatDescription)
            let dims2 = CMVideoFormatDescriptionGetDimensions(format2.formatDescription)
            return dims1.width > dims2.width
        }

        if let bestFormat = sortedFormats.first {
            device.activeFormat = bestFormat

            // Set frame rate to 30fps
            let frameDuration = CMTime(value: 1, timescale: 30)
            device.activeVideoMinFrameDuration = frameDuration
            device.activeVideoMaxFrameDuration = frameDuration
        }

        // Enable smooth autofocus if available
        if device.isSmoothAutoFocusSupported {
            device.isSmoothAutoFocusEnabled = true
        }

        // Set focus mode to continuous auto focus if supported
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }

        // Set exposure mode to continuous auto exposure
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }

        // Set white balance mode to continuous auto white balance
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
    }

    nonisolated private func configureSession(for position: CameraPosition) throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // Remove existing inputs
        if let existingInput = videoDeviceInput {
            captureSession.removeInput(existingInput)
        }

        // Select device
        guard let device = selectBestDevice(for: position) else {
            throw CameraSessionError.deviceNotAvailable
        }

        currentDevice = device

        // Configure device for high quality
        try configureCameraForHighQuality(device)

        // Create input
        let input = try AVCaptureDeviceInput(device: device)

        guard captureSession.canAddInput(input) else {
            throw CameraSessionError.inputAddFailed
        }

        captureSession.addInput(input)
        videoDeviceInput = input

        // Add output if not already added
        if !captureSession.outputs.contains(videoDataOutput) {
            guard captureSession.canAddOutput(videoDataOutput) else {
                throw CameraSessionError.outputAddFailed
            }
            captureSession.addOutput(videoDataOutput)
        }

        // Set session preset based on capabilities
        if captureSession.canSetSessionPreset(.hd4K3840x2160) {
            captureSession.sessionPreset = .hd4K3840x2160
        } else if captureSession.canSetSessionPreset(.hd1920x1080) {
            captureSession.sessionPreset = .hd1920x1080
        }

        // Configure video orientation
        if let connection = videoDataOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = (position == .front)
            }
        }
    }

    // MARK: - Public Methods

    public func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            await MainActor.run {
                self.error = .authorizationDenied
            }
            return false
        @unknown default:
            return false
        }
    }

    public func start(position: CameraPosition = .front) async throws {
        guard await checkAuthorization() else {
            throw CameraSessionError.authorizationDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CameraSessionError.configurationFailed)
                    return
                }

                do {
                    try self.configureSession(for: position)
                    self.captureSession.startRunning()

                    Task { @MainActor in
                        self.currentPosition = position
                        self.isRunning = true
                        continuation.resume()
                    }
                } catch {
                    Task { @MainActor in
                        self.error = error as? CameraSessionError ?? .configurationFailed
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if self.captureSession.isRunning {
                self.captureSession.stopRunning()

                Task { @MainActor in
                    self.isRunning = false
                    self.isExposureLocked = false
                }
            }
        }
    }

    public func switchCamera() async throws {
        let newPosition: CameraPosition = currentPosition == .front ? .back : .front

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CameraSessionError.configurationFailed)
                    return
                }

                do {
                    try self.configureSession(for: newPosition)

                    Task { @MainActor in
                        self.currentPosition = newPosition
                        self.isExposureLocked = false
                        continuation.resume()
                    }
                } catch {
                    Task { @MainActor in
                        self.error = error as? CameraSessionError ?? .configurationFailed
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func lockExposureAndWhiteBalance() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let device = self.currentDevice else { return }

            do {
                try device.lockForConfiguration()

                // Lock exposure
                if device.isExposureModeSupported(.locked) {
                    device.exposureMode = .locked
                }

                // Lock white balance
                if device.isWhiteBalanceModeSupported(.locked) {
                    device.whiteBalanceMode = .locked
                }

                device.unlockForConfiguration()

                Task { @MainActor in
                    self.isExposureLocked = true
                }
            } catch {
                print("Failed to lock exposure and white balance: \(error)")
            }
        }
    }

    public func unlockExposureAndWhiteBalance() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let device = self.currentDevice else { return }

            do {
                try device.lockForConfiguration()

                // Unlock exposure
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }

                // Unlock white balance
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }

                device.unlockForConfiguration()

                Task { @MainActor in
                    self.isExposureLocked = false
                }
            } catch {
                print("Failed to unlock exposure and white balance: \(error)")
            }
        }
    }

    public func getCurrentResolution() -> CGSize? {
        guard let device = currentDevice else { return nil }
        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        return CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
    }

    public func getCurrentFrameRate() -> Double? {
        guard let device = currentDevice else { return nil }
        return Double(device.activeVideoMaxFrameDuration.timescale) / Double(device.activeVideoMaxFrameDuration.value)
    }

    // MARK: - Private Metrics Computation

    nonisolated private func computeMetrics(from pixelBuffer: CVPixelBuffer) -> CalibrationMetrics? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        var histogram = [Int](repeating: 0, count: 256)
        var lumaSum: Double = 0.0
        let totalPixels = width * height

        // Process pixels (BGRA format)
        for y in 0..<height {
            let rowBase = buffer.advanced(by: y * bytesPerRow)

            for x in 0..<width {
                let pixelOffset = x * 4
                let b = Double(rowBase[pixelOffset])
                let g = Double(rowBase[pixelOffset + 1])
                let r = Double(rowBase[pixelOffset + 2])

                // Compute luma using Rec. 709 coefficients
                let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
                let lumaInt = Int(min(255, max(0, luma)))

                histogram[lumaInt] += 1
                lumaSum += luma
            }
        }

        let averageLuma = (lumaSum / Double(totalPixels)) / 255.0

        return CalibrationMetrics(
            averageLuma: averageLuma,
            histogram: histogram,
            totalPixels: totalPixels
        )
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {

    nonisolated public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Wrap in Sendable wrapper for thread-safe operations
        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)

        // Send frame to publisher (thread-safe)
        frameSubject.send(sendableBuffer)

        // Compute metrics on separate queue
        metricsQueue.async { [weak self] in
            guard let self = self,
                  let metrics = self.computeMetrics(from: sendableBuffer.buffer) else {
                return
            }

            // Send metrics to publisher (thread-safe)
            self.metricsSubject.send(metrics)
        }
    }

    nonisolated public func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Frame was dropped - could log this for debugging
    }
}
