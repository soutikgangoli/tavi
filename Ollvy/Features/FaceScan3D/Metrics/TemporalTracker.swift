//
//  TemporalTracker.swift
//  Ollvy
//
//  Compare scans over time to track skin changes
//  Essential for tracking treatment effectiveness
//

import Foundation
import simd

/// Temporal comparison result
struct TemporalComparison {
    let changesSinceLastScan: [String: Float]  // Metric name -> % change
    let improvementAreas: [String]
    let declineAreas: [String]
    let overallTrend: Trend
    let daysSinceLastScan: Int
}

enum Trend {
    case improving
    case stable
    case declining
}

/// Historical scan record
struct ScanRecord: Codable {
    let date: Date
    let metrics: [String: Float]
    let scanID: String
}

/// Temporal tracker for scan history
class TemporalTracker {

    // MARK: - Storage

    private let userDefaults = UserDefaults.standard
    private let scanHistoryKey = "faceScan3D_scanHistory"

    // MARK: - Public API

    /// Save current scan
    func saveScan(metrics: [String: Float], scanID: String) {
        var history = loadHistory()

        let record = ScanRecord(
            date: Date(),
            metrics: metrics,
            scanID: scanID
        )

        history.append(record)

        // Keep last 50 scans
        if history.count > 50 {
            history = Array(history.suffix(50))
        }

        saveHistory(history)
    }

    /// Compare with previous scan
    func compareWithPrevious(currentMetrics: [String: Float]) -> TemporalComparison? {
        let history = loadHistory()
        guard let lastScan = history.last else { return nil }

        let daysSince = Calendar.current.dateComponents([.day], from: lastScan.date, to: Date()).day ?? 0

        var changes: [String: Float] = [:]
        var improvements: [String] = []
        var declines: [String] = []

        for (metric, currentValue) in currentMetrics {
            if let previousValue = lastScan.metrics[metric] {
                let percentChange = ((currentValue - previousValue) / previousValue) * 100
                changes[metric] = percentChange

                // Higher scores are better for most metrics
                if percentChange > 5 {
                    improvements.append(metric)
                } else if percentChange < -5 {
                    declines.append(metric)
                }
            }
        }

        let overallTrend: Trend
        if improvements.count > declines.count {
            overallTrend = .improving
        } else if declines.count > improvements.count {
            overallTrend = .declining
        } else {
            overallTrend = .stable
        }

        return TemporalComparison(
            changesSinceLastScan: changes,
            improvementAreas: improvements,
            declineAreas: declines,
            overallTrend: overallTrend,
            daysSinceLastScan: daysSince
        )
    }

    /// Get scan history
    func getHistory() -> [ScanRecord] {
        return loadHistory()
    }

    /// Clear history
    func clearHistory() {
        userDefaults.removeObject(forKey: scanHistoryKey)
    }

    // MARK: - Private Methods

    private func loadHistory() -> [ScanRecord] {
        guard let data = userDefaults.data(forKey: scanHistoryKey) else { return [] }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode([ScanRecord].self, from: data)
        } catch {
            AppLogger.metrics.error("⚠️ Failed to load scan history: \(error)")
            return []
        }
    }

    private func saveHistory(_ history: [ScanRecord]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(history)
            userDefaults.set(data, forKey: scanHistoryKey)
        } catch {
            AppLogger.metrics.error("⚠️ Failed to save scan history: \(error)")
        }
    }
}
