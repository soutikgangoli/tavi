//
//  CoreDataSaveQueue.swift
//  Ollvy
//
//  Persistent queue for failed Core Data saves with automatic retry
//

import Foundation
import CoreData
import Combine
import UIKit

/// Manages persistent queue of failed Core Data saves with automatic retry
@MainActor
public class CoreDataSaveQueue: ObservableObject {
    public static let shared = CoreDataSaveQueue()

    @Published public private(set) var hasPendingSaves: Bool = false
    @Published public private(set) var pendingSaveCount: Int = 0

    private let userDefaultsKey = "com.ollvy.pendingSaves"
    private let maxRetryAttempts = 5
    private var retryTimer: Timer?

    /// Represents a pending save operation
    struct PendingSave: Codable {
        let id: UUID
        let emotionalMetricsJSON: Data
        let clinicalMetricsJSON: Data
        let timestamp: Date
        var retryCount: Int

        init(emotionalMetrics: EmotionalMetrics, clinicalMetrics: Face3DMetrics) throws {
            self.id = UUID()
            self.emotionalMetricsJSON = try JSONEncoder().encode(emotionalMetrics)
            self.clinicalMetricsJSON = try JSONEncoder().encode(clinicalMetrics)
            self.timestamp = Date()
            self.retryCount = 0
        }
    }

    private init() {
        updatePendingSaveStatus()
        startRetryTimer()
    }

    /// Add a failed save to the persistent queue
    public func enqueueSave(emotionalMetrics: EmotionalMetrics, clinicalMetrics: Face3DMetrics) {
        do {
            let pendingSave = try PendingSave(
                emotionalMetrics: emotionalMetrics,
                clinicalMetrics: clinicalMetrics
            )

            var queue = loadQueue()
            queue.append(pendingSave)
            saveQueue(queue)

            AppLogger.faceScan.info("📝 Enqueued failed save to persistent storage (ID: \(pendingSave.id))")

            updatePendingSaveStatus()

            // Attempt immediate retry
            Task {
                await processQueue()
            }
        } catch {
            AppLogger.faceScan.error("❌ Failed to encode metrics for queue: \(error)")
            CrashReporter.shared.logError(error, context: ["operation": "enqueue_save"])
        }
    }

    /// Process all pending saves in the queue
    public func processQueue() async {
        let queue = loadQueue()
        guard !queue.isEmpty else { return }

        AppLogger.faceScan.info("🔄 Processing \(queue.count) pending save(s)...")

        var successfulSaves: [UUID] = []
        var failedSaves: [PendingSave] = []

        for var pendingSave in queue {
            do {
                let emotionalMetrics = try JSONDecoder().decode(EmotionalMetrics.self, from: pendingSave.emotionalMetricsJSON)
                let clinicalMetrics = try JSONDecoder().decode(Face3DMetrics.self, from: pendingSave.clinicalMetricsJSON)

                // Attempt to save
                let success = await attemptSave(
                    emotionalMetrics: emotionalMetrics,
                    clinicalMetrics: clinicalMetrics,
                    originalTimestamp: pendingSave.timestamp
                )

                if success {
                    successfulSaves.append(pendingSave.id)
                    AppLogger.faceScan.info("✅ Successfully saved queued item (ID: \(pendingSave.id))")
                } else {
                    pendingSave.retryCount += 1
                    if pendingSave.retryCount < self.maxRetryAttempts {
                        failedSaves.append(pendingSave)
                        AppLogger.faceScan.warning("⚠️ Save retry failed, will retry again (attempt \(pendingSave.retryCount)/\(self.maxRetryAttempts))")
                    } else {
                        AppLogger.faceScan.error("❌ Max retry attempts reached for save (ID: \(pendingSave.id)), discarding")
                        CrashReporter.shared.logError(
                            NSError(domain: "CoreDataSaveQueue", code: -1, userInfo: [NSLocalizedDescriptionKey: "Max retries exceeded"]),
                            context: ["save_id": pendingSave.id.uuidString, "retry_count": "\(pendingSave.retryCount)"]
                        )
                    }
                }
            } catch {
                AppLogger.faceScan.error("❌ Failed to decode queued save: \(error)")
            }
        }

        // Update queue with only failed items that haven't exceeded retry limit
        await MainActor.run {
            saveQueue(failedSaves)
            updatePendingSaveStatus()

            if !successfulSaves.isEmpty {
                NotificationCenter.default.post(name: .pendingSavesProcessed, object: nil)
            }
        }
    }

    /// Attempt to save to Core Data
    private func attemptSave(
        emotionalMetrics: EmotionalMetrics,
        clinicalMetrics: Face3DMetrics,
        originalTimestamp: Date
    ) async -> Bool {
        // Get the view context from the persistence controller
        let context = PersistenceController.shared.viewContext
        guard context.persistentStoreCoordinator != nil else {
            AppLogger.faceScan.error("❌ Core Data context not available")
            return false
        }

        return await context.perform {
            let session = SessionResult(context: context)
            session.id = UUID()
            session.date = originalTimestamp  // Use original scan timestamp
            session.deviceModel = UIDevice.current.model
            session.deviceOS = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"

            // Save overall and sub-scores
            session.overallScore = Double(emotionalMetrics.skinAppearanceScore)
            session.textureAvg = Double(emotionalMetrics.smoothness)
            session.pigmentationAvg = Double(emotionalMetrics.evenness)
            session.blurQuality = Double(emotionalMetrics.youthfulness)
            session.moistureSpecular = Double(emotionalMetrics.radiance)
            session.moistureSmoothness = Double(emotionalMetrics.freshness)

            // Store full metrics as versioned JSON
            do {
                let emotionalWrapper = try VersionedEmotionalMetrics(metrics: emotionalMetrics)
                let clinicalWrapper = try VersionedFace3DMetrics(metrics: clinicalMetrics)

                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601

                session.emotionalMetricsData = try encoder.encode(emotionalWrapper)
                session.clinicalMetricsData = try encoder.encode(clinicalWrapper)

                AppLogger.faceScan.info("💾 Saved metrics in CoreDataSaveQueue with version \(MetricsVersion.current.versionString)")
            } catch {
                AppLogger.faceScan.error("Failed to encode metrics: \(error)")
                return false
            }

            // Attempt save
            do {
                try context.save()
                #if DEBUG
                AppLogger.faceScan.info("✅ Core Data save successful (from retry queue)")
                #endif
                return true
            } catch {
                #if DEBUG
                AppLogger.faceScan.error("❌ Failed to save to Core Data (from retry queue): \(error.localizedDescription)")
                if let nserror = error as NSError? {
                    AppLogger.faceScan.error("   Domain: \(nserror.domain), Code: \(nserror.code)")
                    AppLogger.faceScan.error("   UserInfo: \(nserror.userInfo)")
                }
                #endif
                return false
            }
        }
    }

    /// Clear all pending saves (use with caution)
    public func clearQueue() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        updatePendingSaveStatus()
        AppLogger.faceScan.info("🗑️ Cleared pending save queue")
    }

    // MARK: - Private Helpers

    private func loadQueue() -> [PendingSave] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([PendingSave].self, from: data)
        } catch {
            AppLogger.faceScan.error("Failed to decode pending saves: \(error)")
            return []
        }
    }

    private func saveQueue(_ queue: [PendingSave]) {
        do {
            let data = try JSONEncoder().encode(queue)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            AppLogger.faceScan.error("Failed to encode pending saves: \(error)")
        }
    }

    private func updatePendingSaveStatus() {
        let queue = loadQueue()
        pendingSaveCount = queue.count
        hasPendingSaves = !queue.isEmpty
    }

    private func startRetryTimer() {
        // Retry every 30 seconds
        // FIXED: Use DispatchQueue.main.asyncAfter with 1ms delay to ensure
        // state updates are deferred to next run loop, avoiding "Publishing changes" warnings
        retryTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                Task {
                    await self?.processQueue()
                }
            }
        }
    }

    deinit {
        retryTimer?.invalidate()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let pendingSavesProcessed = Notification.Name("pendingSavesProcessed")
}
