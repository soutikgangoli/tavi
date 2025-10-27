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
            return "Please turn your head left"
        case .turnRight:
            return "Please turn your head right"
        case .lookUp:
            return "Please look up slightly"
        case .lookDown:
            return "Please look down slightly"
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
    func isPoseValid(yaw: Float, pitch: Float, roll: Float) -> Bool {
        switch self {
        case .lookStraight:
            // Face should be centered (minimal rotation)
            return abs(yaw) < 5 && abs(pitch) < 5 && abs(roll) < 8

        case .turnLeft:
            // Face should be turned left (positive yaw)
            return yaw > 15 && yaw < 35 && abs(pitch) < 15 && abs(roll) < 12

        case .turnRight:
            // Face should be turned right (negative yaw)
            return yaw < -15 && yaw > -35 && abs(pitch) < 15 && abs(roll) < 12

        case .lookUp:
            // Face should be tilted up (negative pitch)
            return pitch < -10 && pitch > -25 && abs(yaw) < 15 && abs(roll) < 12

        case .lookDown:
            // Face should be tilted down (positive pitch)
            return pitch > 10 && pitch < 25 && abs(yaw) < 15 && abs(roll) < 12
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
