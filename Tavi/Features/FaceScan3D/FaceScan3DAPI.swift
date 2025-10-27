//
//  FaceScan3DAPI.swift
//  Tavi
//
//  Public API surface for 3D face scanning and metrics computation
//  Created on 2025-10-27.
//

import Foundation
import UIKit
import CoreGraphics

// MARK: - Public API

/// Compute complete 3D face metrics from unified mesh and albedo texture
///
/// - Parameters:
///   - unifiedMesh: The merged face mesh from multiple capture angles
///   - texture: The baked albedo texture (color-corrected, lighting-removed)
///   - metadata: Optional scan metadata for context
/// - Returns: Complete Face3DMetrics with global and per-ROI scores
///
/// Example:
/// ```swift
/// let analyzer = Face3DMetricsAnalyzer()
/// let metrics = await analyzer.computeMetrics(
///     unifiedMesh: mergedMesh,
///     unifiedTexture: albedoTexture
/// )
///
/// if let metrics = metrics {
///     print("Overall score: \(metrics.overallScore)/10")
///     print("Interpretation: \(metrics.scoreInterpretation)")
/// }
/// ```
public func computeFace3DMetrics(
    unifiedMesh: UnifiedMesh,
    texture: CGImage,
    metadata: FaceScanMetadata? = nil
) async -> Face3DMetrics? {
    let analyzer = Face3DMetricsAnalyzer()
    return await analyzer.computeMetrics(
        unifiedMesh: unifiedMesh,
        unifiedTexture: texture
    )
}

/// Generate 3D metric overlay visualizations (heatmaps)
///
/// - Parameters:
///   - metrics: Computed Face3DMetrics
///   - texture: Original albedo texture for overlay base
/// - Returns: Dictionary of overlay types to generated heatmap images
///
/// Example:
/// ```swift
/// let overlays = generate3DOverlays(metrics: metrics, texture: albedoTexture)
///
/// if let roughnessHeatmap = overlays[.roughness]?.heatmapImage {
///     imageView.image = roughnessHeatmap
/// }
/// ```
public func generate3DOverlays(
    metrics: Face3DMetrics,
    texture: CGImage
) -> [OverlayType: MetricVisualization] {
    let visualizer = MetricsVisualizer()
    var overlays: [OverlayType: MetricVisualization] = [:]

    // Generate visualization for each metric type
    for overlayType in OverlayType.allCases {
        let metricType: MetricType = switch overlayType {
        case .roughness: .roughness
        case .pigmentation: .pigmentation
        case .discoloration: .luminance
        case .specular: .lightness
        }

        let viz = visualizer.generateVisualization(for: metrics, type: metricType)
        overlays[overlayType] = viz
    }

    return overlays
}

/// Save Face3D summary to persistent storage (UserDefaults)
///
/// - Parameter summary: Face3DSummary to persist
/// - Throws: Error if encoding fails
///
/// Example:
/// ```swift
/// let summary = Face3DSummary.from(
///     metrics: metrics,
///     previewImage: faceImage,
///     thresholdsVersion: "1.0"
/// )
///
/// try saveFace3DSummary(summary)
/// ```
public func saveFace3DSummary(_ summary: Face3DSummary) throws {
    Face3DSummaryManager.save(summary)
}

/// Load all saved Face3D summaries from persistent storage
///
/// - Returns: Array of Face3DSummary, sorted by date (most recent first)
///
/// Example:
/// ```swift
/// let summaries = loadAllFace3DSummaries()
/// for summary in summaries {
///     print("\(summary.date): \(summary.overallScore)/10")
/// }
/// ```
public func loadAllFace3DSummaries() -> [Face3DSummary] {
    return Face3DSummaryManager.loadAll()
}

/// Load specific Face3D summary by ID
///
/// - Parameter id: UUID of the summary to load
/// - Returns: Face3DSummary if found, nil otherwise
public func loadFace3DSummary(id: UUID) -> Face3DSummary? {
    return Face3DSummaryManager.load(id: id)
}

/// Delete Face3D summary by ID
///
/// - Parameter id: UUID of the summary to delete
public func deleteFace3DSummary(id: UUID) {
    Face3DSummaryManager.delete(id: id)
}

// MARK: - Overlay Type

/// Types of metric overlays available
public enum OverlayType: CaseIterable {
    case roughness      // Texture roughness/smoothness
    case pigmentation   // Pigmentation uniformity
    case discoloration  // Inter-ROI color variance
    case specular       // Specular highlights/oiliness

    public var displayName: String {
        switch self {
        case .roughness: return "Roughness"
        case .pigmentation: return "Pigmentation"
        case .discoloration: return "Discoloration"
        case .specular: return "Specular"
        }
    }
}

// MARK: - Convenience Extensions

extension Face3DMetrics {
    /// Get human-readable summary of all metrics
    public var summary: String {
        var lines: [String] = []

        lines.append("=== 3D Face Metrics Summary ===")
        lines.append("")
        lines.append("Overall Score: \(String(format: "%.0f", overallScore))% (\(scoreInterpretation))")
        lines.append("")
        lines.append("Global Scores:")
        lines.append("  • Smoothness: \(String(format: "%.0f", globalRoughnessScore))%")
        lines.append("  • Pigmentation: \(String(format: "%.0f", globalPigmentationScore))%")
        lines.append("  • Discoloration: \(String(format: "%.0f", globalDiscolorationScore))%")
        if let specular = globalSpecularScore {
            lines.append("  • Oil Control: \(String(format: "%.0f", specular))%")
        }
        lines.append("")
        lines.append("Mesh Statistics:")
        lines.append("  • Vertices: \(vertexCount)")
        lines.append("  • Triangles: \(triangleCount)")
        lines.append("  • Texture: \(Int(textureResolution.width))x\(Int(textureResolution.height))")
        lines.append("")
        lines.append("Processing:")
        lines.append("  • Time: \(String(format: "%.2f", processingTime))s")
        lines.append("  • Quality: \(textureQuality ?? "N/A")")

        if !lowConfidenceROIs.isEmpty {
            lines.append("")
            lines.append("⚠️ Low Confidence ROIs:")
            for roi in lowConfidenceROIs {
                lines.append("  • \(roi.displayName)")
            }
        }

        lines.append("")
        lines.append("Regional Scores:")
        for (roi, metrics) in sortedROIMetrics {
            lines.append("  \(roi.displayName):")
            lines.append("    - Smoothness: \(String(format: "%.0f", metrics.roughnessScore))%")
            lines.append("    - Pigmentation: \(String(format: "%.0f", metrics.pigmentationScore))%")
            if let specular = metrics.specularScore {
                lines.append("    - Oil Control: \(String(format: "%.0f", specular))%")
            }
            lines.append("    - Pixels: \(metrics.pixelCount) (\(metrics.confidenceLevel))")
        }

        return lines.joined(separator: "\n")
    }

    /// Export metrics to JSON
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Import metrics from JSON
    public static func fromJSON(_ data: Data) throws -> Face3DMetrics {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Face3DMetrics.self, from: data)
    }
}

extension Face3DSummary {
    /// Get human-readable summary text
    public var summaryText: String {
        var lines: [String] = []

        lines.append("=== Face3D Scan Summary ===")
        lines.append("")
        lines.append("Date: \(date.formatted())")
        lines.append("Device: \(deviceModel) (\(deviceOS))")
        lines.append("Version: \(thresholdsVersion)")
        lines.append("")
        lines.append("Overall Score: \(String(format: "%.0f", overallScore))% (\(scoreInterpretation))")
        lines.append("")
        lines.append("Global Scores:")
        lines.append("  • Smoothness: \(String(format: "%.0f", roughnessScore))%")
        lines.append("  • Pigmentation: \(String(format: "%.0f", pigmentationScore))%")
        lines.append("  • Discoloration: \(String(format: "%.0f", discolorationScore))%")
        if let specular = specularScore {
            lines.append("  • Oil Control: \(String(format: "%.0f", specular))%")
        }
        lines.append("")
        lines.append("Mesh Statistics:")
        lines.append("  • Vertices: \(vertexCount)")
        lines.append("  • Triangles: \(triangleCount)")
        lines.append("  • Texture: \(Int(textureResolution.width))x\(Int(textureResolution.height))")
        lines.append("  • Processing: \(String(format: "%.2f", processingTime))s")

        return lines.joined(separator: "\n")
    }

    /// Export summary to JSON
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Import summary from JSON
    public static func fromJSON(_ data: Data) throws -> Face3DSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Face3DSummary.self, from: data)
    }
}

// MARK: - Usage Example

/*
 Complete workflow example:

 ```swift
 // 1. Capture multi-angle face scans
 let viewModel = FaceScan3DViewModel()
 viewModel.startGuidance()
 // ... user follows guidance prompts, captures complete

 // 2. Get merged mesh and baked texture
 guard let merged = await viewModel.finalizeCapture(),
       let bakeResult = await viewModel.bakeTextureFromSequence() else {
     print("Capture failed")
     return
 }

 // 3. Compute 3D metrics
 guard let metrics = await computeFace3DMetrics(
     unifiedMesh: bakeResult.unifiedMesh,
     texture: bakeResult.albedoTexture
 ) else {
     print("Metrics computation failed")
     return
 }

 // 4. Display results
 let resultsView = Face3DResultsView(metrics: metrics, texturedMesh: bakeResult)
 navigationController.pushViewController(UIHostingController(rootView: resultsView), animated: true)

 // 5. Generate overlays
 let overlays = generate3DOverlays(metrics: metrics, texture: bakeResult.albedoTexture)
 if let roughnessHeatmap = overlays[.roughness]?.heatmapImage {
     // Display heatmap
 }

 // 6. Save summary
 let summary = Face3DSummary.from(
     metrics: metrics,
     previewImage: faceImage,
     thresholdsVersion: "1.0"
 )
 try saveFace3DSummary(summary)

 // 7. Print summary
 print(metrics.summary)
 ```
 */
