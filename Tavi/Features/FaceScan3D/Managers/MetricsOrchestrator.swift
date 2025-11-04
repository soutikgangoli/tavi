//
//  MetricsOrchestrator.swift
//  Tavi
//
//  Handles metrics computation and visualization
//  Extracted from FaceScan3DViewModel to improve maintainability
//

import Foundation
import ARKit
import SwiftUI

/// Manages 3D metrics computation and visualization generation
@MainActor
public class MetricsOrchestrator: ObservableObject {
    // MARK: - Published Properties

    /// Computed 3D face metrics
    @Published public var face3DMetrics: Face3DMetrics?

    /// Whether metrics are being computed
    @Published public var isComputingMetrics: Bool = false

    /// Metric visualizations
    @Published public var metricVisualizations: [VisualizerMetricType: MetricVisualization] = [:]

    // MARK: - Private Properties

    private let metricsAnalyzer = Face3DMetricsAnalyzer()
    private let metricsVisualizer = MetricsVisualizer()

    // MARK: - Public Methods

    /// Compute 3D face metrics from baked result
    public func compute3DMetrics(from bakeResult: TextureBakeResult) async -> Face3DMetrics? {
        isComputingMetrics = true

        AppLogger.faceScan.info("🔬 Starting metrics computation...")

        // Capture references before detaching
        let analyzer = self.metricsAnalyzer
        let unifiedMesh = bakeResult.unifiedMesh
        let unifiedTexture = bakeResult.albedoTexture

        // Run heavy computation off main actor
        let metrics = await Task.detached {
            return await analyzer.computeMetrics(
                unifiedMesh: unifiedMesh,
                unifiedTexture: unifiedTexture
            )
        }.value

        if metrics == nil {
            AppLogger.faceScan.warning("⚠️ Metrics computation returned nil")
        } else {
            AppLogger.faceScan.info("✅ Metrics computed successfully")
        }

        // Update state on main actor
        face3DMetrics = metrics
        isComputingMetrics = false

        // Generate visualizations if metrics were computed
        if let metrics = metrics {
            await generateVisualizations(for: metrics)
        }

        return metrics
    }

    /// Generate visualizations for metrics
    private func generateVisualizations(for metrics: Face3DMetrics) async {
        AppLogger.faceScan.info("🎨 Generating metric visualizations...")

        var visualizations: [VisualizerMetricType: MetricVisualization] = [:]

        for metricType in [VisualizerMetricType.roughness, .pigmentation, .luminance, .specular] {
            let viz = metricsVisualizer.generateVisualization(
                for: metrics,
                type: metricType
            )
            visualizations[metricType] = viz
        }

        metricVisualizations = visualizations
        AppLogger.faceScan.info("✅ Generated \(visualizations.count) visualizations")
    }

    /// Get visualization for specific metric type
    public func getVisualization(for type: VisualizerMetricType) -> MetricVisualization? {
        return metricVisualizations[type]
    }

    /// Get metrics for specific ROI
    public func getMetrics(for roi: Face3DROI) -> ROI3DMetrics? {
        return face3DMetrics?.metrics(for: roi)
    }

    /// Generate metadata from capture sequence
    public func generateMetadata(
        sequence: CaptureSequence,
        bakeResult: TextureBakeResult?,
        mergedMesh: MergedFaceMesh?,
        calibrationState: CalibrationState
    ) -> FaceScanMetadata? {
        let samples = sequence.textureSamples
        let captures = sequence.captures

        guard !captures.isEmpty else { return nil }

        // Calculate statistics
        let avgAmbient = captures.map { $0.ambientIntensity }.reduce(0, +) / CGFloat(captures.count)
        let avgTemp = captures.map { $0.colorTemperature }.reduce(0, +) / CGFloat(captures.count)
        let avgDist = captures.map { $0.distanceFromCamera }.reduce(0, +) / Float(captures.count)

        let avgSharpness = samples.isEmpty ? 0 : samples.map { $0.focusSharpness }.reduce(0, +) / Float(samples.count)
        let avgExposure = samples.isEmpty ? ScanConfiguration.idealExposure : samples.map { $0.exposureScore }.reduce(0, +) / Float(samples.count)

        let deviceModel = UIDevice.current.model
        let iOSVersion = UIDevice.current.systemVersion

        return FaceScanMetadata(
            deviceModel: deviceModel,
            iOSVersion: iOSVersion,
            hasTrueDepth: true,
            totalPoses: captures.count,
            captureSteps: captures.map { $0.step },
            totalDuration: sequence.duration,
            headTransforms: captures.map { $0.transform },
            minAmbientIntensity: sequence.metadata.minLighting ?? 0,
            maxAmbientIntensity: sequence.metadata.maxLighting ?? 0,
            avgAmbientIntensity: avgAmbient,
            avgColorTemperature: avgTemp,
            minDistance: sequence.metadata.minDistance ?? 0,
            maxDistance: sequence.metadata.maxDistance ?? 0,
            avgDistance: avgDist,
            calibrationPassed: calibrationState.isCalibrated,
            lightingCondition: calibrationState.lighting.rawValue,
            distanceCondition: calibrationState.distance.rawValue,
            avgFocusSharpness: avgSharpness,
            avgExposureScore: avgExposure,
            textureCoverage: bakeResult?.coveragePercentage ?? 0,
            processingTime: (bakeResult?.processingTime ?? 0) + (mergedMesh?.mergeTimestamp ?? 0) - sequence.startTime
        )
    }

    /// Reset metrics state
    public func reset() {
        face3DMetrics = nil
        metricVisualizations.removeAll()
        isComputingMetrics = false
        AppLogger.faceScan.info("✅ Metrics orchestrator reset")
    }

    /// Clear visualizations to free memory
    public func clearVisualizations() {
        if !metricVisualizations.isEmpty {
            AppLogger.faceScan.info("Clearing metric visualizations")
            metricVisualizations.removeAll()
        }
    }
}
