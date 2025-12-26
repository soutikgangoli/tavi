//
//  HapticManager.swift
//  Ollvy
//
//  Created on 2025-10-27.
//

import UIKit

/// Centralized haptic feedback manager
class HapticManager {

    // MARK: - Singleton

    static let shared = HapticManager()

    // MARK: - Private Properties

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    // MARK: - Initialization

    private init() {
        // Prepare generators for faster response
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }

    // MARK: - Public Methods

    /// Light impact (e.g., button tap)
    func light() {
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    /// Medium impact (e.g., toggle switch)
    func medium() {
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }

    /// Heavy impact (e.g., important action)
    func heavy() {
        impactHeavy.impactOccurred()
        impactHeavy.prepare()
    }

    /// Success feedback (e.g., calibration success, capture complete)
    func success() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    /// Warning feedback
    func warning() {
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }

    /// Error feedback
    func error() {
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }

    /// Selection feedback (e.g., picker change)
    func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    // MARK: - Specific Use Cases

    /// Haptic for calibration turning green
    func calibrationSuccess() {
        success()
    }

    /// Haptic for capture completion
    func captureComplete() {
        // Double success for emphasis
        success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.success()
        }
    }

    /// Haptic for analysis completion
    func analysisComplete() {
        success()
    }

    /// Haptic for navigation
    func navigation() {
        light()
    }

    /// Haptic for important notification
    func notification() {
        medium()
    }

    /// Haptic for destructive action
    func destructive() {
        heavy()
    }
}
