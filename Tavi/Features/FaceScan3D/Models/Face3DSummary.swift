//
//  Face3DSummary.swift
//  Tavi
//
//  Compact summary of 3D face metrics for persistence
//  Created on 2025-10-27.
//

import Foundation
import UIKit

/// Compact summary of 3D face metrics for persistence and history
public struct Face3DSummary: Codable, Identifiable {
    public let id: UUID

    // Metadata
    public let date: Date
    public let userName: String?  // User's name from profile
    public let deviceModel: String
    public let deviceOS: String
    public let thresholdsVersion: String  // Track scoring configuration version

    // Global scores (0-100 percentage)
    public let overallScore: Float
    public let scoreInterpretation: String
    public let roughnessScore: Float
    public let pigmentationScore: Float
    public let discolorationScore: Float
    public let specularScore: Float?

    // Global raw metrics (0-1 range) - optional for detailed analysis
    public let globalRoughnessProxy: Float
    public let globalPigmentationIndex: Float
    public let globalDiscolorationIndex: Float
    public let globalSpecularProxy: Float?

    // Per-ROI compact data
    public let roiSummaries: [ROISummary]

    // Mesh statistics
    public let vertexCount: Int
    public let triangleCount: Int
    public let textureResolution: CGSize

    // Preview thumbnail (base64 encoded PNG)
    public let previewThumbBase64: String?

    // Processing metadata
    public let processingTime: TimeInterval

    public init(
        id: UUID = UUID(),
        date: Date,
        userName: String?,
        deviceModel: String,
        deviceOS: String,
        thresholdsVersion: String,
        overallScore: Float,
        scoreInterpretation: String,
        roughnessScore: Float,
        pigmentationScore: Float,
        discolorationScore: Float,
        specularScore: Float?,
        globalRoughnessProxy: Float,
        globalPigmentationIndex: Float,
        globalDiscolorationIndex: Float,
        globalSpecularProxy: Float?,
        roiSummaries: [ROISummary],
        vertexCount: Int,
        triangleCount: Int,
        textureResolution: CGSize,
        previewThumbBase64: String?,
        processingTime: TimeInterval
    ) {
        self.id = id
        self.date = date
        self.userName = userName
        self.deviceModel = deviceModel
        self.deviceOS = deviceOS
        self.thresholdsVersion = thresholdsVersion
        self.overallScore = overallScore
        self.scoreInterpretation = scoreInterpretation
        self.roughnessScore = roughnessScore
        self.pigmentationScore = pigmentationScore
        self.discolorationScore = discolorationScore
        self.specularScore = specularScore
        self.globalRoughnessProxy = globalRoughnessProxy
        self.globalPigmentationIndex = globalPigmentationIndex
        self.globalDiscolorationIndex = globalDiscolorationIndex
        self.globalSpecularProxy = globalSpecularProxy
        self.roiSummaries = roiSummaries
        self.vertexCount = vertexCount
        self.triangleCount = triangleCount
        self.textureResolution = textureResolution
        self.previewThumbBase64 = previewThumbBase64
        self.processingTime = processingTime
    }

    /// Create summary from Face3DMetrics
    public static func from(
        metrics: Face3DMetrics,
        previewImage: UIImage?,
        thresholdsVersion: String = "1.0"
    ) -> Face3DSummary {

        // Get user name from profile
        let userName = UserProfileManager.shared.loadProfile().name

        // Get device info
        let deviceModel = UIDevice.current.model
        let deviceOS = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"

        // Generate preview thumbnail
        let previewThumbBase64: String?
        if let previewImage = previewImage {
            let thumbnail = previewImage.resized(to: CGSize(width: 200, height: 200))
            previewThumbBase64 = thumbnail?.pngData()?.base64EncodedString()
        } else {
            previewThumbBase64 = nil
        }

        // Create ROI summaries
        let roiSummaries = metrics.sortedROI3DMetrics.map { (roi, roiMetrics) in
            ROISummary.from(roiMetrics: roiMetrics)
        }

        return Face3DSummary(
            date: Date(),
            userName: userName,
            deviceModel: deviceModel,
            deviceOS: deviceOS,
            thresholdsVersion: thresholdsVersion,
            overallScore: metrics.overallScore,
            scoreInterpretation: metrics.scoreInterpretation,
            roughnessScore: metrics.globalRoughnessScore,
            pigmentationScore: metrics.globalPigmentationScore,
            discolorationScore: metrics.globalDiscolorationScore,
            specularScore: metrics.globalSpecularScore,
            globalRoughnessProxy: metrics.globalRoughnessProxy,
            globalPigmentationIndex: metrics.globalPigmentationIndex,
            globalDiscolorationIndex: metrics.globalDiscolorationIndex,
            globalSpecularProxy: metrics.globalSpecularProxy,
            roiSummaries: roiSummaries,
            vertexCount: metrics.vertexCount,
            triangleCount: metrics.triangleCount,
            textureResolution: metrics.textureResolution,
            previewThumbBase64: previewThumbBase64,
            processingTime: metrics.processingTime
        )
    }

    /// Get preview thumbnail image
    public func getPreviewThumbnail() -> UIImage? {
        guard let base64 = previewThumbBase64,
              let data = Data(base64Encoded: base64) else {
            return nil
        }
        return UIImage(data: data)
    }
}

// MARK: - ROI Summary

/// Compact summary of ROI metrics
public struct ROISummary: Codable, Identifiable {
    public var id: String { roi.rawValue }

    public let roi: Face3DROI

    // Scores (0-100 percentage)
    public let roughnessScore: Float
    public let pigmentationScore: Float
    public let specularScore: Float?

    // Raw metrics (optional, for detailed view)
    public let roughnessProxy: Float
    public let pigmentationIndex: Float
    public let specularProxy: Float?

    public let pixelCount: Int

    public init(
        roi: Face3DROI,
        roughnessScore: Float,
        pigmentationScore: Float,
        specularScore: Float?,
        roughnessProxy: Float,
        pigmentationIndex: Float,
        specularProxy: Float?,
        pixelCount: Int
    ) {
        self.roi = roi
        self.roughnessScore = roughnessScore
        self.pigmentationScore = pigmentationScore
        self.specularScore = specularScore
        self.roughnessProxy = roughnessProxy
        self.pigmentationIndex = pigmentationIndex
        self.specularProxy = specularProxy
        self.pixelCount = pixelCount
    }

    public static func from(roiMetrics: ROI3DMetrics) -> ROISummary {
        return ROISummary(
            roi: roiMetrics.roi,
            roughnessScore: roiMetrics.roughnessScore,
            pigmentationScore: roiMetrics.pigmentationScore,
            specularScore: roiMetrics.specularScore,
            roughnessProxy: roiMetrics.roughnessProxy,
            pigmentationIndex: roiMetrics.pigmentationIndex,
            specularProxy: roiMetrics.specularProxy,
            pixelCount: roiMetrics.pixelCount
        )
    }
}

// MARK: - Persistence Manager

/// Manages persistence of Face3DSummary records
public class Face3DSummaryManager {

    private static let storageKey = "Face3DSummaries"

    /// Save a summary
    public static func save(_ summary: Face3DSummary) {
        var summaries = loadAll()
        summaries.append(summary)

        // Keep only last 50 summaries
        if summaries.count > 50 {
            summaries = Array(summaries.suffix(50))
        }

        if let encoded = try? JSONEncoder().encode(summaries) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    /// Load all summaries
    public static func loadAll() -> [Face3DSummary] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let summaries = try? JSONDecoder().decode([Face3DSummary].self, from: data) else {
            return []
        }
        return summaries.sorted { $0.date > $1.date }
    }

    /// Load summary by ID
    public static func load(id: UUID) -> Face3DSummary? {
        return loadAll().first { $0.id == id }
    }

    /// Delete summary
    public static func delete(id: UUID) {
        var summaries = loadAll()
        summaries.removeAll { $0.id == id }

        if let encoded = try? JSONEncoder().encode(summaries) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    /// Clear all summaries
    public static func deleteAll() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
