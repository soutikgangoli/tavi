//
//  SettingsView.swift
//  Ollvy
//
//  Main settings screen
//  Created on 2025-10-30.
//

import SwiftUI

/// Main settings view
public struct SettingsView: View {
    @AppStorage(AppDefaultsKey.enableFaceMesh) private var enableFaceMesh: Bool = true
    @AppStorage(AppDefaultsKey.enableHighResCapture) private var enableHighResCapture: Bool = false
    @AppStorage(AppDefaultsKey.lightingStrictness) private var lightingStrictness: String = "Strict"
    @AppStorage(AppDefaultsKey.enableHapticFeedback) private var enableHapticFeedback: Bool = true
    @AppStorage(AppDefaultsKey.debugModeEnabled) private var debugModeEnabled: Bool = false
    @AppStorage(AppDefaultsKey.skipOnboarding) private var skipOnboarding: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showDeleteConfirmation = false

    private var verboseLoggingBinding: Binding<Bool> {
        Binding(
            get: { DebugSettings.isVerboseLoggingEnabled },
            set: { DebugSettings.setVerboseLogging($0) }
        )
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Scan Settings Section
                Section(header: Text(AppStrings.Settings.scanSettings),
                        footer: Text("High Quality Mode enables 4K texture (vs 2K) and 5 frames per pose (vs 3). Expected confidence: 90-92% (vs 83-85%). Uses 4x storage and takes longer to process.")) {
                    Toggle(AppStrings.Settings.show3DFaceMesh, isOn: $enableFaceMesh)
                        .accessibilityLabel("Show 3D face mesh during scan")
                        .accessibilityHint("Displays a 3D wireframe overlay of your face during scanning")
                        .accessibilityValue(enableFaceMesh ? "On" : "Off")
                        .onChange(of: enableFaceMesh) { oldValue, newValue in
                            AnalyticsManager.shared.trackSettingChanged(
                                setting: "enable_face_mesh",
                                value: String(newValue),
                                previousValue: String(oldValue)
                            )
                        }

                    Toggle(AppStrings.Settings.highQualityMode, isOn: $enableHighResCapture)
                        .accessibilityLabel("Enable high quality mode (4K texture + 5 frames)")
                        .accessibilityHint("High accuracy with 90-92% confidence. Uses 4x storage and slower processing.")
                        .accessibilityValue(enableHighResCapture ? "On" : "Off")
                        .onChange(of: enableHighResCapture) { oldValue, newValue in
                            AnalyticsManager.shared.trackSettingChanged(
                                setting: "enable_high_res_capture",
                                value: String(newValue),
                                previousValue: String(oldValue)
                            )
                        }

                    Toggle(AppStrings.Settings.hapticFeedback, isOn: $enableHapticFeedback)
                        .accessibilityLabel("Enable haptic feedback during scan")
                        .accessibilityHint("Provides vibration feedback during face scanning process")
                        .accessibilityValue(enableHapticFeedback ? "On" : "Off")
                        .onChange(of: enableHapticFeedback) { oldValue, newValue in
                            AnalyticsManager.shared.trackSettingChanged(
                                setting: "enable_haptic_feedback",
                                value: String(newValue),
                                previousValue: String(oldValue)
                            )
                        }
                }

                // Lighting Strictness Section
                Section(header: Text(AppStrings.Settings.lightingValidation),
                        footer: Text(lightingStrictnessDescription)) {
                    Picker(AppStrings.Settings.lightingValidationToggle, selection: $lightingStrictness) {
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
                        Label("Capture Settings", systemImage: SFSymbol.cameraFill)
                    }
                    .accessibilityLabel("Capture Settings")
                    .accessibilityHint("Opens advanced camera and capture configuration options")

                    NavigationLink {
                        DeviceInfoView()
                    } label: {
                        Label("Device Information", systemImage: SFSymbol.infoCircleFill)
                    }
                    .accessibilityLabel("Device Information")
                    .accessibilityHint("Shows device capabilities and hardware specifications")
                }

                // Legal Section
                Section(header: Text(AppStrings.Settings.legal),
                        footer: Text("View our privacy policy, terms of service, and get support for the app.")) {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label(AppStrings.Settings.privacyPolicy, systemImage: "hand.raised.fill")
                    }
                    .accessibilityLabel("Privacy Policy")
                    .accessibilityHint("Opens privacy policy showing how we handle your data")

                    NavigationLink {
                        TermsOfServiceView()
                    } label: {
                        Label(AppStrings.Settings.termsOfService, systemImage: "doc.text.fill")
                    }
                    .accessibilityLabel("Terms of Service")
                    .accessibilityHint("Opens terms of service with app usage agreement")

                    NavigationLink {
                        SupportView()
                    } label: {
                        Label("Support", systemImage: "questionmark.circle.fill")
                    }
                    .accessibilityLabel("Support")
                    .accessibilityHint("Opens help center and contact information")

                    NavigationLink {
                        AcknowledgmentsView()
                    } label: {
                        Label("Acknowledgments", systemImage: "heart.fill")
                    }
                    .accessibilityLabel("Acknowledgments")
                    .accessibilityHint("Opens credits and acknowledgments")
                }

                // Onboarding Section
                Section(header: Text("Onboarding"),
                        footer: Text("Skip onboarding screen on app launch. You can reset onboarding to see it again.")) {
                    Toggle(AppStrings.Settings.skipOnboarding, isOn: $skipOnboarding)
                        .accessibilityLabel("Skip onboarding screen on app launch")
                        .accessibilityHint("When enabled, the welcome tutorial will not be shown on app launch")
                        .accessibilityValue(skipOnboarding ? "On" : "Off")
                        .onChange(of: skipOnboarding) { oldValue, newValue in
                            AnalyticsManager.shared.trackSettingChanged(
                                setting: "skip_onboarding",
                                value: String(newValue),
                                previousValue: String(oldValue)
                            )
                        }

                    Button(AppStrings.Settings.resetOnboarding) {
                        UserDefaults.standard.removeObject(forKey: AppDefaultsKey.hasCompletedOnboarding)
                        skipOnboarding = false
                        dismiss()
                    }
                    .foregroundColor(.orange)
                    .accessibilityLabel("Reset Onboarding")
                    .accessibilityHint("Clears onboarding completion status so the tutorial will show again on next launch")
                }

                // Developer Section
                Section(header: Text(AppStrings.Settings.developer),
                        footer: Text("Debug mode shows additional scan information. Verbose logging logs every 10 frames (vs 30) and may impact performance.")) {
                    Toggle(AppStrings.Settings.showDebugOverlay, isOn: $debugModeEnabled)
                        .accessibilityLabel("Enable debug mode for additional scan information")
                        .accessibilityHint("Shows technical details and validation information during scans")
                        .accessibilityValue(debugModeEnabled ? "On" : "Off")

                    if debugModeEnabled {
                        Toggle("Verbose Logging", isOn: verboseLoggingBinding)
                            .accessibilityLabel("Enable verbose logging")
                            .accessibilityHint("Logs every 10 frames instead of 30. May impact performance.")
                    }
                }

                // Data Management Section
                Section(header: Text(AppStrings.Sections.dataManagement),
                        footer: Text("Warning: Deleting all data will permanently remove all scan results, progress history, and app settings. This action cannot be undone.")) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label(AppStrings.Settings.deleteAllData, systemImage: SFSymbol.trashFill)
                    }
                    .accessibilityLabel("Delete all data")
                    .accessibilityHint("Permanently deletes all scan results, progress history, and settings. Requires confirmation.")
                }

                // Notifications Section
                Section(AppStrings.Settings.notifications) {
                    NavigationLink {
                        NotificationsSettingsView()
                    } label: {
                        Label("Notification Preferences", systemImage: SFSymbol.bellFill)
                    }
                    .accessibilityLabel("Notification Preferences")
                    .accessibilityHint("Configure scan reminders and notification settings")
                }

                // Privacy Section
                Section(AppStrings.Settings.privacy) {
                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        Label(AppStrings.Titles.privacyData, systemImage: SFSymbol.lockFill)
                    }
                    .accessibilityLabel(AppStrings.Titles.privacyData)
                    .accessibilityHint("Manage your data and privacy settings")
                }

                // About Section
                Section(AppStrings.About.about) {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("\(AppStrings.About.about) \(AppStrings.About.appName)", systemImage: SFSymbol.infoCircleFill)
                    }
                    .accessibilityLabel("\(AppStrings.About.about) \(AppStrings.About.appName)")
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

                // Delete Account Section (App Store Requirement 5.1.1)
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                            Spacer()
                        }
                    }
                    .accessibilityLabel("Delete Account")
                    .accessibilityHint("Permanently deletes all your data and resets the app")
                } footer: {
                    Text("Ollvy stores all data locally on your device. Deleting your account will permanently remove all scans, analysis results, achievements, and settings. This cannot be undone.")
                }
            }
            .navigationTitle(AppStrings.Titles.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppStrings.Buttons.done) {
                        dismiss()
                    }
                    .accessibilityLabel(AppStrings.Buttons.done)
                    .accessibilityHint("Closes settings and returns to previous screen")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Designs.Colors.background)
            .toolbarBackground(Designs.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert(AppStrings.Confirmations.deleteAllDataTitle, isPresented: $showDeleteConfirmation) {
                Button(AppStrings.Buttons.cancel, role: .cancel) { }
                Button(AppStrings.Buttons.delete, role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text(AppStrings.Confirmations.deleteAllDataMessage)
            }
        }
        .preferredColorScheme(.dark)
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
        guard let domain = Bundle.main.bundleIdentifier else {
            AppLogger.storage.warning("⚠️ Could not get bundle identifier for clearing UserDefaults")
            return
        }
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()

        // Set defaults back to initial values
        UserDefaults.standard.set(true, forKey: AppDefaultsKey.enableFaceMesh)
        UserDefaults.standard.set(false, forKey: AppDefaultsKey.enableHighResCapture)
        UserDefaults.standard.set("Strict", forKey: AppDefaultsKey.lightingStrictness)
        UserDefaults.standard.set(true, forKey: AppDefaultsKey.enableHapticFeedback)
        UserDefaults.standard.set(false, forKey: AppDefaultsKey.debugModeEnabled)
        UserDefaults.standard.set(false, forKey: AppDefaultsKey.skipOnboarding)
        UserDefaults.standard.set(true, forKey: AppDefaultsKey.useRealtimeProcessing)

        // Edge case detection defaults
        UserDefaults.standard.set(true, forKey: AppDefaultsKey.detectGlasses)
        UserDefaults.standard.set(true, forKey: AppDefaultsKey.detectHands)
        UserDefaults.standard.set(true, forKey: AppDefaultsKey.detectHat)
        UserDefaults.standard.set(true, forKey: AppDefaultsKey.detectMakeup)
        UserDefaults.standard.set(true, forKey: AppDefaultsKey.detectHairCoverage)
        UserDefaults.standard.set(true, forKey: AppDefaultsKey.detectSunburn)
        UserDefaults.standard.set(true, forKey: AppDefaultsKey.detectEarrings)
        UserDefaults.standard.set(true, forKey: AppDefaultsKey.detectFacialHair)

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
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
