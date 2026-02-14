//
//  CosmeticDisclaimer.swift
//  Ollvy
//
//  Visual-only disclaimer component for results screens
//

import SwiftUI

/// Disclaimer banner clarifying cosmetic-only nature of analysis
public struct CosmeticDisclaimer: View {
    public var compact: Bool = false

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public var body: some View {
        if compact {
            compactView
        } else {
            fullView
        }
    }

    private var fullView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Visual Analysis Only", systemImage: "info.circle.fill")
                .font(.subheadline.bold())
                .foregroundColor(Designs.Colors.warning)

            Text("This analysis evaluates visible cosmetic characteristics. It is NOT a medical device and does not diagnose any health condition.")
                .font(.caption)
                .foregroundColor(Designs.Colors.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Designs.Colors.warning.opacity(0.1))
        .cornerRadius(12)
    }

    private var compactView: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundColor(Designs.Colors.textTertiary)

            Text("For cosmetic reference only. Not a medical device.")
                .font(.caption2)
                .foregroundColor(Designs.Colors.textTertiary)
        }
    }
}

#Preview("Full Disclaimer") {
    VStack {
        CosmeticDisclaimer()
            .padding()
    }
    .background(Designs.Colors.background)
}

#Preview("Compact Disclaimer") {
    VStack {
        CosmeticDisclaimer(compact: true)
            .padding()
    }
    .background(Designs.Colors.background)
}
