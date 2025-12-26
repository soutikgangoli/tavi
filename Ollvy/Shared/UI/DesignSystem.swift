//
//  DesignSystem.swift
//  Ollvy
//
//  Created on 2025-10-27.
//  Airbnb/Uber-inspired design system
//

import SwiftUI

/// Central design system following Airbnb/Uber design principles
/// - Neutral white/gray backgrounds
/// - Bold black headlines, medium-gray body text
/// - Single accent color for CTAs
/// - Rounded cards with shadows
/// - Flat, trustworthy feel (no gradients, no loud hues)
/// 
/// @available(*, deprecated, message: "Use Designs instead. This system is being phased out in favor of the unified Designs system.")
enum DesignSystem {

    // MARK: - Colors

    enum Colors {
        /// Primary accent color for CTAs and interactive elements
        static let accent = Color(red: 0.0, green: 0.48, blue: 0.64) // Teal blue #007BA3

        /// Alternative accent for secondary actions
        static let accentSecondary = Color(red: 0.0, green: 0.58, blue: 0.74) // Lighter teal

        /// Text colors (adaptive for light/dark mode)
        static let textPrimary = Color(uiColor: .label) // Adapts to dark mode
        static let textSecondary = Color(uiColor: .secondaryLabel) // Adapts to dark mode
        static let textTertiary = Color(uiColor: .tertiaryLabel) // Adapts to dark mode

        /// Background colors (adaptive for light/dark mode)
        static let backgroundPrimary = Color(uiColor: .systemBackground) // Adapts to dark mode
        static let backgroundSecondary = Color(uiColor: .secondarySystemBackground) // Adapts to dark mode
        static let backgroundTertiary = Color(uiColor: .tertiarySystemBackground) // Adapts to dark mode

        /// Card colors (adaptive for light/dark mode)
        static let cardBackground = Color(uiColor: .secondarySystemBackground) // Adapts to dark mode
        static let cardBorder = Color(uiColor: .separator) // Adapts to dark mode

        /// Status colors (professional, muted tones that work in both modes)
        static let success = Color(red: 0.0, green: 0.7, blue: 0.4) // Green
        static let warning = Color(red: 1.0, green: 0.6, blue: 0.0) // Orange
        static let error = Color(red: 0.9, green: 0.2, blue: 0.2) // Red
        static let info = Color(red: 0.2, green: 0.6, blue: 1.0) // Blue

        /// Score-based colors (adaptive and professional)
        /// These automatically adjust for dark mode via UIColor
        /// - Below 30: Red (poor)
        /// - 30-70: Yellow (fair)
        /// - 70-89: Green (good)
        /// - 90-100: Bright green (excellent)
        static func scoreColor(for score: Int) -> Color {
            switch score {
            case 90...100: return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
                ? UIColor(red: 0.18, green: 0.82, blue: 0.35, alpha: 1.0)  // Bright green for dark
                : UIColor(red: 0.0, green: 0.75, blue: 0.3, alpha: 1.0)   // Bright green for light
            })
            case 70..<90: return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
                ? UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)  // Green for dark
                : UIColor(red: 0.0, green: 0.65, blue: 0.3, alpha: 1.0) // Green for light
            })
            case 30..<70: return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
                ? UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)  // Brighter yellow for dark
                : UIColor(red: 0.85, green: 0.65, blue: 0.0, alpha: 1.0) // Darker yellow for light
            })
            default: return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
                ? UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0)   // Brighter red for dark
                : UIColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1.0)  // Darker red for light
            })
            }
        }

        /// Overlay colors (adaptive for light/dark mode)
        static let overlay = Color(uiColor: .label).opacity(Designs.Opacity.semiOpaque) // Adapts to dark mode
        static let overlayLight = Color(uiColor: .label).opacity(Designs.Opacity.medium) // Adapts to dark mode
    }

    // MARK: - Typography
    // Uses AppFont for centralized font management
    // To change fonts app-wide, update AppFont.swift

    enum Typography {
        /// Large title (28-34pt, bold)
        static let largeTitle = AppFont.largeTitle

        /// Title (22-28pt, bold)
        static let title = AppFont.title

        /// Title 2 (20-24pt, bold)
        static let title2 = AppFont.title2

        /// Title 3 (18-20pt, semibold)
        static let title3 = AppFont.title3

        /// Headline (16-17pt, semibold)
        static let headline = AppFont.headline

        /// Body (16-17pt, regular)
        static let body = AppFont.body

        /// Callout (15-16pt, regular)
        static let callout = AppFont.callout

        /// Subheadline (14-15pt, regular)
        static let subheadline = AppFont.subheadline

        /// Footnote (12-13pt, regular)
        static let footnote = AppFont.footnote

        /// Caption (11-12pt, regular)
        static let caption = AppFont.captionSmall

        /// Caption 2 (10-11pt, regular)
        static let caption2 = AppFont.custom(size: 11, weight: .regular)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxxSmall: CGFloat = 2
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
        static let xxxLarge: CGFloat = 40
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let xxSmall: CGFloat = 2
        static let xSmall: CGFloat = 4
        static let tiny: CGFloat = 6
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 20
        static let xxLarge: CGFloat = 24
    }

    // MARK: - Score Colors (for metrics and achievements)

    enum ScoreColors {
        /// Excellent score (90-100) - Bright green
        static let excellent = Color(red: 76/255, green: 217/255, blue: 100/255)

        /// Good score (80-89) - Light green
        static let good = Color(red: 101/255, green: 188/255, blue: 126/255)

        /// Fair score (50-79) - Pale green
        static let fair = Color(red: 149/255, green: 218/255, blue: 176/255)

        /// Warning score (30-49) - Yellow
        static let warning = Color(red: 255/255, green: 204/255, blue: 0/255)

        /// Poor score (0-29) - Red
        static let poor = Color(red: 255/255, green: 59/255, blue: 48/255)

        /// Returns the appropriate color for a given score
        /// - Below 30: Red (poor)
        /// - 30-70: Yellow (fair/warning)
        /// - 70-89: Green (good)
        /// - 90-100: Bright green (excellent)
        static func color(for score: Int) -> Color {
            switch score {
            case 90...100: return excellent  // Bright green
            case 70..<90: return good        // Green
            case 30..<70: return warning     // Yellow
            default: return poor             // Red (below 30)
            }
        }

        // Graph colors
        static let graphBlueLight = Color(red: 99/255, green: 179/255, blue: 237/255)
        static let graphBlueDark = Color(red: 56/255, green: 149/255, blue: 211/255)

        // Achievement colors
        static let achievementGreen = Color(red: 0.3, green: 0.8, blue: 0.5)
        static let achievementGreenBackground = Color(red: 0.6, green: 0.9, blue: 0.7)

        // Pink accent (for special features)
        static let pinkAccent = Color(red: 255/255, green: 159/255, blue: 243/255)
    }

    // MARK: - Shadows

    enum Shadow {
        /// Light shadow for cards
        static let card = ShadowStyle(
            color: Color.black.opacity(Designs.Opacity.veryLight - 0.02),
            radius: Designs.Spacing.small,
            x: 0,
            y: Designs.Border.widthThick
        )

        /// Medium shadow for elevated elements
        static let elevated = ShadowStyle(
            color: Color.black.opacity(Designs.Opacity.veryLight + 0.02),
            radius: Designs.Spacing.small + 4,
            x: 0,
            y: Designs.Spacing.xxSmall
        )

        /// Heavy shadow for modals
        static let modal = ShadowStyle(
            color: Color.black.opacity(Designs.Opacity.light),
            radius: Designs.Radius.xLarge,
            x: 0,
            y: Designs.Spacing.small
        )
    }

    // MARK: - Animation

    enum Animation {
        /// Quick animation (0.2s) - for micro-interactions
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)

        /// Standard animation (0.3s) - default for most transitions
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)

        /// Slow animation (0.5s) - for larger transitions
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)

        /// Spring animation - bouncy feedback
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)

        /// Gentle spring - softer bounce
        static let gentle = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)

        /// Bouncy spring - more playful
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)

        /// Breathing animation - slow in/out for ambient effects
        static let breathe = SwiftUI.Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)

        /// Pulse animation - faster rhythm
        static let pulse = SwiftUI.Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)

        /// Slow pulse - very slow ambient pulse
        static let slowPulse = SwiftUI.Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true)

        /// Linear animation (0.5s) - for progress indicators
        static let linear = SwiftUI.Animation.linear(duration: 0.5)
    }
}

// MARK: - Shadow Style Helper

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions
// Note: cardShadow(), elevatedShadow(), modalShadow() are now defined in Designs.swift

// MARK: - Design System Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: Designs.Sizes.buttonHeight)
            .background(
                isEnabled
                    ? DesignSystem.Colors.accent
                    : DesignSystem.Colors.textTertiary
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundColor(isEnabled ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: Designs.Sizes.buttonHeight)
            .background(DesignSystem.Colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(isEnabled ? DesignSystem.Colors.accent : DesignSystem.Colors.cardBorder, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Design System Colors") {
    ScrollView {
        VStack(spacing: DesignSystem.Spacing.large) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text("Colors")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.small) {
                    ColorSwatch(color: DesignSystem.Colors.accent, name: "Accent")
                    ColorSwatch(color: DesignSystem.Colors.success, name: "Success")
                    ColorSwatch(color: DesignSystem.Colors.warning, name: "Warning")
                    ColorSwatch(color: DesignSystem.Colors.error, name: "Error")
                }
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text("Typography")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Large Title")
                    .font(DesignSystem.Typography.largeTitle)
                Text("Title")
                    .font(DesignSystem.Typography.title)
                Text("Headline")
                    .font(DesignSystem.Typography.headline)
                Text("Body")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text("Caption")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }

            VStack(spacing: DesignSystem.Spacing.medium) {
                Button("Primary Button") {}
                    .buttonStyle(PrimaryButtonStyle())

                Button("Secondary Button") {}
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(DesignSystem.Spacing.large)
    }
    .background(DesignSystem.Colors.backgroundSecondary)
}

struct ColorSwatch: View {
    let color: Color
    let name: String

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: Designs.Radius.small)
                .fill(color)
                .frame(height: Designs.Sizes.frameMedium + 20)

            Text(name)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
}
