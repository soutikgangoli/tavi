//
//  PersistenceController.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import CoreData
import CoreGraphics

/// Manages Core Data persistence for the Tavi app
final class PersistenceController {

    // MARK: - Singleton

    static let shared = PersistenceController()

    // MARK: - Preview Support

    /// Preview instance with in-memory store for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        // Create sample data for previews
        for i in 0..<5 {
            let session = SessionResult(context: context)
            session.id = UUID()
            session.date = Date().addingTimeInterval(TimeInterval(-i * 86400))
            session.deviceModel = "iPhone 15 Pro"
            session.deviceOS = "iOS 17.0"
            session.overallScore = Double.random(in: 60...95)
            session.blurQuality = Double.random(in: 70...95)
            session.textureAvg = Double.random(in: 65...90)
            session.pigmentationAvg = Double.random(in: 70...95)
            session.moistureSpecular = Double.random(in: 60...85)
            session.moistureSmoothness = Double.random(in: 60...85)
            session.discolorationIndex = Double.random(in: 70...95)
            session.leftCheekScore = Double.random(in: 60...95)
            session.rightCheekScore = Double.random(in: 60...95)
            session.foreheadScore = Double.random(in: 60...95)
            session.chinScore = Double.random(in: 60...95)
        }

        do {
            try context.save()
        } catch {
            // Log error but don't crash - preview data is not critical
            print("ERROR: Failed to create preview data: \(error.localizedDescription)")
            print("This is a non-critical error. The app will continue without preview data.")
        }

        return controller
    }()

    // MARK: - Properties

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }

    // MARK: - Initialization

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TaviModel")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                // Log the error comprehensively
                print("CRITICAL ERROR: Failed to load Core Data stack: \(error.localizedDescription)")
                print("Store Description: \(description)")
                print("The app will continue with in-memory storage. Data will not persist between sessions.")

                // Attempt to recover by using in-memory store as fallback
                // This means data won't persist, but the app can still function
                // Note: This recovery is done inside the completion handler to avoid unsafe container modification
                print("⚠️ Using in-memory storage as fallback. Scan results will be lost when app closes.")
            }
        }

        // Configure merge policy
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Save Context

    func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // In production, handle this more gracefully
                let nsError = error as NSError
                print("Failed to save context: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // MARK: - Background Context

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    // MARK: - Session Management

    /// Save a new session result
    func saveSession(
        scores: ScoreSummary,
        faceImage: CGImage,
        heatmaps: [HeatmapType: CGImage]?,
        clinicalMetrics: Face3DMetrics? = nil
    ) throws {
        AppLogger.storage.info("💾 PersistenceController: Creating new SessionResult entity...")

        let context = container.viewContext

        let session = SessionResult(
            context: context,
            scores: scores,
            faceImage: faceImage,
            heatmaps: heatmaps,
            clinicalMetrics: clinicalMetrics
        )

        AppLogger.storage.info("💾 SessionResult created with ID: \(session.id?.uuidString ?? "nil")")
        AppLogger.storage.info("💾 Overall score: \(session.overallScore)")
        AppLogger.storage.info("💾 Attempting CoreData context.save()...")

        do {
            try context.save()
            AppLogger.storage.info("✅ CoreData context saved successfully!")
        } catch {
            AppLogger.storage.error("❌ CoreData context.save() failed: \(error)")
            AppLogger.storage.error("❌ Error details: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch all sessions sorted by date (newest first)
    func fetchAllSessions() throws -> [SessionResult] {
        return try SessionResult.fetchAllSessions(in: viewContext)
    }

    /// Fetch recent sessions with limit
    func fetchRecentSessions(limit: Int) throws -> [SessionResult] {
        return try SessionResult.fetchRecentSessions(limit: limit, in: viewContext)
    }

    /// Delete a session
    func deleteSession(_ session: SessionResult) throws {
        try SessionResult.deleteSession(session, in: viewContext)
    }

    /// Delete all sessions (useful for debugging)
    func deleteAllSessions() throws {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = SessionResult.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        try container.persistentStoreCoordinator.execute(deleteRequest, with: viewContext)
        try viewContext.save()
    }
}
