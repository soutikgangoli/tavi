//
//  ScanErrorTests.swift
//  TaviTests
//
//  Unit tests for comprehensive ScanError handling
//  Created on 2025-10-29.
//

import XCTest
@testable import Tavi

class ScanErrorTests: XCTestCase {

    // MARK: - Error Description Tests

    func testErrorDescription_LightingTooLow() {
        let error = ScanError.lightingTooLow(current: 0.15, required: 0.30)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("15%"),
                     "Should show current lighting percentage")
        XCTAssertTrue(error.errorDescription!.contains("30%"),
                     "Should show required lighting percentage")
    }

    func testErrorDescription_LightingTooHigh() {
        let error = ScanError.lightingTooHigh(current: 0.95, max: 0.90)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("95%"),
                     "Should show current lighting percentage")
        XCTAssertTrue(error.errorDescription!.contains("90%"),
                     "Should show max allowed percentage")
    }

    func testErrorDescription_BlurryImage() {
        let error = ScanError.blurryImage(score: 0.42)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("0.4") || error.errorDescription!.contains("blurry"),
                     "Should mention blur score or blurriness")
    }

    func testErrorDescription_OccludedFace() {
        let error = ScanError.occludedFace(regions: ["forehead", "left cheek"])

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("forehead"),
                     "Should list occluded regions")
        XCTAssertTrue(error.errorDescription!.contains("left cheek"),
                     "Should list all occluded regions")
    }

    func testErrorDescription_InsufficientStorage() {
        let error = ScanError.insufficientStorage(required: 50_000_000, available: 10_000_000)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("50.0") || error.errorDescription!.contains("MB"),
                     "Should show required storage in MB")
        XCTAssertTrue(error.errorDescription!.contains("10.0"),
                     "Should show available storage in MB")
    }

    func testErrorDescription_ProcessingTimeout() {
        let error = ScanError.processingTimeout(operation: "mesh_merge", seconds: 45.0)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("45"),
                     "Should show timeout duration")
        XCTAssertTrue(error.errorDescription!.contains("mesh_merge"),
                     "Should show operation that timed out")
    }

    // MARK: - Recovery Suggestion Tests

    func testRecoverySuggestion_CameraUnavailable() {
        let error = ScanError.cameraUnavailable

        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("Settings"),
                     "Should suggest checking Settings")
    }

    func testRecoverySuggestion_TrueDepthUnsupported() {
        let error = ScanError.trueDepthUnsupported

        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("iPhone") && error.recoverySuggestion!.contains("Face ID"),
                     "Should mention device requirements")
    }

    func testRecoverySuggestion_LightingTooLow() {
        let error = ScanError.lightingTooLow(current: 0.15, required: 0.30)

        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("brighter") || error.recoverySuggestion!.contains("light"),
                     "Should suggest improving lighting")
    }

    func testRecoverySuggestion_BlurryImage() {
        let error = ScanError.blurryImage(score: 0.42)

        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("steady") || error.recoverySuggestion!.contains("stable"),
                     "Should suggest holding device steady")
    }

    func testRecoverySuggestion_InsufficientStorage() {
        let error = ScanError.insufficientStorage(required: 50_000_000, available: 10_000_000)

        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("delete") || error.recoverySuggestion!.contains("free up"),
                     "Should suggest freeing up space")
    }

    // MARK: - Identifiable Tests

    func testIdentifiable_UniqueIDs() {
        let errors: [ScanError] = [
            .arSessionFailed(underlying: nil),
            .cameraUnavailable,
            .trueDepthUnsupported,
            .faceNotDetected,
            .multipleFacesDetected,
            .cancelled,
            .lightingTooLow(current: 0.2, required: 0.3),
            .lightingTooHigh(current: 0.95, max: 0.9),
            .blurryImage(score: 0.5),
            .occludedFace(regions: ["forehead"]),
            .invalidExpression(issues: ["smiling"]),
            .mergeFailed(reason: nil),
            .bakeFailed(reason: nil),
            .metricsFailed(analyzer: nil, reason: nil),
            .processingTimeout(operation: "test", seconds: 30),
            .invalidData(field: "test"),
            .coreDataSaveFailed(underlying: NSError(domain: "test", code: 0)),
            .insufficientStorage(required: 1000, available: 500),
            .corruptedData(entity: "test"),
            .processingError("test")
        ]

        let ids = errors.map { $0.id }
        let uniqueIDs = Set(ids)

        XCTAssertEqual(ids.count, uniqueIDs.count,
                      "All error cases should have unique IDs")
    }

    func testIdentifiable_ConsistentIDs() {
        // Same error type should return same ID
        let error1 = ScanError.lightingTooLow(current: 0.2, required: 0.3)
        let error2 = ScanError.lightingTooLow(current: 0.1, required: 0.3)

        XCTAssertEqual(error1.id, error2.id,
                      "Same error type should have consistent ID regardless of associated values")
    }

    func testIdentifiable_IDFormat() {
        // IDs should be snake_case strings
        let error = ScanError.arSessionFailed(underlying: nil)

        XCTAssertEqual(error.id, "ar_session_failed")
        XCTAssertTrue(error.id.contains("_"), "ID should use snake_case")
        XCTAssertTrue(error.id.lowercased() == error.id, "ID should be lowercase")
    }

    // MARK: - Error Classification Tests

    func testRecoverable_NonRecoverableErrors() {
        let nonRecoverable: [ScanError] = [
            .trueDepthUnsupported,
            .coreDataSaveFailed(underlying: NSError(domain: "test", code: 0)),
            .corruptedData(entity: "test")
        ]

        for error in nonRecoverable {
            XCTAssertFalse(error.isRecoverable,
                          "\(error.id) should not be recoverable")
        }
    }

    func testRecoverable_RecoverableErrors() {
        let recoverable: [ScanError] = [
            .faceNotDetected,
            .lightingTooLow(current: 0.2, required: 0.3),
            .lightingTooHigh(current: 0.95, max: 0.9),
            .blurryImage(score: 0.5),
            .occludedFace(regions: ["forehead"]),
            .invalidExpression(issues: ["smiling"]),
            .mergeFailed(reason: nil),
            .bakeFailed(reason: nil),
            .processingTimeout(operation: "test", seconds: 30)
        ]

        for error in recoverable {
            XCTAssertTrue(error.isRecoverable,
                         "\(error.id) should be recoverable")
        }
    }

    func testRecoverable_CancelledIsRecoverable() {
        let error = ScanError.cancelled

        XCTAssertTrue(error.isRecoverable,
                     "Cancelled error should be recoverable (user can retry)")
    }

    func testBlockingError_BlocksScanning() {
        let blocking: [ScanError] = [
            .trueDepthUnsupported,
            .cameraUnavailable,
            .multipleFacesDetected
        ]

        for error in blocking {
            XCTAssertTrue(error.isBlockingError,
                         "\(error.id) should block scan from starting")
        }
    }

    func testBlockingError_NonBlocking() {
        let nonBlocking: [ScanError] = [
            .faceNotDetected,
            .lightingTooLow(current: 0.2, required: 0.3),
            .blurryImage(score: 0.5),
            .mergeFailed(reason: nil),
            .processingTimeout(operation: "test", seconds: 30)
        ]

        for error in nonBlocking {
            XCTAssertFalse(error.isBlockingError,
                          "\(error.id) should not block scan")
        }
    }

    // MARK: - Associated Values Tests

    func testAssociatedValues_LightingTooLow() {
        let error = ScanError.lightingTooLow(current: 0.25, required: 0.35)

        if case .lightingTooLow(let current, let required) = error {
            XCTAssertEqual(current, 0.25, accuracy: 0.001)
            XCTAssertEqual(required, 0.35, accuracy: 0.001)
        } else {
            XCTFail("Should be lightingTooLow case")
        }
    }

    func testAssociatedValues_OccludedFace() {
        let regions = ["forehead", "nose", "chin"]
        let error = ScanError.occludedFace(regions: regions)

        if case .occludedFace(let occludedRegions) = error {
            XCTAssertEqual(occludedRegions.count, 3)
            XCTAssertTrue(occludedRegions.contains("forehead"))
            XCTAssertTrue(occludedRegions.contains("nose"))
            XCTAssertTrue(occludedRegions.contains("chin"))
        } else {
            XCTFail("Should be occludedFace case")
        }
    }

    func testAssociatedValues_MetricsFailed() {
        let error = ScanError.metricsFailed(analyzer: "RoughnessAnalyzer", reason: "Insufficient data")

        if case .metricsFailed(let analyzer, let reason) = error {
            XCTAssertEqual(analyzer, "RoughnessAnalyzer")
            XCTAssertEqual(reason, "Insufficient data")
        } else {
            XCTFail("Should be metricsFailed case")
        }
    }

    func testAssociatedValues_OptionalDefaults() {
        // Test that optional associated values can be nil
        let error1 = ScanError.mergeFailed(reason: nil)
        let error2 = ScanError.metricsFailed(analyzer: nil, reason: nil)

        if case .mergeFailed(let reason) = error1 {
            XCTAssertNil(reason, "Reason should be nil")
        } else {
            XCTFail("Should be mergeFailed case")
        }

        if case .metricsFailed(let analyzer, let reason) = error2 {
            XCTAssertNil(analyzer, "Analyzer should be nil")
            XCTAssertNil(reason, "Reason should be nil")
        } else {
            XCTFail("Should be metricsFailed case")
        }
    }

    // MARK: - Error Message Quality Tests

    func testErrorMessages_AreUserFriendly() {
        // All error descriptions should be understandable by non-technical users
        let errors: [ScanError] = [
            .faceNotDetected,
            .lightingTooLow(current: 0.2, required: 0.3),
            .blurryImage(score: 0.5),
            .mergeFailed(reason: nil)
        ]

        for error in errors {
            let description = error.errorDescription ?? ""

            // Should not contain technical jargon
            XCTAssertFalse(description.contains("null pointer") || description.contains("exception"),
                          "\(error.id): Description should be user-friendly")

            // Should be capitalized
            XCTAssertTrue(description.first?.isUppercase ?? false,
                         "\(error.id): Description should start with capital letter")

            // Should end with period
            XCTAssertTrue(description.hasSuffix(".") || description.hasSuffix("?") || description.hasSuffix("!"),
                         "\(error.id): Description should end with punctuation")
        }
    }

    func testErrorMessages_AreActionable() {
        // Recovery suggestions should provide clear actions
        let errors: [ScanError] = [
            .cameraUnavailable,
            .lightingTooLow(current: 0.2, required: 0.3),
            .blurryImage(score: 0.5),
            .insufficientStorage(required: 50_000_000, available: 10_000_000)
        ]

        for error in errors {
            let suggestion = error.recoverySuggestion ?? ""

            // Should not be empty
            XCTAssertFalse(suggestion.isEmpty,
                          "\(error.id): Should have recovery suggestion")

            // Should contain action verbs
            let actionVerbs = ["move", "turn", "hold", "remove", "enable", "restart", "delete", "go", "ensure"]
            let hasActionVerb = actionVerbs.contains { suggestion.lowercased().contains($0) }
            XCTAssertTrue(hasActionVerb,
                         "\(error.id): Recovery suggestion should contain actionable guidance")
        }
    }

    // MARK: - LocalizedError Conformance Tests

    func testLocalizedError_AllCasesHaveDescriptions() {
        let errors: [ScanError] = [
            .arSessionFailed(underlying: nil),
            .cameraUnavailable,
            .trueDepthUnsupported,
            .faceNotDetected,
            .multipleFacesDetected,
            .cancelled,
            .lightingTooLow(current: 0.2, required: 0.3),
            .lightingTooHigh(current: 0.95, max: 0.9),
            .blurryImage(score: 0.5),
            .occludedFace(regions: ["test"]),
            .invalidExpression(issues: ["test"]),
            .mergeFailed(reason: nil),
            .bakeFailed(reason: nil),
            .metricsFailed(analyzer: nil, reason: nil),
            .processingTimeout(operation: "test", seconds: 30),
            .invalidData(field: "test"),
            .coreDataSaveFailed(underlying: NSError(domain: "test", code: 0)),
            .insufficientStorage(required: 1000, available: 500),
            .corruptedData(entity: "test"),
            .processingError("test")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription,
                           "\(error.id) should have error description")
            XCTAssertNotNil(error.recoverySuggestion,
                           "\(error.id) should have recovery suggestion")
        }
    }
}
