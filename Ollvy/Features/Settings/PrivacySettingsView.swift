//
//  PrivacySettingsView.swift
//  Ollvy
//
//  Privacy and data management settings
//  Created on 2025-01-10
//

import SwiftUI

public struct PrivacySettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)],
        animation: .default
    )
    private var sessions: FetchedResults<SessionResult>

    @State private var showingDeleteAlert = false
    @State private var showingExportSheet = false
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false
    @State private var showingTermsOfService = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Data storage info
                Section {
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .font(.app(size: 24))
                                .foregroundColor(.green)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Privacy First")
                                    .font(AppFont.subheadingPrimary)

                                Text("All your data stays on your device")
                                    .font(AppFont.footnote)
                                    .foregroundColor(Designs.Colors.textSecondary)
                            }
                        }

                        Text("Ollvy stores all scan data locally on your device. We never upload your face images or analysis results to any server.")
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, Designs.Spacing.sm)
                } header: {
                    Text("Your Data")
                }

                // Storage stats
                Section {
                    HStack {
                        Text("Total Scans")
                        Spacer()
                        Text("\(sessions.count)")
                            .foregroundColor(Designs.Colors.textSecondary)
                    }

                    HStack {
                        Text("Data Location")
                        Spacer()
                        Text("On Device")
                            .foregroundColor(Designs.Colors.textSecondary)
                    }
                } header: {
                    Text("Storage Information")
                }

                // Export data
                Section {
                    Button {
                        showingExportSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.app(size: 18))
                                .foregroundColor(Designs.Colors.primary)

                            Text("Export My Data")
                                .font(AppFont.bodyMedium)
                                .foregroundColor(Designs.Colors.textPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.app(size: 13, weight: .semibold))
                                .foregroundColor(Designs.Colors.textTertiary)
                        }
                    }
                } header: {
                    Text("Data Portability")
                } footer: {
                    Text("Export all your scan data and analysis results as a JSON file")
                }

                // Delete all data
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .font(.app(size: 18))

                            Text("Delete All Data")
                                .font(AppFont.bodyMedium)

                            Spacer()
                        }
                        .foregroundColor(.red)
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("This will permanently delete all your scans, analysis results, and settings. This action cannot be undone.")
                }

                // Legal links
                Section {
                    // TODO: Replace with your actual Notion/hosted Privacy Policy URL
                    Link(destination: URL(string: "https://ollvy.notion.site/Privacy-Policy")!) {
                        HStack {
                            Text("Privacy Policy")
                                .font(AppFont.bodyMedium)

                            Spacer()

                            Image(systemName: "arrow.up.forward")
                                .font(.app(size: 13))
                                .foregroundColor(Designs.Colors.textTertiary)
                        }
                    }

                    Button {
                        showingTermsOfService = true
                    } label: {
                        HStack {
                            Text("Terms of Service")
                                .font(AppFont.bodyMedium)
                                .foregroundColor(Designs.Colors.textPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.app(size: 13, weight: .semibold))
                                .foregroundColor(Designs.Colors.textTertiary)
                        }
                    }
                } header: {
                    Text("Legal")
                }
            }
            .navigationTitle("Privacy & Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete All Data?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete all \(sessions.count) scans and cannot be undone. Are you sure?")
            }
            .sheet(isPresented: $showingExportSheet) {
                exportDataSheet
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ActivityViewController(activityItems: [url])
                }
            }
            .sheet(isPresented: $showingTermsOfService) {
                TermsOfServiceView()
            }
        }
    }

    // MARK: - Export Sheet

    private var exportDataSheet: some View {
        NavigationStack {
            VStack(spacing: Designs.Spacing.xl) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.app(size: 64))
                    .foregroundColor(Designs.Colors.primary)

                VStack(spacing: Designs.Spacing.md) {
                    Text("Export Your Data")
                        .font(AppFont.title2)

                    Text("Your scan data will be exported as a JSON file that you can save or share.")
                        .font(AppFont.bodyPrimary)
                        .foregroundColor(Designs.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                    exportInfoRow(icon: "doc.text.fill", text: "\(sessions.count) scans")
                    exportInfoRow(icon: "chart.line.uptrend.xyaxis", text: "All metrics and analysis")
                    exportInfoRow(icon: "calendar", text: "Complete history")
                }
                .padding(Designs.Spacing.lg)
                .background(Designs.Colors.elevatedCard)
                .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))

                Button {
                    exportData()
                } label: {
                    Text("Export Data")
                        .font(AppFont.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Designs.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
                }

                Button {
                    showingExportSheet = false
                } label: {
                    Text("Cancel")
                        .font(AppFont.bodyMedium)
                        .foregroundColor(Designs.Colors.primary)
                }
            }
            .padding(Designs.Spacing.xl)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func exportInfoRow(icon: String, text: String) -> some View {
        HStack(spacing: Designs.Spacing.md) {
            Image(systemName: icon)
                .font(.app(size: 18))
                .foregroundColor(Designs.Colors.primary)
                .frame(width: 28)

            Text(text)
                .font(AppFont.bodySecondary)
                .foregroundColor(Designs.Colors.textPrimary)
        }
    }

    // MARK: - Actions

    private func deleteAllData() {
        withAnimation {
            for session in sessions {
                viewContext.delete(session)
            }

            do {
                try viewContext.save()
                AppLogger.ui.info("All scan data deleted successfully")
            } catch {
                AppLogger.ui.error("Failed to delete all data: \(error)")
                CrashReporter.shared.logError(error, context: ["operation": "deleteAllData"])
            }
        }
    }

    private func exportData() {
        Task {
            do {
                // Create export data structure
                var exportData: [[String: Any]] = []

                for session in sessions {
                    var sessionData: [String: Any] = [
                        "date": ISO8601DateFormatter().string(from: session.date),
                        "deviceModel": session.deviceModel,
                        "deviceOS": session.deviceOS,
                        "overallScore": session.overallScore,
                        "scores": [
                            "texture": session.textureAvg,
                            "pigmentation": session.pigmentationAvg,
                            "discoloration": session.discolorationIndex,
                            "moistureSpecular": session.moistureSpecular,
                            "moistureSmoothness": session.moistureSmoothness,
                            "blurQuality": session.blurQuality
                        ],
                        "regionalScores": [
                            "leftCheek": session.leftCheekScore,
                            "rightCheek": session.rightCheekScore,
                            "forehead": session.foreheadScore,
                            "chin": session.chinScore
                        ]
                    ]

                    // Add emotional metrics if available
                    if let emotionalData = session.emotionalMetricsData,
                       let emotionalJSON = try? JSONSerialization.jsonObject(with: emotionalData) {
                        sessionData["emotionalMetrics"] = emotionalJSON
                    }

                    // Add clinical metrics if available
                    if let clinicalData = session.clinicalMetricsData,
                       let clinicalJSON = try? JSONSerialization.jsonObject(with: clinicalData) {
                        sessionData["clinicalMetrics"] = clinicalJSON
                    }

                    exportData.append(sessionData)
                }

                // Convert to JSON
                let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])

                // Create temporary file
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let fileName = "Ollvy_Export_\(dateFormatter.string(from: Date())).json"

                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try jsonData.write(to: tempURL)

                // Store URL and show share sheet
                await MainActor.run {
                    exportedFileURL = tempURL
                    showingExportSheet = false
                    showingShareSheet = true
                    AppLogger.ui.info("Successfully exported \(sessions.count) scans to \(fileName)")
                }

            } catch {
                AppLogger.ui.error("Failed to export data: \(error)")
                CrashReporter.shared.logError(error, context: ["operation": "exportData"])
                await MainActor.run {
                    showingExportSheet = false
                }
            }
        }
    }
}

// MARK: - Activity View Controller

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    PrivacySettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
