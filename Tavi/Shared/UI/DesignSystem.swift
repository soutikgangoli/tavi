//
//  DesignSystem.swift
//  Tavi
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

        /// Status colors
        static let success = Color(red: 0.0, green: 0.7, blue: 0.4) // Green
        static let warning = Color(red: 1.0, green: 0.6, blue: 0.0) // Orange
        static let error = Color(red: 0.9, green: 0.2, blue: 0.2) // Red
        static let info = Color(red: 0.2, green: 0.6, blue: 1.0) // Blue

        /// Overlay colors (adaptive for light/dark mode)
        static let overlay = Color(uiColor: .label).opacity(0.5) // Adapts to dark mode
        static let overlayLight = Color(uiColor: .label).opacity(0.3) // Adapts to dark mode
    }

    // MARK: - Typography

    enum Typography {
        /// Large title (28-34pt, bold)
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)

        /// Title (22-28pt, bold)
        static let title = Font.system(size: 28, weight: .bold, design: .default)

        /// Title 2 (20-24pt, bold)
        static let title2 = Font.system(size: 24, weight: .bold, design: .default)

        /// Title 3 (18-20pt, semibold)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .default)

        /// Headline (16-17pt, semibold)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)

        /// Body (16-17pt, regular)
        static let body = Font.system(size: 17, weight: .regular, design: .default)

        /// Callout (15-16pt, regular)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)

        /// Subheadline (14-15pt, regular)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)

        /// Footnote (12-13pt, regular)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)

        /// Caption (11-12pt, regular)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)

        /// Caption 2 (10-11pt, regular)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    }

    // MARK: - Spacing

    enum Spacing {
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
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 20
        static let xxLarge: CGFloat = 24
    }

    // MARK: - Shadows

    enum Shadow {
        /// Light shadow for cards
        static let card = ShadowStyle(
            color: Color.black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 2
        )

        /// Medium shadow for elevated elements
        static let elevated = ShadowStyle(
            color: Color.black.opacity(0.12),
            radius: 12,
            x: 0,
            y: 4
        )

        /// Heavy shadow for modals
        static let modal = ShadowStyle(
            color: Color.black.opacity(0.2),
            radius: 20,
            x: 0,
            y: 8
        )
    }

    // MARK: - Animation

    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
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

extension View {
    /// Apply card shadow
    func cardShadow() -> some View {
        self.shadow(
            color: DesignSystem.Shadow.card.color,
            radius: DesignSystem.Shadow.card.radius,
            x: DesignSystem.Shadow.card.x,
            y: DesignSystem.Shadow.card.y
        )
    }

    /// Apply elevated shadow
    func elevatedShadow() -> some View {
        self.shadow(
            color: DesignSystem.Shadow.elevated.color,
            radius: DesignSystem.Shadow.elevated.radius,
            x: DesignSystem.Shadow.elevated.x,
            y: DesignSystem.Shadow.elevated.y
        )
    }

    /// Apply modal shadow
    func modalShadow() -> some View {
        self.shadow(
            color: DesignSystem.Shadow.modal.color,
            radius: DesignSystem.Shadow.modal.radius,
            x: DesignSystem.Shadow.modal.x,
            y: DesignSystem.Shadow.modal.y
        )
    }
}

// MARK: - Design System Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
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
            .frame(height: 56)
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
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 60)

            Text(name)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
}
