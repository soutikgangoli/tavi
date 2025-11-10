//
//  RednessAnalyzer.swift
//  Tavi
//
//  Inflammation and redness detection using red channel analysis
//  Detects overall redness, regional inflammation, and rosacea indicators
//

import UIKit
import Accelerate

/// Redness analysis result
public struct RednessAnalysis: Codable, Sendable {
    let overallScore: Float  // 0-100, higher is better (less red)
    let rednessLevel: RednessLevel
    let globalRedness: Float  // 0-1, average redness index
    let regionalRedness: [String: Float]  // Per-region redness (0-1)
    let inflamedAreas: [InflammedRegion]
    let confidence: Float  // 0-100, measurement confidence
    let detectionMethod: String  // "redness" or "darkening" (for dark skin)
}

/// Individual inflamed region
public struct InflammedRegion: Codable, Sendable {
    let location: String
    let severity: Float  // 0-1
    let area: Float      // in pixels
}

public enum RednessLevel: String, Codable, Sendable {
    case minimal         // Very little redness
    case mild            // Some redness, normal
    case moderate        // Noticeable redness
    case severe          // Significant inflammation

    var score: Float {
        switch self {
        case .minimal: return 95
        case .mild: return 75
        case .moderate: return 50
        case .severe: return 25
        }
    }
}

/// Redness analyzer using red channel analysis
public class RednessAnalyzer {

    // MARK: - Configuration

    private let adaptiveMultiplier: Float = 1.5    // Multiplier for relative detection (skin-tone adaptive)
    private let moderateThreshold: Float = 0.20
    private let severeThreshold: Float = 0.30
    private let skinToneNormalizer = SkinToneNormalizer()

    // MARK: - Public API

    /// Analyze redness and inflammation from texture
    /// IMPROVED: Detects inflammation on darker skin (appears as darkening, not redness)
    public func analyzeRedness(texture: UIImage) -> RednessAnalysis {
        AppLogger.metrics.info("🔬 Analyzing redness and inflammation...")

        guard let cgImage = texture.cgImage else {
            return RednessAnalysis(
                overallScore: 50,
                rednessLevel: .mild,
                globalRedness: 0.1,
                regionalRedness: [:],
                inflamedAreas: [],
                confidence: 0,  // No confidence when image unavailable
                detectionMethod: "none"
            )
        }

        // Convert to RGB data
        let width = cgImage.width
        let height = cgImage.height

        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Detect skin tone for adaptive inflammation detection
        let skinTone = skinToneNormalizer.detectSkinTone(texture: texture)

        // 1. Calculate global redness (skin-tone aware)
        let globalRedness = calculateGlobalRedness(pixelData: pixelData, width: width, height: height, skinTone: skinTone)

        // 2. Calculate regional redness
        let regionalRedness = calculateRegionalRedness(pixelData: pixelData, width: width, height: height)

        // 3. Detect inflamed areas
        let inflamedAreas = detectInflammedAreas(pixelData: pixelData, width: width, height: height)

        // 4. Classify redness level
        let rednessLevel = classifyRednessLevel(globalRedness: globalRedness)

        // 5. Calculate overall score
        let overallScore = calculateOverallScore(
            globalRedness: globalRedness,
            inflamedAreaCount: inflamedAreas.count
        )

        // 6. Calculate confidence based on detection method and consistency
        let useDarkeningDetection = (skinTone == .dark || skinTone == .veryDark || skinTone == .mediumDark)
        let detectionMethodStr = useDarkeningDetection ? "darkening" : "redness"

        let confidence: Float = {
            var conf: Float = 65.0

            // Darkening method (for dark skin) slightly less reliable
            if useDarkeningDetection {
                conf -= 10
            }

            // High consistency across regions = higher confidence
            if !regionalRedness.isEmpty {
                let values = Array(regionalRedness.values)
                let avg = values.reduce(0, +) / Float(values.count)
                let variance = values.map { pow($0 - avg, 2) }.reduce(0, +) / Float(values.count)
                if variance < 0.01 { conf += 15 }  // Very consistent
            }

            // Inflamed area detection adds confidence
            if inflamedAreas.count > 0 && inflamedAreas.count < 20 {
                conf += 10  // Reasonable number of detections
            }

            return max(50, min(90, conf))
        }()

        AppLogger.metrics.info("✅ Redness analysis complete")
        AppLogger.metrics.info("   Global redness: \(String(format: "%.3f", globalRedness))")
        AppLogger.metrics.info("   Level: \(rednessLevel)")
        AppLogger.metrics.info("   Inflamed areas: \(inflamedAreas.count)")
        AppLogger.metrics.info("   Overall score: \(String(format: "%.1f", overallScore))/100")
        AppLogger.metrics.info("   Confidence: \(String(format: "%.1f", confidence))% (\(detectionMethodStr) method)")

        return RednessAnalysis(
            overallScore: overallScore,
            rednessLevel: rednessLevel,
            globalRedness: globalRedness,
            regionalRedness: regionalRedness,
            inflamedAreas: inflamedAreas,
            confidence: confidence,
            detectionMethod: detectionMethodStr
        )
    }

    // MARK: - Private Methods

    /// Calculate global average redness using skin-tone adaptive threshold
    /// IMPROVED: For darker skin, inflammation appears as darkening (not redness)
    private func calculateGlobalRedness(pixelData: [UInt8], width: Int, height: Int, skinTone: SkinToneCategory) -> Float {
        // STEP 1: Calculate baseline skin tone (average RGB in center region)
        let baselineRGB = calculateBaselineSkinTone(pixelData: pixelData, width: width, height: height)
        let baselineRedness = baselineRGB.r - (baselineRGB.g + baselineRGB.b) / 2.0
        let baselineBrightness = (baselineRGB.r + baselineRGB.g + baselineRGB.b) / 3.0

        // STEP 2: Use RELATIVE threshold (adaptive to skin tone)
        let adaptiveThreshold = max(0.08, baselineRedness * adaptiveMultiplier)

        var totalInflammation: Float = 0
        var pixelCount = 0

        // SKIN-TONE AWARE: Dark skin inflammation detection
        let useDarkeningDetection = (skinTone == .dark || skinTone == .veryDark || skinTone == .mediumDark)

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let r = Float(pixelData[index]) / 255.0
                let g = Float(pixelData[index + 1]) / 255.0
                let b = Float(pixelData[index + 2]) / 255.0

                if useDarkeningDetection {
                    // For dark skin: inflammation = localized darkening
                    let brightness = (r + g + b) / 3.0
                    let relativeDarkness = baselineBrightness - brightness

                    // Inflammation shows as areas significantly darker than baseline
                    if relativeDarkness > 0.10 {  // 10% darker = inflammation
                        totalInflammation += relativeDarkness
                        pixelCount += 1
                    }
                } else {
                    // For light skin: standard red-based detection
                    let redness = r - (g + b) / 2.0
                    let relativeRedness = redness - baselineRedness

                    if relativeRedness > adaptiveThreshold {
                        totalInflammation += relativeRedness
                        pixelCount += 1
                    }
                }
            }
        }

        return pixelCount > 0 ? totalInflammation / Float(pixelCount) : 0
    }

    /// Calculate redness per facial region
    private func calculateRegionalRedness(pixelData: [UInt8], width: Int, height: Int) -> [String: Float] {
        var regionalRedness: [String: (total: Float, count: Int)] = [:]

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let r = Float(pixelData[index]) / 255.0
                let g = Float(pixelData[index + 1]) / 255.0
                let b = Float(pixelData[index + 2]) / 255.0

                let redness = r - (g + b) / 2.0

                if redness > 0 {
                    let region = classifyLocation(x: x, y: y, width: width, height: height)
                    let current = regionalRedness[region, default: (0, 0)]
                    regionalRedness[region] = (current.total + redness, current.count + 1)
                }
            }
        }

        return regionalRedness.mapValues { $0.count > 0 ? $0.total / Float($0.count) : 0 }
    }

    /// Detect highly inflamed areas
    private func detectInflammedAreas(pixelData: [UInt8], width: Int, height: Int) -> [InflammedRegion] {
        var inflamedAreas: [InflammedRegion] = []
        var visited = Array(repeating: Array(repeating: false, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                guard !visited[y][x] else { continue }

                let index = (y * width + x) * 4
                let r = Float(pixelData[index]) / 255.0
                let g = Float(pixelData[index + 1]) / 255.0
                let b = Float(pixelData[index + 2]) / 255.0

                let redness = r - (g + b) / 2.0

                // Only consider significantly red areas
                if redness > moderateThreshold {
                    // BFS to find connected inflamed region
                    let area = floodFillInflamed(
                        x: x, y: y,
                        width: width, height: height,
                        pixelData: pixelData,
                        visited: &visited,
                        threshold: moderateThreshold
                    )

                    if let area = area, area.area >= 20 {  // Minimum 20 pixels
                        inflamedAreas.append(area)
                    }
                }
            }
        }

        return inflamedAreas
    }

    /// Flood fill to find connected inflamed region
    private func floodFillInflamed(
        x: Int, y: Int,
        width: Int, height: Int,
        pixelData: [UInt8],
        visited: inout [[Bool]],
        threshold: Float
    ) -> InflammedRegion? {
        var queue: [(Int, Int)] = [(x, y)]
        var pixels: [(Int, Int)] = []
        var totalRedness: Float = 0

        while !queue.isEmpty {
            let (cx, cy) = queue.removeFirst()

            guard cx >= 0 && cx < width && cy >= 0 && cy < height else { continue }
            guard !visited[cy][cx] else { continue }

            let index = (cy * width + cx) * 4
            let r = Float(pixelData[index]) / 255.0
            let g = Float(pixelData[index + 1]) / 255.0
            let b = Float(pixelData[index + 2]) / 255.0

            let redness = r - (g + b) / 2.0

            guard redness > threshold else { continue }

            visited[cy][cx] = true
            pixels.append((cx, cy))
            totalRedness += redness

            // Add neighbors
            queue.append((cx + 1, cy))
            queue.append((cx - 1, cy))
            queue.append((cx, cy + 1))
            queue.append((cx, cy - 1))
        }

        guard !pixels.isEmpty else { return nil }

        let avgX = pixels.map { $0.0 }.reduce(0, +) / pixels.count
        let avgY = pixels.map { $0.1 }.reduce(0, +) / pixels.count
        let area = Float(pixels.count)
        let severity = totalRedness / Float(pixels.count)

        let location = classifyLocation(x: avgX, y: avgY, width: width, height: height)

        return InflammedRegion(location: location, severity: severity, area: area)
    }

    /// Classify location on face
    private func classifyLocation(x: Int, y: Int, width: Int, height: Int) -> String {
        let normalizedY = Float(y) / Float(height)
        let normalizedX = Float(x) / Float(width)

        if normalizedY < 0.35 {
            return "forehead"
        } else if normalizedY < 0.65 {
            if normalizedX < 0.35 {
                return "left_cheek"
            } else if normalizedX > 0.65 {
                return "right_cheek"
            } else {
                return "nose"
            }
        } else {
            return "chin"
        }
    }

    /// Classify redness level (using relative thresholds)
    private func classifyRednessLevel(globalRedness: Float) -> RednessLevel {
        // Adaptive thresholds based on relative redness
        let minimalThreshold: Float = 0.05

        if globalRedness < minimalThreshold {
            return .minimal
        } else if globalRedness < moderateThreshold {
            return .mild
        } else if globalRedness < severeThreshold {
            return .moderate
        } else {
            return .severe
        }
    }

    /// Calculate overall redness score
    private func calculateOverallScore(globalRedness: Float, inflamedAreaCount: Int) -> Float {
        // Less redness = higher score
        let rednessScore = max(0, 100 - (globalRedness * 500))

        // Fewer inflamed areas = higher score
        let areaScore = max(0, 100 - Float(inflamedAreaCount) * 10)

        return (rednessScore * 0.7 + areaScore * 0.3)
    }

    /// Calculate baseline skin tone from center region (avoids edges, hair)
    private func calculateBaselineSkinTone(pixelData: [UInt8], width: Int, height: Int) -> (r: Float, g: Float, b: Float) {
        // Sample center region (avoid edges, hair)
        let centerX = width / 2
        let centerY = height / 2
        let sampleRadius = min(width, height) / 4

        var rSum: Float = 0, gSum: Float = 0, bSum: Float = 0
        var count = 0

        for y in max(0, centerY - sampleRadius)..<min(height, centerY + sampleRadius) {
            for x in max(0, centerX - sampleRadius)..<min(width, centerX + sampleRadius) {
                let index = (y * width + x) * 4
                rSum += Float(pixelData[index]) / 255.0
                gSum += Float(pixelData[index + 1]) / 255.0
                bSum += Float(pixelData[index + 2]) / 255.0
                count += 1
            }
        }

        return count > 0 ? (rSum / Float(count), gSum / Float(count), bSum / Float(count)) : (0.5, 0.5, 0.5)
    }
}
