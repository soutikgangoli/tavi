//
//  PrimaryButton.swift
//  Ollvy
//
//  Created on 2025-10-27.
//

import SwiftUI

// MARK: - Primary Button Style

public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.bodyMedium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Designs.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Designs.Radius.md)
                    .fill(isEnabled ? Designs.Colors.primary : Designs.Colors.primary.opacity(0.5))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Primary Button View

public struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: {
            HapticManager.shared.light()
            action()
        }) {
            Text(title)
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}

#Preview {
    VStack(spacing: Designs.Spacing.medium) {
        PrimaryButton(title: "Get Started") {
            AppLogger.ui.info("Button tapped")
        }

        PrimaryButton(title: "Disabled") {
            AppLogger.ui.info("Won't fire")
        }
        .disabled(true)
    }
    .padding()
    .background(Designs.Colors.backgroundSecondary)
}
