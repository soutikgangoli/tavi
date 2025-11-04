//
//  HeadspaceDesignSystem.swift
//  Tavi
//
//  Headspace-inspired design system: Clean, calm, modern
//  Created on 2025-01-03
//

import SwiftUI

/// Headspace-inspired design system with calming colors and smooth animations
public struct HeadspaceDesign {

    // MARK: - Colors

    /// Primary brand colors - professional and calming
    public struct Colors {
        // Primary palette - warm, inviting tones (from real Headspace)
        public static let primary = Color(red: 242/255, green: 118/255, blue: 74/255) // Warm orange
        public static let secondary = Color(red: 95/255, green: 111/255, blue: 230/255) // Royal blue
        public static let accent = Color(red: 252/255, green: 188/255, blue: 78/255) // Warm yellow

        // Success and positive
        public static let success = Color(red: 101/255, green: 188/255, blue: 126/255) // Soft green

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

        // Gradients - subtle and warm
        public static let warmGradient = LinearGradient(
            colors: [
                Color(red: 255/255, green: 199/255, blue: 95/255),
                Color(red: 252/255, green: 163/255, blue: 84/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        public static let peachGradient = LinearGradient(
            colors: [
                Color(red: 255/255, green: 184/255, blue: 140/255),
                Color(red: 255/255, green: 149/255, blue: 119/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        public static let coolGradient = LinearGradient(
            colors: [
                Color(red: 142/255, green: 158/255, blue: 255/255),
                Color(red: 118/255, green: 135/255, blue: 240/255)
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

    public struct Typography {
        // Font definitions
        public static let bodyMedium = Font.system(size: 16, weight: .medium, design: .rounded)

        // Headings - rounded, friendly
        public static func hero(_ text: String) -> some View {
            Text(text)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(Colors.textPrimary)
        }

        public static func title(_ text: String) -> some View {
            Text(text)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Colors.textPrimary)
        }

        public static func headline(_ text: String) -> some View {
            Text(text)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(Colors.textPrimary)
        }

        public static func body(_ text: String) -> some View {
            Text(text)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Colors.textSecondary)
        }

        public static func caption(_ text: String) -> some View {
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
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
                        .font(.system(size: 24, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md)
                    .fill(HeadspaceDesign.Colors.sunriseGradient)
            )
            .shadow(
                color: HeadspaceDesign.Colors.primary.opacity(0.3),
                radius: isPressed ? 8 : 15,
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
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))

                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(HeadspaceDesign.Colors.sunriseGradient)
                        .shadow(
                            color: HeadspaceDesign.Colors.primary.opacity(0.4),
                            radius: isPressed ? 12 : 20,
                            x: 0,
                            y: isPressed ? 6 : 10
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
            .padding(.bottom, 32)
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
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }
}
