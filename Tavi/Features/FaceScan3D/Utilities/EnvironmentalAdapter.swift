//
//  EnvironmentalAdapter.swift
//  Tavi
//
//  Environmental adaptation for different lighting conditions and time of day
//  Ensures consistent metrics across environments
//

import Foundation
import ARKit
import UIKit

/// Environmental conditions
public struct EnvironmentalConditions {
    let lightingType: LightingType
    let brightness: Float  // 0-1
    let colorTemperature: Float  // Kelvin
    let timeOfDay: TimeOfDay
    let isIndoor: Bool
    let ambientOcclusionAvailable: Bool
}

public enum LightingType {
    case natural  // Daylight/window
    case artificial  // Indoor lights
    case mixed
    case poor  // Too dark/bright
}

public enum TimeOfDay {
    case morning  // 6am-11am
    case midday   // 11am-3pm
    case afternoon  // 3pm-6pm
    case evening  // 6pm-10pm
    case night  // 10pm-6am
}

/// Environmental adapter
public class EnvironmentalAdapter {

    // MARK: - Public API

    /// Analyze current environmental conditions
    public func analyzeEnvironment(frame: ARFrame) -> EnvironmentalConditions {

        // Extract light estimation
        let lightEstimate = frame.lightEstimate

        // Brightness (0-1)
        let brightness = Float(lightEstimate?.ambientIntensity ?? 1000) / 2000.0

        // Color temperature (Kelvin)
        let colorTemp = Float(lightEstimate?.ambientColorTemperature ?? 6500)

        // Classify lighting type
        let lightingType = classifyLighting(
            brightness: brightness,
            colorTemp: colorTemp
        )

        // Determine time of day
        let timeOfDay = determineTimeOfDay()

        // Indoor vs outdoor (heuristic from color temperature)
        let isIndoor = colorTemp < 5500  // Indoor lights are typically warmer

        // Ambient occlusion
        let hasAO = lightEstimate?.ambientIntensity != nil

        return EnvironmentalConditions(
            lightingType: lightingType,
            brightness: min(1.0, max(0.0, brightness)),
            colorTemperature: colorTemp,
            timeOfDay: timeOfDay,
            isIndoor: isIndoor,
            ambientOcclusionAvailable: hasAO
        )
    }

    /// Get adjustment factors for metrics based on environment
    public func getAdjustmentFactors(conditions: EnvironmentalConditions) -> AdjustmentFactors {

        var adjustments = AdjustmentFactors()

        // Brightness adjustments
        if conditions.brightness < 0.3 {
            // Too dark - reduce confidence in all metrics
            adjustments.roughnessConfidence *= 0.7
            adjustments.pigmentationConfidence *= 0.5
            adjustments.poreConfidence *= 0.6
        } else if conditions.brightness > 0.9 {
            // Too bright - reduce confidence
            adjustments.roughnessConfidence *= 0.8
            adjustments.pigmentationConfidence *= 0.7
        }

        // Color temperature adjustments
        if conditions.colorTemperature < 3000 {
            // Very warm light (incandescent) - adjust pigmentation
            adjustments.pigmentationBias = -5  // Subtract 5 from pigmentation score
        } else if conditions.colorTemperature > 7000 {
            // Very cool light (blue-ish) - adjust
            adjustments.pigmentationBias = +5
        }

        // Time of day effects
        switch conditions.timeOfDay {
        case .morning:
            // Skin typically less hydrated in morning
            adjustments.hydrationBias = -3
        case .evening, .night:
            // Fatigue may show
            adjustments.wrinkleBias = +2  // Wrinkles more pronounced
        default:
            break
        }

        // Indoor/outdoor
        if !conditions.isIndoor {
            // Outdoor = more UV exposure risk
            adjustments.pigmentationWarning = "Outdoor scan - SPF protection recommended"
        }

        return adjustments
    }

    /// Get recommendations for optimal scanning
    public func getOptimalConditionsRecommendation(
        current: EnvironmentalConditions
    ) -> String {

        if current.lightingType == .poor {
            return "Lighting is poor. Move to a well-lit area with indirect natural light."
        }

        if current.brightness < 0.3 {
            return "Too dark. Turn on lights or move to a brighter location."
        }

        if current.brightness > 0.9 {
            return "Too bright. Avoid direct sunlight or harsh overhead lights."
        }

        if current.colorTemperature < 3500 {
            return "Warm lighting detected. For best accuracy, use neutral white light (4000-5500K)."
        }

        return "Lighting conditions are good."
    }

    // MARK: - Private Methods

    private func classifyLighting(brightness: Float, colorTemp: Float) -> LightingType {

        // Poor lighting
        if brightness < 0.2 || brightness > 0.95 {
            return .poor
        }

        // Natural daylight (cool, 5500-6500K)
        if colorTemp >= 5500 && colorTemp <= 7000 {
            return .natural
        }

        // Artificial (warm, 2700-4000K)
        if colorTemp >= 2700 && colorTemp <= 4000 {
            return .artificial
        }

        // Mixed
        return .mixed
    }

    private func determineTimeOfDay() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 6..<11:
            return .morning
        case 11..<15:
            return .midday
        case 15..<18:
            return .afternoon
        case 18..<22:
            return .evening
        default:
            return .night
        }
    }
}

/// Adjustment factors for metrics
public struct AdjustmentFactors {
    // Confidence multipliers (0-1)
    var roughnessConfidence: Float = 1.0
    var wrinkleConfidence: Float = 1.0
    var hydrationConfidence: Float = 1.0
    var poreConfidence: Float = 1.0
    var pigmentationConfidence: Float = 1.0

    // Score biases (additive)
    var roughnessBias: Float = 0
    var wrinkleBias: Float = 0
    var hydrationBias: Float = 0
    var poreBias: Float = 0
    var pigmentationBias: Float = 0

    // Warnings
    var pigmentationWarning: String? = nil
}

/// Seasonal adaptation
public struct SeasonalAdapter {

    public static func getSeasonalAdjustments(date: Date = Date()) -> SeasonalAdjustments {
        let month = Calendar.current.component(.month, from: date)

        switch month {
        case 12, 1, 2:  // Winter
            return SeasonalAdjustments(
                season: .winter,
                hydrationFactor: -5,  // Dry air
                recommendations: [
                    "Winter: Use heavier moisturizer",
                    "Indoor heating dries skin - use humidifier",
                    "Don't skip SPF (UV reflects off snow)"
                ]
            )

        case 3, 4, 5:  // Spring
            return SeasonalAdjustments(
                season: .spring,
                pigmentationFactor: +3,  // Sun returning
                recommendations: [
                    "Spring: Increase SPF to SPF 50",
                    "Add vitamin C for brightness",
                    "Great time to address winter damage"
                ]
            )

        case 6, 7, 8:  // Summer
            return SeasonalAdjustments(
                season: .summer,
                hydrationFactor: -3,  // Sweating
                pigmentationFactor: +5,  // Sun exposure
                recommendations: [
                    "Summer: CRITICAL - Reapply SPF every 2 hours",
                    "Stay hydrated (sweating = water loss)",
                    "Consider lighter moisturizer"
                ]
            )

        case 9, 10, 11:  // Fall
            return SeasonalAdjustments(
                season: .fall,
                recommendations: [
                    "Fall: Great time to start retinol",
                    "Focus on repairing summer damage",
                    "Add chemical exfoliant"
                ]
            )

        default:
            return SeasonalAdjustments(season: .spring)
        }
    }
}

public struct SeasonalAdjustments {
    let season: Season
    var hydrationFactor: Float = 0
    var pigmentationFactor: Float = 0
    var recommendations: [String] = []
}
