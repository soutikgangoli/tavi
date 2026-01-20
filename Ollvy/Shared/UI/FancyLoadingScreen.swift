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
    // START VISIBLE - no delay before content appears
    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 1.0
    @State private var textOpacity: Double = 1.0
    @State private var progressBarOpacity: Double = 1.0

    /// Whether actual initialization is complete (set by parent)
    var isReady: Bool = false
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
        // PERFORMANCE: Watch for actual initialization completion
        .onChange(of: isReady) { _, ready in
            if ready {
                completeLoading()
            }
        }
    }

    // MARK: - Loading Sequence

    private func startLoadingSequence() {
        // Animate progress to 80% quickly (gives visual feedback)
        // Remaining 20% animates when actual init completes
        withAnimation(.easeOut(duration: 0.2)) {
            progress = 80
        }

        // If already ready (fast init), complete immediately
        if isReady {
            completeLoading()
        }
    }

    private func completeLoading() {
        // Animate to 100% and fade out
        withAnimation(.easeOut(duration: 0.15)) {
            progress = 100
        }

        // Brief delay to show 100% before fading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                onComplete()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FancyLoadingScreen(isReady: true) {
        print("Loading complete!")
    }
}
