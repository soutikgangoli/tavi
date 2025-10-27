//
//  EdgeCaseDetector.swift
//  Tavi
//
//  Edge case detection: facial hair, makeup, glasses, sunburn
//  Warns user when scan accuracy may be affected
//

import Foundation
import UIImage
import ARKit

/// Edge case detection results
public struct EdgeCaseAnalysis {
    let facialHairDetected: Bool
    let facialHairSeverity: Severity
    let makeupDetected: Bool
    let makeupType: MakeupType?
    let glassesDetected: Bool
    let sunburnDetected: Bool
    let warnings: [String]
    let recommendations: [String]
    let shouldProceed: Bool  // false = block scan
}

public enum Severity {
    case none, mild, moderate, severe
}

public enum MakeupType {
    case foundation, heavyFoundation, specialEffects
}

/// Edge case detector
public class EdgeCaseDetector {

    // MARK: - Public API

    /// Detect all edge cases
    public func detectEdgeCases(
        texture: UIImage,
        faceAnchor: ARFaceAnchor
    ) -> EdgeCaseAnalysis {

        var warnings: [String] = []
        var recommendations: [String] = []

        // Facial hair detection
        let (facialHairDetected, facialHairSeverity) = detectFacialHair(texture: texture)
        if facialHairDetected {
            warnings.append(facialHairSeverity == .severe ? "Heavy facial hair detected" : "Facial hair detected")
            recommendations.append("Facial hair may reduce texture analysis accuracy")
        }

        // Makeup detection
        let (makeupDetected, makeupType) = detectMakeup(texture: texture)
        if makeupDetected {
            warnings.append("Makeup detected")
            if makeupType == .heavyFoundation {
                recommendations.append("Heavy makeup may affect texture and pigmentation metrics. Consider scanning without makeup.")
            } else {
                recommendations.append("Light makeup detected - results may be affected")
            }
        }

        // Glasses detection
        let glassesDetected = detectGlasses(faceAnchor: faceAnchor)
        if glassesDetected {
            warnings.append("Glasses detected")
            recommendations.append("Please remove glasses for best results")
        }

        // Sunburn detection
        let sunburnDetected = detectSunburn(texture: texture)
        if sunburnDetected {
            warnings.append("Possible sunburn detected")
            recommendations.append("Wait 48 hours after sunburn for accurate results")
        }

        // Should we proceed?
        let shouldProceed = !glassesDetected && makeupType != .heavyFoundation

        return EdgeCaseAnalysis(
            facialHairDetected: facialHairDetected,
            facialHairSeverity: facialHairSeverity,
            makeupDetected: makeupDetected,
            makeupType: makeupType,
            glassesDetected: glassesDetected,
            sunburnDetected: sunburnDetected,
            warnings: warnings,
            recommendations: recommendations,
            shouldProceed: shouldProceed
        )
    }

    // MARK: - Facial Hair Detection

    private func detectFacialHair(texture: UIImage) -> (Bool, Severity) {
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
        let avgBrightness = pixels.map { Float($0.0 + $0.1 + $0.2) / 3.0 }.reduce(0, +) / Float(max(pixels.count, 1))

        // Calculate texture variance (hair has high variance)
        let variance = calculateVariance(pixels: pixels)

        // Heuristic: dark + high variance = facial hair
        let isDark = avgBrightness < 100
        let hasHighVariance = variance > 500

        if isDark && hasHighVariance {
            // Determine severity based on coverage
            let darkPixelRatio = Float(pixels.filter { Float($0.0 + $0.1 + $0.2) / 3.0 < 80 }.count) / Float(pixels.count)

            let severity: Severity
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

    private func detectGlasses(faceAnchor: ARFaceAnchor) -> Bool {
        // Check for occluded eye regions (glasses block IR tracking)
        let blendShapes = faceAnchor.blendShapes

        // If eyes are consistently not blinking/moving, might be glasses
        if let leftEyeBlink = blendShapes[.eyeBlinkLeft]?.floatValue,
           let rightEyeBlink = blendShapes[.eyeBlinkRight]?.floatValue {

            // Very low blink values for extended time = possible glasses
            // (This is a simplification - would need temporal tracking)
            if leftEyeBlink < 0.05 && rightEyeBlink < 0.05 {
                // Possible glasses, but not conclusive
                return false  // Conservative: don't block
            }
        }

        // Alternative: Check for reflections in texture (more complex)
        // For now, return false unless we have high confidence
        return false
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

    // MARK: - Helper Methods

    private func extractPixels(from image: CGImage) -> [(UInt8, UInt8, UInt8)] {
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return []
        }

        var pixels: [(UInt8, UInt8, UInt8)] = []
        let bytesPerPixel = 4

        for i in stride(from: 0, to: CFDataGetLength(data), by: bytesPerPixel) {
            let r = bytes[i]
            let g = bytes[i + 1]
            let b = bytes[i + 2]
            pixels.append((r, g, b))
        }

        return pixels
    }

    private func calculateVariance(pixels: [(UInt8, UInt8, UInt8)]) -> Float {
        let grayscale = pixels.map { Float($0.0 + $0.1 + $0.2) / 3.0 }
        let avg = grayscale.reduce(0, +) / Float(max(grayscale.count, 1))

        let variance = grayscale.map { pow($0 - avg, 2) }.reduce(0, +) / Float(max(grayscale.count, 1))
        return variance
    }

    private func calculateSaturation(pixels: [(UInt8, UInt8, UInt8)]) -> Float {
        var totalSaturation: Float = 0

        for pixel in pixels {
            let r = Float(pixel.0) / 255.0
            let g = Float(pixel.1) / 255.0
            let b = Float(pixel.2) / 255.0

            let maxVal = max(r, g, b)
            let minVal = min(r, g, b)

            let saturation = maxVal > 0 ? (maxVal - minVal) / maxVal : 0
            totalSaturation += saturation
        }

        return totalSaturation / Float(max(pixels.count, 1))
    }

    private func calculateRedness(pixels: [(UInt8, UInt8, UInt8)]) -> Float {
        var totalRedness: Float = 0

        for pixel in pixels {
            let r = Float(pixel.0)
            let g = Float(pixel.1)
            let b = Float(pixel.2)

            // Redness = R / (R + G + B)
            let sum = r + g + b
            let redness = sum > 0 ? r / sum : 0
            totalRedness += redness
        }

        return totalRedness / Float(max(pixels.count, 1))
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
