//
//  MetricsOrchestrator.swift
//  Ollvy
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

    /// Track the current computation task for proper cancellation
    /// CRITICAL: Task.detached doesn't inherit cancellation, so we must track and cancel it manually
    private var computationTask: Task<Face3DMetrics?, Error>?

    /// Flag to prevent GPU operations after cleanup starts
    private var isCleaningUp: Bool = false

    deinit {
        // CRITICAL: Cancel any running computation task to prevent use-after-free
        // The Task.detached may hold strong references to GPU resources
        computationTask?.cancel()
        computationTask = nil
        AppLogger.faceScan.info("🧹 MetricsOrchestrator deallocating")
    }

    // MARK: - Public Methods

    /// Compute 3D face metrics from baked result
    /// - Parameter bakeResult: The baked texture result from capture
    /// - Returns: Computed face metrics, or nil if computation fails or is cancelled
    public func compute3DMetrics(from bakeResult: TextureBakeResult) async -> Face3DMetrics? {
        // CRITICAL: Don't start if already cleaning up
        guard !isCleaningUp else {
            AppLogger.faceScan.info("🛑 Metrics computation skipped - cleanup in progress")
            return nil
        }

        // FIXED: Defer state update to avoid "Publishing changes from within view updates" warning
        DispatchQueue.main.async { [weak self] in
            self?.isComputingMetrics = true
        }

        AppLogger.faceScan.info("🔬 Starting metrics computation...")

        // Check for cancellation before starting heavy computation
        guard !Task.isCancelled else {
            AppLogger.faceScan.info("🛑 Metrics computation cancelled before start")
            DispatchQueue.main.async { [weak self] in
                self?.isComputingMetrics = false
            }
            return nil
        }

        // Cancel any previous computation task
        computationTask?.cancel()

        // Capture references before detaching
        let analyzer = self.metricsAnalyzer
        let unifiedMesh = bakeResult.unifiedMesh
        let unifiedTexture = bakeResult.albedoTexture

        // Create and store the task for proper cancellation tracking
        // CRITICAL FIX: Use Task (not Task.detached) so it inherits cancellation from parent
        let task = Task<Face3DMetrics?, Error>(priority: .userInitiated) {
            // Check cancellation at the start
            try Task.checkCancellation()

            // Run computation off main actor
            let result = await Task.detached(priority: .userInitiated) {
                await analyzer.computeMetrics(
                    unifiedMesh: unifiedMesh,
                    unifiedTexture: unifiedTexture
                )
            }.value

            // Check cancellation after computation
            try Task.checkCancellation()

            return result
        }

        // Store task for cancellation during cleanup/deinit
        computationTask = task

        // Wait for result with proper error handling
        let metrics: Face3DMetrics?
        do {
            metrics = try await task.value
        } catch is CancellationError {
            AppLogger.faceScan.info("🛑 Metrics computation cancelled during processing")
            DispatchQueue.main.async { [weak self] in
                self?.isComputingMetrics = false
            }
            computationTask = nil
            return nil
        } catch {
            AppLogger.faceScan.error("❌ Metrics computation error: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.isComputingMetrics = false
            }
            computationTask = nil
            return nil
        }

        // Clear task reference after completion
        computationTask = nil

        // Check cancellation before updating state
        guard !Task.isCancelled else {
            AppLogger.faceScan.info("🛑 Metrics computation cancelled after processing")
            DispatchQueue.main.async { [weak self] in
                self?.isComputingMetrics = false
            }
            return nil
        }

        if metrics == nil {
            AppLogger.faceScan.warning("⚠️ Metrics computation returned nil")
        } else {
            AppLogger.faceScan.info("✅ Metrics computed successfully")
        }

        // Update state - defer to avoid "Publishing changes from within view updates" warning
        DispatchQueue.main.async { [weak self] in
            self?.face3DMetrics = metrics
            self?.isComputingMetrics = false
        }

        // Generate visualizations if metrics were computed (and not cancelled)
        if let metrics = metrics, !Task.isCancelled {
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

        // Defer state update to avoid "Publishing changes from within view updates" warning
        DispatchQueue.main.async { [weak self] in
            self?.metricVisualizations = visualizations
        }
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
        // CRITICAL: Set cleanup flag first to prevent new operations
        isCleaningUp = true

        // Cancel any running computation task
        if computationTask != nil {
            computationTask?.cancel()
            computationTask = nil
            AppLogger.faceScan.info("🛑 Cancelled running metrics computation task")
        }

        // Defer @Published property updates to avoid "Publishing changes from within view updates"
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.face3DMetrics = nil
            self.metricVisualizations.removeAll()
            self.isComputingMetrics = false
        }

        // Reset cleanup flag after reset is complete
        isCleaningUp = false
        AppLogger.faceScan.info("✅ Metrics orchestrator reset")
    }

    /// Cancel any running computation and prepare for deallocation
    /// Call this BEFORE the orchestrator is deallocated to prevent use-after-free
    public func cancelComputation() {
        isCleaningUp = true
        if computationTask != nil {
            computationTask?.cancel()
            computationTask = nil
            AppLogger.faceScan.info("🛑 Metrics computation cancelled for cleanup")
        }
    }

    /// Clear visualizations to free memory
    public func clearVisualizations() {
        if !metricVisualizations.isEmpty {
            AppLogger.faceScan.info("Clearing metric visualizations")
            // Defer @Published property update to avoid "Publishing changes from within view updates"
            DispatchQueue.main.async { [weak self] in
                self?.metricVisualizations.removeAll()
            }
        }
    }
}
