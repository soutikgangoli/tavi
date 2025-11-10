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
public class SessionResult: NSManagedObject {

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

    // Images (stored as JPEG data with 0.8 quality for efficient storage)
    @NSManaged public var thumbnail: Data?
    @NSManaged public var faceImage: Data?  // Full resolution face image (for comparisons and heatmap generation)
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

    /// Computed property to decode clinical metrics on-demand
    public var skinMetrics: Face3DMetrics? {
        guard let data = clinicalMetricsData else { return nil }
        let result = VersionedMetricsLoader.loadFace3DMetrics(from: data)
        return result.metrics
    }
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

            // Save clinical metrics as versioned JSON
            do {
                let versionedWrapper = try VersionedFace3DMetrics(metrics: metrics)
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                self.clinicalMetricsData = try encoder.encode(versionedWrapper)
                AppLogger.storage.info("💾 Saved clinical metrics in SessionResult with version \(MetricsVersion.current.versionString)")
            } catch {
                AppLogger.storage.error("Failed to encode clinical metrics in SessionResult: \(error)")
                CrashReporter.shared.logError(error, context: ["operation": "json_encode_clinical_session"])
            }
        } else {
            // Fallback to overall score with slight variation per region
            self.leftCheekScore = Double(scores.overallScore)
            self.rightCheekScore = Double(scores.overallScore)
            self.foreheadScore = Double(scores.overallScore)
            self.chinScore = Double(scores.overallScore)
        }

        // Generate thumbnail and save full face image asynchronously with JPEG compression
        Task {
            // Save full resolution face image (JPEG at 0.8 quality for heatmap generation)
            let uiFaceImage = UIImage(cgImage: faceImage)
            if let faceImageData = uiFaceImage.jpegData(compressionQuality: 0.8) {
                await MainActor.run {
                    self.faceImage = faceImageData
                }
            }

            // Generate thumbnail (JPEG at 0.8 quality - saves ~5x storage vs PNG)
            if let thumbnailImage = await resizeImage(faceImage, to: CGSize(width: 200, height: 200)) {
                await MainActor.run {
                    self.thumbnail = thumbnailImage.jpegData(compressionQuality: 0.8)
                }
            }

            // Save heatmaps (JPEG at 0.8 quality for efficient storage)
            if let heatmaps = heatmaps {
                if let composite = heatmaps[.composite],
                   let resized = await resizeImage(composite, to: CGSize(width: 300, height: 300)) {
                    await MainActor.run {
                        self.heatmapComposite = resized.jpegData(compressionQuality: 0.8)
                    }
                }
                if let sharpness = heatmaps[.sharpness],
                   let resized = await resizeImage(sharpness, to: CGSize(width: 300, height: 300)) {
                    await MainActor.run {
                        self.heatmapSharpness = resized.jpegData(compressionQuality: 0.8)
                    }
                }
                if let texture = heatmaps[.texture],
                   let resized = await resizeImage(texture, to: CGSize(width: 300, height: 300)) {
                    await MainActor.run {
                        self.heatmapTexture = resized.jpegData(compressionQuality: 0.8)
                    }
                }
                if let pigmentation = heatmaps[.pigmentation],
                   let resized = await resizeImage(pigmentation, to: CGSize(width: 300, height: 300)) {
                    await MainActor.run {
                        self.heatmapPigmentation = resized.jpegData(compressionQuality: 0.8)
                    }
                }
                if let moisture = heatmaps[.moisture],
                   let resized = await resizeImage(moisture, to: CGSize(width: 300, height: 300)) {
                    await MainActor.run {
                        self.heatmapMoisture = resized.jpegData(compressionQuality: 0.8)
                    }
                }
            }
        }
    }

    private func resizeImage(_ image: CGImage, to size: CGSize) async -> UIImage? {
        // Perform image resizing on background thread to avoid blocking main thread
        await Task.detached(priority: .utility) {
            UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
            defer { UIGraphicsEndImageContext() }

            let context = UIGraphicsGetCurrentContext()
            context?.interpolationQuality = .high

            let uiImage = UIImage(cgImage: image)
            uiImage.draw(in: CGRect(origin: .zero, size: size))

            return UIGraphicsGetImageFromCurrentImageContext()
        }.value
    }

    /// Extract regional score from Face3DMetrics
    private func extractROIScore(for region: Face3DROI, from metrics: Face3DMetrics) -> Double {
        // Get ROI metrics for this region
        guard let roiMetrics = metrics.roiMetrics[region] else {
            // Fallback to overall score if ROI not found
            return Double(metrics.overallScore)
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

// MARK: - Equality Comparison

extension SessionResult {
    public static func == (lhs: SessionResult, rhs: SessionResult) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Computed Properties

extension SessionResult {

    public var thumbnailImage: UIImage? {
        guard let data = thumbnail else { return nil }
        return UIImage(data: data)
    }

    public var faceUIImage: UIImage? {
        guard let data = faceImage else { return nil }
        return UIImage(data: data)
    }

    public var faceCGImage: CGImage? {
        faceUIImage?.cgImage
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

    /// Decode the full Face3DMetrics from stored JSON
    public var face3DMetrics: Face3DMetrics? {
        guard let data = clinicalMetricsData else {
            AppLogger.storage.debug("No clinicalMetricsData available for session \(id)")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let versionedWrapper = try decoder.decode(VersionedFace3DMetrics.self, from: data)
            let metrics = try versionedWrapper.decodeMetrics()
            AppLogger.storage.info("✅ Successfully decoded Face3DMetrics (version \(versionedWrapper.version.versionString))")
            return metrics
        } catch {
            AppLogger.storage.error("❌ Failed to decode Face3DMetrics: \(error)")
            CrashReporter.shared.logError(error, context: ["operation": "decode_face3d_metrics", "session_id": id.uuidString])
            return nil
        }
    }

    /// Decode EmotionalMetrics from stored JSON
    public var emotionalMetrics: EmotionalMetrics? {
        guard let data = emotionalMetricsData else {
            AppLogger.storage.debug("No emotionalMetricsData available for session \(id)")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let metrics = try decoder.decode(EmotionalMetrics.self, from: data)
            AppLogger.storage.info("✅ Successfully decoded EmotionalMetrics")
            return metrics
        } catch {
            AppLogger.storage.error("❌ Failed to decode EmotionalMetrics: \(error)")
            CrashReporter.shared.logError(error, context: ["operation": "decode_emotional_metrics", "session_id": id.uuidString])
            return nil
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

// MARK: - Identifiable Conformance

extension SessionResult: Identifiable {
    // NSManagedObject already has an objectID property
    // But for SwiftUI we use the UUID id property
    // The @NSManaged public var id: UUID already satisfies Identifiable
}
