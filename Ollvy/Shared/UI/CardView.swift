//
//  CardView.swift
//  Ollvy
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
            .padding(Designs.Spacing.medium)
            .background(Designs.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Designs.CornerRadius.medium))
            .cardShadow()
    }
}

#Preview {
    VStack(spacing: Designs.Spacing.medium) {
        CardView {
            VStack(alignment: .leading, spacing: Designs.Spacing.small) {
                Text("Card Title")
                    .font(Designs.Typography.headline)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text("Card content goes here with medium-gray body text")
                    .font(Designs.Typography.body)
                    .foregroundColor(Designs.Colors.textSecondary)
            }
        }

        CardView {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Designs.Colors.success)

                Text("Success message")
                    .font(Designs.Typography.callout)
            }
        }
    }
    .padding()
    .background(Designs.Colors.backgroundSecondary)
}
