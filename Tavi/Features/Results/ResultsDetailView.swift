//
//  ResultsDetailView.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI
import CoreData

/// Detailed view of a single analysis session with all metrics and heatmaps
struct ResultsDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    let session: SessionResult

    @State private var selectedHeatmap: HeatmapType = .composite
    @State private var showingOriginal = false
    @State private var showingDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Face Image with Heatmap Toggle
                imageSection

                // Overall Score Card
                overallScoreCard

                // Metrics Grid
                metricsGrid

                // ROI Scores
                roiScoresSection

                // Actions
                actionsSection
            }
            .padding()
        }
        .navigationTitle("Analysis Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .alert("Delete Session", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSession()
            }
        } message: {
            Text("Are you sure you want to delete this analysis session?")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(session.relativeDate)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(session.formattedDate)
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(session.deviceModel)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Image Section

    private var imageSection: some View {
        CardView {
            VStack(spacing: 12) {
                // Heatmap Selector
                heatmapPicker

                // Image Display
                heatmapImageView
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Original/Heatmap Toggle
                Toggle("Show Original", isOn: $showingOriginal)
                    .toggleStyle(.switch)
            }
        }
    }

    private var heatmapPicker: some View {
        Picker("Heatmap Type", selection: $selectedHeatmap) {
            ForEach(HeatmapType.allCases, id: \.self) { type in
                Text(type.displayName).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var heatmapImageView: some View {
        if showingOriginal {
            if let thumbnail = session.thumbnailImage {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                placeholderImage
            }
        } else {
            if let heatmapImage = selectedHeatmap.image(from: session) {
                Image(uiImage: heatmapImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                placeholderImage
            }
        }
    }

    private var placeholderImage: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "face.smiling")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Overall Score Card

    private var overallScoreCard: some View {
        CardView {
            VStack(spacing: 12) {
                Text("Overall Skin Health")
                    .font(.headline)

                HStack(spacing: 16) {
                    // Circular Progress
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 12)

                        Circle()
                            .trim(from: 0, to: session.overallScore / 100)
                            .stroke(scoreColor(for: session.overallScore), lineWidth: 12)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 4) {
                            Text("\(Int(session.overallScore))")
                                .font(.system(size: 40, weight: .bold))

                            Text("/ 100")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 120, height: 120)

                    // Grade
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Grade")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(session.grade.rawValue)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(gradeColor(for: session.grade))

                        Text(session.grade.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        VStack(spacing: 12) {
            Text("Detailed Metrics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ResultsMetricCard(title: "Sharpness", value: session.blurQuality, icon: "camera.aperture")
                ResultsMetricCard(title: "Texture", value: session.textureAvg, icon: "square.grid.3x3")
                ResultsMetricCard(title: "Pigmentation", value: session.pigmentationAvg, icon: "paintpalette")
                ResultsMetricCard(title: "Discoloration", value: session.discolorationIndex, icon: "circle.lefthalf.filled")
                ResultsMetricCard(title: "Moisture (S)", value: session.moistureSpecular, icon: "drop")
                ResultsMetricCard(title: "Moisture (Sm)", value: session.moistureSmoothness, icon: "drop.fill")
            }
        }
    }

    // MARK: - ROI Scores

    private var roiScoresSection: some View {
        VStack(spacing: 12) {
            Text("Regional Scores")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ResultsMetricCard(title: "Left Cheek", value: session.leftCheekScore, icon: "face.smiling")
                ResultsMetricCard(title: "Right Cheek", value: session.rightCheekScore, icon: "face.smiling")
                ResultsMetricCard(title: "Forehead", value: session.foreheadScore, icon: "face.smiling")
                ResultsMetricCard(title: "Chin", value: session.chinScore, icon: "face.smiling")
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "Share Results") {
                shareResults()
            }

            Button {
                showingDeleteAlert = true
            } label: {
                Text("Delete Session")
                    .font(.headline)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
        }
    }

    // MARK: - Actions

    private func shareResults() {
        // TODO: Implement share functionality
        print("Share results for session: \(session.id)")
    }

    private func deleteSession() {
        viewContext.delete(session)
        try? viewContext.save()
        dismiss()
    }

    // MARK: - Helpers

    private func scoreColor(for score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    private func gradeColor(for grade: ScoreGrade) -> Color {
        switch grade {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor, .veryPoor: return .red
        }
    }
}

// MARK: - Metric Card

struct ResultsMetricCard: View {

    let title: String
    let value: Double
    let icon: String

    var body: some View {
        CardView {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(scoreColor)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(Int(value))%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor)
            }
            .padding(.vertical, 8)
        }
    }

    private var scoreColor: Color {
        switch value {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

// MARK: - Heatmap Type Enum

enum HeatmapType: CaseIterable {
    case composite
    case sharpness
    case texture
    case pigmentation
    case moisture

    var displayName: String {
        switch self {
        case .composite: return "Overall"
        case .sharpness: return "Sharpness"
        case .texture: return "Texture"
        case .pigmentation: return "Pigmentation"
        case .moisture: return "Moisture"
        }
    }

    func image(from session: SessionResult) -> UIImage? {
        switch self {
        case .composite:
            guard let data = session.heatmapComposite else { return nil }
            return UIImage(data: data)
        case .sharpness:
            guard let data = session.heatmapSharpness else { return nil }
            return UIImage(data: data)
        case .texture:
            guard let data = session.heatmapTexture else { return nil }
            return UIImage(data: data)
        case .pigmentation:
            guard let data = session.heatmapPigmentation else { return nil }
            return UIImage(data: data)
        case .moisture:
            guard let data = session.heatmapMoisture else { return nil }
            return UIImage(data: data)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        if let session = try? PersistenceController.preview.fetchRecentSessions(limit: 1).first {
            ResultsDetailView(session: session)
                .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
        }
    }
}
