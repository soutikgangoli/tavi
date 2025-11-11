//
//  PrivacySettingsView.swift
//  Tavi
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

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Data storage info
                Section {
                    VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 24))
                                .foregroundColor(.green)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Privacy First")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                                Text("All your data stays on your device")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                            }
                        }

                        Text("Tavi stores all scan data locally on your device. We never upload your face images or analysis results to any server.")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, HeadspaceDesign.Spacing.sm)
                } header: {
                    Text("Your Data")
                }

                // Storage stats
                Section {
                    HStack {
                        Text("Total Scans")
                        Spacer()
                        Text("\(sessions.count)")
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    }

                    HStack {
                        Text("Data Location")
                        Spacer()
                        Text("On Device")
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)
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
                                .font(.system(size: 18))
                                .foregroundColor(HeadspaceDesign.Colors.primary)

                            Text("Export My Data")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(HeadspaceDesign.Colors.textTertiary)
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
                                .font(.system(size: 18))

                            Text("Delete All Data")
                                .font(.system(size: 16, weight: .medium, design: .rounded))

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
                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                                .font(.system(size: 16, weight: .medium, design: .rounded))

                            Spacer()

                            Image(systemName: "arrow.up.forward")
                                .font(.system(size: 13))
                                .foregroundColor(HeadspaceDesign.Colors.textTertiary)
                        }
                    }

                    Link(destination: URL(string: "https://example.com/terms")!) {
                        HStack {
                            Text("Terms of Service")
                                .font(.system(size: 16, weight: .medium, design: .rounded))

                            Spacer()

                            Image(systemName: "arrow.up.forward")
                                .font(.system(size: 13))
                                .foregroundColor(HeadspaceDesign.Colors.textTertiary)
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
        }
    }

    // MARK: - Export Sheet

    private var exportDataSheet: some View {
        NavigationStack {
            VStack(spacing: HeadspaceDesign.Spacing.xl) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(HeadspaceDesign.Colors.primary)

                VStack(spacing: HeadspaceDesign.Spacing.md) {
                    Text("Export Your Data")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("Your scan data will be exported as a JSON file that you can save or share.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.sm) {
                    exportInfoRow(icon: "doc.text.fill", text: "\(sessions.count) scans")
                    exportInfoRow(icon: "chart.line.uptrend.xyaxis", text: "All metrics and analysis")
                    exportInfoRow(icon: "calendar", text: "Complete history")
                }
                .padding(HeadspaceDesign.Spacing.lg)
                .background(HeadspaceDesign.Colors.elevatedCard)
                .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))

                Button {
                    exportData()
                } label: {
                    Text("Export Data")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(HeadspaceDesign.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md))
                }

                Button {
                    showingExportSheet = false
                } label: {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(HeadspaceDesign.Colors.primary)
                }
            }
            .padding(HeadspaceDesign.Spacing.xl)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func exportInfoRow(icon: String, text: String) -> some View {
        HStack(spacing: HeadspaceDesign.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(HeadspaceDesign.Colors.primary)
                .frame(width: 28)

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(HeadspaceDesign.Colors.textPrimary)
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
                let fileName = "Tavi_Export_\(dateFormatter.string(from: Date())).json"

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
