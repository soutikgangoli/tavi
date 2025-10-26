//
//  CaptureSettingsView.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

/// Settings view with capability-aware feature toggles
struct CaptureSettingsView: View {

    @AppStorage("enableHighResCapture") private var enableHighResCapture = false
    @AppStorage("enableFaceMesh") private var enableFaceMesh = true
    @AppStorage("useRealtimeProcessing") private var useRealtimeProcessing = true

    private let capabilities = DeviceCapabilities.current

    var body: some View {
        List {
            // High-Res Capture (4K devices only)
            if capabilities.shouldShowHighResCaptureToggle {
                highResCaptureSection
            }

            // Face Mesh (TrueDepth devices only)
            if capabilities.shouldEnableFaceMesh {
                faceMeshSection
            }

            // Real-time Processing (A16+ devices only)
            if capabilities.supportsNeuralEngineA16Plus {
                realtimeProcessingSection
            }

            // Performance tips
            performanceTipsSection

            // Device info link
            deviceInfoSection
        }
        .navigationTitle("Capture Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - High-Res Capture Section

    private var highResCaptureSection: some View {
        Section {
            Toggle(isOn: $enableHighResCapture) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("High-Res Capture")
                            .font(DesignSystem.Typography.body)

                        Badge(text: "4K", color: DesignSystem.Colors.accent)
                    }

                    Text("Capture at 4K resolution for maximum detail")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .tint(DesignSystem.Colors.accent)
            .onChange(of: enableHighResCapture) { _, newValue in
                if newValue {
                    HapticManager.shared.light()
                }
            }
        } footer: {
            Text("Note: Higher resolution uses more battery and storage. Recommended for detailed analysis.")
                .font(DesignSystem.Typography.caption)
        }
    }

    // MARK: - Face Mesh Section

    private var faceMeshSection: some View {
        Section {
            Toggle(isOn: $enableFaceMesh) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Face Mesh Overlay")
                            .font(DesignSystem.Typography.body)

                        Badge(text: "TrueDepth", color: DesignSystem.Colors.info)
                    }

                    Text("Show 3D face mesh during capture")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .tint(DesignSystem.Colors.accent)
            .onChange(of: enableFaceMesh) { _, newValue in
                if newValue {
                    HapticManager.shared.light()
                }
            }
        } footer: {
            Text("Uses TrueDepth camera to display a 3D mesh of your face for precise positioning.")
                .font(DesignSystem.Typography.caption)
        }
    }

    // MARK: - Real-time Processing Section

    private var realtimeProcessingSection: some View {
        Section {
            Toggle(isOn: $useRealtimeProcessing) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Real-time Processing")
                            .font(DesignSystem.Typography.body)

                        Badge(text: "A16+", color: DesignSystem.Colors.success)
                    }

                    Text("Process frames as they're captured")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .tint(DesignSystem.Colors.accent)
            .onChange(of: useRealtimeProcessing) { _, newValue in
                if newValue {
                    HapticManager.shared.light()
                }
            }
        } footer: {
            Text("Leverages Neural Engine for instant results. Disable to save battery.")
                .font(DesignSystem.Typography.caption)
        }
    }

    // MARK: - Performance Tips Section

    private var performanceTipsSection: some View {
        Section("Performance Tips") {
            if capabilities.isLowEndDevice {
                TipCard(
                    icon: "lightbulb.fill",
                    title: "Optimized for your device",
                    description: "Some features are adjusted for best performance on your iPhone model.",
                    color: DesignSystem.Colors.warning
                )
            } else if capabilities.isHighEndDevice {
                TipCard(
                    icon: "bolt.fill",
                    title: "All features available",
                    description: "Your device supports all advanced features including real-time processing and 4K capture.",
                    color: DesignSystem.Colors.success
                )
            }

            if enableHighResCapture && !capabilities.isHighEndDevice {
                TipCard(
                    icon: "battery.25",
                    title: "Battery impact",
                    description: "4K capture uses more battery. Consider disabling for everyday use.",
                    color: DesignSystem.Colors.warning
                )
            }
        }
    }

    // MARK: - Device Info Section

    private var deviceInfoSection: some View {
        Section {
            NavigationLink {
                DeviceInfoView()
            } label: {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(DesignSystem.Colors.accent)

                    Text("Device Capabilities")
                        .font(DesignSystem.Typography.body)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct TipCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.small) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(DesignSystem.Typography.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(description)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xSmall)
    }
}

// MARK: - Preview

#Preview("High-End Device") {
    NavigationStack {
        CaptureSettingsView()
    }
}

#Preview("Settings List") {
    List {
        NavigationLink("Capture Settings") {
            CaptureSettingsView()
        }
    }
}
