//
//  DataBackupView.swift
//  Ollvy
//
//  User interface for data backup and recovery
//  Created on 2025-11-04.
//

import SwiftUI

/// User interface for managing data backups
public struct DataBackupView: View {

    @StateObject private var backupManager: DataBackupManager
    @State private var showingCreateBackup = false
    @State private var backupName = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingRestoreConfirmation = false
    @State private var backupToRestore: BackupInfo?
    @State private var showingDeleteConfirmation = false
    @State private var backupToDelete: BackupInfo?
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    private let initializationFailed: Bool

    public init(storeURL: URL) {
        if let manager = DataBackupManager(storeURL: storeURL) {
            _backupManager = StateObject(wrappedValue: manager)
            initializationFailed = false
        } else {
            // Create a placeholder manager that will show error state
            // This should never happen on iOS but handles edge case gracefully
            _backupManager = StateObject(wrappedValue: DataBackupManager.disabled)
            initializationFailed = true
        }
    }

    public var body: some View {
        if initializationFailed {
            ContentUnavailableView(
                "Backup Unavailable",
                systemImage: "externaldrive.badge.exclamationmark",
                description: Text("Unable to access storage for backups. Please restart the app.")
            )
            .navigationTitle("Data Backups")
        } else {
            backupListView
        }
    }

    @ViewBuilder
    private var backupListView: some View {
        List {
            // Summary Section
            Section {
                HStack {
                    Image(systemName: "externaldrive.fill")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text("Total Backups")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(backupManager.availableBackups.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Storage Used")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(backupManager.formattedTotalSize)
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                }
                .padding(.vertical, 8)
            }

            // Actions Section
            Section {
                Button {
                    showingCreateBackup = true
                } label: {
                    Label("Create Backup", systemImage: "plus.circle.fill")
                }
                .disabled(backupManager.isBackingUp)

                if backupManager.isBackingUp {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Creating backup...")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Actions")
            }

            // Backups List
            if !backupManager.availableBackups.isEmpty {
                Section {
                    ForEach(backupManager.availableBackups, id: \.url) { backup in
                        BackupRow(backup: backup)
                            .contextMenu {
                                Button {
                                    backupToRestore = backup
                                    showingRestoreConfirmation = true
                                } label: {
                                    Label("Restore", systemImage: "arrow.counterclockwise")
                                }

                                Button {
                                    exportBackup(backup)
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    backupToDelete = backup
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    backupToDelete = backup
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    backupToRestore = backup
                                    showingRestoreConfirmation = true
                                } label: {
                                    Label("Restore", systemImage: "arrow.counterclockwise")
                                }
                                .tint(.blue)
                            }
                    }
                } header: {
                    Text("Available Backups")
                } footer: {
                    Text("Backups are stored locally on this device. Export important backups to keep them safe.")
                }
            } else {
                Section {
                    ContentUnavailableView(
                        "No Backups",
                        systemImage: "externaldrive.badge.xmark",
                        description: Text("Create your first backup to protect your data")
                    )
                }
            }

            // Info Section
            Section {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("About Backups")
                            .font(.headline)
                        Text("Backups include all your scan results, heatmaps, and metrics. Create regular backups before app updates.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Data Backups")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    backupManager.refreshBackupList()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showingCreateBackup) {
            CreateBackupSheet(
                backupName: $backupName,
                onCreateBackup: createBackup
            )
        }
        .alert("Restore Backup?", isPresented: $showingRestoreConfirmation) {
            Button("Cancel", role: .cancel) {
                backupToRestore = nil
            }
            Button("Restore", role: .destructive) {
                if let backup = backupToRestore {
                    restoreBackup(backup)
                }
            }
        } message: {
            if let backup = backupToRestore {
                Text("This will replace all current data with data from \(backup.formattedDate). This action cannot be undone.")
            }
        }
        .alert("Delete Backup?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                backupToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let backup = backupToDelete {
                    deleteBackup(backup)
                }
            }
        } message: {
            Text("This backup will be permanently deleted. This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                DataBackupShareSheet(items: [url])
            }
        }
    }

    // MARK: - Actions

    private func createBackup() {
        Task {
            do {
                let name = backupName.isEmpty ? nil : backupName
                try await backupManager.createBackup(named: name)
                showingCreateBackup = false
                backupName = ""
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func restoreBackup(_ backup: BackupInfo) {
        Task {
            do {
                try await backupManager.restoreFromBackup(backup)
                backupToRestore = nil

                // Show success and suggest app restart
                errorMessage = "Backup restored successfully. Please restart the app to see your restored data."
                showingError = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func exportBackup(_ backup: BackupInfo) {
        do {
            let exportURL = try backupManager.exportBackup(backup)
            shareURL = exportURL
            showingShareSheet = true
            AppLogger.storage.info("Backup exported to: \(exportURL.path)")
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func deleteBackup(_ backup: BackupInfo) {
        do {
            try backupManager.deleteBackup(backup)
            backupToDelete = nil
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Backup Row

private struct BackupRow: View {
    let backup: BackupInfo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(backup.url.deletingPathExtension().lastPathComponent)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Label(backup.formattedDate, systemImage: "clock")
                    Label(backup.formattedSize, systemImage: "externaldrive")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create Backup Sheet

private struct CreateBackupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var backupName: String
    let onCreateBackup: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Backup Name (Optional)", text: $backupName)
                } header: {
                    Text("Name")
                } footer: {
                    Text("If no name is provided, a timestamp will be used.")
                }

                Section {
                    Text("This will create a backup of all your scan results, including images, heatmaps, and metrics.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Create Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreateBackup()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DataBackupView(
            storeURL: URL(fileURLWithPath: "/tmp/test.sqlite")
        )
    }
}

// MARK: - ShareSheet Helper

private struct DataBackupShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
