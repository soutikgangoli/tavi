//
//  CalibrationState.swift
//  Ollvy
//
//  Calibration state for 3D face scanning
//  Created on 2025-10-27.
//

import Foundation
import ARKit

/// Lighting condition states
public enum LightingCondition: String, Sendable {
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
public enum DistanceCondition: String, Sendable {
    case tooClose = "tooClose"
    case tooFar = "tooFar"
    case good = "good"              // Optimal quality range (30-55cm)

    var message: String {
        switch self {
        case .tooClose:
            return "Move back slightly"
        case .tooFar:
            return "Move a bit closer"
        case .good:
            return "Distance is perfect"
        }
    }

    var isValid: Bool {
        return self == .good
    }

    var isOptimal: Bool {
        return self == .good
    }
}

/// Face stability state
public enum StabilityCondition: Sendable {
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
public enum CenterPosition: String, Sendable {
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

/// Guidance steps for capture (5 poses - currently only lookStraight enabled)
public enum GuidanceStep: Int, CaseIterable, Sendable {
    case lookStraight = 0
    case turnLeft
    case turnRight
    case lookUp
    case lookDown
    
    /// Active poses for capture - all 5 poses enabled for better scan accuracy
    public static var activePoses: [GuidanceStep] {
        return [.lookStraight, .turnLeft, .turnRight, .lookUp, .lookDown]
    }

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
    /// NOTE: Debug logging removed to reduce log spam (called 60+ times/second)
    func isPoseValid(yaw: Float, pitch: Float, roll: Float) -> Bool {
        switch self {
        case .lookStraight:
            // STRICT: ±5° for yaw and pitch, ±8° for roll (per documentation)
            // This ensures accurate center position detection
            return abs(yaw) <= ScanConfiguration.maxCenterYawDegrees &&
                   abs(pitch) <= ScanConfiguration.maxCenterPitchDegrees &&
                   abs(roll) <= ScanConfiguration.maxCenterRollDegrees

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

    /// Returns the next guidance step, or nil if this is the last step
    var next: GuidanceStep? {
        let allCases = Self.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else {
            return nil
        }
        let nextIndex = currentIndex + 1
        return nextIndex < allCases.count ? allCases[nextIndex] : nil
    }
}

/// Overall calibration state
public struct CalibrationState: Sendable {
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
    /// NOTE: Debug logging removed to reduce log spam (60fps). Lighting state is logged
    /// by CalibrationManager every 30 frames (~0.5s) which is sufficient for debugging.
    public mutating func updateLighting(from lightEstimate: LightEstimation?) {
        guard let light = lightEstimate else {
            lighting = .tooDark
            return
        }

        // Use ScanConfiguration constants for lighting thresholds
        let intensity = light.ambientIntensity
        let previousLighting = lighting

        // ARKit ambientIntensity is in lumens - typical indoor range is 500-2000
        if intensity < ScanConfiguration.minAmbientLighting {
            // Too dark - need good illumination for skin analysis
            lighting = .tooDark
        } else if intensity < ScanConfiguration.optimalLightingMin {
            // Acceptable but not ideal
            lighting = .acceptable
        } else if intensity > ScanConfiguration.maxAmbientLighting {
            // Too bright - risk of overexposure
            lighting = .tooBright
        } else if intensity > ScanConfiguration.optimalLightingMax {
            // Acceptable but bright
            lighting = .acceptable
        } else {
            // Good lighting range: optimal min-max
            lighting = .good
        }

        // Only log when lighting state changes (reduces log spam from 60/s to occasional)
        if lighting != previousLighting {
            // Capture values before logging to avoid escaping autoclosure issue
            let newLightingValue = lighting.rawValue
            AppLogger.faceScan.debug("🔆 Lighting changed: \(previousLighting.rawValue) → \(newLightingValue) (intensity: \(Int(intensity)) lumens)")
        }
    }

    /// Update distance from face anchor transform
    public mutating func updateDistance(from transform: simd_float4x4) {
        // Extract Z distance from camera (depth along camera view axis)
        let distance = abs(transform.columns.3.z)

        // Simplified distance zones - no more confusing "acceptable" range
        // Good range: 30-55cm (where ARKit tracking is stable and detail is good)
        if distance < ScanConfiguration.minFaceDistance {
            // Too close (< 30cm) - causes tracking jitter
            self.distance = .tooClose
        } else if distance <= ScanConfiguration.acceptableFarDistance {
            // Good zone (30-55cm) - stable tracking + good detail
            self.distance = .good
        } else {
            // Too far (> 55cm) - insufficient skin detail
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
        let oldPosition = self.centerPosition

        if oldPosition != newPosition {
            AppLogger.faceScan.debug("🧭 Center Position changed: \(oldPosition.rawValue) → \(newPosition.rawValue) (yaw: \(String(format: "%.1f", yaw))°)")
        }

        self.centerPosition = newPosition
    }
}

/// Captured pose data for a guidance step
public struct CapturedPoseData: Sendable {
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
