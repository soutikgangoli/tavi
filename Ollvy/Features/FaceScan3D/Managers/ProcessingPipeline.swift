//
//  ProcessingPipeline.swift
//  Ollvy
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
        let resolution = resolveTextureResolution()
        var config = TextureBaker.Configuration()
        config.textureWidth = resolution.width
        config.textureHeight = resolution.height
        return TextureBaker(configuration: config)
    }

    /// Resolve texture resolution based on device capability or user override
    private func resolveTextureResolution() -> TextureResolution {
        // Check for explicit user override first
        if UserDefaults.standard.object(forKey: AppDefaultsKey.enableHighResCapture) != nil {
            let use4K = UserDefaults.standard.bool(forKey: AppDefaultsKey.enableHighResCapture)
            return use4K ? .highRes4K : .standard2K
        }
        // Use device-based default (4K for 6GB+ devices)
        return DeviceCapabilities.current.recommendedTextureResolution
    }

    // MARK: - Public Methods

    /// Finalize capture and merge all partial meshes
    public func finalizeCapture(sequence: CaptureSequence) async -> MergedFaceMesh? {
        // CRITICAL: Check cancellation at the very start
        guard !Task.isCancelled else {
            AppLogger.mesh.info("🛑 Mesh merge cancelled at start")
            return nil
        }
        
        // MEMORY MANAGEMENT: Check available memory before starting
        if let stats = AdvancedMemoryMonitor.shared.getMemoryStats() {
            AppLogger.mesh.info("📊 Pre-merge memory: \(stats.formattedUsed) / \(stats.formattedTotal)")

            // If memory is tight, proactively clean up
            let moderatePressure: AdvancedMemoryMonitor.MemoryPressure = .moderate
            if stats.pressure >= moderatePressure {
                AppLogger.mesh.warning("⚠️ Memory pressure detected - performing cleanup")
                AdvancedMemoryMonitor.shared.forceCleanup(atPressure: stats.pressure)

                // Wait a moment for cleanup to take effect (but check cancellation first)
                guard !Task.isCancelled else {
                    AppLogger.mesh.info("🛑 Mesh merge cancelled during memory cleanup")
                    return nil
                }
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

        // CRITICAL: Check cancellation before starting heavy work
        guard !Task.isCancelled else {
            AppLogger.mesh.info("🛑 Mesh merge cancelled before merge operation")
            return nil
        }

        // Defer @Published update to avoid "Publishing changes from within view updates" warning
        DispatchQueue.main.async { [weak self] in self?.isMerging = true }

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
                // Check cancellation before streaming merge
                guard !Task.isCancelled else {
                    AppLogger.mesh.info("🛑 Streaming merge cancelled before start")
                    DispatchQueue.main.async { [weak self] in self?.isMerging = false }
                    return nil
                }

                merged = try await streamingMerger.merge(captures: captures) { progress, message in
                    // Log progress - callback is already on main actor
                    AppLogger.mesh.debug("Streaming merge progress: \(Int(progress * 100))%")
                }
            } catch is CancellationError {
                AppLogger.mesh.info("🛑 Streaming merge cancelled")
                DispatchQueue.main.async { [weak self] in self?.isMerging = false }
                return nil
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
                DispatchQueue.main.async { [weak self] in self?.isMerging = false }
                return nil
            }
        } else {
            // Use standard merger for smaller meshes
            // Capture merger reference and cancellation state before detaching
            let merger = self.meshMerger
            let isCancelled = Task.isCancelled
            merged = await Task.detached(priority: .userInitiated) { () -> MergedFaceMesh? in
                // Check cancellation before starting
                if isCancelled || Task.isCancelled {
                    AppLogger.mesh.info("🛑 Mesh merge cancelled before start")
                    return nil
                }
                
                AppLogger.mesh.info("🔧 Calling standard merger.merge()")
                let merged = merger.merge(captures: captures)
                
                // Check cancellation after merge completes
                if Task.isCancelled {
                    AppLogger.mesh.info("🛑 Mesh merge cancelled after completion")
                    return nil
                }

                guard let finalMesh = merged else {
                    AppLogger.mesh.error("❌ Standard merger returned nil!")
                    return nil
                }

                AppLogger.mesh.info("✅ Merged mesh: \(finalMesh.vertices.count) vertices")
                return finalMesh
            }.value
        }

        // CRITICAL: Check cancellation after merge completes
        guard !Task.isCancelled else {
            AppLogger.mesh.info("🛑 Mesh merge cancelled after merge completed")
            DispatchQueue.main.async { [weak self] in self?.isMerging = false }
            return nil
        }

        guard let merged = merged else {
            AppLogger.mesh.error("❌ MERGE FAILED: Final merged mesh is nil")
            DispatchQueue.main.async { [weak self] in self?.isMerging = false }
            return nil
        }

        // Store merged result - defer to avoid "Publishing changes from within view updates" warning
        DispatchQueue.main.async { [weak self] in
            self?.mergedMesh = merged
            self?.isMerging = false
        }

        // MEMORY OPTIMIZATION: Release original captures after merge is complete
        // The merged mesh contains all the data we need - original captures are no longer needed
        sequence.releaseCaptures()

        // Log post-merge memory status
        if let stats = AdvancedMemoryMonitor.shared.getMemoryStats() {
            AppLogger.memory.info("📊 Post-merge memory: \(stats.formattedUsed) / \(stats.formattedTotal)")
        }

        return merged
    }

    /// Bake unified texture from all captured samples
    public func bakeUnifiedTexture(
        from unifiedMesh: MergedFaceMesh,
        samples: [PoseSample]
    ) async -> TextureBakeResult? {
        // CRITICAL: Check cancellation at the very start
        guard !Task.isCancelled else {
            AppLogger.faceScan.info("🛑 Texture bake cancelled at start")
            return nil
        }
        
        guard !samples.isEmpty else {
            AppLogger.faceScan.error("❌ No texture samples available")
            return nil
        }

        // Defer @Published update to avoid "Publishing changes from within view updates" warning
        DispatchQueue.main.async { [weak self] in self?.isBaking = true }

        // Check cancellation before starting heavy bake operation
        guard !Task.isCancelled else {
            AppLogger.faceScan.info("🛑 Texture bake cancelled before bake operation")
            DispatchQueue.main.async { [weak self] in self?.isBaking = false }
            return nil
        }

        let result = await textureBaker.bakeUnifiedTexture(
            from: unifiedMesh,
            samples: samples
        )

        // CRITICAL: Check cancellation after bake completes
        guard !Task.isCancelled else {
            AppLogger.faceScan.info("🛑 Texture bake cancelled after completion")
            DispatchQueue.main.async { [weak self] in self?.isBaking = false }
            return nil
        }

        // Defer @Published updates
        DispatchQueue.main.async { [weak self] in
            self?.bakeResult = result
            self?.isBaking = false
        }

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
        // Defer @Published property updates to avoid "Publishing changes from within view updates"
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.mergedMesh = nil
            self.bakeResult = nil
            self.isMerging = false
            self.isBaking = false
        }
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
                // Defer @Published property update to avoid "Publishing changes from within view updates"
                DispatchQueue.main.async { [weak self] in
                    self?.bakeResult = nil
                }
            }

        case .critical:
            // Clear everything except currently processing data
            if !isMerging {
                AppLogger.mesh.error("🧹 Critical pressure: Clearing merged mesh")
                // Defer @Published property update to avoid "Publishing changes from within view updates"
                DispatchQueue.main.async { [weak self] in
                    self?.mergedMesh = nil
                }
            }
            if !isBaking {
                AppLogger.mesh.error("🧹 Critical pressure: Clearing bake result")
                // Defer @Published property update to avoid "Publishing changes from within view updates"
                DispatchQueue.main.async { [weak self] in
                    self?.bakeResult = nil
                }
            }
        }
    }
}
