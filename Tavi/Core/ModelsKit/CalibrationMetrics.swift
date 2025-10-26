//
//  CalibrationMetrics.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation

public struct CalibrationMetrics {
    /// Average luminance (luma) value normalized to 0-1
    public let averageLuma: Double

    /// Histogram values (256 bins for grayscale)
    public let histogram: [Int]

    /// Total number of pixels
    public let totalPixels: Int

    public init(averageLuma: Double, histogram: [Int], totalPixels: Int) {
        self.averageLuma = averageLuma
        self.histogram = histogram
        self.totalPixels = totalPixels
    }

    /// Check if histogram is clipped (>1% of pixels at extreme values)
    public var isHistogramClipped: Bool {
        let threshold = Double(totalPixels) * 0.01 // 1% threshold

        // Check first 5 bins (shadows)
        let shadowClipping = histogram.prefix(5).reduce(0, +)
        if Double(shadowClipping) > threshold {
            return true
        }

        // Check last 5 bins (highlights)
        let highlightClipping = histogram.suffix(5).reduce(0, +)
        if Double(highlightClipping) > threshold {
            return true
        }

        return false
    }

    /// Determine calibration status based on metrics
    public var calibrationStatus: CalibrationStatus {
        // Check luma range first
        if averageLuma < 0.35 || averageLuma > 0.65 {
            return .tooLow
        }

        // Check histogram clipping
        if isHistogramClipped {
            return .clipped
        }

        return .good
    }
}

public enum CalibrationStatus {
    case tooLow      // Luma out of range
    case clipped     // Histogram clipped
    case good        // Ready to calibrate

    public var color: String {
        switch self {
        case .tooLow:
            return "red"
        case .clipped:
            return "yellow"
        case .good:
            return "green"
        }
    }

    public var message: String {
        switch self {
        case .tooLow:
            return "Lighting too dark or too bright"
        case .clipped:
            return "Histogram clipped - adjust lighting"
        case .good:
            return "Ready to calibrate"
        }
    }
}
