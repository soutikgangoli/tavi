//
//  Face3DResultsIntegration.swift
//  Tavi
//
//  Integration helper for Face3D results with existing results system
//  Created on 2025-10-27.
//

import Foundation
import SwiftUI
import CoreData

/// Integration point for Face3D results into existing ResultsHistoryView
public class Face3DResultsIntegration {

    // MARK: - Converting Face3DMetrics to SessionResult (CoreData)

    /// Save Face3DMetrics as a SessionResult in CoreData
    ///
    /// This allows Face3D results to appear in the existing ResultsHistoryView
    public static func saveToCoreData(
        metrics: Face3DMetrics,
        faceImage: UIImage,
        heatmaps: [OverlayType: UIImage],
        context: NSManagedObjectContext
    ) throws {
        let session = SessionResult(context: context)

        // Basic info
        session.id = UUID()
        session.timestamp = Date()
        session.deviceModel = UIDevice.current.model

        // Overall score (convert from 0-10 to 0-100)
        session.overallScore = Double(metrics.overallScore * 10)

        // Map 3D scores to 2D metrics (0-100 scale)
        session.textureAvg = Double(metrics.globalRoughnessScore * 10)
        session.pigmentationAvg = Double(metrics.globalPigmentationScore * 10)
        session.discolorationIndex = Double(metrics.globalDiscolorationScore * 10)

        // Moisture metrics (use specular if available)
        if let specularScore = metrics.globalSpecularScore {
            session.moistureSpecular = Double(specularScore * 10)
            session.moistureSmoothness = Double(specularScore * 10)
        } else {
            session.moistureSpecular = 50.0
            session.moistureSmoothness = 50.0
        }

        // Blur quality (use texture quality)
        session.blurQuality = metrics.isHighQuality ? 90.0 : 60.0

        // ROI scores (convert from 0-10 to 0-100)
        if let forehead = metrics.metrics(for: .forehead) {
            session.foreheadScore = Double(forehead.roughnessScore * 10)
        }
        if let leftCheek = metrics.metrics(for: .leftCheek) {
            session.leftCheekScore = Double(leftCheek.roughnessScore * 10)
        }
        if let rightCheek = metrics.metrics(for: .rightCheek) {
            session.rightCheekScore = Double(rightCheek.roughnessScore * 10)
        }
        if let chin = metrics.metrics(for: .chin) {
            session.chinScore = Double(chin.roughnessScore * 10)
        }

        // Images
        session.thumbnail = faceImage.jpegData(compressionQuality: 0.8)

        // Heatmaps
        if let composite = heatmaps[.roughness] {
            session.heatmapComposite = composite.pngData()
        }
        if let roughness = heatmaps[.roughness] {
            session.heatmapSharpness = roughness.pngData()
            session.heatmapTexture = roughness.pngData()
        }
        if let pigmentation = heatmaps[.pigmentation] {
            session.heatmapPigmentation = pigmentation.pngData()
        }
        if let specular = heatmaps[.specular] {
            session.heatmapMoisture = specular.pngData()
        }

        try context.save()
    }

    // MARK: - Navigation Helper

    /// Create SwiftUI view for Face3D results
    public static func createResultsView(
        metrics: Face3DMetrics,
        texturedMesh: TextureBakeResult?
    ) -> some View {
        return Face3DResultsView(metrics: metrics, texturedMesh: texturedMesh)
    }

    // MARK: - Export Helper

    /// Export Face3D metrics and summary as PDF report
    public static func exportAsPDF(
        metrics: Face3DMetrics,
        summary: Face3DSummary,
        previewImage: UIImage?
    ) -> Data? {
        // Create PDF renderer
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()

            // Title
            let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.label
            ]
            let titleText = "3D Face Scan Report"
            titleText.draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)

            // Date
            let bodyFont = UIFont.systemFont(ofSize: 12)
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.secondaryLabel
            ]
            let dateText = "Date: \(summary.date.formatted())"
            dateText.draw(at: CGPoint(x: 50, y: 90), withAttributes: bodyAttributes)

            // Preview image
            if let image = previewImage {
                let imageRect = CGRect(x: 50, y: 120, width: 200, height: 200)
                image.draw(in: imageRect)
            }

            // Overall score
            let scoreFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
            let scoreAttributes: [NSAttributedString.Key: Any] = [
                .font: scoreFont,
                .foregroundColor: UIColor.label
            ]
            let scoreText = "Overall Score: \(String(format: "%.1f", metrics.overallScore))/10 (\(metrics.scoreInterpretation))"
            scoreText.draw(at: CGPoint(x: 270, y: 150), withAttributes: scoreAttributes)

            // Global scores
            var yOffset: CGFloat = 200
            let sectionFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
            let sectionAttributes: [NSAttributedString.Key: Any] = [
                .font: sectionFont,
                .foregroundColor: UIColor.label
            ]

            "Global Metrics:".draw(at: CGPoint(x: 270, y: yOffset), withAttributes: sectionAttributes)
            yOffset += 25

            let detailFont = UIFont.systemFont(ofSize: 12)
            let detailAttributes: [NSAttributedString.Key: Any] = [
                .font: detailFont,
                .foregroundColor: UIColor.label
            ]

            "• Smoothness: \(String(format: "%.1f", metrics.globalRoughnessScore))/10".draw(
                at: CGPoint(x: 280, y: yOffset),
                withAttributes: detailAttributes
            )
            yOffset += 20

            "• Pigmentation: \(String(format: "%.1f", metrics.globalPigmentationScore))/10".draw(
                at: CGPoint(x: 280, y: yOffset),
                withAttributes: detailAttributes
            )
            yOffset += 20

            "• Discoloration: \(String(format: "%.1f", metrics.globalDiscolorationScore))/10".draw(
                at: CGPoint(x: 280, y: yOffset),
                withAttributes: detailAttributes
            )
            yOffset += 40

            // Regional scores
            "Regional Analysis:".draw(at: CGPoint(x: 50, y: yOffset), withAttributes: sectionAttributes)
            yOffset += 25

            for (roi, roiMetrics) in metrics.sortedROIMetrics {
                "\(roi.displayName):".draw(at: CGPoint(x: 60, y: yOffset), withAttributes: detailAttributes)
                yOffset += 18

                "  Smoothness: \(String(format: "%.1f", roiMetrics.roughnessScore))/10".draw(
                    at: CGPoint(x: 70, y: yOffset),
                    withAttributes: detailAttributes
                )
                yOffset += 15

                "  Pigmentation: \(String(format: "%.1f", roiMetrics.pigmentationScore))/10".draw(
                    at: CGPoint(x: 70, y: yOffset),
                    withAttributes: detailAttributes
                )
                yOffset += 15

                "  Confidence: \(roiMetrics.confidenceLevel)".draw(
                    at: CGPoint(x: 70, y: yOffset),
                    withAttributes: detailAttributes
                )
                yOffset += 25
            }

            // Technical details
            yOffset += 20
            "Technical Details:".draw(at: CGPoint(x: 50, y: yOffset), withAttributes: sectionAttributes)
            yOffset += 25

            "Vertices: \(metrics.vertexCount)".draw(at: CGPoint(x: 60, y: yOffset), withAttributes: detailAttributes)
            yOffset += 18

            "Triangles: \(metrics.triangleCount)".draw(at: CGPoint(x: 60, y: yOffset), withAttributes: detailAttributes)
            yOffset += 18

            "Texture: \(Int(metrics.textureResolution.width))x\(Int(metrics.textureResolution.height))".draw(
                at: CGPoint(x: 60, y: yOffset),
                withAttributes: detailAttributes
            )
            yOffset += 18

            "Processing Time: \(String(format: "%.2f", metrics.processingTime))s".draw(
                at: CGPoint(x: 60, y: yOffset),
                withAttributes: detailAttributes
            )
        }
    }
}

// MARK: - SwiftUI Preview Integration

extension Face3DResultsView {
    /// Create view wrapped in navigation for standalone presentation
    public static func standalone(metrics: Face3DMetrics, texturedMesh: TextureBakeResult?) -> some View {
        NavigationStack {
            Face3DResultsView(metrics: metrics, texturedMesh: texturedMesh)
        }
    }
}
