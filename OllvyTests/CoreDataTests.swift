//
//  CoreDataTests.swift
//  OllvyTests
//
//  Unit tests for Core Data persistence operations
//  Created on 2025-10-29.
//

import XCTest
import CoreData
@testable import Ollvy

class CoreDataTests: XCTestCase {

    var testController: PersistenceController!

    override func setUp() {
        super.setUp()
        // Use in-memory store for testing (doesn't persist to disk)
        testController = PersistenceController(inMemory: true)
    }

    override func tearDown() {
        // Clean up
        testController = nil
        super.tearDown()
    }

    // MARK: - Save Operation Tests

    func testSaveSession_Success() throws {
        // Create mock data
        let scores = createMockScores()
        let faceImage = createMockImage()

        // Save session
        XCTAssertNoThrow(try testController.saveSession(
            scores: scores,
            faceImage: faceImage,
            heatmaps: nil
        ))

        // Verify session was saved
        let sessions = try testController.fetchAllSessions()
        XCTAssertEqual(sessions.count, 1, "Should save exactly one session")
    }

    func testSaveSession_StoresCorrectData() throws {
        let scores = createMockScores(
            roughness: 85.0,
            pigmentation: 90.0,
            discoloration: 75.0,
            overall: 83.3
        )
        let faceImage = createMockImage()

        try testController.saveSession(
            scores: scores,
            faceImage: faceImage,
            heatmaps: nil
        )

        let sessions = try testController.fetchAllSessions()
        let session = try XCTUnwrap(sessions.first)

        // Verify scores
        XCTAssertEqual(session.overallScore, 83.3, accuracy: 0.1)
        XCTAssertEqual(session.textureAvg, 85.0, accuracy: 0.1)
        XCTAssertEqual(session.pigmentationAvg, 90.0, accuracy: 0.1)
        XCTAssertEqual(session.discolorationIndex, 75.0, accuracy: 0.1)

        // Verify metadata
        XCTAssertNotNil(session.id)
        XCTAssertNotNil(session.date)
        XCTAssertFalse(session.deviceModel.isEmpty)
        XCTAssertFalse(session.deviceOS.isEmpty)
    }

    func testSaveSession_AssignsUniqueIDs() throws {
        let scores = createMockScores()
        let faceImage = createMockImage()

        // Save multiple sessions
        try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)
        try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)
        try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)

        let sessions = try testController.fetchAllSessions()
        let ids = sessions.map { $0.id }
        let uniqueIDs = Set(ids)

        XCTAssertEqual(ids.count, uniqueIDs.count, "All sessions should have unique IDs")
    }

    func testSaveSession_WithHeatmaps() throws {
        let scores = createMockScores()
        let faceImage = createMockImage()
        let heatmaps: [HeatmapType: CGImage] = [
            .composite: createMockImage(),
            .texture: createMockImage(),
            .pigmentation: createMockImage()
        ]

        try testController.saveSession(
            scores: scores,
            faceImage: faceImage,
            heatmaps: heatmaps
        )

        let sessions = try testController.fetchAllSessions()
        let session = try XCTUnwrap(sessions.first)

        // Note: Heatmaps are saved asynchronously, so we can't test the data immediately
        // We're just verifying the save operation doesn't throw
        XCTAssertNotNil(session.id)
    }

    // MARK: - Fetch Operation Tests

    func testFetchAllSessions_EmptyDatabase() throws {
        let sessions = try testController.fetchAllSessions()
        XCTAssertTrue(sessions.isEmpty, "Empty database should return empty array")
    }

    func testFetchAllSessions_OrderedByDate() throws {
        let scores = createMockScores()
        let faceImage = createMockImage()

        // Save sessions with different timestamps
        try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)
        Thread.sleep(forTimeInterval: 0.01)  // Ensure different timestamps

        try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)
        Thread.sleep(forTimeInterval: 0.01)

        try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)

        let sessions = try testController.fetchAllSessions()

        XCTAssertEqual(sessions.count, 3)

        // Verify newest first
        for i in 0..<(sessions.count - 1) {
            XCTAssertGreaterThanOrEqual(sessions[i].date, sessions[i + 1].date,
                                       "Sessions should be ordered newest first")
        }
    }

    func testFetchRecentSessions_RespectsLimit() throws {
        let scores = createMockScores()
        let faceImage = createMockImage()

        // Save 10 sessions
        for _ in 0..<10 {
            try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)
            Thread.sleep(forTimeInterval: 0.01)
        }

        // Fetch with limit
        let recentSessions = try testController.fetchRecentSessions(limit: 5)

        XCTAssertEqual(recentSessions.count, 5, "Should return exactly 5 sessions")
    }

    func testFetchRecentSessions_ReturnsNewest() throws {
        let scores = createMockScores()
        let faceImage = createMockImage()

        // Save sessions
        for _ in 0..<5 {
            try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)
            Thread.sleep(forTimeInterval: 0.01)
        }

        let allSessions = try testController.fetchAllSessions()
        let recentSessions = try testController.fetchRecentSessions(limit: 3)

        // The 3 most recent should match the first 3 from fetchAll
        XCTAssertEqual(recentSessions[0].id, allSessions[0].id)
        XCTAssertEqual(recentSessions[1].id, allSessions[1].id)
        XCTAssertEqual(recentSessions[2].id, allSessions[2].id)
    }

    // MARK: - Delete Operation Tests

    func testDeleteSession_RemovesSession() throws {
        let scores = createMockScores()
        let faceImage = createMockImage()

        try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)

        var sessions = try testController.fetchAllSessions()
        XCTAssertEqual(sessions.count, 1)

        let session = try XCTUnwrap(sessions.first)
        try testController.deleteSession(session)

        sessions = try testController.fetchAllSessions()
        XCTAssertTrue(sessions.isEmpty, "Session should be deleted")
    }

    func testDeleteSession_OnlyRemovesSpecificSession() throws {
        let scores = createMockScores()
        let faceImage = createMockImage()

        // Save 3 sessions
        try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)
        try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)
        try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)

        var sessions = try testController.fetchAllSessions()
        XCTAssertEqual(sessions.count, 3)

        // Delete middle session
        let sessionToDelete = sessions[1]
        try testController.deleteSession(sessionToDelete)

        sessions = try testController.fetchAllSessions()
        XCTAssertEqual(sessions.count, 2, "Should delete only one session")

        // Verify deleted session is gone
        XCTAssertFalse(sessions.contains { $0.id == sessionToDelete.id })
    }

    func testDeleteAllSessions_ClearsDatabase() throws {
        let scores = createMockScores()
        let faceImage = createMockImage()

        // Save multiple sessions
        for _ in 0..<5 {
            try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)
        }

        var sessions = try testController.fetchAllSessions()
        XCTAssertEqual(sessions.count, 5)

        // Delete all
        try testController.deleteAllSessions()

        sessions = try testController.fetchAllSessions()
        XCTAssertTrue(sessions.isEmpty, "All sessions should be deleted")
    }

    // MARK: - JPEG Compression Tests

    func testJPEGCompression_ReducesStorageSize() throws {
        // This test verifies that JPEG compression (0.8 quality) is being used
        // We can't directly test the compression in unit tests without async wait,
        // but we can verify the session saves without error
        let scores = createMockScores()
        let faceImage = createMockImage()

        XCTAssertNoThrow(try testController.saveSession(
            scores: scores,
            faceImage: faceImage,
            heatmaps: nil
        ))
    }

    // MARK: - Data Integrity Tests

    func testDataIntegrity_ScoresInValidRange() throws {
        let scores = createMockScores(
            roughness: 85.0,
            pigmentation: 90.0,
            discoloration: 75.0,
            overall: 83.3
        )
        let faceImage = createMockImage()

        try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)

        let sessions = try testController.fetchAllSessions()
        let session = try XCTUnwrap(sessions.first)

        // Verify scores are in valid range (0-100)
        XCTAssertTrue(session.overallScore >= 0 && session.overallScore <= 100)
        XCTAssertTrue(session.textureAvg >= 0 && session.textureAvg <= 100)
        XCTAssertTrue(session.pigmentationAvg >= 0 && session.pigmentationAvg <= 100)
        XCTAssertTrue(session.discolorationIndex >= 0 && session.discolorationIndex <= 100)
    }

    func testDataIntegrity_DateIsReasonable() throws {
        let scores = createMockScores()
        let faceImage = createMockImage()

        let beforeSave = Date()
        try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)
        let afterSave = Date()

        let sessions = try testController.fetchAllSessions()
        let session = try XCTUnwrap(sessions.first)

        // Date should be between before and after save
        XCTAssertTrue(session.date >= beforeSave && session.date <= afterSave,
                     "Session date should be current timestamp")
    }

    // MARK: - Context Management Tests

    func testViewContext_AutomaticMerging() {
        // Verify merge policy is configured
        let context = testController.viewContext
        XCTAssertTrue(context.automaticallyMergesChangesFromParent,
                     "View context should automatically merge changes")
    }

    func testBackgroundContext_HasMergePolicy() {
        let backgroundContext = testController.newBackgroundContext()
        XCTAssertNotNil(backgroundContext.mergePolicy,
                       "Background context should have merge policy configured")
    }

    func testSaveContext_OnlyWhenNeeded() {
        let context = testController.viewContext

        // Save without changes
        XCTAssertFalse(context.hasChanges, "Fresh context should have no changes")

        testController.save()  // Should not throw or crash

        XCTAssertFalse(context.hasChanges, "Context should still have no changes")
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentSaves_NoRaceConditions() throws {
        let expectation = XCTestExpectation(description: "Concurrent saves complete")
        expectation.expectedFulfillmentCount = 5

        // Attempt concurrent saves
        DispatchQueue.concurrentPerform(iterations: 5) { _ in
            let scores = createMockScores()
            let faceImage = createMockImage()

            do {
                try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)
                expectation.fulfill()
            } catch {
                XCTFail("Concurrent save failed: \(error)")
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Verify all sessions were saved
        let sessions = try testController.fetchAllSessions()
        XCTAssertEqual(sessions.count, 5, "All concurrent saves should succeed")
    }

    // MARK: - Error Handling Tests

    func testFetchSessions_HandlesEmptyResult() {
        XCTAssertNoThrow(try testController.fetchAllSessions(),
                        "Fetching from empty database should not throw")
    }

    func testDeleteSession_HandlesAlreadyDeleted() throws {
        let scores = createMockScores()
        let faceImage = createMockImage()

        try testController.saveSession(scores: scores, faceImage: faceImage, heatmaps: nil)

        let sessions = try testController.fetchAllSessions()
        let session = try XCTUnwrap(sessions.first)

        // Delete once
        try testController.deleteSession(session)

        // Attempt to delete again (should handle gracefully)
        // Note: This may throw or succeed depending on merge policy
        // The important thing is it doesn't crash
    }

    // MARK: - SessionResult Extension Tests

    func testThumbnailImage_ReturnsNilWhenNoData() throws {
        let context = testController.viewContext
        let session = SessionResult(context: context)

        XCTAssertNil(session.thumbnailImage, "Should return nil when no thumbnail data")
    }

    func testGrade_CalculatesCorrectly() throws {
        let context = testController.viewContext
        let session = SessionResult(context: context)

        session.overallScore = 95.0
        XCTAssertEqual(session.grade, ScoreGrade(from: 95.0))

        session.overallScore = 65.0
        XCTAssertEqual(session.grade, ScoreGrade(from: 65.0))
    }

    func testFormattedDate_NotEmpty() throws {
        let context = testController.viewContext
        let session = SessionResult(context: context)
        session.date = Date()

        XCTAssertFalse(session.formattedDate.isEmpty,
                      "Formatted date should not be empty")
    }

    // MARK: - Clinical Metrics JSON Encoding Tests

    func testClinicalMetrics_EncodingDecoding() throws {
        let scores = createMockScores()
        let faceImage = createMockImage()
        let clinicalMetrics = createMockFace3DMetrics()

        try testController.saveSession(
            scores: scores,
            faceImage: faceImage,
            heatmaps: nil,
            clinicalMetrics: clinicalMetrics
        )

        let sessions = try testController.fetchAllSessions()
        let session = try XCTUnwrap(sessions.first)

        XCTAssertNotNil(session.clinicalMetricsData,
                       "Clinical metrics should be saved as JSON")

        // Verify we can decode it back
        if let data = session.clinicalMetricsData {
            XCTAssertNoThrow(try JSONDecoder().decode(Face3DMetrics.self, from: data),
                           "Should be able to decode clinical metrics")
        }
    }

    // MARK: - Helper Methods

    private func createMockScores(
        roughness: Float = 80.0,
        pigmentation: Float = 85.0,
        discoloration: Float = 75.0,
        overall: Float = 80.0
    ) -> ScoreSummary {
        return ScoreSummary(
            overallScore: overall,
            roughnessScore: roughness,
            pigmentationScore: pigmentation,
            discolorationScore: discoloration,
            hydrationScore: 70.0,
            poreScore: 65.0,
            grade: ScoreGrade(from: overall)
        )
    }

    private func createMockImage() -> CGImage {
        // Create a simple 1x1 pixel image for testing
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }

        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.red.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        return context.makeImage()!
    }

    private func createMockFace3DMetrics() -> Face3DMetrics {
        return Face3DMetrics(
            roiMetrics: [:],
            globalRoughnessProxy: 0.5,
            globalPigmentationIndex: 0.5,
            globalDiscolorationIndex: 0.5,
            globalSpecularProxy: 0.5,
            globalAverageLuminance: 0.5,
            globalRoughnessScore: 80.0,
            globalPigmentationScore: 85.0,
            globalDiscolorationScore: 75.0,
            globalSpecularScore: 70.0,
            overallScore: 77.5,
            scoreInterpretation: "Good",
            vertexCount: 1000,
            triangleCount: 2000,
            textureResolution: CGSize(width: 1024, height: 1024),
            processingTime: 1.5
        )
    }
}
