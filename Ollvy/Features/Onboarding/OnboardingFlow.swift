//
//  OnboardingFlow.swift
//  Ollvy
//
//  First-time user onboarding with tutorial screens
//  Gentler Streak inspired - warm, friendly, welcoming design
//

import SwiftUI

// MARK: - Gentler Streak Inspired Colors

private enum OnboardingColors {
    // Warm cream background
    static let background = Color(red: 252/255, green: 250/255, blue: 245/255)
    // Soft warm gray for text
    static let textPrimary = Color(red: 60/255, green: 60/255, blue: 60/255)
    static let textSecondary = Color(red: 120/255, green: 115/255, blue: 110/255)
    // Coral/orange accent (like the heart mascot)
    static let accentCoral = Color(red: 235/255, green: 120/255, blue: 90/255)
    // Soft teal for secondary actions
    static let accentTeal = Color(red: 75/255, green: 160/255, blue: 150/255)
    // Soft green for positive
    static let softGreen = Color(red: 130/255, green: 190/255, blue: 140/255)
    // Warm card background
    static let cardBackground = Color.white
}

/// Onboarding flow coordinator - Gentler Streak inspired design
public struct OnboardingFlowView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var currentPage: Int = 0
    @State private var userName: String = ""
    @FocusState private var isKeyboardFocused: Bool

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Hi there,",
            subtitle: "What's your name?",
            description: "Let's personalize your experience",
            imageName: "person.crop.circle",
            requiresInput: true
        ),
        OnboardingPage(
            title: "Track Your Skin",
            subtitle: "Simple. Private. Insightful.",
            description: "Quick 3D face scans to monitor your skin analysis over time.\n\n✓ Advanced AI skin analysis\n✓ 100% on-device privacy\n✓ Track changes & progress",
            imageName: "viewfinder.circle",
            requiresInput: false
        )
    ]

    public var body: some View {
        ZStack {
            // Warm cream background
            OnboardingColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with skip
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(OnboardingColors.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Page indicator dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? OnboardingColors.accentCoral : OnboardingColors.textSecondary.opacity(0.3))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.top, 20)

                // Content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(
                            page: pages[index],
                            userName: pages[index].requiresInput ? $userName : .constant(""),
                            isKeyboardFocused: pages[index].requiresInput ? $isKeyboardFocused : nil
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentPage) { _, newPage in
                    // Dismiss keyboard when navigating away from name input page
                    if newPage > 0 {
                        isKeyboardFocused = false
                    }
                }

                // Bottom action area
                VStack(spacing: 16) {
                    // Main action button
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation(.spring(response: 0.4)) {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        HStack {
                            Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                                .font(.system(size: 18, weight: .semibold))

                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(OnboardingColors.accentCoral)
                        )
                    }

                    // Back button (if not first page)
                    if currentPage > 0 {
                        Button {
                            withAnimation(.spring(response: 0.4)) {
                                currentPage -= 1
                            }
                        } label: {
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(OnboardingColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func completeOnboarding() {
        // Save user name if entered
        if !userName.isEmpty {
            try? UserProfileManager.shared.updateName(userName)
        }
        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: AppDefaultsKey.hasCompletedOnboarding)
        dismiss()
    }
}

/// Single onboarding page - Gentler Streak style
struct OnboardingPageView: View {
    let page: OnboardingPage
    @Binding var userName: String
    var isKeyboardFocused: FocusState<Bool>.Binding?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Illustration area
            ZStack {
                // Soft background circle
                Circle()
                    .fill(OnboardingColors.accentCoral.opacity(0.1))
                    .frame(width: 180, height: 180)

                // Icon
                Image(systemName: page.imageName)
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(OnboardingColors.accentCoral)
            }
            .padding(.bottom, 40)

            // Title
            Text(page.title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(OnboardingColors.textPrimary)
                .multilineTextAlignment(.center)

            // Subtitle
            if let subtitle = page.subtitle {
                Text(subtitle)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(OnboardingColors.accentTeal)
                    .padding(.top, 4)
            }

            // Description
            Text(page.description)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(OnboardingColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
                .padding(.top, 16)

            // Name input field (if required)
            if page.requiresInput {
                VStack(spacing: 8) {
                    if let focusBinding = isKeyboardFocused {
                        TextField("Your name", text: $userName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(OnboardingColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(OnboardingColors.cardBackground)
                                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                            )
                            .focused(focusBinding)
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                    } else {
                        TextField("Your name", text: $userName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(OnboardingColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(OnboardingColors.cardBackground)
                                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                            )
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 32)
            }

            Spacer()
            Spacer()
        }
    }
}

/// Onboarding page data
struct OnboardingPage {
    let title: String
    let subtitle: String?
    let description: String
    let imageName: String
    let requiresInput: Bool

    init(title: String, subtitle: String? = nil, description: String, imageName: String, requiresInput: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.imageName = imageName
        self.requiresInput = requiresInput
    }
}

// MARK: - Info/Tutorial Cards View (shown before first scan)

/// Info screen shown before the first scan - Gentler Streak style
public struct ScanInfoView: View {
    @Environment(\.dismiss) private var dismiss
    let onContinue: () -> Void

    private let infoCards: [InfoCard] = [
        InfoCard(
            icon: "sun.max.fill",
            title: "Good Lighting",
            description: "Find a well-lit spot with even, natural light for the best results.",
            color: Color(red: 255/255, green: 200/255, blue: 60/255)
        ),
        InfoCard(
            icon: "face.smiling",
            title: "Center Your Face",
            description: "Position yourself 12-18 inches from the camera, face centered.",
            color: Color(red: 235/255, green: 120/255, blue: 90/255)
        ),
        InfoCard(
            icon: "hand.raised.fill",
            title: "Stay Still",
            description: "Keep relaxed and still during the quick capture process.",
            color: Color(red: 75/255, green: 160/255, blue: 150/255)
        )
    ]

    public var body: some View {
        ZStack {
            // Warm cream background
            OnboardingColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Before You Scan")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(OnboardingColors.textPrimary)

                    Text("A few tips for the best results")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(OnboardingColors.textSecondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 32)

                // Info cards
                VStack(spacing: 16) {
                    ForEach(infoCards) { card in
                        InfoCardView(card: card)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Continue button
                Button {
                    onContinue()
                } label: {
                    HStack {
                        Text("I'm Ready")
                            .font(.system(size: 18, weight: .semibold))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(OnboardingColors.accentCoral)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

/// Info card data
struct InfoCard: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
}

/// Single info card - Gentler Streak style
struct InfoCardView: View {
    let card: InfoCard

    var body: some View {
        HStack(spacing: 16) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(card.color.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: card.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(card.color)
            }

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(OnboardingColors.textPrimary)

                Text(card.description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(OnboardingColors.textSecondary)
                    .lineSpacing(2)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(OnboardingColors.cardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Metric Explanation View

/// Metric explanation view (detailed) - Updated styling
public struct MetricExplanationView: View {
    let metric: AnalysisMetricType

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    ZStack {
                        Circle()
                            .fill(OnboardingColors.accentCoral.opacity(0.15))
                            .frame(width: 60, height: 60)

                        Image(systemName: metric.iconName)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(OnboardingColors.accentCoral)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(metric.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(OnboardingColors.textPrimary)

                        Text(metric.tagline)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(OnboardingColors.textSecondary)
                    }
                }
                .padding()

                Divider()

                // Content sections
                MetricSectionView(title: "What It Measures") {
                    Text(metric.whatItMeasures)
                        .font(.system(size: 16))
                        .foregroundColor(OnboardingColors.textPrimary)
                }

                MetricSectionView(title: "Why It Matters") {
                    Text(metric.whyItMatters)
                        .font(.system(size: 16))
                        .foregroundColor(OnboardingColors.textPrimary)
                }

                MetricSectionView(title: "How We Measure It") {
                    Text(metric.howWeMeasure)
                        .font(.system(size: 16))
                        .foregroundColor(OnboardingColors.textPrimary)
                }

                MetricSectionView(title: "What Affects This Metric") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(metric.affectingFactors, id: \.self) { factor in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(OnboardingColors.accentTeal)
                                    .frame(width: 6, height: 6)
                                Text(factor)
                                    .font(.system(size: 15))
                                    .foregroundColor(OnboardingColors.textPrimary)
                            }
                        }
                    }
                }

                MetricSectionView(title: "How to Improve") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(metric.improvementTips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(OnboardingColors.softGreen)
                                Text(tip)
                                    .font(.system(size: 15))
                                    .foregroundColor(OnboardingColors.textPrimary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(OnboardingColors.background)
        .navigationTitle(metric.name)
    }
}

/// Section view for metric explanations
struct MetricSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(OnboardingColors.textPrimary)

            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(OnboardingColors.cardBackground)
                        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                )
        }
    }
}

// Keep the old SectionView for backward compatibility if needed elsewhere
struct SectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(OnboardingColors.textPrimary)

            content
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(OnboardingColors.cardBackground)
                )
        }
    }
}

/// Metric information data
extension AnalysisMetricType {
    var iconName: String {
        switch self {
        case .roughness: return "waveform.path"
        case .wrinkles: return "line.3.horizontal.decrease"
        case .hydration: return "drop.fill"
        case .pores: return "circle.grid.3x3"
        case .pigmentation: return "paintpalette.fill"
        case .discoloration: return "paintpalette"
        case .specular: return "sparkles"
        case .luminance: return "sun.max.fill"
        case .brightness: return "sun.max.fill"
        }
    }

    var color: Color {
        OnboardingColors.accentCoral // Unified warm accent
    }

    var tagline: String {
        switch self {
        case .roughness: return "Skin smoothness"
        case .wrinkles: return "Fine lines & depth"
        case .hydration: return "Moisture level"
        case .pores: return "Pore visibility"
        case .pigmentation: return "Skin tone evenness"
        case .discoloration: return "Color uniformity"
        case .specular: return "Shine & oil control"
        case .luminance: return "Overall brightness"
        case .brightness: return "Overall brightness"
        }
    }

    var whatItMeasures: String {
        switch self {
        case .roughness:
            return "Skin texture roughness measures how smooth or uneven your skin surface is. We analyze microscopic texture patterns across your entire face."
        case .wrinkles:
            return "We measure actual wrinkle depth in millimeters using 3D geometry. This includes fine lines, crow's feet, forehead lines, and smile lines."
        case .hydration:
            return "Skin hydration indicates how well-moisturized your skin appears. We estimate this from surface texture and light reflection patterns."
        case .pores:
            return "Pore visibility measures how prominent your pores appear. We analyze pore density and average size across different facial regions."
        case .pigmentation:
            return "Pigmentation evenness measures color consistency across your face. We detect dark spots, hyperpigmentation, and overall tone uniformity."
        case .discoloration:
            return "Discoloration measures color variations and uneven tone across different facial regions. We analyze color differences between areas to detect discoloration patterns."
        case .specular:
            return "Specular highlights measure how much light your skin reflects, indicating oiliness and shine. We analyze reflection patterns to assess oil production levels."
        case .luminance:
            return "Luminance measures the overall brightness and lightness of your skin. We analyze the perceived brightness across your face to assess skin radiance."
        case .brightness:
            return "Luminance measures the overall brightness and lightness of your skin. We analyze the perceived brightness across your face to assess skin radiance."
        }
    }

    var whyItMatters: String {
        switch self {
        case .roughness:
            return "Smooth skin reflects light better and looks healthier. Rough texture can indicate dehydration, sun damage, or aging."
        case .wrinkles:
            return "Wrinkles are a natural part of aging, but deeper wrinkles can indicate collagen loss, sun damage, or dehydration. Tracking them helps you see if your skincare routine is working."
        case .hydration:
            return "Well-hydrated skin is more elastic, looks plumper, and has fewer fine lines. Dehydrated skin can appear dull and accentuate wrinkles."
        case .pores:
            return "While pore size is largely genetic, visible pores can be minimized with proper skincare. Enlarged pores often indicate oily skin or clogged pores."
        case .pigmentation:
            return "Even skin tone is a key indicator of skin analysis. Uneven pigmentation can result from sun damage, hormones, or inflammation."
        case .discoloration:
            return "Color uniformity across your face is important for a healthy, youthful appearance. Regional discoloration can indicate sun damage, inflammation, or circulation issues."
        case .specular:
            return "Balanced oil production is essential for healthy skin. Too much shine can indicate excess sebum, while too little can mean dry skin. Proper oil balance helps prevent acne and maintains skin barrier function."
        case .luminance:
            return "Overall skin brightness is associated with healthy, youthful skin. Dull skin can indicate dehydration, poor circulation, or buildup of dead skin cells. Radiant skin reflects good health."
        case .brightness:
            return "Overall skin brightness is associated with healthy, youthful skin. Dull skin can indicate dehydration, poor circulation, or buildup of dead skin cells. Radiant skin reflects good health."
        }
    }

    var howWeMeasure: String {
        switch self {
        case .roughness:
            return "Using high-resolution texture analysis, we calculate surface roughness from the 12MP camera texture mapped to your 3D face model."
        case .wrinkles:
            return "We use 3D curvature analysis to measure actual wrinkle depth in millimeters. This is unique to 3D scanning - 2D photos can't measure depth!"
        case .hydration:
            return "We estimate hydration from specular reflectance (how shiny your skin is) combined with roughness data. Very dry skin is rough and non-reflective."
        case .pores:
            return "High-frequency texture analysis detects small dark spots (pores) and calculates their density and average size per square centimeter."
        case .pigmentation:
            return "We analyze color variance across your face in the LAB color space, which is designed for human perception. We also detect dark spots and hyperpigmentation."
        case .discoloration:
            return "We compare color consistency across different facial regions using LAB color space analysis. This detects regional color variations and discoloration patterns."
        case .specular:
            return "We measure specular highlights by analyzing how light reflects off your skin surface. Higher specular values indicate more oil production and shine."
        case .luminance:
            return "We calculate the L* (lightness) component in LAB color space, which represents the perceived brightness of your skin independent of color."
        case .brightness:
            return "We calculate the L* (lightness) component in LAB color space, which represents the perceived brightness of your skin independent of color."
        }
    }

    var affectingFactors: [String] {
        switch self {
        case .roughness:
            return ["Hydration level", "Exfoliation frequency", "Sun exposure", "Age", "Genetics"]
        case .wrinkles:
            return ["Age", "Sun exposure", "Smoking", "Facial expressions", "Collagen levels", "Hydration"]
        case .hydration:
            return ["Water intake", "Moisturizer use", "Humidity", "Climate", "Caffeine/alcohol", "Age"]
        case .pores:
            return ["Genetics", "Oil production", "Age", "Sun damage", "Skincare routine"]
        case .pigmentation:
            return ["Sun exposure", "Hormones", "Inflammation", "Age spots", "Melasma", "Genetics"]
        case .discoloration:
            return ["Sun exposure", "Inflammation", "Circulation", "Hormones", "Age", "Skincare routine"]
        case .specular:
            return ["Oil production", "Skincare routine", "Hormones", "Diet", "Climate", "Genetics"]
        case .luminance:
            return ["Hydration", "Exfoliation", "Sleep", "Blood circulation", "Sun exposure", "Skincare routine"]
        case .brightness:
            return ["Hydration", "Exfoliation", "Sleep", "Blood circulation", "Sun exposure", "Skincare routine"]
        }
    }

    var improvementTips: [String] {
        switch self {
        case .roughness:
            return [
                "Exfoliate 2-3 times per week with AHAs/BHAs",
                "Use a hydrating moisturizer daily",
                "Apply retinol/retinoids at night",
                "Stay hydrated (8 glasses of water/day)"
            ]
        case .wrinkles:
            return [
                "Use retinol products as recommended",
                "Apply SPF 30+ daily to prevent further damage",
                "Consider eye cream for crow's feet",
                "Stay hydrated and get adequate sleep",
                "Avoid smoking and limit alcohol"
            ]
        case .hydration:
            return [
                "Drink 8 glasses of water daily",
                "Use a hydrating serum (hyaluronic acid)",
                "Apply moisturizer morning and night",
                "Use a humidifier in dry climates",
                "Limit hot showers (strip natural oils)"
            ]
        case .pores:
            return [
                "Cleanse twice daily to prevent clogging",
                "Use niacinamide to reduce appearance",
                "Exfoliate regularly with BHAs (salicylic acid)",
                "Apply retinol to improve skin texture",
                "Always remove makeup before bed"
            ]
        case .pigmentation:
            return [
                "Wear SPF 30+ daily (most important!)",
                "Use vitamin C serum in the morning",
                "Try niacinamide for dark spots",
                "Consider professional skincare products recommended by your dermatologist",
                "Avoid direct sun exposure"
            ]
        case .discoloration:
            return [
                "Apply SPF 30+ daily to prevent further discoloration",
                "Use vitamin C and niacinamide serums",
                "Consider gentle chemical peels",
                "Maintain consistent skincare routine",
                "Address underlying inflammation or circulation issues"
            ]
        case .specular:
            return [
                "Use oil-control or mattifying products",
                "Cleanse twice daily with gentle cleanser",
                "Try niacinamide to regulate oil production",
                "Use blotting papers throughout the day",
                "Avoid heavy, comedogenic moisturizers",
                "Consider salicylic acid treatments"
            ]
        case .luminance:
            return [
                "Exfoliate regularly to remove dead skin cells",
                "Use vitamin C serum for brightening",
                "Stay well-hydrated (8 glasses water/day)",
                "Get adequate sleep (7-9 hours)",
                "Use illuminating or radiance-boosting products",
                "Protect from sun damage with daily SPF"
            ]
        case .brightness:
            return [
                "Exfoliate regularly to remove dead skin cells",
                "Use vitamin C serum for brightening",
                "Stay well-hydrated (8 glasses water/day)",
                "Get adequate sleep (7-9 hours)",
                "Use illuminating or radiance-boosting products",
                "Protect from sun damage with daily SPF"
            ]
        }
    }
}

public enum AnalysisMetricType: String, Codable, Identifiable {
    public var id: String { rawValue }
    case roughness
    case wrinkles
    case hydration
    case pores
    case pigmentation
    case discoloration
    case specular
    case luminance
    case brightness

    var name: String {
        switch self {
        case .roughness: return "Skin Texture"
        case .wrinkles: return "Wrinkles"
        case .hydration: return "Hydration"
        case .pores: return "Pores"
        case .pigmentation: return "Pigmentation"
        case .discoloration: return "Discoloration"
        case .specular: return "Oiliness"
        case .luminance: return "Brightness"
        case .brightness: return "Brightness"
        }
    }

    /// Get the metric value from ROI metrics (for ROI-level visualization)
    func getValue(from roiMetrics: ROI3DMetrics) -> Float {
        switch self {
        case .roughness: return roiMetrics.roughnessProxy
        case .wrinkles:
            return roiMetrics.roughnessScore / 100.0
        case .hydration:
            if roiMetrics.moistureProxy.moistureIndex > 0 {
                return Float(roiMetrics.moistureProxy.moistureIndex)
            }
            return 1.0 - roiMetrics.pigmentationIndex
        case .pores:
            return (100.0 - roiMetrics.roughnessScore) / 100.0
        case .pigmentation: return roiMetrics.pigmentationIndex
        case .discoloration:
            return roiMetrics.pigmentationIndex
        case .specular: return roiMetrics.specularProxy ?? 0
        case .luminance:
            return roiMetrics.averageLuminance / 255.0
        case .brightness:
            return roiMetrics.averageLuminance / 255.0
        }
    }

    /// Get the metric value from full Face3DMetrics
    func getValue(from metrics: Face3DMetrics) -> Float {
        switch self {
        case .roughness:
            return metrics.globalRoughnessProxy
        case .wrinkles:
            if let wrinkleAnalysis = metrics.wrinkleAnalysis {
                return wrinkleAnalysis.overallScore / 100.0
            }
            return metrics.globalRoughnessScore / 100.0
        case .hydration:
            if let hydration = metrics.hydrationEstimate {
                return hydration.overallScore / 100.0
            }
            let avgMoisture = metrics.roiMetrics.values.map { $0.moistureProxy.moistureIndex }.reduce(0.0, +) / Double(metrics.roiMetrics.count)
            return Float(avgMoisture)
        case .pores:
            if let poreAnalysis = metrics.poreAnalysis {
                return (100.0 - poreAnalysis.visibilityScore) / 100.0
            }
            return (100.0 - metrics.globalRoughnessScore) / 100.0
        case .pigmentation:
            return metrics.globalPigmentationIndex
        case .discoloration:
            return metrics.globalDiscolorationIndex
        case .specular:
            return metrics.globalSpecularProxy ?? 0
        case .luminance:
            return metrics.globalAverageLuminance / 255.0
        case .brightness:
            if let glowAnalysis = metrics.glowAnalysis {
                return glowAnalysis.radianceScore / 100.0
            }
            return metrics.globalAverageLuminance / 255.0
        }
    }
}
