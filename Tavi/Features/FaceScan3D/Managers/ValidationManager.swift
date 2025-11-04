//
//  ValidationManager.swift
//  Tavi
//
//  Manages lighting validation, quality checks, and edge case detection
//  Extracted from FaceScan3DViewModel for better maintainability
//

import Foundation
import ARKit
import Combine
import SwiftUI

/// Manages validation of lighting, face position, and scan quality
@MainActor
public class ValidationManager: ObservableObject {

    // MARK: - Published Properties

    /// Quality warning message
    @Published public var qualityWarning: String?

    /// Current light estimation data
    @Published public var lightEstimation: LightEstimation?

    /// Calibration state for lighting consistency
    @Published public var calibrationState: CalibrationState = CalibrationState()

    // MARK: - Private Properties

    private var previousQualityWarning: String?
    private var baselineLighting: CGFloat?
    private var baselineColorTemperature: CGFloat?

    @AppStorage("lightingStrictness") private var lightingStrictness: String = "Strict"
    @AppStorage("detectGlasses") private var detectGlasses: Bool = true
    @AppStorage("detectHands") private var detectHands: Bool = true
    @AppStorage("detectHat") private var detectHat: Bool = true
    @AppStorage("detectMakeup") private var detectMakeup: Bool = true

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Validates lighting conditions from ARFrame
    public func validateLighting(from frame: ARFrame) -> Bool {
        guard let lightEstimate = frame.lightEstimate else {
            qualityWarning = "Unable to estimate lighting"
            return false
        }

        // Extract lighting values
        let intensity = lightEstimate.ambientIntensity
        let colorTemp = lightEstimate.ambientColorTemperature

        // Update light estimation
        self.lightEstimation = LightEstimation(
            ambientIntensity: intensity,
            colorTemperature: colorTemp
        )

        // Check lighting strictness
        let isValid = checkLightingStrictness(intensity: intensity, colorTemp: colorTemp)

        if !isValid {
            updateQualityWarning(for: intensity)
        } else {
            clearQualityWarning()
        }

        return isValid
    }

    /// Validates face position and orientation (5 poses)
    public func validateFacePosition(transform: simd_float4x4, targetStep: GuidanceStep) -> Bool {
        let angles = extractEulerAngles(from: transform)

        let pitchDegrees = angles.pitch * 180 / .pi
        let yawDegrees = angles.yaw * 180 / .pi

        switch targetStep {
        case .lookStraight:
            return abs(pitchDegrees) < 10 && abs(yawDegrees) < 10

        case .lookUp:
            return pitchDegrees > 10 && pitchDegrees < 22 && abs(yawDegrees) < 10

        case .lookDown:
            return pitchDegrees < -10 && pitchDegrees > -25 && abs(yawDegrees) < 10

        case .turnLeft:
            return yawDegrees > 20 && yawDegrees < 45 && abs(pitchDegrees) < 10

        case .turnRight:
            return yawDegrees < -20 && yawDegrees > -45 && abs(pitchDegrees) < 10
        }
    }

    /// Detects edge cases (glasses, hands, hat, etc.)
    public func detectEdgeCases(from blendShapes: [ARFaceAnchor.BlendShapeLocation: NSNumber]?) -> [String] {
        var warnings: [String] = []

        guard let shapes = blendShapes else {
            return warnings
        }

        // Detect glasses (if enabled)
        if detectGlasses {
            // Check for unnatural eye behavior patterns
            if let eyeBlinkLeft = shapes[.eyeBlinkLeft]?.floatValue,
               let eyeBlinkRight = shapes[.eyeBlinkRight]?.floatValue {
                if eyeBlinkLeft < 0.1 && eyeBlinkRight < 0.1 {
                    // Eyes suspiciously static - possible glasses
                    warnings.append("Glasses detected - may affect accuracy")
                }
            }
        }

        // Detect hands on face (if enabled)
        if detectHands {
            // Check for cheek puff and jaw movements that might indicate hands
            if let cheekPuff = shapes[.cheekPuff]?.floatValue,
               let jawOpen = shapes[.jawOpen]?.floatValue {
                if cheekPuff > 0.5 || jawOpen > 0.6 {
                    warnings.append("Hands near face detected")
                }
            }
        }

        // Detect heavy makeup (if enabled)
        if detectMakeup {
            // This would require texture analysis - placeholder for now
            // Could analyze color distribution and specular highlights
        }

        return warnings
    }

    /// Sets baseline lighting for consistency checks
    public func setBaselineLighting(intensity: CGFloat, colorTemp: CGFloat) {
        baselineLighting = intensity
        baselineColorTemperature = colorTemp
        calibrationState.isCalibrated = true
    }

    /// Checks if lighting is consistent with baseline
    public func checkLightingConsistency(intensity: CGFloat, colorTemp: CGFloat) -> Bool {
        guard let baseline = baselineLighting,
              let baselineTemp = baselineColorTemperature else {
            return true // No baseline set yet
        }

        let intensityDiff = abs(intensity - baseline) / baseline
        let tempDiff = abs(colorTemp - baselineTemp) / baselineTemp

        // Allow 20% variance
        return intensityDiff < 0.2 && tempDiff < 0.2
    }

    /// Resets validation state
    public func reset() {
        qualityWarning = nil
        previousQualityWarning = nil
        baselineLighting = nil
        baselineColorTemperature = nil
        calibrationState = CalibrationState()
        lightEstimation = nil
    }

    // MARK: - Private Methods

    private func checkLightingStrictness(intensity: CGFloat, colorTemp: CGFloat) -> Bool {
        switch lightingStrictness {
        case "Strict":
            // Require optimal lighting (40-70% intensity, natural color temp)
            return intensity >= 400 && intensity <= 700 &&
                   colorTemp >= 4000 && colorTemp <= 7000

        case "Relaxed":
            // Allow wider range (25-85% intensity)
            return intensity >= 250 && intensity <= 850

        case "Off":
            // No validation
            return true

        default:
            return true
        }
    }

    private func updateQualityWarning(for intensity: CGFloat) {
        let warning: String

        if intensity < 400 {
            warning = "⚠️ Low light - move to brighter area"
        } else if intensity > 700 {
            warning = "⚠️ Too bright - reduce lighting"
        } else {
            warning = "⚠️ Lighting quality issues detected"
        }

        if warning != previousQualityWarning {
            qualityWarning = warning
            previousQualityWarning = warning
            HapticManager.shared.warning()
        }
    }

    private func clearQualityWarning() {
        if qualityWarning != nil {
            qualityWarning = nil
            previousQualityWarning = nil
        }
    }

    private func extractEulerAngles(from transform: simd_float4x4) -> (pitch: Float, yaw: Float, roll: Float) {
        let pitch = asin(-transform.columns.2.y)
        let yaw = atan2(transform.columns.2.x, transform.columns.2.z)
        let roll = atan2(transform.columns.0.y, transform.columns.1.y)

        return (pitch, yaw, roll)
    }
}

// MARK: - Supporting Types

public struct LightEstimation {
    public let ambientIntensity: CGFloat
    public let colorTemperature: CGFloat
}

public struct CalibrationState {
    public var isCalibrated: Bool = false
    public var calibrationTimestamp: Date?
    public var calibrationQuality: Double = 0
}
