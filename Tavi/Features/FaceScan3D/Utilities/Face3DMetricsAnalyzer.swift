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

    // MARK: - Configuration

    public struct Configuration {
        /// Whether to compute specular/oiliness metrics (requires raw RGB frames)
        public var computeSpecular: Bool = false

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

        print("🔬 Face3DMetricsAnalyzer: Starting analysis...")

        // Step 0: Validate texture quality
        let textureQualityResult = qualityValidator.validateTexture(unifiedTexture)
        print("   Texture quality: \(textureQualityResult.qualityDescription)")

        if !textureQualityResult.isValid {
            print("⚠️ \(textureQualityResult.reason ?? "Poor texture quality")")
            // Note: Still proceed but mark as low quality
        }

        // Step 1: Generate ROI masks
        let masks = roiMaskGenerator.generateROIMasks(
            from: unifiedMesh.textureCoordinates.map { $0.toSIMD() },
            topology: unifiedMesh.triangleIndices
        )

        print("   Generated \(masks.count) ROI masks")

        // Step 2: Sample texture for each ROI
        var roiSamples: [Face3DROI: ROITextureSample] = [:]

        for (roi, mask) in masks {
            if let sample = ROITextureSampler.sampleROITexture(unifiedTexture, mask: mask) {
                roiSamples[roi] = sample
                print("   Sampled \(sample.pixelCount) pixels for \(roi.displayName)")
            }
        }

        guard !roiSamples.isEmpty else {
            print("⚠️ No ROI samples could be extracted")
            return nil
        }

        // Step 2.5: Validate ROI samples
        let roiConfidences = qualityValidator.validateROISamples(roiSamples)
        let globalValidity = qualityValidator.canComputeGlobalMetrics(roiConfidences)

        var lowConfidenceROIs: [Face3DROI] = []
        for (roi, confidence) in roiConfidences {
            if !confidence.isValid {
                print("   ⚠️ \(roi.displayName) has low confidence (\(confidence.pixelCount) pixels < \(confidence.minimumRequired))")
                lowConfidenceROIs.append(roi)
            }
        }

        // Step 3: Compute metrics for each ROI
        var roiMetrics: [Face3DROI: ROI3DMetrics] = [:]

        for (roi, sample) in roiSamples {
            let confidence = roiConfidences[roi]
            let metrics = await computeROI3DMetrics(sample, rawSample: nil, confidence: confidence)
            roiMetrics[roi] = metrics
            print("   \(roi.displayName): roughness=\(metrics.roughnessProxy), pigmentation=\(metrics.pigmentationIndex), confidence=\(metrics.confidenceLevel)")
        }

        // Step 4: Compute global metrics and scores
        let globalResults = computeGlobalMetrics(
            roiMetrics: roiMetrics,
            roiSamples: roiSamples
        )

        let processingTime = Date().timeIntervalSince1970 - startTime

        // Step 5: Convert UnifiedMesh to FaceMeshGeometry for advanced analyzers
        let faceMeshGeometry = convertToFaceMeshGeometry(unifiedMesh: unifiedMesh)

        // Convert CGImage to UIImage for texture-based analyzers
        var textureImage = UIImage(cgImage: unifiedTexture)

        // Step 4.5: Apply color temperature normalization BEFORE all analysis
        print("   🌡️ Normalizing color temperature...")
        let detectedColorTemp = colorTempNormalizer.estimateColorTemperature(from: textureImage)
        let lightingType = colorTempNormalizer.detectLightingType(ambientColorTemperature: detectedColorTemp)
        print("      Detected: \(String(format: "%.0f", detectedColorTemp))K (\(lightingType))")

        // Normalize to standard daylight (6000K) for consistent analysis
        let targetColorTemp: CGFloat = 6000
        if abs(detectedColorTemp - targetColorTemp) > 500 {  // Only normalize if difference > 500K
            if let normalizedImage = colorTempNormalizer.normalizeColorTemperature(
                image: textureImage,
                currentColorTemp: detectedColorTemp,
                targetColorTemp: targetColorTemp
            ) {
                textureImage = normalizedImage
                print("      ✅ Normalized \(String(format: "%.0f", detectedColorTemp))K → \(String(format: "%.0f", targetColorTemp))K")
            } else {
                print("      ⚠️ Color temp normalization failed, using original texture")
            }
        } else {
            print("      ✅ Color temperature already near target (\(String(format: "%.0f", detectedColorTemp))K)")
        }

        // Step 5: Detect skin tone for normalization
        let skinTone = skinToneNormalizer.detectSkinTone(texture: textureImage)
        print("   📊 Detected skin tone: \(skinTone) (reference L*: \(skinTone.referenceL))")

        // Step 5a: Compute wrinkle analysis FIRST (needed for elasticity calculation)
        print("   🔍 Running WrinkleAnalyzer...")
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
                print("   Using actual wrinkle depth for elasticity: \(String(format: "%.4f", currentWrinkleDepth))mm")
            } else {
                // Fallback to roughness only if wrinkle analysis failed
                currentWrinkleDepth = globalResults.roughness * 0.001  // Convert to meters
                print("   ⚠️ Wrinkle analysis unavailable, using roughness fallback")
            }

            elasticityAnalysis = skinElasticityAnalyzer.estimateElasticity(
                historicalScans: historicalScans,
                currentWrinkleDepth: currentWrinkleDepth
            )
        } else {
            elasticityAnalysis = nil
        }

        // Step 5c: Compute remaining advanced metrics
        print("   🔍 Running advanced analyzers...")

        // Volume metrics
        let volumeAnalysis: VolumeAnalysis? = volumeMetricsAnalyzer.analyzeVolume(
            geometry: faceMeshGeometry,
            baseline: configuration.baselineMesh
        )

        // Regional analysis
        let regionalAnalysis: RegionalAnalysis? = regionalAnalyzers.analyzeRegions(
            geometry: faceMeshGeometry,
            texture: textureImage
        )

        // Skin type classification
        let skinTypeAnalysis: SkinTypeAnalysis? = skinTypeClassifier.classifySkinType(
            texture: textureImage,
            roughnessScore: globalResults.roughnessScore,
            specularity: globalResults.specular ?? 0
        )

        // Pore analysis (high-frequency texture)
        print("   🔍 Running PoreAnalyzer...")
        let poreAnalysis: PoreAnalysis? = poreAnalyzer.analyzePores(texture: textureImage)

        // Acne and blemish detection
        print("   🔍 Running AcneAnalyzer...")
        let acneAnalysis: AcneAnalysis? = acneAnalyzer.analyzeAcne(texture: textureImage)

        // Redness and inflammation detection
        print("   🔍 Running RednessAnalyzer...")
        let rednessAnalysis: RednessAnalysis? = rednessAnalyzer.analyzeRedness(texture: textureImage)

        // Mesh topology quality analysis
        print("   🔍 Running TopologyAnalyzer...")
        let topologyAnalysis: TopologyAnalysis? = topologyAnalyzer.analyzeTopology(geometry: faceMeshGeometry)

        print("   Advanced metrics computed:")
        if let elasticity = elasticityAnalysis {
            print("   - Elasticity: \(elasticity.overallScore)/100 (\(elasticity.elasticityLevel))")
        }
        if let volume = volumeAnalysis {
            print("   - Volume: \(volume.overallScore)/100")
        }
        if let regional = regionalAnalysis {
            print("   - Regional: Under-eye \(regional.underEyeDarkness.score)/100, Jawline \(regional.jawlineDefinition.definition)/100")
        }
        if let skinType = skinTypeAnalysis {
            print("   - Skin Type: \(skinType.skinType) (confidence: \(skinType.confidence))")
        }
        if let wrinkles = wrinkleAnalysis {
            print("   - Wrinkles: \(wrinkles.overallScore)/100 (\(wrinkles.wrinkleDepth), count: \(wrinkles.wrinkleCount))")
        }
        if let pores = poreAnalysis {
            print("   - Pores: visibility \(pores.visibility)/100")
        }
        if let acne = acneAnalysis {
            print("   - Acne: \(acne.overallScore)/100 (\(acne.severity), count: \(acne.blemishCount))")
        }
        if let redness = rednessAnalysis {
            print("   - Redness: \(redness.overallScore)/100 (\(redness.rednessLevel))")
        }
        if let topology = topologyAnalysis {
            print("   - Topology: \(String(format: "%.1f", topology.overallScore))/100 (\(topology.qualityLevel)) - Manifold: \(topology.isManifold), Watertight: \(topology.isWatertight)")
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

        print("   📊 Skin tone normalization applied:")
        print("      Pigmentation: \(String(format: "%.1f", globalResults.pigmentationScore)) → \(String(format: "%.1f", normalizedPigmentationScore))")
        print("      Discoloration: \(String(format: "%.1f", globalResults.discolorationScore)) → \(String(format: "%.1f", normalizedDiscolorationScore))")

        // Recalculate overall score with normalized values
        let normalizedOverallScore = scoring.computeOverallScore(
            roughnessScore: globalResults.roughnessScore,
            pigmentationScore: normalizedPigmentationScore,
            discolorationScore: normalizedDiscolorationScore,
            specularScore: globalResults.specularScore
        )

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
            processingTime: processingTime,
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
            print("   🔍 Running SunDamageAnalyzer...")
            sunDamageAnalysis = sunDamageAnalyzer.analyzeSunDamage(
                from: metrics,
                skinTone: skinTone
            )

            if let sunDamage = sunDamageAnalysis {
                print("   - Sun Protection: \(String(format: "%.1f", sunDamage.protectionScore))/100 (\(sunDamage.damageLevel.rawValue))")
                print("      Components: Pigmentation \(String(format: "%.0f", sunDamage.pigmentationHealth))%, Photoaging \(String(format: "%.0f", sunDamage.photoagingResistance))%, Texture \(String(format: "%.0f", sunDamage.textureHealth))%")
                print("      Normalized for \(skinTone): ✅")
            }
        } else {
            print("   ⏭️  Skipping SunDamageAnalyzer (disabled in settings)")
            sunDamageAnalysis = nil
        }

        // Update metrics with sun damage analysis
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
            processingTime: metrics.processingTime,
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
            sunDamageAnalysis: sunDamageAnalysis
        )

        print("✅ Face3DMetricsAnalyzer: Complete in \(processingTime)s")
        print("   Overall Score: \(globalResults.overallScore)/10 (\(globalResults.scoreInterpretation))")
        if !lowConfidenceROIs.isEmpty {
            print("   ⚠️ Low confidence ROIs (excluded from global): \(lowConfidenceROIs.map { $0.displayName }.joined(separator: ", "))")
        }
        return finalMetrics
    }

    // MARK: - ROI Metrics Computation

    private func computeROI3DMetrics(_ sample: ROITextureSample, rawSample: ROITextureSample?, confidence: ROIConfidence?) async -> ROI3DMetrics {
        // Compute roughness proxy
        let roughness = roughnessAnalyzer.computeRoughnessProxy(sample)

        // Compute pigmentation index
        let pigmentation = pigmentationAnalyzer.computePigmentationIndex(sample)

        // Compute specular proxy (if raw frames available)
        let specular: Float? = if configuration.computeSpecular, let rawSample = rawSample {
            specularAnalyzer.computeSpecularProxy(rawSample)
        } else {
            nil
        }

        // Compute average luminance
        let luminance = computeAverageLuminance(sample.pixels)

        // Compute average CIELAB values
        let labMean = discolorationAnalyzer.computeLABMean(sample)

        // Compute scores
        let roughnessScore = scoring.mapRoughnessScore(roughness)
        let pigmentationScore = scoring.mapPigmentationScore(pigmentation)
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
        roiSamples: [Face3DROI: ROITextureSample]
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
        let globalDiscoloration = discolorationAnalyzer.computeDiscolorationIndex(roiLABMeans)

        // Compute scores
        let roughnessScore = scoring.mapRoughnessScore(globalRoughness)
        let pigmentationScore = scoring.mapPigmentationScore(globalPigmentation)
        let discolorationScore = scoring.mapDiscolorationScore(globalDiscoloration)
        let specularScore = globalSpecular.map { scoring.mapSpecularScore($0) }

        // Compute overall score
        let overallScore = scoring.computeOverallScore(
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
        // Convert Vector3 to SIMD3<Float>
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

