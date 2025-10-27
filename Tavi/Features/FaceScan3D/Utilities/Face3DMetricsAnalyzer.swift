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

        // Step 5: Compute advanced metrics (elasticity, volume, regional, skin type)
        let elasticityAnalysis: ElasticityAnalysis? = if let historicalScans = configuration.historicalScans, !historicalScans.isEmpty {
            // Compute elasticity only if we have historical data
            let currentWrinkleDepth: Float = globalResults.roughness  // Use roughness as proxy for wrinkle depth
            skinElasticityAnalyzer.estimateElasticity(
                historicalScans: historicalScans,
                currentWrinkleDepth: currentWrinkleDepth
            )
        } else {
            nil
        }

        // Convert UnifiedMesh to FaceMeshGeometry for volume/regional analyzers
        let faceMeshGeometry = convertToFaceMeshGeometry(unifiedMesh: unifiedMesh)

        // Volume metrics
        let volumeAnalysis: VolumeAnalysis? = volumeMetricsAnalyzer.analyzeVolume(
            geometry: faceMeshGeometry,
            baseline: configuration.baselineMesh
        )

        // Convert CGImage to UIImage for regional and skin type analysis
        let textureImage = UIImage(cgImage: unifiedTexture)

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

        print("   Advanced metrics computed:")
        if let elasticity = elasticityAnalysis {
            print("   - Elasticity: \(elasticity.overallScore)/100 (\(elasticity.elasticityLevel))")
        }
        if let volume = volumeAnalysis {
            print("   - Volume: \(volume.overallScore)/100")
        }
        if let regional = regionalAnalysis {
            print("   - Regional: Under-eye \(regional.underEyeDarkness.score)/100, Jawline \(regional.jawlineDefinition.score)/100")
        }
        if let skinType = skinTypeAnalysis {
            print("   - Skin Type: \(skinType.skinType) (confidence: \(skinType.confidence))")
        }

        let metrics = Face3DMetrics(
            roiMetrics: roiMetrics,
            globalRoughnessProxy: globalResults.roughness,
            globalPigmentationIndex: globalResults.pigmentation,
            globalDiscolorationIndex: globalResults.discoloration,
            globalSpecularProxy: globalResults.specular,
            globalAverageLuminance: globalResults.luminance,
            globalRoughnessScore: globalResults.roughnessScore,
            globalPigmentationScore: globalResults.pigmentationScore,
            globalDiscolorationScore: globalResults.discolorationScore,
            globalSpecularScore: globalResults.specularScore,
            overallScore: globalResults.overallScore,
            scoreInterpretation: globalResults.scoreInterpretation,
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
            skinTypeAnalysis: skinTypeAnalysis
        )

        print("✅ Face3DMetricsAnalyzer: Complete in \(processingTime)s")
        print("   Overall Score: \(globalResults.overallScore)/10 (\(globalResults.scoreInterpretation))")
        if !lowConfidenceROIs.isEmpty {
            print("   ⚠️ Low confidence ROIs (excluded from global): \(lowConfidenceROIs.map { $0.displayName }.joined(separator: ", "))")
        }
        return metrics
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

        // Create FaceMeshGeometry manually
        // Note: Since FaceMeshGeometry's init requires ARFaceAnchor, we'll use the raw initializer if available
        // For now, create a simple struct with required data
        return FaceMeshGeometry(
            vertices: vertices,
            triangleIndices: unifiedMesh.triangleIndices,
            normals: normals,
            textureCoordinates: textureCoordinates,
            transform: transform,
            timestamp: Date().timeIntervalSince1970,
            originalVertexCount: unifiedMesh.vertexCount,
            wasExtended: false
        )
    }
}

// Extension to make FaceMeshGeometry initializable with raw data
extension FaceMeshGeometry {
    init(
        vertices: [SIMD3<Float>],
        triangleIndices: [Int32],
        normals: [SIMD3<Float>],
        textureCoordinates: [SIMD2<Float>],
        transform: simd_float4x4,
        timestamp: TimeInterval,
        originalVertexCount: Int,
        wasExtended: Bool
    ) {
        self.vertices = vertices
        self.triangleIndices = triangleIndices
        self.normals = normals
        self.textureCoordinates = textureCoordinates
        self.transform = transform
        self.timestamp = timestamp
        self.originalVertexCount = originalVertexCount
        self.wasExtended = wasExtended
    }
}
