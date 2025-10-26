//
//  MetricsComputer.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import CoreGraphics
import Accelerate

/// Computes deterministic skin analysis metrics
public class MetricsComputer {

    private let configuration: MetricsConfiguration

    public init(configuration: MetricsConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Main Computation

    /// Compute all metrics for a set of ROI images
    public func computeMetrics(
        for roiImages: [ExtractedROIImage]
    ) throws -> MetricsResult {
        var roiMetrics: [ROIType: ROIMetrics] = [:]

        // Compute metrics for each ROI
        for roiImage in roiImages {
            let metrics = try computeROIMetrics(for: roiImage.image, type: roiImage.type)
            roiMetrics[roiImage.type] = metrics
        }

        // Compute inter-ROI discoloration
        let discolorationIndex = try computeDiscolorationIndex(roiImages: roiImages)

        return MetricsResult(
            roiMetrics: roiMetrics,
            discolorationIndex: discolorationIndex,
            timestamp: Date()
        )
    }

    // MARK: - Individual Metrics

    /// Compute all metrics for a single ROI
    private func computeROIMetrics(for image: CGImage, type: ROIType) throws -> ROIMetrics {
        let blurScore = try computeBlurScore(image: image)
        let textureEnergy = try computeTextureEnergy(imageROI: image)
        let labVariance = try computeLABVariance(imageROI: image)
        let moistureProxy = try computeMoistureProxy(imageROI: image)

        return ROIMetrics(
            blurScore: blurScore,
            textureEnergy: textureEnergy,
            labVariance: labVariance,
            moistureProxy: moistureProxy,
            roiType: type
        )
    }

    /// Compute Laplacian variance, normalized 0-1
    public func computeBlurScore(image: CGImage) throws -> Double {
        // Use existing ImageProcessing implementation
        let rawScore = ImageProcessing.computeBlurScore(for: image)

        // Normalize to 0-1 range
        let normalized = (rawScore - configuration.minBlur) / (configuration.maxBlur - configuration.minBlur)
        return min(max(normalized, 0.0), 1.0)
    }

    /// Compute high-frequency energy, 0-1
    public func computeTextureEnergy(imageROI: CGImage) throws -> Double {
        let width = imageROI.width
        let height = imageROI.height

        guard width > 0 && height > 0 else {
            throw MetricsError.invalidImageDimensions
        }

        // Extract grayscale pixel data
        let grayscale = try extractGrayscaleData(from: imageROI)

        // Apply high-pass filter (difference from low-pass)
        let highPass = try applyHighPassFilter(grayscale: grayscale, width: width, height: height)

        // Compute energy (sum of squared values)
        var energy: Double = 0.0
        for value in highPass {
            energy += Double(value) * Double(value)
        }

        // Normalize by number of pixels
        energy /= Double(width * height)

        // Normalize to 0-1 range
        let normalized = (energy - configuration.minTextureEnergy) / (configuration.maxTextureEnergy - configuration.minTextureEnergy)
        return min(max(normalized, 0.0), 1.0)
    }

    /// Compute LAB variance (pigmentation unevenness), 0-1
    public func computeLABVariance(imageROI: CGImage) throws -> Double {
        let width = imageROI.width
        let height = imageROI.height

        guard width > 0 && height > 0 else {
            throw MetricsError.invalidImageDimensions
        }

        // Extract pixel data
        guard let pixelData = extractPixelData(from: imageROI) else {
            throw MetricsError.pixelDataExtractionFailed
        }

        // Convert all pixels to LAB
        var labColors: [LABColor] = []
        labColors.reserveCapacity(width * height)

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = pixelData[offset + 2]     // BGRA format
                let g = pixelData[offset + 1]
                let b = pixelData[offset]

                let lab = LABColor(r: r, g: g, b: b)
                labColors.append(lab)
            }
        }

        // Compute mean LAB values
        let meanL = labColors.map { $0.L }.reduce(0, +) / Double(labColors.count)
        let meanA = labColors.map { $0.A }.reduce(0, +) / Double(labColors.count)
        let meanB = labColors.map { $0.B }.reduce(0, +) / Double(labColors.count)

        // Compute variance
        var varianceL: Double = 0
        var varianceA: Double = 0
        var varianceB: Double = 0

        for lab in labColors {
            varianceL += pow(lab.L - meanL, 2)
            varianceA += pow(lab.A - meanA, 2)
            varianceB += pow(lab.B - meanB, 2)
        }

        varianceL /= Double(labColors.count)
        varianceA /= Double(labColors.count)
        varianceB /= Double(labColors.count)

        // Combined variance (Euclidean)
        let totalVariance = sqrt(varianceL + varianceA + varianceB)

        // Normalize to 0-1 range
        let normalized = (totalVariance - configuration.minLABVariance) / (configuration.maxLABVariance - configuration.minLABVariance)
        return min(max(normalized, 0.0), 1.0)
    }

    /// Compute inter-ROI LAB mean variance (discoloration), 0-1
    public func computeDiscolorationIndex(roiImages: [ExtractedROIImage]) throws -> Double {
        guard roiImages.count >= 2 else {
            return 0.0 // Need at least 2 ROIs to compute variance
        }

        // Compute mean LAB for each ROI
        var roiMeans: [(L: Double, A: Double, B: Double)] = []

        for roiImage in roiImages {
            let mean = try computeMeanLAB(image: roiImage.image)
            roiMeans.append(mean)
        }

        // Compute variance of means
        let meanL = roiMeans.map { $0.L }.reduce(0, +) / Double(roiMeans.count)
        let meanA = roiMeans.map { $0.A }.reduce(0, +) / Double(roiMeans.count)
        let meanB = roiMeans.map { $0.B }.reduce(0, +) / Double(roiMeans.count)

        var varianceL: Double = 0
        var varianceA: Double = 0
        var varianceB: Double = 0

        for mean in roiMeans {
            varianceL += pow(mean.L - meanL, 2)
            varianceA += pow(mean.A - meanA, 2)
            varianceB += pow(mean.B - meanB, 2)
        }

        varianceL /= Double(roiMeans.count)
        varianceA /= Double(roiMeans.count)
        varianceB /= Double(roiMeans.count)

        // Combined variance
        let totalVariance = sqrt(varianceL + varianceA + varianceB)

        // Normalize to 0-1 (use same range as LAB variance)
        let normalized = (totalVariance - configuration.minLABVariance) / (configuration.maxLABVariance - configuration.minLABVariance)
        return min(max(normalized, 0.0), 1.0)
    }

    /// Compute moisture proxy metrics
    public func computeMoistureProxy(imageROI: CGImage) throws -> MoistureProxy {
        let width = imageROI.width
        let height = imageROI.height

        guard width > 0 && height > 0 else {
            throw MetricsError.invalidImageDimensions
        }

        // Extract grayscale data
        let grayscale = try extractGrayscaleData(from: imageROI)

        // 1. Specular ratio: percentage of pixels above threshold
        var specularCount = 0
        for value in grayscale {
            if value >= configuration.specularThreshold {
                specularCount += 1
            }
        }
        let specularRatio = Double(specularCount) / Double(grayscale.count)

        // 2. Smoothness (low-frequency): compute after low-pass filter
        let lowPass = try applyLowPassFilter(
            grayscale: grayscale,
            width: width,
            height: height,
            kernelSize: configuration.smoothnessKernelSize
        )

        // Compute variance of low-pass filtered image (lower variance = smoother)
        let mean = lowPass.reduce(0.0, +) / Double(lowPass.count)
        var variance: Double = 0
        for value in lowPass {
            variance += pow(Double(value) - mean, 2)
        }
        variance /= Double(lowPass.count)

        // Normalize smoothness: lower variance = higher smoothness
        // Map variance to 0-1 range (inverse relationship)
        let maxVariance = 1000.0 // Typical max variance for uint8 images
        let smoothness = 1.0 - min(variance / maxVariance, 1.0)

        return MoistureProxy(
            specularRatio: specularRatio,
            smoothnessLowFreq: smoothness
        )
    }

    // MARK: - Helper Methods

    private func computeMeanLAB(image: CGImage) throws -> (L: Double, A: Double, B: Double) {
        let width = image.width
        let height = image.height

        guard let pixelData = extractPixelData(from: image) else {
            throw MetricsError.pixelDataExtractionFailed
        }

        var sumL: Double = 0
        var sumA: Double = 0
        var sumB: Double = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = pixelData[offset + 2]
                let g = pixelData[offset + 1]
                let b = pixelData[offset]

                let lab = LABColor(r: r, g: g, b: b)
                sumL += lab.L
                sumA += lab.A
                sumB += lab.B
            }
        }

        let count = Double(width * height)
        return (L: sumL / count, A: sumA / count, B: sumB / count)
    }

    private func extractGrayscaleData(from image: CGImage) throws -> [UInt8] {
        let width = image.width
        let height = image.height

        guard let pixelData = extractPixelData(from: image) else {
            throw MetricsError.pixelDataExtractionFailed
        }

        var grayscale = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let b = pixelData[offset]
                let g = pixelData[offset + 1]
                let r = pixelData[offset + 2]

                // Rec. 709 coefficients
                let gray = UInt8(0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b))
                grayscale[y * width + x] = gray
            }
        }

        return grayscale
    }

    private func extractPixelData(from image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return pixelData
    }

    private func applyHighPassFilter(grayscale: [UInt8], width: Int, height: Int) throws -> [Double] {
        // First apply low-pass (box filter)
        let lowPass = try applyLowPassFilter(grayscale: grayscale, width: width, height: height, kernelSize: 5)

        // High-pass = original - low-pass
        var highPass = [Double](repeating: 0, count: grayscale.count)
        for i in 0..<grayscale.count {
            highPass[i] = Double(grayscale[i]) - lowPass[i]
        }

        return highPass
    }

    private func applyLowPassFilter(
        grayscale: [UInt8],
        width: Int,
        height: Int,
        kernelSize: Int
    ) throws -> [Double] {
        let halfKernel = kernelSize / 2
        var result = [Double](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                var sum: Double = 0
                var count = 0

                // Box filter
                for ky in -halfKernel...halfKernel {
                    for kx in -halfKernel...halfKernel {
                        let px = x + kx
                        let py = y + ky

                        if px >= 0 && px < width && py >= 0 && py < height {
                            sum += Double(grayscale[py * width + px])
                            count += 1
                        }
                    }
                }

                result[y * width + x] = sum / Double(count)
            }
        }

        return result
    }
}

// MARK: - Errors

public enum MetricsError: Error, LocalizedError {
    case invalidImageDimensions
    case pixelDataExtractionFailed
    case insufficientROIs

    public var errorDescription: String? {
        switch self {
        case .invalidImageDimensions:
            return "Invalid image dimensions for metrics computation"
        case .pixelDataExtractionFailed:
            return "Failed to extract pixel data from image"
        case .insufficientROIs:
            return "Insufficient ROIs for discoloration analysis"
        }
    }
}
