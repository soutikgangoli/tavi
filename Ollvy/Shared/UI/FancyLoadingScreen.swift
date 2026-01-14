//
//  FancyLoadingScreen.swift
//  Ollvy
//
//  Premium splash screen - clean, modern, Apple-inspired
//  Created on October 29, 2025.
//

import SwiftUI

/// Premium splash screen with elegant minimal design
struct FancyLoadingScreen: View {
    @State private var progress: Double = 0
    @State private var showContent: Bool = false
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var progressBarOpacity: Double = 0

    var onComplete: () -> Void

    // Warm cream colors (matching onboarding)
    private let backgroundColor = Color(red: 252/255, green: 250/255, blue: 245/255)
    private let textPrimary = Color(red: 60/255, green: 60/255, blue: 60/255)
    private let textSecondary = Color(red: 120/255, green: 115/255, blue: 110/255)
    private let accentGreen = Color(red: 0/255, green: 180/255, blue: 110/255)
    private let accentCoral = Color(red: 235/255, green: 120/255, blue: 90/255)

    var body: some View {
        ZStack {
            // Clean warm background
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo section
                VStack(spacing: 28) {
                    // Animated ring with icon
                    ZStack {
                        // Outer subtle ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [accentGreen.opacity(0.3), accentCoral.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 130, height: 130)
                            .scaleEffect(ringScale)
                            .opacity(ringOpacity * 0.5)

                        // Main logo circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [accentGreen, accentGreen.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: accentGreen.opacity(0.3), radius: 20, x: 0, y: 8)
                            .scaleEffect(ringScale)
                            .opacity(ringOpacity)

                        // App icon - simple face scan icon
                        Image(systemName: "faceid")
                            .font(.system(size: 44, weight: .regular))
                            .foregroundColor(.white)
                            .scaleEffect(ringScale)
                            .opacity(ringOpacity)
                    }

                    // App name
                    VStack(spacing: 6) {
                        Text("Ollvy")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(textPrimary)

                        Text("Skin Analysis Tracker")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(textSecondary)
                    }
                    .opacity(textOpacity)
                }

                Spacer()

                // Bottom section - minimal progress
                VStack(spacing: 20) {
                    // Simple progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Track
                            Capsule()
                                .fill(Color.black.opacity(0.08))
                                .frame(height: 4)

                            // Progress fill
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [accentGreen, accentGreen.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, geometry.size.width * (progress / 100)), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .frame(maxWidth: 200)
                    .opacity(progressBarOpacity)

                    // Simple status text
                    Text("Getting things ready...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textSecondary)
                        .opacity(progressBarOpacity * 0.8)
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 80)
            }
        }
        .onAppear {
            startLoadingSequence()
        }
    }

    // MARK: - Loading Sequence

    private func startLoadingSequence() {
        // Phase 1: Reveal logo with spring animation
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.2)) {
            ringScale = 1.0
            ringOpacity = 1.0
        }

        // Phase 2: Reveal text
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            textOpacity = 1.0
        }

        // Phase 3: Show progress bar
        withAnimation(.easeOut(duration: 0.4).delay(0.8)) {
            progressBarOpacity = 1.0
        }

        // Phase 4: Animate progress smoothly
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            animateProgress()
        }
    }

    private func animateProgress() {
        // Smooth continuous progress animation
        withAnimation(.easeInOut(duration: 0.6)) {
            progress = 30
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                progress = 60
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.4)) {
                progress = 85
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                progress = 100
            }
        }

        // Complete and transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.35)) {
                onComplete()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FancyLoadingScreen {
        AppLogger.ui.info("Loading complete!")
    }
}
