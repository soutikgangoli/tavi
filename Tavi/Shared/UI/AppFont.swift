//
//  AppFont.swift
//  Tavi
//
//  Centralized font configuration for the entire app.
//  Change the font family here to update fonts throughout the app.
//

import SwiftUI

/// Centralized font configuration - change font family in ONE place
/// To switch fonts later, just update the `fontFamily` and weight mappings below
public enum AppFont {

    // MARK: - Font Family Configuration

    /// The base font family name - change this to switch fonts app-wide
    /// Current: General Sans
    /// To change: Update this value and the weight mappings below
    private static let fontFamily = "GeneralSans"

    // MARK: - Weight Mappings

    /// Maps SwiftUI Font.Weight to the actual font file name suffix
    /// Update these if your new font has different naming conventions
    private static func fontName(for weight: Font.Weight) -> String {
        let suffix: String
        switch weight {
        case .ultraLight, .thin:
            suffix = "Extralight"
        case .light:
            suffix = "Light"
        case .regular:
            suffix = "Regular"
        case .medium:
            suffix = "Medium"
        case .semibold:
            suffix = "Semibold"
        case .bold:
            suffix = "Bold"
        case .heavy, .black:
            suffix = "Bold"  // General Sans doesn't have heavier than Bold
        default:
            suffix = "Regular"
        }
        return "\(fontFamily)-\(suffix)"
    }

    /// Returns italic variant name for the given weight
    private static func italicFontName(for weight: Font.Weight) -> String {
        let suffix: String
        switch weight {
        case .ultraLight, .thin:
            suffix = "ExtralightItalic"
        case .light:
            suffix = "LightItalic"
        case .regular:
            suffix = "Italic"
        case .medium:
            suffix = "MediumItalic"
        case .semibold:
            suffix = "SemiboldItalic"
        case .bold, .heavy, .black:
            suffix = "BoldItalic"
        default:
            suffix = "Italic"
        }
        return "\(fontFamily)-\(suffix)"
    }

    // MARK: - Public Font Accessors

    /// Creates the app font with specified size and weight
    /// - Parameters:
    ///   - size: Font size in points
    ///   - weight: Font weight (default: .regular)
    /// - Returns: Custom font using the app's font family
    public static func custom(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.custom(fontName(for: weight), size: size)
    }

    /// Creates an italic version of the app font
    /// - Parameters:
    ///   - size: Font size in points
    ///   - weight: Font weight (default: .regular)
    /// - Returns: Custom italic font using the app's font family
    public static func italic(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.custom(italicFontName(for: weight), size: size)
    }

    // MARK: - Semantic Font Styles

    /// Extra large display (40pt bold) - for hero sections
    public static let displayLarge = custom(size: 40, weight: .bold)

    /// Large score display (64pt bold) - for main scores
    public static let scoreDisplay = custom(size: 64, weight: .bold)

    /// Medium score (48pt bold)
    public static let scoreMedium = custom(size: 48, weight: .bold)

    /// Small score (32pt bold)
    public static let scoreSmall = custom(size: 32, weight: .bold)

    /// Page title (28pt bold)
    public static let pageTitle = custom(size: 28, weight: .bold)

    /// Large title (34pt bold)
    public static let largeTitle = custom(size: 34, weight: .bold)

    /// Title (28pt bold)
    public static let title = custom(size: 28, weight: .bold)

    /// Title 2 (24pt bold)
    public static let title2 = custom(size: 24, weight: .bold)

    /// Title 3 (20pt semibold)
    public static let title3 = custom(size: 20, weight: .semibold)

    /// Section header (22pt semibold)
    public static let sectionHeader = custom(size: 22, weight: .semibold)

    /// Card title (18pt semibold)
    public static let cardTitle = custom(size: 18, weight: .semibold)

    /// Headline (17pt semibold)
    public static let headline = custom(size: 17, weight: .semibold)

    /// Body primary (16pt regular)
    public static let bodyPrimary = custom(size: 16, weight: .regular)

    /// Body (17pt regular)
    public static let body = custom(size: 17, weight: .regular)

    /// Body medium (16pt medium)
    public static let bodyMedium = custom(size: 16, weight: .medium)

    /// Body secondary (15pt regular)
    public static let bodySecondary = custom(size: 15, weight: .regular)

    /// Callout (16pt regular)
    public static let callout = custom(size: 16, weight: .regular)

    /// Subheadline (15pt regular)
    public static let subheadline = custom(size: 15, weight: .regular)

    /// Caption (14pt medium)
    public static let caption = custom(size: 14, weight: .medium)

    /// Caption small (12pt regular)
    public static let captionSmall = custom(size: 12, weight: .regular)

    /// Footnote (13pt regular)
    public static let footnote = custom(size: 13, weight: .regular)

    /// Label (13pt semibold)
    public static let label = custom(size: 13, weight: .semibold)

    /// Button (17pt semibold)
    public static let button = custom(size: 17, weight: .semibold)

    /// Tab bar (10pt medium)
    public static let tabBar = custom(size: 10, weight: .medium)

    // MARK: - Additional Semantic Styles

    /// Extra large score display (80pt bold) - for celebration screens
    public static let scoreDisplayLarge = custom(size: 80, weight: .bold)

    /// Light display (56pt light) - for special metric displays
    public static let displayLight = custom(size: 56, weight: .light)

    /// Metric value (20pt medium) - for metric numbers
    public static let metricValue = custom(size: 20, weight: .medium)

    /// Metric label (14pt semibold) - for metric labels
    public static let metricLabel = custom(size: 14, weight: .semibold)

    /// Micro text (9pt regular) - for very small labels
    public static let micro = custom(size: 9, weight: .regular)

    /// Micro bold (9pt bold) - for very small emphasized text
    public static let microBold = custom(size: 9, weight: .bold)

    /// Navigation icon (24pt regular) - for nav/tab icons
    public static let navIcon = custom(size: 24, weight: .regular)

    // MARK: - Headline/Subheading Semantic Styles
    
    /// Primary headline (20pt bold) - for main headlines
    public static let headlinePrimary = custom(size: 20, weight: .bold)
    
    /// Secondary headline (18pt semibold) - for secondary headlines
    public static let headlineSecondary = custom(size: 18, weight: .semibold)
    
    /// Primary subheading (16pt semibold) - for primary subheadings
    public static let subheadingPrimary = custom(size: 16, weight: .semibold)
    
    /// Secondary subheading (15pt medium) - for secondary subheadings
    public static let subheadingSecondary = custom(size: 15, weight: .medium)
}

// MARK: - Font Extension for Convenience

extension Font {
    /// Creates the app's custom font with specified size, weight, and optional design
    /// This is the primary way to use fonts throughout the app
    /// - Parameters:
    ///   - size: Font size in points
    ///   - weight: Font weight (default: .regular)
    ///   - design: Font design (default: nil for app's custom font, or use .monospaced, .rounded)
    /// - Note: When design is specified, uses system font with that design instead of custom font
    public static func app(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design? = nil) -> Font {
        if let design = design {
            // When design is specified, use system font with that design
            return .system(size: size, weight: weight, design: design)
        }
        return AppFont.custom(size: size, weight: weight)
    }

    /// Creates an italic version of the app font
    public static func appItalic(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return AppFont.italic(size: size, weight: weight)
    }

    /// Legacy support - maps to app font
    public static func gilroy(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return AppFont.custom(size: size, weight: weight)
    }

    /// Legacy support - maps to app font
    public static func generalSans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return AppFont.custom(size: size, weight: weight)
    }

    /// Score font using app's bold weight
    public static func scoreFont(size: CGFloat) -> Font {
        return AppFont.custom(size: size, weight: .bold)
    }
}
