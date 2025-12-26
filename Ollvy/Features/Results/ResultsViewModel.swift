//
//  ResultsViewModel.swift
//  Ollvy
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

        AppLogger.storage.info("📚 Loading all sessions from CoreData...")

        do {
            let loadedSessions = try storageManager.fetchAllSessions()

            // Validate loaded data
            let validSessions = loadedSessions.filter { session in
                validateSession(session)
            }

            // Log validation results
            let invalidCount = loadedSessions.count - validSessions.count
            if invalidCount > 0 {
                AppLogger.storage.warning("⚠️ Filtered out \(invalidCount) invalid sessions")
                CrashReporter.shared.logError(
                    NSError(domain: "DataValidation", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Invalid sessions detected during load"
                    ]),
                    context: [
                        "invalid_count": "\(invalidCount)",
                        "total_count": "\(loadedSessions.count)",
                        "valid_count": "\(validSessions.count)"
                    ]
                )
            }

            sessions = validSessions
            AppLogger.storage.info("✅ Loaded \(validSessions.count) valid sessions (filtered \(invalidCount) invalid)")
            isLoading = false
        } catch {
            errorMessage = "Unable to load your scan history. Please try again later."
            AppLogger.storage.error("❌ Failed to load sessions: \(error.localizedDescription)")
            CrashReporter.shared.logError(error, context: ["operation": "load_sessions"])
            isLoading = false
        }
    }

    /// Load recent sessions with limit
    func loadRecentSessions(limit: Int = 10) {
        isLoading = true
        errorMessage = nil

        AppLogger.storage.info("📚 Loading recent \(limit) sessions from CoreData...")

        do {
            let loadedSessions = try storageManager.fetchRecentSessions(limit: limit)

            // Validate loaded data
            let validSessions = loadedSessions.filter { session in
                validateSession(session)
            }

            // Log validation results
            let invalidCount = loadedSessions.count - validSessions.count
            if invalidCount > 0 {
                AppLogger.storage.warning("⚠️ Filtered out \(invalidCount) invalid sessions from recent load")
                CrashReporter.shared.logError(
                    NSError(domain: "DataValidation", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Invalid sessions detected during recent load"
                    ]),
                    context: [
                        "invalid_count": "\(invalidCount)",
                        "requested_limit": "\(limit)",
                        "total_count": "\(loadedSessions.count)",
                        "valid_count": "\(validSessions.count)"
                    ]
                )
            }

            sessions = validSessions
            AppLogger.storage.info("✅ Loaded \(validSessions.count) valid recent sessions")
            isLoading = false
        } catch {
            errorMessage = "Unable to load recent scans. Please try again later."
            AppLogger.storage.error("❌ Error loading recent sessions: \(error.localizedDescription)")
            CrashReporter.shared.logError(error, context: ["operation": "load_recent_sessions", "limit": "\(limit)"])
            isLoading = false
        }
    }

    /// Delete a specific session
    func deleteSession(_ session: SessionResult) {
        AppLogger.storage.info("🗑️ Attempting to delete session from \(session.formattedDate)")

        do {
            try storageManager.deleteSession(session)
            AppLogger.storage.info("✅ Session deleted successfully")
            loadSessions() // Reload after deletion
        } catch {
            errorMessage = "Unable to delete this scan. Please try again."
            AppLogger.storage.error("❌ Error deleting session: \(error.localizedDescription)")
            CrashReporter.shared.logError(error, context: ["operation": "delete_session", "session_id": session.id.uuidString])
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

        AppLogger.storage.info("📝 Attempting to save session with overall score: \(scores.overallScore)")

        do {
            try storageManager.saveSession(
                scores: scores,
                faceImage: faceImage,
                heatmaps: heatmaps
            )
            AppLogger.storage.info("✅ Session saved successfully to CoreData")

            loadSessions() // Reload to include new session
            AppLogger.storage.info("📚 Sessions reloaded. Total count: \(self.sessions.count)")

            isLoading = false
        } catch {
            let errorMsg = "Unable to save your scan results. Please ensure you have enough storage space and try again."
            errorMessage = errorMsg
            AppLogger.storage.error("❌ Failed to save session: \(error.localizedDescription)")
            AppLogger.storage.error("❌ Error details: \(error)")
            isLoading = false
        }
    }

    /// Get session count
    var sessionCount: Int {
        return sessions.count
    }

    /// Get average score across all sessions
    var averageScore: Double {
        guard !self.sessions.isEmpty else { return 0 }
        let total = self.sessions.reduce(0.0) { $0 + $1.overallScore }
        return total / Double(self.sessions.count)
    }

    /// Get latest session
    var latestSession: SessionResult? {
        return sessions.first
    }

    // MARK: - Private Validation

    /// Validate a session result for data integrity
    /// - Parameter session: The session to validate
    /// - Returns: True if the session is valid, false otherwise
    private func validateSession(_ session: SessionResult) -> Bool {
        var validationErrors: [String] = []

        // Required field validations
        if session.id.uuidString.isEmpty {
            validationErrors.append("missing_id")
        }

        // Date validation - should not be in the future
        if session.date > Date() {
            validationErrors.append("future_date")
        }

        // Date validation - should not be unreasonably old (before 2020)
        if let year2020 = Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 1)),
           session.date < year2020 {
            validationErrors.append("ancient_date")
        }

        // Score validations (0-100 range)
        let scoreFields: [(Double, String)] = [
            (session.overallScore, "overallScore"),
            (session.blurQuality, "blurQuality"),
            (session.textureAvg, "textureAvg"),
            (session.pigmentationAvg, "pigmentationAvg"),
            (session.moistureSpecular, "moistureSpecular"),
            (session.moistureSmoothness, "moistureSmoothness"),
            (session.leftCheekScore, "leftCheekScore"),
            (session.rightCheekScore, "rightCheekScore"),
            (session.foreheadScore, "foreheadScore"),
            (session.chinScore, "chinScore")
        ]

        for (score, fieldName) in scoreFields {
            if score < 0 || score > 100 {
                validationErrors.append("\(fieldName)_out_of_range(\(score))")
            }
            if score.isNaN || score.isInfinite {
                validationErrors.append("\(fieldName)_invalid_number")
            }
        }

        // Discoloration index validation (0-1 range, can be higher in extreme cases)
        if session.discolorationIndex < 0 || session.discolorationIndex > 10 {
            validationErrors.append("discolorationIndex_out_of_range(\(session.discolorationIndex))")
        }

        // Device info validations
        if session.deviceModel.isEmpty {
            validationErrors.append("missing_deviceModel")
        }

        if session.deviceOS.isEmpty {
            validationErrors.append("missing_deviceOS")
        }

        // Log validation failures with details
        if !validationErrors.isEmpty {
            AppLogger.storage.warning("❌ Session validation failed: \(validationErrors.joined(separator: ", "))")
            AppLogger.storage.debug("   Session ID: \(session.id)")
            AppLogger.storage.debug("   Date: \(session.formattedDate)")
            AppLogger.storage.debug("   Overall Score: \(session.overallScore)")
            return false
        }

        return true
    }
}

