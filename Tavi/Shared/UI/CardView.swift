//
//  CardView.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

public struct CardView<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(DesignSystem.Spacing.medium)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .cardShadow()
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spacing.medium) {
        CardView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text("Card Title")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Card content goes here with medium-gray body text")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }

        CardView {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.success)

                Text("Success message")
                    .font(DesignSystem.Typography.callout)
            }
        }
    }
    .padding()
    .background(DesignSystem.Colors.backgroundSecondary)
}
