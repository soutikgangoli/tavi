//
//  OnboardingModels.swift
//  Ollvy
//
//  Created on 2025-10-27.
//

import SwiftUI

// MARK: - Onboarding Card

struct OnboardingCard: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let tips: [String]
    let image: OnboardingImage

    enum OnboardingImage {
        case systemIcon(String, Color)
        case illustration(String) // For future custom illustrations
    }
}

// MARK: - Onboarding Data

extension OnboardingCard {

    static let cards: [OnboardingCard] = [
        // Card 1: Good Lighting
        OnboardingCard(
            title: "Good Lighting is Key",
            description: "For accurate skin analysis, ensure you're in a well-lit environment with even, natural lighting.",
            iconName: "sun.max.fill",
            tips: [
                "Use natural daylight when possible",
                "Avoid harsh shadows on your face",
                "Position yourself facing the light source",
                "Avoid direct sunlight or strong backlighting"
            ],
            image: .systemIcon("sun.max.fill", Designs.Colors.warning)
        ),

        // Card 2: Framing Guide
        OnboardingCard(
            title: "Frame Your Face",
            description: "Position your face within the guide to ensure all key areas are captured for analysis.",
            iconName: "face.smiling",
            tips: [
                "Center your face in the frame",
                "Keep your entire face visible",
                "Maintain 12-18 inches from camera",
                "Look directly at the camera"
            ],
            image: .systemIcon("face.smiling", Designs.Colors.accent)
        ),

        // Card 3: Hold Still
        OnboardingCard(
            title: "Hold Still",
            description: "During capture, stay still and relaxed to get the clearest, most accurate results.",
            iconName: "hand.raised.fill",
            tips: [
                "Keep your face relaxed and neutral",
                "Avoid talking or moving during capture",
                "The capture takes only a few seconds",
                "You'll feel a haptic when complete"
            ],
            image: .systemIcon("hand.raised.fill", Designs.Colors.info)
        )
    ]
}
