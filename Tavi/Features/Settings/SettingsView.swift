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
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            Form {
                // Scan Settings Section
                Section(header: Text("Scan Settings"),
                        footer: Text("High resolution capture provides better quality but uses more storage.")) {
                    Toggle("Show 3D Face Mesh", isOn: $enableFaceMesh)
                        .accessibilityLabel("Show 3D face mesh during scan")
                        .onChange(of: enableFaceMesh) { oldValue, newValue in
                            AnalyticsManager.shared.trackSettingChanged(
                                setting: "enable_face_mesh",
                                value: String(newValue),
                                previousValue: String(oldValue)
                            )
                        }

                    Toggle("High Resolution Capture", isOn: $enableHighResCapture)
                        .accessibilityLabel("Enable high resolution capture (4K texture)")
                        .onChange(of: enableHighResCapture) { oldValue, newValue in
                            AnalyticsManager.shared.trackSettingChanged(
                                setting: "enable_high_res_capture",
                                value: String(newValue),
                                previousValue: String(oldValue)
                            )
                        }

                    Toggle("Haptic Feedback", isOn: $enableHapticFeedback)
                        .accessibilityLabel("Enable haptic feedback during scan")
                        .onChange(of: enableHapticFeedback) { oldValue, newValue in
                            AnalyticsManager.shared.trackSettingChanged(
                                setting: "enable_haptic_feedback",
                                value: String(newValue),
                                previousValue: String(oldValue)
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
                }

                // Advanced Settings Section
                Section("Advanced") {
                    NavigationLink {
                        CaptureSettingsView()
                    } label: {
                        Label("Capture Settings", systemImage: "camera.fill")
                    }

                    NavigationLink {
                        DeviceInfoView()
                    } label: {
                        Label("Device Information", systemImage: "info.circle.fill")
                    }
                }

                // Developer Section
                Section(header: Text("Developer"),
                        footer: Text("Debug mode shows additional scan information and validation details.")) {
                    Toggle("Debug Mode", isOn: $debugModeEnabled)
                        .accessibilityLabel("Enable debug mode for additional scan information")

                    Button("Reset Onboarding") {
                        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }

                // About Section
                Section("About") {
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
                }
            }
        }
    }

    private var lightingStrictnessDescription: String {
        switch lightingStrictness {
        case "Strict":
            return "Strict validation ensures optimal lighting for accurate scans. Works for all skin tones by analyzing contrast and detail."
        case "Relaxed":
            return "Relaxed validation allows scanning in less-than-ideal lighting conditions. May affect scan accuracy."
        case "Off":
            return "No lighting validation. Scans will proceed regardless of lighting conditions. Not recommended for accurate results."
        default:
            return ""
        }
    }
}

#Preview {
    SettingsView()
}
