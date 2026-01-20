//
//  AcknowledgmentsView.swift
//  Ollvy
//
//  Credits and acknowledgments
//  Created on 2026-01-21
//

import SwiftUI

public struct AcknowledgmentsView: View {

    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Designs.Spacing.xl) {
                    // Header
                    VStack(alignment: .leading, spacing: Designs.Spacing.sm) {
                        Text("Acknowledgments")
                            .font(AppFont.pageTitle)
                            .foregroundColor(Designs.Colors.textPrimary)

                        Text("Thank you to everyone who made this possible")
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }
                    .padding(.bottom, Designs.Spacing.md)

                    // Apple Technologies
                    acknowledgmentSection(
                        icon: "apple.logo",
                        title: "Apple Technologies",
                        items: [
                            ("ARKit", "Advanced 3D facial tracking and mesh generation"),
                            ("TrueDepth Camera", "Precise depth sensing for skin analysis"),
                            ("Core Data", "Secure local data persistence"),
                            ("Metal", "GPU-accelerated texture processing"),
                            ("SwiftUI", "Modern, responsive user interface")
                        ]
                    )

                    // Fonts
                    acknowledgmentSection(
                        icon: "textformat",
                        title: "Typography",
                        items: [
                            ("General Sans", "Beautiful, modern typeface by Frode Helland / Indian Type Foundry")
                        ]
                    )

                    // Special Thanks
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        HStack(spacing: Designs.Spacing.sm) {
                            Image(systemName: "heart.fill")
                                .font(.app(size: 20))
                                .foregroundColor(.red)

                            Text("Special Thanks")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(Designs.Colors.textPrimary)
                        }

                        Text("To our early testers and everyone who provided feedback to help make Ollvy better. Your insights have been invaluable in creating an app that truly serves its users.")
                            .font(AppFont.bodySecondary)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }
                    .padding(Designs.Spacing.lg)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))

                    // Privacy Commitment
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        HStack(spacing: Designs.Spacing.sm) {
                            Image(systemName: "lock.shield.fill")
                                .font(.app(size: 20))
                                .foregroundColor(.green)

                            Text("Our Commitment")
                                .font(AppFont.headlineSecondary)
                                .foregroundColor(Designs.Colors.textPrimary)
                        }

                        Text("Ollvy was built with privacy as a core principle. We believe your personal data—especially something as sensitive as facial scans—should remain yours and yours alone. That's why everything stays on your device.")
                            .font(AppFont.bodySecondary)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }
                    .padding(Designs.Spacing.lg)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))

                    // Made with love
                    VStack(spacing: Designs.Spacing.md) {
                        Divider()

                        HStack(spacing: 4) {
                            Text("Made with")
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("in India")
                        }
                        .font(AppFont.caption)
                        .foregroundColor(Designs.Colors.textTertiary)

                        Text("© 2026 Ollvy. All rights reserved.")
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Designs.Spacing.lg)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, Designs.Spacing.lg)
                .padding(.top, Designs.Spacing.lg)
            }
            .background(Designs.Colors.background)
            .navigationTitle("Acknowledgments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Section Builder

    private func acknowledgmentSection(icon: String, title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: Designs.Spacing.md) {
            HStack(spacing: Designs.Spacing.sm) {
                Image(systemName: icon)
                    .font(.app(size: 20))
                    .foregroundColor(Designs.Colors.primary)

                Text(title)
                    .font(AppFont.headlineSecondary)
                    .foregroundColor(Designs.Colors.textPrimary)
            }

            VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                ForEach(items, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.0)
                            .font(AppFont.bodyMedium)
                            .foregroundColor(Designs.Colors.textPrimary)

                        Text(item.1)
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }
                }
            }
        }
        .padding(Designs.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Designs.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
    }
}

#Preview {
    AcknowledgmentsView()
}
