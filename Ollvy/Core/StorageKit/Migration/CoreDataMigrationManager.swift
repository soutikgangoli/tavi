//
//  CoreDataMigrationManager.swift
//  Ollvy
//
//  Handles Core Data migrations with safety checks, versioning, and rollback support
//  Created on 2025-11-04.
//

import Foundation
import CoreData
import os.log

/// Core Data migration manager with comprehensive safety measures
public final class CoreDataMigrationManager {

    // MARK: - Types

    /// Migration result
    public enum MigrationResult {
        case notRequired
        case succeeded(from: String, to: String, duration: TimeInterval)
        case failed(Error)
    }

    /// Migration error types
    public enum MigrationError: LocalizedError {
        case storeNotFound(URL)
        case metadataReadFailed(URL)
        case incompatibleModel(current: String, store: String)
        case backupFailed(Error)
        case migrationFailed(from: String, to: String, Error)
        case rollbackFailed(Error)
        case invalidModelVersion(String)
        case cachesDirectoryUnavailable

        public var errorDescription: String? {
            switch self {
            case .storeNotFound(let url):
                return "Core Data store not found at \(url.path)"
            case .metadataReadFailed(let url):
                return "Failed to read metadata from store at \(url.path)"
            case .incompatibleModel(let current, let store):
                return "Incompatible models: current=\(current), store=\(store)"
            case .backupFailed(let error):
                return "Backup failed: \(error.localizedDescription)"
            case .migrationFailed(let from, let to, let error):
                return "Migration failed from \(from) to \(to): \(error.localizedDescription)"
            case .rollbackFailed(let error):
                return "Rollback failed: \(error.localizedDescription)"
            case .invalidModelVersion(let version):
                return "Invalid model version: \(version)"
            case .cachesDirectoryUnavailable:
                return "Unable to access Caches directory"
            }
        }
    }

    // MARK: - Properties

    private let modelName: String
    private let modelBundle: Bundle
    private let storeURL: URL
    private let backupDirectory: URL

    /// Logger for migration operations
    private let logger = Logger(subsystem: "com.ollvy.app", category: "CoreDataMigration")

    // MARK: - Initialization

    public init?(
        modelName: String,
        storeURL: URL,
        bundle: Bundle = .main
    ) {
        self.modelName = modelName
        self.storeURL = storeURL
        self.modelBundle = bundle

        // Create backup directory in Caches (not backed up to iCloud)
        guard let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            AppLogger.storage.error("CoreDataMigrationManager: Unable to access Caches directory")
            return nil
        }
        self.backupDirectory = cachesURL.appendingPathComponent("CoreDataBackups", isDirectory: true)

        // Ensure backup directory exists
        try? FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Check if migration is needed and perform it safely
    public func migrateStoreIfNeeded() -> MigrationResult {
        logger.info("🔍 Checking if Core Data migration is needed...")

        // Check if store exists
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            logger.info("✅ No existing store found - no migration needed")
            return .notRequired
        }

        // Read store metadata
        guard let storeMetadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        ) else {
            logger.error("❌ Failed to read store metadata")
            return .failed(MigrationError.metadataReadFailed(storeURL))
        }

        // Get current model
        guard let currentModel = NSManagedObjectModel.mergedModel(from: [modelBundle], forStoreMetadata: storeMetadata) else {
            logger.info("✅ Store is compatible with current model - no migration needed")
            return .notRequired
        }

        // Get destination model (latest version)
        guard let destinationModel = NSManagedObjectModel.mergedModel(from: [modelBundle]) else {
            logger.error("❌ Failed to load destination model")
            return .failed(MigrationError.invalidModelVersion("latest"))
        }

        // Check if models are compatible
        if currentModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: storeMetadata) {
            logger.info("✅ Store is compatible - no migration needed")
            return .notRequired
        }

        // Migration needed - get version identifiers
        let sourceVersion = getModelVersion(from: currentModel)
        let destinationVersion = getModelVersion(from: destinationModel)

        logger.warning("⚠️ Migration required: \(sourceVersion) → \(destinationVersion)")

        // Create backup before migration
        do {
            try createBackup()
            logger.info("✅ Backup created successfully")
        } catch {
            logger.error("❌ Backup failed: \(error.localizedDescription)")
            return .failed(MigrationError.backupFailed(error))
        }

        // Perform migration
        let startTime = Date()
        do {
            try performMigration(
                from: currentModel,
                to: destinationModel,
                sourceVersion: sourceVersion,
                destinationVersion: destinationVersion
            )
            let duration = Date().timeIntervalSince(startTime)
            logger.info("✅ Migration succeeded in \(String(format: "%.2f", duration))s")

            // Validate migrated store
            if validateMigratedStore() {
                logger.info("✅ Migrated store validated successfully")
                return .succeeded(from: sourceVersion, to: destinationVersion, duration: duration)
            } else {
                logger.error("❌ Migrated store validation failed")
                try rollback()
                return .failed(MigrationError.migrationFailed(
                    from: sourceVersion,
                    to: destinationVersion,
                    NSError(domain: "Migration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Validation failed"])
                ))
            }
        } catch {
            logger.error("❌ Migration failed: \(error.localizedDescription)")

            // Attempt rollback
            do {
                try rollback()
                logger.info("✅ Rollback succeeded - restored from backup")
            } catch {
                logger.error("❌ Rollback failed: \(error.localizedDescription)")
            }

            return .failed(MigrationError.migrationFailed(
                from: sourceVersion,
                to: destinationVersion,
                error
            ))
        }
    }

    /// Get list of available backups
    public func getBackups() -> [BackupInfo] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { url -> BackupInfo? in
            guard url.pathExtension == "sqlite",
                  let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let creationDate = attributes[.creationDate] as? Date,
                  let fileSize = attributes[.size] as? UInt64 else {
                return nil
            }

            return BackupInfo(
                url: url,
                creationDate: creationDate,
                fileSize: fileSize
            )
        }.sorted { $0.creationDate > $1.creationDate }
    }

    /// Clean up old backups (keep only N most recent)
    public func cleanupOldBackups(keepCount: Int = 5) throws {
        let backups = getBackups()

        // Delete backups beyond keepCount
        for backup in backups.dropFirst(keepCount) {
            logger.info("🧹 Deleting old backup: \(backup.url.lastPathComponent)")
            try FileManager.default.removeItem(at: backup.url)

            // Also delete associated files (-shm, -wal)
            let basePath = backup.url.deletingPathExtension()
            for ext in ["sqlite-shm", "sqlite-wal"] {
                let file = basePath.appendingPathExtension(ext)
                try? FileManager.default.removeItem(at: file)
            }
        }

        logger.info("✅ Cleaned up \(backups.count - keepCount) old backups")
    }

    // MARK: - Private Methods

    private func createBackup() throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupURL = backupDirectory.appendingPathComponent("backup_\(timestamp).sqlite")

        logger.info("💾 Creating backup at \(backupURL.path)")

        // Copy main store file
        try FileManager.default.copyItem(at: storeURL, to: backupURL)

        // Copy associated files (-shm, -wal)
        let basePath = storeURL.deletingPathExtension()
        let backupBasePath = backupURL.deletingPathExtension()

        for ext in ["sqlite-shm", "sqlite-wal"] {
            let sourceFile = basePath.appendingPathExtension(ext)
            let destFile = backupBasePath.appendingPathExtension(ext)

            if FileManager.default.fileExists(atPath: sourceFile.path) {
                try? FileManager.default.copyItem(at: sourceFile, to: destFile)
            }
        }
    }

    private func performMigration(
        from sourceModel: NSManagedObjectModel,
        to destinationModel: NSManagedObjectModel,
        sourceVersion: String,
        destinationVersion: String
    ) throws {
        logger.info("🔄 Starting migration: \(sourceVersion) → \(destinationVersion)")

        // Check if mapping model exists
        if let mappingModel = NSMappingModel(
            from: [modelBundle],
            forSourceModel: sourceModel,
            destinationModel: destinationModel
        ) {
            logger.info("✅ Found custom mapping model")
            try performMigrationWithMappingModel(
                sourceModel: sourceModel,
                destinationModel: destinationModel,
                mappingModel: mappingModel
            )
        } else {
            logger.info("⚠️ No custom mapping model - using lightweight migration")
            try performLightweightMigration(
                sourceModel: sourceModel,
                destinationModel: destinationModel
            )
        }
    }

    private func performMigrationWithMappingModel(
        sourceModel: NSManagedObjectModel,
        destinationModel: NSManagedObjectModel,
        mappingModel: NSMappingModel
    ) throws {
        let tempURL = storeURL.deletingLastPathComponent()
            .appendingPathComponent("temp_\(UUID().uuidString).sqlite")

        let migrationManager = NSMigrationManager(
            sourceModel: sourceModel,
            destinationModel: destinationModel
        )

        // Migrate to temporary store
        try migrationManager.migrateStore(
            from: storeURL,
            sourceType: NSSQLiteStoreType,
            options: nil,
            with: mappingModel,
            toDestinationURL: tempURL,
            destinationType: NSSQLiteStoreType,
            destinationOptions: nil
        )

        // Replace old store with migrated store
        try replaceStore(with: tempURL)
    }

    private func performLightweightMigration(
        sourceModel: NSManagedObjectModel,
        destinationModel: NSManagedObjectModel
    ) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: destinationModel)

        let options = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]

        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: options
        )

        logger.info("✅ Lightweight migration completed")
    }

    private func replaceStore(with newStoreURL: URL) throws {
        let fileManager = FileManager.default

        // Remove old store files
        try? fileManager.removeItem(at: storeURL)

        let basePath = storeURL.deletingPathExtension()
        for ext in ["sqlite-shm", "sqlite-wal"] {
            let file = basePath.appendingPathExtension(ext)
            try? fileManager.removeItem(at: file)
        }

        // Move new store files
        try fileManager.moveItem(at: newStoreURL, to: storeURL)

        let newBasePath = newStoreURL.deletingPathExtension()
        for ext in ["sqlite-shm", "sqlite-wal"] {
            let sourceFile = newBasePath.appendingPathExtension(ext)
            let destFile = basePath.appendingPathExtension(ext)

            if fileManager.fileExists(atPath: sourceFile.path) {
                try? fileManager.moveItem(at: sourceFile, to: destFile)
            }
        }
    }

    private func validateMigratedStore() -> Bool {
        do {
            // Try to load the migrated store
            guard let model = NSManagedObjectModel.mergedModel(from: [modelBundle]) else {
                logger.error("❌ Failed to load model for validation")
                return false
            }

            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
            let store = try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: [NSReadOnlyPersistentStoreOption: true]
            )

            // Perform basic sanity checks
            let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator

            // Try to fetch count (validates entity integrity)
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "SessionResult")
            let count = try context.count(for: request)

            logger.info("✅ Validation: Found \(count) SessionResult records")

            try coordinator.remove(store)
            return true
        } catch {
            logger.error("❌ Validation failed: \(error.localizedDescription)")
            return false
        }
    }

    private func rollback() throws {
        logger.warning("⚠️ Rolling back migration...")

        // Get most recent backup
        guard let latestBackup = getBackups().first else {
            throw MigrationError.rollbackFailed(
                NSError(domain: "Migration", code: -1, userInfo: [NSLocalizedDescriptionKey: "No backup found"])
            )
        }

        let fileManager = FileManager.default

        // Remove current (failed) store
        try? fileManager.removeItem(at: storeURL)

        let basePath = storeURL.deletingPathExtension()
        for ext in ["sqlite-shm", "sqlite-wal"] {
            let file = basePath.appendingPathExtension(ext)
            try? fileManager.removeItem(at: file)
        }

        // Restore from backup
        try fileManager.copyItem(at: latestBackup.url, to: storeURL)

        let backupBasePath = latestBackup.url.deletingPathExtension()
        for ext in ["sqlite-shm", "sqlite-wal"] {
            let sourceFile = backupBasePath.appendingPathExtension(ext)
            let destFile = basePath.appendingPathExtension(ext)

            if fileManager.fileExists(atPath: sourceFile.path) {
                try? fileManager.copyItem(at: sourceFile, to: destFile)
            }
        }

        logger.info("✅ Rollback completed - restored from \(latestBackup.url.lastPathComponent)")
    }

    private func getModelVersion(from model: NSManagedObjectModel) -> String {
        // Try to get version from model's version identifiers
        if let versionIdentifier = model.versionIdentifiers.first as? String {
            return versionIdentifier
        }

        // Fallback to hash
        return "\(model.hash)"
    }
}

// MARK: - Supporting Types

public struct BackupInfo {
    public let url: URL
    public let creationDate: Date
    public let fileSize: UInt64

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }
}
