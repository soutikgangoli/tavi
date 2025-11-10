//
//  AboutView.swift
//  Tavi
//
//  App information, support, and credits
//  Created on 2025-01-10
//

import SwiftUI

struct AboutView: View {

    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeadspaceDesign.Spacing.xl) {
                    // App icon and version
                    VStack(spacing: HeadspaceDesign.Spacing.lg) {
                        // App icon placeholder
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            HeadspaceDesign.Colors.primary,
                                            HeadspaceDesign.Colors.secondary
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)

                            Image(systemName: "face.smiling")
                                .font(.system(size: 48, weight: .medium))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: HeadspaceDesign.Spacing.sm) {
                            Text("Tavi")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                            Text("Version \(appVersion) (\(buildNumber))")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                            Text("Skin Health Analysis")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                        }
                    }
                    .padding(.top, HeadspaceDesign.Spacing.xl)

                    // About section
                    VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.lg) {
                        Text("About")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                        Text("Tavi uses advanced 3D face scanning technology to analyze your skin health. Track your progress, unlock achievements, and get personalized recommendations for better skin care.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(HeadspaceDesign.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HeadspaceDesign.Colors.elevatedCard)
                    .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))

                    // Features section
                    VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
                        Text("Features")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                        VStack(spacing: HeadspaceDesign.Spacing.md) {
                            featureRow(icon: "camera.metering.center.weighted", title: "3D Face Scanning", description: "Advanced ARKit-powered analysis")
                            featureRow(icon: "chart.line.uptrend.xyaxis", title: "8 Skin Metrics", description: "Comprehensive skin health tracking")
                            featureRow(icon: "flame.fill", title: "Gamification", description: "Challenges, streaks, and achievements")
                            featureRow(icon: "lock.shield.fill", title: "Privacy First", description: "All data stays on your device")
                        }
                    }
                    .padding(HeadspaceDesign.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HeadspaceDesign.Colors.elevatedCard)
                    .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))

                    // Support section
                    VStack(spacing: HeadspaceDesign.Spacing.sm) {
                        Button {
                            openEmail()
                        } label: {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 18))

                                Text("Contact Support")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(HeadspaceDesign.Colors.textTertiary)
                            }
                            .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                            .padding(HeadspaceDesign.Spacing.md)
                            .background(HeadspaceDesign.Colors.elevatedCard)
                            .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md))
                        }

                        Button {
                            rateApp()
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 18))

                                Text("Rate Tavi")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(HeadspaceDesign.Colors.textTertiary)
                            }
                            .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                            .padding(HeadspaceDesign.Spacing.md)
                            .background(HeadspaceDesign.Colors.elevatedCard)
                            .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md))
                        }

                        Link(destination: URL(string: "https://example.com/faq")!) {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.system(size: 18))

                                Text("FAQ")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                                Spacer()

                                Image(systemName: "arrow.up.forward")
                                    .font(.system(size: 13))
                                    .foregroundColor(HeadspaceDesign.Colors.textTertiary)
                            }
                            .foregroundColor(HeadspaceDesign.Colors.textPrimary)
                            .padding(HeadspaceDesign.Spacing.md)
                            .background(HeadspaceDesign.Colors.elevatedCard)
                            .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md))
                        }
                    }

                    // Credits section
                    VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.md) {
                        Text("Credits")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                        Text("Developed with ❤️ using SwiftUI and ARKit")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)

                        Text("© 2025 Tavi. All rights reserved.")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.textTertiary)
                    }
                    .padding(HeadspaceDesign.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HeadspaceDesign.Colors.elevatedCard)
                    .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, HeadspaceDesign.Spacing.lg)
            }
            .background(HeadspaceDesign.Colors.background)
            .navigationTitle("About")
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

    // MARK: - Feature Row

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: HeadspaceDesign.Spacing.md) {
            ZStack {
                Circle()
                    .fill(HeadspaceDesign.Colors.primary.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(HeadspaceDesign.Colors.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                Text(description)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(HeadspaceDesign.Colors.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Actions

    private func openEmail() {
        if let url = URL(string: "mailto:support@taviapp.com") {
            UIApplication.shared.open(url)
        }
    }

    private func rateApp() {
        // TODO: Open App Store rating page
        AppLogger.ui.info("Rate app requested - not yet implemented")
    }
}

#Preview {
    AboutView()
}
