//
//  QualityIndicators.swift
//  Tavi
//
//  Per-scan quality scoring and validation indicators
//  Helps users understand scan reliability
//

import SwiftUI

/// Scan quality assessment (UI-focused)
public struct UIScanQuality {
    public let overallScore: Float  // 0-100
    public let rating: QualityRating
    public let lightingQuality: Float
    public let trackingStability: Float
    public let faceCoverage: Float
    public let meshQuality: Float
    public let issues: [String]
    public let isReliable: Bool

    public init(overallScore: Float, rating: QualityRating, lightingQuality: Float, trackingStability: Float, faceCoverage: Float, meshQuality: Float, issues: [String], isReliable: Bool) {
        self.overallScore = overallScore
        self.rating = rating
        self.lightingQuality = lightingQuality
        self.trackingStability = trackingStability
        self.faceCoverage = faceCoverage
        self.meshQuality = meshQuality
        self.issues = issues
        self.isReliable = isReliable
    }
}

public enum QualityRating: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"

    public var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
}

/// Quality indicators view
struct QualityIndicatorsView: View {
    let quality: UIScanQuality

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Overall quality header
            HStack {
                Text("Scan Quality: \(quality.rating.rawValue)")
                    .font(.headline)
                    .foregroundColor(quality.rating.color)

                Spacer()

                Text("\(String(format: "%.0f", quality.overallScore))/100")
                    .font(.title2)
                    .bold()
                    .foregroundColor(quality.rating.color)
            }

            // Individual quality metrics
            VStack(spacing: 10) {
                QualityBar(label: "Lighting", score: quality.lightingQuality)
                QualityBar(label: "Tracking Stability", score: quality.trackingStability)
                QualityBar(label: "Face Coverage", score: quality.faceCoverage)
                QualityBar(label: "Mesh Quality", score: quality.meshQuality)
            }

            // Issues
            if !quality.issues.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Issues Detected:")
                        .font(.subheadline)
                        .bold()

                    ForEach(quality.issues, id: \.self) { issue in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(issue)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Reliability indicator
            HStack {
                Image(systemName: quality.isReliable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(quality.isReliable ? .green : .red)

                Text(quality.isReliable ? "Results are reliable" : "Consider rescanning for better accuracy")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(15)
    }
}

/// Quality bar component
struct QualityBar: View {
    let label: String
    let score: Float

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text("\(String(format: "%.0f", score))%")
                    .font(.caption)
                    .bold()
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)

                    // Progress
                    Rectangle()
                        .fill(barColor)
                        .frame(width: geometry.size.width * CGFloat(score / 100), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
    }

    private var barColor: Color {
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .blue
        } else if score >= 40 {
            return .orange
        } else {
            return .red
        }
    }
}

/// Quality calculator
class QualityCalculator {

    func calculateQuality(
        lightingQuality: ProcessingLightingQuality,
        validationResult: MeshValidationResult,
        frameCount: Int,
        coverage: Float
    ) -> UIScanQuality {

        let lightingScore = lightingQuality.overallScore * 100
        let trackingScore = Float(frameCount) / 15.0 * 100  // 15 frames target
        let meshScore = validationResult.qualityScore * 100
        let coverageScore = coverage * 100

        let overallScore = (lightingScore * 0.3 + trackingScore * 0.2 + meshScore * 0.3 + coverageScore * 0.2)

        let rating: QualityRating
        if overallScore >= 80 {
            rating = .excellent
        } else if overallScore >= 65 {
            rating = .good
        } else if overallScore >= 50 {
            rating = .fair
        } else {
            rating = .poor
        }

        var issues: [String] = []
        issues.append(contentsOf: lightingQuality.issues)
        issues.append(contentsOf: validationResult.issues)

        if frameCount < 10 {
            issues.append("Low frame count - may have increased noise")
        }
        if coverage < 0.9 {
            issues.append("Incomplete face coverage")
        }

        let isReliable = overallScore >= 60 && issues.count < 3

        return UIScanQuality(
            overallScore: overallScore,
            rating: rating,
            lightingQuality: lightingScore,
            trackingStability: trackingScore,
            faceCoverage: coverageScore,
            meshQuality: meshScore,
            issues: issues,
            isReliable: isReliable
        )
    }
}
