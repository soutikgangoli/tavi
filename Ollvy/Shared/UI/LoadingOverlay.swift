//
//  LoadingOverlay.swift
//  Ollvy
//
//  Created on 2025-10-27.
//

import SwiftUI

/// Full-screen loading overlay with disabled UI for long operations
struct LoadingOverlay: View {

    let message: String
    let showProgress: Bool

    init(message: String = "Loading...", showProgress: Bool = true) {
        self.message = message
        self.showProgress = showProgress
    }

    var body: some View {
        ZStack {
            // Overlay background
            Designs.Colors.overlay
                .ignoresSafeArea()

            // Loading card
            VStack(spacing: Designs.Spacing.large) {
                if showProgress {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Designs.Colors.accent))
                        .scaleEffect(1.5)
                }

                Text(message)
                    .font(Designs.Typography.headline)
                    .foregroundColor(Designs.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(Designs.Spacing.xxLarge)
            .background(Designs.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Designs.CornerRadius.large))
            .modalShadow()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

// MARK: - View Modifier

struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool
    let message: String

    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)

            if isLoading {
                LoadingOverlay(message: message)
            }
        }
        .animation(Designs.Animation.standard, value: isLoading)
    }
}

extension View {
    /// Show loading overlay when condition is true
    func loadingOverlay(isLoading: Bool, message: String = "Loading...") -> some View {
        self.modifier(LoadingOverlayModifier(isLoading: isLoading, message: message))
    }
}

// MARK: - Inline Loading View

struct InlineLoadingView: View {
    let message: String

    var body: some View {
        HStack(spacing: Designs.Spacing.medium) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Designs.Colors.accent))

            Text(message)
                .font(Designs.Typography.body)
                .foregroundColor(Designs.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(Designs.Spacing.large)
    }
}

// MARK: - Preview

#Preview("Loading Overlay") {
    ZStack {
        VStack {
            Text("Background Content")
                .font(Designs.Typography.title)

            Button("Tap Me") {}
                .buttonStyle(PrimaryButtonStyle())
                .padding()
        }

        LoadingOverlay(message: "Analyzing skin...")
    }
}

#Preview("With Modifier") {
    VStack {
        Text("Content")
            .font(Designs.Typography.title)

        Button("Button") {}
            .buttonStyle(PrimaryButtonStyle())
            .padding()
    }
    .loadingOverlay(isLoading: true, message: "Processing...")
}

#Preview("Inline Loading") {
    VStack {
        InlineLoadingView(message: "Loading results...")
    }
    .background(Designs.Colors.backgroundSecondary)
}
