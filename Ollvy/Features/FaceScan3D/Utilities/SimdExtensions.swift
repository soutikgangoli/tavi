//
//  SimdExtensions.swift
//  Ollvy
//
//  Extensions for simd types to extract Euler angles
//  Created on 2025-01-05
//

import Foundation
import simd
import ARKit

extension simd_float4x4 {
    /// Extract Euler angles (in radians) from transformation matrix
    /// Returns SIMD3<Float> with x=pitch, y=yaw, z=roll
    ///
    /// CRITICAL: This extracts angles from the 3x3 rotation part of the matrix
    /// For face tracking, call this on the RELATIVE transform (camera space to face space)
    var eulerAngles: SIMD3<Float> {
        // Extract the 3x3 rotation part
        let r11 = self[0][0]
        let r12 = self[0][1]
        let r13 = self[0][2]
        let r21 = self[1][0]
        let r22 = self[1][1]
        let r23 = self[1][2]
        // r31 = self[2][0] - unused in ZYX Euler angle calculation
        // r32 = self[2][1] - unused in ZYX Euler angle calculation
        let r33 = self[2][2]

        // YXZ Euler angle extraction (yaw-pitch-roll order)
        // This matches how face orientation naturally works
        var pitch: Float
        var yaw: Float
        var roll: Float

        // Check for gimbal lock
        let sinPitch = -r23
        if abs(sinPitch) >= 0.9999 {
            // Gimbal lock case
            pitch = sinPitch > 0 ? Float.pi / 2 : -Float.pi / 2
            yaw = 0
            roll = atan2(-r12, r11)
        } else {
            pitch = asin(sinPitch)
            yaw = atan2(r13, r33)
            roll = atan2(r21, r22)
        }

        return SIMD3<Float>(x: pitch, y: yaw, z: roll)
    }
}

extension ARFaceAnchor {
    /// Get face orientation angles relative to camera
    /// Returns SIMD3<Float> with x=pitch (up/down), y=yaw (left/right), z=roll (tilt)
    ///
    /// CRITICAL FIX: ARFaceAnchor.transform is in WORLD space
    /// We need angles relative to CAMERA (device), not world
    /// This calculates the relative orientation by inverting the transform
    func eulerAnglesRelativeToCamera() -> SIMD3<Float> {
        // ARFaceAnchor.transform is face position/rotation in world space
        // To get face orientation relative to camera, we need to extract just the rotation
        // and work in the face's local coordinate system

        // Use the inverse transform to get camera-relative orientation
        // This effectively asks: "how is the face rotated relative to looking straight at camera?"
        let relativeTransform = self.transform.inverse

        return relativeTransform.eulerAngles
    }
}
