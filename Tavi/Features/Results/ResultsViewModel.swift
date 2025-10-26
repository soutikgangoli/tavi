//
//  ResultsViewModel.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import CoreData
import Combine

@MainActor
class ResultsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var sessions: [SessionResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let storageManager = StorageManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        loadSessions()
    }

    // MARK: - Public Methods

    /// Load all sessions from Core Data
    func loadSessions() {
        isLoading = true
        errorMessage = nil

        do {
            sessions = try storageManager.fetchAllSessions()
            isLoading = false
        } catch {
            errorMessage = "Failed to load sessions: \(error.localizedDescription)"
            isLoading = false
            print("Error loading sessions: \(error)")
        }
    }

    /// Load recent sessions with limit
    func loadRecentSessions(limit: Int = 10) {
        isLoading = true
        errorMessage = nil

        do {
            sessions = try storageManager.fetchRecentSessions(limit: limit)
            isLoading = false
        } catch {
            errorMessage = "Failed to load sessions: \(error.localizedDescription)"
            isLoading = false
            print("Error loading sessions: \(error)")
        }
    }

    /// Delete a specific session
    func deleteSession(_ session: SessionResult) {
        do {
            try storageManager.deleteSession(session)
            loadSessions() // Reload after deletion
        } catch {
            errorMessage = "Failed to delete session: \(error.localizedDescription)"
            print("Error deleting session: \(error)")
        }
    }

    /// Save a new session after analysis
    func saveSession(
        scores: ScoreSummary,
        faceImage: CGImage,
        heatmaps: [HeatmapMetric: CGImage]?
    ) {
        isLoading = true
        errorMessage = nil

        do {
            try storageManager.saveSession(
                scores: scores,
                faceImage: faceImage,
                heatmaps: heatmaps
            )
            loadSessions() // Reload to include new session
            isLoading = false
        } catch {
            errorMessage = "Failed to save session: \(error.localizedDescription)"
            isLoading = false
            print("Error saving session: \(error)")
        }
    }

    /// Get session count
    var sessionCount: Int {
        return sessions.count
    }

    /// Get average score across all sessions
    var averageScore: Double {
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.reduce(0.0) { $0 + $1.overallScore }
        return total / Double(sessions.count)
    }

    /// Get latest session
    var latestSession: SessionResult? {
        return sessions.first
    }
}

