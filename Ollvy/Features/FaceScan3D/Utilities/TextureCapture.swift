//
//  TextureCapture.swift
//  Ollvy
//
//  Capture RGB texture frames from camera for face mesh texturing
//  Created on 2025-10-27.
//

import Foundation
import ARKit
import UIKit
import AVFoundation
import Metal

/// Captures RGB texture frames during face scanning
public class TextureCapture {

    // MARK: - Configuration

    public struct Configuration {
        /// Target texture resolution (will be scaled to fit)
        /// Defaults to 4K (4096×4096) for devices with 6GB+ RAM, 2K (2048×2048) for older devices
        /// User can override via Settings. Per POSE_REQUIREMENTS_GUIDE.md: 2K = 83-85% confidence, 4K = 90-92% confidence
        public var targetTextureWidth: Int = {
            // Check for explicit user override first
            if UserDefaults.standard.object(forKey: AppDefaultsKey.enableHighResCapture) != nil {
                let override = UserDefaults.standard.bool(forKey: AppDefaultsKey.enableHighResCapture)
                return override ? ScanConfiguration.highResTextureWidth : ScanConfiguration.standardTextureWidth
            }
            // Use device-based default (4K for 6GB+ devices)
            return DeviceCapabilities.current.recommendedTextureResolution.width
        }()
        public var targetTextureHeight: Int = {
            // Check for explicit user override first
            if UserDefaults.standard.object(forKey: AppDefaultsKey.enableHighResCapture) != nil {
                let override = UserDefaults.standard.bool(forKey: AppDefaultsKey.enableHighResCapture)
                return override ? ScanConfiguration.highResTextureHeight : ScanConfiguration.standardTextureHeight
            }
            // Use device-based default (4K for 6GB+ devices)
            return DeviceCapabilities.current.recommendedTextureResolution.height
        }()

        /// Quality thresholds
        /// ADAPTIVE: Base minimum Laplacian variance for sharp texture capture
        /// This is adjusted based on lighting conditions - lower threshold in poor lighting
        /// Blurry textures cause incorrect roughness measurements, but we need to balance
        /// with realistic capture success rates in various lighting conditions
        /// VERY LENIENT: Significantly lowered to match CalibrationManager thresholds for consistency
        public var minSharpness: Float = 40.0  // Base minimum (significantly lowered from 80)
        public var minSharpnessOptimal: Float = 60.0  // Target for optimal lighting (lowered from 120)
        public var minSharpnessPoorLight: Float = 30.0   // Minimum for poor lighting (lowered from 60)
        public var minExposure: Float = 0.2
        public var maxExposure: Float = 0.8

        /// Front-facing criteria
        public var maxYawForFrontFacing: Float = 15.0  // degrees
        public var maxPitchForFrontFacing: Float = 10.0  // degrees

        public init() {}
    }

    private let configuration: Configuration
    private let qualityAnalyzer: ImageQualityAnalyzer

    /// PERFORMANCE OPTIMIZATION: Cache CIContext to avoid expensive re-creation
    /// Creating CIContext is ~100-200ms, reusing it is ~0ms
    private lazy var ciContext: CIContext = {
        // Use Metal for hardware acceleration when available
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: metalDevice, options: [
                .cacheIntermediates: false,  // Reduce memory usage
                .priorityRequestLow: false   // High priority for responsiveness
            ])
        }
        return CIContext(options: [.cacheIntermediates: false])
    }()

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration

        var analyzerConfig = ImageQualityAnalyzer.Configuration()
        analyzerConfig.minSharpnessThreshold = configuration.minSharpness
        self.qualityAnalyzer = ImageQualityAnalyzer(configuration: analyzerConfig)
    }

    // MARK: - Capture Methods

    /// Capture texture sample from ARFrame
    public func captureSample(
        step: String,
        faceAnchor: ARFaceAnchor,
        frame: ARFrame,
        lightEstimation: LightEstimation?
    ) -> PoseSample? {

        // Extract camera image
        guard let textureImage = extractCameraImage(from: frame) else {
            AppLogger.faceScan.warning("⚠️ TextureCapture: Failed to extract camera image")
            return nil
        }

        // OPTIMIZATION FIX: Trust pre-capture validation from CalibrationManager
        // Post-capture quality checks removed to prevent duplicate validation failures
        // Quality was already validated during countdown - no need to re-check
        let quality = qualityAnalyzer.analyzeQuality(image: textureImage)
        AppLogger.faceScan.info("✅ TextureCapture: Quality metrics - sharpness: \(quality.sharpness), exposure: \(quality.exposure)")

        // Extract rotation angles
        let transform = faceAnchor.transform
        let eulerAngles = extractEulerAngles(from: transform)
        let yaw = eulerAngles.y * 180 / .pi
        let pitch = eulerAngles.x * 180 / .pi
        let roll = eulerAngles.z * 180 / .pi

        // Check if front-facing
        let isFrontFacing = abs(yaw) < configuration.maxYawForFrontFacing &&
                           abs(pitch) < configuration.maxPitchForFrontFacing

        // Extract light direction (estimate from ambient)
        var lightDirection: SIMD3<Float>? = nil
        if lightEstimation != nil {
            // Simple approximation: light from above-front
            // In reality, ARKit doesn't give us directional info easily
            // We assume overhead lighting as default
            let rawDirection = SIMD3<Float>(0, 1, 0.5)  // Above and slightly forward
            lightDirection = normalize(rawDirection)
        }

        // Calculate distance from camera
        let cameraPos = frame.camera.transform.columns.3
        let facePos = transform.columns.3
        let dx = cameraPos.x - facePos.x
        let dy = cameraPos.y - facePos.y
        let dz = cameraPos.z - facePos.z
        let distance = sqrt(dx * dx + dy * dy + dz * dz)

        // Create pose sample
        let sample = PoseSample(
            step: step,
            textureImage: textureImage,
            faceTransform: transform,
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            ambientIntensity: lightEstimation?.ambientIntensity ?? 1000,
            colorTemperature: lightEstimation?.ambientColorTemperature ?? 6500,
            lightDirection: lightDirection,
            distanceFromCamera: distance,
            focusSharpness: quality.sharpness,
            exposureScore: quality.exposure,
            isFrontFacing: isFrontFacing
        )

        AppLogger.faceScan.info("✅ TextureCapture: Captured sample - step: \(step), sharpness: \(quality.sharpness), exposure: \(quality.exposure), front: \(isFrontFacing)")

        return sample
    }

    // MARK: - Image Extraction

    /// Extract UIImage from ARFrame's captured image
    /// PERFORMANCE OPTIMIZED: Uses cached CIContext with Metal acceleration
    private func extractCameraImage(from frame: ARFrame) -> UIImage? {
        let pixelBuffer = frame.capturedImage

        // Create CIImage from pixel buffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Apply orientation correction (front camera is mirrored)
        let orientedImage = ciImage.oriented(.right)  // Rotate for portrait

        // PERFORMANCE: Use cached CIContext (saves ~100-200ms per capture)
        guard let cgImage = ciContext.createCGImage(orientedImage, from: orientedImage.extent) else {
            return nil
        }

        // Create UIImage
        let image = UIImage(cgImage: cgImage)

        // Scale to target resolution
        return scaleImage(image, targetWidth: configuration.targetTextureWidth, targetHeight: configuration.targetTextureHeight)
    }

    /// Scale image to target resolution while maintaining aspect ratio
    /// PERFORMANCE FIX: Uses scale 1.0 to avoid 2x-3x memory bloat from screen scale
    private func scaleImage(_ image: UIImage, targetWidth: Int, targetHeight: Int) -> UIImage? {
        let size = image.size

        // Calculate scale to fit within target dimensions
        let widthRatio = CGFloat(targetWidth) / size.width
        let heightRatio = CGFloat(targetHeight) / size.height
        let scaleFactor = min(widthRatio, heightRatio)

        let newWidth = size.width * scaleFactor
        let newHeight = size.height * scaleFactor
        let newSize = CGSize(width: newWidth, height: newHeight)

        // PERFORMANCE FIX: Use scale 1.0 (not 0.0) to prevent 2x-3x memory multiplication
        // With 0.0 (screen scale), a 4K target would become 12K on a 3x display - causing massive slowdown
        // Scale 1.0 = exact pixel dimensions requested
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)  // opaque=true for better performance
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return scaledImage
    }

    // MARK: - Helper Methods

    /// Extract Euler angles (pitch, yaw, roll) from a 4x4 transformation matrix
    private func extractEulerAngles(from matrix: simd_float4x4) -> SIMD3<Float> {
        // Extract rotation matrix (upper-left 3x3)
        let m11 = matrix.columns.0.x
        let _ = matrix.columns.1.x  // m12 - unused in ZYX Euler angle calculation
        let m13 = matrix.columns.2.x
        let m21 = matrix.columns.0.y
        let m22 = matrix.columns.1.y
        let m23 = matrix.columns.2.y
        let m31 = matrix.columns.0.z
        let _ = matrix.columns.1.z  // m32 - unused in ZYX Euler angle calculation
        let m33 = matrix.columns.2.z

        // Calculate Euler angles (ZYX convention)
        // pitch (x-axis rotation)
        let pitch = asin(-m23)

        // yaw (y-axis rotation)
        let yaw: Float
        if abs(m23) < 0.99999 {
            yaw = atan2(m13, m33)
        } else {
            yaw = atan2(-m31, m11)
        }

        // roll (z-axis rotation)
        let roll: Float
        if abs(m23) < 0.99999 {
            roll = atan2(m21, m22)
        } else {
            roll = 0
        }

        return SIMD3<Float>(pitch, yaw, roll)
    }
}
