//
//  ExportManager.swift
//  Tavi
//
//  Manage export, save, and share operations for textured meshes
//  Created on 2025-10-27.
//

import Foundation
import UIKit
import SwiftUI
import Compression

/// Manages export operations and file handling
public class ExportManager {

    // MARK: - Export Formats

    public enum ExportFormat {
        case obj  // OBJ + MTL + PNG
        case gltf  // glTF + BIN + PNG
        case usdz  // USDZ with embedded texture
    }

    // MARK: - Save Functions

    /// Create timestamped export directory in Documents
    public static func createExportDirectory() throws -> URL {
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        let timestamp = Int(Date().timeIntervalSince1970)
        let exportDir = documentsPath.appendingPathComponent("FaceScan_\(timestamp)")

        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

        print("📁 Created export directory: \(exportDir.path)")
        return exportDir
    }

    /// Export textured mesh to specified format
    public static func exportMesh(
        _ result: TextureBakeResult,
        metadata: FaceScanMetadata,
        format: ExportFormat
    ) throws -> URL {

        let exportDir = try createExportDirectory()

        switch format {
        case .obj:
            return try MeshTextureExporter.exportOBJ(
                unifiedMesh: result.unifiedMesh,
                texture: result.albedoTexture,
                metadata: metadata,
                outputDirectory: exportDir
            )

        case .gltf:
            return try MeshTextureExporter.exportGLTF(
                unifiedMesh: result.unifiedMesh,
                texture: result.albedoTexture,
                metadata: metadata,
                outputDirectory: exportDir
            )

        case .usdz:
            return try MeshTextureExporter.exportUSDZ(
                unifiedMesh: result.unifiedMesh,
                texture: result.albedoTexture,
                metadata: metadata,
                outputDirectory: exportDir
            )
        }
    }

    /// Zip entire export directory
    /// Note: For production, consider using ZIPFoundation or native compression
    public static func zipExportDirectory(_ directory: URL) throws -> URL {
        let zipURL = directory.deletingLastPathComponent()
            .appendingPathComponent(directory.lastPathComponent + ".zip")

        // For now, just return the directory URL
        // In production, implement proper ZIP compression using:
        // - ZIPFoundation (3rd party)
        // - Or native compression APIs

        print("📦 Export directory ready: \(directory.path)")
        print("   (ZIP compression requires additional implementation)")

        return directory
    }

    /// Get all export directories
    public static func listExportDirectories() -> [URL] {
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: documentsPath,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )

            return contents.filter { url in
                url.lastPathComponent.hasPrefix("FaceScan_")
            }.sorted { $0.lastPathComponent > $1.lastPathComponent }  // Newest first

        } catch {
            print("⚠️ Failed to list export directories: \(error)")
            return []
        }
    }

    /// Delete export directory
    public static func deleteExport(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
        print("🗑️ Deleted export: \(url.lastPathComponent)")
    }

    /// Clean up old exports (keep only last N)
    public static func cleanupOldExports(keepLast: Int = 10) throws {
        let exports = listExportDirectories()

        if exports.count > keepLast {
            let toDelete = exports.dropFirst(keepLast)
            for url in toDelete {
                try? deleteExport(at: url)
            }
        }
    }
}

// MARK: - SwiftUI Share Sheet

/// SwiftUI wrapper for UIActivityViewController
public struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let excludedActivityTypes: [UIActivity.ActivityType]?

    public init(items: [Any], excludedActivityTypes: [UIActivity.ActivityType]? = nil) {
        self.items = items
        self.excludedActivityTypes = excludedActivityTypes
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Export Result View

/// View showing export results with share options
public struct ExportResultView: View {
    let exportURL: URL
    @State private var showingShareSheet = false
    @State private var zipURL: URL?
    @State private var isZipping = false

    public init(exportURL: URL) {
        self.exportURL = exportURL
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Export Complete!")
                .font(.title)
                .fontWeight(.bold)

            Text(exportURL.lastPathComponent)
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            VStack(spacing: 12) {
                Button(action: shareFiles) {
                    Label("Share Files", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: createZipAndShare) {
                    Label("Share as ZIP", systemImage: "doc.zipper")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isZipping)

                if isZipping {
                    ProgressView("Creating ZIP...")
                        .padding()
                }
            }
            .padding()

            Button("View in Files") {
                openInFiles()
            }
            .foregroundColor(.blue)
        }
        .padding()
        .sheet(isPresented: $showingShareSheet) {
            if let zipURL = zipURL {
                ShareSheet(items: [zipURL])
            } else {
                ShareSheet(items: [exportURL])
            }
        }
    }

    private func shareFiles() {
        zipURL = nil
        showingShareSheet = true
    }

    private func createZipAndShare() {
        isZipping = true

        Task {
            do {
                let zip = try ExportManager.zipExportDirectory(exportURL)
                await MainActor.run {
                    zipURL = zip
                    isZipping = false
                    showingShareSheet = true
                }
            } catch {
                print("⚠️ Failed to create ZIP: \(error)")
                await MainActor.run {
                    isZipping = false
                }
            }
        }
    }

    private func openInFiles() {
        // Open Files app to Documents directory
        if let url = URL(string: "shareddocuments://") {
            UIApplication.shared.open(url)
        }
    }
}
