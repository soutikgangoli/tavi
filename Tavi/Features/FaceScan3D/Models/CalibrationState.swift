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
    case poor = "poor"          // Quality issues (shadows, color cast, etc.)
    case acceptable = "acceptable"  // Passable but not optimal
    case good = "good"

    var message: String {
        switch self {
        case .tooDark:
            return "Too dark - find brighter lighting"
        case .tooBright:
            return "Too bright - reduce lighting"
        case .poor:
            return "Lighting quality issues detected"
        case .acceptable:
            return "Lighting acceptable - could be better"
        case .good:
            return "Lighting is good"
        }
    }

    var isValid: Bool {
        // Only accept "good" - block poor, tooDark, tooBright
        // "acceptable" is allowed but not ideal
        return self == .good || self == .acceptable
    }

    var isOptimal: Bool {
        return self == .good
    }
}

/// Distance condition states
public enum DistanceCondition: String {
    case tooClose = "tooClose"
    case tooFar = "tooFar"
    case acceptable = "acceptable"  // Works but not optimal
    case good = "good"              // Optimal quality range

    var message: String {
        switch self {
        case .tooClose:
            return "Please move back a bit"
        case .tooFar:
            return "Too far - move closer for skin detail"
        case .acceptable:
            return "Move closer for best skin analysis quality"
        case .good:
            return "Distance is perfect"
        }
    }

    var isValid: Bool {
        // UX FIX: Accept both "good" (30-50cm) and "acceptable" (25-30cm, 50-60cm)
        // This gives users more flexibility while still maintaining quality
        // Only reject "tooClose" (<25cm) and "tooFar" (>60cm)
        return self == .good || self == .acceptable
    }

    var isOptimal: Bool {
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
            return "Keep your head steady to start countdown"
        case .stable:
            return "Holding steady"
        }
    }

    var isValid: Bool {
        return self == .stable
    }
}

/// Center position indicator (for UI display)
public enum CenterPosition: String {
    case center = "center"
    case slightlyLeft = "slightlyLeft"
    case slightlyRight = "slightlyRight"
    case farLeft = "farLeft"
    case farRight = "farRight"

    public var displayText: String {
        switch self {
        case .center:
            return "Center"
        case .slightlyLeft:
            return "Slightly Left"
        case .slightlyRight:
            return "Slightly Right"
        case .farLeft:
            return "Turn Right"
        case .farRight:
            return "Turn Left"
        }
    }

    /// Determine center position from yaw angle (in degrees)
    public static func from(yaw: Float) -> CenterPosition {
        let absYaw = abs(yaw)

        if absYaw <= ScanConfiguration.maxCenterYawDegrees {
            return .center
        } else if absYaw <= ScanConfiguration.slightTurnYawDegrees {
            // Slightly off center
            return yaw > 0 ? .slightlyLeft : .slightlyRight
        } else {
            // Far from center - tell user which way to turn
            return yaw > 0 ? .farLeft : .farRight
        }
    }
}

/// Guidance steps for capture (5 poses)
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
    /// STRICT validation using ScanConfiguration constants (matches documentation)
    func isPoseValid(yaw: Float, pitch: Float, roll: Float) -> Bool {
        // DEBUG: Log pose validation to understand why Direction indicator stays red
        print("📐 isPoseValid(\(self.shortName)): yaw=\(String(format: "%.1f", yaw))° pitch=\(String(format: "%.1f", pitch))° roll=\(String(format: "%.1f", roll))°")

        switch self {
        case .lookStraight:
            // STRICT: ±5° for yaw and pitch, ±8° for roll (per documentation)
            // This ensures accurate center position detection
            let valid = abs(yaw) <= ScanConfiguration.maxCenterYawDegrees &&
                        abs(pitch) <= ScanConfiguration.maxCenterPitchDegrees &&
                        abs(roll) <= ScanConfiguration.maxCenterRollDegrees
            print("   → lookStraight: \(valid ? "✅ VALID" : "❌ INVALID") (yaw ≤\(ScanConfiguration.maxCenterYawDegrees)°, pitch ≤\(ScanConfiguration.maxCenterPitchDegrees)°, roll ≤\(ScanConfiguration.maxCenterRollDegrees)°)")
            return valid

        case .turnLeft:
            // yaw must be in left range (15-35°)
            return yaw >= ScanConfiguration.minTurnLeftYawDegrees &&
                   yaw <= ScanConfiguration.maxTurnLeftYawDegrees &&
                   abs(pitch) <= ScanConfiguration.turnPoseTolerancePitchRollDegrees &&
                   abs(roll) <= ScanConfiguration.maxCenterRollDegrees

        case .turnRight:
            // yaw must be in right range (-15° to -35°)
            return yaw <= ScanConfiguration.minTurnRightYawDegrees &&
                   yaw >= ScanConfiguration.maxTurnRightYawDegrees &&
                   abs(pitch) <= ScanConfiguration.turnPoseTolerancePitchRollDegrees &&
                   abs(roll) <= ScanConfiguration.maxCenterRollDegrees

        case .lookUp:
            // pitch must be upward (10-22°)
            return pitch >= ScanConfiguration.minLookUpPitchDegrees &&
                   pitch <= ScanConfiguration.maxLookUpPitchDegrees &&
                   abs(yaw) <= ScanConfiguration.upDownPoseToleranceYawRollDegrees &&
                   abs(roll) <= ScanConfiguration.maxCenterRollDegrees

        case .lookDown:
            // pitch must be downward (-12° to -25°)
            return pitch <= ScanConfiguration.minLookDownPitchDegrees &&
                   pitch >= ScanConfiguration.maxLookDownPitchDegrees &&
                   abs(yaw) <= ScanConfiguration.upDownPoseToleranceYawRollDegrees &&
                   abs(roll) <= ScanConfiguration.maxCenterRollDegrees
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
            // Guide user to center position
            // ARKit: +yaw = face turned LEFT, -yaw = face turned RIGHT
            // User sees: Tell them which way to turn their physical head

            // Priority: yaw (left/right) > pitch (up/down) > roll (tilt)
            // Calculate absolute values for comparison
            let absYaw = abs(yaw)
            let absRoll = abs(roll)

            // Check yaw (left/right rotation) - most important
            if absYaw > 30 {
                // Very far from center (>30°)
                return yaw > 0 ? "Turn your head to the RIGHT" : "Turn your head to the LEFT"
            } else if absYaw > ScanConfiguration.slightTurnYawDegrees {
                // Between 10-30° off center
                return yaw > 0 ? "Turn slightly right" : "Turn slightly left"
            } else if absYaw > ScanConfiguration.maxCenterYawDegrees {
                // Between 5-10° off center (close!)
                return yaw > 0 ? "Almost centered - tiny bit right" : "Almost centered - tiny bit left"
            }

            // Check pitch (up/down tilt)
            if pitch < -15 {
                // Looking too far down
                return "Look UP toward the camera"
            } else if pitch < -ScanConfiguration.maxCenterPitchDegrees {
                return "Almost level - lift chin slightly"
            } else if pitch > 25 {
                // Looking too far up
                return "Look DOWN toward the camera"
            } else if pitch > ScanConfiguration.maxCenterPitchDegrees {
                return "Almost level - lower chin slightly"
            }

            // Check roll (side tilt)
            if absRoll > 25 {
                return roll > 0 ? "Level your head (tilted to left)" : "Level your head (tilted to right)"
            } else if absRoll > ScanConfiguration.maxCenterRollDegrees {
                return "Almost level - straighten head"
            }

            // If within all ranges but still not valid
            return "Hold steady - almost perfect"

        case .turnLeft:
            // Need positive yaw (turn left)
            if yaw < -ScanConfiguration.maxCenterYawDegrees {
                return "Wrong direction - turn your head to the LEFT"
            } else if yaw < (ScanConfiguration.minTurnLeftYawDegrees - 5) {
                return "Turn more to the left"
            } else if yaw < ScanConfiguration.minTurnLeftYawDegrees {
                return "Almost there, turn a bit more left"
            } else if yaw > ScanConfiguration.maxTurnLeftYawDegrees {
                return "Too far, turn back slightly to the right"
            } else if abs(pitch) > ScanConfiguration.turnPoseTolerancePitchRollDegrees {
                return "Good angle - level your head"
            } else if abs(roll) > ScanConfiguration.maxCenterRollDegrees {
                return "Good angle - straighten head"
            }
            return "Hold that position"

        case .turnRight:
            // Need negative yaw (turn right)
            if yaw > ScanConfiguration.maxCenterYawDegrees {
                return "Wrong direction - turn your head to the RIGHT"
            } else if yaw > (ScanConfiguration.minTurnRightYawDegrees + 5) {
                return "Turn more to the right"
            } else if yaw > ScanConfiguration.minTurnRightYawDegrees {
                return "Almost there, turn a bit more right"
            } else if yaw < ScanConfiguration.maxTurnRightYawDegrees {
                return "Too far, turn back slightly to the left"
            } else if abs(pitch) > ScanConfiguration.turnPoseTolerancePitchRollDegrees {
                return "Good angle - level your head"
            } else if abs(roll) > ScanConfiguration.maxCenterRollDegrees {
                return "Good angle - straighten head"
            }
            return "Hold that position"

        case .lookUp:
            // Need positive pitch (look up)
            if pitch < (ScanConfiguration.minLookUpPitchDegrees - 5) {
                return "Tilt your head UP more"
            } else if pitch < ScanConfiguration.minLookUpPitchDegrees {
                return "Almost there, tilt up a bit more"
            } else if pitch > ScanConfiguration.maxLookUpPitchDegrees {
                return "Too far, tilt down slightly"
            } else if abs(yaw) > ScanConfiguration.upDownPoseToleranceYawRollDegrees {
                return "Good angle - face more forward"
            } else if abs(roll) > ScanConfiguration.maxCenterRollDegrees {
                return "Good angle - level your head"
            }
            return "Hold that position"

        case .lookDown:
            // Need negative pitch (look down)
            if pitch > (ScanConfiguration.minLookDownPitchDegrees + 5) {
                return "Tilt your head DOWN more"
            } else if pitch > ScanConfiguration.minLookDownPitchDegrees {
                return "Almost there, tilt down a bit more"
            } else if pitch < ScanConfiguration.maxLookDownPitchDegrees {
                return "Too far, tilt up slightly"
            } else if abs(yaw) > ScanConfiguration.upDownPoseToleranceYawRollDegrees {
                return "Good angle - face more forward"
            } else if abs(roll) > ScanConfiguration.maxCenterRollDegrees {
                return "Good angle - level your head"
            }
            return "Hold that position"
        }
    }
}

/// Overall calibration state
public struct CalibrationState {
    public var lighting: LightingCondition = .tooDark
    public var distance: DistanceCondition = .tooFar
    public var stability: StabilityCondition = .moving
    public var faceDetected: Bool = false

    /// Current center position (for UI indicator)
    public var centerPosition: CenterPosition = .center

    /// Detailed lighting quality message (from EdgeCaseDetector)
    public var lightingDetail: String? = nil

    /// Current face angles for debug display (in degrees)
    public var currentYaw: Float = 0
    public var currentPitch: Float = 0
    public var currentRoll: Float = 0

    /// Check if basic calibration is valid (ready to start guidance)
    public var isCalibrated: Bool {
        return faceDetected &&
               lighting.isValid &&
               distance.isValid &&
               stability.isValid
    }

    /// Check if lighting quality is good (for blocking button)
    public var hasGoodLightingQuality: Bool {
        return lighting == .good || lighting == .acceptable
    }

    /// Get specific lighting issue message
    public var lightingIssueMessage: String {
        return lightingDetail ?? lighting.message
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

        // Use ScanConfiguration constants for lighting thresholds
        let intensity = light.ambientIntensity

        // DEBUG: Log actual ARKit values to understand what we're getting
        // ARKit ambientIntensity is in lumens - typical indoor range is 500-2000
        print("🔆 ARKit ambientIntensity: \(intensity) lumens (min: \(ScanConfiguration.minAmbientLighting), optimal: \(ScanConfiguration.optimalLightingMin)-\(ScanConfiguration.optimalLightingMax))")

        if intensity < ScanConfiguration.minAmbientLighting {
            // Too dark - need good illumination for skin analysis
            lighting = .tooDark
            print("   → VERDICT: tooDark (< \(ScanConfiguration.minAmbientLighting))")
        } else if intensity < ScanConfiguration.optimalLightingMin {
            // Acceptable but not ideal
            lighting = .acceptable
            print("   → VERDICT: acceptable (< \(ScanConfiguration.optimalLightingMin))")
        } else if intensity > ScanConfiguration.maxAmbientLighting {
            // Too bright - risk of overexposure
            lighting = .tooBright
            print("   → VERDICT: tooBright (> \(ScanConfiguration.maxAmbientLighting))")
        } else if intensity > ScanConfiguration.optimalLightingMax {
            // Acceptable but bright
            lighting = .acceptable
            print("   → VERDICT: acceptable (> \(ScanConfiguration.optimalLightingMax))")
        } else {
            // Good lighting range: optimal min-max
            lighting = .good
            print("   → VERDICT: good (\(ScanConfiguration.optimalLightingMin)-\(ScanConfiguration.optimalLightingMax))")
        }
    }

    /// Update distance from face anchor transform
    public mutating func updateDistance(from transform: simd_float4x4) {
        // Extract Z distance from camera (depth along camera view axis)
        // ARKit: negative Z = forward (toward camera), positive Z = backward
        // For face scanning, we care about depth (Z-axis distance), not full 3D distance
        let distance = abs(transform.columns.3.z)

        // Use ScanConfiguration constants for distance validation
        // FIXED: Check optimal range first to ensure 0.30-0.50m gets .good status
        if distance < ScanConfiguration.minFaceDistance {
            // Too close - risk of distortion and cutoff (< 0.20m)
            self.distance = .tooClose
        } else if distance >= ScanConfiguration.optimalDistanceMin && distance <= ScanConfiguration.optimalDistanceMax {
            // OPTIMAL zone - best quality (0.25m - 0.50m)
            self.distance = .good
        } else if distance < ScanConfiguration.optimalDistanceMin {
            // Between min and optimal - acceptable (0.20m - 0.25m)
            self.distance = .acceptable
        } else if distance <= ScanConfiguration.acceptableFarDistance {
            // Beyond optimal but still acceptable (0.50m - 0.60m)
            self.distance = .acceptable
        } else {
            // Too far - insufficient detail (> 0.60m)
            self.distance = .tooFar
        }
    }

    /// Update stability by comparing transforms over time
    public mutating func updateStability(movement: Float) {
        // Use ScanConfiguration constant for stability threshold
        if movement < ScanConfiguration.stabilityMovementThreshold {
            stability = .stable
        } else {
            stability = .moving
        }
    }

    /// Update center position from yaw angle (in degrees)
    public mutating func updateCenterPosition(yaw: Float) {
        let newPosition = CenterPosition.from(yaw: yaw)

        // DEBUG: Log center position updates to diagnose Direction indicator
        if centerPosition != newPosition {
            print("🧭 Center Position changed: \(centerPosition.rawValue) → \(newPosition.rawValue) (yaw: \(String(format: "%.1f", yaw))°)")
        }

        centerPosition = newPosition
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
