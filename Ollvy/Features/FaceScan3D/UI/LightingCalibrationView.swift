//
//  LightingCalibrationView.swift
//  Ollvy
//
//  Real-time lighting calibration guide for optimal scan quality
//  Guides users to achieve 40-70% brightness (optimal range)
//  Blocks scans if lighting < 25% or > 90%
//

import SwiftUI
import AVFoundation

/// Lighting quality levels (UI version)
public enum UILightingQuality {
    case tooDark         // < 25% - BLOCK
    case suboptimalDark  // 25-40% - WARN
    case optimal         // 40-70% - GOOD
    case suboptimalBright // 70-90% - WARN
    case tooBright       // > 90% - BLOCK

    var color: Color {
        switch self {
        case .tooDark, .tooBright: return .red
        case .suboptimalDark, .suboptimalBright: return .orange
        case .optimal: return .green
        }
    }

    var icon: String {
        switch self {
        case .tooDark: return "moon.fill"
        case .suboptimalDark: return "moon.stars.fill"
        case .optimal: return "sun.max.fill"
        case .suboptimalBright: return "sun.max"
        case .tooBright: return "sun.max.circle.fill"
        }
    }

    var message: String {
        switch self {
        case .tooDark: return "Too dark - increase lighting"
        case .suboptimalDark: return "Lighting is low - move to brighter area"
        case .optimal: return "Perfect lighting!"
        case .suboptimalBright: return "Lighting is bright - reduce glare"
        case .tooBright: return "Too bright - reduce lighting or move"
        }
    }

    var canProceed: Bool {
        switch self {
        case .tooDark, .tooBright: return false
        default: return true
        }
    }
}

/// Real-time lighting calibration view
public struct LightingCalibrationView: View {
    @ObservedObject var viewModel: LightingCalibrationViewModel
    let onComplete: () -> Void
    let onCancel: () -> Void

    public var body: some View {
        ZStack {
            // Camera preview (full screen)
            CameraPreviewView(session: viewModel.captureSession)
                .edgesIgnoringSafeArea(.all)

            // Overlay with guidance
            VStack {
                Spacer()

                // Lighting status card
                VStack(spacing: 16) {
                    // Icon and status
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.lightingQuality.icon)
                            .font(.app(size: 40))
                            .foregroundColor(viewModel.lightingQuality.color)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.lightingQuality.message)
                                .font(.headline)
                                .foregroundColor(.white)

                            Text("Brightness: \(Int(viewModel.currentBrightness * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(Designs.Opacity.semiTransparent))
                        }

                        Spacer()
                    }
                    .padding()
                    .background(viewModel.lightingQuality.color.opacity(Designs.Opacity.medium))
                    .cornerRadius(Designs.Radius.medium)

                    // Brightness meter
                    BrightnessMeterView(
                        brightness: viewModel.currentBrightness,
                        quality: viewModel.lightingQuality
                    )

                    // Action buttons
                    HStack(spacing: 16) {
                        Button(action: onCancel) {
                            Text("Cancel")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(Designs.Opacity.semiOpaque))
                                .cornerRadius(Designs.Radius.medium)
                        }

                        Button(action: onComplete) {
                            Text(viewModel.lightingQuality.canProceed ? "Continue" : "Waiting for good lighting...")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(viewModel.lightingQuality.canProceed ? Color.blue : Color.gray.opacity(Designs.Opacity.semiOpaque))
                                .cornerRadius(Designs.Radius.medium)
                        }
                        .disabled(!viewModel.lightingQuality.canProceed)
                    }
                }
                .padding()
                .background(Color.black.opacity(Designs.Opacity.semiTransparent))
                .cornerRadius(Designs.Radius.large)
                .padding()
            }
        }
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
}

/// Brightness meter visual component
struct BrightnessMeterView: View {
    let brightness: Float
    let quality: UILightingQuality

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target: 40-70%")
                .font(.caption)
                .foregroundColor(.white.opacity(Designs.Opacity.semiTransparent))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(Designs.Opacity.light))

                    // Optimal zone (40-70%)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(Designs.Opacity.medium))
                        .frame(width: geometry.size.width * 0.3)  // 30% width for 40-70% range
                        .offset(x: geometry.size.width * 0.4)  // Start at 40%

                    // Current brightness indicator
                    RoundedRectangle(cornerRadius: 8)
                        .fill(quality.color)
                        .frame(width: geometry.size.width * CGFloat(brightness))

                    // Current position marker
                    Circle()
                        .fill(Color.white)
                        .frame(width: Designs.Sizes.indicatorSmallCircle, height: Designs.Sizes.indicatorSmallCircle)
                        .overlay(
                            Circle()
                                .stroke(quality.color, lineWidth: 3)
                        )
                        .offset(x: geometry.size.width * CGFloat(brightness) - 8)
                }
            }
            .frame(height: Designs.Sizes.frameMedium)

            // Scale markers
            HStack {
                Text("0%")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(Designs.Opacity.semiOpaque))
                Spacer()
                Text("25%")
                    .font(.caption2)
                    .foregroundColor(.red.opacity(Designs.Opacity.semiTransparent))
                Spacer()
                Text("40%")
                    .font(.caption2)
                    .foregroundColor(.green)
                Spacer()
                Text("70%")
                    .font(.caption2)
                    .foregroundColor(.green)
                Spacer()
                Text("90%")
                    .font(.caption2)
                    .foregroundColor(.orange.opacity(Designs.Opacity.semiTransparent))
                Spacer()
                Text("100%")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(Designs.Opacity.semiOpaque))
            }
        }
    }
}

/// Camera preview for SwiftUI
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90  // Portrait orientation
        }
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            Task { @MainActor in
                previewLayer.frame = uiView.bounds
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

/// View model for lighting calibration
public class LightingCalibrationViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published public var currentBrightness: Float = 0.5
    @Published public var lightingQuality: UILightingQuality = .optimal

    public let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.ollvy.lightingCalibration")

    // MARK: - Lifecycle

    public override init() {
        super.init()
        setupCamera()
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        captureSession.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            AppLogger.faceScan.warning("⚠️ Front camera not available")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true

            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
        } catch {
            AppLogger.faceScan.error("⚠️ Camera setup failed: \(error)")
        }
    }

    // MARK: - Monitoring

    public func startMonitoring() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    public func stopMonitoring() {
        captureSession.stopRunning()
    }

    // MARK: - Sample Buffer Delegate

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let brightness = calculateBrightness(from: pixelBuffer)

        Task { @MainActor [weak self] in
            self?.currentBrightness = brightness
            self?.lightingQuality = self?.determineLightingQuality(brightness: brightness) ?? .optimal
        }
    }

    // MARK: - Brightness Calculation

    private func calculateBrightness(from pixelBuffer: CVPixelBuffer) -> Float {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return 0.5 }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        // Sample 100 pixels from center region (face area)
        let centerX = width / 2
        let centerY = height / 2
        let sampleRadius = min(width, height) / 6

        var totalBrightness: Float = 0
        var sampleCount = 0

        for y in stride(from: centerY - sampleRadius, to: centerY + sampleRadius, by: sampleRadius / 5) {
            for x in stride(from: centerX - sampleRadius, to: centerX + sampleRadius, by: sampleRadius / 5) {
                guard x >= 0 && x < width && y >= 0 && y < height else { continue }

                let offset = y * bytesPerRow + x * 4
                let ptr = baseAddress.advanced(by: offset).assumingMemoryBound(to: UInt8.self)

                let r = Float(ptr[0])
                let g = Float(ptr[1])
                let b = Float(ptr[2])

                // Luminance (perceived brightness)
                let luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0

                totalBrightness += luminance
                sampleCount += 1
            }
        }

        return sampleCount > 0 ? totalBrightness / Float(sampleCount) : 0.5
    }

    private func determineLightingQuality(brightness: Float) -> UILightingQuality {
        // Skin-tone-aware thresholds
        // Darker skin (Indian, Fitzpatrick IV-VI) naturally has 20-40% luminance in good lighting
        // Light skin has 40-60% luminance in same lighting
        if brightness < 0.15 {  // Was: 0.25 - only block if VERY dark
            return .tooDark  // BLOCK
        } else if brightness < 0.30 {  // Was: 0.40 - more forgiving
            return .suboptimalDark  // WARN
        } else if brightness <= 0.70 {
            return .optimal  // GOOD
        } else if brightness <= 0.90 {
            return .suboptimalBright  // WARN
        } else {
            return .tooBright  // BLOCK
        }
    }
}
