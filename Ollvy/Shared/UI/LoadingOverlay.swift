//
//  LoadingOverlay.swift
//  Ollvy
//
//  Full-screen loading overlay - clean modern design
//  Created on 2025-10-27.
//

import SwiftUI

/// Full-screen loading overlay with disabled UI for long operations
struct LoadingOverlay: View {

    let message: String
    let showProgress: Bool

    // Theme colors
    private let backgroundColor = Color(red: 252/255, green: 250/255, blue: 245/255)
    private let textPrimary = Color(red: 60/255, green: 60/255, blue: 60/255)
    private let textSecondary = Color(red: 120/255, green: 115/255, blue: 110/255)
    private let accentGreen = Color(red: 0/255, green: 180/255, blue: 110/255)

    init(message: String = "Loading...", showProgress: Bool = true) {
        self.message = message
        self.showProgress = showProgress
    }

    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Loading card
            VStack(spacing: 20) {
                if showProgress {
                    LoadingSpinner(color: accentGreen)
                        .frame(width: 40, height: 40)
                }

                Text(message)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(backgroundColor)
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
        .animation(.easeInOut(duration: 0.25), value: isLoading)
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

    private let textSecondary = Color(red: 120/255, green: 115/255, blue: 110/255)
    private let accentGreen = Color(red: 0/255, green: 180/255, blue: 110/255)

    var body: some View {
        HStack(spacing: 12) {
            LoadingSpinner(color: accentGreen)
                .frame(width: 20, height: 20)

            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 20)
    }
}

// MARK: - Preview

#Preview("Loading Overlay") {
    ZStack {
        VStack {
            Text("Background Content")
                .font(.title)
                .foregroundColor(Color(red: 60/255, green: 60/255, blue: 60/255))

            Button("Tap Me") {}
                .buttonStyle(PrimaryButtonStyle())
                .padding()
        }

        LoadingOverlay(message: "Analyzing skin...")
    }
    .background(Color(red: 252/255, green: 250/255, blue: 245/255))
}

#Preview("With Modifier") {
    VStack {
        Text("Content")
            .font(.title)

        Button("Button") {}
            .buttonStyle(PrimaryButtonStyle())
            .padding()
    }
    .loadingOverlay(isLoading: true, message: "Processing...")
    .background(Color(red: 252/255, green: 250/255, blue: 245/255))
}

#Preview("Inline Loading") {
    VStack {
        InlineLoadingView(message: "Loading results...")
    }
    .background(Color(red: 252/255, green: 250/255, blue: 245/255))
}
