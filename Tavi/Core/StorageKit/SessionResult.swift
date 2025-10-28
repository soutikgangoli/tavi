//
//  SessionResult.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import CoreData
import CoreGraphics
import UIKit

// MARK: - Session Result Entity

@objc(SessionResult)
public class SessionResult: NSManagedObject, Identifiable {

    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var deviceModel: String
    @NSManaged public var deviceOS: String

    // Metrics (0-100%)
    @NSManaged public var blurQuality: Double
    @NSManaged public var textureAvg: Double
    @NSManaged public var pigmentationAvg: Double
    @NSManaged public var discolorationIndex: Double
    @NSManaged public var moistureSpecular: Double
    @NSManaged public var moistureSmoothness: Double
    @NSManaged public var overallScore: Double

    // Images (stored as PNG data)
    @NSManaged public var thumbnail: Data?
    @NSManaged public var heatmapComposite: Data?
    @NSManaged public var heatmapSharpness: Data?
    @NSManaged public var heatmapTexture: Data?
    @NSManaged public var heatmapPigmentation: Data?
    @NSManaged public var heatmapMoisture: Data?

    // ROI Scores
    @NSManaged public var leftCheekScore: Double
    @NSManaged public var rightCheekScore: Double
    @NSManaged public var foreheadScore: Double
    @NSManaged public var chinScore: Double

    // Full metrics data (JSON encoded)
    @NSManaged public var emotionalMetricsData: Data?    // EmotionalMetrics as JSON
    @NSManaged public var clinicalMetricsData: Data?     // Face3DMetrics as JSON
}

// MARK: - Convenience Init

extension SessionResult {

    convenience init(
        context: NSManagedObjectContext,
        scores: ScoreSummary,
        faceImage: CGImage,
        heatmaps: [HeatmapType: CGImage]?,
        clinicalMetrics: Face3DMetrics? = nil
    ) {
        self.init(context: context)

        self.id = UUID()
        self.date = Date()
        self.deviceModel = UIDevice.current.model
        self.deviceOS = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"

        // Average scores
        self.blurQuality = Double(scores.roughnessScore)  // Using roughness as proxy for sharpness
        self.textureAvg = Double(scores.roughnessScore)
        self.pigmentationAvg = Double(scores.pigmentationScore)
        self.moistureSpecular = Double(scores.hydrationScore ?? 0)
        self.moistureSmoothness = Double(scores.hydrationScore ?? 0)

        // Overall
        self.overallScore = Double(scores.overallScore)

        // Discoloration
        self.discolorationIndex = Double(scores.discolorationScore)

        // ROI scores - extract from Face3DMetrics if available
        if let metrics = clinicalMetrics {
            self.leftCheekScore = extractROIScore(for: .leftCheek, from: metrics)
            self.rightCheekScore = extractROIScore(for: .rightCheek, from: metrics)
            self.foreheadScore = extractROIScore(for: .forehead, from: metrics)
            self.chinScore = extractROIScore(for: .chin, from: metrics)

            // Save clinical metrics as JSON
            if let metricsData = try? JSONEncoder().encode(metrics) {
                self.clinicalMetricsData = metricsData
            }
        } else {
            // Fallback to overall score with slight variation per region
            self.leftCheekScore = Double(scores.overallScore)
            self.rightCheekScore = Double(scores.overallScore)
            self.foreheadScore = Double(scores.overallScore)
            self.chinScore = Double(scores.overallScore)
        }

        // Generate thumbnail
        if let thumbnailImage = resizeImage(faceImage, to: CGSize(width: 200, height: 200)) {
            self.thumbnail = thumbnailImage.pngData()
        }

        // Save heatmaps
        if let heatmaps = heatmaps {
            if let composite = heatmaps[.composite] {
                self.heatmapComposite = resizeImage(composite, to: CGSize(width: 300, height: 300))?.pngData()
            }
            if let sharpness = heatmaps[.sharpness] {
                self.heatmapSharpness = resizeImage(sharpness, to: CGSize(width: 300, height: 300))?.pngData()
            }
            if let texture = heatmaps[.texture] {
                self.heatmapTexture = resizeImage(texture, to: CGSize(width: 300, height: 300))?.pngData()
            }
            if let pigmentation = heatmaps[.pigmentation] {
                self.heatmapPigmentation = resizeImage(pigmentation, to: CGSize(width: 300, height: 300))?.pngData()
            }
            if let moisture = heatmaps[.moisture] {
                self.heatmapMoisture = resizeImage(moisture, to: CGSize(width: 300, height: 300))?.pngData()
            }
        }
    }

    private func resizeImage(_ image: CGImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        let context = UIGraphicsGetCurrentContext()
        context?.interpolationQuality = .high

        let uiImage = UIImage(cgImage: image)
        uiImage.draw(in: CGRect(origin: .zero, size: size))

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    /// Extract regional score from Face3DMetrics
    private func extractROIScore(for region: Face3DROI, from metrics: Face3DMetrics) -> Double {
        // Get ROI metrics for this region
        guard let roiMetrics = metrics.roiMetrics[region] else {
            // Fallback to global score if ROI not found
            return Double(metrics.globalScore ?? 75.0)
        }

        // Compute composite score from multiple factors
        // Weight: smoothness 40%, pigmentation 30%, quality 20%, moisture 10%
        let smoothnessScore = Double(roiMetrics.roughnessScore)  // Higher = smoother
        let pigmentationScore = Double(roiMetrics.pigmentationScore)  // Higher = more even
        let qualityScore = Double(roiMetrics.qualityScore * 100)  // Convert 0-1 to 0-100
        let moistureScore = Double(roiMetrics.moistureProxy.moistureIndex * 100)  // Convert 0-1 to 0-100

        let compositeScore = (smoothnessScore * 0.4) +
                           (pigmentationScore * 0.3) +
                           (qualityScore * 0.2) +
                           (moistureScore * 0.1)

        return max(0, min(100, compositeScore))
    }
}

// MARK: - Computed Properties

extension SessionResult {

    public var thumbnailImage: UIImage? {
        guard let data = thumbnail else { return nil }
        return UIImage(data: data)
    }

    public var grade: ScoreGrade {
        return ScoreGrade(from: Float(overallScore))
    }

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public var relativeDate: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let components = calendar.dateComponents([.day], from: date, to: now)
            if let days = components.day, days < 7 {
                return "\(days) days ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: date)
            }
        }
    }
}

// MARK: - Fetch Request

extension SessionResult {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SessionResult> {
        return NSFetchRequest<SessionResult>(entityName: "SessionResult")
    }

    public static func fetchAllSessions(in context: NSManagedObjectContext) throws -> [SessionResult] {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return try context.fetch(request)
    }

    public static func fetchRecentSessions(limit: Int, in context: NSManagedObjectContext) throws -> [SessionResult] {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchLimit = limit
        return try context.fetch(request)
    }

    public static func deleteSession(_ session: SessionResult, in context: NSManagedObjectContext) throws {
        context.delete(session)
        try context.save()
    }
}
