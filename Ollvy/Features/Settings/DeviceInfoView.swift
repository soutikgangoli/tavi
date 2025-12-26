//
//  DeviceInfoView.swift
//  Ollvy
//
//  Created on 2025-10-27.
//

import SwiftUI

/// View showing device capabilities and optimized settings
struct DeviceInfoView: View {

    private let capabilities = DeviceCapabilities.current

    var body: some View {
        List {
            deviceSection
            capabilitiesSection
            optimizedSettingsSection
            performanceSection
        }
        .navigationTitle("Device Info")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Device Section

    private var deviceSection: some View {
        Section("Device") {
            InfoRow(label: "Model", value: capabilities.deviceName)
            InfoRow(label: "Chip", value: capabilities.iPhoneModel.chipName)
            InfoRow(label: "Identifier", value: capabilities.modelIdentifier)
        }
    }

    // MARK: - Capabilities Section

    private var capabilitiesSection: some View {
        Section("Capabilities") {
            CapabilityRow(
                label: "TrueDepth Camera",
                isSupported: capabilities.supportsTrueDepth,
                detail: "Face mesh overlay"
            )

            CapabilityRow(
                label: "4K Video Capture",
                isSupported: capabilities.supports4KVideo,
                detail: "High-resolution capture"
            )

            CapabilityRow(
                label: "Neural Engine A16+",
                isSupported: capabilities.supportsNeuralEngineA16Plus,
                detail: "Real-time processing"
            )
        }
    }

    // MARK: - Optimized Settings Section

    private var optimizedSettingsSection: some View {
        Section {
            InfoRow(
                label: "Processing Mode",
                value: capabilities.recommendedProcessingMode.description
            )

            InfoRow(
                label: "Max Resolution",
                value: capabilities.maxRecommendedResolution.description
            )

            InfoRow(
                label: "Frame Rate",
                value: "\(capabilities.recommendedFrameRate) fps"
            )

            InfoRow(
                label: "Concurrent Frames",
                value: "\(capabilities.maxConcurrentFrames) frames"
            )
        } header: {
            Text("Optimized Settings")
        } footer: {
            Text("These settings are automatically optimized for your device to provide the best balance of performance and quality.")
                .font(Designs.Typography.caption)
        }
    }

    // MARK: - Performance Section

    private var performanceSection: some View {
        Section("Performance Profile") {
            if capabilities.isHighEndDevice {
                PerformanceBadge(
                    title: "High-End Device",
                    description: "All features enabled with real-time processing",
                    icon: "bolt.fill",
                    color: Designs.Colors.success
                )
            } else if capabilities.isLowEndDevice {
                PerformanceBadge(
                    title: "Optimized Mode",
                    description: "Features adjusted for optimal performance",
                    icon: "gauge.medium",
                    color: Designs.Colors.warning
                )
            } else {
                PerformanceBadge(
                    title: "Balanced Mode",
                    description: "Good balance of features and performance",
                    icon: "checkmark.circle.fill",
                    color: Designs.Colors.info
                )
            }
        }
    }
}

// MARK: - Supporting Views

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(Designs.Typography.body)
                .foregroundColor(Designs.Colors.textPrimary)

            Spacer()

            Text(value)
                .font(Designs.Typography.body)
                .foregroundColor(Designs.Colors.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct CapabilityRow: View {
    let label: String
    let isSupported: Bool
    let detail: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(Designs.Typography.body)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text(detail)
                    .font(Designs.Typography.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: isSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isSupported ? Designs.Colors.success : Designs.Colors.textTertiary)
                .font(Designs.Typography.title3)
        }
    }
}

private struct PerformanceBadge: View {
    let title: String
    let description: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: Designs.Spacing.medium) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Designs.Typography.headline)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text(description)
                    .font(Designs.Typography.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Designs.Spacing.small)
    }
}

// MARK: - Preview

#Preview("High-End Device") {
    NavigationStack {
        DeviceInfoView()
    }
}

#Preview("Device List") {
    List {
        NavigationLink("Device Info") {
            DeviceInfoView()
        }
    }
    .navigationTitle("Settings")
}
