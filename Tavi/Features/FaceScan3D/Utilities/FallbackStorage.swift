//
//  FallbackStorage.swift
//  Tavi
//
//  Fallback JSON-based storage when Core Data is unavailable
//

import Foundation
import UIKit

/// Manages fallback JSON storage when Core Data is unavailable
@MainActor
public class FallbackStorage: ObservableObject {
    public static let shared = FallbackStorage()

    @Published public private(set) var isUsingFallback: Bool = false
    @Published public private(set) var fallbackSessionCount: Int = 0

    private let fallbackDirectory: URL
    private let sessionListFile: URL

    /// Represents a session saved to fallback storage
    public struct FallbackSession: Codable, Identifiable, Sendable {
        public let id: UUID
        public let date: Date
        public let deviceModel: String
        public let deviceOS: String
        public let emotionalMetrics: EmotionalMetrics
        public let clinicalMetrics: Face3DMetrics

        /// Overall score (mapped from glow score for compatibility with SessionResult)
        /// Returns Double to match SessionResult's type (Core Data uses Double for scores)
        public var overallScore: Double {
            return Double(emotionalMetrics.glowScore)
        }

        /// Relative date string (e.g., "Today", "Yesterday", "3 days ago")
        public var relativeDate: String {
            let calendar = Calendar.current
            let now = Date()

            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                let components = calendar.dateComponents([.day], from: date, to: now)
                if let days = components.day, days < 7 {
                    return "\(days) days ago"
                } else {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    return formatter.string(from: date)
                }
            }
        }

        @MainActor
        public init(
            id: UUID = UUID(),
            date: Date = Date(),
            emotionalMetrics: EmotionalMetrics,
            clinicalMetrics: Face3DMetrics
        ) {
            self.id = id
            self.date = date
            self.deviceModel = UIDevice.current.model
            self.deviceOS = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
            self.emotionalMetrics = emotionalMetrics
            self.clinicalMetrics = clinicalMetrics
        }
    }

    private init() {
        // Create fallback directory in Documents
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fallbackDirectory = documentsPath.appendingPathComponent("TaviFallbackStorage", isDirectory: true)
        self.sessionListFile = fallbackDirectory.appendingPathComponent("sessions.json")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: fallbackDirectory, withIntermediateDirectories: true)

        updateFallbackStatus()
    }

    /// Check if Core Data is available
    public func isCoreDataAvailable() -> Bool {
        let context = PersistenceController.shared.viewContext
        return context.persistentStoreCoordinator != nil
    }

    /// Update fallback status
    private func updateFallbackStatus() {
        isUsingFallback = !isCoreDataAvailable()
        fallbackSessionCount = loadAllSessions().count

        if isUsingFallback {
            AppLogger.storage.warning("⚠️ Core Data unavailable - using fallback JSON storage")
        }
    }

    /// Save session to fallback storage
    public func saveSession(emotionalMetrics: EmotionalMetrics, clinicalMetrics: Face3DMetrics) throws {
        let session = FallbackSession(
            emotionalMetrics: emotionalMetrics,
            clinicalMetrics: clinicalMetrics
        )

        // Load existing sessions
        var sessions = loadAllSessions()

        // Add new session
        sessions.insert(session, at: 0)  // Insert at beginning (most recent)

        // Keep only last 100 sessions to avoid excessive storage
        if sessions.count > 100 {
            sessions = Array(sessions.prefix(100))
        }

        // Save to file
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(sessions)
        try data.write(to: sessionListFile, options: .atomic)

        // Also save individual session file for redundancy
        let sessionFile = fallbackDirectory.appendingPathComponent("\(session.id.uuidString).json")
        try data.write(to: sessionFile, options: .atomic)

        updateFallbackStatus()

        AppLogger.storage.info("✅ Saved session to fallback storage: \(session.id)")
    }

    /// Load all sessions from fallback storage
    public func loadAllSessions() -> [FallbackSession] {
        guard FileManager.default.fileExists(atPath: sessionListFile.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: sessionListFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sessions = try decoder.decode([FallbackSession].self, from: data)
            return sessions
        } catch {
            AppLogger.storage.error("Failed to load fallback sessions: \(error)")
            return []
        }
    }

    /// Migrate fallback data to Core Data when it becomes available
    public func migrateToCoreDataIfPossible() async -> Int {
        // Check if Core Data is now available
        guard isCoreDataAvailable() else {
            AppLogger.storage.info("Core Data still unavailable - cannot migrate")
            return 0
        }

        let sessions = loadAllSessions()
        guard !sessions.isEmpty else {
            return 0
        }

        AppLogger.storage.info("🔄 Migrating \(sessions.count) sessions from fallback to Core Data...")

        var migratedCount = 0
        let context = PersistenceController.shared.viewContext

        for session in sessions {
            let success = await context.perform {
                let coreDataSession = SessionResult(context: context)
                coreDataSession.id = session.id
                coreDataSession.date = session.date
                coreDataSession.deviceModel = session.deviceModel
                coreDataSession.deviceOS = session.deviceOS

                // Copy scores
                coreDataSession.overallScore = Double(session.emotionalMetrics.glowScore)
                coreDataSession.textureAvg = Double(session.emotionalMetrics.smoothness)
                coreDataSession.pigmentationAvg = Double(session.emotionalMetrics.evenness)
                coreDataSession.blurQuality = Double(session.emotionalMetrics.youthfulness)
                coreDataSession.moistureSpecular = Double(session.emotionalMetrics.radiance)
                coreDataSession.moistureSmoothness = Double(session.emotionalMetrics.freshness)

                // Encode metrics with versioning
                do {
                    let emotionalWrapper = try VersionedEmotionalMetrics(metrics: session.emotionalMetrics)
                    let clinicalWrapper = try VersionedFace3DMetrics(metrics: session.clinicalMetrics)

                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601

                    coreDataSession.emotionalMetricsData = try encoder.encode(emotionalWrapper)
                    coreDataSession.clinicalMetricsData = try encoder.encode(clinicalWrapper)

                    try context.save()
                    AppLogger.storage.info("💾 Migrated session \(session.id) to Core Data with version \(MetricsVersion.current.versionString)")
                    return true
                } catch {
                    AppLogger.storage.error("Failed to migrate session \(session.id): \(error)")
                    return false
                }
            }

            if success {
                migratedCount += 1
            }
        }

        // Clear fallback storage after successful migration
        if migratedCount == sessions.count {
            clearAllSessions()
            AppLogger.storage.info("✅ Successfully migrated all \(migratedCount) sessions to Core Data")
        } else {
            AppLogger.storage.warning("⚠️ Partially migrated \(migratedCount)/\(sessions.count) sessions")
        }

        updateFallbackStatus()
        return migratedCount
    }

    /// Export fallback data to shareable JSON file
    public func exportToFile() throws -> URL {
        let sessions = loadAllSessions()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(sessions)

        // Create export file in temp directory
        let tempDir = FileManager.default.temporaryDirectory
        let exportFile = tempDir.appendingPathComponent("tavi_backup_\(Date().timeIntervalSince1970).json")

        try data.write(to: exportFile, options: .atomic)

        AppLogger.storage.info("✅ Exported \(sessions.count) sessions to: \(exportFile.path)")
        return exportFile
    }

    /// Import sessions from backup file
    public func importFromFile(url: URL) throws -> Int {
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let importedSessions = try decoder.decode([FallbackSession].self, from: data)

        // Merge with existing sessions (avoiding duplicates by ID)
        var existingSessions = loadAllSessions()
        let existingIDs = Set(existingSessions.map { $0.id })

        let newSessions = importedSessions.filter { !existingIDs.contains($0.id) }
        existingSessions.append(contentsOf: newSessions)

        // Sort by date (most recent first)
        existingSessions.sort { $0.date > $1.date }

        // Keep only last 100
        if existingSessions.count > 100 {
            existingSessions = Array(existingSessions.prefix(100))
        }

        // Save merged list
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let mergedData = try encoder.encode(existingSessions)
        try mergedData.write(to: sessionListFile, options: .atomic)

        updateFallbackStatus()

        AppLogger.storage.info("✅ Imported \(newSessions.count) new sessions from backup")
        return newSessions.count
    }

    /// Clear all fallback sessions
    public func clearAllSessions() {
        try? FileManager.default.removeItem(at: fallbackDirectory)
        try? FileManager.default.createDirectory(at: fallbackDirectory, withIntermediateDirectories: true)
        updateFallbackStatus()
        AppLogger.storage.info("🗑️ Cleared all fallback storage")
    }

    /// Get storage statistics
    public func getStorageInfo() -> (sessionCount: Int, storageSize: Int64, isUsingFallback: Bool) {
        let sessions = loadAllSessions()

        var totalSize: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: fallbackDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }

        return (sessions.count, totalSize, isUsingFallback)
    }
}
