//
//  SimdExtensions.swift
//  Tavi
//
//  Extensions for simd types to extract Euler angles
//  Created on 2025-01-05
//

import Foundation
import simd

extension simd_float4x4 {
    /// Extract Euler angles (in radians) from transformation matrix
    /// Returns SIMD3<Float> with x=pitch, y=yaw, z=roll
    var eulerAngles: SIMD3<Float> {
        // Extract rotation matrix (upper-left 3x3)
        let m11 = self[0][0]
        let m12 = self[0][1]
        let m13 = self[0][2]
        let m21 = self[1][0]
        let m22 = self[1][1]
        let m23 = self[1][2]
        let m31 = self[2][0]
        let m32 = self[2][1]
        let m33 = self[2][2]

        // Calculate Euler angles
        // Using ZYX rotation order (common for face tracking)
        var pitch: Float = 0
        var yaw: Float = 0
        var roll: Float = 0

        // Check for gimbal lock
        if abs(m31) < 0.99999 {
            yaw = atan2(m21, m11)
            pitch = asin(-m31)
            roll = atan2(m32, m33)
        } else {
            // Gimbal lock case
            yaw = atan2(-m12, m22)
            pitch = m31 < 0 ? .pi / 2 : -.pi / 2
            roll = 0
        }

        return SIMD3<Float>(x: pitch, y: yaw, z: roll)
    }
}
