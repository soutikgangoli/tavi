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

/// Historical scan record with full metric snapshots
struct ScanRecord: Codable {
    let date: Date
    let metrics: [String: Float]
    let scanID: String

    // Core scores for trend tracking (0-100)
    var smoothness: Float?
    var hydration: Float?
    var radiance: Float?
    var evenness: Float?
    var youthfulness: Float?

    // For elasticity calculation
    var wrinkleDepth: Float?
    var wrinkleCount: Int?

    // Optional scores
    var acneScore: Float?
    var rednessScore: Float?
    var poreScore: Float?

    // Default init for backwards compatibility with existing data
    init(date: Date, metrics: [String: Float], scanID: String,
         smoothness: Float? = nil, hydration: Float? = nil, radiance: Float? = nil,
         evenness: Float? = nil, youthfulness: Float? = nil,
         wrinkleDepth: Float? = nil, wrinkleCount: Int? = nil,
         acneScore: Float? = nil, rednessScore: Float? = nil, poreScore: Float? = nil) {
        self.date = date
        self.metrics = metrics
        self.scanID = scanID
        self.smoothness = smoothness
        self.hydration = hydration
        self.radiance = radiance
        self.evenness = evenness
        self.youthfulness = youthfulness
        self.wrinkleDepth = wrinkleDepth
        self.wrinkleCount = wrinkleCount
        self.acneScore = acneScore
        self.rednessScore = rednessScore
        self.poreScore = poreScore
    }
}

/// Temporal tracker for scan history
class TemporalTracker {

    // MARK: - Storage

    private let userDefaults = UserDefaults.standard
    private let scanHistoryKey = "faceScan3D_scanHistory"

    // MARK: - Public API

    /// Save current scan with full metric snapshot
    func saveScan(
        metrics: [String: Float],
        scanID: String,
        smoothness: Float? = nil,
        hydration: Float? = nil,
        radiance: Float? = nil,
        evenness: Float? = nil,
        youthfulness: Float? = nil,
        wrinkleDepth: Float? = nil,
        wrinkleCount: Int? = nil,
        acneScore: Float? = nil,
        rednessScore: Float? = nil,
        poreScore: Float? = nil
    ) {
        var history = loadHistory()

        let record = ScanRecord(
            date: Date(),
            metrics: metrics,
            scanID: scanID,
            smoothness: smoothness,
            hydration: hydration,
            radiance: radiance,
            evenness: evenness,
            youthfulness: youthfulness,
            wrinkleDepth: wrinkleDepth,
            wrinkleCount: wrinkleCount,
            acneScore: acneScore,
            rednessScore: rednessScore,
            poreScore: poreScore
        )

        history.append(record)

        // Keep last 50 scans
        if history.count > 50 {
            history = Array(history.suffix(50))
        }

        saveHistory(history)
        AppLogger.metrics.info("📊 TemporalTracker: Saved scan #\(history.count)")
    }

    /// Get the current scan count
    func getScanCount() -> Int {
        return loadHistory().count
    }

    /// Get historical scans for elasticity calculation
    /// Returns scans with wrinkle depth data for SkinElasticityAnalyzer
    func getHistoricalScansForElasticity() -> [HistoricalScan] {
        let history = loadHistory()

        return history.compactMap { record in
            guard let wrinkleDepth = record.wrinkleDepth else { return nil }
            return HistoricalScan(
                timestamp: record.date.timeIntervalSince1970,
                wrinkleDepth: wrinkleDepth,
                wrinkleCount: record.wrinkleCount ?? 0
            )
        }
    }

    /// Get trend for a specific metric
    /// Returns nil if insufficient data (need at least 2 scans)
    func getTrend(for metricName: String) -> MetricTrend? {
        let history = loadHistory()
        guard history.count >= 2 else { return nil }

        let lastScan = history[history.count - 1]
        let previousScan = history[history.count - 2]

        let daysSince = Calendar.current.dateComponents([.day], from: previousScan.date, to: lastScan.date).day ?? 0

        // Get values based on metric name
        let currentValue: Float?
        let previousValue: Float?

        switch metricName.lowercased() {
        case "smoothness", "texture":
            currentValue = lastScan.smoothness
            previousValue = previousScan.smoothness
        case "hydration", "freshness":
            currentValue = lastScan.hydration
            previousValue = previousScan.hydration
        case "radiance":
            currentValue = lastScan.radiance
            previousValue = previousScan.radiance
        case "evenness", "tone":
            currentValue = lastScan.evenness
            previousValue = previousScan.evenness
        case "youthfulness", "lines", "wrinkles":
            currentValue = lastScan.youthfulness
            previousValue = previousScan.youthfulness
        case "acne":
            currentValue = lastScan.acneScore
            previousValue = previousScan.acneScore
        case "redness":
            currentValue = lastScan.rednessScore
            previousValue = previousScan.rednessScore
        case "pores":
            currentValue = lastScan.poreScore
            previousValue = previousScan.poreScore
        default:
            // Try legacy metrics dictionary
            currentValue = lastScan.metrics[metricName]
            previousValue = previousScan.metrics[metricName]
        }

        guard let current = currentValue, let previous = previousValue, previous > 0 else {
            return nil
        }

        let change = ((current - previous) / previous) * 100  // % change

        let direction: MetricTrend.TrendDirection
        if change > 3 {
            direction = .improving
        } else if change < -3 {
            direction = .declining
        } else {
            direction = .stable
        }

        return MetricTrend(change: change, direction: direction, daysSinceLast: daysSince)
    }

    /// Get trends for all available metrics
    func getAllTrends() -> [String: MetricTrend] {
        var trends: [String: MetricTrend] = [:]

        let metricNames = ["smoothness", "hydration", "radiance", "evenness", "youthfulness", "acne", "redness", "pores"]

        for name in metricNames {
            if let trend = getTrend(for: name) {
                trends[name] = trend
            }
        }

        return trends
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
