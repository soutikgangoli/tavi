//
//  PDFReportGenerator.swift
//  Tavi
//
//  Professional PDF report generation with branding
//  Shareable with dermatologist or for personal records
//

import Foundation
import UIKit
import PDFKit
import os.log

/// PDF report generator
public class PDFReportGenerator {

    // MARK: - Public API

    /// Generate comprehensive PDF report (async to avoid blocking UI)
    public func generateReport(
        scan: Face3DMetrics,
        interpretedResults: InterpretedResults,
        scanQuality: ScanQuality,
        userProfile: UserProfile?,
        recommendations: PersonalizedRecommendations?
    ) async -> URL? {

        // Create PDF context
        let pdfMetaData = [
            kCGPDFContextCreator: "Ollvy - Advanced Skin Analysis",
            kCGPDFContextAuthor: "Ollvy App",
            kCGPDFContextTitle: "Skin Analysis Report - \(Date().formatted())"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageSize = CGSize(width: 612, height: 792)  // Letter size
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)

        let data = renderer.pdfData { context in
            // Page 1: Summary
            context.beginPage()
            drawPage1Summary(context: context, pageSize: pageSize, results: interpretedResults, quality: scanQuality)

            // Page 2: Detailed Metrics
            context.beginPage()
            drawPage2DetailedMetrics(context: context, pageSize: pageSize, results: interpretedResults)

            // Page 3: Recommendations
            if let recommendations = recommendations {
                context.beginPage()
                drawPage3Recommendations(context: context, pageSize: pageSize, recommendations: recommendations)
            }

            // Page 4: Technical Data
            context.beginPage()
            drawPage4TechnicalData(context: context, pageSize: pageSize, scan: scan, quality: scanQuality)
        }

        // Save to temporary file asynchronously to avoid blocking UI
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OllvyReport_\(Date().timeIntervalSince1970).pdf")

        return await Task.detached(priority: .userInitiated) {
            do {
                try data.write(to: tempURL, options: .atomic)
                AppLogger.export.info("✅ PDF report generated successfully: \(tempURL.lastPathComponent)")
                AppLogger.export.debug("PDF size: \(data.count) bytes, Path: \(tempURL.path)")
                return tempURL
            } catch let error as NSError {
                AppLogger.export.error("❌ Failed to save PDF report: \(error.localizedDescription)")
                AppLogger.export.error("Error domain: \(error.domain), code: \(error.code)")
                AppLogger.export.error("Attempted path: \(tempURL.path)")

                // Log additional details for debugging
                if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                    AppLogger.export.error("Underlying error: \(underlyingError.localizedDescription)")
                }

                // Check disk space
                if let resourceValues = try? FileManager.default.attributesOfFileSystem(forPath: tempURL.path),
                   let freeSpace = resourceValues[.systemFreeSize] as? Int64 {
                    AppLogger.export.error("Available disk space: \(freeSpace / 1024 / 1024) MB")
                }

                return nil
            }
        }.value
    }

    // MARK: - Page 1: Summary

    private func drawPage1Summary(
        context: UIGraphicsPDFRendererContext,
        pageSize: CGSize,
        results: InterpretedResults,
        quality: ScanQuality
    ) {
        let cgContext = context.cgContext

        // Header with branding
        drawHeader(context: cgContext, pageSize: pageSize, title: "Skin Analysis Report")

        var yPosition: CGFloat = 120

        // Overall score card
        yPosition = drawOverallScoreCard(
            context: cgContext,
            yPosition: yPosition,
            pageSize: pageSize,
            score: results.overallHealthScore,
            rating: results.overallRating
        )

        yPosition += 30

        // Summary text
        let summaryText = results.summary
        yPosition = drawText(
            context: cgContext,
            text: summaryText,
            yPosition: yPosition,
            pageSize: pageSize,
            fontSize: 14
        )

        yPosition += 30

        // Metrics overview (bar chart style)
        drawMetricsOverview(
            context: cgContext,
            yPosition: yPosition,
            pageSize: pageSize,
            metrics: results.detailedMetrics
        )

        // Footer
        drawFooter(context: cgContext, pageSize: pageSize, pageNumber: 1)
    }

    // MARK: - Page 2: Detailed Metrics

    private func drawPage2DetailedMetrics(
        context: UIGraphicsPDFRendererContext,
        pageSize: CGSize,
        results: InterpretedResults
    ) {
        let cgContext = context.cgContext

        drawHeader(context: cgContext, pageSize: pageSize, title: "Detailed Metrics")

        var yPosition: CGFloat = 120

        for metric in results.detailedMetrics {
            yPosition = drawMetricDetail(
                context: cgContext,
                yPosition: yPosition,
                pageSize: pageSize,
                metric: metric
            )

            yPosition += 20

            if yPosition > pageSize.height - 100 {
                break  // Page full
            }
        }

        drawFooter(context: cgContext, pageSize: pageSize, pageNumber: 2)
    }

    // MARK: - Page 3: Recommendations

    private func drawPage3Recommendations(
        context: UIGraphicsPDFRendererContext,
        pageSize: CGSize,
        recommendations: PersonalizedRecommendations
    ) {
        let cgContext = context.cgContext

        drawHeader(context: cgContext, pageSize: pageSize, title: "Personalized Recommendations")

        var yPosition: CGFloat = 120

        // High priority
        if !recommendations.highPriority.isEmpty {
            yPosition = drawRecommendationSection(
                context: cgContext,
                yPosition: yPosition,
                pageSize: pageSize,
                title: "High Priority",
                recommendations: recommendations.highPriority,
                color: UIColor.red
            )
        }

        // Medium priority
        if !recommendations.mediumPriority.isEmpty && yPosition < pageSize.height - 150 {
            yPosition = drawRecommendationSection(
                context: cgContext,
                yPosition: yPosition,
                pageSize: pageSize,
                title: "Medium Priority",
                recommendations: recommendations.mediumPriority,
                color: UIColor.orange
            )
        }

        drawFooter(context: cgContext, pageSize: pageSize, pageNumber: 3)
    }

    // MARK: - Page 4: Technical Data

    private func drawPage4TechnicalData(
        context: UIGraphicsPDFRendererContext,
        pageSize: CGSize,
        scan: Face3DMetrics,
        quality: ScanQuality
    ) {
        let cgContext = context.cgContext

        drawHeader(context: cgContext, pageSize: pageSize, title: "Technical Data")

        var yPosition: CGFloat = 120

        // Scan quality
        yPosition = drawSectionTitle(context: cgContext, title: "Scan Quality", yPosition: yPosition, pageSize: pageSize)
        yPosition += 10

        let qualityText = """
        Overall Quality: \(String(format: "%.0f", quality.overallQuality))/100
        Quality Level: \(quality.qualityLevel.rawValue)
        Lighting Quality: \(String(format: "%.0f", quality.lightingQuality))%
        Stability Score: \(String(format: "%.0f", quality.stabilityScore))%
        Coverage Quality: \(String(format: "%.0f", quality.coverageQuality))%
        Texture Clarity: \(String(format: "%.0f", quality.textureClarity))%
        Resolution Quality: \(String(format: "%.0f", quality.resolutionQuality))%
        """

        yPosition = drawText(context: cgContext, text: qualityText, yPosition: yPosition, pageSize: pageSize, fontSize: 12)

        yPosition += 30

        // Disclaimer
        yPosition = drawSectionTitle(context: cgContext, title: "Disclaimer", yPosition: yPosition, pageSize: pageSize)
        yPosition += 10

        let disclaimer = """
        This report is generated by Ollvy, a consumer skin analysis application. The metrics and recommendations are for informational purposes only and should not be considered medical advice. Please consult with a qualified dermatologist for medical concerns.

        Accuracy: ±1mm geometry, ±0.2mm wrinkle depth. Results may vary based on lighting conditions and scan quality.

        Generated: \(Date().formatted(date: .complete, time: .shortened))
        """

        _ = drawText(context: cgContext, text: disclaimer, yPosition: yPosition, pageSize: pageSize, fontSize: 10)

        drawFooter(context: cgContext, pageSize: pageSize, pageNumber: 4)
    }

    // MARK: - Drawing Helpers

    private func drawHeader(context: CGContext, pageSize: CGSize, title: String) {
        // Background bar
        context.setFillColor(UIColor.systemBlue.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: pageSize.width, height: 80))

        // App name
        let appName = "TAVI"
        let appNameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let appNameString = NSAttributedString(string: appName, attributes: appNameAttrs)
        appNameString.draw(at: CGPoint(x: 40, y: 20))

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        let titleString = NSAttributedString(string: title, attributes: titleAttrs)
        titleString.draw(at: CGPoint(x: 40, y: 50))
    }

    private func drawFooter(context: CGContext, pageSize: CGSize, pageNumber: Int) {
        let footerY = pageSize.height - 40

        // Line
        context.setStrokeColor(UIColor.gray.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: 40, y: footerY))
        context.addLine(to: CGPoint(x: pageSize.width - 40, y: footerY))
        context.strokePath()

        // Text
        let footerText = "Page \(pageNumber) • Generated by Ollvy • \(Date().formatted(date: .abbreviated, time: .omitted))"
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        let footerString = NSAttributedString(string: footerText, attributes: footerAttrs)
        footerString.draw(at: CGPoint(x: 40, y: footerY + 5))
    }

    private func drawOverallScoreCard(
        context: CGContext,
        yPosition: CGFloat,
        pageSize: CGSize,
        score: Float,
        rating: HealthRating
    ) -> CGFloat {

        let cardRect = CGRect(x: 40, y: yPosition, width: pageSize.width - 80, height: 100)

        // Background
        context.setFillColor(UIColor.systemGray6.cgColor)
        let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 10)
        context.addPath(path.cgPath)
        context.fillPath()

        // Score
        let scoreText = String(format: "%.0f", score)
        let scoreAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 48, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        let scoreString = NSAttributedString(string: scoreText, attributes: scoreAttrs)
        scoreString.draw(at: CGPoint(x: 60, y: yPosition + 25))

        // Rating
        let ratingText = rating.rawValue
        let ratingAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let ratingString = NSAttributedString(string: ratingText, attributes: ratingAttrs)
        ratingString.draw(at: CGPoint(x: 200, y: yPosition + 40))

        return yPosition + 110
    }

    private func drawMetricsOverview(
        context: CGContext,
        yPosition: CGFloat,
        pageSize: CGSize,
        metrics: [MetricInterpretation]
    ) {
        var currentY = yPosition

        for metric in metrics.prefix(5) {
            // Label
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.label
            ]
            let labelString = NSAttributedString(string: metric.name, attributes: labelAttrs)
            labelString.draw(at: CGPoint(x: 40, y: currentY))

            // Bar background
            let barRect = CGRect(x: 180, y: currentY, width: pageSize.width - 260, height: 20)
            context.setFillColor(UIColor.systemGray5.cgColor)
            let barPath = UIBezierPath(roundedRect: barRect, cornerRadius: 5)
            context.addPath(barPath.cgPath)
            context.fillPath()

            // Bar fill
            let fillWidth = barRect.width * CGFloat(metric.score / 100)
            let fillRect = CGRect(x: 180, y: currentY, width: fillWidth, height: 20)
            context.setFillColor(colorForScore(metric.score).cgColor)
            let fillPath = UIBezierPath(roundedRect: fillRect, cornerRadius: 5)
            context.addPath(fillPath.cgPath)
            context.fillPath()

            // Score text
            let scoreText = String(format: "%.0f", metric.score)
            let scoreAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let scoreString = NSAttributedString(string: scoreText, attributes: scoreAttrs)
            scoreString.draw(at: CGPoint(x: pageSize.width - 50, y: currentY + 3))

            currentY += 30
        }
    }

    private func drawMetricDetail(
        context: CGContext,
        yPosition: CGFloat,
        pageSize: CGSize,
        metric: MetricInterpretation
    ) -> CGFloat {

        var currentY = yPosition

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        let titleString = NSAttributedString(string: metric.name, attributes: titleAttrs)
        titleString.draw(at: CGPoint(x: 40, y: currentY))

        currentY += 25

        // Score and rating
        let scoreText = "\(String(format: "%.0f", metric.score))/100 - \(metric.rating.rawValue)"
        let scoreAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: colorForScore(metric.score)
        ]
        let scoreString = NSAttributedString(string: scoreText, attributes: scoreAttrs)
        scoreString.draw(at: CGPoint(x: 40, y: currentY))

        currentY += 25

        // Description
        currentY = drawText(
            context: context,
            text: metric.description,
            yPosition: currentY,
            pageSize: pageSize,
            fontSize: 12
        )

        return currentY
    }

    private func drawRecommendationSection(
        context: CGContext,
        yPosition: CGFloat,
        pageSize: CGSize,
        title: String,
        recommendations: [Recommendation],
        color: UIColor
    ) -> CGFloat {

        var currentY = yPosition

        currentY = drawSectionTitle(context: context, title: title, yPosition: currentY, pageSize: pageSize, color: color)
        currentY += 10

        for rec in recommendations.prefix(3) {
            let recText = "• \(rec.area): \(rec.suggestion)"
            currentY = drawText(context: context, text: recText, yPosition: currentY, pageSize: pageSize, fontSize: 11)
            currentY += 5
        }

        currentY += 20

        return currentY
    }

    private func drawSectionTitle(
        context: CGContext,
        title: String,
        yPosition: CGFloat,
        pageSize: CGSize,
        color: UIColor = .label
    ) -> CGFloat {

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: color
        ]
        let string = NSAttributedString(string: title, attributes: attrs)
        string.draw(at: CGPoint(x: 40, y: yPosition))

        return yPosition + 25
    }

    private func drawText(
        context: CGContext,
        text: String,
        yPosition: CGFloat,
        pageSize: CGSize,
        fontSize: CGFloat
    ) -> CGFloat {

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor.label
        ]

        let textRect = CGRect(x: 40, y: yPosition, width: pageSize.width - 80, height: 1000)
        let attributedString = NSAttributedString(string: text, attributes: attrs)

        let frameSetter = CTFramesetterCreateWithAttributedString(attributedString)
        let textPath = CGPath(rect: textRect, transform: nil)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: 0), textPath, nil)

        CTFrameDraw(frame, context)

        // Calculate height used - safely cast CTFrameGetLines result
        guard let lines = CTFrameGetLines(frame) as? [CTLine] else {
            AppLogger.export.warning("Failed to extract lines from CTFrame - using fallback calculation")
            // Fallback: estimate based on text length and font size
            let estimatedLines = (attributedString.length / 80) + 1 // ~80 chars per line
            return yPosition + CGFloat(estimatedLines) * (fontSize + 4)
        }

        let lineCount = lines.count
        return yPosition + CGFloat(lineCount) * (fontSize + 4)
    }

    private func colorForScore(_ score: Float) -> UIColor {
        if score >= 80 {
            return .systemGreen
        } else if score >= 60 {
            return .systemBlue
        } else if score >= 40 {
            return .systemOrange
        } else {
            return .systemRed
        }
    }
}
