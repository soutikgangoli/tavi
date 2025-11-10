//
//  SettingsView.swift
//  Tavi
//
//  Main settings screen
//  Created on 2025-10-30.
//

import SwiftUI

/// Main settings view
public struct SettingsView: View {
    @AppStorage("enableFaceMesh") private var enableFaceMesh: Bool = true
    @AppStorage("enableHighResCapture") private var enableHighResCapture: Bool = false
    @AppStorage("lightingStrictness") private var lightingStrictness: String = "Strict"
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback: Bool = true
    @AppStorage("debugModeEnabled") private var debugModeEnabled: Bool = false
    @AppStorage("skipOnboarding") private var skipOnboarding: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showDeleteConfirmation = false

    public var body: some View {
        NavigationStack {
            Form {
                // Scan Settings Section
                Section(header: Text("Scan Settings"),
                        footer: Text("High Quality Mode enables 4K texture (vs 2K) and 5 frames per pose (vs 3). Expected confidence: 90-92% (vs 83-85%). Uses 4x storage and takes longer to process.")) {
                    Toggle("Show 3D Face Mesh", isOn: $enableFaceMesh)
                        .accessibilityLabel("Show 3D face mesh during scan")
                        .accessibilityHint("Displays a 3D wireframe overlay of your face during scanning")
                        .accessibilityValue(enableFaceMesh ? "On" : "Off")
                        .onChange(of: enableFaceMesh) { newValue in
                            AnalyticsManager.shared.trackSettingChanged(
                                setting: "enable_face_mesh",
                                value: String(newValue),
                                previousValue: String(!newValue)
                            )
                        }

                    Toggle("High Quality Mode", isOn: $enableHighResCapture)
                        .accessibilityLabel("Enable high quality mode (4K texture + 5 frames)")
                        .accessibilityHint("Clinical-grade accuracy with 90-92% confidence. Uses 4x storage and slower processing.")
                        .accessibilityValue(enableHighResCapture ? "On" : "Off")
                        .onChange(of: enableHighResCapture) { newValue in
                            AnalyticsManager.shared.trackSettingChanged(
                                setting: "enable_high_res_capture",
                                value: String(newValue),
                                previousValue: String(!newValue)
                            )
                        }

                    Toggle("Haptic Feedback", isOn: $enableHapticFeedback)
                        .accessibilityLabel("Enable haptic feedback during scan")
                        .accessibilityHint("Provides vibration feedback during face scanning process")
                        .accessibilityValue(enableHapticFeedback ? "On" : "Off")
                        .onChange(of: enableHapticFeedback) { newValue in
                            AnalyticsManager.shared.trackSettingChanged(
                                setting: "enable_haptic_feedback",
                                value: String(newValue),
                                previousValue: String(!newValue)
                            )
                        }
                }

                // Lighting Strictness Section
                Section(header: Text("Lighting Validation"),
                        footer: Text(lightingStrictnessDescription)) {
                    Picker("Lighting Validation", selection: $lightingStrictness) {
                        Text("Strict").tag("Strict")
                        Text("Relaxed").tag("Relaxed")
                        Text("Off").tag("Off")
                    }
                    .accessibilityLabel("Lighting validation level")
                    .accessibilityHint("Controls how strictly the app validates lighting conditions before scanning")
                    .accessibilityValue(lightingStrictness)
                }

                // Advanced Settings Section
                Section("Advanced") {
                    NavigationLink {
                        CaptureSettingsView()
                    } label: {
                        Label("Capture Settings", systemImage: "camera.fill")
                    }
                    .accessibilityLabel("Capture Settings")
                    .accessibilityHint("Opens advanced camera and capture configuration options")

                    NavigationLink {
                        DeviceInfoView()
                    } label: {
                        Label("Device Information", systemImage: "info.circle.fill")
                    }
                    .accessibilityLabel("Device Information")
                    .accessibilityHint("Shows device capabilities and hardware specifications")
                }

                // Legal Section
                Section(header: Text("Legal"),
                        footer: Text("View our privacy policy, terms of service, and get support for the app.")) {
                    Button {
                        AnalyticsManager.shared.trackAction("tap", target: "privacy_policy_link")
                        if let url = URL(string: "https://tavi.app/privacy") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Label("Privacy Policy", systemImage: "hand.raised.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    .accessibilityLabel("Privacy Policy")
                    .accessibilityHint("Opens privacy policy in Safari showing how we handle your data")

                    Button {
                        AnalyticsManager.shared.trackAction("tap", target: "terms_of_service_link")
                        if let url = URL(string: "https://tavi.app/terms") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Label("Terms of Service", systemImage: "doc.text.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    .accessibilityLabel("Terms of Service")
                    .accessibilityHint("Opens terms of service in Safari with app usage agreement")

                    Button {
                        AnalyticsManager.shared.trackAction("tap", target: "support_link")
                        if let url = URL(string: "https://tavi.app/support") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Label("Support", systemImage: "questionmark.circle.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    .accessibilityLabel("Support")
                    .accessibilityHint("Opens support page in Safari for help and contact information")

                    Button {
                        AnalyticsManager.shared.trackAction("tap", target: "acknowledgments_link")
                        if let url = URL(string: "https://tavi.app/acknowledgments") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Label("Acknowledgments", systemImage: "heart.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    .accessibilityLabel("Acknowledgments")
                    .accessibilityHint("Opens acknowledgments page showing third-party libraries and credits")
                }

                // Onboarding Section
                Section(header: Text("Onboarding"),
                        footer: Text("Skip onboarding screen on app launch. You can reset onboarding to see it again.")) {
                    Toggle("Skip Onboarding", isOn: $skipOnboarding)
                        .accessibilityLabel("Skip onboarding screen on app launch")
                        .accessibilityHint("When enabled, the welcome tutorial will not be shown on app launch")
                        .accessibilityValue(skipOnboarding ? "On" : "Off")
                        .onChange(of: skipOnboarding) { newValue in
                            AnalyticsManager.shared.trackSettingChanged(
                                setting: "skip_onboarding",
                                value: String(newValue),
                                previousValue: String(!newValue)
                            )
                        }

                    Button("Reset Onboarding") {
                        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                        skipOnboarding = false
                        dismiss()
                    }
                    .foregroundColor(.orange)
                    .accessibilityLabel("Reset Onboarding")
                    .accessibilityHint("Clears onboarding completion status so the tutorial will show again on next launch")
                }

                // Developer Section
                Section(header: Text("Developer"),
                        footer: Text("Debug mode shows additional scan information. Verbose logging logs every 10 frames (vs 30) and may impact performance.")) {
                    Toggle("Debug Mode", isOn: $debugModeEnabled)
                        .accessibilityLabel("Enable debug mode for additional scan information")
                        .accessibilityHint("Shows technical details and validation information during scans")
                        .accessibilityValue(debugModeEnabled ? "On" : "Off")

                    if debugModeEnabled {
                        Toggle("Verbose Logging", isOn: Binding(
                            get: { DebugSettings.isVerboseLoggingEnabled },
                            set: { DebugSettings.setVerboseLogging($0) }
                        ))
                        .accessibilityLabel("Enable verbose logging")
                        .accessibilityHint("Logs every 10 frames instead of 30. May impact performance.")
                    }
                }

                // Data Management Section
                Section(header: Text("Data Management"),
                        footer: Text("Warning: Deleting all data will permanently remove all scan results, progress history, and app settings. This action cannot be undone.")) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash.fill")
                    }
                    .accessibilityLabel("Delete all data")
                    .accessibilityHint("Permanently deletes all scan results, progress history, and settings. Requires confirmation.")
                }

                // Notifications Section
                Section("Notifications") {
                    NavigationLink {
                        NotificationsSettingsView()
                    } label: {
                        Label("Notification Preferences", systemImage: "bell.fill")
                    }
                    .accessibilityLabel("Notification Preferences")
                    .accessibilityHint("Configure scan reminders and notification settings")
                }

                // Privacy Section
                Section("Privacy") {
                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        Label("Privacy & Data", systemImage: "lock.fill")
                    }
                    .accessibilityLabel("Privacy & Data")
                    .accessibilityHint("Manage your data and privacy settings")
                }

                // About Section
                Section("About") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About Tavi", systemImage: "info.circle.fill")
                    }
                    .accessibilityLabel("About Tavi")
                    .accessibilityHint("Learn more about the app, features, and support")

                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityLabel("Done")
                    .accessibilityHint("Closes settings and returns to previous screen")
                }
            }
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete all scan results, progress history, achievements, and app settings. This action cannot be undone.")
            }
        }
    }

    // MARK: - Data Deletion

    private func deleteAllData() {
        // Delete all Core Data entities
        deleteAllCoreDataEntities()

        // Clear all UserDefaults
        clearUserDefaults()

        // Track analytics (before clearing everything)
        AnalyticsManager.shared.trackAction("delete_all_data", target: "settings")

        // Provide haptic feedback
        HapticManager.shared.error()

        // Dismiss settings after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }

    private func deleteAllCoreDataEntities() {
        // Fetch and delete all SessionResult entities
        let fetchRequest = SessionResult.fetchRequest()

        do {
            let results = try viewContext.fetch(fetchRequest)
            for result in results {
                viewContext.delete(result)
            }

            // Save the context to persist deletions
            try viewContext.save()

            AppLogger.storage.info("✅ Successfully deleted \(results.count) SessionResult entities")
        } catch {
            AppLogger.storage.error("❌ Error deleting Core Data entities: \(error.localizedDescription)")
        }
    }

    private func clearUserDefaults() {
        // Get all keys
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()

        // Set defaults back to initial values
        UserDefaults.standard.set(true, forKey: "enableFaceMesh")
        UserDefaults.standard.set(false, forKey: "enableHighResCapture")
        UserDefaults.standard.set("Strict", forKey: "lightingStrictness")
        UserDefaults.standard.set(true, forKey: "enableHapticFeedback")
        UserDefaults.standard.set(false, forKey: "debugModeEnabled")
        UserDefaults.standard.set(false, forKey: "skipOnboarding")
        UserDefaults.standard.set(true, forKey: "useRealtimeProcessing")
        UserDefaults.standard.set(false, forKey: "enableSunDamageAnalysis")

        // Edge case detection defaults
        UserDefaults.standard.set(true, forKey: "detectGlasses")
        UserDefaults.standard.set(true, forKey: "detectHands")
        UserDefaults.standard.set(true, forKey: "detectHat")
        UserDefaults.standard.set(true, forKey: "detectMakeup")
        UserDefaults.standard.set(true, forKey: "detectHairCoverage")
        UserDefaults.standard.set(true, forKey: "detectSunburn")
        UserDefaults.standard.set(true, forKey: "detectEarrings")
        UserDefaults.standard.set(true, forKey: "detectFacialHair")

        AppLogger.storage.info("✅ Successfully cleared UserDefaults and reset to defaults")
    }

    private var lightingStrictnessDescription: String {
        switch lightingStrictness {
        case "Strict":
            return "Uses contrast and detail analysis (not absolute brightness) to work accurately across all skin tones from very light to very dark. Ensures optimal lighting quality by measuring texture clarity and shadow definition, which work equally well for melanin-rich and lighter skin."
        case "Relaxed":
            return "Relaxed validation allows scanning in less-than-ideal lighting conditions. Still uses contrast-based analysis for all skin tones, but with lower thresholds. May affect scan accuracy and consistency between sessions."
        case "Off":
            return "No lighting validation. Scans will proceed regardless of lighting conditions. Not recommended for accurate results as poor lighting affects texture detection and metric accuracy across all skin tones."
        default:
            return ""
        }
    }
}

#Preview {
    SettingsView()
}
