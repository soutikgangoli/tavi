//
//  CaptureSettingsView.swift
//  Ollvy
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

    @AppStorage(AppDefaultsKey.enableHighResCapture) private var enableHighResCapture = false
    @AppStorage(AppDefaultsKey.enableFaceMesh) private var enableFaceMesh = true
    @AppStorage(AppDefaultsKey.useRealtimeProcessing) private var useRealtimeProcessing = true
    @AppStorage(AppDefaultsKey.enableHapticFeedback) private var enableHapticFeedback = true
    @AppStorage(AppDefaultsKey.lightingStrictness) private var lightingStrictnessRaw = LightingStrictness.strict.rawValue
    @AppStorage(AppDefaultsKey.enableSunDamageAnalysis) private var enableSunDamageAnalysis = false

    // Edge Case Detection Settings
    @AppStorage(AppDefaultsKey.detectGlasses) private var detectGlasses: Bool = true
    @AppStorage(AppDefaultsKey.detectHands) private var detectHands: Bool = true
    @AppStorage(AppDefaultsKey.detectHat) private var detectHat: Bool = true
    @AppStorage(AppDefaultsKey.detectMakeup) private var detectMakeup: Bool = true
    @AppStorage(AppDefaultsKey.detectHairCoverage) private var detectHairCoverage: Bool = true
    @AppStorage(AppDefaultsKey.detectSunburn) private var detectSunburn: Bool = true
    @AppStorage(AppDefaultsKey.detectEarrings) private var detectEarrings: Bool = true
    @AppStorage(AppDefaultsKey.detectFacialHair) private var detectFacialHair: Bool = true

    private var lightingStrictness: Binding<LightingStrictness> {
        Binding(
            get: { LightingStrictness(rawValue: lightingStrictnessRaw) ?? .strict },
            set: { lightingStrictnessRaw = $0.rawValue }
        )
    }

    private let capabilities = DeviceCapabilities.current

    // MARK: - Device-Based High-Res Resolution

    /// Whether user has explicitly set high-res preference
    private var hasUserSetHighResPreference: Bool {
        UserDefaults.standard.object(forKey: AppDefaultsKey.enableHighResCapture) != nil
    }

    /// Actual effective high-res state (considering device default)
    /// - If user never touched toggle: use device default (4K for 6GB+ devices)
    /// - If user explicitly set: use their preference
    private var isHighQualityEffective: Bool {
        if hasUserSetHighResPreference {
            return UserDefaults.standard.bool(forKey: AppDefaultsKey.enableHighResCapture)
        }
        return capabilities.supports4KTextureDefault
    }

    /// Custom binding that reflects actual state and writes explicit preference
    private var highQualityBinding: Binding<Bool> {
        Binding(
            get: { isHighQualityEffective },
            set: { newValue in
                UserDefaults.standard.set(newValue, forKey: AppDefaultsKey.enableHighResCapture)
            }
        )
    }

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
            Toggle(isOn: highQualityBinding) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("High Quality Mode")
                            .font(Designs.Typography.body)

                        Badge(text: "4K + 5 Frames", color: Designs.Colors.accent)

                        // Show "Auto" badge when using device default
                        if !hasUserSetHighResPreference && capabilities.supports4KTextureDefault {
                            Badge(text: "Auto", color: Designs.Colors.success)
                        }
                    }

                    Text(capabilities.supports4KTextureDefault
                        ? "4K texture + 5 frames per pose. Your device supports 4K by default."
                        : "4K texture + 5 frames per pose for advanced accuracy (90-92% confidence)")
                        .font(Designs.Typography.caption)
                        .foregroundColor(Designs.Colors.textSecondary)
                }
            }
            .accessibilityLabel("High quality mode")
            .accessibilityHint("Captures at 4K texture with 5 frames per pose for maximum accuracy. Uses more battery and storage.")
            .accessibilityValue(isHighQualityEffective ? "On" : "Off")
            .tint(Designs.Colors.accent)
            .onChange(of: isHighQualityEffective) { _, newValue in
                if newValue {
                    HapticManager.shared.light()
                }
            }
        } footer: {
            Text(capabilities.supports4KTextureDefault
                ? "Your device uses 4K by default (6GB+ RAM). Toggle off to use 2K and save battery."
                : "Note: Higher resolution uses more battery and storage. Recommended for detailed analysis.")
                .font(Designs.Typography.caption)
        }
    }

    // MARK: - Face Mesh Section

    private var faceMeshSection: some View {
        Section {
            Toggle(isOn: $enableFaceMesh) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Face Mesh Overlay")
                            .font(Designs.Typography.body)

                        Badge(text: "TrueDepth", color: Designs.Colors.info)
                    }

                    Text("Show 3D face mesh during capture")
                        .font(Designs.Typography.caption)
                        .foregroundColor(Designs.Colors.textSecondary)
                }
            }
            .accessibilityLabel("Face mesh overlay")
            .accessibilityHint("Shows a 3D wireframe mesh of your face during capture using TrueDepth camera")
            .accessibilityValue(enableFaceMesh ? "On" : "Off")
            .tint(Designs.Colors.accent)
            .onChange(of: enableFaceMesh) { _, newValue in
                if newValue {
                    HapticManager.shared.light()
                }
            }
        } footer: {
            Text("Uses TrueDepth camera to display a 3D mesh of your face for precise positioning.")
                .font(Designs.Typography.caption)
        }
    }

    // MARK: - Haptic Feedback Section

    private var hapticFeedbackSection: some View {
        Section {
            Toggle(isOn: $enableHapticFeedback) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Haptic Feedback")
                        .font(Designs.Typography.body)

                    Text("Vibrate when pose is correct and captured")
                        .font(Designs.Typography.caption)
                        .foregroundColor(Designs.Colors.textSecondary)
                }
            }
            .accessibilityLabel("Haptic feedback")
            .accessibilityHint("Provides vibration feedback when pose is correct and captured")
            .accessibilityValue(enableHapticFeedback ? "On" : "Off")
            .tint(Designs.Colors.accent)
            .onChange(of: enableHapticFeedback) { _, newValue in
                if newValue {
                    HapticManager.shared.light()
                }
            }
        } footer: {
            Text("Get tactile feedback during scanning to know when your pose is perfect.")
                .font(Designs.Typography.caption)
        }
    }

    // MARK: - Lighting Strictness Section

    private var lightingGuideSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Lighting Validation")
                        .font(Designs.Typography.body)

                    if lightingStrictness.wrappedValue == .strict {
                        Badge(text: "Recommended", color: Designs.Colors.success)
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
                .onChange(of: lightingStrictness.wrappedValue) {
                    HapticManager.shared.light()
                }

                // Description
                Text(lightingStrictness.wrappedValue.description)
                    .font(Designs.Typography.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("• Strict: Validates lighting for every pose (40-70% brightness)")
                Text("• Relaxed: Blocks only extreme lighting (<15%, >95%)")
                Text("• Off: No blocking, warnings only")
            }
            .font(Designs.Typography.caption)
        }
    }

    // MARK: - Sun Damage Analysis Section

    private var sunDamageAnalysisSection: some View {
        Section {
            Toggle(isOn: $enableSunDamageAnalysis) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Sun Damage Analysis")
                            .font(Designs.Typography.body)

                        Badge(text: "Advanced", color: Designs.Colors.warning)
                    }

                    Text("Assess UV protection and photoaging indicators")
                        .font(Designs.Typography.caption)
                        .foregroundColor(Designs.Colors.textSecondary)
                }
            }
            .accessibilityLabel("Sun damage analysis")
            .accessibilityHint("Analyzes pigmentation, photoaging, texture, redness, and pores to assess UV damage")
            .accessibilityValue(enableSunDamageAnalysis ? "On" : "Off")
            .tint(Designs.Colors.accent)
            .onChange(of: enableSunDamageAnalysis) { _, newValue in
                if newValue {
                    HapticManager.shared.light()
                }
            }
        } footer: {
            Text("Analyzes 5 indicators (pigmentation, photoaging, texture, redness, pores) to assess sun damage. Normalized for all skin tones. Disable if you prefer not to track UV damage.")
                .font(Designs.Typography.caption)
        }
    }

    // MARK: - Edge Case Detection Section

    private var edgeCaseDetectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("Edge Case Detection")
                    .font(Designs.Typography.body)
                    .fontWeight(.semibold)

                Toggle("Glasses", isOn: $detectGlasses)
                    .accessibilityLabel("Detect glasses")
                    .accessibilityHint("Warns if glasses are detected during scan")
                    .accessibilityValue(detectGlasses ? "On" : "Off")
                    .tint(Designs.Colors.accent)
                Toggle("Hands on Face", isOn: $detectHands)
                    .accessibilityLabel("Detect hands on face")
                    .accessibilityHint("Warns if hands are touching face during scan")
                    .accessibilityValue(detectHands ? "On" : "Off")
                    .tint(Designs.Colors.accent)
                Toggle("Hat/Headband", isOn: $detectHat)
                    .accessibilityLabel("Detect hat or headband")
                    .accessibilityHint("Warns if headwear is detected during scan")
                    .accessibilityValue(detectHat ? "On" : "Off")
                    .tint(Designs.Colors.accent)
                Toggle("Heavy Makeup", isOn: $detectMakeup)
                    .accessibilityLabel("Detect heavy makeup")
                    .accessibilityHint("Warns if heavy makeup is detected during scan")
                    .accessibilityValue(detectMakeup ? "On" : "Off")
                    .tint(Designs.Colors.accent)
                Toggle("Hair Coverage", isOn: $detectHairCoverage)
                    .accessibilityLabel("Detect hair coverage")
                    .accessibilityHint("Warns if hair is covering parts of face during scan")
                    .accessibilityValue(detectHairCoverage ? "On" : "Off")
                    .tint(Designs.Colors.accent)
                Toggle("Sunburn", isOn: $detectSunburn)
                    .accessibilityLabel("Detect sunburn")
                    .accessibilityHint("Warns if sunburn is detected during scan")
                    .accessibilityValue(detectSunburn ? "On" : "Off")
                    .tint(Designs.Colors.accent)
                Toggle("Earrings", isOn: $detectEarrings)
                    .accessibilityLabel("Detect earrings")
                    .accessibilityHint("Warns if earrings are detected during scan")
                    .accessibilityValue(detectEarrings ? "On" : "Off")
                    .tint(Designs.Colors.accent)
                Toggle("Facial Hair", isOn: $detectFacialHair)
                    .accessibilityLabel("Detect facial hair")
                    .accessibilityHint("Warns if facial hair is detected during scan")
                    .accessibilityValue(detectFacialHair ? "On" : "Off")
                    .tint(Designs.Colors.accent)
            }
            .padding(.vertical, 4)
        } footer: {
            Text("Disable detections that cause false positives for your face. All are enabled by default for maximum accuracy. Warning: Disabling these may affect scan quality.")
                .font(Designs.Typography.caption)
        }
    }

    // MARK: - Real-time Processing Section

    private var realtimeProcessingSection: some View {
        Section {
            Toggle(isOn: $useRealtimeProcessing) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Real-time Processing")
                            .font(Designs.Typography.body)

                        Badge(text: "A16+", color: Designs.Colors.success)
                    }

                    Text("Process frames as they're captured")
                        .font(Designs.Typography.caption)
                        .foregroundColor(Designs.Colors.textSecondary)
                }
            }
            .accessibilityLabel("Real-time processing")
            .accessibilityHint("Processes frames instantly using Neural Engine. Disable to save battery.")
            .accessibilityValue(useRealtimeProcessing ? "On" : "Off")
            .tint(Designs.Colors.accent)
            .onChange(of: useRealtimeProcessing) { _, newValue in
                if newValue {
                    HapticManager.shared.light()
                }
            }
        } footer: {
            Text("Leverages Neural Engine for instant results. Disable to save battery.")
                .font(Designs.Typography.caption)
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
                    color: Designs.Colors.warning
                )
            } else if capabilities.isHighEndDevice {
                TipCard(
                    icon: "bolt.fill",
                    title: "All features available",
                    description: "Your device supports all advanced features including real-time processing and 4K capture.",
                    color: Designs.Colors.success
                )
            }

            if isHighQualityEffective && !capabilities.isHighEndDevice {
                TipCard(
                    icon: "battery.25",
                    title: "Battery impact",
                    description: "4K capture uses more battery. Consider disabling for everyday use.",
                    color: Designs.Colors.warning
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
                        .foregroundColor(Designs.Colors.accent)

                    Text("Device Capabilities")
                        .font(Designs.Typography.body)
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
            .font(Designs.Typography.caption2)
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
        HStack(alignment: .top, spacing: Designs.Spacing.small) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(Designs.Typography.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Designs.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text(description)
                    .font(Designs.Typography.caption)
                    .foregroundColor(Designs.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Designs.Spacing.xSmall)
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
