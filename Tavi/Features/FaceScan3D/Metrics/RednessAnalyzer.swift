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
    let inflam​medAreas: [InflammedRegion]
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

    private let rednessThreshold: Float = 0.12    // R - (G+B)/2 threshold
    private let moderateThreshold: Float = 0.20
    private let severeThreshold: Float = 0.30

    // MARK: - Public API

    /// Analyze redness and inflammation from texture
    public func analyzeRedness(texture: UIImage) -> RednessAnalysis {
        print("🔬 Analyzing redness and inflammation...")

        guard let cgImage = texture.cgImage else {
            return RednessAnalysis(
                overallScore: 50,
                rednessLevel: .mild,
                globalRedness: 0.1,
                regionalRedness: [:],
                inflamedAreas: []
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

        // 1. Calculate global redness
        let globalRedness = calculateGlobalRedness(pixelData: pixelData, width: width, height: height)

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

        print("✅ Redness analysis complete")
        print("   Global redness: \(String(format: "%.3f", globalRedness))")
        print("   Level: \(rednessLevel)")
        print("   Inflamed areas: \(inflamedAreas.count)")
        print("   Overall score: \(String(format: "%.1f", overallScore))/100")

        return RednessAnalysis(
            overallScore: overallScore,
            rednessLevel: rednessLevel,
            globalRedness: globalRedness,
            regionalRedness: regionalRedness,
            inflamedAreas: inflamedAreas
        )
    }

    // MARK: - Private Methods

    /// Calculate global average redness
    private func calculateGlobalRedness(pixelData: [UInt8], width: Int, height: Int) -> Float {
        var totalRedness: Float = 0
        var pixelCount = 0

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let r = Float(pixelData[index]) / 255.0
                let g = Float(pixelData[index + 1]) / 255.0
                let b = Float(pixelData[index + 2]) / 255.0

                // Redness index = R - (G+B)/2
                // Positive values indicate more red
                let redness = r - (g + b) / 2.0

                if redness > 0 {
                    totalRedness += redness
                    pixelCount += 1
                }
            }
        }

        return pixelCount > 0 ? totalRedness / Float(pixelCount) : 0
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

    /// Classify redness level
    private func classifyRednessLevel(globalRedness: Float) -> RednessLevel {
        if globalRedness < rednessThreshold {
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
}
