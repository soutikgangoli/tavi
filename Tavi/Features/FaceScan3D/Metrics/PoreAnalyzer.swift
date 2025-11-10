//
//  PoreAnalyzer.swift
//  Tavi
//
//  Pore detection and analysis using texture frequency analysis
//  High-frequency texture components indicate visible pores
//

import UIKit
import Accelerate

/// Pore size classification
public enum PoreSize: String, Codable, Sendable {
    case small = "Small"     // < 3 pixels
    case medium = "Medium"   // 3-6 pixels
    case large = "Large"     // > 6 pixels
    case veryLarge = "Very Large"  // > 10 pixels

    public var score: Float {
        switch self {
        case .small: return 90
        case .medium: return 70
        case .large: return 50
        case .veryLarge: return 30
        }
    }
}

/// Pore size distribution
public struct PoreSizeDistribution: Codable, Sendable {
    public let smallCount: Int       // Pores < 3 pixels
    public let mediumCount: Int      // Pores 3-6 pixels
    public let largeCount: Int       // Pores 6-10 pixels
    public let veryLargeCount: Int   // Pores > 10 pixels

    public var totalCount: Int {
        smallCount + mediumCount + largeCount + veryLargeCount
    }

    public var smallPercentage: Float {
        guard totalCount > 0 else { return 0 }
        return Float(smallCount) / Float(totalCount) * 100
    }

    public var mediumPercentage: Float {
        guard totalCount > 0 else { return 0 }
        return Float(mediumCount) / Float(totalCount) * 100
    }

    public var largePercentage: Float {
        guard totalCount > 0 else { return 0 }
        return Float(largeCount) / Float(totalCount) * 100
    }

    public var veryLargePercentage: Float {
        guard totalCount > 0 else { return 0 }
        return Float(veryLargeCount) / Float(totalCount) * 100
    }

    public var dominantSize: PoreSize {
        let counts = [(PoreSize.small, smallCount), (PoreSize.medium, mediumCount),
                      (PoreSize.large, largeCount), (PoreSize.veryLarge, veryLargeCount)]
        return counts.max(by: { $0.1 < $1.1 })?.0 ?? .medium
    }
}

/// Pore analysis result
public struct PoreAnalysis: Codable, Sendable {
    public let visibility: Float  // 0-100, lower is better (inverse)
    public let visibilityScore: Float  // 0-100, higher is better (for consistency with other metrics)
    public let density: Float     // pores per cm²
    public let averageSize: Float // in pixels
    public let sizeDistribution: PoreSizeDistribution  // NEW: Size classification
    public let dominantSize: PoreSize  // NEW: Most common pore size
    public let regionalScores: [String: Float]
    public let confidence: Float  // 0-100, reliability of detection

    public init(visibility: Float, density: Float, averageSize: Float, sizeDistribution: PoreSizeDistribution, regionalScores: [String: Float], confidence: Float) {
        self.visibility = visibility
        self.visibilityScore = 100 - visibility  // Inverse for consistency
        self.density = density
        self.averageSize = averageSize
        self.sizeDistribution = sizeDistribution
        self.dominantSize = sizeDistribution.dominantSize
        self.regionalScores = regionalScores
        self.confidence = confidence
    }
}

/// Pore analyzer using texture frequency analysis
class PoreAnalyzer {

    // MARK: - Public API

    /// Analyze pore visibility from high-resolution texture
    func analyzePores(texture: UIImage) -> PoreAnalysis {
        AppLogger.metrics.info("🔬 Analyzing pore visibility...")

        guard let cgImage = texture.cgImage else {
            AppLogger.metrics.warning("⚠️ Could not extract CGImage from texture")
            return PoreAnalysis(visibility: 0, density: 0, averageSize: 0, regionalScores: [:], confidence: 0)
        }

        // High-frequency texture energy correlates with visible pores
        let highFreqEnergy = calculateHighFrequencyEnergy(image: texture)

        // Detect individual pores using local minima in high-pass filtered image
        let poreDetectionResult = detectPores(image: cgImage)

        // Calculate pore density (pores per cm²)
        // Assume texture covers ~10cm x 10cm of face (approximate)
        let faceAreaCm2: Float = 100.0  // Approximate face area
        let density = Float(poreDetectionResult.poreCount) / faceAreaCm2

        // Calculate average pore size
        let averageSize = poreDetectionResult.averagePoreSize

        // Classify pores by size
        var smallCount = 0
        var mediumCount = 0
        var largeCount = 0
        var veryLargeCount = 0

        for pore in poreDetectionResult.poreLocations {
            if pore.size < 3.0 {
                smallCount += 1
            } else if pore.size < 6.0 {
                mediumCount += 1
            } else if pore.size < 10.0 {
                largeCount += 1
            } else {
                veryLargeCount += 1
            }
        }

        let sizeDistribution = PoreSizeDistribution(
            smallCount: smallCount,
            mediumCount: mediumCount,
            largeCount: largeCount,
            veryLargeCount: veryLargeCount
        )

        // Analyze regional pore distribution
        let regionalScores = analyzeRegionalPores(
            image: cgImage,
            poreLocations: poreDetectionResult.poreLocations
        )

        // Convert to visibility score (0-100)
        let visibility = min(100, highFreqEnergy * 10)

        // Calculate confidence score
        let confidence = calculateConfidence(
            poreCount: poreDetectionResult.poreCount,
            averagePoreSize: averageSize,
            imageResolution: (width: cgImage.width, height: cgImage.height),
            skinBrightness: poreDetectionResult.skinBrightness
        )

        AppLogger.metrics.info("✅ Pore analysis complete:")
        AppLogger.metrics.info("   Visibility: \(String(format: "%.1f", visibility))/100 (Score: \(String(format: "%.1f", 100 - visibility)))")
        AppLogger.metrics.info("   Density: \(String(format: "%.1f", density)) pores/cm²")
        AppLogger.metrics.info("   Avg size: \(String(format: "%.2f", averageSize)) pixels")
        AppLogger.metrics.info("   Size distribution: Small=\(smallCount), Medium=\(mediumCount), Large=\(largeCount), VeryLarge=\(veryLargeCount)")
        AppLogger.metrics.info("   Dominant size: \(sizeDistribution.dominantSize.rawValue)")
        AppLogger.metrics.info("   Confidence: \(String(format: "%.1f", confidence))%")
        AppLogger.metrics.info("   Regional scores: \(regionalScores.count) regions")

        return PoreAnalysis(
            visibility: visibility,
            density: density,
            averageSize: averageSize,
            sizeDistribution: sizeDistribution,
            regionalScores: regionalScores,
            confidence: confidence
        )
    }

    // MARK: - Private Methods

    /// Calculate high-frequency energy (indicates pores)
    private func calculateHighFrequencyEnergy(image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 5 }

        // Convert to grayscale
        let width = cgImage.width
        let height = cgImage.height

        var grayData = [UInt8](repeating: 0, count: width * height)

        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: &grayData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: 0
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Apply high-pass filter to detect high-frequency components
        let floatData = grayData.map { Float($0) / 255.0 }

        // Simple Laplacian operator (high-pass filter)
        var filteredData = [Float](repeating: 0, count: width * height)

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = floatData[y * width + x]
                let top = floatData[(y - 1) * width + x]
                let bottom = floatData[(y + 1) * width + x]
                let left = floatData[y * width + (x - 1)]
                let right = floatData[y * width + (x + 1)]

                // Laplacian: 4*center - (top + bottom + left + right)
                let laplacian = 4 * center - (top + bottom + left + right)
                filteredData[y * width + x] = abs(laplacian)
            }
        }

        // Calculate average energy
        let energy = filteredData.reduce(0, +) / Float(filteredData.count)

        return energy
    }

    // MARK: - Pore Detection

    /// Result of pore detection
    private struct PoreDetectionResult {
        let poreCount: Int
        let averagePoreSize: Float
        let poreLocations: [(x: Int, y: Int, size: Float)]
        let skinBrightness: Float  // For confidence calculation
    }

    /// Detect individual pores using local minima detection
    private func detectPores(image: CGImage) -> PoreDetectionResult {
        let width = image.width
        let height = image.height

        // Convert to grayscale
        var grayData = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &grayData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: 0
        ) else {
            return PoreDetectionResult(poreCount: 0, averagePoreSize: 0, poreLocations: [], skinBrightness: 128.0)
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Apply Gaussian blur to reduce noise
        let blurred = applyGaussianBlur(data: grayData, width: width, height: height)

        // Calculate adaptive darkness threshold based on skin tone
        // This makes pore detection fair across all skin tones (light to dark)
        let avgSkinBrightness = calculateAverageSkinBrightness(data: blurred, width: width, height: height)

        // Pores are typically 20-30% darker than surrounding skin
        // Use LIGHTING-AWARE adaptive multiplier for better accuracy across lighting conditions
        let adaptiveMultiplier = calculateAdaptiveMultiplier(brightness: avgSkinBrightness)
        let minDarkness = UInt8(max(50, min(180, Int(avgSkinBrightness * adaptiveMultiplier))))

        AppLogger.metrics.debug("Adaptive pore threshold: \(minDarkness) (skin brightness: \(avgSkinBrightness))")

        // Detect local minima (dark spots = pores)
        var poreLocations: [(x: Int, y: Int, size: Float)] = []
        let searchRadius = 2  // Search within 2-pixel radius

        for y in stride(from: searchRadius, to: height - searchRadius, by: 3) {
            for x in stride(from: searchRadius, to: width - searchRadius, by: 3) {
                let centerValue = blurred[y * width + x]

                // Check if this is a local minimum (darker than neighbors)
                if centerValue < minDarkness && isLocalMinimum(data: blurred, x: x, y: y, width: width, height: height, radius: searchRadius) {
                    // Estimate pore size by measuring dark region extent
                    let poreSize = measurePoreSize(data: blurred, centerX: x, centerY: y, width: width, height: height)
                    poreLocations.append((x, y, poreSize))
                }
            }
        }

        // Calculate average pore size
        let averageSize: Float = poreLocations.isEmpty ? 0 : poreLocations.map { $0.size }.reduce(0, +) / Float(poreLocations.count)

        return PoreDetectionResult(
            poreCount: poreLocations.count,
            averagePoreSize: averageSize,
            poreLocations: poreLocations,
            skinBrightness: avgSkinBrightness
        )
    }

    /// Calculate average skin brightness for adaptive thresholding
    /// This enables fair pore detection across all skin tones (light to dark)
    private func calculateAverageSkinBrightness(data: [UInt8], width: Int, height: Int) -> Float {
        // Sample center region of face (avoid edges and hair)
        let sampleMinX = width / 3
        let sampleMaxX = width * 2 / 3
        let sampleMinY = height / 3
        let sampleMaxY = height * 2 / 3

        var sum: Float = 0
        var count: Int = 0

        for y in stride(from: sampleMinY, to: sampleMaxY, by: 5) {
            for x in stride(from: sampleMinX, to: sampleMaxX, by: 5) {
                sum += Float(data[y * width + x])
                count += 1
            }
        }

        return count > 0 ? sum / Float(count) : 128.0  // Default to mid-gray if sampling fails
    }

    /// Calculate adaptive multiplier based on lighting conditions
    /// Adjusts pore detection threshold for different lighting scenarios
    private func calculateAdaptiveMultiplier(brightness: Float) -> Float {
        // Optimal lighting: 100-200 brightness → use 0.7 (standard)
        // Too dark: <80 → use 0.6 (more sensitive)
        // Too bright: >220 → use 0.75 (less sensitive)
        if brightness < 80 {
            return 0.6  // Lower threshold for dark conditions
        } else if brightness > 220 {
            return 0.75  // Higher threshold for bright conditions
        } else {
            return 0.7  // Optimal range
        }
    }

    /// Apply Gaussian blur to reduce noise
    private func applyGaussianBlur(data: [UInt8], width: Int, height: Int) -> [UInt8] {
        var blurred = [UInt8](repeating: 0, count: width * height)

        // Simple 3x3 Gaussian kernel
        let kernel: [[Float]] = [
            [1, 2, 1],
            [2, 4, 2],
            [1, 2, 1]
        ]
        let kernelSum: Float = 16.0

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var sum: Float = 0

                for ky in -1...1 {
                    for kx in -1...1 {
                        let pixelValue = Float(data[(y + ky) * width + (x + kx)])
                        sum += pixelValue * kernel[ky + 1][kx + 1]
                    }
                }

                blurred[y * width + x] = UInt8(sum / kernelSum)
            }
        }

        return blurred
    }

    /// Check if pixel is a local minimum
    private func isLocalMinimum(data: [UInt8], x: Int, y: Int, width: Int, height: Int, radius: Int) -> Bool {
        let centerValue = data[y * width + x]

        for dy in -radius...radius {
            for dx in -radius...radius {
                if dx == 0 && dy == 0 { continue }

                let nx = x + dx
                let ny = y + dy

                if nx >= 0 && nx < width && ny >= 0 && ny < height {
                    if data[ny * width + nx] <= centerValue {
                        return false  // Not a minimum
                    }
                }
            }
        }

        return true
    }

    /// Measure pore size by flood-fill like expansion
    private func measurePoreSize(data: [UInt8], centerX: Int, centerY: Int, width: Int, height: Int) -> Float {
        let centerValue = data[centerY * width + centerX]
        let threshold = centerValue + 30  // Pore boundary threshold

        var size: Float = 1.0
        var visited = Set<Int>()
        var queue = [(centerX, centerY)]
        visited.insert(centerY * width + centerX)

        while !queue.isEmpty && size < 100 {  // Limit max pore size to 100 pixels
            let (x, y) = queue.removeFirst()

            for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                let nx = x + dx
                let ny = y + dy

                if nx >= 0 && nx < width && ny >= 0 && ny < height {
                    let index = ny * width + nx
                    if !visited.contains(index) && data[index] < threshold {
                        visited.insert(index)
                        queue.append((nx, ny))
                        size += 1
                    }
                }
            }
        }

        return size
    }

    // MARK: - Regional Analysis

    /// Analyze pore distribution across face regions
    private func analyzeRegionalPores(
        image: CGImage,
        poreLocations: [(x: Int, y: Int, size: Float)]
    ) -> [String: Float] {
        let width = image.width
        let height = image.height

        // Define face regions (normalized coordinates)
        let regions: [String: (minX: Float, maxX: Float, minY: Float, maxY: Float)] = [
            "forehead": (0.3, 0.7, 0.1, 0.3),
            "leftCheek": (0.1, 0.4, 0.4, 0.7),
            "rightCheek": (0.6, 0.9, 0.4, 0.7),
            "nose": (0.4, 0.6, 0.3, 0.6),
            "chin": (0.35, 0.65, 0.7, 0.9)
        ]

        var regionalScores: [String: Float] = [:]

        for (regionName, bounds) in regions {
            // Count pores in this region
            var poreCount = 0
            var totalPoreSize: Float = 0

            for pore in poreLocations {
                let normalizedX = Float(pore.x) / Float(width)
                let normalizedY = Float(pore.y) / Float(height)

                if normalizedX >= bounds.minX && normalizedX <= bounds.maxX &&
                   normalizedY >= bounds.minY && normalizedY <= bounds.maxY {
                    poreCount += 1
                    totalPoreSize += pore.size
                }
            }

            // Calculate region score (lower is better)
            let regionArea = (bounds.maxX - bounds.minX) * (bounds.maxY - bounds.minY)
            let density = Float(poreCount) / (regionArea * 100.0)  // Pores per normalized area
            let avgSize = poreCount > 0 ? totalPoreSize / Float(poreCount) : 0

            // Score: 100 = no pores, 0 = many large pores
            let score = max(0, 100 - (density * 50 + avgSize * 2))
            regionalScores[regionName] = score
        }

        return regionalScores
    }

    // MARK: - Confidence Calculation

    /// Calculate confidence score for pore detection
    /// Factors: image quality, lighting, detection consistency
    private func calculateConfidence(
        poreCount: Int,
        averagePoreSize: Float,
        imageResolution: (width: Int, height: Int),
        skinBrightness: Float
    ) -> Float {
        var confidence: Float = 70.0  // Base confidence for pore detection

        // Factor 1: Image resolution
        let totalPixels = imageResolution.width * imageResolution.height
        if totalPixels >= 1_000_000 {  // 1MP+
            confidence += 10
        } else if totalPixels >= 500_000 {  // 0.5MP+
            confidence += 5
        } else {  // Low resolution
            confidence -= 10
        }

        // Factor 2: Lighting conditions - NOW MORE ACCURATE with adaptive thresholds
        if skinBrightness >= 100 && skinBrightness <= 200 {
            confidence += 15  // Optimal lighting (increased from +10)
        } else if skinBrightness >= 80 && skinBrightness <= 220 {
            confidence += 8   // Good lighting (increased from +5)
        } else if skinBrightness < 60 || skinBrightness > 240 {
            confidence -= 10  // Poor lighting (reduced from -15, since we handle it better)
        } else {
            confidence -= 3   // Suboptimal (reduced from -5)
        }

        // Factor 3: Detection count (more pores = more reliable statistics)
        if poreCount >= 50 {
            confidence += 10  // Good sample size
        } else if poreCount >= 20 {
            confidence += 5   // Adequate sample
        } else if poreCount < 10 {
            confidence -= 15  // Too few pores detected
        }

        // Factor 4: Pore size consistency (should be 2-20 pixels typically)
        if averagePoreSize >= 2 && averagePoreSize <= 20 {
            confidence += 5   // Reasonable pore sizes
        } else if averagePoreSize > 30 {
            confidence -= 10  // Suspiciously large (likely false positives)
        }

        // Clamp to 40-95% range
        // Never 100% confident (texture analysis has inherent limitations)
        // Never below 40% (still provides useful relative information)
        return max(40, min(95, confidence))
    }
}
