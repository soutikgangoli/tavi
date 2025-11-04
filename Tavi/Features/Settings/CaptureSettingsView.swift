//
//  CaptureSettingsView.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

/// Lighting strictness levels
enum LightingStrictness: String, CaseIterable, Identifiable {
    case strict = "Strict"
    case relaxed = "Relaxed"
    case off = "Off"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .strict:
            return "Calibrates lighting for each pose. Ensures perfect conditions."
        case .relaxed:
            return "Lenient thresholds. Blocks only extreme lighting."
        case .off:
            return "No blocking. Shows warnings only."
        }
    }

    var minBrightness: Float {
        switch self {
        case .strict: return 0.25  // Block <25%
        case .relaxed: return 0.15  // Block <15%
        case .off: return 0.0  // Never block
        }
    }

    var maxBrightness: Float {
        switch self {
        case .strict: return 0.90  // Block >90%
        case .relaxed: return 0.95  // Block >95%
        case .off: return 1.0  // Never block
        }
    }

    var shouldValidatePerPose: Bool {
        self == .strict  // Only Strict validates every pose
    }
}

/// Settings view with capability-aware feature toggles
struct CaptureSettingsView: View {

    @AppStorage("enableHighResCapture") private var enableHighResCapture = false
    @AppStorage("enableFaceMesh") private var enableFaceMesh = true
    @AppStorage("useRealtimeProcessing") private var useRealtimeProcessing = true
    @AppStorage("enableHapticFeedback") private var enableHapticFeedback = true
    @AppStorage("lightingStrictness") private var lightingStrictnessRaw = LightingStrictness.strict.rawValue
    @AppStorage("enableSunDamageAnalysis") private var enableSunDamageAnalysis = false

    // Edge Case Detection Settings
    @AppStorage("detectGlasses") private var detectGlasses: Bool = true
    @AppStorage("detectHands") private var detectHands: Bool = true
    @AppStorage("detectHat") private var detectHat: Bool = true
    @AppStorage("detectMakeup") private var detectMakeup: Bool = true
    @AppStorage("detectHairCoverage") private var detectHairCoverage: Bool = true
    @AppStorage("detectSunburn") private var detectSunburn: Bool = true
    @AppStorage("detectEarrings") private var detectEarrings: Bool = true
    @AppStorage("detectFacialHair") private var detectFacialHair: Bool = true

    private var lightingStrictness: Binding<LightingStrictness> {
        Binding(
            get: { LightingStrictness(rawValue: lightingStrictnessRaw) ?? .strict },
            set: { lightingStrictnessRaw = $0.rawValue }
        )
    }

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

            // Haptic Feedback (all devices)
            hapticFeedbackSection

            // Lighting Guide (all devices)
            lightingGuideSection

            // Sun Damage Analysis (all devices)
            sunDamageAnalysisSection

            // Edge Case Detection (all devices)
            edgeCaseDetectionSection

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
            .accessibilityLabel("High resolution capture")
            .accessibilityHint("Captures at 4K resolution for maximum detail. Uses more battery and storage.")
            .accessibilityValue(enableHighResCapture ? "On" : "Off")
            .tint(DesignSystem.Colors.accent)
            .onChange(of: enableHighResCapture) { newValue in
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
            .accessibilityLabel("Face mesh overlay")
            .accessibilityHint("Shows a 3D wireframe mesh of your face during capture using TrueDepth camera")
            .accessibilityValue(enableFaceMesh ? "On" : "Off")
            .tint(DesignSystem.Colors.accent)
            .onChange(of: enableFaceMesh) { newValue in
                if newValue {
                    HapticManager.shared.light()
                }
            }
        } footer: {
            Text("Uses TrueDepth camera to display a 3D mesh of your face for precise positioning.")
                .font(DesignSystem.Typography.caption)
        }
    }

    // MARK: - Haptic Feedback Section

    private var hapticFeedbackSection: some View {
        Section {
            Toggle(isOn: $enableHapticFeedback) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Haptic Feedback")
                        .font(DesignSystem.Typography.body)

                    Text("Vibrate when pose is correct and captured")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .accessibilityLabel("Haptic feedback")
            .accessibilityHint("Provides vibration feedback when pose is correct and captured")
            .accessibilityValue(enableHapticFeedback ? "On" : "Off")
            .tint(DesignSystem.Colors.accent)
            .onChange(of: enableHapticFeedback) { newValue in
                if newValue {
                    HapticManager.shared.light()
                }
            }
        } footer: {
            Text("Get tactile feedback during scanning to know when your pose is perfect.")
                .font(DesignSystem.Typography.caption)
        }
    }

    // MARK: - Lighting Strictness Section

    private var lightingGuideSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Lighting Validation")
                        .font(DesignSystem.Typography.body)

                    if lightingStrictness.wrappedValue == .strict {
                        Badge(text: "Recommended", color: DesignSystem.Colors.success)
                    }
                }

                Picker("Strictness Level", selection: lightingStrictness) {
                    ForEach(LightingStrictness.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Lighting validation strictness level")
                .accessibilityHint("Controls how strictly lighting conditions are validated before scanning")
                .accessibilityValue(lightingStrictness.wrappedValue.rawValue)
                .onChange(of: lightingStrictness.wrappedValue) { _ in
                    HapticManager.shared.light()
                }

                // Description
                Text(lightingStrictness.wrappedValue.description)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("• Strict: Validates lighting for every pose (40-70% brightness)")
                Text("• Relaxed: Blocks only extreme lighting (<15%, >95%)")
                Text("• Off: No blocking, warnings only")
            }
            .font(DesignSystem.Typography.caption)
        }
    }

    // MARK: - Sun Damage Analysis Section

    private var sunDamageAnalysisSection: some View {
        Section {
            Toggle(isOn: $enableSunDamageAnalysis) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Sun Damage Analysis")
                            .font(DesignSystem.Typography.body)

                        Badge(text: "Advanced", color: DesignSystem.Colors.warning)
                    }

                    Text("Assess UV protection and photoaging indicators")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .accessibilityLabel("Sun damage analysis")
            .accessibilityHint("Analyzes pigmentation, photoaging, texture, redness, and pores to assess UV damage")
            .accessibilityValue(enableSunDamageAnalysis ? "On" : "Off")
            .tint(DesignSystem.Colors.accent)
            .onChange(of: enableSunDamageAnalysis) { newValue in
                if newValue {
                    HapticManager.shared.light()
                }
            }
        } footer: {
            Text("Analyzes 5 indicators (pigmentation, photoaging, texture, redness, pores) to assess sun damage. Normalized for all skin tones. Disable if you prefer not to track UV damage.")
                .font(DesignSystem.Typography.caption)
        }
    }

    // MARK: - Edge Case Detection Section

    private var edgeCaseDetectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("Edge Case Detection")
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)

                Toggle("Glasses", isOn: $detectGlasses)
                    .accessibilityLabel("Detect glasses")
                    .accessibilityHint("Warns if glasses are detected during scan")
                    .accessibilityValue(detectGlasses ? "On" : "Off")
                    .tint(DesignSystem.Colors.accent)
                Toggle("Hands on Face", isOn: $detectHands)
                    .accessibilityLabel("Detect hands on face")
                    .accessibilityHint("Warns if hands are touching face during scan")
                    .accessibilityValue(detectHands ? "On" : "Off")
                    .tint(DesignSystem.Colors.accent)
                Toggle("Hat/Headband", isOn: $detectHat)
                    .accessibilityLabel("Detect hat or headband")
                    .accessibilityHint("Warns if headwear is detected during scan")
                    .accessibilityValue(detectHat ? "On" : "Off")
                    .tint(DesignSystem.Colors.accent)
                Toggle("Heavy Makeup", isOn: $detectMakeup)
                    .accessibilityLabel("Detect heavy makeup")
                    .accessibilityHint("Warns if heavy makeup is detected during scan")
                    .accessibilityValue(detectMakeup ? "On" : "Off")
                    .tint(DesignSystem.Colors.accent)
                Toggle("Hair Coverage", isOn: $detectHairCoverage)
                    .accessibilityLabel("Detect hair coverage")
                    .accessibilityHint("Warns if hair is covering parts of face during scan")
                    .accessibilityValue(detectHairCoverage ? "On" : "Off")
                    .tint(DesignSystem.Colors.accent)
                Toggle("Sunburn", isOn: $detectSunburn)
                    .accessibilityLabel("Detect sunburn")
                    .accessibilityHint("Warns if sunburn is detected during scan")
                    .accessibilityValue(detectSunburn ? "On" : "Off")
                    .tint(DesignSystem.Colors.accent)
                Toggle("Earrings", isOn: $detectEarrings)
                    .accessibilityLabel("Detect earrings")
                    .accessibilityHint("Warns if earrings are detected during scan")
                    .accessibilityValue(detectEarrings ? "On" : "Off")
                    .tint(DesignSystem.Colors.accent)
                Toggle("Facial Hair", isOn: $detectFacialHair)
                    .accessibilityLabel("Detect facial hair")
                    .accessibilityHint("Warns if facial hair is detected during scan")
                    .accessibilityValue(detectFacialHair ? "On" : "Off")
                    .tint(DesignSystem.Colors.accent)
            }
            .padding(.vertical, 4)
        } footer: {
            Text("Disable detections that cause false positives for your face. All are enabled by default for maximum accuracy. Warning: Disabling these may affect scan quality.")
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
            .accessibilityLabel("Real-time processing")
            .accessibilityHint("Processes frames instantly using Neural Engine. Disable to save battery.")
            .accessibilityValue(useRealtimeProcessing ? "On" : "Off")
            .tint(DesignSystem.Colors.accent)
            .onChange(of: useRealtimeProcessing) { newValue in
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
            .accessibilityLabel("Device Capabilities")
            .accessibilityHint("Shows detailed information about your device hardware and supported features")
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
