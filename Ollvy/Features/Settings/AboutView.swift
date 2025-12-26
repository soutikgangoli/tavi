//
//  AboutView.swift
//  Ollvy
//
//  App information, support, and credits
//  Created on 2025-01-10
//

import SwiftUI
import StoreKit

public struct AboutView: View {

    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Designs.Spacing.xl) {
                    // App icon and version
                    VStack(spacing: Designs.Spacing.lg) {
                        // App icon placeholder
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Designs.Colors.primary,
                                            Designs.Colors.secondary
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: Designs.Sizes.frameXXLarge, height: Designs.Sizes.frameXXLarge)

                            Image(systemName: "face.smiling")
                                .font(.app(size: 48, weight: .medium))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: Designs.Spacing.sm) {
                            Text(AppStrings.About.appName)
                                .font(AppFont.pageTitle)
                                .foregroundColor(Designs.Colors.textPrimary)

                            Text(AppStrings.About.version(appVersion, build: buildNumber))
                                .font(AppFont.caption)
                                .foregroundColor(Designs.Colors.textSecondary)

                            Text(AppStrings.About.skinHealthAnalysis)
                                .font(AppFont.bodyPrimary)
                                .foregroundColor(Designs.Colors.textSecondary)
                        }
                    }
                    .padding(.top, Designs.Spacing.xl)

                    // About section
                    VStack(alignment: .leading, spacing: Designs.Spacing.lg) {
                        Text(AppStrings.About.about)
                            .font(AppFont.headlineSecondary)
                            .foregroundColor(Designs.Colors.textPrimary)

                        Text("Ollvy uses advanced 3D face scanning technology to analyze your skin health. Track your progress, unlock achievements, and get personalized recommendations for better skin care.")
                            .font(AppFont.bodySecondary)
                            .foregroundColor(Designs.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Designs.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Designs.Colors.elevatedCard)
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))

                    // Features section
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        Text("Features")
                            .font(AppFont.headlineSecondary)
                            .foregroundColor(Designs.Colors.textPrimary)

                        VStack(spacing: Designs.Spacing.md) {
                            featureRow(icon: "camera.metering.center.weighted", title: "3D Face Scanning", description: "Advanced ARKit-powered analysis")
                            featureRow(icon: "chart.line.uptrend.xyaxis", title: "8 Skin Metrics", description: "Comprehensive skin health tracking")
                            featureRow(icon: SFSymbol.flameFill, title: "Gamification", description: "Challenges, streaks, and achievements")
                            featureRow(icon: "lock.shield.fill", title: "Privacy First", description: "All data stays on your device")
                        }
                    }
                    .padding(Designs.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Designs.Colors.elevatedCard)
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))

                    // Support section
                    VStack(spacing: Designs.Spacing.sm) {
                        Button {
                            openEmail()
                        } label: {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .font(.app(size: 18))

                                Text(AppStrings.Settings.contactSupport)
                                    .font(AppFont.subheadingPrimary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.app(size: 13, weight: .semibold))
                                    .foregroundColor(Designs.Colors.textTertiary)
                            }
                            .foregroundColor(Designs.Colors.textPrimary)
                            .padding(Designs.Spacing.md)
                            .background(Designs.Colors.elevatedCard)
                            .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
                        }

                        Button {
                            rateApp()
                        } label: {
                            HStack {
                                Image(systemName: SFSymbol.starFill)
                                    .font(.app(size: 18))

                                Text(AppStrings.Settings.rateApp)
                                    .font(AppFont.subheadingPrimary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.app(size: 13, weight: .semibold))
                                    .foregroundColor(Designs.Colors.textTertiary)
                            }
                            .foregroundColor(Designs.Colors.textPrimary)
                            .padding(Designs.Spacing.md)
                            .background(Designs.Colors.elevatedCard)
                            .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
                        }

                        Link(destination: URL(string: "https://example.com/faq")!) {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.app(size: 18))

                                Text("FAQ")
                                    .font(AppFont.subheadingPrimary)

                                Spacer()

                                Image(systemName: "arrow.up.forward")
                                    .font(.app(size: 13))
                                    .foregroundColor(Designs.Colors.textTertiary)
                            }
                            .foregroundColor(Designs.Colors.textPrimary)
                            .padding(Designs.Spacing.md)
                            .background(Designs.Colors.elevatedCard)
                            .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
                        }
                    }

                    // Credits section
                    VStack(alignment: .leading, spacing: Designs.Spacing.md) {
                        Text("Credits")
                            .font(AppFont.headlineSecondary)
                            .foregroundColor(Designs.Colors.textPrimary)

                        Text(AppStrings.About.developedWithLove)
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textSecondary)

                        Text("© 2025 \(AppStrings.About.appName). \(AppStrings.About.allRightsReserved)")
                            .font(AppFont.footnote)
                            .foregroundColor(Designs.Colors.textTertiary)
                    }
                    .padding(Designs.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Designs.Colors.elevatedCard)
                    .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, Designs.Spacing.lg)
            }
            .background(Designs.Colors.background)
            .navigationTitle(AppStrings.About.about)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppStrings.Buttons.done) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Feature Row

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: Designs.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Designs.Colors.primary.opacity(0.15))
                    .frame(width: Designs.Sizes.iconMedium, height: Designs.Sizes.iconMedium)

                Image(systemName: icon)
                    .font(.app(size: 20, weight: .semibold))
                    .foregroundColor(Designs.Colors.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFont.subheadingSecondary)
                    .foregroundColor(Designs.Colors.textPrimary)

                Text(description)
                    .font(AppFont.footnote)
                    .foregroundColor(Designs.Colors.textSecondary)
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
        // Request in-app review using StoreKit
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            AppStore.requestReview(in: windowScene)
            AppLogger.ui.info("Requested in-app review")
        } else {
            AppLogger.ui.warning("Could not present review - no window scene available")
        }
    }
}

#Preview {
    AboutView()
}
