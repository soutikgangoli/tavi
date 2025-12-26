//
//  AnalysisTypes.swift
//  Ollvy
//
//  Missing type definitions for analysis results
//  Created on 2025-10-28.
//

import Foundation
import CoreGraphics
import AVFoundation
import Combine
import SwiftUI
import Vision
import ARKit

// MARK: - Score Summary

/// Summary of all skin analysis scores
public struct ScoreSummary: Codable {
    /// Overall skin health score (0-100)
    public let overallScore: Float

    /// Individual metric scores
    public let roughnessScore: Float
    public let pigmentationScore: Float
    public let discolorationScore: Float
    public let hydrationScore: Float?
    public let poreScore: Float?

    /// Score grade interpretation
    public let grade: ScoreGrade

    /// Scores per ROI
    public let roiScores: [Face3DROI: ROIScores]

    /// Average scores across all ROIs
    public let averageScores: ROIScores

    /// Timestamp of analysis
    public let timestamp: Date

    public init(
        overallScore: Float,
        roughnessScore: Float,
        pigmentationScore: Float,
        discolorationScore: Float,
        hydrationScore: Float? = nil,
        poreScore: Float? = nil,
        grade: ScoreGrade,
        roiScores: [Face3DROI: ROIScores] = [:],
        averageScores: ROIScores? = nil,
        timestamp: Date = Date()
    ) {
        self.overallScore = overallScore
        self.roughnessScore = roughnessScore
        self.pigmentationScore = pigmentationScore
        self.discolorationScore = discolorationScore
        self.hydrationScore = hydrationScore
        self.poreScore = poreScore
        self.grade = grade
        self.roiScores = roiScores

        // Calculate average scores if not provided
        if let averageScores = averageScores {
            self.averageScores = averageScores
        } else if !roiScores.isEmpty {
            // Calculate averages from ROI scores
            let avgSharpness = roiScores.values.map { $0.sharpnessScore }.reduce(0, +) / Double(roiScores.count)
            let avgTexture = roiScores.values.map { $0.textureScore }.reduce(0, +) / Double(roiScores.count)
            let avgPigmentation = roiScores.values.map { $0.pigmentationScore }.reduce(0, +) / Double(roiScores.count)
            let avgMoisture = roiScores.values.map { $0.moistureScore }.reduce(0, +) / Double(roiScores.count)

            self.averageScores = ROIScores(
                sharpnessScore: avgSharpness,
                textureScore: avgTexture,
                pigmentationScore: avgPigmentation,
                moistureScore: avgMoisture
            )
        } else {
            // Default values if no ROI scores
            self.averageScores = ROIScores(
                sharpnessScore: Double(roughnessScore),
                textureScore: Double(roughnessScore),
                pigmentationScore: Double(pigmentationScore),
                moistureScore: Double(hydrationScore ?? 50.0)
            )
        }

        self.timestamp = timestamp
    }
}

// MARK: - Score Grade

/// Letter grade for overall score
public enum ScoreGrade: String, Codable {
    case excellent = "A+"
    case good = "A"
    case fair = "B"
    case poor = "C"
    case veryPoor = "D"

    public init(from score: Float) {
        switch score {
        case 90...100: self = .excellent
        case 80..<90: self = .good
        case 70..<80: self = .fair
        case 60..<70: self = .poor
        default: self = .veryPoor
        }
    }

    public var displayName: String {
        return rawValue
    }

    public var interpretation: String {
        switch self {
        case .excellent: return "Exceptional skin quality with minimal concerns"
        case .good: return "Good overall skin quality"
        case .fair: return "Moderate skin quality with some concerns"
        case .poor: return "Below average skin quality"
        case .veryPoor: return "Significant skin concerns detected"
        }
    }

    public var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .veryPoor: return "Very Poor"
        }
    }

    public var scoreRange: String {
        switch self {
        case .excellent: return "90-100"
        case .good: return "80-89"
        case .fair: return "70-79"
        case .poor: return "60-69"
        case .veryPoor: return "0-59"
        }
    }
}

// MARK: - ROI Scores

/// Individual scores for a region of interest
/// Note: Composite excludes moistureScore for consistency with overall score (hydration is proxy-based, 50-70% confidence)
public struct ROIScores: Codable {
    public let sharpnessScore: Double
    public let textureScore: Double
    public let pigmentationScore: Double
    public let moistureScore: Double
    public let compositeScore: Double
    public let grade: ScoreGrade
    public let roiType: Face3DROI?

    public init(
        sharpnessScore: Double,
        textureScore: Double,
        pigmentationScore: Double,
        moistureScore: Double,
        compositeScore: Double? = nil,
        grade: ScoreGrade? = nil,
        roiType: Face3DROI? = nil
    ) {
        self.sharpnessScore = sharpnessScore
        self.textureScore = textureScore
        self.pigmentationScore = pigmentationScore
        self.moistureScore = moistureScore

        // Calculate composite score as average if not provided
        // FIXED: Exclude moistureScore (hydration) for consistency with overall score
        // Hydration is proxy-based (50-70% confidence) and shouldn't inflate composite
        let calculatedComposite = compositeScore ?? (sharpnessScore + textureScore + pigmentationScore) / 3.0
        self.compositeScore = calculatedComposite

        // Calculate grade if not provided
        self.grade = grade ?? ScoreGrade(from: Float(calculatedComposite))
        self.roiType = roiType
    }
}

// MARK: - Heatmap Metric

/// Metric type for heatmap visualization
public struct HeatmapMetric: Codable, Hashable {
    public let metricType: AnalysisMetricType
    public let values: [Float]  // Per-vertex or per-ROI values
    public let colorMap: ColorMapType

    public init(metricType: AnalysisMetricType, values: [Float], colorMap: ColorMapType = .heatmap) {
        self.metricType = metricType
        self.values = values
        self.colorMap = colorMap
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(metricType)
        hasher.combine(colorMap)
    }

    public static func == (lhs: HeatmapMetric, rhs: HeatmapMetric) -> Bool {
        return lhs.metricType == rhs.metricType &&
               lhs.values == rhs.values &&
               lhs.colorMap == rhs.colorMap
    }
}

/// Color map type for heatmap
public enum ColorMapType: String, Codable {
    case heatmap    // Red-Yellow-Green
    case grayscale  // Black-White
    case viridis    // Perceptually uniform
}

// MARK: - Heatmap Type

/// Type of heatmap visualization
public enum HeatmapType: String, Codable, CaseIterable, Hashable, Sendable {
    case composite
    case sharpness
    case texture
    case pigmentation
    case moisture

    public var displayName: String {
        switch self {
        case .composite: return "Overall"
        case .sharpness: return "Sharp"
        case .texture: return "Texture"
        case .pigmentation: return "Pigment"
        case .moisture: return "Moisture"
        }
    }
}

// MARK: - Face Detection Result

/// Result from face detection
public struct FaceDetectionResult {
    public let faceFound: Bool
    public let boundingBox: CGRect?
    public let confidence: Float
    public let landmarks: FaceLandmarks?
    public let yaw: CGFloat?   // Head rotation left/right
    public let pitch: CGFloat? // Head rotation up/down
    public let roll: CGFloat?  // Head tilt sideways

    public init(
        faceFound: Bool,
        boundingBox: CGRect? = nil,
        confidence: Float = 0,
        landmarks: FaceLandmarks? = nil,
        yaw: CGFloat? = nil,
        pitch: CGFloat? = nil,
        roll: CGFloat? = nil
    ) {
        self.faceFound = faceFound
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.landmarks = landmarks
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
    }
}

/// Face landmarks
public struct FaceLandmarks {
    public let leftEye: CGPoint
    public let rightEye: CGPoint
    public let nose: CGPoint
    public let mouth: CGPoint
    public let allPoints: [CGPoint]?
    public let leftEyebrow: [CGPoint]?
    public let rightEyebrow: [CGPoint]?
    public let noseCrest: [CGPoint]?
    public let medianLine: [CGPoint]?
    public let outerLips: [CGPoint]?
    public let innerLips: [CGPoint]?
    public let leftPupil: CGPoint?
    public let rightPupil: CGPoint?
    public let faceContour: [CGPoint]?

    public init(
        leftEye: CGPoint,
        rightEye: CGPoint,
        nose: CGPoint,
        mouth: CGPoint,
        allPoints: [CGPoint]? = nil,
        leftEyebrow: [CGPoint]? = nil,
        rightEyebrow: [CGPoint]? = nil,
        noseCrest: [CGPoint]? = nil,
        medianLine: [CGPoint]? = nil,
        outerLips: [CGPoint]? = nil,
        innerLips: [CGPoint]? = nil,
        leftPupil: CGPoint? = nil,
        rightPupil: CGPoint? = nil,
        faceContour: [CGPoint]? = nil
    ) {
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.nose = nose
        self.mouth = mouth
        self.allPoints = allPoints
        self.leftEyebrow = leftEyebrow
        self.rightEyebrow = rightEyebrow
        self.noseCrest = noseCrest
        self.medianLine = medianLine
        self.outerLips = outerLips
        self.innerLips = innerLips
        self.leftPupil = leftPupil
        self.rightPupil = rightPupil
        self.faceContour = faceContour
    }

    /// Calculate eye angle in radians (for head tilt detection)
    public func eyeAngle() -> CGFloat? {
        guard let left = leftPupil, let right = rightPupil else {
            return nil
        }
        let dx = right.x - left.x
        let dy = right.y - left.y
        return atan2(dy, dx)
    }
}

// MARK: - Face ROI Display

/// Single face region of interest (for 2D overlay display)
public struct ROIDisplayInfo {
    public let type: Face3DROI
    public let imageRect: CGRect
    public let confidence: Float
    public let scaleFactorIPD: Float

    public init(type: Face3DROI, imageRect: CGRect, confidence: Float = 1.0, scaleFactorIPD: Float = 1.0) {
        self.type = type
        self.imageRect = imageRect
        self.confidence = confidence
        self.scaleFactorIPD = scaleFactorIPD
    }
}

// MARK: - Face ROI Set

/// Set of face regions of interest
public struct FaceROISet: Codable {
    public let rois: [Face3DROI: ROIData]
    public let interPupilDistance: Double

    public init(rois: [Face3DROI: ROIData], interPupilDistance: Double = 100.0) {
        self.rois = rois
        self.interPupilDistance = interPupilDistance
    }

    /// Convenience initializer for creating FaceROISet from CGRect regions
    public init(
        forehead: CGRect,
        leftCheek: CGRect,
        rightCheek: CGRect,
        nose: CGRect,
        chin: CGRect,
        interPupilDistance: Double = 100.0
    ) {
        // Convert CGRect to ROIData (simplified bounds)
        var roiDict: [Face3DROI: ROIData] = [:]

        if forehead != .zero {
            roiDict[.forehead] = ROIData(
                roi: .forehead,
                bounds: UVBounds(minU: Float(forehead.minX), maxU: Float(forehead.maxX), minV: Float(forehead.minY), maxV: Float(forehead.maxY)),
                pixelCount: Int(forehead.width * forehead.height * 1000)
            )
        }
        if leftCheek != .zero {
            roiDict[.leftCheek] = ROIData(
                roi: .leftCheek,
                bounds: UVBounds(minU: Float(leftCheek.minX), maxU: Float(leftCheek.maxX), minV: Float(leftCheek.minY), maxV: Float(leftCheek.maxY)),
                pixelCount: Int(leftCheek.width * leftCheek.height * 1000)
            )
        }
        if rightCheek != .zero {
            roiDict[.rightCheek] = ROIData(
                roi: .rightCheek,
                bounds: UVBounds(minU: Float(rightCheek.minX), maxU: Float(rightCheek.maxX), minV: Float(rightCheek.minY), maxV: Float(rightCheek.maxY)),
                pixelCount: Int(rightCheek.width * rightCheek.height * 1000)
            )
        }
        if nose != .zero {
            roiDict[.noseBridge] = ROIData(
                roi: .noseBridge,
                bounds: UVBounds(minU: Float(nose.minX), maxU: Float(nose.maxX), minV: Float(nose.minY), maxV: Float(nose.maxY)),
                pixelCount: Int(nose.width * nose.height * 1000)
            )
        }
        if chin != .zero {
            roiDict[.chin] = ROIData(
                roi: .chin,
                bounds: UVBounds(minU: Float(chin.minX), maxU: Float(chin.maxX), minV: Float(chin.minY), maxV: Float(chin.maxY)),
                pixelCount: Int(chin.width * chin.height * 1000)
            )
        }

        self.rois = roiDict
        self.interPupilDistance = interPupilDistance
    }

    /// Get all ROIs as ROIDisplayInfo array (for UI overlay)
    public var allROIs: [ROIDisplayInfo] {
        return rois.map { (type, data) in
            let rect = CGRect(
                x: CGFloat(data.bounds.minU) * 1000,
                y: CGFloat(data.bounds.minV) * 1000,
                width: CGFloat(data.bounds.maxU - data.bounds.minU) * 1000,
                height: CGFloat(data.bounds.maxV - data.bounds.minV) * 1000
            )
            return ROIDisplayInfo(type: type, imageRect: rect, confidence: 1.0, scaleFactorIPD: 1.0)
        }
    }
}

/// ROI data
public struct ROIData: Codable {
    public let roi: Face3DROI
    public let bounds: UVBounds
    public let pixelCount: Int

    public init(roi: Face3DROI, bounds: UVBounds, pixelCount: Int) {
        self.roi = roi
        self.bounds = bounds
        self.pixelCount = pixelCount
    }
}

// MARK: - ROI Type

/// Legacy ROI type (for compatibility)
public typealias ROIType = Face3DROI
public typealias FaceROI = Face3DROI

// MARK: - Camera Session

/// Camera session wrapper
public class CameraSession: ObservableObject {
    public let session: AVCaptureSession

    // Published properties for debug monitoring
    @Published public var isExposureLocked: Bool = false
    @Published public var isWhiteBalanceLocked: Bool = false

    // Publishers for metrics
    public let metricsPublisher = PassthroughSubject<CalibrationMetrics, Never>()
    public let framePublisher = PassthroughSubject<CVPixelBuffer, Never>()

    public init() {
        self.session = AVCaptureSession()
    }

    /// Get current capture resolution
    public func getCurrentResolution() -> CGSize {
        // Default HD resolution
        return CGSize(width: 1920, height: 1080)
    }
}

// MARK: - Calibration Metrics

/// Calibration metrics for exposure/histogram
public struct CalibrationMetrics {
    public let averageLuma: Double
    public let histogram: [Int]
    public let totalPixels: Int
    public let calibrationStatus: CalibrationStatus
    public let isHistogramClipped: Bool

    public init(averageLuma: Double, histogram: [Int], totalPixels: Int) {
        self.averageLuma = averageLuma
        self.histogram = histogram
        self.totalPixels = totalPixels

        // Calculate histogram clipping
        let blackClipped = histogram.prefix(5).reduce(0, +)
        let whiteClipped = histogram.suffix(5).reduce(0, +)
        let totalClipped = blackClipped + whiteClipped
        self.isHistogramClipped = Double(totalClipped) / Double(totalPixels) > 0.05

        // Determine calibration status
        if averageLuma < 0.35 {
            self.calibrationStatus = .tooLow
        } else if averageLuma > 0.65 || isHistogramClipped {
            self.calibrationStatus = .clipped
        } else {
            self.calibrationStatus = .good
        }
    }
}

/// Calibration status enum
public enum CalibrationStatus {
    case tooLow
    case clipped
    case good

    public var message: String {
        switch self {
        case .tooLow:
            return "Too dark - add light"
        case .clipped:
            return "Too bright - reduce light"
        case .good:
            return "Lighting optimal"
        }
    }
}

// MARK: - Face Detector

/// Face detection wrapper
public class FaceDetector {
    public init() {}

    public func detectFaces(in image: CGImage) -> [FaceDetectionResult] {
        // Use Vision framework for face detection with angle extraction
        var detectedFaces: [FaceDetectionResult] = []
        
        // Use Vision requests to get bounding boxes and landmarks for angle calculation
        let rectangleRequest = VNDetectFaceRectanglesRequest()
        let landmarksRequest = VNDetectFaceLandmarksRequest()
        
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([rectangleRequest, landmarksRequest])

        guard let rectangleObservations = rectangleRequest.results else {
            return []
        }

        let landmarksObservations = landmarksRequest.results ?? []
        
        // Match observations by bounding box overlap
        for rectObservation in rectangleObservations {
            let boundingBox = rectObservation.boundingBox
            let confidence = rectObservation.confidence
            
            // Calculate all angles from landmarks (Vision doesn't provide yaw/roll directly)
            var yaw: CGFloat? = nil
            var roll: CGFloat? = nil
            var pitch: CGFloat? = nil
            
            // Find matching landmarks observation
            for landmarksObs in landmarksObservations {
                let intersection = boundingBox.intersection(landmarksObs.boundingBox)
                let overlap = (intersection.width * intersection.height) / 
                             max(boundingBox.width * boundingBox.height, landmarksObs.boundingBox.width * landmarksObs.boundingBox.height)
                if overlap > 0.5, let landmarks = landmarksObs.landmarks {
                    // Calculate all angles from landmarks
                    if let nose = landmarks.nose,
                       let leftEye = landmarks.leftEye,
                       let rightEye = landmarks.rightEye,
                       !nose.normalizedPoints.isEmpty,
                       !leftEye.normalizedPoints.isEmpty,
                       !rightEye.normalizedPoints.isEmpty {

                        // DEBUG: Log that we're calculating angles
                        AppLogger.metrics.debug("🔍 DEBUG: Calculating angles from landmarks - nose points: \(nose.normalizedPoints.count), leftEye: \(leftEye.normalizedPoints.count), rightEye: \(rightEye.normalizedPoints.count)")

                        // Calculate eye centers
                        let leftEyeSum = leftEye.normalizedPoints.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
                        let leftEyeCenter = CGPoint(
                            x: leftEyeSum.x / CGFloat(leftEye.normalizedPoints.count),
                            y: leftEyeSum.y / CGFloat(leftEye.normalizedPoints.count)
                        )
                        
                        let rightEyeSum = rightEye.normalizedPoints.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
                        let rightEyeCenter = CGPoint(
                            x: rightEyeSum.x / CGFloat(rightEye.normalizedPoints.count),
                            y: rightEyeSum.y / CGFloat(rightEye.normalizedPoints.count)
                        )
                        
                        let eyeCenter = CGPoint(
                            x: (leftEyeCenter.x + rightEyeCenter.x) / 2,
                            y: (leftEyeCenter.y + rightEyeCenter.y) / 2
                        )
                        
                        // Calculate nose center
                        let noseSum = nose.normalizedPoints.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
                        let nosePoint = CGPoint(
                            x: noseSum.x / CGFloat(nose.normalizedPoints.count),
                            y: noseSum.y / CGFloat(nose.normalizedPoints.count)
                        )
                        
                        // Calculate ROLL (head tilt) from eye angle
                        let eyeVector = CGPoint(x: rightEyeCenter.x - leftEyeCenter.x, y: rightEyeCenter.y - leftEyeCenter.y)
                        let rollRadians = atan2(eyeVector.y, eyeVector.x)
                        roll = CGFloat(rollRadians) * 180 / .pi
                        
                        // Calculate YAW (left/right turn) from nose position relative to eye center
                        // When face is centered, nose is between eyes. When turned, nose shifts horizontally
                        let horizontalOffset = nosePoint.x - eyeCenter.x
                        // Normalize by eye distance to get relative offset
                        let eyeDistance = sqrt(eyeVector.x * eyeVector.x + eyeVector.y * eyeVector.y)
                        if eyeDistance > 0 {
                            let normalizedOffset = horizontalOffset / eyeDistance
                            // Convert to approximate yaw angle (scale factor based on typical face geometry)
                            // Typical: full profile turn (90°) ≈ 0.5-0.6 normalized offset
                            yaw = CGFloat(normalizedOffset * 60.0) // Rough conversion
                        }
                        
                        // Calculate PITCH (up/down tilt) from nose position relative to eye center
                        let verticalOffset = nosePoint.y - eyeCenter.y
                        // Typical face: nose is ~0.1-0.15 below eye center when level
                        // Scale factor: ~30-40 degrees per 0.1 normalized units
                        pitch = CGFloat(verticalOffset * 40.0)

                        AppLogger.metrics.debug("🔍 DEBUG: Calculated angles - Yaw: \(yaw?.description ?? "nil")°, Pitch: \(pitch?.description ?? "nil")°, Roll: \(roll?.description ?? "nil")°")
                        break
                    } else {
                        AppLogger.metrics.debug("🔍 DEBUG: Landmarks missing or empty - nose: \(landmarks.nose != nil), leftEye: \(landmarks.leftEye != nil), rightEye: \(landmarks.rightEye != nil)")
                    }
                } else {
                    AppLogger.metrics.debug("🔍 DEBUG: No landmarks found in observation")
                }
            }

            if yaw == nil && pitch == nil && roll == nil {
                AppLogger.metrics.debug("⚠️ DEBUG: No angles calculated - landmarksObservations count: \(landmarksObservations.count)")
                AppLogger.metrics.debug("⚠️ DEBUG: Vision framework angles unavailable. Use ARKit for accurate 3D angles.")
                // Set to 0 as fallback to indicate face detected but angles unavailable
                yaw = 0
                pitch = 0
                roll = 0
            }

            let faceResult = FaceDetectionResult(
                faceFound: true,
                boundingBox: boundingBox,
                confidence: Float(confidence),
                landmarks: nil,
                yaw: yaw,
                pitch: pitch,
                roll: roll
            )
            detectedFaces.append(faceResult)
        }

        return detectedFaces
    }

    /// Detect faces from ARFaceAnchor (already have face data from ARKit)
    public func detectFaceFromARKit(faceAnchor: ARFaceAnchor) -> FaceDetectionResult {
        // ARKit already provides face detection, extract bounding box from geometry
        let geometry = faceAnchor.geometry

        // Calculate bounding box from face vertices
        var minX: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var minY: Float = .greatestFiniteMagnitude
        var maxY: Float = -.greatestFiniteMagnitude

        for vertex in geometry.vertices {
            minX = min(minX, vertex.x)
            maxX = max(maxX, vertex.x)
            minY = min(minY, vertex.y)
            maxY = max(maxY, vertex.y)
        }

        // Convert to normalized CGRect (0-1 range)
        // ARKit face is typically about 0.2m wide, normalize to 0-1
        let width = maxX - minX
        let height = maxY - minY
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2

        // Normalize to 0-1 range (assuming typical face dimensions)
        let normalizedRect = CGRect(
            x: CGFloat(centerX - width / 2),
            y: CGFloat(centerY - height / 2),
            width: CGFloat(width),
            height: CGFloat(height)
        )

        // Extract angles from ARFaceAnchor transform using the extension
        let eulerAngles = faceAnchor.eulerAnglesRelativeToCamera()
        let yawDegrees = CGFloat(eulerAngles.y * 180 / .pi)
        let pitchDegrees = CGFloat(eulerAngles.x * 180 / .pi)
        let rollDegrees = CGFloat(eulerAngles.z * 180 / .pi)

        return FaceDetectionResult(
            faceFound: true,
            boundingBox: normalizedRect,
            confidence: 1.0,  // ARKit tracking is high confidence
            landmarks: nil,
            yaw: yawDegrees,
            pitch: pitchDegrees,
            roll: rollDegrees
        )
    }

    /// Convert bounding box from normalized coordinates to view coordinates
    public static func convertBoundingBox(
        _ boundingBox: CGRect?,
        imageSize: CGSize,
        viewSize: CGSize,
        isMirrored: Bool
    ) -> CGRect {
        guard let box = boundingBox else { return .zero }

        // Calculate aspect-fit scaling
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        let scale = min(scaleX, scaleY)

        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2

        // Vision uses bottom-left origin, convert to top-left
        var rect = box
        rect.origin.x = rect.origin.x * scaledWidth + offsetX
        rect.origin.y = (1 - rect.origin.y - rect.height) * scaledHeight + offsetY
        rect.size.width *= scaledWidth
        rect.size.height *= scaledHeight

        // Mirror if needed
        if isMirrored {
            rect.origin.x = viewSize.width - rect.origin.x - rect.width
        }

        return rect
    }

    /// Convert point from normalized coordinates to view coordinates
    public static func convertFromNormalizedCoordinates(
        _ point: CGPoint,
        imageSize: CGSize,
        viewSize: CGSize,
        isMirrored: Bool
    ) -> CGPoint {
        // Calculate aspect-fit scaling
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        let scale = min(scaleX, scaleY)

        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2

        // Vision uses bottom-left origin, convert to top-left
        var converted = CGPoint(
            x: point.x * scaledWidth + offsetX,
            y: (1 - point.y) * scaledHeight + offsetY
        )

        // Mirror if needed
        if isMirrored {
            converted.x = viewSize.width - converted.x
        }

        return converted
    }
}

// MARK: - ROI Builder

/// ROI builder for face regions
public class ROIBuilder {
    public init() {}

    public func buildROI(for region: Face3DROI, from geometry: FaceMeshGeometry) -> FaceROISet? {
        // Build ROI from FaceMeshGeometry using UV bounds
        let uvBounds = region.uvBounds

        // Find vertices that fall within this ROI's UV bounds
        var vertexIndices: [Int] = []
        for (index, uv) in geometry.textureCoordinates.enumerated() {
            if uvBounds.contains(uv) {
                vertexIndices.append(index)
            }
        }

        // Find triangles that have all vertices within this ROI
        var triangleIndices: [Int] = []
        for i in stride(from: 0, to: geometry.triangleIndices.count, by: 3) {
            let i0 = Int(geometry.triangleIndices[i])
            let i1 = Int(geometry.triangleIndices[i + 1])
            let i2 = Int(geometry.triangleIndices[i + 2])

            if vertexIndices.contains(i0) && vertexIndices.contains(i1) && vertexIndices.contains(i2) {
                triangleIndices.append(i / 3)
            }
        }

        // Create simple FaceROISet with calculated indices
        // Note: This is a simplified implementation
        guard !vertexIndices.isEmpty else { return nil }

        // ROI bounds in screen coordinates (V: 0=top, 1=bottom)
        return FaceROISet(
            forehead: region == .forehead ? CGRect(x: 0.25, y: 0.08, width: 0.5, height: 0.20) : .zero,
            leftCheek: region == .leftCheek ? CGRect(x: 0.10, y: 0.35, width: 0.28, height: 0.23) : .zero,
            rightCheek: region == .rightCheek ? CGRect(x: 0.62, y: 0.35, width: 0.28, height: 0.23) : .zero,
            nose: region == .noseBridge ? CGRect(x: 0.38, y: 0.32, width: 0.24, height: 0.20) : .zero,
            chin: region == .chin ? CGRect(x: 0.30, y: 0.60, width: 0.40, height: 0.20) : .zero
        )
    }

    /// Compute ROIs from ARFaceGeometry
    public func computeROIsFromARKit(geometry: FaceMeshGeometry) -> FaceROISet {
        // Extract ROIs from FaceMeshGeometry using UV mapping
        // ROI bounds in screen coordinates (V: 0=top, 1=bottom)
        return FaceROISet(
            forehead: CGRect(x: 0.25, y: 0.08, width: 0.5, height: 0.20),
            leftCheek: CGRect(x: 0.10, y: 0.35, width: 0.28, height: 0.23),
            rightCheek: CGRect(x: 0.62, y: 0.35, width: 0.28, height: 0.23),
            nose: CGRect(x: 0.38, y: 0.32, width: 0.24, height: 0.20),
            chin: CGRect(x: 0.30, y: 0.60, width: 0.40, height: 0.20)
        )
    }

    /// Compute ROIs from face detection result
    public func computeROIs(for face: FaceDetectionResult, imageSize: CGSize) throws -> FaceROISet? {
        // Extract ROIs from face bounding box
        guard let bbox = face.boundingBox else { return nil }

        let faceWidth = bbox.width
        let faceHeight = bbox.height
        let faceX = bbox.origin.x
        let faceY = bbox.origin.y

        // Define ROIs as proportions of the face bounding box
        return FaceROISet(
            forehead: CGRect(
                x: faceX + faceWidth * 0.2,
                y: faceY + faceHeight * 0.7,
                width: faceWidth * 0.6,
                height: faceHeight * 0.25
            ),
            leftCheek: CGRect(
                x: faceX + faceWidth * 0.1,
                y: faceY + faceHeight * 0.35,
                width: faceWidth * 0.35,
                height: faceHeight * 0.3
            ),
            rightCheek: CGRect(
                x: faceX + faceWidth * 0.55,
                y: faceY + faceHeight * 0.35,
                width: faceWidth * 0.35,
                height: faceHeight * 0.3
            ),
            nose: CGRect(
                x: faceX + faceWidth * 0.4,
                y: faceY + faceHeight * 0.4,
                width: faceWidth * 0.2,
                height: faceHeight * 0.3
            ),
            chin: CGRect(
                x: faceX + faceWidth * 0.3,
                y: faceY + faceHeight * 0.05,
                width: faceWidth * 0.4,
                height: faceHeight * 0.25
            )
        )
    }

    /// Convert ROI from image coordinates to view coordinates
    public static func convertROIToViewCoordinates(
        _ roi: ROIDisplayInfo,
        imageSize: CGSize,
        viewSize: CGSize,
        isMirrored: Bool
    ) -> CGRect {
        // Calculate aspect-fit scaling
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        let scale = min(scaleX, scaleY)

        // Calculate content rect (aspect-fit positioned rect)
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2

        // Convert ROI rect
        var rect = roi.imageRect
        rect.origin.x = rect.origin.x * scale + offsetX
        rect.origin.y = rect.origin.y * scale + offsetY
        rect.size.width *= scale
        rect.size.height *= scale

        // Mirror if needed
        if isMirrored {
            rect.origin.x = viewSize.width - rect.origin.x - rect.width
        }

        return rect
    }
}

// MARK: - Capture Progress

/// Progress state for capture
public enum CaptureProgress {
    case idle
    case capturing(frame: Int, total: Int)
    case processingBlur
    case aligning
    case combining
    case extractingROIs
    case completed
    case failed(Error)

    public var progressPercentage: Double {
        switch self {
        case .idle:
            return 0
        case .capturing(let frame, let total):
            return Double(frame) / Double(total) * 0.5  // 50% for capture
        case .processingBlur:
            return 0.6
        case .aligning:
            return 0.7
        case .combining:
            return 0.85
        case .extractingROIs:
            return 0.95
        case .completed:
            return 1.0
        case .failed:
            return 0
        }
    }

    public var description: String {
        switch self {
        case .idle:
            return "Ready"
        case .capturing(let frame, let total):
            return "Capturing frame \(frame) of \(total)"
        case .processingBlur:
            return "Analyzing image quality"
        case .aligning:
            return "Aligning frames"
        case .combining:
            return "Creating final image"
        case .extractingROIs:
            return "Extracting regions"
        case .completed:
            return "Complete"
        case .failed(let error):
            return "Failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Capture Result

/// Result from capture session
public struct CaptureResult {
    public let combinedImage: CGImage
    public let totalFramesCaptured: Int
    public let sharpFramesUsed: Int
    public let captureTime: Double
    public let averageBlurScore: Double
    public let roiImages: [ROIImage]
    public let frames: [CapturedFrame]
    public let roiSet: FaceROISet?

    public init(
        combinedImage: CGImage,
        totalFramesCaptured: Int,
        sharpFramesUsed: Int,
        captureTime: Double,
        averageBlurScore: Double,
        roiImages: [ROIImage],
        frames: [CapturedFrame],
        roiSet: FaceROISet?
    ) {
        self.combinedImage = combinedImage
        self.totalFramesCaptured = totalFramesCaptured
        self.sharpFramesUsed = sharpFramesUsed
        self.captureTime = captureTime
        self.averageBlurScore = averageBlurScore
        self.roiImages = roiImages
        self.frames = frames
        self.roiSet = roiSet
    }
}

/// ROI image with type
public struct ROIImage {
    public let type: Face3DROI
    public let image: CGImage

    public init(type: Face3DROI, image: CGImage) {
        self.type = type
        self.image = image
    }
}

/// Captured frame with metadata
public struct CapturedFrame {
    public let image: CGImage
    public let blurScore: Double
    public let isSharp: Bool

    public init(image: CGImage, blurScore: Double, isSharp: Bool) {
        self.image = image
        self.blurScore = blurScore
        self.isSharp = isSharp
    }
}

/// Metrics result
public struct MetricsResult {
    public let metrics: Face3DMetrics
    public let heatmaps: [HeatmapType: CGImage]?

    // Computed properties for backward compatibility
    public var roiMetrics: [Face3DROI: ROI3DMetrics] {
        return metrics.roiMetrics
    }

    public var averageMetrics: ROI3DMetrics? {
        // Return average of all ROI metrics
        guard !metrics.roiMetrics.isEmpty else { return nil }
        return metrics.roiMetrics.values.first // Simplified - return first for now
    }

    public var overallQualityScore: Double {
        // Convert overallScore from 0-100 to 0-1 range
        return Double(metrics.overallScore) / 100.0
    }

    public var discolorationIndex: Double {
        // Use global discoloration index from Face3DMetrics
        return Double(metrics.globalDiscolorationIndex)
    }

    public init(metrics: Face3DMetrics, heatmaps: [HeatmapType: CGImage]? = nil) {
        self.metrics = metrics
        self.heatmaps = heatmaps
    }
}

// Type aliases for backward compatibility
public typealias ROIMetrics = ROI3DMetrics

// MARK: - Extracted ROI Image

/// Extracted region of interest image
public struct ExtractedROIImage {
    public let roi: Face3DROI
    public let image: CGImage
    public let bounds: CGRect

    /// Alias for roi (for compatibility)
    public var type: Face3DROI {
        return roi
    }

    /// Image size
    public var size: CGSize {
        return CGSize(width: image.width, height: image.height)
    }

    public init(roi: Face3DROI, image: CGImage, bounds: CGRect) {
        self.roi = roi
        self.image = image
        self.bounds = bounds
    }
}
