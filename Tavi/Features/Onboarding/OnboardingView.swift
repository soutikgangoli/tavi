//
//  OnboardingView.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

/// Onboarding flow with 3 cards explaining how to use the app
struct OnboardingView: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0
    private let cards = OnboardingCard.cards

    var onComplete: (() -> Void)?

    var body: some View {
        ZStack {
            // Background
            DesignSystem.Colors.backgroundSecondary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()

                    if currentPage < cards.count - 1 {
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("Skip")
                                .font(DesignSystem.Typography.callout)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .padding(DesignSystem.Spacing.medium)
                    }
                }

                Spacer()

                // Card carousel
                TabView(selection: $currentPage) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                        OnboardingCardView(card: card)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Spacer()

                // Navigation buttons
                VStack(spacing: DesignSystem.Spacing.medium) {
                    if currentPage < cards.count - 1 {
                        Button {
                            withAnimation(DesignSystem.Animation.spring) {
                                currentPage += 1
                            }
                            HapticManager.shared.light()
                        } label: {
                            Text("Next")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button {
                            completeOnboarding()
                        } label: {
                            Text("Skip Tutorial")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    } else {
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("Get Started")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .padding(DesignSystem.Spacing.large)
            }
        }
    }

    private func completeOnboarding() {
        HapticManager.shared.success()
        hasCompletedOnboarding = true
        onComplete?()
        dismiss()
    }
}

// MARK: - Onboarding Card View

struct OnboardingCardView: View {

    let card: OnboardingCard

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xLarge) {
            // Icon
            iconView

            // Content card
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.large) {
                // Title and description
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    Text(card.title)
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(card.description)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Tips
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                    ForEach(card.tips, id: \.self) { tip in
                        TipRow(text: tip)
                    }
                }
            }
            .padding(DesignSystem.Spacing.xLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
            .cardShadow()
        }
        .padding(DesignSystem.Spacing.large)
    }

    @ViewBuilder
    private var iconView: some View {
        switch card.image {
        case .systemIcon(let name, let color):
            Image(systemName: name)
                .font(.system(size: 80, weight: .light))
                .foregroundColor(color)
                .frame(height: 120)

        case .illustration(let name):
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 120)
        }
    }
}

// MARK: - Tip Row

struct TipRow: View {

    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.small) {
            Image(systemName: "checkmark.circle.fill")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.success)
                .frame(width: 20, alignment: .center)

            Text(text)
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView()
}

#Preview("Single Card") {
    ZStack {
        DesignSystem.Colors.backgroundSecondary
            .ignoresSafeArea()

        OnboardingCardView(card: OnboardingCard.cards[0])
    }
}

#Preview("Dark Mode") {
    OnboardingView()
        .preferredColorScheme(.dark)
}
