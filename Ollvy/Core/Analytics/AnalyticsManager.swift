//
//  AnalyticsManager.swift
//  Ollvy
//
//  Local analytics tracking with future server upload capability
//  Created on 2025-01-04
//

import Foundation
import SwiftUI
import UIKit
import os.log

/// Event tracking manager for user behavior analytics
@MainActor
public class AnalyticsManager {
    public static let shared = AnalyticsManager()

    @AppStorage(AppDefaultsKey.analyticsEnabled) private var isEnabled: Bool = true

    private let logger = Logger(subsystem: "com.ollvy.app", category: "Analytics")
    private let eventQueue = DispatchQueue(label: "com.ollvy.analytics", qos: .utility)
    private var eventStorage: [AnalyticsEvent] = []

    private init() {
        loadStoredEvents()
    }

    // MARK: - Event Tracking

    /// Track a generic event
    public func trackEvent(_ name: String, parameters: [String: String]? = nil) {
        guard isEnabled else { return }

        let event = AnalyticsEvent(
            name: name,
            parameters: parameters,
            timestamp: Date()
        )

        logger.info("📊 Event: \(name), params: \(parameters?.description ?? "{}")")

        saveEvent(event)
    }

    /// Track screen view
    public func trackScreen(_ screenName: String) {
        trackEvent("screen_view", parameters: ["screen": screenName])
    }

    /// Track performance timing
    public func trackTiming(_ metric: String, duration: TimeInterval, context: [String: String]? = nil) {
        var params = context ?? [:]
        params["metric"] = metric
        params["duration_ms"] = String(format: "%.0f", duration * 1000)

        trackEvent("performance_timing", parameters: params)
    }

    /// Track error occurrence
    public func trackError(_ error: Error, context: String, metadata: [String: String]? = nil) {
        var params = metadata ?? [:]
        params["error"] = error.localizedDescription
        params["context"] = context
        params["error_type"] = String(describing: type(of: error))

        trackEvent("error_occurred", parameters: params)
    }

    /// Track user action
    public func trackAction(_ action: String, target: String? = nil, value: String? = nil) {
        var params: [String: String] = ["action": action]
        if let target = target { params["target"] = target }
        if let value = value { params["value"] = value }

        trackEvent("user_action", parameters: params)
    }

    // MARK: - Scan Lifecycle Events

    /// Track scan started
    public func trackScanStarted(scanType: String = "face_3d") {
        trackEvent("scan_started", parameters: ["scan_type": scanType])
    }

    /// Track scan completed successfully
    public func trackScanCompleted(duration: TimeInterval, poseCount: Int, score: Double) {
        trackEvent("scan_completed", parameters: [
            "duration_seconds": String(format: "%.1f", duration),
            "pose_count": String(poseCount),
            "score": String(format: "%.1f", score)
        ])
    }

    /// Track scan failed
    public func trackScanFailed(reason: String, duration: TimeInterval) {
        trackEvent("scan_failed", parameters: [
            "reason": reason,
            "duration_seconds": String(format: "%.1f", duration)
        ])
    }

    /// Track scan retry
    public func trackScanRetry(attempt: Int, reason: String) {
        trackEvent("scan_retry", parameters: [
            "attempt": String(attempt),
            "reason": reason
        ])
    }

    // MARK: - Navigation Events

    /// Track navigation action
    public func trackNavigation(from: String, to: String, method: String = "tap") {
        trackEvent("navigation", parameters: [
            "from": from,
            "to": to,
            "method": method
        ])
    }

    // MARK: - Settings Events

    /// Track setting changed
    public func trackSettingChanged(setting: String, value: String, previousValue: String? = nil) {
        var params = [
            "setting": setting,
            "value": value
        ]
        if let prev = previousValue {
            params["previous_value"] = prev
        }

        trackEvent("setting_changed", parameters: params)
    }

    // MARK: - Performance Metrics

    /// Start performance timer
    public func startTimer(_ name: String) -> PerformanceTimer {
        return PerformanceTimer(name: name, manager: self)
    }

    // MARK: - Storage

    private func saveEvent(_ event: AnalyticsEvent) {
        eventQueue.async { [weak self] in
            guard let self = self else { return }

            // Add to in-memory queue
            Task { @MainActor in
                self.eventStorage.append(event)

                // Persist to disk
                self.persistEvents()

                // Trim old events (keep last 1000)
                if self.eventStorage.count > 1000 {
                    self.eventStorage.removeFirst(self.eventStorage.count - 1000)
                }
            }
        }
    }

    private func persistEvents() {
        do {
            let encoded = try JSONEncoder().encode(eventStorage)
            UserDefaults.standard.set(encoded, forKey: AppDefaultsKey.analyticsEvents)
            logger.debug("💾 Persisted \(self.eventStorage.count) events to storage")
        } catch {
            logger.error("Failed to encode analytics events: \(error)")
            CrashReporter.shared.logError(error, context: ["operation": "json_encode_analytics"])
        }
    }

    private func loadStoredEvents() {
        guard let data = UserDefaults.standard.data(forKey: AppDefaultsKey.analyticsEvents) else {
            return
        }

        do {
            let events = try JSONDecoder().decode([AnalyticsEvent].self, from: data)
            eventStorage = events
            logger.info("📂 Loaded \(events.count) stored events")
        } catch {
            logger.error("Failed to decode analytics events: \(error)")
            CrashReporter.shared.logError(error, context: ["operation": "json_decode_analytics"])
        }
    }

    // MARK: - Future Server Upload

    /// Get all events for upload (can be called by future upload service)
    public func getEventsForUpload() -> [AnalyticsEvent] {
        return eventStorage
    }

    /// Clear events after successful upload
    public func clearUploadedEvents(before date: Date) {
        eventStorage.removeAll { $0.timestamp < date }
        persistEvents()
        logger.info("🗑️ Cleared events before \(date)")
    }

    /// Prepare events for JSON upload to server
    public func prepareForUpload() -> Data? {
        let uploadPayload = AnalyticsUploadPayload(
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            events: eventStorage
        )

        do {
            return try JSONEncoder().encode(uploadPayload)
        } catch {
            logger.error("Failed to encode analytics upload payload: \(error)")
            CrashReporter.shared.logError(error, context: ["operation": "json_encode_analytics_upload"])
            return nil
        }
    }
}

// MARK: - Models

/// Analytics event model
public struct AnalyticsEvent: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let parameters: [String: String]?
    public let timestamp: Date

    public init(name: String, parameters: [String: String]?, timestamp: Date) {
        self.id = UUID()
        self.name = name
        self.parameters = parameters
        self.timestamp = timestamp
    }
}

/// Upload payload structure (for future server upload)
struct AnalyticsUploadPayload: Codable {
    let deviceId: String
    let appVersion: String
    let events: [AnalyticsEvent]
    let uploadTimestamp: Date

    init(deviceId: String, appVersion: String, events: [AnalyticsEvent]) {
        self.deviceId = deviceId
        self.appVersion = appVersion
        self.events = events
        self.uploadTimestamp = Date()
    }
}

/// Performance timer helper
public class PerformanceTimer {
    private let name: String
    private let startTime: Date
    private weak var manager: AnalyticsManager?

    init(name: String, manager: AnalyticsManager) {
        self.name = name
        self.manager = manager
        self.startTime = Date()
    }

    public func stop(context: [String: String]? = nil) {
        let duration = Date().timeIntervalSince(startTime)
        Task { @MainActor in
            manager?.trackTiming(name, duration: duration, context: context)
        }
    }
}
