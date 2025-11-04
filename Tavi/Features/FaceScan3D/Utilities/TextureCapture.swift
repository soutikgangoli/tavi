//
//  TextureCapture.swift
//  Tavi
//
//  Capture RGB texture frames from camera for face mesh texturing
//  Created on 2025-10-27.
//

import Foundation
import ARKit
import UIKit
import AVFoundation

/// Captures RGB texture frames during face scanning
public class TextureCapture {

    // MARK: - Configuration

    public struct Configuration {
        /// Target texture resolution (will be scaled to fit)
        public var targetTextureWidth: Int = 1024
        public var targetTextureHeight: Int = 1024

        /// Quality thresholds
        public var minSharpness: Float = 100.0
        public var minExposure: Float = 0.2
        public var maxExposure: Float = 0.8

        /// Front-facing criteria
        public var maxYawForFrontFacing: Float = 15.0  // degrees
        public var maxPitchForFrontFacing: Float = 10.0  // degrees

        public init() {}
    }

    private let configuration: Configuration
    private let qualityAnalyzer: ImageQualityAnalyzer

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
            print("⚠️ TextureCapture: Failed to extract camera image")
            return nil
        }

        // Calculate quality metrics
        let quality = qualityAnalyzer.analyzeQuality(image: textureImage)

        // Check quality thresholds
        guard quality.overallQuality else {
            print("⚠️ TextureCapture: Quality check failed - sharpness: \(quality.sharpness), exposure: \(quality.exposure)")
            return nil
        }

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
            lightDirection = SIMD3<Float>(0, 1, 0.5)  // Above and slightly forward
            lightDirection = normalize(lightDirection!)
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

        print("✅ TextureCapture: Captured sample - step: \(step), sharpness: \(quality.sharpness), exposure: \(quality.exposure), front: \(isFrontFacing)")

        return sample
    }

    // MARK: - Image Extraction

    /// Extract UIImage from ARFrame's captured image
    private func extractCameraImage(from frame: ARFrame) -> UIImage? {
        let pixelBuffer = frame.capturedImage

        // Create CIImage from pixel buffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Apply orientation correction (front camera is mirrored)
        let orientedImage = ciImage.oriented(.right)  // Rotate for portrait

        // Create CGImage
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(orientedImage, from: orientedImage.extent) else {
            return nil
        }

        // Create UIImage
        let image = UIImage(cgImage: cgImage)

        // Scale to target resolution
        return scaleImage(image, targetWidth: configuration.targetTextureWidth, targetHeight: configuration.targetTextureHeight)
    }

    /// Scale image to target resolution while maintaining aspect ratio
    private func scaleImage(_ image: UIImage, targetWidth: Int, targetHeight: Int) -> UIImage? {
        let size = image.size

        // Calculate scale to fit within target dimensions
        let widthRatio = CGFloat(targetWidth) / size.width
        let heightRatio = CGFloat(targetHeight) / size.height
        let scale = min(widthRatio, heightRatio)

        let newWidth = size.width * scale
        let newHeight = size.height * scale
        let newSize = CGSize(width: newWidth, height: newHeight)

        // Render scaled image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
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
        let m12 = matrix.columns.1.x
        let m13 = matrix.columns.2.x
        let m21 = matrix.columns.0.y
        let m22 = matrix.columns.1.y
        let m23 = matrix.columns.2.y
        let m31 = matrix.columns.0.z
        let m32 = matrix.columns.1.z
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
