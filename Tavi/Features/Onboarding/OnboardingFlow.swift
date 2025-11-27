//
//  OnboardingFlow.swift
//  Tavi
//
//  First-time user onboarding with tutorial screens
//  Explains metrics and scan process
//

import SwiftUI

/// Onboarding flow coordinator
public struct OnboardingFlowView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var currentPage: Int = 0
    @State private var userName: String = ""

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "What's Your Name?",
            description: "Let's personalize your experience",
            imageName: "person.circle.fill",
            color: .blue,
            requiresInput: true
        ),
        OnboardingPage(
            title: "3D Face Scan in 1 Minute",
            description: "We'll guide you through five quick poses to capture your face in 3D.\n\n• Clinical-grade AI skin analysis\n• Track changes over time\n• 100% on-device privacy\n\nLet's begin.",
            imageName: "face.smiling",
            color: .blue
        )
    ]

    public var body: some View {
        VStack {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    // Skip tutorial, but still save name if entered
                    if !userName.isEmpty {
                        try? UserProfileManager.shared.updateName(userName)
                    }
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    dismiss()
                }
                .foregroundColor(.gray)
                .padding(.top, 20)
                .padding(.trailing, 20)
            }

            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 10)

            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    if pages[index].requiresInput {
                        OnboardingPageView(page: pages[index], userName: $userName)
                            .tag(index)
                    } else {
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Action buttons
            HStack(spacing: 20) {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .foregroundColor(.gray)
                }

                Spacer()

                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .fontWeight(.semibold)
                } else {
                    Button("Get Started") {
                        // Save user name to profile
                        if !userName.isEmpty {
                            try? UserProfileManager.shared.updateName(userName)
                        }

                        // Mark onboarding as complete
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(25)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }
}

/// Single onboarding page
struct OnboardingPageView: View {
    let page: OnboardingPage
    @Binding var userName: String

    init(page: OnboardingPage, userName: Binding<String> = .constant("")) {
        self.page = page
        self._userName = userName
    }

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Icon
            Image(systemName: page.imageName)
                .font(.system(size: 80))
                .foregroundColor(page.color)

            // Title
            Text(page.title)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)

            // Description
            Text(page.description)
                .font(.system(size: 18))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Input field for name if required
            if page.requiresInput {
                TextField("Enter your name", text: $userName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 18))
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
            }

            Spacer()
        }
    }
}

/// Onboarding page data
struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let color: Color
    let requiresInput: Bool

    init(title: String, description: String, imageName: String, color: Color, requiresInput: Bool = false) {
        self.title = title
        self.description = description
        self.imageName = imageName
        self.color = color
        self.requiresInput = requiresInput
    }
}

/// Metric explanation view (detailed)
public struct MetricExplanationView: View {
    let metric: AnalysisMetricType

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: metric.iconName)
                        .font(.system(size: 40))
                        .foregroundColor(metric.color)

                    VStack(alignment: .leading) {
                        Text(metric.name)
                            .font(.title)
                            .bold()

                        Text(metric.tagline)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding()

                Divider()

                // What it is
                SectionView(title: "What It Measures") {
                    Text(metric.whatItMeasures)
                        .font(.body)
                }

                // Why it matters
                SectionView(title: "Why It Matters") {
                    Text(metric.whyItMatters)
                        .font(.body)
                }

                // How we measure it
                SectionView(title: "How We Measure It") {
                    Text(metric.howWeMeasure)
                        .font(.body)
                }

                // What affects it
                SectionView(title: "What Affects This Metric") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(metric.affectingFactors, id: \.self) { factor in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                Text(factor)
                            }
                        }
                    }
                }

                // Tips to improve
                SectionView(title: "How to Improve") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(metric.improvementTips, id: \.self) { tip in
                            HStack(alignment: .top) {
                                Text("•")
                                    .bold()
                                Text(tip)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(metric.name)
    }
}

struct SectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            content
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
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
        case .brightness: return "sun.max.fill"  // Alias for luminance
        }
    }

    var color: Color {
        switch self {
        case .roughness: return .blue
        case .wrinkles: return .purple
        case .hydration: return .cyan
        case .pores: return .green
        case .pigmentation: return .orange
        case .discoloration: return .red
        case .specular: return .yellow
        case .luminance: return .white
        case .brightness: return .white  // Alias for luminance
        }
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
        case .brightness: return "Overall brightness"  // Alias for luminance
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
            return "Even skin tone is a key indicator of skin health. Uneven pigmentation can result from sun damage, hormones, or inflammation."
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
                "Use retinol or prescription retinoids",
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
                "Consider prescription treatments (hydroquinone, tretinoin)",
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
    case brightness  // Alias for luminance

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

    /// Get the metric value from ROI metrics
    func getValue(from roiMetrics: ROI3DMetrics) -> Float {
        switch self {
        case .roughness: return roiMetrics.roughnessProxy
        case .wrinkles: return roiMetrics.roughnessProxy // Use roughness as proxy for wrinkles
        case .hydration: return 1.0 - roiMetrics.pigmentationIndex // Use inverse pigmentation as hydration proxy
        case .pores: return roiMetrics.roughnessProxy // Use roughness as proxy for pores
        case .pigmentation: return roiMetrics.pigmentationIndex
        case .discoloration: return roiMetrics.pigmentationIndex // Use pigmentation as discoloration proxy
        case .specular: return roiMetrics.specularProxy ?? 0
        case .luminance: return roiMetrics.pigmentationIndex // Use pigmentation as luminance proxy
        case .brightness: return roiMetrics.pigmentationIndex // Same as luminance
        }
    }
}
