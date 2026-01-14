//
//  Face3DMetricsAnalyzer.swift
//  Ollvy
//
//  Complete 3D face metrics analyzer
//  Created on 2025-10-27.
//

import Foundation
import UIKit
import CoreGraphics
import simd

/// Analyzes 3D face metrics from unified mesh and albedo texture
public class Face3DMetricsAnalyzer {

    // MARK: - Components

    private let roiMaskGenerator: ROIMaskGenerator
    private let roughnessAnalyzer: RoughnessAnalyzer
    private let pigmentationAnalyzer: PigmentationAnalyzer
    private let discolorationAnalyzer: DiscolorationAnalyzer
    private let specularAnalyzer: SpecularAnalyzer
    private let scoring: Scoring3D
    private let qualityValidator: TextureQualityValidator

    // NEW: Advanced analyzers
    private let skinElasticityAnalyzer: SkinElasticityAnalyzer
    private let volumeMetricsAnalyzer: VolumeMetricsAnalyzer
    private let regionalAnalyzers: RegionalAnalyzers
    private let skinTypeClassifier: SkinTypeClassifier
    private let wrinkleAnalyzer: WrinkleAnalyzer
    private let poreAnalyzer: PoreAnalyzer
    private let acneAnalyzer: AcneAnalyzer
    private let rednessAnalyzer: RednessAnalyzer
    private let topologyAnalyzer: MeshTopologyAnalyzer
    private let hydrationEstimator: HydrationEstimator

    // Normalizers for diverse skin tones and lighting conditions
    private let skinToneNormalizer: SkinToneNormalizer
    private let colorTempNormalizer: ColorTemperatureNormalizer

    // MARK: - Parallel Analysis Result Types

    /// Result type for parallel analysis tasks
    private enum AnalysisResult: Sendable {
        case volume(VolumeAnalysis?)
        case regional(RegionalAnalysis?)
        case skinType(SkinTypeAnalysis?)
        case pore(PoreAnalysis?)
        case acne(AcneAnalysis?)
        case redness(RednessAnalysis?)
        case topology(TopologyAnalysis?)
    }

    // MARK: - Configuration

    public struct Configuration {
        /// Whether to compute specular/oiliness metrics (requires raw RGB frames)
        public var computeSpecular: Bool = true

        /// Quality validation configuration
        public var qualityValidation: TextureQualityValidator.Configuration = TextureQualityValidator.Configuration()

        /// Historical scans for elasticity analysis (optional)
        public var historicalScans: [HistoricalScan]? = nil

        /// Baseline mesh for volume comparison (optional)
        public var baselineMesh: FaceMeshGeometry? = nil

        public init() {}
    }

    private let configuration: Configuration

    // MARK: - Initialization

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.roiMaskGenerator = ROIMaskGenerator()
        self.roughnessAnalyzer = RoughnessAnalyzer()
        self.pigmentationAnalyzer = PigmentationAnalyzer()
        self.discolorationAnalyzer = DiscolorationAnalyzer()
        self.specularAnalyzer = SpecularAnalyzer()
        self.scoring = Scoring3D()
        self.qualityValidator = TextureQualityValidator(configuration: configuration.qualityValidation)
        self.skinElasticityAnalyzer = SkinElasticityAnalyzer()
        self.volumeMetricsAnalyzer = VolumeMetricsAnalyzer()
        self.regionalAnalyzers = RegionalAnalyzers()
        self.skinTypeClassifier = SkinTypeClassifier()
        self.wrinkleAnalyzer = WrinkleAnalyzer()
        self.poreAnalyzer = PoreAnalyzer()
        self.acneAnalyzer = AcneAnalyzer()
        self.rednessAnalyzer = RednessAnalyzer()
        self.topologyAnalyzer = MeshTopologyAnalyzer()
        self.hydrationEstimator = HydrationEstimator()
        self.skinToneNormalizer = SkinToneNormalizer()
        self.colorTempNormalizer = ColorTemperatureNormalizer()
    }

    // MARK: - Main API

    /// Compute complete 3D face metrics
    public func computeMetrics(
        unifiedMesh: UnifiedMesh,
        unifiedTexture: CGImage
    ) async -> Face3DMetrics? {

        let startTime = Date().timeIntervalSince1970

        AppLogger.metrics.info("🔬 Face3DMetricsAnalyzer: Starting analysis...")

        // Step 0: Skip Laplacian-based texture quality validation for baked textures
        // REASON: Baked textures are upscaled from camera resolution, which destroys
        // high-frequency detail that Laplacian measures. Original sharpness was already
        // validated at capture time in TextureCapture.swift → ImageQualityAnalyzer.analyzeQuality()
        // The capture-time sharpness of 10.4+ means the source texture is sharp.
        //
        // Previously this returned variance=0.0 for upscaled textures, causing false
        // "Texture too blurry" warnings and 30% confidence reduction on every scan.
        let textureQualityResult = TextureQualityResult(
            isValid: true,  // Trust capture-time validation
            laplacianVariance: 100.0,  // Nominal "good" value (not computed on baked texture)
            minimumThreshold: 80.0,
            reason: nil
        )
        AppLogger.metrics.info("   Texture quality: Validated at capture time (skipping post-bake Laplacian)")

        // Step 1: Generate ROI masks
        let masks = roiMaskGenerator.generateROIMasks(
            from: unifiedMesh.textureCoordinates.map { $0.toSIMD() },
            topology: unifiedMesh.triangleIndices
        )

        AppLogger.metrics.info("   Generated \(masks.count) ROI masks")

        // Step 2: Sample texture for each ROI
        var roiSamples: [Face3DROI: ROITextureSample] = [:]

        for (roi, mask) in masks {
            if let sample = ROITextureSampler.sampleROITexture(unifiedTexture, mask: mask) {
                roiSamples[roi] = sample
                AppLogger.metrics.debug("   Sampled \(sample.pixelCount) pixels for \(roi.displayName)")
            }
        }

        guard !roiSamples.isEmpty else {
            AppLogger.metrics.warning("⚠️ No ROI samples could be extracted")
            return nil
        }

        // Step 2.5: Validate ROI samples
        let roiConfidences = qualityValidator.validateROISamples(roiSamples)
        let globalValidity = qualityValidator.canComputeGlobalMetrics(roiConfidences)

        var lowConfidenceROIs: [Face3DROI] = []
        for (roi, confidence) in roiConfidences {
            if !confidence.isValid {
                AppLogger.metrics.warning("   ⚠️ \(roi.displayName) has low confidence (\(confidence.pixelCount) pixels < \(confidence.minimumRequired))")
                lowConfidenceROIs.append(roi)
            }
        }

        // Step 3: Convert CGImage to UIImage for analysis
        // IMPORTANT: This image is NEVER modified - all analyzers use RAW data
        let textureImage = UIImage(cgImage: unifiedTexture)

        // Step 3.0: FIXED - Detect skin tone BEFORE any analysis to prevent race conditions
        // This ensures skin tone is available for all analyzers that need it
        AppLogger.metrics.info("   📊 Detecting skin tone FIRST (prevents race conditions)...")
        let skinTone = skinToneNormalizer.detectSkinTone(texture: textureImage)
        AppLogger.metrics.info("      Detected: \(skinTone.rawValue) (reference L*: \(skinTone.referenceL))")

        // Step 3.1: Assess lighting quality BEFORE metrics computation
        AppLogger.metrics.info("   💡 Assessing lighting quality...")
        let lightingNormalizer = LightingNormalizer()
        let lightingQuality = lightingNormalizer.assessLightingQuality(image: textureImage)
        AppLogger.metrics.info("      Overall quality: \(String(format: "%.2f", lightingQuality.overallScore)) (\(lightingQuality.isAcceptable ? "acceptable" : "poor"))")
        AppLogger.metrics.info("      Brightness: \(String(format: "%.2f", lightingQuality.brightness)), Uniformity: \(String(format: "%.2f", lightingQuality.uniformity)), Shadows: \(String(format: "%.2f", lightingQuality.shadowPresence))")
        if !lightingQuality.issues.isEmpty {
            AppLogger.metrics.warning("      ⚠️ Issues: \(lightingQuality.issues.joined(separator: ", "))")
        }

        // Extract lighting quality score for variance correction
        let lightingQualityScore = lightingQuality.overallScore

        // Step 3.2: Compute metrics for each ROI IN PARALLEL with lighting quality awareness
        // NOTE: roiSamples contains FULL RESOLUTION data
        // Only RoughnessAnalyzer downsamples internally for performance
        var roiMetrics: [Face3DROI: ROI3DMetrics] = [:]

        AppLogger.metrics.info("   Computing metrics for \(roiSamples.count) ROIs in parallel...")

        // MEMORY OPTIMIZATION: Parallel processing with limited concurrency
        // Processing all ROIs simultaneously can spike memory to 2.5GB (5× 4096×4096 Metal textures)
        // Limit to 2-3 concurrent Metal operations to keep memory under 1GB
        let maxConcurrentOperations = 2
        await withTaskGroup(of: (Face3DROI, ROI3DMetrics).self) { group in
            var pendingROIs = Array(roiSamples)
            var activeCount = 0

            // Process ROIs with concurrency limit
            while !pendingROIs.isEmpty || activeCount > 0 {
                // Check cancellation periodically (non-throwing check)
                guard !Task.isCancelled else {
                    AppLogger.metrics.info("🛑 ROI processing cancelled")
                    break
                }
                
                // Start new tasks up to concurrency limit
                while activeCount < maxConcurrentOperations && !pendingROIs.isEmpty {
                    let (roi, sample) = pendingROIs.removeFirst()
                    let confidence = roiConfidences[roi]
                    let lightingScore = lightingQualityScore  // Capture for async context

                    group.addTask {
                        // Check cancellation in task
                        guard !Task.isCancelled else {
                            AppLogger.metrics.debug("   🛑 Cancelled processing \(roi.displayName)")
                            // Return minimal ROI3DMetrics with default values for cancellation case
                            return (roi, ROI3DMetrics(
                                roi: roi,
                                roughnessProxy: 0,
                                pigmentationIndex: 0,
                                specularProxy: nil,
                                blurScore: 0.5,
                                textureEnergy: 0.5,
                                labVariance: 0.5,
                                qualityScore: 0.5,
                                moistureProxy: MoistureProxy(moistureIndex: 0.5, specularRatio: 0.5, smoothnessLowFreq: 0.5),
                                pixelCount: 0,
                                averageLuminance: 0,
                                averageLightness: 0,
                                averageAChannel: 0,
                                averageBChannel: 0,
                                roughnessScore: 0,
                                pigmentationScore: 0,
                                specularScore: nil,
                                isLowConfidence: true,
                                confidenceLevel: "Cancelled"
                            ))
                        }
                        AppLogger.metrics.debug("   - Processing \(roi.displayName)...")
                        // Pass lighting quality to metrics computation
                        let metrics = await self.computeROI3DMetrics(sample, rawSample: nil, confidence: confidence, lightingQuality: lightingScore)
                        AppLogger.metrics.debug("   ✓ \(roi.displayName): roughness=\(metrics.roughnessProxy), pigmentation=\(metrics.pigmentationIndex), confidence=\(metrics.confidenceLevel)")
                        return (roi, metrics)
                    }
                    activeCount += 1
                }

                // Wait for one task to complete
                if let result = await group.next() {
                    let (roi, metrics) = result
                    roiMetrics[roi] = metrics
                    activeCount -= 1
                }
            }
        }
        AppLogger.metrics.info("   ✅ All ROI metrics computed (parallel processing with memory optimization)")

        // Step 4: Compute global metrics and scores
        let globalResults = computeGlobalMetrics(
            roiMetrics: roiMetrics,
            roiSamples: roiSamples,
            lightingQuality: lightingQualityScore
        )

        // NOTE: Don't calculate processingTime here - it's calculated at the end after all analysis
        // let processingTime = Date().timeIntervalSince1970 - startTime

        // Step 5: Convert UnifiedMesh to FaceMeshGeometry for advanced analyzers
        let faceMeshGeometry = convertToFaceMeshGeometry(unifiedMesh: unifiedMesh)

        // Step 4.5: Skin tone already detected in Step 3.0 (before parallel analysis)
        // SCIENTIFIC APPROACH: Never modify source image data - use RAW for all analysis
        // Color temperature normalization was REMOVED because it:
        // 1. Corrupts redness measurements (alters red channel)
        // 2. Corrupts pigmentation variance (changes LAB A*/B* values)
        // 3. Corrupts acne detection (changes darkness thresholds)
        // 4. Creates inconsistency between analyzers
        // Instead, we assess lighting quality and adjust CONFIDENCE/THRESHOLDS, not the image
        // NOTE: skinTone was detected early in Step 3.0 to prevent race conditions

        // Log color temperature for diagnostic purposes only (no modification)
        let detectedColorTemp = colorTempNormalizer.estimateColorTemperature(from: textureImage)
        let lightingType = colorTempNormalizer.detectLightingType(ambientColorTemperature: detectedColorTemp)
        AppLogger.metrics.info("      Color temperature: \(String(format: "%.0f", detectedColorTemp))K (\(lightingType.rawValue)) - logged only, not normalized")

        // Step 5a: Compute wrinkle analysis FIRST (needed for elasticity calculation)
        AppLogger.metrics.info("   🔍 Running WrinkleAnalyzer...")
        let wrinkleAnalysis: WrinkleAnalysis? = wrinkleAnalyzer.analyzeWrinkles(geometry: faceMeshGeometry)

        // Step 5b: Compute elasticity using ACTUAL wrinkle depth (not roughness proxy!)
        let elasticityAnalysis: ElasticityAnalysis?
        if let historicalScans = configuration.historicalScans, !historicalScans.isEmpty {
            // Use actual wrinkle depth from WrinkleAnalyzer
            let currentWrinkleDepth: Float
            if let wrinkles = wrinkleAnalysis {
                // Use average depth from wrinkle regions (most accurate)
                currentWrinkleDepth = wrinkles.wrinkleRegions.isEmpty ? 0 :
                    wrinkles.wrinkleRegions.map { $0.depth }.reduce(0, +) / Float(wrinkles.wrinkleRegions.count)
                AppLogger.metrics.info("   Using actual wrinkle depth for elasticity: \(String(format: "%.4f", currentWrinkleDepth))mm")
            } else {
                // Fallback to roughness only if wrinkle analysis failed
                currentWrinkleDepth = globalResults.roughness * 0.001  // Convert to meters
                AppLogger.metrics.warning("   ⚠️ Wrinkle analysis unavailable, using roughness fallback")
            }

            // Temporal analysis (2+ scans, high confidence 60-90%)
            elasticityAnalysis = skinElasticityAnalyzer.estimateElasticity(
                historicalScans: historicalScans,
                currentWrinkleDepth: currentWrinkleDepth
            )
            if elasticityAnalysis != nil {
                AppLogger.metrics.info("   ✅ Using temporal elasticity analysis (2+ scans)")
            }
        } else {
            // No elasticity analysis for first-time users
            // Elasticity requires 2+ scans separated by 3+ days for accurate temporal analysis
            // No proxy/placeholder values - only real data
            elasticityAnalysis = nil
            AppLogger.metrics.info("   ℹ️ Elasticity analysis skipped (requires 2+ scans for temporal analysis)")
        }

        // Step 5c: Compute remaining advanced metrics
        // IMPORTANT: GPU-heavy texture analyzers (pore, acne, redness) run SEQUENTIALLY
        // to prevent GPU command queue contention and memory pressure.
        // All GPU operations now use polling with 5s timeout instead of blocking waitUntilCompleted().
        // Geometry-based analyzers (volume, regional, topology) run in parallel as they're CPU-bound.
        AppLogger.metrics.info("   🔍 Running advanced analyzers...")

        let parallelStartTime = Date().timeIntervalSince1970

        // Capture values outside TaskGroup to avoid Sendable issues
        let baselineMesh = configuration.baselineMesh

        // STEP 1: Run geometry-based analyzers in parallel (CPU-bound, no blocking GPU calls)
        AppLogger.metrics.debug("   🚀 Starting geometry-based parallel analysis tasks...")
        let (volumeAnalysis, regionalAnalysis, topologyAnalysis) = await withTaskGroup(
            of: AnalysisResult.self,
            returning: (VolumeAnalysis?, RegionalAnalysis?, TopologyAnalysis?).self
        ) { group in
            // Task 1: Volume metrics (geometry-based)
            group.addTask { [volumeMetricsAnalyzer] in
                let result = volumeMetricsAnalyzer.analyzeVolume(
                    geometry: faceMeshGeometry,
                    baseline: baselineMesh
                )
                return .volume(result)
            }

            // Task 2: Regional analysis (geometry + texture)
            group.addTask { [regionalAnalyzers] in
                let result = regionalAnalyzers.analyzeRegions(
                    geometry: faceMeshGeometry,
                    texture: textureImage
                )
                return .regional(result)
            }

            // Task 3: Topology analysis (geometry-based)
            group.addTask { [topologyAnalyzer] in
                let result = topologyAnalyzer.analyzeTopology(geometry: faceMeshGeometry)
                return .topology(result)
            }

            // Collect geometry-based results
            var volume: VolumeAnalysis?
            var regional: RegionalAnalysis?
            var topology: TopologyAnalysis?

            for await result in group {
                // Check cancellation while collecting results (non-throwing check)
                guard !Task.isCancelled else {
                    AppLogger.metrics.info("🛑 Geometry analysis cancelled")
                    break
                }
                
                switch result {
                case .volume(let analysis):
                    AppLogger.metrics.debug("      ✓ Volume analysis complete")
                    volume = analysis
                case .regional(let analysis):
                    AppLogger.metrics.debug("      ✓ Regional analysis complete")
                    regional = analysis
                case .topology(let analysis):
                    AppLogger.metrics.debug("      ✓ Topology analysis complete")
                    topology = analysis
                default:
                    break
                }
            }

            return (volume, regional, topology)
        }

        // STEP 2: Run GPU-heavy texture analyzers SEQUENTIALLY to avoid thread pool exhaustion
        // These now use cancellable polling instead of blocking waitUntilCompleted()
        AppLogger.metrics.debug("   🎨 Running texture-based analyzers sequentially (GPU)...")

        // Check cancellation before starting GPU analyzers (non-throwing check)
        guard !Task.isCancelled else {
            AppLogger.metrics.info("🛑 GPU analyzers cancelled before start")
            return nil
        }

        // Pore analysis (GPU-accelerated)
        let poreAnalysis: PoreAnalysis? = poreAnalyzer.analyzePores(texture: textureImage)
        AppLogger.metrics.debug("      ✓ Pore analysis complete")
        
        // Check cancellation between analyzer steps
        guard !Task.isCancelled else {
            AppLogger.metrics.info("🛑 GPU analyzers cancelled after pore analysis")
            return nil
        }

        // Acne analysis (GPU-accelerated)
        let acneAnalysis: AcneAnalysis? = acneAnalyzer.analyzeAcne(texture: textureImage)
        AppLogger.metrics.debug("      ✓ Acne analysis complete")
        
        // Check cancellation between analyzer steps
        guard !Task.isCancelled else {
            AppLogger.metrics.info("🛑 GPU analyzers cancelled after acne analysis")
            return nil
        }

        // Redness analysis (GPU-accelerated)
        let rednessAnalysis: RednessAnalysis? = rednessAnalyzer.analyzeRedness(texture: textureImage)
        AppLogger.metrics.debug("      ✓ Redness analysis complete")

        let parallelTime = Date().timeIntervalSince1970 - parallelStartTime
        AppLogger.metrics.info("   ⚡️ Advanced analysis completed in \(String(format: "%.3f", parallelTime))s")

        AppLogger.metrics.info("   Advanced metrics computed:")
        if let elasticity = elasticityAnalysis {
            AppLogger.metrics.info("   - Elasticity: \(elasticity.overallScore)/100 (\(elasticity.elasticityLevel.rawValue))")
        }
        if let volume = volumeAnalysis {
            AppLogger.metrics.info("   - Volume: \(volume.overallScore)/100")
        }
        if let regional = regionalAnalysis {
            let underEyeScore = regional.underEyeDarkness?.score ?? 0
            let jawlineScore = regional.jawlineDefinition?.definition ?? 0
            AppLogger.metrics.info("   - Regional: Under-eye \(underEyeScore)/100, Jawline \(jawlineScore)/100")
        }
        if let wrinkles = wrinkleAnalysis {
            AppLogger.metrics.info("   - Wrinkles: \(wrinkles.overallScore)/100 (\(wrinkles.wrinkleDepth.rawValue), count: \(wrinkles.wrinkleCount))")
        }
        if let pores = poreAnalysis {
            AppLogger.metrics.info("   - Pores: visibility \(pores.visibility)/100")
        }
        if let acne = acneAnalysis {
            AppLogger.metrics.info("   - Acne: \(acne.overallScore)/100 (\(acne.severity.rawValue), count: \(acne.blemishCount))")
        }
        if let redness = rednessAnalysis {
            AppLogger.metrics.info("   - Redness: \(redness.overallScore)/100 (\(redness.rednessLevel.rawValue))")
        }
        if let topology = topologyAnalysis {
            AppLogger.metrics.info("   - Topology: \(String(format: "%.1f", topology.overallScore))/100 (\(topology.qualityLevel.rawValue)) - Manifold: \(topology.isManifold), Watertight: \(topology.isWatertight)")
        }

        // Step 6: Apply skin tone normalization to pigmentation and discoloration scores
        let normalizedPigmentationScore = skinToneNormalizer.normalizePigmentationScore(
            rawScore: globalResults.pigmentationScore,
            skinTone: skinTone
        )
        let normalizedDiscolorationScore = skinToneNormalizer.normalizeDiscolorationScore(
            rawScore: globalResults.discolorationScore,
            skinTone: skinTone
        )

        AppLogger.metrics.info("   📊 Skin tone normalization applied:")
        AppLogger.metrics.info("      Pigmentation: \(String(format: "%.1f", globalResults.pigmentationScore)) → \(String(format: "%.1f", normalizedPigmentationScore))")
        AppLogger.metrics.info("      Discoloration: \(String(format: "%.1f", globalResults.discolorationScore)) → \(String(format: "%.1f", normalizedDiscolorationScore))")

        // Calculate hydration score from ROI moisture proxies (for display only - not in overall score)
        let moistureValues = roiMetrics.values.map { $0.moistureProxy.moistureIndex }
        let avgMoisture = Float(moistureValues.reduce(0, +)) / Float(moistureValues.count)
        let _ = avgMoisture * 100  // Convert 0-1 to 0-100 score (reserved for future use)

        // Run skin type classification
        AppLogger.metrics.info("   🔍 Running SkinTypeClassifier...")
        let skinTypeAnalysis = skinTypeClassifier.classifySkinType(
            texture: textureImage,
            roughnessScore: globalResults.roughnessScore,
            specularity: globalResults.specular ?? 0.5
        )
        AppLogger.metrics.info("   - Skin Type: \(skinTypeAnalysis.skinType.rawValue) (confidence: \(String(format: "%.0f", skinTypeAnalysis.confidence * 100))%)")
        AppLogger.metrics.info("      Oiliness: \(String(format: "%.0f", skinTypeAnalysis.oilinessScore))%, Dryness: \(String(format: "%.0f", skinTypeAnalysis.drynessScore))%")

        // Recalculate overall score with normalized values using new 5-metric formula
        // ONLY includes high-confidence metrics (70%+ confidence):
        // - Smoothness (85%), Pores (70-90%), Pigmentation (80%), Discoloration (80%), Acne (75-85%)
        // Excluded: Elasticity (requires 2+ scans), Hydration (proxy method ~65%), Oil Control (disabled), Redness (measurement limitations)
        let normalizedOverallScore = scoring.computeOverallScore(
            smoothnessScore: globalResults.roughnessScore,
            poresScore: poreAnalysis?.visibilityScore,
            pigmentationScore: normalizedPigmentationScore,
            discolorationScore: normalizedDiscolorationScore,
            acneScore: acneAnalysis?.overallScore
        )

        // Calculate intermediate processing time (will be updated at the end with actual total)
        let intermediateProcessingTime = Date().timeIntervalSince1970 - startTime

        let metrics = Face3DMetrics(
            roiMetrics: roiMetrics,
            globalRoughnessProxy: globalResults.roughness,
            globalPigmentationIndex: globalResults.pigmentation,
            globalDiscolorationIndex: globalResults.discoloration,
            globalSpecularProxy: globalResults.specular,
            globalAverageLuminance: globalResults.luminance,
            globalRoughnessScore: globalResults.roughnessScore,
            globalPigmentationScore: normalizedPigmentationScore,  // NORMALIZED
            globalDiscolorationScore: normalizedDiscolorationScore,  // NORMALIZED
            globalSpecularScore: globalResults.specularScore,
            overallScore: normalizedOverallScore,  // NORMALIZED
            scoreInterpretation: scoring.interpretScore(normalizedOverallScore),
            vertexCount: unifiedMesh.vertexCount,
            triangleCount: unifiedMesh.triangleCount,
            textureResolution: CGSize(width: unifiedTexture.width, height: unifiedTexture.height),
            processingTime: intermediateProcessingTime,  // Temporary - will be updated at end
            textureQuality: textureQualityResult.qualityDescription,
            lowConfidenceROIs: lowConfidenceROIs,
            isHighQuality: textureQualityResult.isValid && globalValidity.isValid,
            elasticityAnalysis: elasticityAnalysis,
            volumeAnalysis: volumeAnalysis,
            regionalAnalysis: regionalAnalysis,
            skinTypeAnalysis: skinTypeAnalysis,
            wrinkleAnalysis: wrinkleAnalysis,
            poreAnalysis: poreAnalysis,
            acneAnalysis: acneAnalysis,
            rednessAnalysis: rednessAnalysis,
            topologyAnalysis: topologyAnalysis
        )

        // Glow and radiance analysis (differentiated measurements)
        // IMPORTANT: Uses same RAW textureImage as all other analyzers for consistency
        AppLogger.metrics.info("   ✨ Running GlowAnalyzer...")
        let glowAnalyzer = GlowAnalyzer()
        let glowAnalysis = glowAnalyzer.analyzeGlow(
            texture: textureImage,  // Use consistent RAW image
            geometry: unifiedMesh.geometry,
            existingMetrics: metrics,
            specularAnalyzer: specularAnalyzer
        )
        AppLogger.metrics.info("   - Skin Analysis Score: \(String(format: "%.1f", glowAnalysis.skinHealthScore))/100")
        AppLogger.metrics.info("   - Radiance Score (Luminosity): \(String(format: "%.1f", glowAnalysis.radianceScore))/100")

        // Hydration estimation (multi-method ensemble)
        // IMPORTANT: Uses same RAW textureImage as all other analyzers for consistency
        AppLogger.metrics.info("   💧 Running HydrationEstimator...")
        let hydrationEstimate = hydrationEstimator.estimateHydration(
            texture: textureImage,  // Use consistent RAW image
            roughnessScore: metrics.globalRoughnessScore,
            geometry: unifiedMesh.geometry
        )
        AppLogger.metrics.info("   - Hydration Score: \(String(format: "%.1f", hydrationEstimate.overallScore))/100 (\(hydrationEstimate.level.rawValue))")
        AppLogger.metrics.info("      Methods: Specularity \(String(format: "%.0f", hydrationEstimate.specularityScore))%, Texture \(String(format: "%.0f", hydrationEstimate.textureScore))%, Variance \(String(format: "%.0f", hydrationEstimate.varianceScore))%")

        // Update ROI metrics with real moisture data from hydration estimate
        let moistureProxy = MoistureProxy(
            moistureIndex: Double(hydrationEstimate.overallScore) / 100.0,
            specularRatio: Double(hydrationEstimate.specularityScore) / 100.0,
            smoothnessLowFreq: Double(hydrationEstimate.textureScore) / 100.0
        )

        var updatedROIMetrics: [Face3DROI: ROI3DMetrics] = [:]
        for (roi, roiMetric) in metrics.roiMetrics {
            // Create updated ROI metric with real moisture data
            let updatedMetric = ROI3DMetrics(
                roi: roi,
                roughnessProxy: roiMetric.roughnessProxy,
                pigmentationIndex: roiMetric.pigmentationIndex,
                specularProxy: roiMetric.specularProxy,
                blurScore: roiMetric.blurScore,
                textureEnergy: roiMetric.textureEnergy,
                labVariance: roiMetric.labVariance,
                qualityScore: roiMetric.qualityScore,
                moistureProxy: moistureProxy,  // Use real hydration data
                pixelCount: roiMetric.pixelCount,
                averageLuminance: roiMetric.averageLuminance,
                averageLightness: roiMetric.averageLightness,
                averageAChannel: roiMetric.averageAChannel,
                averageBChannel: roiMetric.averageBChannel,
                roughnessScore: roiMetric.roughnessScore,
                pigmentationScore: roiMetric.pigmentationScore,
                specularScore: roiMetric.specularScore,
                isLowConfidence: roiMetric.isLowConfidence,
                confidenceLevel: roiMetric.confidenceLevel
            )
            updatedROIMetrics[roi] = updatedMetric
        }

        // Calculate ACTUAL total processing time including all parallel analyzers
        let actualProcessingTime = Date().timeIntervalSince1970 - startTime

        // Update metrics with sun damage analysis, glow analysis, and hydration estimate
        let finalMetrics = Face3DMetrics(
            roiMetrics: updatedROIMetrics,
            globalRoughnessProxy: metrics.globalRoughnessProxy,
            globalPigmentationIndex: metrics.globalPigmentationIndex,
            globalDiscolorationIndex: metrics.globalDiscolorationIndex,
            globalSpecularProxy: metrics.globalSpecularProxy,
            globalAverageLuminance: metrics.globalAverageLuminance,
            globalRoughnessScore: metrics.globalRoughnessScore,
            globalPigmentationScore: metrics.globalPigmentationScore,
            globalDiscolorationScore: metrics.globalDiscolorationScore,
            globalSpecularScore: metrics.globalSpecularScore,
            overallScore: metrics.overallScore,
            scoreInterpretation: metrics.scoreInterpretation,
            vertexCount: metrics.vertexCount,
            triangleCount: metrics.triangleCount,
            textureResolution: metrics.textureResolution,
            processingTime: actualProcessingTime,  // Use actual total time
            textureQuality: metrics.textureQuality,
            lowConfidenceROIs: metrics.lowConfidenceROIs,
            isHighQuality: metrics.isHighQuality,
            elasticityAnalysis: metrics.elasticityAnalysis,
            volumeAnalysis: metrics.volumeAnalysis,
            regionalAnalysis: metrics.regionalAnalysis,
            skinTypeAnalysis: metrics.skinTypeAnalysis,
            wrinkleAnalysis: metrics.wrinkleAnalysis,
            poreAnalysis: metrics.poreAnalysis,
            acneAnalysis: metrics.acneAnalysis,
            rednessAnalysis: metrics.rednessAnalysis,
            hydrationEstimate: hydrationEstimate,
            topologyAnalysis: metrics.topologyAnalysis,
            glowAnalysis: glowAnalysis
        )

        AppLogger.metrics.info("✅ Face3DMetricsAnalyzer: Complete in \(actualProcessingTime)s")
        AppLogger.metrics.info("   Overall Score: \(globalResults.overallScore)/10 (\(globalResults.scoreInterpretation))")
        if !lowConfidenceROIs.isEmpty {
            AppLogger.metrics.warning("   ⚠️ Low confidence ROIs (excluded from global): \(lowConfidenceROIs.map { $0.displayName }.joined(separator: ", "))")
        }
        return finalMetrics
    }

    // MARK: - ROI Metrics Computation

    private func computeROI3DMetrics(_ sample: ROITextureSample, rawSample: ROITextureSample?, confidence: ROIConfidence?, lightingQuality: Float?) async -> ROI3DMetrics {
        AppLogger.metrics.debug("      → Computing roughness...")
        // Compute roughness proxy
        let roughness = roughnessAnalyzer.computeRoughnessProxy(sample)
        AppLogger.metrics.debug("      ✓ Roughness: \(roughness)")

        AppLogger.metrics.debug("      → Computing pigmentation...")
        // Compute pigmentation index WITH lighting quality correction
        let pigmentation = pigmentationAnalyzer.computePigmentationIndex(sample, lightingQuality: lightingQuality)
        AppLogger.metrics.debug("      ✓ Pigmentation: \(pigmentation)")

        // Compute specular proxy (if raw frames available)
        let specular: Float?
        if configuration.computeSpecular, let rawSample = rawSample {
            AppLogger.metrics.debug("      → Computing specular...")
            specular = specularAnalyzer.computeSpecularProxy(rawSample)
            AppLogger.metrics.debug("      ✓ Specular: \(specular ?? 0)")
        } else {
            specular = nil
        }

        AppLogger.metrics.debug("      → Computing luminance...")
        // Compute average luminance
        let luminance = computeAverageLuminance(sample.pixels)
        AppLogger.metrics.debug("      ✓ Luminance: \(luminance)")

        AppLogger.metrics.debug("      → Computing CIELAB values...")
        // Compute average CIELAB values
        let labMean = discolorationAnalyzer.computeLABMean(sample)
        AppLogger.metrics.debug("      ✓ LAB mean computed")

        // Compute scores WITH lighting quality-aware adaptive thresholds
        let roughnessScore = scoring.mapRoughnessScore(roughness)
        let pigmentationScore = scoring.mapPigmentationScore(pigmentation, lightingQuality: lightingQuality)
        let specularScore = specular.map { scoring.mapSpecularScore($0) }

        return ROI3DMetrics(
            roi: sample.roi,
            roughnessProxy: roughness,
            pigmentationIndex: pigmentation,
            specularProxy: specular,
            pixelCount: sample.pixelCount,
            averageLuminance: luminance,
            averageLightness: labMean.l,
            averageAChannel: labMean.a,
            averageBChannel: labMean.b,
            roughnessScore: roughnessScore,
            pigmentationScore: pigmentationScore,
            specularScore: specularScore,
            isLowConfidence: !(confidence?.isValid ?? true),
            confidenceLevel: confidence?.confidenceLevel.rawValue ?? "High"
        )
    }

    // MARK: - Global Metrics

    private func computeGlobalMetrics(
        roiMetrics: [Face3DROI: ROI3DMetrics],
        roiSamples: [Face3DROI: ROITextureSample],
        lightingQuality: Float?
    ) -> (
        roughness: Float,
        pigmentation: Float,
        discoloration: Float,
        specular: Float?,
        luminance: Float,
        roughnessScore: Float,
        pigmentationScore: Float,
        discolorationScore: Float,
        specularScore: Float?,
        overallScore: Float,
        scoreInterpretation: String
    ) {

        guard !roiMetrics.isEmpty else {
            // Return default scores instead of 0 to prevent showing 0 in UI
            AppLogger.metrics.warning("⚠️ computeGlobalMetrics: roiMetrics is empty, using default scores")
            return (0.15, 0.15, 0.15, nil, 0.5, 50, 50, 50, nil, 50, "Fair")
        }

        var totalRoughness: Float = 0
        var totalPigmentation: Float = 0
        var totalLuminance: Float = 0
        var totalSpecular: Float = 0
        var totalPixels: Int = 0
        var specularROICount: Int = 0
        var highConfidenceCount: Int = 0

        // Weighted average by pixel count (exclude low confidence ROIs)
        for (_, metrics) in roiMetrics {
            // Skip low confidence ROIs from global metrics
            if metrics.isLowConfidence {
                continue
            }
            highConfidenceCount += 1

            let weight = Float(metrics.pixelCount)
            totalRoughness += metrics.roughnessProxy * weight
            totalPigmentation += metrics.pigmentationIndex * weight
            totalLuminance += metrics.averageLuminance * weight
            totalPixels += metrics.pixelCount

            if let specular = metrics.specularProxy {
                totalSpecular += specular * weight
                specularROICount += 1
            }
        }

        // SAFETY: If all ROIs were low confidence, include them anyway rather than returning 0
        if highConfidenceCount == 0 {
            AppLogger.metrics.warning("⚠️ computeGlobalMetrics: All ROIs are low confidence, including them anyway")
            for (_, metrics) in roiMetrics {
                let weight = Float(metrics.pixelCount)
                totalRoughness += metrics.roughnessProxy * weight
                totalPigmentation += metrics.pigmentationIndex * weight
                totalLuminance += metrics.averageLuminance * weight
                totalPixels += metrics.pixelCount

                if let specular = metrics.specularProxy {
                    totalSpecular += specular * weight
                    specularROICount += 1
                }
            }
        }

        let weightSum = Float(totalPixels)

        // SAFETY: Provide default values if no pixels were sampled
        let globalRoughness = weightSum > 0 ? totalRoughness / weightSum : 0.15
        let globalPigmentation = weightSum > 0 ? totalPigmentation / weightSum : 0.15
        let globalLuminance = weightSum > 0 ? totalLuminance / weightSum : 0.5
        let globalSpecular: Float? = specularROICount > 0 && weightSum > 0 ? totalSpecular / weightSum : nil

        // Compute discoloration (inter-ROI variance)
        var roiLABMeans: [Face3DROI: DiscolorationAnalyzer.LABMean] = [:]
        for (roi, sample) in roiSamples {
            roiLABMeans[roi] = discolorationAnalyzer.computeLABMean(sample)
        }
        let globalDiscoloration = discolorationAnalyzer.computeDiscolorationIndex(roiLABMeans, lightingQuality: lightingQuality)

        // Compute scores WITH lighting quality-aware adaptive thresholds
        let roughnessScore = scoring.mapRoughnessScore(globalRoughness)
        let pigmentationScore = scoring.mapPigmentationScore(globalPigmentation, lightingQuality: lightingQuality)
        let discolorationScore = scoring.mapDiscolorationScore(globalDiscoloration, lightingQuality: lightingQuality)
        let specularScore = globalSpecular.map { scoring.mapSpecularScore($0) }

        // DIAGNOSTIC: Log global metrics with clear interpretation
        AppLogger.metrics.info("📊 Global Metrics Summary:")
        AppLogger.metrics.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Roughness (Lower proxy = Better score)
        AppLogger.metrics.info("   Roughness Proxy: \(String(format: "%.4f", Double(globalRoughness))) [0=smooth, 1=rough]")
        AppLogger.metrics.info("   → Smoothness Score: \(String(format: "%.1f", Double(roughnessScore)))/100 [higher=better]")

        // Pigmentation (Lower index = Better score)
        AppLogger.metrics.info("   Pigmentation Index: \(String(format: "%.4f", Double(globalPigmentation))) [0=even, 1=uneven]")
        AppLogger.metrics.info("   → Evenness Score: \(String(format: "%.1f", Double(pigmentationScore)))/100 [higher=better]")

        // Discoloration (Lower index = Better score)
        AppLogger.metrics.info("   Discoloration Index: \(String(format: "%.4f", Double(globalDiscoloration))) [0=uniform, 1=patchy]")
        AppLogger.metrics.info("   → Uniformity Score: \(String(format: "%.1f", Double(discolorationScore)))/100 [higher=better]")

        // Specular (Lower proxy = Better score)
        if let spec = globalSpecular, let specScore = specularScore {
            AppLogger.metrics.info("   Specular Proxy: \(String(format: "%.4f", Double(spec))) [0.02=dry, 0.18=oily]")
            AppLogger.metrics.info("   → Oil Control Score: \(String(format: "%.1f", Double(specScore)))/100 [higher=better]")
        }
        AppLogger.metrics.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // SAFETY CHECK: Validate roughness score
        if roughnessScore == 0 {
            AppLogger.metrics.warning("🚨 SMOOTHNESS SCORE = 0/100 (WORST possible - very rough skin)")
            AppLogger.metrics.warning("   Roughness Proxy: \(String(format: "%.4f", Double(globalRoughness)))")
            if globalRoughness > 0.50 {
                AppLogger.metrics.warning("   ✓ Proxy >0.50 confirms extremely rough texture")
            } else if globalRoughness < 0.08 {
                AppLogger.metrics.warning("   ✗ Proxy <0.08 but score=0 → SCORING BUG!")
            } else {
                AppLogger.metrics.warning("   ? Proxy moderate but score=0 → Check mapping logic")
            }
            AppLogger.metrics.warning("   Expected for young skin: score 70-85")
        } else if roughnessScore >= 90 {
            AppLogger.metrics.info("✅ Excellent smoothness score: \(String(format: "%.1f", Double(roughnessScore)))/100")
        }

        // Compute overall score using legacy 4-metric formula (for internal helper)
        let overallScore = scoring.computeOverallScoreLegacy(
            roughnessScore: roughnessScore,
            pigmentationScore: pigmentationScore,
            discolorationScore: discolorationScore,
            specularScore: specularScore
        )

        let scoreInterpretation = scoring.interpretScore(overallScore)

        return (
            globalRoughness,
            globalPigmentation,
            globalDiscoloration,
            globalSpecular,
            globalLuminance,
            roughnessScore,
            pigmentationScore,
            discolorationScore,
            specularScore,
            overallScore,
            scoreInterpretation
        )
    }

    // MARK: - Helpers

    private func computeAverageLuminance(_ pixels: [SIMD3<Float>]) -> Float {
        guard !pixels.isEmpty else { return 0 }

        var sum: Float = 0
        for pixel in pixels {
            // FIXED: Standardized on BT.709 (sRGB) for consistency across all analyzers
            sum += 0.2126 * pixel.x + 0.7152 * pixel.y + 0.0722 * pixel.z
        }

        return sum / Float(pixels.count)
    }

    /// Convert UnifiedMesh to FaceMeshGeometry for advanced analyzers
    private func convertToFaceMeshGeometry(unifiedMesh: UnifiedMesh) -> FaceMeshGeometry {
        // CRITICAL FIX: Do NOT apply scaling here - vertices are already scaled by 0.63x
        // when UnifiedMesh was created from FaceMeshGeometry.init(faceAnchor:)
        // Applying scaling again would result in 0.63 × 0.63 = 0.40x (too small!)

        // Convert Vector3 to SIMD3<Float> WITHOUT additional scaling
        let vertices = unifiedMesh.vertices.map { $0.toSIMD() }
        let normals = unifiedMesh.normals.map { $0.toSIMD() }
        let textureCoordinates = unifiedMesh.textureCoordinates.map { $0.toSIMD() }

        // Create a dummy transform (identity matrix since we're already in world space)
        let transform = simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )

        // Create FaceMeshGeometry using the raw data initializer
        return FaceMeshGeometry(
            vertices: vertices,
            normals: normals,
            textureCoordinates: textureCoordinates,
            triangleIndices: unifiedMesh.triangleIndices,
            transform: transform,
            timestamp: Date().timeIntervalSince1970
        )
    }
}

