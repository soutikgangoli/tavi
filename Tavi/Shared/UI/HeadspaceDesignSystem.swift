//
//  HeadspaceDesignSystem.swift
//  Tavi
//
//  Headspace-inspired design system: Clean, calm, modern
//  Created on 2025-01-03
//

import SwiftUI

/// Headspace-inspired design system with calming colors and smooth animations
/// 
/// @available(*, deprecated, message: "Use Designs instead. This system is being phased out in favor of the unified Designs system.")
public struct HeadspaceDesign {

    // MARK: - Colors

    /// ACTUAL Bumble colors - their real brand palette
    public struct Colors {
        // BUMBLE's ACTUAL brand colors
        public static let primary = Color(red: 255/255, green: 199/255, blue: 0/255) // Bumble Yellow - THE iconic color
        public static let secondary = Color(red: 30/255, green: 30/255, blue: 30/255) // Bumble Dark Gray/Black
        public static let accent = Color(red: 255/255, green: 199/255, blue: 0/255) // Bumble Yellow (same as primary)

        // Success and positive
        public static let success = Color(red: 0/255, green: 201/255, blue: 167/255) // Teal accent

        // Backgrounds - adaptive for light/dark mode
        public static let background = Color(uiColor: .systemBackground) // Adapts to dark mode
        public static let cardBackground = Color(uiColor: .secondarySystemBackground) // Adapts to dark mode
        public static let elevatedCard = Color(uiColor: .tertiarySystemBackground) // Adapts to dark mode

        // Text hierarchy - adaptive for light/dark mode
        public static let textPrimary = Color(uiColor: .label) // Adapts to dark mode
        public static let textSecondary = Color(uiColor: .secondaryLabel) // Adapts to dark mode
        public static let textTertiary = Color(uiColor: .tertiaryLabel) // Adapts to dark mode

        // Border color
        public static let border = Color(uiColor: .separator)

        // Card colors - Bumble style with yellow and neutrals
        public static let cardYellow = Color(red: 255/255, green: 199/255, blue: 0/255) // Bumble Yellow
        public static let cardWhite = Color(red: 255/255, green: 255/255, blue: 255/255) // White cards
        public static let cardGray = Color(red: 246/255, green: 246/255, blue: 246/255) // Light gray
        public static let cardDark = Color(red: 30/255, green: 30/255, blue: 30/255) // Dark accent

        // Solid "gradients" (single color wrapped in LinearGradient for API compatibility)
        public static let peachGradient = LinearGradient(
            colors: [cardGray, cardGray],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        public static let coolGradient = LinearGradient(
            colors: [cardYellow, cardYellow],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Legacy gradients (kept for compatibility)
        public static let warmGradient = LinearGradient(
            colors: [
                Color(red: 255/255, green: 199/255, blue: 95/255),
                Color(red: 252/255, green: 163/255, blue: 84/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        public static let mintGradient = LinearGradient(
            colors: [
                Color(red: 149/255, green: 218/255, blue: 176/255),
                Color(red: 118/255, green: 200/255, blue: 160/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        public static let sunriseGradient = LinearGradient(
            colors: [
                Color(red: 242/255, green: 118/255, blue: 74/255),
                Color(red: 255/255, green: 140/255, blue: 90/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Typography

    /// Clean, minimalistic sans-serif typography system
    /// Uses AppFont for centralized font management
    /// To change fonts app-wide, update AppFont.swift
    public struct Typography {

        // MARK: - Base Font Function

        /// Creates an app font with the specified size and weight
        public static func generalSans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return AppFont.custom(size: size, weight: weight)
        }

        /// Legacy method name for backward compatibility
        public static func gilroy(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return AppFont.custom(size: size, weight: weight)
        }

        // MARK: - Semantic Font Styles

        /// Extra large display text for hero sections (40pt bold)
        public static let displayLarge = AppFont.displayLarge

        /// Large display text for main scores (64pt bold, high contrast)
        public static let scoreDisplay = AppFont.scoreDisplay

        /// Medium score display (48pt bold)
        public static let scoreMedium = AppFont.scoreMedium

        /// Small score display (32pt bold)
        public static let scoreSmall = AppFont.scoreSmall

        /// Page titles (28pt bold)
        public static let pageTitle = AppFont.pageTitle

        /// Section headers (22pt semibold)
        public static let sectionHeader = AppFont.sectionHeader

        /// Card titles (18pt semibold)
        public static let cardTitle = AppFont.cardTitle

        /// Body text - primary (16pt regular)
        public static let bodyPrimary = AppFont.bodyPrimary

        /// Body text - medium weight (16pt medium)
        public static let bodyMedium = AppFont.bodyMedium

        /// Body text - secondary (15pt regular)
        public static let bodySecondary = AppFont.bodySecondary

        /// Caption text (14pt medium)
        public static let caption = AppFont.caption

        /// Small caption text (12pt regular)
        public static let captionSmall = AppFont.captionSmall

        /// Label text (13pt semibold)
        public static let label = AppFont.label

        /// Button text (17pt semibold)
        public static let button = AppFont.button

        /// Tab bar text (10pt medium)
        public static let tabBar = AppFont.tabBar

        // MARK: - Legacy View Builders (for backward compatibility)

        public static func hero(_ text: String) -> some View {
            Text(text)
                .font(AppFont.largeTitle)
                .foregroundColor(Colors.textPrimary)
        }

        public static func title(_ text: String) -> some View {
            Text(text)
                .font(AppFont.title2)
                .foregroundColor(Colors.textPrimary)
        }

        public static func headline(_ text: String) -> some View {
            Text(text)
                .font(AppFont.cardTitle)
                .foregroundColor(Colors.textPrimary)
        }

        public static func body(_ text: String) -> some View {
            Text(text)
                .font(AppFont.bodyPrimary)
                .foregroundColor(Colors.textSecondary)
        }

        public static func caption(_ text: String) -> some View {
            Text(text)
                .font(AppFont.caption)
                .foregroundColor(Colors.textTertiary)
        }
    }

    // MARK: - Spacing (Headspace uses generous spacing)

    public struct Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
        public static let xxxl: CGFloat = 40
    }

    // MARK: - Corner Radius (Headspace uses consistent 16px radius)

    public struct Radius {
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16  // Primary card radius
        public static let xl: CGFloat = 24
        public static let pill: CGFloat = 100
    }

    // Alias for backward compatibility
    public typealias CornerRadius = Radius

    // MARK: - Shadows (Headspace uses very subtle shadows, adaptive for dark mode)

    public struct Shadows {
        public static let card = Shadow(
            color: Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.3)  // Stronger shadow in dark mode
                : UIColor.black.withAlphaComponent(0.04) // Subtle shadow in light mode
            }),
            radius: 8,
            x: 0,
            y: 2
        )

        public static let soft = Shadow(
            color: Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.3)
                : UIColor.black.withAlphaComponent(0.04)
            }),
            radius: 8,
            x: 0,
            y: 2
        )

        public static let button = Shadow(
            color: Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.4)
                : UIColor.black.withAlphaComponent(0.08)
            }),
            radius: 12,
            x: 0,
            y: 4
        )

        public static let elevated = Shadow(
            color: Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.35)
                : UIColor.black.withAlphaComponent(0.06)
            }),
            radius: 16,
            x: 0,
            y: 6
        )
    }

    public struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    // MARK: - Animations

    public struct Animations {
        public static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.75)
        public static let smooth = Animation.easeInOut(duration: 0.3)
        public static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    }
}

// MARK: - Reusable Card Components

/// Headspace-style card with soft shadow and rounded corners
public struct HeadspaceCard<Content: View>: View {
    let content: Content
    let gradient: LinearGradient?

    public init(gradient: LinearGradient? = nil, @ViewBuilder content: () -> Content) {
        self.gradient = gradient
        self.content = content()
    }

    public var body: some View {
        content
            .padding(HeadspaceDesign.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg)
                    .fill(gradient != nil ? AnyShapeStyle(gradient!) : AnyShapeStyle(HeadspaceDesign.Colors.cardBackground))
            )
            .shadow(
                color: HeadspaceDesign.Shadows.soft.color,
                radius: HeadspaceDesign.Shadows.soft.radius,
                x: HeadspaceDesign.Shadows.soft.x,
                y: HeadspaceDesign.Shadows.soft.y
            )
    }
}

/// Headspace-style primary button
public struct HeadspacePrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    @State private var isPressed = false

    public init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: HeadspaceDesign.Spacing.md) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(AppFont.navIcon)
                }

                Text(title)
                    .font(AppFont.button)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, HeadspaceDesign.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md)
                    .fill(HeadspaceDesign.Colors.sunriseGradient)
            )
            .shadow(
                color: HeadspaceDesign.Colors.primary.opacity(0.3),
                radius: isPressed ? 8 : 19,
                x: 0,
                y: isPressed ? 4 : 8
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(HeadspaceDesign.Animations.gentle) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(HeadspaceDesign.Animations.gentle) {
                        isPressed = false
                    }
                }
        )
    }
}

/// Floating sticky button (stays at bottom)
public struct HeadspaceStickyButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var isPressed = false

    public init(title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        VStack {
            Spacer()

            Button(action: action) {
                HStack(spacing: HeadspaceDesign.Spacing.sm) {
                    Image(systemName: icon)
                        .font(AppFont.sectionHeader)

                    Text(title)
                        .font(AppFont.button)
                }
                .foregroundColor(.white)
                .padding(.horizontal, HeadspaceDesign.Spacing.xxl)
                .padding(.vertical, HeadspaceDesign.Spacing.lg)
                .background(
                    Capsule()
                        .fill(HeadspaceDesign.Colors.sunriseGradient)
                        .shadow(
                            color: HeadspaceDesign.Colors.primary.opacity(0.2),
                            radius: isPressed ? 12 : 24,
                            x: 0,
                            y: isPressed ? 8 : 8
                        )
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation(HeadspaceDesign.Animations.bouncy) {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(HeadspaceDesign.Animations.bouncy) {
                            isPressed = false
                        }
                    }
            )
            .padding(.bottom, HeadspaceDesign.Spacing.xxl)
        }
    }
}

/// Soft pill badge
public struct HeadspaceBadge: View {
    let text: String
    let color: Color

    public init(text: String, color: Color = HeadspaceDesign.Colors.primary) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(AppFont.label)
            .foregroundColor(color)
            .padding(.horizontal, HeadspaceDesign.Spacing.sm)
            .padding(.vertical, HeadspaceDesign.Spacing.xs)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }
}

// MARK: - Font Extension
// Note: Main font extensions are now defined in AppFont.swift
// The extensions below are kept for backward compatibility and delegate to AppFont
