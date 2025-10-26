//
//  SessionResult.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import Foundation
import CoreData
import UIKit

// MARK: - Session Result Entity

@objc(SessionResult)
public class SessionResult: NSManagedObject {

    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var deviceModel: String

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
}

// MARK: - Convenience Init

extension SessionResult {

    convenience init(
        context: NSManagedObjectContext,
        scores: ScoreSummary,
        faceImage: CGImage,
        heatmaps: [HeatmapMetric: CGImage]?
    ) {
        self.init(context: context)

        self.id = UUID()
        self.date = Date()
        self.deviceModel = UIDevice.current.model

        // Average scores
        let avg = scores.averageScores
        self.blurQuality = avg.sharpnessScore
        self.textureAvg = avg.textureScore
        self.pigmentationAvg = avg.pigmentationScore
        self.moistureSpecular = avg.moistureScore
        self.moistureSmoothness = avg.moistureScore // Using same for now

        // Overall
        self.overallScore = scores.overallScore

        // Discoloration (invert for consistency - higher = better)
        self.discolorationIndex = 100.0 - (scores.roiMetrics.values.map { $0.pigmentationScore }.reduce(0, +) / Double(scores.roiMetrics.count))

        // ROI scores
        self.leftCheekScore = scores.roiScores[.leftCheek]?.compositeScore ?? 0
        self.rightCheekScore = scores.roiScores[.rightCheek]?.compositeScore ?? 0
        self.foreheadScore = scores.roiScores[.foreheadCenter]?.compositeScore ?? 0
        self.chinScore = scores.roiScores[.chinCenter]?.compositeScore ?? 0

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
}

// MARK: - Computed Properties

extension SessionResult {

    public var thumbnailImage: UIImage? {
        guard let data = thumbnail else { return nil }
        return UIImage(data: data)
    }

    public var grade: ScoreGrade {
        return ScoreGrade.from(score: overallScore)
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
