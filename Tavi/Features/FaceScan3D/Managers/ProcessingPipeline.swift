//
//  ProcessingPipeline.swift
//  Tavi
//
//  Handles mesh merging, texture baking, and export operations
//  Extracted from FaceScan3DViewModel to improve maintainability
//

import Foundation
import ARKit
import SwiftUI

/// Manages mesh processing, merging, texture baking, and export
@MainActor
public class ProcessingPipeline: ObservableObject {
    // MARK: - Published Properties

    /// Merged face mesh from all captures
    @Published public var mergedMesh: MergedFaceMesh?

    /// Whether sequence is being processed/merged
    @Published public var isMerging: Bool = false

    /// Baked texture result (unified mesh + albedo texture)
    @Published public var bakeResult: TextureBakeResult?

    /// Whether texture is being baked
    @Published public var isBaking: Bool = false

    // MARK: - Private Properties

    private let meshMerger = MeshMerger()
    private let streamingMerger = StreamingMeshMerger()
    private var textureBaker: TextureBaker {
        let enableHighRes = UserDefaults.standard.bool(forKey: "enableHighResCapture")
        var config = TextureBaker.Configuration()
        if enableHighRes {
            config.textureWidth = ScanConfiguration.highResTextureWidth
            config.textureHeight = ScanConfiguration.highResTextureHeight
        } else {
            config.textureWidth = ScanConfiguration.standardTextureWidth
            config.textureHeight = ScanConfiguration.standardTextureHeight
        }
        return TextureBaker(configuration: config)
    }

    // MARK: - Public Methods

    /// Finalize capture and merge all partial meshes
    public func finalizeCapture(sequence: CaptureSequence) async -> MergedFaceMesh? {
        // MEMORY MANAGEMENT: Check available memory before starting
        if let stats = AdvancedMemoryMonitor.shared.getMemoryStats() {
            AppLogger.mesh.info("📊 Pre-merge memory: \(stats.formattedUsed) / \(stats.formattedTotal)")

            // If memory is tight, proactively clean up
            let moderatePressure: AdvancedMemoryMonitor.MemoryPressure = .moderate
            if stats.pressure >= moderatePressure {
                AppLogger.mesh.warning("⚠️ Memory pressure detected - performing cleanup")
                AdvancedMemoryMonitor.shared.forceCleanup(atPressure: stats.pressure)

                // Wait a moment for cleanup to take effect
                try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
            }
        }

        // Keep screen on during processing
        let previousIdleTimerState = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        AppLogger.mesh.info("🔋 Screen will stay on during processing")

        defer {
            // Already on MainActor since class is @MainActor
            UIApplication.shared.isIdleTimerDisabled = previousIdleTimerState
            AppLogger.mesh.info("🔋 Screen sleep restored")

            // MEMORY MANAGEMENT: Release intermediate data after processing
            self.releaseIntermediateData()
        }

        guard !sequence.captures.isEmpty else {
            AppLogger.mesh.error("❌ MERGE FAILED: No captures in sequence")
            return nil
        }

        let captureCount = sequence.captures.count
        AppLogger.mesh.info("🔄 Starting mesh merge with \(captureCount) captures")

        // Validate captures have geometry
        let emptyCaptures = sequence.captures.filter { $0.vertices.isEmpty }
        if !emptyCaptures.isEmpty {
            AppLogger.mesh.error("❌ Found \(emptyCaptures.count) captures with 0 vertices!")
            return nil
        }

        isMerging = true

        // Calculate total vertices to decide on merger strategy
        let totalVertices = sequence.captures.reduce(0) { $0 + $1.vertices.count }
        let threshold = ScanConfiguration.streamingMeshThreshold
        let useStreaming = totalVertices > threshold

        if useStreaming {
            AppLogger.mesh.info("🌊 Using streaming merger for \(totalVertices) vertices")
        } else {
            AppLogger.mesh.info("⚡️ Using standard merger for \(totalVertices) vertices")
        }

        let captures = sequence.captures
        let merged: MergedFaceMesh?

        if useStreaming {
            // Use streaming merger for large meshes
            do {
                merged = try await streamingMerger.merge(captures: captures) { progress, message in
                    // Log progress - callback is already on main actor
                    AppLogger.mesh.debug("Streaming merge progress: \(Int(progress * 100))%")
                }
            } catch {
                AppLogger.mesh.error("❌ Streaming merge failed: \(error.localizedDescription)")
                CrashReporter.shared.logError(
                    error,
                    context: [
                        "operation": "streaming_mesh_merge",
                        "vertex_count": totalVertices,
                        "capture_count": captures.count
                    ]
                )
                self.isMerging = false
                return nil
            }
        } else {
            // Use standard merger for smaller meshes
            // Capture merger reference before detaching from main actor
            let merger = self.meshMerger
            merged = await Task.detached(priority: .userInitiated) { () -> MergedFaceMesh? in
                AppLogger.mesh.info("🔧 Calling standard merger.merge()")
                let merged = merger.merge(captures: captures)

                guard let finalMesh = merged else {
                    AppLogger.mesh.error("❌ Standard merger returned nil!")
                    return nil
                }

                AppLogger.mesh.info("✅ Merged mesh: \(finalMesh.vertices.count) vertices")
                return finalMesh
            }.value
        }

        guard let merged = merged else {
            AppLogger.mesh.error("❌ MERGE FAILED: Final merged mesh is nil")
            self.isMerging = false
            return nil
        }

        // Store merged result
        mergedMesh = merged
        isMerging = false

        return merged
    }

    /// Bake unified texture from all captured samples
    public func bakeUnifiedTexture(
        from unifiedMesh: MergedFaceMesh,
        samples: [PoseSample]
    ) async -> TextureBakeResult? {
        guard !samples.isEmpty else {
            AppLogger.faceScan.error("❌ No texture samples available")
            return nil
        }

        isBaking = true

        let result = await textureBaker.bakeUnifiedTexture(
            from: unifiedMesh,
            samples: samples
        )

        bakeResult = result
        isBaking = false

        return result
    }

    /// Export sequence to specified format
    public func exportSequence(sequence: CaptureSequence, format: MeshExporter.ExportFormat) throws -> Data {
        return try MeshExporter.export(sequence: sequence, format: format)
    }

    /// Export merged mesh to specified format
    public func exportMergedMesh(format: MeshExporter.ExportFormat) throws -> Data {
        guard let mesh = mergedMesh else {
            throw NSError(domain: "FaceScan3D", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No merged mesh to export"
            ])
        }

        return try MeshExporter.export(mesh: mesh, format: format)
    }

    /// Export textured mesh as OBJ + MTL + PNG
    public func exportOBJ(
        unifiedMesh: UnifiedMesh,
        texture: CGImage,
        metadata: FaceScanMetadata
    ) throws -> URL {
        let outputDir = try ExportManager.createExportDirectory()
        return try MeshTextureExporter.exportOBJ(
            unifiedMesh: unifiedMesh,
            texture: texture,
            metadata: metadata,
            outputDirectory: outputDir
        )
    }

    /// Export textured mesh as glTF 2.0 + PNG
    public func exportGLTF(
        unifiedMesh: UnifiedMesh,
        texture: CGImage,
        metadata: FaceScanMetadata
    ) throws -> URL {
        let outputDir = try ExportManager.createExportDirectory()
        return try MeshTextureExporter.exportGLTF(
            unifiedMesh: unifiedMesh,
            texture: texture,
            metadata: metadata,
            outputDirectory: outputDir
        )
    }

    /// Export textured mesh as USDZ
    public func exportUSDZ(
        unifiedMesh: UnifiedMesh,
        texture: CGImage,
        metadata: FaceScanMetadata
    ) throws -> URL {
        let outputDir = try ExportManager.createExportDirectory()
        return try MeshTextureExporter.exportUSDZ(
            unifiedMesh: unifiedMesh,
            texture: texture,
            metadata: metadata,
            outputDirectory: outputDir
        )
    }

    /// Reset processing state
    public func reset() {
        mergedMesh = nil
        bakeResult = nil
        isMerging = false
        isBaking = false
        AppLogger.mesh.info("✅ Processing pipeline reset")
    }

    /// Release intermediate processing data to free memory
    private func releaseIntermediateData() {
        AppLogger.mesh.info("🧹 Releasing intermediate processing data")

        // Merged mesh can be large (~30MB) - convert to managed resource
        if let mesh = mergedMesh {
            let sizeMB = Double(mesh.vertices.count * MemoryLayout<SIMD3<Float>>.stride) / 1_048_576.0
            AppLogger.mesh.debug("  Merged mesh: \(String(format: "%.2f", sizeMB)) MB")
        }

        // Bake result can be very large (~67MB for 4K textures)
        if let result = bakeResult {
            let textureSizeMB = Double(result.albedoTexture.width * result.albedoTexture.height * 4) / 1_048_576.0
            AppLogger.mesh.debug("  Texture: \(String(format: "%.2f", textureSizeMB)) MB")
        }

        AppLogger.mesh.info("✅ Intermediate data released")
    }

    /// Register with memory manager for proactive cleanup
    public func registerMemoryCleanup() {
        AdvancedMemoryMonitor.shared.registerCleanupHandler(id: "ProcessingPipeline") { [weak self] pressure in
            guard let self = self else { return }
            self.handleMemoryPressure(pressure)
        }
    }

    /// Handle memory pressure
    private func handleMemoryPressure(_ pressure: AdvancedMemoryMonitor.MemoryPressure) {
        AppLogger.mesh.warning("⚠️ Memory pressure: \(pressure.description)")

        switch pressure {
        case .normal:
            // No action needed
            break

        case .moderate:
            // Don't clear anything during active processing
            if !isMerging && !isBaking {
                AppLogger.mesh.info("🧹 Moderate pressure: Ready to clear on demand")
            }

        case .high:
            // Clear non-essential data
            if !isMerging && !isBaking {
                AppLogger.mesh.warning("🧹 High pressure: Clearing bake result")
                bakeResult = nil
            }

        case .critical:
            // Clear everything except currently processing data
            if !isMerging {
                AppLogger.mesh.error("🧹 Critical pressure: Clearing merged mesh")
                mergedMesh = nil
            }
            if !isBaking {
                AppLogger.mesh.error("🧹 Critical pressure: Clearing bake result")
                bakeResult = nil
            }
        }
    }
}
