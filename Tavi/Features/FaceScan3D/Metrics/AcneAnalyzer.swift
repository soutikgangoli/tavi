//
//  AcneAnalyzer.swift
//  Tavi
//
//  Acne and blemish detection using color and texture analysis
//  Detects dark spots, red inflamed areas, and texture irregularities
//

import UIKit
import Accelerate

/// Acne analysis result
public struct AcneAnalysis: Codable {
    let overallScore: Float  // 0-100, higher is better (less acne)
    let blemishCount: Int
    let severity: AcneSeverity
    let blemishes: [Blemish]
    let regionalScores: [String: Float]
}

/// Individual blemish detection
public struct Blemish: Codable {
    let location: String  // "forehead", "cheeks", "chin", etc.
    let type: BlemishType
    let severity: Float  // 0-1
    let size: Float      // in pixels
}

public enum BlemishType: String, Codable {
    case blackhead       // Dark spot
    case whitehead       // Light spot
    case papule          // Red bump
    case pustule         // White/yellow center with redness
    case cyst            // Large, deep lesion
}

public enum AcneSeverity: String, Codable {
    case clear           // 0-5 blemishes
    case mild            // 6-20 blemishes
    case moderate        // 21-50 blemishes
    case severe          // 50+ blemishes

    var score: Float {
        switch self {
        case .clear: return 95
        case .mild: return 75
        case .moderate: return 50
        case .severe: return 25
        }
    }
}

/// Acne analyzer using blob detection and color analysis
public class AcneAnalyzer {

    // MARK: - Configuration

    private let minBlemishSize: Float = 2.0      // pixels
    private let maxBlemishSize: Float = 50.0     // pixels
    private let darknessThreshold: Float = 0.3   // Darker than surrounding
    private let rednessThreshold: Float = 0.15   // More red than surrounding

    // MARK: - Public API

    /// Analyze acne and blemishes from texture
    public func analyzeAcne(texture: UIImage) -> AcneAnalysis {
        print("🔬 Analyzing acne and blemishes...")

        guard let cgImage = texture.cgImage else {
            return AcneAnalysis(
                overallScore: 50,
                blemishCount: 0,
                severity: .clear,
                blemishes: [],
                regionalScores: [:]
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

        // 1. Detect dark spots (blackheads, hyperpigmentation)
        let darkSpots = detectDarkSpots(pixelData: pixelData, width: width, height: height)

        // 2. Detect red inflamed areas (papules, pustules)
        let redSpots = detectRedSpots(pixelData: pixelData, width: width, height: height)

        // 3. Combine and classify
        var blemishes: [Blemish] = []

        for spot in darkSpots {
            blemishes.append(Blemish(
                location: classifyLocation(x: spot.x, y: spot.y, width: width, height: height),
                type: .blackhead,
                severity: spot.intensity,
                size: spot.size
            ))
        }

        for spot in redSpots {
            blemishes.append(Blemish(
                location: classifyLocation(x: spot.x, y: spot.y, width: width, height: height),
                type: .papule,
                severity: spot.intensity,
                size: spot.size
            ))
        }

        // 4. Calculate severity
        let severity = classifySeverity(count: blemishes.count)

        // 5. Calculate regional scores
        let regionalScores = calculateRegionalScores(blemishes: blemishes)

        // 6. Calculate overall score
        let overallScore = calculateOverallScore(
            blemishCount: blemishes.count,
            severity: severity
        )

        print("✅ Acne analysis complete")
        print("   Blemishes detected: \(blemishes.count)")
        print("   Severity: \(severity)")
        print("   Overall score: \(String(format: "%.1f", overallScore))/100")

        return AcneAnalysis(
            overallScore: overallScore,
            blemishCount: blemishes.count,
            severity: severity,
            blemishes: blemishes,
            regionalScores: regionalScores
        )
    }

    // MARK: - Private Methods

    private struct Spot {
        let x: Int
        let y: Int
        let size: Float
        let intensity: Float
    }

    /// Detect dark spots (blackheads, dark marks)
    private func detectDarkSpots(pixelData: [UInt8], width: Int, height: Int) -> [Spot] {
        var spots: [Spot] = []

        // Calculate average luminance
        var totalLuminance: Float = 0
        var pixelCount = 0

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let r = Float(pixelData[index]) / 255.0
                let g = Float(pixelData[index + 1]) / 255.0
                let b = Float(pixelData[index + 2]) / 255.0

                let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                totalLuminance += luminance
                pixelCount += 1
            }
        }

        let avgLuminance = totalLuminance / Float(pixelCount)
        let darkThreshold = avgLuminance - darknessThreshold

        // Find dark regions
        var visited = Array(repeating: Array(repeating: false, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                guard !visited[y][x] else { continue }

                let index = (y * width + x) * 4
                let r = Float(pixelData[index]) / 255.0
                let g = Float(pixelData[index + 1]) / 255.0
                let b = Float(pixelData[index + 2]) / 255.0

                let luminance = 0.299 * r + 0.587 * g + 0.114 * b

                if luminance < darkThreshold {
                    // BFS to find connected component
                    let spot = floodFill(
                        x: x, y: y,
                        width: width, height: height,
                        pixelData: pixelData,
                        visited: &visited,
                        threshold: darkThreshold,
                        isDark: true
                    )

                    if let spot = spot, spot.size >= minBlemishSize && spot.size <= maxBlemishSize {
                        spots.append(spot)
                    }
                }
            }
        }

        return spots
    }

    /// Detect red inflamed spots (papules, pustules)
    private func detectRedSpots(pixelData: [UInt8], width: Int, height: Int) -> [Spot] {
        var spots: [Spot] = []

        // Find red regions (high R, low G/B ratio)
        var visited = Array(repeating: Array(repeating: false, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                guard !visited[y][x] else { continue }

                let index = (y * width + x) * 4
                let r = Float(pixelData[index]) / 255.0
                let g = Float(pixelData[index + 1]) / 255.0
                let b = Float(pixelData[index + 2]) / 255.0

                // Redness = R - (G+B)/2
                let redness = r - (g + b) / 2.0

                if redness > rednessThreshold {
                    // BFS to find connected component
                    let spot = floodFillRed(
                        x: x, y: y,
                        width: width, height: height,
                        pixelData: pixelData,
                        visited: &visited,
                        threshold: rednessThreshold
                    )

                    if let spot = spot, spot.size >= minBlemishSize && spot.size <= maxBlemishSize {
                        spots.append(spot)
                    }
                }
            }
        }

        return spots
    }

    /// Flood fill to find connected dark region
    private func floodFill(
        x: Int, y: Int,
        width: Int, height: Int,
        pixelData: [UInt8],
        visited: inout [[Bool]],
        threshold: Float,
        isDark: Bool
    ) -> Spot? {
        var queue: [(Int, Int)] = [(x, y)]
        var pixels: [(Int, Int)] = []
        var totalIntensity: Float = 0

        while !queue.isEmpty {
            let (cx, cy) = queue.removeFirst()

            guard cx >= 0 && cx < width && cy >= 0 && cy < height else { continue }
            guard !visited[cy][cx] else { continue }

            let index = (cy * width + cx) * 4
            let r = Float(pixelData[index]) / 255.0
            let g = Float(pixelData[index + 1]) / 255.0
            let b = Float(pixelData[index + 2]) / 255.0

            let luminance = 0.299 * r + 0.587 * g + 0.114 * b

            guard luminance < threshold else { continue }

            visited[cy][cx] = true
            pixels.append((cx, cy))
            totalIntensity += (threshold - luminance)

            // Add neighbors
            queue.append((cx + 1, cy))
            queue.append((cx - 1, cy))
            queue.append((cx, cy + 1))
            queue.append((cx, cy - 1))
        }

        guard !pixels.isEmpty else { return nil }

        let avgX = pixels.map { $0.0 }.reduce(0, +) / pixels.count
        let avgY = pixels.map { $0.1 }.reduce(0, +) / pixels.count
        let size = Float(pixels.count)
        let intensity = totalIntensity / Float(pixels.count)

        return Spot(x: avgX, y: avgY, size: size, intensity: intensity)
    }

    /// Flood fill for red regions
    private func floodFillRed(
        x: Int, y: Int,
        width: Int, height: Int,
        pixelData: [UInt8],
        visited: inout [[Bool]],
        threshold: Float
    ) -> Spot? {
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
        let size = Float(pixels.count)
        let intensity = totalRedness / Float(pixels.count)

        return Spot(x: avgX, y: avgY, size: size, intensity: intensity)
    }

    /// Classify location on face
    private func classifyLocation(x: Int, y: Int, width: Int, height: Int) -> String {
        let normalizedY = Float(y) / Float(height)
        let normalizedX = Float(x) / Float(width)

        // Simple heuristic
        if normalizedY < 0.35 {
            return "forehead"
        } else if normalizedY < 0.65 {
            return normalizedX < 0.35 ? "left_cheek" : (normalizedX > 0.65 ? "right_cheek" : "nose")
        } else {
            return "chin"
        }
    }

    /// Classify severity based on count
    private func classifySeverity(count: Int) -> AcneSeverity {
        switch count {
        case 0...5: return .clear
        case 6...20: return .mild
        case 21...50: return .moderate
        default: return .severe
        }
    }

    /// Calculate regional scores
    private func calculateRegionalScores(blemishes: [Blemish]) -> [String: Float] {
        var regionCounts: [String: Int] = [:]

        for blemish in blemishes {
            regionCounts[blemish.location, default: 0] += 1
        }

        var scores: [String: Float] = [:]
        for (region, count) in regionCounts {
            // More blemishes = lower score
            scores[region] = max(0, 100 - Float(count) * 5)
        }

        return scores
    }

    /// Calculate overall acne score
    private func calculateOverallScore(blemishCount: Int, severity: AcneSeverity) -> Float {
        // Fewer blemishes = higher score
        let countScore = max(0, 100 - Float(blemishCount) * 2)

        // Combine with severity
        return (countScore * 0.6 + severity.score * 0.4)
    }
}
