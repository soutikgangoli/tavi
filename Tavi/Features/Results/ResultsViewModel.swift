//
//  ResultsViewModel.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import CoreData
import CoreGraphics
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
            errorMessage = "Unable to load your scan history. Please try again later."
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
            errorMessage = "Unable to load recent scans. Please try again later."
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
            errorMessage = "Unable to delete this scan. Please try again."
            print("Error deleting session: \(error)")
        }
    }

    /// Save a new session after analysis
    func saveSession(
        scores: ScoreSummary,
        faceImage: CGImage,
        heatmaps: [HeatmapType: CGImage]?
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
            errorMessage = "Unable to save your scan results. Please ensure you have enough storage space and try again."
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

