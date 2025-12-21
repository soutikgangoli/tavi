//
//  ScoreSummaryView.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

// MARK: - Score Summary View

public struct ScoreSummaryView: View {
    let scores: ScoreSummary
    let faceImage: CGImage?
    let roiSet: FaceROISet?
    @Binding var isPresented: Bool
    @State private var showingHeatmap = false

    public init(
        scores: ScoreSummary,
        faceImage: CGImage? = nil,
        roiSet: FaceROISet? = nil,
        isPresented: Binding<Bool>
    ) {
        self.scores = scores
        self.faceImage = faceImage
        self.roiSet = roiSet
        self._isPresented = isPresented
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Heatmap button (if image and ROI available)
                    if faceImage != nil && roiSet != nil {
                        Button {
                            showingHeatmap = true
                        } label: {
                            HStack {
                                Image(systemName: "map.fill")
                                    .font(.title3)
                                Text("View Heatmap Visualization")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .cornerRadius(Designs.Radius.medium)
                        }
                    }

                    // Overall Score Card
                    overallScoreCard

                    // Average Scores
                    averageScoresCard

                    // Individual ROI Scores
                    ForEach(Array(scores.roiScores.keys.sorted(by: { $0.displayName < $1.displayName })), id: \.self) { roiType in
                        if let roiScore = scores.roiScores[roiType] {
                            ROIScoreCard(roiType: roiType, scores: roiScore)
                        }
                    }

                    // Interpretation Guide
                    interpretationGuide
                }
                .padding()
            }
            .navigationTitle("Skin Analysis Scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showingHeatmap) {
                if let faceImage = faceImage, let roiSet = roiSet {
                    HeatmapView(
                        faceImage: faceImage,
                        scores: scores,
                        roiSet: roiSet,
                        isPresented: $showingHeatmap
                    )
                }
            }
        }
    }

    private var overallScoreCard: some View {
        VStack(spacing: 16) {
            Text("Overall Skin Quality")
                .font(.headline)

            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(Designs.Opacity.light), lineWidth: Designs.Border.widthThick * 12)
                    .frame(width: Designs.Sizes.displayLarge, height: Designs.Sizes.displayLarge)

                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(scores.overallScore) / 100.0)
                    .stroke(
                        gradeColor(scores.grade),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: Designs.Sizes.displayLarge, height: Designs.Sizes.displayLarge)
                    .rotationEffect(.degrees(-90))

                // Score text
                VStack(spacing: 8) {
                    Text("\(Int(scores.overallScore))")
                        .font(.scoreFont(size: 56))
                        .foregroundStyle(gradeColor(scores.grade))

                    Text("out of 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(scores.grade.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(gradeColor(scores.grade))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .background(gradeColor(scores.grade).opacity(Designs.Opacity.veryLight))
                        .cornerRadius(Designs.Radius.small)
                }
            }

            Text(scores.grade.interpretation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(Designs.Radius.large)
    }

    private var averageScoresCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Average Scores Across Face")
                .font(.headline)

            ScoreBar(
                label: "Sharpness",
                score: scores.averageScores.sharpnessScore,
                icon: "camera.aperture",
                color: .blue
            )

            ScoreBar(
                label: "Texture Quality",
                score: scores.averageScores.textureScore,
                icon: "waveform",
                color: .green
            )

            ScoreBar(
                label: "Pigmentation Evenness",
                score: scores.averageScores.pigmentationScore,
                icon: "paintpalette",
                color: .orange
            )

            ScoreBar(
                label: "Moisture Level",
                score: scores.averageScores.moistureScore,
                icon: "drop",
                color: .cyan
            )

            Divider()

            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .frame(width: Designs.Sizes.iconTiny)

                Text("Composite Score")
                    .font(.headline)

                Spacer()

                Text(String(format: "%.0f%%", scores.averageScores.compositeScore))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(scoreColor(scores.averageScores.compositeScore))
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(Designs.Radius.large)
    }

    private var interpretationGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Interpretation")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                GradeRow(grade: .excellent, color: gradeColor(.excellent))
                GradeRow(grade: .good, color: gradeColor(.good))
                GradeRow(grade: .fair, color: gradeColor(.fair))
                GradeRow(grade: .poor, color: gradeColor(.poor))
                GradeRow(grade: .veryPoor, color: gradeColor(.veryPoor))
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(Designs.Radius.large)
    }

    private func gradeColor(_ grade: ScoreGrade) -> Color {
        switch grade {
        case .excellent:
            return .green
        case .good:
            return Color(red: 0.5, green: 0.8, blue: 0.3)
        case .fair:
            return .orange
        case .poor:
            return Color(red: 1.0, green: 0.5, blue: 0.0)
        case .veryPoor:
            return .red
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        // - Below 30: Red (poor)
        // - 30-70: Yellow (fair)
        // - 70-89: Green (good)
        // - 90-100: Bright green (excellent)
        switch score {
        case 90...100:
            return Color(red: 0.18, green: 0.82, blue: 0.35)  // Bright green
        case 70..<90:
            return .green
        case 30..<70:
            return .yellow
        default:
            return .red
        }
    }
}

// MARK: - ROI Score Card

struct ROIScoreCard: View {
    let roiType: ROIType
    let scores: ROIScores

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(roiType.displayName)
                    .font(.headline)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f%%", scores.compositeScore))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(scoreColor(scores.compositeScore))

                    Text(scores.grade.rawValue)
                        .font(.caption)
                        .foregroundStyle(scoreColor(scores.compositeScore))
                }
            }

            Divider()

            VStack(spacing: 8) {
                ScoreRow(
                    label: "Sharpness",
                    score: scores.sharpnessScore,
                    icon: "camera.aperture",
                    color: .blue
                )

                ScoreRow(
                    label: "Texture",
                    score: scores.textureScore,
                    icon: "waveform",
                    color: .green
                )

                ScoreRow(
                    label: "Pigmentation",
                    score: scores.pigmentationScore,
                    icon: "paintpalette",
                    color: .orange
                )

                ScoreRow(
                    label: "Moisture",
                    score: scores.moistureScore,
                    icon: "drop",
                    color: .cyan
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(Designs.Radius.large)
    }

    private func scoreColor(_ score: Double) -> Color {
        // - Below 30: Red (poor)
        // - 30-70: Yellow (fair)
        // - 70-89: Green (good)
        // - 90-100: Bright green (excellent)
        switch score {
        case 90...100:
            return Color(red: 0.18, green: 0.82, blue: 0.35)  // Bright green
        case 70..<90:
            return .green
        case 30..<70:
            return .yellow
        default:
            return .red
        }
    }
}

// MARK: - Score Row

struct ScoreRow: View {
    let label: String
    let score: Double
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: Designs.Sizes.indicatorMedium)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(String(format: "%.0f%%", score))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(valueColor(score))
        }
    }

    private func valueColor(_ val: Double) -> Color {
        switch val {
        case 90...100:
            return .green
        case 70..<90:
            return Color(red: 0.5, green: 0.8, blue: 0.3)
        case 50..<70:
            return .orange
        case 30..<50:
            return Color(red: 1.0, green: 0.5, blue: 0.0)
        default:
            return .red
        }
    }
}

// MARK: - Score Bar

struct ScoreBar: View {
    let label: String
    let score: Double
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: Designs.Sizes.iconTiny)

                Text(label)
                    .font(.subheadline)

                Spacer()

                Text(String(format: "%.0f%%", score))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: Designs.Radius.xSmall)
                        .fill(Color.gray.opacity(Designs.Opacity.light))
                        .frame(height: Designs.Sizes.indicatorTiny)

                    // Progress
                    RoundedRectangle(cornerRadius: Designs.Radius.xSmall)
                        .fill(barColor(score))
                        .frame(width: geometry.size.width * (score / 100.0), height: 8)
                }
            }
            .frame(height: Designs.Sizes.indicatorTiny)
        }
    }

    private func barColor(_ val: Double) -> Color {
        switch val {
        case 90...100:
            return .green
        case 70..<90:
            return Color(red: 0.5, green: 0.8, blue: 0.3)
        case 50..<70:
            return .orange
        case 30..<50:
            return Color(red: 1.0, green: 0.5, blue: 0.0)
        default:
            return .red
        }
    }
}

// MARK: - Grade Row

struct GradeRow: View {
    let grade: ScoreGrade
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(grade.rawValue)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: Designs.Sizes.frameSmall, height: Designs.Sizes.frameSmall)
                .background(color)
                .cornerRadius(Designs.Radius.small)

            VStack(alignment: .leading, spacing: 2) {
                Text(grade.description)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(grade.scoreRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    ScoreSummaryView(
        scores: ScoreSummary(
            overallScore: 78.5,
            roughnessScore: 75.0,
            pigmentationScore: 72.0,
            discolorationScore: 70.0,
            hydrationScore: 68.0,
            poreScore: 65.0,
            grade: ScoreGrade.good,
            roiScores: [
                Face3DROI.leftCheek: ROIScores(
                    sharpnessScore: 85.0,
                    textureScore: 78.0,
                    pigmentationScore: 72.0,
                    moistureScore: 65.0,
                    roiType: Face3DROI.leftCheek
                ),
                Face3DROI.rightCheek: ROIScores(
                    sharpnessScore: 82.0,
                    textureScore: 75.0,
                    pigmentationScore: 70.0,
                    moistureScore: 68.0,
                    roiType: Face3DROI.rightCheek
                )
            ],
            averageScores: ROIScores(
                sharpnessScore: 83.5,
                textureScore: 76.5,
                pigmentationScore: 71.0,
                moistureScore: 66.5
            ),
            timestamp: Date()
        ),
        isPresented: .constant(true)
    )
}
