//
//  StorageManager.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import CoreData
import CoreGraphics

/// Legacy storage manager - now redirects to PersistenceController for session data
/// Kept for backward compatibility with other app preferences
public class StorageManager {
    public static let shared = StorageManager()

    private let userDefaults = UserDefaults.standard
    private let persistenceController = PersistenceController.shared

    private init() {}

    // MARK: - Session Management (Redirects to Core Data)

    /// Save a new session result to Core Data
    public func saveSession(
        scores: ScoreSummary,
        faceImage: CGImage,
        heatmaps: [HeatmapType: CGImage]?
    ) throws {
        try persistenceController.saveSession(
            scores: scores,
            faceImage: faceImage,
            heatmaps: heatmaps
        )
    }

    /// Fetch all sessions from Core Data
    public func fetchAllSessions() throws -> [SessionResult] {
        return try persistenceController.fetchAllSessions()
    }

    /// Fetch recent sessions with limit
    public func fetchRecentSessions(limit: Int = 10) throws -> [SessionResult] {
        return try persistenceController.fetchRecentSessions(limit: limit)
    }

    /// Delete a specific session
    public func deleteSession(_ session: SessionResult) throws {
        try persistenceController.deleteSession(session)
    }

    // MARK: - UserDefaults (For App Preferences)

    /// Generic save for app preferences (not session data)
    public func save<T: Codable>(_ object: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        userDefaults.set(data, forKey: key)
    }

    /// Generic load for app preferences (not session data)
    public func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }

    /// Delete app preference
    public func delete(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
}
