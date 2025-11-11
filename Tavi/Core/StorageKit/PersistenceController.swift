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
            AppLogger.storage.warning("Failed to create preview data: \(error.localizedDescription)")
            AppLogger.storage.warning("This is a non-critical error. The app will continue without preview data.")
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
        // Try to load the model explicitly if automatic loading fails
        var managedObjectModel: NSManagedObjectModel?
        
        // First try to find the compiled .momd file
        if let modelURL = Bundle.main.url(forResource: "TaviModel", withExtension: "momd") {
            managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        }
        
        // If that fails, try to find the source .xcdatamodeld (shouldn't happen in production but helps with debugging)
        if managedObjectModel == nil,
           let modelURL = Bundle.main.url(forResource: "TaviModel", withExtension: "xcdatamodeld") {
            managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        }
        
        // Create container with explicit model if found, otherwise let it try automatic loading
        if let model = managedObjectModel {
            container = NSPersistentContainer(name: "TaviModel", managedObjectModel: model)
            AppLogger.storage.info("✅ Loaded Core Data model explicitly from bundle")
        } else {
            container = NSPersistentContainer(name: "TaviModel")
            AppLogger.storage.warning("⚠️ Could not find TaviModel in bundle - using automatic loading")
            AppLogger.storage.warning("   Make sure TaviModel.xcdatamodeld is added to target's 'Copy Bundle Resources' in Xcode")
        }

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure store for production use with automatic migration
            if let storeDescription = container.persistentStoreDescriptions.first {
                // Enable automatic migration
                storeDescription.shouldMigrateStoreAutomatically = true
                storeDescription.shouldInferMappingModelAutomatically = true

                AppLogger.storage.info("✅ Core Data configured with automatic migration")
            }
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                // Log the error comprehensively
                AppLogger.storage.error("❌ CRITICAL: Failed to load Core Data stack")
                AppLogger.storage.error("   Error: \(error.localizedDescription)")
                AppLogger.storage.error("   Store: \(description.url?.path ?? "unknown")")

                // Check if this is a migration-related error
                let nsError = error as NSError
                if nsError.domain == NSCocoaErrorDomain &&
                   (nsError.code == NSPersistentStoreIncompatibleVersionHashError ||
                    nsError.code == NSMigrationMissingSourceModelError) {

                    AppLogger.storage.error("   Migration error detected - store incompatible with model")
                    AppLogger.storage.error("   Consider restoring from backup or resetting store")
                }

                AppLogger.storage.warning("⚠️ Using in-memory storage as fallback")
                AppLogger.storage.warning("   Data will NOT persist between app sessions")
            } else {
                AppLogger.storage.info("✅ Core Data persistent store loaded successfully")
                AppLogger.storage.info("   Store URL: \(description.url?.path ?? "unknown")")

                // Log store size for monitoring
                if let storeURL = description.url,
                   let attributes = try? FileManager.default.attributesOfItem(atPath: storeURL.path),
                   let fileSize = attributes[.size] as? UInt64 {
                    let sizeMB = Double(fileSize) / 1_048_576.0
                    AppLogger.storage.info("   Store size: \(String(format: "%.2f", sizeMB)) MB")
                }
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
                let nsError = error as NSError
                AppLogger.storage.error("Failed to save PersistenceController context: \(nsError), \(nsError.userInfo)")
                CrashReporter.shared.logError(error, context: [
                    "operation": "persistence_controller_save",
                    "has_changes": "true"
                ])

                // In production, this is a background save - we log but don't show UI
                // If this fails, the next save attempt will retry any unsaved changes
            }
        }
    }

    // MARK: - Background Context

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    // MARK: - Migration Info

    /// Get the current Core Data model version
    func getCurrentModelVersion() -> String? {
        guard let modelURL = container.managedObjectModel.versionIdentifiers.first as? String else {
            return nil
        }
        return modelURL
    }

    /// Check if migration is needed
    func isMigrationNeeded(at storeURL: URL) -> Bool {
        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL,
                options: nil
            )

            let isCompatible = container.managedObjectModel.isConfiguration(
                withName: nil,
                compatibleWithStoreMetadata: metadata
            )

            return !isCompatible
        } catch {
            AppLogger.storage.warning("⚠️ Could not check if migration is needed: \(error.localizedDescription)")
            return false
        }
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

        AppLogger.storage.info("💾 SessionResult created with ID: \(session.id.uuidString)")
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
