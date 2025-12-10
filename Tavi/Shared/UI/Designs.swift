//
//  Designs.swift
//  Tavi
//
//  Unified design system - Ultrahuman-inspired dark theme
//  Clean, modern health-tech aesthetic with deep dark backgrounds
//  Change design tokens here to update the entire app.
//  Created on 2025-01-10.
//

import SwiftUI

/// Unified design system - the single source of truth for all design tokens
/// Ultrahuman-inspired dark theme: deep backgrounds, subtle cards, clean typography
public enum Designs {

    // MARK: - Colors

    public enum Colors {

        // MARK: Brand Colors

        /// Primary brand color - Cyan/Teal (Ultrahuman-style accent)
        public static let primary = Color(red: 0/255, green: 212/255, blue: 255/255) // Bright cyan

        /// Secondary brand color - Deep charcoal for cards
        public static let secondary = Color(red: 28/255, green: 28/255, blue: 30/255)

        /// Accent color - Warm gold for highlights
        public static let accent = Color(red: 255/255, green: 199/255, blue: 0/255)

        /// Teal accent (for CTAs and interactive elements)
        public static let teal = Color(red: 0/255, green: 212/255, blue: 255/255)

        // MARK: Semantic Colors

        /// Success state - Vibrant green
        public static let success = Color(red: 48/255, green: 209/255, blue: 88/255)

        /// Warning state - Warm orange
        public static let warning = Color(red: 255/255, green: 159/255, blue: 10/255)

        /// Error state - Bright red
        public static let error = Color(red: 255/255, green: 69/255, blue: 58/255)

        /// Info state - Blue
        public static let info = Color(red: 10/255, green: 132/255, blue: 255/255)

        // MARK: Dark Theme Colors (Ultrahuman-inspired)

        /// Background - primary (deep black)
        public static let background = Color(red: 0/255, green: 0/255, blue: 0/255)

        /// Background - secondary (slightly lighter)
        public static let backgroundSecondary = Color(red: 18/255, green: 18/255, blue: 18/255)

        /// Background - tertiary (card level)
        public static let backgroundTertiary = Color(red: 28/255, green: 28/255, blue: 30/255)

        /// Card background - subtle dark gray
        public static let cardBackground = Color(red: 28/255, green: 28/255, blue: 30/255)

        /// Elevated card background - slightly lighter
        public static let cardElevated = Color(red: 44/255, green: 44/255, blue: 46/255)

        /// Alias for cardElevated (backward compatibility)
        public static let elevatedCard = cardElevated

        /// Border/separator - subtle
        public static let border = Color(red: 56/255, green: 56/255, blue: 58/255)

        // MARK: Text Colors (Dark Theme)

        /// Primary text - white
        public static let textPrimary = Color.white

        /// Secondary text - light gray
        public static let textSecondary = Color(red: 174/255, green: 174/255, blue: 178/255)

        /// Tertiary text - darker gray
        public static let textTertiary = Color(red: 99/255, green: 99/255, blue: 102/255)

        // MARK: Overlay Colors

        /// Dark overlay (50% opacity)
        public static let overlay = Color.black.opacity(0.5)

        /// Light overlay (30% opacity)
        public static let overlayLight = Color.white.opacity(0.1)

        // MARK: Card Accent Colors

        /// Cyan card accent (primary)
        public static let cardYellow = Color(red: 0/255, green: 212/255, blue: 255/255)

        /// White card (now dark in dark theme)
        public static let cardWhite = Color(red: 44/255, green: 44/255, blue: 46/255)

        /// Gray card
        public static let cardGray = Color(red: 28/255, green: 28/255, blue: 30/255)

        /// Dark card
        public static let cardDark = Color(red: 18/255, green: 18/255, blue: 18/255)

        // MARK: Gradients (Ultrahuman-style - subtle, sophisticated)

        /// Cyan gradient (primary)
        public static let sunriseGradient = LinearGradient(
            colors: [
                Color(red: 0/255, green: 212/255, blue: 255/255),
                Color(red: 0/255, green: 150/255, blue: 200/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Warm gold gradient
        public static let warmGradient = LinearGradient(
            colors: [
                Color(red: 255/255, green: 199/255, blue: 0/255),
                Color(red: 255/255, green: 149/255, blue: 0/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Green gradient (for health/success)
        public static let mintGradient = LinearGradient(
            colors: [
                Color(red: 48/255, green: 209/255, blue: 88/255),
                Color(red: 30/255, green: 160/255, blue: 70/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Cool gradient (cyan)
        public static let coolGradient = LinearGradient(
            colors: [primary, primary.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Neutral gradient (dark gray)
        public static let neutralGradient = LinearGradient(
            colors: [cardBackground, cardBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Peach gradient (alias for warmGradient)
        public static let peachGradient = warmGradient

        // MARK: Metric Gradient Colors (Ultrahuman-style - vibrant on dark)

        /// Overall/Smoothness metric gradient (cyan tones)
        public static let metricOverallGradient = LinearGradient(
            colors: [
                Color(red: 0/255, green: 212/255, blue: 255/255),
                Color(red: 48/255, green: 209/255, blue: 88/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Hydration metric gradient (blue tones)
        public static let metricHydrationGradient = LinearGradient(
            colors: [
                Color(red: 10/255, green: 132/255, blue: 255/255),
                Color(red: 90/255, green: 200/255, blue: 250/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Pigmentation metric gradient (gold tones)
        public static let metricPigmentationGradient = LinearGradient(
            colors: [
                Color(red: 255/255, green: 199/255, blue: 0/255),
                Color(red: 255/255, green: 149/255, blue: 0/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Wrinkles metric gradient (purple tones)
        public static let metricWrinklesGradient = LinearGradient(
            colors: [
                Color(red: 191/255, green: 90/255, blue: 242/255),
                Color(red: 148/255, green: 55/255, blue: 255/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Elasticity metric gradient (orange tones)
        public static let metricElasticityGradient = LinearGradient(
            colors: [
                Color(red: 255/255, green: 159/255, blue: 10/255),
                Color(red: 255/255, green: 69/255, blue: 58/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Volume metric gradient (cyan tones)
        public static let metricVolumeGradient = LinearGradient(
            colors: [
                Color(red: 100/255, green: 210/255, blue: 255/255),
                Color(red: 50/255, green: 173/255, blue: 230/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // MARK: Metric Color Arrays (for use in charts and gradients)

        /// Overall/Smoothness metric colors
        public static let metricOverallColors: [Color] = [
            Color(red: 0/255, green: 212/255, blue: 255/255),
            Color(red: 48/255, green: 209/255, blue: 88/255)
        ]

        /// Hydration metric colors
        public static let metricHydrationColors: [Color] = [
            Color(red: 10/255, green: 132/255, blue: 255/255),
            Color(red: 90/255, green: 200/255, blue: 250/255)
        ]

        /// Pigmentation metric colors
        public static let metricPigmentationColors: [Color] = [
            Color(red: 255/255, green: 199/255, blue: 0/255),
            Color(red: 255/255, green: 149/255, blue: 0/255)
        ]

        /// Wrinkles metric colors
        public static let metricWrinklesColors: [Color] = [
            Color(red: 191/255, green: 90/255, blue: 242/255),
            Color(red: 148/255, green: 55/255, blue: 255/255)
        ]

        /// Elasticity metric colors
        public static let metricElasticityColors: [Color] = [
            Color(red: 255/255, green: 159/255, blue: 10/255),
            Color(red: 255/255, green: 69/255, blue: 58/255)
        ]

        /// Volume metric colors
        public static let metricVolumeColors: [Color] = [
            Color(red: 100/255, green: 210/255, blue: 255/255),
            Color(red: 50/255, green: 173/255, blue: 230/255)
        ]

        // MARK: Score Colors

        /// Returns color for score (0-100)
        public static func scoreColor(for score: Int) -> Color {
            switch score {
            case 90...100: return ScoreColors.excellent
            case 80..<90: return ScoreColors.good
            case 50..<80: return ScoreColors.fair
            case 30..<50: return ScoreColors.warning
            default: return ScoreColors.poor
            }
        }
    }

    // MARK: - Gentler Streak Colors (Warm, friendly theme for home/onboarding)

    public enum GentlerStreak {
        /// Warm cream background
        public static let background = Color(red: 252/255, green: 250/255, blue: 245/255)

        /// Soft warm gray for primary text
        public static let textPrimary = Color(red: 60/255, green: 60/255, blue: 60/255)

        /// Soft warm gray for secondary text
        public static let textSecondary = Color(red: 120/255, green: 115/255, blue: 110/255)

        /// Coral/orange accent
        public static let accentCoral = Color(red: 235/255, green: 120/255, blue: 90/255)

        /// Soft teal accent
        public static let accentTeal = Color(red: 75/255, green: 160/255, blue: 150/255)

        /// Soft green for good scores
        public static let softGreen = Color(red: 130/255, green: 190/255, blue: 140/255)

        /// Soft red/coral for lower scores
        public static let softRed = Color(red: 220/255, green: 100/255, blue: 100/255)

        /// Soft yellow for medium scores
        public static let softYellow = Color(red: 240/255, green: 190/255, blue: 80/255)

        /// Card background (white)
        public static let cardBackground = Color.white

        /// Progress bar track
        public static let progressTrack = Color(red: 230/255, green: 228/255, blue: 223/255)
    }

    // MARK: - Score Colors (Ultrahuman-style - vibrant on dark)

    public enum ScoreColors {
        /// Excellent (90-100) - Bright green
        public static let excellent = Color(red: 48/255, green: 209/255, blue: 88/255)

        /// Good (80-89) - Cyan
        public static let good = Color(red: 0/255, green: 212/255, blue: 255/255)

        /// Fair (50-79) - Yellow
        public static let fair = Color(red: 255/255, green: 214/255, blue: 10/255)

        /// Warning (30-49) - Orange
        public static let warning = Color(red: 255/255, green: 159/255, blue: 10/255)

        /// Poor (0-29) - Red
        public static let poor = Color(red: 255/255, green: 69/255, blue: 58/255)

        /// Graph cyan light
        public static let graphBlueLight = Color(red: 0/255, green: 212/255, blue: 255/255)

        /// Graph cyan dark
        public static let graphBlueDark = Color(red: 0/255, green: 150/255, blue: 200/255)

        /// Achievement green
        public static let achievementGreen = Color(red: 48/255, green: 209/255, blue: 88/255)

        /// Achievement green background (darker for dark theme)
        public static let achievementGreenBackground = Color(red: 48/255, green: 209/255, blue: 88/255).opacity(0.2)

        /// Pink accent
        public static let pinkAccent = Color(red: 255/255, green: 55/255, blue: 95/255)

        /// Returns the appropriate color for a given score
        public static func color(for score: Int) -> Color {
            switch score {
            case 90...100: return excellent
            case 80..<90: return good
            case 50..<80: return fair
            case 30..<50: return warning
            default: return poor
            }
        }
    }

    // MARK: - Status Indicator Colors (Ultrahuman-style)

    public enum Status {
        /// Status indicator - active/good (green)
        public static let active = Color(red: 48/255, green: 209/255, blue: 88/255)

        /// Status indicator - warning (yellow)
        public static let warning = Color(red: 255/255, green: 214/255, blue: 10/255)

        /// Status indicator - inactive/neutral (gray)
        public static let inactive = Color(red: 99/255, green: 99/255, blue: 102/255)

        /// Status indicator - error (red)
        public static let error = Color(red: 255/255, green: 69/255, blue: 58/255)
    }

    // MARK: - Opacity

    public enum Opacity {
        /// Very light opacity (0.1)
        public static let veryLight: Double = 0.1
        
        /// Light opacity (0.2)
        public static let light: Double = 0.2
        
        /// Medium opacity (0.3)
        public static let medium: Double = 0.3
        
        /// Semi-opaque (0.5)
        public static let semiOpaque: Double = 0.5
        
        /// Semi-transparent (0.7)
        public static let semiTransparent: Double = 0.7
        
        /// Almost opaque (0.9)
        public static let almostOpaque: Double = 0.9
        
        /// Almost transparent (0.95)
        public static let almostTransparent: Double = 0.95
    }

    // MARK: - Typography

    /// Typography is now centralized in AppFont.swift
    /// Use AppFont directly or these aliases for consistency
    public enum Typography {
        public static let displayLarge = AppFont.displayLarge
        public static let scoreDisplay = AppFont.scoreDisplay
        public static let scoreMedium = AppFont.scoreMedium
        public static let scoreSmall = AppFont.scoreSmall
        public static let pageTitle = AppFont.pageTitle
        public static let sectionHeader = AppFont.sectionHeader
        public static let cardTitle = AppFont.cardTitle
        public static let bodyPrimary = AppFont.bodyPrimary
        public static let bodyMedium = AppFont.bodyMedium
        public static let bodySecondary = AppFont.bodySecondary
        public static let caption = AppFont.caption
        public static let captionSmall = AppFont.captionSmall
        public static let label = AppFont.label
        public static let button = AppFont.button
        public static let tabBar = AppFont.tabBar

        // Standard SwiftUI-like aliases
        public static let largeTitle = AppFont.largeTitle
        public static let title = AppFont.title
        public static let title2 = AppFont.title2
        public static let title3 = AppFont.title3
        public static let headline = AppFont.headline
        public static let body = AppFont.body
        public static let callout = AppFont.callout
        public static let subheadline = AppFont.subheadline
        public static let footnote = AppFont.footnote
        public static let caption2 = AppFont.custom(size: 11, weight: .regular)
    }

    // MARK: - Spacing

    public enum Spacing {
        public static let xxxSmall: CGFloat = 2
        public static let xxSmall: CGFloat = 4
        public static let tiny: CGFloat = 6
        public static let xSmall: CGFloat = 8
        public static let small: CGFloat = 12
        public static let medium: CGFloat = 16
        public static let large: CGFloat = 20
        public static let xLarge: CGFloat = 24
        public static let xxLarge: CGFloat = 32
        public static let xxxLarge: CGFloat = 40

        // Short aliases (Headspace style)
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
        public static let xxxl: CGFloat = 40
    }

    // MARK: - Corner Radius

    public enum Radius {
        public static let xxSmall: CGFloat = 2
        public static let xSmall: CGFloat = 4
        public static let tiny: CGFloat = 6
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let xLarge: CGFloat = 20
        public static let xxLarge: CGFloat = 24
        public static let pill: CGFloat = 100

        // Short aliases
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
    }

    // Backward compatibility
    public typealias CornerRadius = Radius

    // MARK: - Sizes

    public enum Sizes {
        /// Standard button height
        public static let buttonHeight: CGFloat = 56

        /// Icon sizes
        public static let iconSmall: CGFloat = 24
        public static let iconMedium: CGFloat = 44
        public static let iconLarge: CGFloat = 56

        /// Achievement icon size
        public static let achievementIcon: CGFloat = 120

        /// Graph/chart heights
        public static let graphHeight: CGFloat = 220
        public static let graphBarHeight: CGFloat = 40

        /// Tab bar icon size
        public static let tabBarIcon: CGFloat = 56

        /// Profile icon size
        public static let profileIcon: CGFloat = 80

        /// Metric display sizes
        public static let metricIcon: CGFloat = 44
        public static let metricChart: CGFloat = 200
        public static let metricChartSmall: CGFloat = 180

        /// Progress indicator sizes
        public static let progressIndicator: CGFloat = 8
        public static let progressIndicatorSmall: CGFloat = 4

        /// Badge sizes
        public static let badgeSmall: CGFloat = 18
        public static let badgeMedium: CGFloat = 30

        /// Status indicator size
        public static let statusIndicator: CGFloat = 24

        /// Achievement icon sizes
        public static let achievementIconSmall: CGFloat = 70
        public static let achievementIconMedium: CGFloat = 100
        public static let achievementIconLarge: CGFloat = 140

        /// Card icon size
        public static let cardIcon: CGFloat = 48

        /// Metric icon size (already exists as metricIcon, but adding for clarity)
        /// Use metricIcon (44) for standard metric icons

        /// Small icon size (already exists as iconSmall, but adding common variants)
        public static let iconTiny: CGFloat = 20
        public static let iconXSmall: CGFloat = 28

        /// Large score circle (for main score displays)
        public static let scoreCircleLarge: CGFloat = 160

        /// Medium metric ring size
        public static let metricRingMedium: CGFloat = 60

        /// Common frame sizes
        public static let frameSmall: CGFloat = 32
        public static let frameMedium: CGFloat = 40
        public static let frameLarge: CGFloat = 64
        public static let frameXLarge: CGFloat = 80
        public static let frameXXLarge: CGFloat = 100
        public static let frameXXXLarge: CGFloat = 240
        
        /// Tiny indicator sizes
        public static let indicatorTiny: CGFloat = 8
        public static let indicatorSmall: CGFloat = 4
        public static let indicatorXSmall: CGFloat = 12
        public static let indicatorSmallCircle: CGFloat = 16
        public static let indicatorMedium: CGFloat = 20
        public static let indicatorLarge: CGFloat = 30
        public static let indicatorXLarge: CGFloat = 100
        
        /// Large display sizes
        public static let displayLarge: CGFloat = 180
        public static let displayMedium: CGFloat = 120
        public static let displaySmall: CGFloat = 50
        public static let displayHeight: CGFloat = 300
        public static let displayXLarge: CGFloat = 150
        public static let displayHeightMedium: CGFloat = 200
        public static let displayXLarge2: CGFloat = 220
        public static let displayXXLarge: CGFloat = 320
        public static let displayHeightChart: CGFloat = 250
        public static let displayHeightLarge: CGFloat = 260
        public static let displayHeightXLarge: CGFloat = 400
        public static let frameWidthMedium: CGFloat = 110
        public static let frameWidthSmall: CGFloat = 50
        public static let frameWidthTiny: CGFloat = 30
        public static let frameHeightBar: CGFloat = 12
        public static let frameHeightBarSmall: CGFloat = 6
        public static let frameHeightBarTiny: CGFloat = 4
        public static let frameHeightBarXSmall: CGFloat = 1
        public static let frameHeightBarMedium: CGFloat = 20
    }

    // MARK: - Border

    public enum Border {
        /// Standard border width
        public static let width: CGFloat = 1.0

        /// Thick border width
        public static let widthThick: CGFloat = 1.5

        /// Thin border width
        public static let widthThin: CGFloat = 0.5
    }

    // MARK: - Shadows (Dark theme - minimal, sophisticated)

    public enum Shadows {
        /// Card shadow (subtle - dark theme uses minimal shadows)
        public static let card = Shadow(
            color: Color.black.opacity(0.4),
            radius: 8,
            x: 0,
            y: 4
        )

        /// Soft shadow
        public static let soft = Shadow(
            color: Color.black.opacity(0.3),
            radius: 6,
            x: 0,
            y: 2
        )

        /// Button shadow (subtle glow for dark theme)
        public static let button = Shadow(
            color: Color.black.opacity(0.5),
            radius: 12,
            x: 0,
            y: 4
        )

        /// Elevated shadow (for modals, sheets)
        public static let elevated = Shadow(
            color: Color.black.opacity(0.6),
            radius: 16,
            x: 0,
            y: 8
        )

        /// Modal shadow (heaviest)
        public static let modal = Shadow(
            color: Color.black.opacity(0.7),
            radius: 24,
            x: 0,
            y: 10
        )
    }

    public struct Shadow {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat
    }

    // MARK: - Animations

    public enum Animation {
        /// Quick animation (0.2s)
        public static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)

        /// Standard animation (0.3s)
        public static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)

        /// Smooth animation (0.3s) - alias for standard
        public static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)

        /// Slow animation (0.5s)
        public static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)

        /// Gentle spring
        public static let gentle = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.75)

        /// Spring animation
        public static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)

        /// Bouncy spring
        public static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)

        /// Breathing animation (ambient)
        public static let breathe = SwiftUI.Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)

        /// Pulse animation
        public static let pulse = SwiftUI.Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)

        /// Slow pulse
        public static let slowPulse = SwiftUI.Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true)

        /// Linear animation (for progress)
        public static let linear = SwiftUI.Animation.linear(duration: 0.5)

        /// Ease out animation (0.3s) - for exits
        public static let easeOut = SwiftUI.Animation.easeOut(duration: 0.3)

        /// Slow ease out (1.5s) - for celebrations
        public static let slowEaseOut = SwiftUI.Animation.easeOut(duration: 1.5)

        /// Gentle spring with custom parameters
        public static let gentleSpring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
    }

    /// Alias for Animation (backward compatibility)
    public typealias Animations = Animation
}

// MARK: - View Extensions

extension View {
    /// Apply card shadow
    public func cardShadow() -> some View {
        self.shadow(
            color: Designs.Shadows.card.color,
            radius: Designs.Shadows.card.radius,
            x: Designs.Shadows.card.x,
            y: Designs.Shadows.card.y
        )
    }

    /// Apply soft shadow
    public func softShadow() -> some View {
        self.shadow(
            color: Designs.Shadows.soft.color,
            radius: Designs.Shadows.soft.radius,
            x: Designs.Shadows.soft.x,
            y: Designs.Shadows.soft.y
        )
    }

    /// Apply elevated shadow
    public func elevatedShadow() -> some View {
        self.shadow(
            color: Designs.Shadows.elevated.color,
            radius: Designs.Shadows.elevated.radius,
            x: Designs.Shadows.elevated.x,
            y: Designs.Shadows.elevated.y
        )
    }

    /// Apply modal shadow
    public func modalShadow() -> some View {
        self.shadow(
            color: Designs.Shadows.modal.color,
            radius: Designs.Shadows.modal.radius,
            x: Designs.Shadows.modal.x,
            y: Designs.Shadows.modal.y
        )
    }
}

// MARK: - Typealiases for Migration

/// Typealias for migration from DesignSystem
public typealias DesignSystemMigration = Designs

/// Typealias for migration from HeadspaceDesign
public typealias HeadspaceDesignMigration = Designs
