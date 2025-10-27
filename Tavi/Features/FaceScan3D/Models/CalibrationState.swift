//
//  CalibrationState.swift
//  Tavi
//
//  Calibration state for 3D face scanning
//  Created on 2025-10-27.
//

import Foundation
import ARKit

/// Lighting condition states
public enum LightingCondition: String {
    case tooDark = "tooDark"
    case tooBright = "tooBright"
    case good = "good"

    var message: String {
        switch self {
        case .tooDark:
            return "Please find better lighting"
        case .tooBright:
            return "Lighting is too bright"
        case .good:
            return "Lighting is good"
        }
    }

    var isValid: Bool {
        return self == .good
    }
}

/// Distance condition states
public enum DistanceCondition: String {
    case tooClose = "tooClose"
    case tooFar = "tooFar"
    case good = "good"

    var message: String {
        switch self {
        case .tooClose:
            return "Please move back a bit"
        case .tooFar:
            return "Please move closer"
        case .good:
            return "Distance is perfect"
        }
    }

    var isValid: Bool {
        return self == .good
    }
}

/// Face stability state
public enum StabilityCondition {
    case moving
    case stable

    var message: String {
        switch self {
        case .moving:
            return "Please hold still"
        case .stable:
            return "Holding steady"
        }
    }

    var isValid: Bool {
        return self == .stable
    }
}

/// Guidance steps for capture
public enum GuidanceStep: Int, CaseIterable {
    case lookStraight = 0
    case turnLeft
    case turnRight
    case lookUp
    case lookDown

    var instruction: String {
        switch self {
        case .lookStraight:
            return "Please look straight at the camera"
        case .turnLeft:
            return "Turn your head slightly to the left"
        case .turnRight:
            return "Turn your head slightly to the right"
        case .lookUp:
            return "Tilt your head up a bit"
        case .lookDown:
            return "Tilt your head down a bit"
        }
    }

    var shortName: String {
        switch self {
        case .lookStraight:
            return "Center"
        case .turnLeft:
            return "Left"
        case .turnRight:
            return "Right"
        case .lookUp:
            return "Up"
        case .lookDown:
            return "Down"
        }
    }

    /// Check if the current face pose matches this step
    /// STRICT validation for high-quality 3D reconstruction
    func isPoseValid(yaw: Float, pitch: Float, roll: Float) -> Bool {
        switch self {
        case .lookStraight:
            // Face must be truly parallel to camera (STRICT for accuracy)
            return abs(yaw) < 5 && abs(pitch) < 5 && abs(roll) < 8

        case .turnLeft:
            // Face should be turned left (positive yaw)
            // Must be in range but also not tilted up/down too much
            return yaw > 15 && yaw < 35 && abs(pitch) < 12 && abs(roll) < 10

        case .turnRight:
            // Face should be turned right (negative yaw)
            return yaw < -15 && yaw > -35 && abs(pitch) < 12 && abs(roll) < 10

        case .lookUp:
            // Face should be tilted up (positive pitch - head tilts back)
            // Not too much rotation left/right while tilted up
            return pitch > 10 && pitch < 25 && abs(yaw) < 12 && abs(roll) < 10

        case .lookDown:
            // Face should be tilted down (negative pitch - head tilts forward)
            return pitch < -10 && pitch > -25 && abs(yaw) < 12 && abs(roll) < 10
        }
    }

    /// Get real-time guidance feedback when user is close to target pose
    func getGuidanceFeedback(yaw: Float, pitch: Float, roll: Float) -> String? {
        // If already valid, no feedback needed
        if isPoseValid(yaw: yaw, pitch: pitch, roll: roll) {
            return nil
        }

        switch self {
        case .lookStraight:
            // Guide user to truly parallel position (strict)
            if abs(yaw) > 8 {
                return yaw > 0 ? "Turn more to the right to face camera directly" : "Turn more to the left to face camera directly"
            }
            if abs(yaw) > 5 {
                return yaw > 0 ? "Almost straight, turn a bit more right" : "Almost straight, turn a bit more left"
            }
            if abs(pitch) > 8 {
                return pitch > 0 ? "Tilt your head up to face camera directly" : "Tilt your head down to face camera directly"
            }
            if abs(pitch) > 5 {
                return pitch > 0 ? "Almost level, tilt up just a bit" : "Almost level, tilt down just a bit"
            }
            if abs(roll) > 8 {
                return "Level your head - it's tilted to the side"
            }
            return "Almost perfectly straight, hold steady"

        case .turnLeft:
            // Need yaw > 15
            if yaw < 10 {
                return "Turn more to the left"
            } else if yaw < 15 {
                return "Almost there, turn a bit more left"
            } else if yaw > 35 {
                return "Too far, turn back slightly to the right"
            } else if abs(pitch) > 15 {
                return pitch > 0 ? "Good angle, now level your head" : "Good angle, now level your head"
            }
            return "Almost there, hold that position"

        case .turnRight:
            // Need yaw < -15
            if yaw > -10 {
                return "Turn more to the right"
            } else if yaw > -15 {
                return "Almost there, turn a bit more right"
            } else if yaw < -35 {
                return "Too far, turn back slightly to the left"
            } else if abs(pitch) > 15 {
                return pitch > 0 ? "Good angle, now level your head" : "Good angle, now level your head"
            }
            return "Almost there, hold that position"

        case .lookUp:
            // Need pitch > 10
            if pitch < 5 {
                return "Tilt your head up more"
            } else if pitch < 10 {
                return "Almost there, tilt up just a bit more"
            } else if pitch > 25 {
                return "Too far, tilt down slightly"
            } else if abs(yaw) > 15 {
                return yaw > 0 ? "Good angle, now straighten your head" : "Good angle, now straighten your head"
            }
            return "Almost there, hold that position"

        case .lookDown:
            // Need pitch < -10
            if pitch > -5 {
                return "Tilt your head down more"
            } else if pitch > -10 {
                return "Almost there, tilt down just a bit more"
            } else if pitch < -25 {
                return "Too far, tilt up slightly"
            } else if abs(yaw) > 15 {
                return yaw > 0 ? "Good angle, now straighten your head" : "Good angle, now straighten your head"
            }
            return "Almost there, hold that position"
        }
    }
}

/// Overall calibration state
public struct CalibrationState {
    public var lighting: LightingCondition = .tooDark
    public var distance: DistanceCondition = .tooFar
    public var stability: StabilityCondition = .moving
    public var faceDetected: Bool = false

    /// Check if basic calibration is valid (ready to start guidance)
    public var isCalibrated: Bool {
        return faceDetected &&
               lighting.isValid &&
               distance.isValid &&
               stability.isValid
    }

    /// Get the primary issue message
    public var primaryMessage: String? {
        if !faceDetected {
            return "Please position your face in the frame"
        }

        if !lighting.isValid {
            return lighting.message
        }

        if !distance.isValid {
            return distance.message
        }

        if !stability.isValid {
            return stability.message
        }

        return nil
    }

    /// Update lighting from ARKit light estimate
    public mutating func updateLighting(from lightEstimate: LightEstimation?) {
        guard let light = lightEstimate else {
            lighting = .tooDark
            return
        }

        // Typical good lighting: 500-2000 lux
        // ARKit ambientIntensity is in lumens
        let intensity = light.ambientIntensity

        if intensity < 300 {
            lighting = .tooDark
        } else if intensity > 2500 {
            lighting = .tooBright
        } else {
            lighting = .good
        }
    }

    /// Update distance from face anchor transform
    public mutating func updateDistance(from transform: simd_float4x4) {
        // Extract Z distance from camera (negative Z in ARKit camera space)
        let distance = abs(transform.columns.3.z)

        // Optimal distance: 30-60cm for face scanning
        if distance < 0.25 {
            self.distance = .tooClose
        } else if distance > 0.70 {
            self.distance = .tooFar
        } else {
            self.distance = .good
        }
    }

    /// Update stability by comparing transforms over time
    public mutating func updateStability(movement: Float) {
        // Movement threshold in meters
        let stabilityThreshold: Float = 0.01

        if movement < stabilityThreshold {
            stability = .stable
        } else {
            stability = .moving
        }
    }
}

/// Captured pose data for a guidance step
public struct CapturedPoseData {
    public let step: GuidanceStep
    public let geometry: FaceMeshGeometry
    public let timestamp: TimeInterval
    public let yaw: Float
    public let pitch: Float
    public let roll: Float

    public init(step: GuidanceStep, geometry: FaceMeshGeometry, yaw: Float, pitch: Float, roll: Float) {
        self.step = step
        self.geometry = geometry
        self.timestamp = Date().timeIntervalSince1970
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
    }
}
