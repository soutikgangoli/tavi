//
//  Luminance.swift
//  Ollvy
//
//  Single source of truth for luminance calculations across CPU and GPU paths.
//  Matches Metal shader helpers in AnalyzerCommon.metal.
//
//  Created to fix CPU-GPU score mismatch bug.
//

import Foundation
import simd

/// Luminance calculation helpers matching Metal GPU behavior exactly
public enum Luminance {

    // MARK: - BT.709 (sRGB Luminance)

    /// Calculate BT.709 perceptual luminance from sRGB color in 0..1 range
    /// Matches Metal `perceptualLuminance()` in AnalyzerCommon.metal:17-18
    ///
    /// Formula: Y = 0.2126R + 0.7152G + 0.0722B
    /// Input: sRGB-encoded RGB in [0, 1]
    /// Output: Luminance in [0, 1]
    @inline(__always)
    public static func bt709LuminanceSRGB01(rgb01: SIMD3<Float>) -> Float {
        return 0.2126 * rgb01.x + 0.7152 * rgb01.y + 0.0722 * rgb01.z
    }

    /// Calculate BT.709 perceptual luminance from sRGB color in 0..255 range
    /// Normalizes to 0..1 then applies BT.709 coefficients
    ///
    /// Input: sRGB-encoded RGB in [0, 255]
    /// Output: Luminance in [0, 1]
    @inline(__always)
    public static func bt709LuminanceSRGB255(r: Float, g: Float, b: Float) -> Float {
        let rgb01 = SIMD3<Float>(r / 255.0, g / 255.0, b / 255.0)
        return bt709LuminanceSRGB01(rgb01: rgb01)
    }

    // MARK: - Legacy Luminance

    /// Calculate legacy luminance from sRGB color in 0..1 range
    /// Matches Metal `legacyLuminance()` in AnalyzerCommon.metal:23-24
    ///
    /// Formula: Y = 0.299R + 0.587G + 0.114B
    /// Input: sRGB-encoded RGB in [0, 1]
    /// Output: Luminance in [0, 1]
    @inline(__always)
    public static func legacyLuminanceSRGB01(rgb01: SIMD3<Float>) -> Float {
        return 0.299 * rgb01.x + 0.587 * rgb01.y + 0.114 * rgb01.z
    }

    /// Calculate legacy luminance from sRGB color in 0..255 range
    /// Normalizes to 0..1 then applies legacy coefficients
    ///
    /// Input: sRGB-encoded RGB in [0, 255]
    /// Output: Luminance in [0, 1]
    @inline(__always)
    public static func legacyLuminanceSRGB255(r: Float, g: Float, b: Float) -> Float {
        let rgb01 = SIMD3<Float>(r / 255.0, g / 255.0, b / 255.0)
        return legacyLuminanceSRGB01(rgb01: rgb01)
    }

    // MARK: - XYZ D65 Y Component (Linear RGB)

    /// Calculate CIE XYZ Y component from linear RGB (D65 illuminant)
    /// Matches Metal `linearRGBToXYZ()` in AnalyzerCommon.metal:49 and GlowAnalysis.metal:49
    ///
    /// Formula: Y = 0.2126729R + 0.7151522G + 0.0721750B (exact D65 matrix coefficients)
    /// Input: Linear RGB in [0, 1] (NOT sRGB-encoded, must apply gamma correction first)
    /// Output: XYZ Y component (luminance) in [0, 1]
    ///
    /// NOTE: These coefficients are MORE PRECISE than BT.709. Do not round them.
    /// BT.709 uses 0.2126/0.7152/0.0722 (rounded), but the exact XYZ D65 Y row is:
    /// 0.2126729, 0.7151522, 0.0721750
    @inline(__always)
    public static func yLinearD65(rgbLinear: SIMD3<Float>) -> Float {
        return 0.2126729 * rgbLinear.x + 0.7151522 * rgbLinear.y + 0.0721750 * rgbLinear.z
    }

    /// Convert linear RGB to full XYZ color space (D65 illuminant)
    /// Matches Metal `linearRGBToXYZ()` in AnalyzerCommon.metal:45-52 and GlowAnalysis.metal:46-52
    ///
    /// Full D65 transformation matrix:
    /// X = 0.4124564R + 0.3575761G + 0.1804375B
    /// Y = 0.2126729R + 0.7151522G + 0.0721750B
    /// Z = 0.0193339R + 0.1191920G + 0.9503041B
    ///
    /// Input: Linear RGB in [0, 1] (NOT sRGB-encoded)
    /// Output: XYZ tristimulus values in [0, 1]
    @inline(__always)
    public static func linearRGBToXYZ(rgbLinear: SIMD3<Float>) -> SIMD3<Float> {
        let x = 0.4124564 * rgbLinear.x + 0.3575761 * rgbLinear.y + 0.1804375 * rgbLinear.z
        let y = 0.2126729 * rgbLinear.x + 0.7151522 * rgbLinear.y + 0.0721750 * rgbLinear.z
        let z = 0.0193339 * rgbLinear.x + 0.1191920 * rgbLinear.y + 0.9503041 * rgbLinear.z
        return SIMD3<Float>(x, y, z)
    }

    /// Calculate CIE XYZ Y component from sRGB color in 0..1 range
    /// Applies inverse sRGB gamma to get linear RGB, then computes Y component
    ///
    /// Input: sRGB-encoded RGB in [0, 1]
    /// Output: XYZ Y component (luminance) in [0, 1]
    @inline(__always)
    public static func yLinearD65FromSRGB01(rgb01: SIMD3<Float>) -> Float {
        let linear = srgbToLinear(rgb01)
        return yLinearD65(rgbLinear: linear)
    }

    /// Calculate CIE XYZ Y component from sRGB color in 0..255 range
    /// Normalizes, applies inverse gamma, then computes Y component
    ///
    /// Input: sRGB-encoded RGB in [0, 255]
    /// Output: XYZ Y component (luminance) in [0, 1]
    @inline(__always)
    public static func yLinearD65FromSRGB255(r: Float, g: Float, b: Float) -> Float {
        let rgb01 = SIMD3<Float>(r / 255.0, g / 255.0, b / 255.0)
        return yLinearD65FromSRGB01(rgb01: rgb01)
    }

    // MARK: - sRGB ↔ Linear Conversion

    /// Convert sRGB-encoded value to linear RGB
    /// Matches Metal srgbToLinear() in AnalyzerCommon.metal
    ///
    /// sRGB gamma curve:
    ///   linear = srgb / 12.92                    if srgb <= 0.04045
    ///   linear = ((srgb + 0.055) / 1.055)^2.4    if srgb > 0.04045
    @inline(__always)
    public static func srgbToLinear(_ srgb: Float) -> Float {
        if srgb <= 0.04045 {
            return srgb / 12.92
        } else {
            return pow((srgb + 0.055) / 1.055, 2.4)
        }
    }

    /// Convert sRGB-encoded RGB vector to linear RGB
    @inline(__always)
    public static func srgbToLinear(_ srgb: SIMD3<Float>) -> SIMD3<Float> {
        return SIMD3<Float>(
            srgbToLinear(srgb.x),
            srgbToLinear(srgb.y),
            srgbToLinear(srgb.z)
        )
    }

    /// Convert linear RGB value to sRGB-encoded
    /// Matches Metal linearToSrgb() in AnalyzerCommon.metal
    ///
    /// Inverse sRGB gamma curve:
    ///   srgb = linear * 12.92                if linear <= 0.0031308
    ///   srgb = 1.055 * linear^(1/2.4) - 0.055  if linear > 0.0031308
    @inline(__always)
    public static func linearToSrgb(_ linear: Float) -> Float {
        if linear <= 0.0031308 {
            return linear * 12.92
        } else {
            return 1.055 * pow(linear, 1.0 / 2.4) - 0.055
        }
    }

    /// Convert linear RGB vector to sRGB-encoded
    @inline(__always)
    public static func linearToSrgb(_ linear: SIMD3<Float>) -> SIMD3<Float> {
        return SIMD3<Float>(
            linearToSrgb(linear.x),
            linearToSrgb(linear.y),
            linearToSrgb(linear.z)
        )
    }
}
