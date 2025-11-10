//
//  PrimaryButton.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

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
    VStack(spacing: DesignSystem.Spacing.medium) {
        PrimaryButton(title: "Get Started") {
            AppLogger.ui.info("Button tapped")
        }

        PrimaryButton(title: "Disabled") {
            AppLogger.ui.info("Won't fire")
        }
        .disabled(true)
    }
    .padding()
    .background(DesignSystem.Colors.backgroundSecondary)
}
