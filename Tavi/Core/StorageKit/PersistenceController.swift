//
//  PersistenceController.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import CoreData

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
            fatalError("Failed to create preview data: \(error)")
        }

        return controller
    }()

    // MARK: - Properties

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }

    // MARK: - Initialization

    private init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TaviModel")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                // In production, handle this more gracefully
                fatalError("Failed to load Core Data stack: \(error)")
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
        heatmaps: [HeatmapMetric: CGImage]?
    ) throws {
        let context = container.viewContext

        _ = SessionResult(
            context: context,
            scores: scores,
            faceImage: faceImage,
            heatmaps: heatmaps
        )

        try context.save()
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
