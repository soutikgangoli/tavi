//
//  DataBackupManager.swift
//  Ollvy
//
//  Provides user-facing data backup and recovery functionality
//  Created on 2025-11-04.
//

import Foundation
import CoreData
import os.log

/// Manages user-initiated data backups and recovery
public final class DataBackupManager: ObservableObject {

    // MARK: - Types

    public enum BackupError: LocalizedError {
        case storeNotFound
        case backupFailed(Error)
        case restoreFailed(Error)
        case exportFailed(Error)
        case importFailed(Error)

        public var errorDescription: String? {
            switch self {
            case .storeNotFound:
                return "Core Data store not found"
            case .backupFailed(let error):
                return "Backup failed: \(error.localizedDescription)"
            case .restoreFailed(let error):
                return "Restore failed: \(error.localizedDescription)"
            case .exportFailed(let error):
                return "Export failed: \(error.localizedDescription)"
            case .importFailed(let error):
                return "Import failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Properties

    @Published public private(set) var availableBackups: [BackupInfo] = []
    @Published public private(set) var isBackingUp: Bool = false
    @Published public private(set) var isRestoring: Bool = false

    private let storeURL: URL
    private let backupDirectory: URL
    private let logger = Logger(subsystem: "com.ollvy.app", category: "DataBackup")

    // MARK: - Initialization

    public init(storeURL: URL) {
        self.storeURL = storeURL

        // Use Documents directory for user-initiated backups (backed up to iCloud)
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to access Documents directory")
        }
        self.backupDirectory = documentsURL.appendingPathComponent("Backups", isDirectory: true)

        // Ensure backup directory exists
        try? FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        // Load available backups
        refreshBackupList()
    }

    // MARK: - Public API

    /// Create a manual backup
    public func createBackup(named name: String? = nil) async throws {
        await MainActor.run {
            isBackingUp = true
        }

        defer {
            Task { @MainActor in
                isBackingUp = false
                refreshBackupList()
            }
        }

        logger.info("💾 Creating manual backup...")

        // Check if store exists
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            throw BackupError.storeNotFound
        }

        // Generate backup name
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupName = name ?? "Manual_\(timestamp)"
        let backupURL = backupDirectory.appendingPathComponent("\(backupName).sqlite")

        do {
            // Copy store file
            try FileManager.default.copyItem(at: storeURL, to: backupURL)

            // Copy associated files
            let basePath = storeURL.deletingPathExtension()
            let backupBasePath = backupURL.deletingPathExtension()

            for ext in ["sqlite-shm", "sqlite-wal"] {
                let sourceFile = basePath.appendingPathExtension(ext)
                let destFile = backupBasePath.appendingPathExtension(ext)

                if FileManager.default.fileExists(atPath: sourceFile.path) {
                    try? FileManager.default.copyItem(at: sourceFile, to: destFile)
                }
            }

            logger.info("✅ Backup created: \(backupName)")
        } catch {
            logger.error("❌ Backup failed: \(error.localizedDescription)")
            throw BackupError.backupFailed(error)
        }
    }

    /// Restore from a backup
    public func restoreFromBackup(_ backup: BackupInfo) async throws {
        await MainActor.run {
            isRestoring = true
        }

        defer {
            Task { @MainActor in
                isRestoring = false
            }
        }

        logger.warning("⚠️ Restoring from backup: \(backup.url.lastPathComponent)")

        do {
            let fileManager = FileManager.default

            // Remove current store
            try? fileManager.removeItem(at: storeURL)

            let basePath = storeURL.deletingPathExtension()
            for ext in ["sqlite-shm", "sqlite-wal"] {
                let file = basePath.appendingPathExtension(ext)
                try? fileManager.removeItem(at: file)
            }

            // Copy backup to store location
            try fileManager.copyItem(at: backup.url, to: storeURL)

            let backupBasePath = backup.url.deletingPathExtension()
            for ext in ["sqlite-shm", "sqlite-wal"] {
                let sourceFile = backupBasePath.appendingPathExtension(ext)
                let destFile = basePath.appendingPathExtension(ext)

                if fileManager.fileExists(atPath: sourceFile.path) {
                    try? fileManager.copyItem(at: sourceFile, to: destFile)
                }
            }

            logger.info("✅ Restore completed")
        } catch {
            logger.error("❌ Restore failed: \(error.localizedDescription)")
            throw BackupError.restoreFailed(error)
        }
    }

    /// Export backup to share with user
    public func exportBackup(_ backup: BackupInfo) throws -> URL {
        logger.info("📤 Exporting backup for sharing...")

        let tempDirectory = FileManager.default.temporaryDirectory
        let exportURL = tempDirectory.appendingPathComponent("OllvyBackup_\(Date().timeIntervalSince1970).sqlite")

        do {
            try FileManager.default.copyItem(at: backup.url, to: exportURL)
            logger.info("✅ Backup exported to: \(exportURL.path)")
            return exportURL
        } catch {
            logger.error("❌ Export failed: \(error.localizedDescription)")
            throw BackupError.exportFailed(error)
        }
    }

    /// Import backup from external file
    public func importBackup(from url: URL, named name: String? = nil) async throws {
        logger.info("📥 Importing backup from: \(url.lastPathComponent)")

        let backupName = name ?? "Imported_\(ISO8601DateFormatter().string(from: Date()))"
        let destURL = backupDirectory.appendingPathComponent("\(backupName).sqlite")

        do {
            // Start accessing security-scoped resource (for files from document picker)
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Copy to backup directory
            try FileManager.default.copyItem(at: url, to: destURL)

            logger.info("✅ Backup imported: \(backupName)")

            await MainActor.run {
                refreshBackupList()
            }
        } catch {
            logger.error("❌ Import failed: \(error.localizedDescription)")
            throw BackupError.importFailed(error)
        }
    }

    /// Delete a backup
    public func deleteBackup(_ backup: BackupInfo) throws {
        logger.info("🗑️ Deleting backup: \(backup.url.lastPathComponent)")

        try FileManager.default.removeItem(at: backup.url)

        // Delete associated files
        let basePath = backup.url.deletingPathExtension()
        for ext in ["sqlite-shm", "sqlite-wal"] {
            let file = basePath.appendingPathExtension(ext)
            try? FileManager.default.removeItem(at: file)
        }

        refreshBackupList()
        logger.info("✅ Backup deleted")
    }

    /// Refresh list of available backups
    public func refreshBackupList() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            availableBackups = []
            return
        }

        availableBackups = contents.compactMap { url -> BackupInfo? in
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

    /// Get total backup storage size
    public var totalBackupSize: UInt64 {
        availableBackups.reduce(0) { $0 + $1.fileSize }
    }

    /// Get formatted total backup size
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBackupSize), countStyle: .file)
    }
}
