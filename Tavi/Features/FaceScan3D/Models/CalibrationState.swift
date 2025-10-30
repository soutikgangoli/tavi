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
    case tiltLeft
    case tiltRight

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
        case .tiltLeft:
            return "Tilt head left - ear toward shoulder (don't turn, just tilt)"
        case .tiltRight:
            return "Tilt head right - ear toward shoulder (don't turn, just tilt)"
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
        case .tiltLeft:
            return "Tilt Left"
        case .tiltRight:
            return "Tilt Right"
        }
    }

    /// Check if the current face pose matches this step
    /// BALANCED validation - achievable but still accurate for 3D reconstruction
    func isPoseValid(yaw: Float, pitch: Float, roll: Float) -> Bool {
        switch self {
        case .lookStraight:
            // Face looking at camera - BALANCED
            // Primary: yaw must be centered (most important for front view)
            // Secondary: pitch has more tolerance (phone angle varies)
            // Tertiary: roll should be level
            return abs(yaw) < 12 && abs(pitch) < 15 && abs(roll) < 12

        case .turnLeft:
            // Face turned left - BALANCED
            // Primary: yaw must be in left range (15-38° is good coverage)
            // Secondary: pitch/roll have tolerance for natural movement
            return yaw > 13 && yaw < 38 && abs(pitch) < 15 && abs(roll) < 15

        case .turnRight:
            // Face turned right - BALANCED
            // Primary: yaw must be in right range
            return yaw < -13 && yaw > -38 && abs(pitch) < 15 && abs(roll) < 15

        case .lookUp:
            // Face tilted up - BALANCED
            // Primary: pitch must be upward (10-25° is comfortable and useful)
            // Secondary: yaw/roll have tolerance
            return pitch > 10 && pitch < 25 && abs(yaw) < 15 && abs(roll) < 12

        case .lookDown:
            // Face tilted down - STRICTER
            // Primary: pitch must be downward (-12° to -25° for clear downward tilt)
            // Secondary: must be facing forward (tighter yaw/roll tolerance)
            return pitch < -12 && pitch > -25 && abs(yaw) < 10 && abs(roll) < 10

        case .tiltLeft:
            // Head tilted left (ear toward shoulder) - BALANCED
            // FIXED: ARKit roll is inverted - negative roll = tilt left
            // Primary: roll must be negative (left tilt) in range -10 to -28°
            // Secondary: yaw/pitch have MORE tolerance (people naturally turn when tilting)
            return roll < -10 && roll > -28 && abs(yaw) < 20 && abs(pitch) < 15

        case .tiltRight:
            // Head tilted right (ear toward shoulder) - BALANCED
            // FIXED: ARKit roll is inverted - positive roll = tilt right
            // Primary: roll must be positive (right tilt) in range 10 to 28°
            // Secondary: yaw/pitch have MORE tolerance
            return roll > 10 && roll < 28 && abs(yaw) < 20 && abs(pitch) < 15
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
            // Guide user to center position - balanced guidance
            if abs(yaw) > 15 {
                return yaw > 0 ? "Turn more to the right" : "Turn more to the left"
            }
            if abs(yaw) > 12 {
                return yaw > 0 ? "Almost straight, turn slightly right" : "Almost straight, turn slightly left"
            }
            if abs(pitch) > 18 {
                return pitch > 0 ? "Tilt head down to face camera" : "Tilt head up to face camera"
            }
            if abs(pitch) > 15 {
                return pitch > 0 ? "Almost there, slightly down" : "Almost there, slightly up"
            }
            if abs(roll) > 12 {
                return "Level your head (tilted to side)"
            }
            return "Hold steady"

        case .turnLeft:
            // Need yaw > 13 (turn left = positive yaw)
            // Check if user turned the WRONG direction (right instead of left)
            if yaw < -5 {
                return "Wrong direction - turn your head to the LEFT"
            } else if yaw < 8 {
                return "Turn more to the left"
            } else if yaw < 13 {
                return "Almost there, turn a bit more left"
            } else if yaw > 38 {
                return "Too far, turn back slightly to the right"
            } else if yaw > 35 {
                return "Almost too far, ease back a bit"
            } else if abs(pitch) > 15 {
                return pitch > 0 ? "Good angle, now level your head" : "Good angle, now level your head"
            }
            return "Almost there, hold that position"

        case .turnRight:
            // Need yaw < -13 (turn right = negative yaw)
            // Check if user turned the WRONG direction (left instead of right)
            if yaw > 5 {
                return "Wrong direction - turn your head to the RIGHT"
            } else if yaw > -8 {
                return "Turn more to the right"
            } else if yaw > -13 {
                return "Almost there, turn a bit more right"
            } else if yaw < -38 {
                return "Too far, turn back slightly to the left"
            } else if yaw < -35 {
                return "Almost too far, ease back a bit"
            } else if abs(pitch) > 15 {
                return pitch > 0 ? "Good angle, now level your head" : "Good angle, now level your head"
            }
            return "Almost there, hold that position"

        case .lookUp:
            // Need pitch > 10 (balanced guidance)
            if pitch < 5 {
                return "Tilt your head up more"
            } else if pitch < 10 {
                return "Almost there, tilt up just a bit more"
            } else if pitch > 25 {
                return "Too far, tilt down slightly"
            } else if pitch > 23 {
                return "Almost too far, ease down a bit"
            } else if abs(yaw) > 15 {
                return yaw > 0 ? "Good angle, now straighten your head" : "Good angle, now straighten your head"
            }
            return "Almost there, hold that position"

        case .lookDown:
            // Need pitch < -12 (stricter guidance)
            if pitch > -8 {
                return "Tilt your head down more"
            } else if pitch > -12 {
                return "Almost there, tilt down just a bit more"
            } else if pitch < -25 {
                return "Too far, tilt up slightly"
            } else if pitch < -23 {
                return "Almost too far, ease up a bit"
            } else if abs(yaw) > 10 {
                return yaw > 0 ? "Good angle, but face more forward" : "Good angle, but face more forward"
            }
            return "Almost there, hold that position"

        case .tiltLeft:
            // Need roll < -10 (FIXED: negative = tilt left)
            if roll > -5 {
                return "Tilt your head sideways to the left - ear toward shoulder"
            } else if roll > -10 {
                return "Almost there, tilt a bit more to the left"
            } else if roll < -28 {
                return "Too much tilt, bring your head back a bit"
            } else if roll < -26 {
                return "Almost too much, ease back a bit"
            } else if abs(yaw) > 20 {
                return yaw > 0 ? "Good tilt, but straighten your face toward camera" : "Good tilt, but straighten your face toward camera"
            } else if abs(pitch) > 15 {
                return pitch > 0 ? "Good tilt, but keep your head level" : "Good tilt, but keep your head level"
            }
            return "Almost there, hold that position"

        case .tiltRight:
            // Need roll > 10 (FIXED: positive = tilt right)
            if roll < 5 {
                return "Tilt your head sideways to the right - ear toward shoulder"
            } else if roll < 10 {
                return "Almost there, tilt a bit more to the right"
            } else if roll > 28 {
                return "Too much tilt, bring your head back a bit"
            } else if roll > 26 {
                return "Almost too much, ease back a bit"
            } else if abs(yaw) > 20 {
                return yaw > 0 ? "Good tilt, but straighten your face toward camera" : "Good tilt, but straighten your face toward camera"
            } else if abs(pitch) > 15 {
                return pitch > 0 ? "Good tilt, but keep your head level" : "Good tilt, but keep your head level"
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
