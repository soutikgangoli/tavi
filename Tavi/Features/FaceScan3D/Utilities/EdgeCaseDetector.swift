//
//  EdgeCaseDetector.swift
//  Tavi
//
//  Edge case detection: facial hair, makeup, glasses, sunburn
//  Warns user when scan accuracy may be affected
//

import Foundation
import UIKit
import ARKit
import SwiftUI
import Accelerate

/// Edge case severity levels
public enum EdgeCaseSeverity {
    case none, mild, moderate, severe
}

/// Edge case detection results
public struct EdgeCaseAnalysis {
    let facialHairDetected: Bool
    let facialHairSeverity: EdgeCaseSeverity
    let makeupDetected: Bool
    let makeupType: MakeupType?
    let glassesDetected: Bool
    let handOcclusionDetected: Bool
    let hairCoverageDetected: Bool
    let sunburnDetected: Bool
    let hatDetected: Bool
    let earringsDetected: Bool
    let lightingQuality: LightingQuality  // NEW: Lighting assessment
    let currentBrightness: Float  // NEW: 0-1 brightness level
    let warnings: [String]
    let recommendations: [String]
    let shouldProceed: Bool  // false = block scan
    let blockReason: String?  // NEW: Explanation when shouldProceed = false
}

/// Lighting quality assessment
public enum LightingQuality {
    case tooDark         // < 0.45 brightness OR poor dynamic range - BLOCK
    case suboptimalDark  // 0.45-0.55 brightness OR low contrast - WARN
    case optimal         // 0.55-0.75 brightness with good contrast - GOOD
    case suboptimalBright // 0.75-0.85 brightness OR slight overexposure - WARN
    case tooBright       // > 0.85 brightness OR >10% overexposed - BLOCK

    var shouldBlock: Bool {
        self == .tooDark || self == .tooBright
    }

    var description: String {
        switch self {
        case .tooDark: return "Too Dark"
        case .suboptimalDark: return "Low Light"
        case .optimal: return "Optimal"
        case .suboptimalBright: return "Bright"
        case .tooBright: return "Too Bright"
        }
    }
}

public enum MakeupType {
    case foundation, heavyFoundation, specialEffects
}

/// Lighting strictness levels (imported from settings)
public enum LightingStrictnessLevel {
    case strict
    case relaxed
    case off

    var minBrightness: Float {
        switch self {
        case .strict: return 0.25  // Block <25%
        case .relaxed: return 0.15  // Block <15%
        case .off: return 0.0  // Never block
        }
    }

    var maxBrightness: Float {
        switch self {
        case .strict: return 0.90  // Block >90%
        case .relaxed: return 0.95  // Block >95%
        case .off: return 1.0  // Never block
        }
    }
}

/// Edge case detector
public class EdgeCaseDetector {

    // MARK: - Properties

    private let skinToneNormalizer = SkinToneNormalizer()

    // Debug throttling for lighting messages
    private var lastLoggedLightingQuality: LightingQuality?
    private var lightingCheckCount: Int = 0
    private let lightingLogInterval: Int = 30  // Log every 30 checks (~0.5 seconds at 60fps)

    // OPTIMIZATION: Buffer reuse to avoid repeated allocations
    private var cachedPixelBuffer: [(UInt8, UInt8, UInt8)]?
    private var cachedImageReference: CGImage?

    // MARK: - Public API

    /// Detect all edge cases
    public func detectEdgeCases(
        texture: UIImage,
        faceAnchor: ARFaceAnchor,
        strictness: LightingStrictnessLevel = .strict
    ) -> EdgeCaseAnalysis {
        // OPTIMIZATION FIX: Clear cache at start of new analysis to prevent stale data
        // Each detectEdgeCases call is for a new frame/image
        cachedPixelBuffer = nil
        cachedImageReference = nil

        var warnings: [String] = []
        var recommendations: [String] = []

        // Load user preferences for edge case detection
        let detectGlasses = UserDefaults.standard.object(forKey: "detectGlasses") as? Bool ?? true
        let detectHands = UserDefaults.standard.object(forKey: "detectHands") as? Bool ?? true
        let detectHat = UserDefaults.standard.object(forKey: "detectHat") as? Bool ?? true
        let detectMakeup = UserDefaults.standard.object(forKey: "detectMakeup") as? Bool ?? true
        let detectHairCoverage = UserDefaults.standard.object(forKey: "detectHairCoverage") as? Bool ?? true
        let detectSunburn = UserDefaults.standard.object(forKey: "detectSunburn") as? Bool ?? true
        let detectEarrings = UserDefaults.standard.object(forKey: "detectEarrings") as? Bool ?? true
        let detectFacialHair = UserDefaults.standard.object(forKey: "detectFacialHair") as? Bool ?? true

        // LIGHTING DETECTION (First priority - blocks everything else if too dark/bright)
        let (brightness, lightingQuality) = detectLightingConditions(texture: texture, strictness: strictness)

        if lightingQuality == .tooDark {
            warnings.append("Lighting too dark for accurate scan")
            recommendations.append("Move to a brighter area or turn on more lights")
        } else if lightingQuality == .suboptimalDark {
            warnings.append("Lighting is low - results may be less accurate")
            recommendations.append("For best results, move to better lighting")
        } else if lightingQuality == .tooBright {
            warnings.append("Lighting too bright - excessive glare detected")
            recommendations.append("Move away from direct light source or reduce lighting")
        } else if lightingQuality == .suboptimalBright {
            warnings.append("Lighting is very bright")
            recommendations.append("Reduce glare for optimal results")
        }

        // Facial hair detection
        let (facialHairDetected, facialHairSeverity) = detectFacialHair ? self.detectFacialHair(texture: texture) : (false, .none)
        if detectFacialHair && facialHairDetected {
            warnings.append(facialHairSeverity == .severe ? "Heavy facial hair detected" : "Facial hair detected")
            recommendations.append("Facial hair may reduce texture analysis accuracy")
        }

        // Makeup detection
        let (makeupDetected, makeupType) = detectMakeup ? self.detectMakeup(texture: texture) : (false, nil)
        if detectMakeup && makeupDetected {
            warnings.append("Makeup detected")
            if makeupType == .heavyFoundation {
                recommendations.append("Heavy makeup may affect texture and pigmentation metrics. Consider scanning without makeup.")
            } else {
                recommendations.append("Light makeup detected - results may be affected")
            }
        }

        // Glasses detection
        let glassesDetected = detectGlasses ? self.detectGlasses(faceAnchor: faceAnchor, texture: texture) : false
        if detectGlasses && glassesDetected {
            warnings.append("Glasses detected")
            recommendations.append("Please remove glasses for accurate scan")
        }

        // Hand occlusion detection
        let handOcclusionDetected = detectHands ? self.detectHandOcclusion(faceAnchor: faceAnchor, texture: texture) : false
        if detectHands && handOcclusionDetected {
            warnings.append("Hand near/on face detected")
            recommendations.append("Please remove hands from face")
        }

        // Hair coverage detection
        let hairCoverageDetected = detectHairCoverage ? self.detectHairCoverage(texture: texture, faceAnchor: faceAnchor) : false
        if detectHairCoverage && hairCoverageDetected {
            warnings.append("Hair covering face/forehead detected")
            recommendations.append("Please move hair away from face for better results")
        }

        // Sunburn detection
        let sunburnDetected = detectSunburn ? self.detectSunburn(texture: texture) : false
        if detectSunburn && sunburnDetected {
            warnings.append("Possible sunburn detected")
            recommendations.append("Wait 48 hours after sunburn for accurate results")
        }

        // Hat/headband detection
        let hatDetected = detectHat ? self.detectHat(texture: texture, faceAnchor: faceAnchor) : false
        if detectHat && hatDetected {
            warnings.append("Hat or headband detected")
            recommendations.append("Please remove hat/headband for complete forehead analysis")
        }

        // Earring detection
        let earringsDetected = detectEarrings ? self.detectEarrings(texture: texture, faceAnchor: faceAnchor) : false
        if detectEarrings && earringsDetected {
            warnings.append("Large earrings detected")
            recommendations.append("Large earrings may affect cheek/jawline analysis")
        }

        // BLOCKING LOGIC - CONSERVATIVE APPROACH
        // ONLY block for truly critical issues that prevent accurate scanning
        // Hat, glasses, and hand detection are too unreliable - make them warnings only
        let criticalIssues = detectMakeup && makeupType == .heavyFoundation  // Only block heavy makeup if detection enabled
        let badLighting = lightingQuality.shouldBlock

        let shouldProceed = !criticalIssues && !badLighting

        // Determine block reason
        var blockReason: String? = nil
        if !shouldProceed {
            if badLighting {
                blockReason = lightingQuality == .tooDark ?
                    "Lighting too dark - move to brighter area" :
                    "Lighting too bright - reduce glare"
            } else if detectMakeup && makeupType == .heavyFoundation {
                blockReason = "Heavy makeup detected - scan without makeup for accurate results"
            }
        }

        // Add warnings for non-blocking issues (only if detection is enabled)
        if detectGlasses && glassesDetected {
            warnings.insert("Glasses may affect accuracy - remove if possible", at: 0)
        }
        if detectHands && handOcclusionDetected {
            warnings.insert("Hands near face detected - keep hands away for best results", at: 0)
        }
        if detectHat && hatDetected {
            warnings.insert("Hat/headband detected - remove for complete forehead analysis", at: 0)
        }

        return EdgeCaseAnalysis(
            facialHairDetected: facialHairDetected,
            facialHairSeverity: facialHairSeverity,
            makeupDetected: makeupDetected,
            makeupType: makeupType,
            glassesDetected: glassesDetected,
            handOcclusionDetected: handOcclusionDetected,
            hairCoverageDetected: hairCoverageDetected,
            sunburnDetected: sunburnDetected,
            hatDetected: hatDetected,
            earringsDetected: earringsDetected,
            lightingQuality: lightingQuality,
            currentBrightness: brightness,
            warnings: warnings,
            recommendations: recommendations,
            shouldProceed: shouldProceed,
            blockReason: blockReason
        )
    }

    // MARK: - Lighting Detection

    /// Detect lighting conditions from texture
    /// IMPROVED: Skin-tone aware lighting detection using contrast and dynamic range
    private func detectLightingConditions(texture: UIImage, strictness: LightingStrictnessLevel) -> (brightness: Float, quality: LightingQuality) {
        guard let cgImage = texture.cgImage else { return (0.5, .optimal) }

        // Sample center region (face area) for brightness
        let width = cgImage.width
        let height = cgImage.height
        let centerX = width / 2
        let centerY = height / 2
        let sampleRadius = min(width, height) / 6

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            return (0.5, .optimal)
        }

        var totalBrightness: Float = 0
        var minBrightness: Float = 1.0
        var maxBrightness: Float = 0.0
        var overexposedPixels = 0
        var underexposedPixels = 0
        var sampleCount = 0
        var brightnessValues: [Float] = []

        // Sample 100 pixels from center region
        for y in stride(from: centerY - sampleRadius, to: centerY + sampleRadius, by: sampleRadius / 5) {
            for x in stride(from: centerX - sampleRadius, to: centerX + sampleRadius, by: sampleRadius / 5) {
                guard x >= 0 && x < width && y >= 0 && y < height else { continue }

                let offset = (y * width + x) * 4
                guard offset + 2 < CFDataGetLength(data) else { continue }

                let r = Float(ptr[offset])
                let g = Float(ptr[offset + 1])
                let b = Float(ptr[offset + 2])

                // Luminance (perceived brightness)
                let luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0

                totalBrightness += luminance
                brightnessValues.append(luminance)
                minBrightness = min(minBrightness, luminance)
                maxBrightness = max(maxBrightness, luminance)

                // Count overexposed/underexposed pixels
                if luminance > 0.95 {
                    overexposedPixels += 1
                } else if luminance < 0.05 {
                    underexposedPixels += 1
                }

                sampleCount += 1
            }
        }

        let averageBrightness = sampleCount > 0 ? totalBrightness / Float(sampleCount) : 0.5

        // IMPROVED: Calculate contrast and dynamic range (works for all skin tones)
        let dynamicRange = maxBrightness - minBrightness
        let overexposedRatio = Float(overexposedPixels) / Float(max(sampleCount, 1))
        let underexposedRatio = Float(underexposedPixels) / Float(max(sampleCount, 1))

        // Calculate standard deviation for contrast assessment
        let variance = brightnessValues.map { pow($0 - averageBrightness, 2) }.reduce(0, +) / Float(max(brightnessValues.count, 1))
        let contrast = sqrt(variance)

        // SKIN-TONE AWARE QUALITY ASSESSMENT
        // Instead of absolute brightness thresholds, we check:
        // 1. Dynamic range (can we see facial features?)
        // 2. Overexposure (blown out highlights?)
        // 3. Underexposure (too many black pixels?)
        // 4. Contrast (enough detail visible?)

        let quality: LightingQuality

        // STRICT THRESHOLDS FOR CLINICAL SKIN ANALYSIS
        // Need accurate color capture for pigmentation, redness, sun damage, glow, etc.
        // SKIN-TONE INDEPENDENT: Prioritize dynamic range and contrast over absolute brightness

        // CRITICAL: Overexposure (blown highlights) - BLOCK
        // Strict: 10% max (was 30%) - can't analyze washed out skin
        if overexposedRatio > 0.10 {
            quality = .tooBright
        }
        // CRITICAL: Too bright for accurate color - BLOCK
        // Strict: Max 85% brightness (was 90%) to avoid color washout
        else if averageBrightness > 0.85 {
            quality = .tooBright
        }
        // CRITICAL: Poor dynamic range - BLOCK (skin-tone independent)
        // Strict: Need 30% dynamic range (was 10%) to see facial features
        // This works for ALL skin tones - it's about contrast, not absolute brightness
        else if dynamicRange < 0.30 {
            quality = .tooDark
        }
        // CRITICAL: Too many underexposed pixels - BLOCK
        // More than 20% pure black pixels = too dark regardless of skin tone
        else if underexposedRatio > 0.20 {
            quality = .tooDark
        }
        // SECONDARY: Very low brightness (but allow darker skin tones)
        // Further relaxed from 30% to 20% for very dark skin (Fitzpatrick VI)
        // Only block if BOTH brightness is very low AND contrast is poor
        else if averageBrightness < 0.20 && contrast < 0.10 {  // Was: 0.30 && 0.12
            quality = .tooDark
        }
        // WARNING: Borderline overexposure
        else if overexposedRatio > 0.05 || averageBrightness > 0.75 {
            quality = .suboptimalBright
        }
        // WARNING: Low contrast/detail (skin-tone independent)
        // Strict: Need 15% contrast (was 8%) to see texture and pigmentation
        else if contrast < 0.15 || dynamicRange < 0.40 {
            quality = .suboptimalDark
        }
        // OPTIMAL: Good lighting for clinical skin analysis
        else {
            quality = .optimal
        }

        // Throttle debug output: only log when quality changes OR every N checks
        lightingCheckCount += 1
        let shouldLog = (lastLoggedLightingQuality != quality) || (lightingCheckCount >= lightingLogInterval)

        if shouldLog {
            AppLogger.metrics.info("💡 Lighting detected: \(quality.description)")
            AppLogger.metrics.info("Brightness: \(String(format: "%.0f", averageBrightness * 100))%, Range: \(String(format: "%.2f", dynamicRange)), Contrast: \(String(format: "%.2f", contrast))")
            AppLogger.metrics.info("Overexposed: \(String(format: "%.1f", overexposedRatio * 100))%, Underexposed: \(String(format: "%.1f", underexposedRatio * 100))%")

            lastLoggedLightingQuality = quality
            lightingCheckCount = 0
        }

        return (averageBrightness, quality)
    }

    // MARK: - Facial Hair Detection

    private func detectFacialHair(texture: UIImage) -> (Bool, EdgeCaseSeverity) {
        guard let cgImage = texture.cgImage else { return (false, .none) }

        // Extract lower face region (beard/mustache area)
        let lowerFaceRegion = cgImage.cropping(to: CGRect(
            x: cgImage.width / 3,
            y: cgImage.height * 2 / 3,
            width: cgImage.width / 3,
            height: cgImage.height / 6
        ))

        guard let region = lowerFaceRegion else { return (false, .none) }

        // Calculate darkness (facial hair is typically darker)
        let pixels = extractPixels(from: region)
        let brightnessValues = pixels.map { (Float($0.0) + Float($0.1) + Float($0.2)) / 3.0 }
        let sumBrightness = brightnessValues.reduce(0, +)
        let avgBrightness = sumBrightness / Float(max(pixels.count, 1))

        // Calculate texture variance (hair has high variance)
        let variance = calculateVariance(pixels: pixels)

        // SKIN-TONE AWARE: Use relative darkness threshold based on overall skin tone
        // Detect skin tone from full texture first
        let skinTone = skinToneNormalizer.detectSkinTone(texture: texture)
        let relativeDarknessThreshold: Float

        switch skinTone {
        case .veryLight, .light:
            relativeDarknessThreshold = 80  // Normal threshold for light skin
        case .medium, .mediumDark:
            relativeDarknessThreshold = 60  // Lower for medium skin
        case .dark, .veryDark:
            relativeDarknessThreshold = 40  // Much lower for dark skin (Fitzpatrick IV-VI)
        }

        // Heuristic: dark + high variance = facial hair
        let isDark = avgBrightness < relativeDarknessThreshold
        let hasHighVariance = variance > 500

        if isDark && hasHighVariance {
            // Determine severity based on coverage
            let darkPixels = pixels.filter { (Float($0.0) + Float($0.1) + Float($0.2)) / 3.0 < 80 }
            let darkPixelRatio = Float(darkPixels.count) / Float(pixels.count)

            let severity: EdgeCaseSeverity
            if darkPixelRatio > 0.5 {
                severity = .severe  // Heavy beard
            } else if darkPixelRatio > 0.3 {
                severity = .moderate
            } else if darkPixelRatio > 0.1 {
                severity = .mild
            } else {
                severity = .none
            }

            return (true, severity)
        }

        return (false, .none)
    }

    // MARK: - Makeup Detection

    private func detectMakeup(texture: UIImage) -> (Bool, MakeupType?) {
        guard let cgImage = texture.cgImage else { return (false, nil) }

        // Extract cheek region
        let cheekRegion = cgImage.cropping(to: CGRect(
            x: cgImage.width / 4,
            y: cgImage.height / 2,
            width: cgImage.width / 6,
            height: cgImage.height / 6
        ))

        guard let region = cheekRegion else { return (false, nil) }

        let pixels = extractPixels(from: region)

        // Calculate skin tone uniformity (makeup = very uniform)
        let variance = calculateVariance(pixels: pixels)

        // Calculate average color saturation
        let avgSaturation = calculateSaturation(pixels: pixels)

        // Heuristics:
        // 1. Very low variance = foundation (mask texture)
        // 2. High saturation = blush/contour
        let hasFoundation = variance < 50  // Very uniform
        let hasColorMakeup = avgSaturation > 0.3

        if hasFoundation && hasColorMakeup {
            return (true, .heavyFoundation)
        } else if hasFoundation {
            return (true, .foundation)
        } else if hasColorMakeup {
            return (true, .foundation)  // Light makeup
        }

        return (false, nil)
    }

    // MARK: - Glasses Detection

    private func detectGlasses(faceAnchor: ARFaceAnchor, texture: UIImage) -> Bool {
        guard let cgImage = texture.cgImage else { return false }

        // Strategy 1: Check for reflections in eye region (specular highlights from glass)
        let leftEyeRegion = cgImage.cropping(to: CGRect(
            x: cgImage.width / 4,
            y: cgImage.height / 3,
            width: cgImage.width / 8,
            height: cgImage.height / 12
        ))

        let rightEyeRegion = cgImage.cropping(to: CGRect(
            x: cgImage.width * 5 / 8,
            y: cgImage.height / 3,
            width: cgImage.width / 8,
            height: cgImage.height / 12
        ))

        guard let leftEye = leftEyeRegion, let rightEye = rightEyeRegion else { return false }

        // Detect bright spots (reflections from glasses)
        let leftReflections = detectBrightSpots(in: leftEye)
        let rightReflections = detectBrightSpots(in: rightEye)

        // Strategy 2: Check for edge patterns (frame edges)
        let leftEdges = detectEdgePatterns(in: leftEye)
        let rightEdges = detectEdgePatterns(in: rightEye)

        // Strategy 3: Check ARKit eye tracking confidence
        // Glasses interfere with eye tracking, reducing quality
        let leftEyeTransform = faceAnchor.leftEyeTransform
        let rightEyeTransform = faceAnchor.rightEyeTransform

        // If eyes have abnormal transforms (invalid tracking), might be glasses
        let leftEyeConfidence = isEyeTransformNormal(leftEyeTransform)
        let rightEyeConfidence = isEyeTransformNormal(rightEyeTransform)

        // Combine heuristics:
        // - High reflections + edge patterns = likely glasses
        // - Multiple indicators = higher confidence
        let reflectionScore = leftReflections + rightReflections
        let edgeScore = leftEdges + rightEdges
        let trackingIssues = (!leftEyeConfidence ? 1 : 0) + (!rightEyeConfidence ? 1 : 0)

        let glassesScore = reflectionScore * 2.0 + edgeScore * 1.5 + Float(trackingIssues) * 3.0

        // IMPROVED: Require multiple indicators to reduce false positives
        // Single reflections can be from lighting, not glasses
        // Glasses typically show: reflections + edges OR reflections + tracking issues
        let hasMultipleIndicators = (reflectionScore > 0 && edgeScore > 0) ||
                                   (reflectionScore > 0 && trackingIssues > 0) ||
                                   (edgeScore > 0 && trackingIssues > 0)

        // Higher threshold + require multiple indicators to avoid false positives from lighting
        let glassesDetected = glassesScore > 8.0 && hasMultipleIndicators

        if glassesScore > 3.0 {
            AppLogger.metrics.debug("🕶️ Glasses check (score: \(String(format: "%.1f", glassesScore)), detected: \(glassesDetected))")
            AppLogger.metrics.debug("Reflections: \(String(format: "%.1f", reflectionScore)), Edges: \(String(format: "%.1f", edgeScore)), Tracking issues: \(trackingIssues)")
            AppLogger.metrics.debug("Multiple indicators: \(hasMultipleIndicators)")
        }

        return glassesDetected
    }

    // MARK: - Hand Occlusion Detection

    private func detectHandOcclusion(faceAnchor: ARFaceAnchor, texture: UIImage) -> Bool {
        // Strategy: Only check for severe geometry occlusions
        // Color variance is too unreliable across different skin tones and lighting

        let geometry = faceAnchor.geometry
        let vertices = geometry.vertices
        let vertexCount = geometry.vertices.count

        // Check for suspicious vertex patterns in lower face (where hands typically appear)
        var suspiciousVertices = 0

        for i in 0..<vertexCount {
            let vertex = vertices[i]

            // Check if vertex is in lower face region (y < 0, near chin/cheeks)
            if vertex.y < 0 && vertex.y > -0.08 {
                // Check if vertex has abnormal z-depth (too far forward = occlusion)
                if abs(vertex.z) < 0.015 {  // Very close to camera plane = likely hand
                    suspiciousVertices += 1
                }
            }
        }

        let occlusionRatio = Float(suspiciousVertices) / Float(max(vertexCount, 1))

        // CONSERVATIVE: Only detect hands if there's severe geometry occlusion
        // This prevents false positives from lighting, shadows, or skin tone variations
        let handDetected = occlusionRatio > 0.25  // 25% of lower face vertices abnormally close

        if occlusionRatio > 0.10 {
            AppLogger.metrics.debug("✋ Hand check (occlusion ratio: \(String(format: "%.2f", occlusionRatio)), detected: \(handDetected))")
        }

        return handDetected
    }

    // MARK: - Hair Coverage Detection

    private func detectHairCoverage(texture: UIImage, faceAnchor: ARFaceAnchor) -> Bool {
        guard let cgImage = texture.cgImage else { return false }

        // Strategy 1: Check forehead region for hair texture patterns
        // Hair has distinct texture (high variance, dark color, linear patterns)

        let foreheadRegion = cgImage.cropping(to: CGRect(
            x: cgImage.width / 3,
            y: cgImage.height / 6,
            width: cgImage.width / 3,
            height: cgImage.height / 6
        ))

        guard let forehead = foreheadRegion else { return false }

        let foreheadPixels = extractPixels(from: forehead)
        let foreheadVariance = calculateVariance(pixels: foreheadPixels)
        let foreheadBrightnessValues = foreheadPixels.map { (Float($0.0) + Float($0.1) + Float($0.2)) / 3.0 }
        let sumForeheadBrightness = foreheadBrightnessValues.reduce(0, +)
        let foreheadBrightness = sumForeheadBrightness / Float(max(foreheadPixels.count, 1))

        // Hair characteristics:
        // 1. High variance (different from smooth skin)
        // 2. Generally darker than skin
        // 3. High ratio of dark pixels

        let darkForeheadPixels = foreheadPixels.filter { (Float($0.0) + Float($0.1) + Float($0.2)) / 3.0 < 100 }
        let darkPixelRatio = Float(darkForeheadPixels.count) / Float(foreheadPixels.count)

        let hasHairTexture = foreheadVariance > 600
        let isDark = foreheadBrightness < 110
        let hasSignificantDarkArea = darkPixelRatio > 0.4

        // Strategy 2: Check for reduced landmark confidence in forehead region
        // (ARKit doesn't expose per-landmark confidence, but we can infer from geometry quality)

        let geometry = faceAnchor.geometry
        let vertices = geometry.vertices
        let vertexCount = geometry.vertices.count

        // Check for missing/invalid vertices in upper face
        var invalidUpperVertices = 0
        for i in 0..<vertexCount {
            let vertex = vertices[i]
            if vertex.y > 0.05 {  // Upper face region
                // Check for abnormal positions
                if vertex.z.isNaN || vertex.z.isInfinite || abs(vertex.z) > 0.5 {
                    invalidUpperVertices += 1
                }
            }
        }

        let upperFaceQualityIssue = Float(invalidUpperVertices) / Float(max(vertexCount, 1)) > 0.05

        // Combine heuristics
        let hairCoverageDetected = (hasHairTexture && isDark && hasSignificantDarkArea) || upperFaceQualityIssue

        if hairCoverageDetected {
            AppLogger.metrics.debug("💇 Hair coverage detected (variance: \(foreheadVariance), brightness: \(foreheadBrightness), dark ratio: \(darkPixelRatio))")
        }

        return hairCoverageDetected
    }

    // MARK: - Helper Methods for Glasses Detection

    private func detectBrightSpots(in image: CGImage) -> Float {
        let pixels = extractPixels(from: image)

        // Count very bright pixels (reflections from glasses)
        let brightPixelCount = pixels.filter { pixel in
            let brightness = (Float(pixel.0) + Float(pixel.1) + Float(pixel.2)) / 3.0
            return brightness > 220  // Very bright = likely reflection
        }.count

        let ratio = Float(brightPixelCount) / Float(max(pixels.count, 1))
        return ratio * 10.0  // Scale to contribution score
    }

    private func detectEdgePatterns(in image: CGImage) -> Float {
        // Simple Sobel edge detection to find frame edges
        let pixels = extractPixels(from: image)
        guard pixels.count > 100 else { return 0 }

        // Count strong edges (frame boundaries)
        var edgeCount = 0
        let width = image.width
        let height = image.height

        // Sample grid for edge detection (faster than full image)
        for y in stride(from: 1, to: height - 1, by: 2) {
            for x in stride(from: 1, to: width - 1, by: 2) {
                let idx = y * width + x

                guard idx < pixels.count,
                      idx - width >= 0,
                      idx + width < pixels.count,
                      x > 0 && x < width - 1 else { continue }

                let center = (Float(pixels[idx].0) + Float(pixels[idx].1) + Float(pixels[idx].2)) / 3.0
                let top = (Float(pixels[idx - width].0) + Float(pixels[idx - width].1) + Float(pixels[idx - width].2)) / 3.0
                let bottom = (Float(pixels[idx + width].0) + Float(pixels[idx + width].1) + Float(pixels[idx + width].2)) / 3.0
                let left = (Float(pixels[idx - 1].0) + Float(pixels[idx - 1].1) + Float(pixels[idx - 1].2)) / 3.0
                let right = (Float(pixels[idx + 1].0) + Float(pixels[idx + 1].1) + Float(pixels[idx + 1].2)) / 3.0

                let edgeMagnitude = abs(center - top) + abs(center - bottom) + abs(center - left) + abs(center - right)

                if edgeMagnitude > 100 {  // Strong edge
                    edgeCount += 1
                }
            }
        }

        let edgeRatio = Float(edgeCount) / Float(max(pixels.count / 4, 1))
        return edgeRatio * 8.0  // Scale to contribution score
    }

    private func isEyeTransformNormal(_ transform: simd_float4x4) -> Bool {
        // Check if eye transform has valid values
        // Glasses can interfere with eye tracking, causing abnormal transforms

        let position = transform.columns.3

        // Check for NaN or extreme values
        if position.x.isNaN || position.y.isNaN || position.z.isNaN ||
           position.x.isInfinite || position.y.isInfinite || position.z.isInfinite {
            return false
        }

        // Check for reasonable eye position relative to face origin
        // Eyes should be within ~0.1m of face center
        let distance = sqrt(position.x * position.x + position.y * position.y + position.z * position.z)

        if distance > 0.15 || distance < 0.01 {
            return false  // Abnormal eye position
        }

        return true
    }

    // MARK: - Sunburn Detection

    private func detectSunburn(texture: UIImage) -> Bool {
        guard let cgImage = texture.cgImage else { return false }

        // Extract face regions
        let foreheadRegion = cgImage.cropping(to: CGRect(
            x: cgImage.width / 3,
            y: cgImage.height / 6,
            width: cgImage.width / 3,
            height: cgImage.height / 6
        ))

        let cheekRegion = cgImage.cropping(to: CGRect(
            x: cgImage.width / 4,
            y: cgImage.height / 2,
            width: cgImage.width / 6,
            height: cgImage.height / 6
        ))

        guard let forehead = foreheadRegion, let cheek = cheekRegion else { return false }

        // Calculate redness (high R channel relative to G/B)
        let foreheadPixels = extractPixels(from: forehead)
        let cheekPixels = extractPixels(from: cheek)

        let foreheadRedness = calculateRedness(pixels: foreheadPixels)
        let cheekRedness = calculateRedness(pixels: cheekPixels)

        // Sunburn = high redness across multiple regions
        return foreheadRedness > 0.6 && cheekRedness > 0.6
    }

    // MARK: - Hat/Headband Detection

    private func detectHat(texture: UIImage, faceAnchor: ARFaceAnchor) -> Bool {
        guard let cgImage = texture.cgImage else { return false }

        // Strategy 1: Check crown region (top of head, above forehead)
        // Hats/headbands create distinct texture patterns and block face mesh tracking

        let crownRegion = cgImage.cropping(to: CGRect(
            x: cgImage.width / 3,
            y: 0,  // Very top of image
            width: cgImage.width / 3,
            height: cgImage.height / 8  // Just the crown area
        ))

        guard let crown = crownRegion else { return false }

        let crownPixels = extractPixels(from: crown)

        // Characteristics of hat/headband:
        // 1. Very different color from skin (non-skin-tone)
        // 2. High uniformity (fabric vs hair/skin texture)
        // 3. Sharp color boundary with hair/forehead

        let crownVariance = calculateVariance(pixels: crownPixels)
        let crownSaturation = calculateSaturation(pixels: crownPixels)
        let crownBrightnessValues = crownPixels.map { (Float($0.0) + Float($0.1) + Float($0.2)) / 3.0 }
        let sumCrownBrightness = crownBrightnessValues.reduce(0, +)
        let crownBrightness = sumCrownBrightness / Float(max(crownPixels.count, 1))

        // Check for non-skin-tone colors (hats are usually bright, saturated, or very dark)
        let hasNonSkinColor = crownSaturation > 0.4 || crownBrightness > 200 || crownBrightness < 40

        // Low variance = fabric (smooth texture vs hair)
        let hasFabricTexture = crownVariance < 300

        // Strategy 2: Check for missing vertices in crown area (ARKit loses tracking above forehead)
        let geometry = faceAnchor.geometry
        let vertices = geometry.vertices
        let vertexCount = geometry.vertices.count

        var crownVertices = 0
        for i in 0..<vertexCount {
            let vertex = vertices[i]
            if vertex.y > 0.08 {  // Crown region (very top of head)
                crownVertices += 1
            }
        }

        // ARKit face mesh doesn't extend to crown, so very few vertices = likely hat
        let hasCrownCoverage = crownVertices < 50  // Abnormally low vertex count

        // Strategy 3: Check for horizontal edge pattern (headband line)
        let horizontalEdges = detectHorizontalEdge(in: cgImage, yPosition: cgImage.height / 6)

        let hatDetected = (hasNonSkinColor && hasFabricTexture) || hasCrownCoverage || horizontalEdges > 0.3

        if hatDetected {
            AppLogger.metrics.debug("🎩 Hat/headband detected (color: \(hasNonSkinColor), fabric: \(hasFabricTexture), coverage: \(hasCrownCoverage), edges: \(String(format: "%.2f", horizontalEdges)))")
        }

        return hatDetected
    }

    // MARK: - Earring Detection

    private func detectEarrings(texture: UIImage, faceAnchor: ARFaceAnchor) -> Bool {
        guard let cgImage = texture.cgImage else { return false }

        // Strategy: Check ear regions for metallic/non-skin-tone objects
        // Large earrings are typically:
        // 1. Highly saturated (gold, silver = high brightness or saturation)
        // 2. Very different from skin tone
        // 3. Symmetrical (both ears usually)

        let leftEarRegion = cgImage.cropping(to: CGRect(
            x: 0,  // Far left edge
            y: cgImage.height / 3,
            width: cgImage.width / 8,
            height: cgImage.height / 4
        ))

        let rightEarRegion = cgImage.cropping(to: CGRect(
            x: cgImage.width * 7 / 8,  // Far right edge
            y: cgImage.height / 3,
            width: cgImage.width / 8,
            height: cgImage.height / 4
        ))

        guard let leftEar = leftEarRegion, let rightEar = rightEarRegion else { return false }

        let leftPixels = extractPixels(from: leftEar)
        let rightPixels = extractPixels(from: rightEar)

        // Check for metallic/bright spots (jewelry reflections)
        let leftBrightCount = leftPixels.filter { pixel in
            let brightness = (Float(pixel.0) + Float(pixel.1) + Float(pixel.2)) / 3.0
            return brightness > 200  // Very bright = metal reflection
        }.count

        let rightBrightCount = rightPixels.filter { pixel in
            let brightness = (Float(pixel.0) + Float(pixel.1) + Float(pixel.2)) / 3.0
            return brightness > 200
        }.count

        let leftBrightRatio = Float(leftBrightCount) / Float(max(leftPixels.count, 1))
        let rightBrightRatio = Float(rightBrightCount) / Float(max(rightPixels.count, 1))

        // Check for high saturation (colored earrings)
        let leftSaturation = calculateSaturation(pixels: leftPixels)
        let rightSaturation = calculateSaturation(pixels: rightPixels)

        // Earrings detected if:
        // - Both sides have bright spots OR high saturation
        // - Asymmetry is low (both ears usually have earrings)

        let hasBrightSpots = (leftBrightRatio > 0.05 && rightBrightRatio > 0.05)
        let hasHighSaturation = (leftSaturation > 0.35 && rightSaturation > 0.35)

        // Check for color objects (not skin tone)
        let leftBrightnessValues = leftPixels.map { (Float($0.0) + Float($0.1) + Float($0.2)) / 3.0 }
        let sumLeftBrightness = leftBrightnessValues.reduce(0, +)
        let leftAvgBrightness = sumLeftBrightness / Float(max(leftPixels.count, 1))

        let rightBrightnessValues = rightPixels.map { (Float($0.0) + Float($0.1) + Float($0.2)) / 3.0 }
        let sumRightBrightness = rightBrightnessValues.reduce(0, +)
        let rightAvgBrightness = sumRightBrightness / Float(max(rightPixels.count, 1))

        // Very bright or very dark = jewelry
        let hasNonSkinTone = (leftAvgBrightness > 180 || leftAvgBrightness < 60) &&
                             (rightAvgBrightness > 180 || rightAvgBrightness < 60)

        let earringsDetected = hasBrightSpots || hasHighSaturation || hasNonSkinTone

        if earringsDetected {
            AppLogger.metrics.debug("💎 Earrings detected (bright: L=\(String(format: "%.2f", leftBrightRatio)), R=\(String(format: "%.2f", rightBrightRatio)), saturation: L=\(String(format: "%.2f", leftSaturation)), R=\(String(format: "%.2f", rightSaturation)))")
        }

        return earringsDetected
    }

    // MARK: - Helper Methods for Hat Detection

    private func detectHorizontalEdge(in image: CGImage, yPosition: Int) -> Float {
        // Detect horizontal edges (headband line) at specific y position
        let pixels = extractPixels(from: image)
        let width = image.width
        let height = image.height

        guard yPosition > 0 && yPosition < height - 1 else { return 0 }

        var horizontalEdgeCount = 0
        var totalSampled = 0

        // Sample horizontal line
        for x in stride(from: width / 4, to: width * 3 / 4, by: 2) {
            let aboveIdx = (yPosition - 1) * width + x
            let belowIdx = (yPosition + 1) * width + x

            guard aboveIdx >= 0 && belowIdx < pixels.count else { continue }

            let above = (Float(pixels[aboveIdx].0) + Float(pixels[aboveIdx].1) + Float(pixels[aboveIdx].2)) / 3.0
            let below = (Float(pixels[belowIdx].0) + Float(pixels[belowIdx].1) + Float(pixels[belowIdx].2)) / 3.0

            let edgeMagnitude = abs(above - below)

            if edgeMagnitude > 50 {  // Strong horizontal edge
                horizontalEdgeCount += 1
            }

            totalSampled += 1
        }

        return Float(horizontalEdgeCount) / Float(max(totalSampled, 1))
    }

    // MARK: - Helper Methods

    /// OPTIMIZATION: Extract pixels with caching to avoid repeated allocations
    /// If the same image is passed multiple times, returns cached result
    private func extractPixels(from image: CGImage) -> [(UInt8, UInt8, UInt8)] {
        // Check if we have cached pixels for this image
        if let cached = cachedPixelBuffer, cachedImageReference === image {
            return cached
        }

        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return []
        }

        var pixels: [(UInt8, UInt8, UInt8)] = []
        let bytesPerPixel = 4
        let dataLength = CFDataGetLength(data)

        // OPTIMIZATION: Pre-allocate array capacity
        pixels.reserveCapacity(dataLength / bytesPerPixel)

        for i in stride(from: 0, to: dataLength, by: bytesPerPixel) {
            let r = bytes[i]
            let g = bytes[i + 1]
            let b = bytes[i + 2]
            pixels.append((r, g, b))
        }

        // Cache the result
        cachedPixelBuffer = pixels
        cachedImageReference = image

        return pixels
    }

    /// OPTIMIZATION: Extract face region only (center 70% of image)
    /// Reduces processing time by ignoring background
    private func extractFaceRegion(from image: CGImage) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        // Focus on center 70% of image (face area)
        let faceRegion = CGRect(
            x: width * 0.15,
            y: height * 0.15,
            width: width * 0.7,
            height: height * 0.7
        )

        return image.cropping(to: faceRegion)
    }

    /// OPTIMIZATION: Calculate variance using vDSP for faster computation
    private func calculateVariance(pixels: [(UInt8, UInt8, UInt8)]) -> Float {
        guard !pixels.isEmpty else { return 0 }

        // Convert to grayscale Float array
        var grayscale = [Float](repeating: 0, count: pixels.count)
        for (i, pixel) in pixels.enumerated() {
            grayscale[i] = (Float(pixel.0) + Float(pixel.1) + Float(pixel.2)) / 3.0
        }

        // OPTIMIZATION: Use vDSP for mean and variance
        var mean: Float = 0
        vDSP_meanv(grayscale, 1, &mean, vDSP_Length(grayscale.count))

        var normalized = [Float](repeating: 0, count: grayscale.count)
        var negMean = -mean
        vDSP_vsadd(grayscale, 1, &negMean, &normalized, 1, vDSP_Length(grayscale.count))

        var squared = [Float](repeating: 0, count: grayscale.count)
        vDSP_vsq(normalized, 1, &squared, 1, vDSP_Length(grayscale.count))

        var variance: Float = 0
        vDSP_meanv(squared, 1, &variance, vDSP_Length(grayscale.count))

        return variance
    }

    /// OPTIMIZATION: Calculate saturation with reduced loop overhead
    private func calculateSaturation(pixels: [(UInt8, UInt8, UInt8)]) -> Float {
        guard !pixels.isEmpty else { return 0 }

        var totalSaturation: Float = 0

        // Process pixels with simplified calculations
        for pixel in pixels {
            let r = Float(pixel.0)
            let g = Float(pixel.1)
            let b = Float(pixel.2)

            let maxVal = max(r, g, b)
            let minVal = min(r, g, b)

            // Avoid division by checking maxVal > 0
            if maxVal > 0 {
                totalSaturation += (maxVal - minVal) / maxVal
            }
        }

        return totalSaturation / Float(pixels.count)
    }

    /// OPTIMIZATION: Calculate redness with reduced loop overhead
    private func calculateRedness(pixels: [(UInt8, UInt8, UInt8)]) -> Float {
        guard !pixels.isEmpty else { return 0 }

        var totalRedness: Float = 0

        for pixel in pixels {
            let r = Float(pixel.0)
            let sum = r + Float(pixel.1) + Float(pixel.2)

            // Redness = R / (R + G + B)
            if sum > 0 {
                totalRedness += r / sum
            }
        }

        return totalRedness / Float(pixels.count)
    }
}

/// Edge case warning view
public struct EdgeCaseWarningView: View {
    let analysis: EdgeCaseAnalysis
    let onProceed: () -> Void
    let onCancel: () -> Void

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Scan Quality Warning")
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 10) {
                ForEach(analysis.warnings, id: \.self) { warning in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.orange)
                        Text(warning)
                            .font(.body)
                    }
                }
            }
            .padding()

            Text("Recommendations:")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(analysis.recommendations, id: \.self) { rec in
                    HStack(alignment: .top) {
                        Text("•")
                        Text(rec)
                            .font(.subheadline)
                    }
                }
            }
            .padding()

            if analysis.shouldProceed {
                Button(action: onProceed) {
                    Text("Proceed Anyway")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(10)
                }

                Button(action: onCancel) {
                    Text("Cancel & Adjust")
                        .foregroundColor(.blue)
                }
            } else {
                Button(action: onCancel) {
                    Text("OK, I'll Fix This")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
    }
}
