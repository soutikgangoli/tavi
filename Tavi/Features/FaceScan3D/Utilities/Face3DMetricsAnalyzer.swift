//
//  Face3DMetricsAnalyzer.swift
//  Tavi
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
    private let sunDamageAnalyzer: SunDamageAnalyzer

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
        self.sunDamageAnalyzer = SunDamageAnalyzer()
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

        // Step 0: Validate texture quality
        let textureQualityResult = qualityValidator.validateTexture(unifiedTexture)
        AppLogger.metrics.info("   Texture quality: \(textureQualityResult.qualityDescription)")

        if !textureQualityResult.isValid {
            AppLogger.metrics.warning("⚠️ \(textureQualityResult.reason ?? "Poor texture quality")")
            // Note: Still proceed but mark as low quality
        }

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

        // Step 3: Convert CGImage to UIImage for initial quality assessment
        var textureImage = UIImage(cgImage: unifiedTexture)

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
                // Start new tasks up to concurrency limit
                while activeCount < maxConcurrentOperations && !pendingROIs.isEmpty {
                    let (roi, sample) = pendingROIs.removeFirst()
                    let confidence = roiConfidences[roi]
                    let lightingScore = lightingQualityScore  // Capture for async context

                    group.addTask {
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

        // Step 4.5: Pre-detect skin tone on RAW image (before normalization)
        // This enables adaptive color temperature targets based on natural skin characteristics
        AppLogger.metrics.info("   📊 Pre-detecting skin tone on raw image...")
        let rawSkinTone = skinToneNormalizer.detectSkinTone(texture: textureImage)
        AppLogger.metrics.info("      Detected: \(rawSkinTone.rawValue) (reference L*: \(rawSkinTone.referenceL))")

        // Step 4.6: Apply skin-tone-aware color temperature normalization
        AppLogger.metrics.info("   🌡️ Normalizing color temperature (adaptive)...")
        let detectedColorTemp = colorTempNormalizer.estimateColorTemperature(from: textureImage)
        let lightingType = colorTempNormalizer.detectLightingType(ambientColorTemperature: detectedColorTemp)
        AppLogger.metrics.info("      Detected: \(String(format: "%.0f", detectedColorTemp))K (\(lightingType.rawValue))")

        // Determine adaptive target based on skin tone (preserves natural undertones)
        let adaptiveTarget: CGFloat
        switch rawSkinTone {
        case .veryLight, .light:
            adaptiveTarget = 6000  // Standard daylight
        case .medium, .mediumDark:
            adaptiveTarget = 5800  // Preserve golden undertones (Indian/Asian skin)
        case .dark, .veryDark:
            adaptiveTarget = 5600  // More warmth preservation (African/Dark skin)
        }
        AppLogger.metrics.info("      Adaptive target: \(String(format: "%.0f", adaptiveTarget))K for \(rawSkinTone.rawValue) skin")

        if abs(detectedColorTemp - adaptiveTarget) > 500 {  // Only normalize if difference > 500K
            if let normalizedImage = colorTempNormalizer.normalizeColorTemperature(
                image: textureImage,
                currentColorTemp: detectedColorTemp,
                targetColorTemp: adaptiveTarget,
                skinTone: rawSkinTone
            ) {
                textureImage = normalizedImage
                AppLogger.metrics.info("      ✅ Normalized \(String(format: "%.0f", detectedColorTemp))K → \(String(format: "%.0f", adaptiveTarget))K")
            } else {
                AppLogger.metrics.warning("      ⚠️ Color temp normalization failed, using original texture")
            }
        } else {
            AppLogger.metrics.info("      ✅ Color temperature already near target (\(String(format: "%.0f", detectedColorTemp))K)")
        }

        // Step 5: Final skin tone detection (on normalized image for validation)
        let skinTone = skinToneNormalizer.detectSkinTone(texture: textureImage)
        AppLogger.metrics.info("   📊 Final skin tone: \(skinTone.rawValue) (reference L*: \(skinTone.referenceL))")
        if skinTone != rawSkinTone {
            AppLogger.metrics.warning("      ⚠️ Skin tone changed after normalization: \(rawSkinTone.rawValue) → \(skinTone.rawValue)")
        }

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

            elasticityAnalysis = skinElasticityAnalyzer.estimateElasticity(
                historicalScans: historicalScans,
                currentWrinkleDepth: currentWrinkleDepth
            )
        } else {
            elasticityAnalysis = nil
        }

        // Step 5c: Compute remaining advanced metrics IN PARALLEL using TaskGroup
        AppLogger.metrics.info("   🔍 Running advanced analyzers in parallel...")

        let parallelStartTime = Date().timeIntervalSince1970

        // Capture values outside TaskGroup to avoid Sendable issues
        let roughnessScore = globalResults.roughnessScore
        let specularValue = globalResults.specular ?? 0
        let baselineMesh = configuration.baselineMesh

        // Run all independent analyzers concurrently
        // Note: Using nonisolated(unsafe) to suppress Sendable warnings
        // The analyzers don't mutate state and are safe for concurrent access
        AppLogger.metrics.debug("   🚀 Starting parallel analysis tasks...")
        let (volumeAnalysis, regionalAnalysis, skinTypeAnalysis, poreAnalysis, acneAnalysis, rednessAnalysis, topologyAnalysis) = await withTaskGroup(
            of: AnalysisResult.self,
            returning: (VolumeAnalysis?, RegionalAnalysis?, SkinTypeAnalysis?, PoreAnalysis?, AcneAnalysis?, RednessAnalysis?, TopologyAnalysis?).self
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

            // Task 3: Skin type classification (texture-based)
            group.addTask { [skinTypeClassifier] in
                let result = skinTypeClassifier.classifySkinType(
                    texture: textureImage,
                    roughnessScore: roughnessScore,
                    specularity: specularValue
                )
                return .skinType(result)
            }

            // Task 4: Pore analysis (texture-based)
            group.addTask { [poreAnalyzer] in
                let result = poreAnalyzer.analyzePores(texture: textureImage)
                return .pore(result)
            }

            // Task 5: Acne analysis (texture-based)
            group.addTask { [acneAnalyzer] in
                let result = acneAnalyzer.analyzeAcne(texture: textureImage)
                return .acne(result)
            }

            // Task 6: Redness analysis (texture-based)
            group.addTask { [rednessAnalyzer] in
                let result = rednessAnalyzer.analyzeRedness(texture: textureImage)
                return .redness(result)
            }

            // Task 7: Topology analysis (geometry-based)
            group.addTask { [topologyAnalyzer] in
                let result = topologyAnalyzer.analyzeTopology(geometry: faceMeshGeometry)
                return .topology(result)
            }

            // Collect all results
            var volume: VolumeAnalysis?
            var regional: RegionalAnalysis?
            var skinType: SkinTypeAnalysis?
            var pore: PoreAnalysis?
            var acne: AcneAnalysis?
            var redness: RednessAnalysis?
            var topology: TopologyAnalysis?

            for await result in group {
                switch result {
                case .volume(let analysis):
                    AppLogger.metrics.debug("      ✓ Volume analysis complete")
                    volume = analysis
                case .regional(let analysis):
                    AppLogger.metrics.debug("      ✓ Regional analysis complete")
                    regional = analysis
                case .skinType(let analysis):
                    AppLogger.metrics.debug("      ✓ Skin type analysis complete")
                    skinType = analysis
                case .pore(let analysis):
                    AppLogger.metrics.debug("      ✓ Pore analysis complete")
                    pore = analysis
                case .acne(let analysis):
                    AppLogger.metrics.debug("      ✓ Acne analysis complete")
                    acne = analysis
                case .redness(let analysis):
                    AppLogger.metrics.debug("      ✓ Redness analysis complete")
                    redness = analysis
                case .topology(let analysis):
                    AppLogger.metrics.debug("      ✓ Topology analysis complete")
                    topology = analysis
                }
            }

            return (volume, regional, skinType, pore, acne, redness, topology)
        }

        let parallelTime = Date().timeIntervalSince1970 - parallelStartTime
        AppLogger.metrics.info("   ⚡️ Parallel analysis completed in \(String(format: "%.3f", parallelTime))s")

        AppLogger.metrics.info("   Advanced metrics computed:")
        if let elasticity = elasticityAnalysis {
            AppLogger.metrics.info("   - Elasticity: \(elasticity.overallScore)/100 (\(elasticity.elasticityLevel.rawValue))")
        }
        if let volume = volumeAnalysis {
            AppLogger.metrics.info("   - Volume: \(volume.overallScore)/100")
        }
        if let regional = regionalAnalysis {
            AppLogger.metrics.info("   - Regional: Under-eye \(regional.underEyeDarkness.score)/100, Jawline \(regional.jawlineDefinition.definition)/100")
        }
        if let skinType = skinTypeAnalysis {
            AppLogger.metrics.info("   - Skin Type: \(skinType.skinType.rawValue) (confidence: \(skinType.confidence))")
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
        let avgMoisture = moistureValues.reduce(0, +) / Float(moistureValues.count)
        let hydrationScore = avgMoisture * 100  // Convert 0-1 to 0-100 score

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

        // Sun damage analysis (runs AFTER normalization to use corrected scores)
        // Check if sun damage analysis is enabled in settings
        let enableSunDamageAnalysis = UserDefaults.standard.bool(forKey: "enableSunDamageAnalysis")

        let sunDamageAnalysis: SunDamageAnalysis?
        if enableSunDamageAnalysis {
            AppLogger.metrics.info("   🔍 Running SunDamageAnalyzer...")
            sunDamageAnalysis = sunDamageAnalyzer.analyzeSunDamage(
                from: metrics,
                skinTone: skinTone
            )

            if let sunDamage = sunDamageAnalysis {
                AppLogger.metrics.info("   - Sun Protection: \(String(format: "%.1f", sunDamage.protectionScore))/100 (\(sunDamage.damageLevel.rawValue))")
                AppLogger.metrics.info("      Components: Pigmentation \(String(format: "%.0f", sunDamage.pigmentationHealth))%, Photoaging \(String(format: "%.0f", sunDamage.photoagingResistance))%, Texture \(String(format: "%.0f", sunDamage.textureHealth))%")
                AppLogger.metrics.info("      Normalized for \(skinTone.rawValue): ✅")
            }
        } else {
            AppLogger.metrics.info("   ⏭️  Skipping SunDamageAnalyzer (disabled in settings)")
            sunDamageAnalysis = nil
        }

        // Glow and radiance analysis (differentiated measurements)
        AppLogger.metrics.info("   ✨ Running GlowAnalyzer...")
        let glowAnalyzer = GlowAnalyzer()
        let glowAnalysis = glowAnalyzer.analyzeGlow(
            texture: UIImage(cgImage: unifiedTexture),
            geometry: unifiedMesh.geometry,
            existingMetrics: metrics,
            specularAnalyzer: specularAnalyzer
        )
        AppLogger.metrics.info("   - Glow Score (Health): \(String(format: "%.1f", glowAnalysis.glowScore))/100")
        AppLogger.metrics.info("   - Radiance Score (Luminosity): \(String(format: "%.1f", glowAnalysis.radianceScore))/100")

        // Calculate ACTUAL total processing time including all parallel analyzers
        let actualProcessingTime = Date().timeIntervalSince1970 - startTime

        // Update metrics with sun damage analysis and glow analysis
        let finalMetrics = Face3DMetrics(
            roiMetrics: metrics.roiMetrics,
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
            topologyAnalysis: metrics.topologyAnalysis,
            sunDamageAnalysis: sunDamageAnalysis,
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
            return (0, 0, 0, nil, 0, 0, 0, 0, nil, 0, "N/A")
        }

        var totalRoughness: Float = 0
        var totalPigmentation: Float = 0
        var totalLuminance: Float = 0
        var totalSpecular: Float = 0
        var totalPixels: Int = 0
        var specularROICount: Int = 0

        // Weighted average by pixel count (exclude low confidence ROIs)
        for (_, metrics) in roiMetrics {
            // Skip low confidence ROIs from global metrics
            if metrics.isLowConfidence {
                continue
            }

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

        let weightSum = Float(totalPixels)

        let globalRoughness = weightSum > 0 ? totalRoughness / weightSum : 0
        let globalPigmentation = weightSum > 0 ? totalPigmentation / weightSum : 0
        let globalLuminance = weightSum > 0 ? totalLuminance / weightSum : 0
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
            // Standard luminance: Y = 0.299R + 0.587G + 0.114B
            sum += 0.299 * pixel.x + 0.587 * pixel.y + 0.114 * pixel.z
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

