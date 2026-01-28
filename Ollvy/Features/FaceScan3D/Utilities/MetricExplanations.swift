//
//  MetricExplanations.swift
//  Ollvy
//
//  Provides user-friendly explanations for 3D face metrics
//  Created on 2025-10-27.
//

import Foundation

/// Provides explanations and recommendations for metrics
public struct MetricExplanations {

    // MARK: - Overall Score

    public static func overallExplanation(score: Float, interpretation: String) -> String {
        switch interpretation {
        case "Excellent":
            return "Your skin shows excellent quality across all measured characteristics. Continue your current skincare routine."

        case "Very Good":
            return "Your skin quality is very good with minor areas for improvement. Your skincare routine is working well."

        case "Good":
            return "Your skin shows good overall quality. Consider targeting specific concerns highlighted in individual metrics."

        case "Fair":
            return "Your skin shows moderate concerns in some areas. Review individual metrics to identify improvement opportunities."

        case "Poor":
            return "Your skin shows significant concerns across multiple metrics. Consider consulting with a dermatologist."

        case "Very Poor":
            return "Your skin shows substantial concerns. We recommend professional consultation for personalized treatment."

        default:
            return "Skin analysis complete. Review individual metrics for detailed insights."
        }
    }

    // MARK: - Roughness / Smoothness

    public static func roughnessExplanation(score: Float) -> String {
        switch score {
        case 8.0...10.0:
            return "Smooth, even texture with minimal visible texture variation. Excellent skin surface quality."

        case 6.0..<8.0:
            return "Generally smooth with some minor texture variation. Good skin surface quality."

        case 4.0..<6.0:
            return "Moderate texture variation. Consider exfoliating treatments and moisturizing regularly."

        case 2.0..<4.0:
            return "Noticeable texture irregularities. Gentle exfoliation and hydrating products may help."

        default:
            return "Significant texture concerns. Professional treatments like chemical peels or microdermabrasion may benefit."
        }
    }

    public static func roughnessRecommendations(score: Float) -> [String] {
        if score >= 8.0 {
            return [
                "Maintain current routine",
                "Use gentle cleansers",
                "Keep skin hydrated"
            ]
        } else if score >= 6.0 {
            return [
                "Regular exfoliation (1-2x per week)",
                "Hydrating serums",
                "SPF protection daily"
            ]
        } else if score >= 4.0 {
            return [
                "Chemical exfoliants (AHA/BHA)",
                "Retinol products",
                "Deep moisturizing treatments"
            ]
        } else {
            return [
                "Consult a dermatologist",
                "Professional exfoliation treatments",
                "Targeted texture-improving serums"
            ]
        }
    }

    // MARK: - Pigmentation

    public static func pigmentationExplanation(score: Float) -> String {
        switch score {
        case 8.0...10.0:
            return "Very even skin tone with minimal color variation. Excellent pigmentation uniformity."

        case 6.0..<8.0:
            return "Generally even tone with minor variations. Good pigmentation control."

        case 4.0..<6.0:
            return "Moderate pigmentation irregularities. Sun protection and brightening products may help."

        case 2.0..<4.0:
            return "Noticeable pigmentation concerns. Targeted products for dark spots recommended."

        default:
            return "Significant pigmentation irregularities. Professional dermatologist consultation may benefit."
        }
    }

    public static func pigmentationRecommendations(score: Float) -> [String] {
        if score >= 8.0 {
            return [
                "Daily SPF 30+ protection",
                "Maintain current routine",
                "Antioxidant serums (Vitamin C)"
            ]
        } else if score >= 6.0 {
            return [
                "Broad-spectrum SPF 50+",
                "Vitamin C serum",
                "Niacinamide products"
            ]
        } else if score >= 4.0 {
            return [
                "High SPF + reapply regularly",
                "Brightening serums",
                "Retinol for cell turnover",
                "Alpha arbutin or kojic acid"
            ]
        } else {
            return [
                "Consult a dermatologist",
                "Professional treatments (laser, peels)",
                "Professional brightening treatments",
                "Strict sun protection"
            ]
        }
    }

    // MARK: - Discoloration / Uniform Tone

    public static func discolorationExplanation(score: Float) -> String {
        switch score {
        case 8.0...10.0:
            return "Very uniform tone across all facial regions. Excellent color consistency."

        case 6.0..<8.0:
            return "Generally uniform with minor differences between areas. Good overall tone."

        case 4.0..<6.0:
            return "Moderate tone differences between facial regions. Consider evening treatments."

        case 2.0..<4.0:
            return "Noticeable uneven tone across face. Targeted brightening may help balance."

        default:
            return "Significant tone variation between regions. Professional color correction treatments recommended."
        }
    }

    public static func discolorationRecommendations(score: Float) -> [String] {
        if score >= 8.0 {
            return [
                "Continue current skincare",
                "Daily SPF protection",
                "Even product application"
            ]
        } else if score >= 6.0 {
            return [
                "Vitamin C for brightening",
                "Even sunscreen application",
                "Niacinamide for tone balance"
            ]
        } else if score >= 4.0 {
            return [
                "Targeted spot treatments",
                "Color-correcting serums",
                "Professional facial treatments"
            ]
        } else {
            return [
                "Dermatologist consultation",
                "Laser tone correction",
                "Professional medical treatments",
                "IPL (Intense Pulsed Light)"
            ]
        }
    }

    // MARK: - Specular / Matte Finish

    public static func specularExplanation(score: Float) -> String {
        switch score {
        case 8.0...10.0:
            return "Matte finish with minimal shine. Excellent oil control."

        case 6.0..<8.0:
            return "Generally matte with slight shine in some areas. Good oil balance."

        case 4.0..<6.0:
            return "Moderate shine indicates oiliness. Oil-control products may help."

        case 2.0..<4.0:
            return "Noticeable oily areas. Oil-absorbing treatments recommended."

        default:
            return "Significant oiliness detected. Professional sebum control treatments may benefit."
        }
    }

    public static func specularRecommendations(score: Float) -> [String] {
        if score >= 8.0 {
            return [
                "Maintain current routine",
                "Light, non-comedogenic moisturizer",
                "Oil-free SPF"
            ]
        } else if score >= 6.0 {
            return [
                "Mattifying products",
                "Oil-control cleansers",
                "Blotting papers as needed"
            ]
        } else if score >= 4.0 {
            return [
                "Salicylic acid cleanser",
                "Oil-absorbing clay masks",
                "Niacinamide for sebum control",
                "Light, gel-based moisturizers"
            ]
        } else {
            return [
                "Consult a dermatologist",
                "Professional retinoid treatments",
                "Professional oil-control treatments",
                "Consider hormonal factors"
            ]
        }
    }

    // MARK: - Short Summary

    public static func shortSummary(for metricType: String, score: Float) -> String {
        let baseExplanation: String

        switch metricType.lowercased() {
        case "roughness", "smoothness":
            if score >= 7.0 {
                baseExplanation = "Smooth texture"
            } else if score >= 4.0 {
                baseExplanation = "Some texture variation"
            } else {
                baseExplanation = "Rough texture noted"
            }

        case "pigmentation":
            if score >= 7.0 {
                baseExplanation = "Even tone"
            } else if score >= 4.0 {
                baseExplanation = "Minor color variation"
            } else {
                baseExplanation = "Pigmentation concerns"
            }

        case "discoloration", "uniform tone":
            if score >= 7.0 {
                baseExplanation = "Uniform across face"
            } else if score >= 4.0 {
                baseExplanation = "Some area differences"
            } else {
                baseExplanation = "Uneven tone regions"
            }

        case "specular", "matte finish", "oiliness":
            if score >= 7.0 {
                baseExplanation = "Well-balanced oil levels"
            } else if score >= 4.0 {
                baseExplanation = "Moderate shine"
            } else {
                baseExplanation = "Oily areas detected"
            }

        default:
            baseExplanation = "Analysis complete"
        }

        return baseExplanation
    }
}
