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
    @State private var clinicalMetrics: Face3DMetrics?
    @State private var isGeneratingPDF = false
    @State private var isPreparingShare = false
    @State private var errorState: ErrorState?

    init(session: SessionResult) {
        self.session = session
        // Decode clinical metrics for confidence scores with versioned loader
        if let data = session.clinicalMetricsData {
            let result = VersionedMetricsLoader.loadFace3DMetrics(from: data)
            if let metrics = result.metrics {
                _clinicalMetrics = State(initialValue: metrics)
                if case .migrated(_, let from, let to) = result {
                    AppLogger.ui.info("Migrated clinical metrics from v\(from.versionString) to v\(to.versionString)")
                }
            } else {
                AppLogger.ui.error("Failed to load clinical metrics in ResultsDetailView: \(result.userMessage)")
                CrashReporter.shared.logError(
                    NSError(domain: "ResultsDetailView", code: -1, userInfo: ["message": result.userMessage]),
                    context: ["operation": "versioned_load_clinical_results"]
                )
                _clinicalMetrics = State(initialValue: nil)
            }
        }
    }

    var body: some View {
        Group {
            if let error = errorState {
                errorView(error)
            } else {
                contentView
            }
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

    // MARK: - Content View

    private var contentView: some View {
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

                // Glow vs Radiance Breakdown (if available)
                if let metrics = clinicalMetrics, let glowAnalysis = metrics.glowAnalysis {
                    glowRadianceBreakdown(glowAnalysis)
                }

                // ROI Scores
                roiScoresSection

                // Actions
                actionsSection
            }
            .padding()
        }
    }

    // MARK: - Error View

    private func errorView(_ error: ErrorState) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Unable to Load Results")
                .font(.title2)
                .fontWeight(.semibold)

            Text(error.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                errorState = nil
            } label: {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top)
        }
        .padding()
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
                // Use enhanced cards with confidence if available
                if let metrics = clinicalMetrics {
                    ResultsMetricCardWithConfidence(
                        title: "Sharpness",
                        value: session.blurQuality,
                        confidence: Double(metrics.scanQuality?.textureClarity ?? 70),
                        icon: "camera.aperture"
                    )
                    ResultsMetricCardWithConfidence(
                        title: "Texture",
                        value: session.textureAvg,
                        confidence: Double(metrics.poreAnalysis?.confidence ?? 70),
                        icon: "square.grid.3x3"
                    )
                    ResultsMetricCardWithConfidence(
                        title: "Pigmentation",
                        value: session.pigmentationAvg,
                        confidence: Double(metrics.globalPigmentationScore > 0 ? 75 : 60),
                        icon: "paintpalette"
                    )
                    ResultsMetricCardWithConfidence(
                        title: "Discoloration",
                        value: session.discolorationIndex,
                        confidence: Double(metrics.globalDiscolorationScore > 0 ? 70 : 60),
                        icon: "circle.lefthalf.filled"
                    )

                    // Glow Score (Overall Health Index)
                    if let glowAnalysis = metrics.glowAnalysis {
                        ResultsMetricCardWithConfidence(
                            title: "Glow (Health)",
                            value: Double(glowAnalysis.glowScore),
                            confidence: Double(glowAnalysis.confidence),
                            icon: "sparkles"
                        )
                    }

                    // Radiance Score (Pure Luminosity)
                    if let glowAnalysis = metrics.glowAnalysis {
                        ResultsMetricCardWithConfidence(
                            title: "Radiance (Brightness)",
                            value: Double(glowAnalysis.radianceScore),
                            confidence: Double(glowAnalysis.confidence),
                            icon: "sun.max"
                        )
                    }

                    // Hydration with confidence (capped at 80% - indirect measurement)
                    ResultsMetricCardWithConfidence(
                        title: "Moisture",
                        value: session.moistureSpecular,
                        confidence: 65, // Moderate confidence (indirect measurement)
                        icon: "drop"
                    )

                    // Wrinkles (categorical)
                    if let wrinkleAnalysis = metrics.wrinkleAnalysis {
                        CategoricalMetricCard(
                            title: "Wrinkle Depth",
                            category: wrinkleAnalysis.wrinkleDepth.rawValue,
                            confidence: Double(wrinkleAnalysis.confidence),
                            icon: "waveform.path",
                            color: wrinkleColor(for: wrinkleAnalysis.wrinkleDepth)
                        )
                    }
                } else {
                    // Fallback to basic cards if no clinical metrics
                    ResultsMetricCard(title: "Sharpness", value: session.blurQuality, icon: "camera.aperture")
                    ResultsMetricCard(title: "Texture", value: session.textureAvg, icon: "square.grid.3x3")
                    ResultsMetricCard(title: "Pigmentation", value: session.pigmentationAvg, icon: "paintpalette")
                    ResultsMetricCard(title: "Discoloration", value: session.discolorationIndex, icon: "circle.lefthalf.filled")
                    ResultsMetricCard(title: "Moisture (S)", value: session.moistureSpecular, icon: "drop")
                    ResultsMetricCard(title: "Moisture (Sm)", value: session.moistureSmoothness, icon: "drop.fill")
                }
            }
        }
    }

    private func wrinkleColor(for depth: WrinkleDepth) -> Color {
        switch depth {
        case .fine: return .green
        case .moderate: return .orange
        case .deep: return .red
        }
    }

    // MARK: - Glow vs Radiance Breakdown

    private func glowRadianceBreakdown(_ analysis: GlowAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Glow vs Radiance Analysis")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Understanding the difference between your skin's overall health and pure luminosity.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Side-by-side comparison
            HStack(spacing: 16) {
                // Glow (Health Index)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.orange)
                        Text("Glow (Health)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text("\(Int(analysis.glowScore))/100")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)

                    Text("Overall health index")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Components:")
                            .font(.caption)
                            .fontWeight(.semibold)

                        HStack {
                            Text("Smoothness")
                                .font(.caption2)
                            Spacer()
                            Text("\(Int(analysis.smoothnessContribution))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Evenness")
                                .font(.caption2)
                            Spacer()
                            Text("\(Int(analysis.evennessContribution))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Discoloration")
                                .font(.caption2)
                            Spacer()
                            Text("\(Int(analysis.discolorationContribution))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Specular")
                                .font(.caption2)
                            Spacer()
                            Text("\(Int(analysis.specularContribution))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                )

                // Radiance (Luminosity)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sun.max")
                            .foregroundColor(.yellow)
                        Text("Radiance (Brightness)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text("\(Int(analysis.radianceScore))/100")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)

                    Text("Pure luminosity")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Components:")
                            .font(.caption)
                            .fontWeight(.semibold)

                        HStack {
                            Text("LAB L* Lightness")
                                .font(.caption2)
                            Spacer()
                            Text("\(Int(analysis.labLightness * 100))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Specular Highlights")
                                .font(.caption2)
                            Spacer()
                            Text("\(Int(analysis.specularHighlightRatio * 100))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Luminosity Index")
                                .font(.caption2)
                            Spacer()
                            Text("\(Int(analysis.luminosityIndex))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.1))
                )
            }

            // Explanation
            Text("💡 **Glow** measures overall skin health (texture + tone + shine), while **Radiance** measures how much light your skin reflects (physics-based brightness).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
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
            // Compare with latest button (if this isn't the latest scan)
            if !isLatestScan {
                NavigationLink {
                    if let latestSession = fetchLatestSession() {
                        Comparison3DView(
                            beforeSession: session,
                            afterSession: latestSession
                        )
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.headline)
                        Text("Compare with Latest Scan")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }

            PrimaryButton(title: isPreparingShare ? "Preparing..." : "Share Results") {
                shareResults()
            }
            .disabled(isPreparingShare)
            .overlay {
                if isPreparingShare {
                    ProgressView()
                        .tint(.white)
                }
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

    // Helper to check if this is the latest scan
    private var isLatestScan: Bool {
        let request = SessionResult.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)]
        request.fetchLimit = 1

        guard let latestSession = try? viewContext.fetch(request).first else {
            return false
        }

        return latestSession.id == session.id
    }

    // Helper to fetch the latest session
    private func fetchLatestSession() -> SessionResult? {
        let request = SessionResult.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)]
        request.fetchLimit = 1

        return try? viewContext.fetch(request).first
    }

    // MARK: - Actions

    private func shareResults() {
        Task {
            await performShare()
        }
    }

    private func performShare() async {
        // Set loading state
        await MainActor.run {
            isPreparingShare = true
        }

        // Generate share content
        var itemsToShare: [Any] = []

        // 1. Generate summary text with top 3 metrics
        let shareText = generateShareText()
        itemsToShare.append(shareText)

        // 2. Add PDF report if we have clinical metrics
        if let pdfData = await generatePDFReport() {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Tavi_Analysis_\(session.date.formatted(date: .abbreviated, time: .omitted)).pdf")
            try? pdfData.write(to: tempURL)
            itemsToShare.append(tempURL)
        }

        // 3. Add heatmap image if available
        if let heatmapImage = session.thumbnailImage {
            itemsToShare.append(heatmapImage)
        }

        // Present native iOS share sheet on main actor
        await MainActor.run {
            isPreparingShare = false
            let activityVC = UIActivityViewController(
                activityItems: itemsToShare,
                applicationActivities: nil
            )

            // For iPad support
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = rootVC.view
                    popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                rootVC.present(activityVC, animated: true)
            }
        }
    }

    private func generateShareText() -> String {
        // Get top 3 metrics
        let metrics: [(name: String, value: Double)] = [
            ("Overall Health", session.overallScore),
            ("Texture Quality", session.textureAvg),
            ("Pigmentation", session.pigmentationAvg),
            ("Moisture", session.moistureSpecular),
            ("Sharpness", session.blurQuality)
        ]

        let topMetrics = metrics.sorted { $0.value > $1.value }.prefix(3)

        var text = "📊 Tavi Skin Analysis Results\n"
        text += "Date: \(session.formattedDate)\n\n"
        text += "🏆 Overall Score: \(Int(session.overallScore))/100 (\(session.grade.rawValue))\n\n"
        text += "Top Metrics:\n"

        for (index, metric) in topMetrics.enumerated() {
            let emoji = ["🥇", "🥈", "🥉"][index]
            text += "\(emoji) \(metric.name): \(Int(metric.value))%\n"
        }

        text += "\n✨ Analyzed with Tavi - 3D Skin Analysis"

        return text
    }

    private func generatePDFReport() async -> Data? {
        // Set loading state
        await MainActor.run {
            isGeneratingPDF = true
        }

        defer {
            Task { @MainActor in
                isGeneratingPDF = false
            }
        }

        // Only generate PDF if we have clinical metrics
        guard let metricsData = session.clinicalMetricsData else {
            return nil
        }

        // Load metrics with versioned loader
        let result = VersionedMetricsLoader.loadFace3DMetrics(from: metricsData)
        guard let metrics = result.metrics else {
            AppLogger.ui.error("Failed to load clinical metrics for PDF generation: \(result.userMessage)")
            CrashReporter.shared.logError(
                NSError(domain: "ResultsDetailView", code: -1, userInfo: ["message": result.userMessage]),
                context: ["operation": "versioned_load_clinical_pdf"]
            )
            return nil
        }

        // Generate interpreted results for the report
        let interpretedResults = InterpretedResults.from(metrics: metrics)

        // Ensure we have scan quality data
        guard let scanQuality = metrics.scanQuality else {
            return nil
        }

        // Generate PDF report
        let generator = PDFReportGenerator()
        guard let pdfURL = await generator.generateReport(
            scan: metrics,
            interpretedResults: interpretedResults,
            scanQuality: scanQuality,
            userProfile: nil,  // Optional - could load from UserProfile
            recommendations: nil  // Optional - could generate from PersonalizedRecommendationEngine
        ) else {
            return nil
        }

        // Convert URL to Data
        return try? Data(contentsOf: pdfURL)
    }

    private func deleteSession() {
        viewContext.delete(session)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            handleError(error, context: "deleting session")
            // Still dismiss even on error - delete was queued
            dismiss()
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error, context: String) {
        AppLogger.ui.error("ResultsDetailView error (\(context)): \(error)")
        CrashReporter.shared.logError(error, context: ["view": "ResultsDetailView", "operation": context])
        errorState = ErrorState(
            message: "Unable to \(context). Please try again.",
            error: error
        )
    }

    private struct ErrorState {
        let message: String
        let error: Error
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

// MARK: - Enhanced Metric Card with Confidence

struct ResultsMetricCardWithConfidence: View {

    let title: String
    let value: Double
    let confidence: Double  // 0-100
    let icon: String
    let unit: String?  // Optional unit (%, categorical value, etc.)

    init(title: String, value: Double, confidence: Double, icon: String, unit: String? = "%") {
        self.title = title
        self.value = value
        self.confidence = confidence
        self.icon = icon
        self.unit = unit
    }

    var body: some View {
        CardView {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(scoreColor)

                    Spacer()

                    // Confidence badge
                    Text("\(Int(confidence))% confidence")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(confidenceColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(confidenceColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let unit = unit {
                    Text("\(Int(value))\(unit)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(displayValue)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(scoreColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Confidence bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(confidenceColor)
                            .frame(width: geometry.size.width * CGFloat(confidence / 100), height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(.vertical, 8)
        }
    }

    private var displayValue: String {
        // For categorical values (no unit)
        return "\(Int(value))"
    }

    private var scoreColor: Color {
        switch value {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    private var confidenceColor: Color {
        switch confidence {
        case 75...100: return .green
        case 50..<75: return .orange
        default: return .yellow
        }
    }
}

// MARK: - Categorical Metric Card (for wrinkles, etc.)

struct CategoricalMetricCard: View {

    let title: String
    let category: String  // e.g., "Fine Lines", "Moderate", "Deep"
    let confidence: Double  // 0-100
    let icon: String
    let color: Color

    var body: some View {
        CardView {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)

                    Spacer()

                    // Confidence badge
                    Text("\(Int(confidence))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(confidenceColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(confidenceColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(category)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Confidence bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(confidenceColor)
                            .frame(width: geometry.size.width * CGFloat(confidence / 100), height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(.vertical, 8)
        }
    }

    private var confidenceColor: Color {
        switch confidence {
        case 75...100: return .green
        case 50..<75: return .orange
        default: return .yellow
        }
    }
}

// MARK: - Heatmap Type Extension

// Note: HeatmapType is defined in AnalysisTypes.swift

extension HeatmapType {
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
