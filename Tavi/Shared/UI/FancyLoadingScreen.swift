//
//  FancyLoadingScreen.swift
//  Tavi
//
//  Premium loading screen with 0-100 progress animation
//  Created on October 29, 2025.
//

import SwiftUI

/// Premium loading screen with smooth 0-100 progress animation
struct FancyLoadingScreen: View {
    @State private var progress: Double = 0
    @State private var currentPhase: LoadingPhase = .initializing
    @State private var showLogo: Bool = false
    @State private var pulseAnimation: Bool = false

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            // Premium gradient background - deeper, richer colors
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.08, green: 0.05, blue: 0.20),
                    Color(red: 0.05, green: 0.10, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Animated background particles - subtler, more elegant
            GeometryReader { geometry in
                ForEach(0..<15, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(Designs.Opacity.veryLight / 5),
                                    Color.blue.opacity(Designs.Opacity.veryLight / 2.5),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 60
                            )
                        )
                        .frame(width: CGFloat.random(in: 60...150))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .blur(radius: 30)
                        .animation(
                            Animation.easeInOut(duration: Double.random(in: 4...7))
                                .repeatForever(autoreverses: true)
                                .delay(Double.random(in: 0...2)),
                            value: pulseAnimation
                        )
                }
            }
            .onAppear {
                pulseAnimation.toggle()
            }

            VStack(spacing: 0) {
                Spacer()

                // Logo with reveal animation - improved spacing
                VStack(spacing: 24) {
                    // Logo circle with glow - more prominent
                    ZStack {
                        // Outer glow - stronger presence
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.blue.opacity(Designs.Opacity.light),
                                        Color.blue.opacity(Designs.Opacity.veryLight + 0.05),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 40,
                                    endRadius: 120
                                )
                            )
                            .frame(width: 240, height: 240)
                            .blur(radius: 25)
                            .scaleEffect(showLogo ? 1.0 : 0.8)

                        // Main logo circle - slightly larger
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.45, green: 0.65, blue: 1.0),
                                        Color(red: 0.25, green: 0.45, blue: 0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: Designs.Sizes.achievementIconLarge, height: Designs.Sizes.achievementIconLarge)
                            .shadow(color: .blue.opacity(Designs.Opacity.semiOpaque + 0.1), radius: Designs.Spacing.xxxLarge - 5, x: 0, y: Designs.Spacing.small)
                            .scaleEffect(showLogo ? 1.0 : 0.5)
                            .opacity(showLogo ? 1.0 : 0.0)

                        // App icon content - slightly larger
                        Text("T")
                            .font(AppFont.scoreDisplayLarge)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color.white.opacity(Designs.Opacity.almostOpaque)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .scaleEffect(showLogo ? 1.0 : 0.5)
                            .opacity(showLogo ? 1.0 : 0.0)
                    }

                    // App name - better spacing
                    Text("Ollvy")
                        .font(.app(size: 48, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    .white,
                                    Color.white.opacity(Designs.Opacity.almostTransparent)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(Designs.Opacity.medium), radius: Designs.Spacing.small, x: 0, y: Designs.Spacing.xxSmall)
                        .opacity(showLogo ? 1.0 : 0.0)
                        .offset(y: showLogo ? 0 : 20)
                }
                .animation(Designs.Animation.gentleSpring, value: showLogo)

                Spacer()

                // Progress section - improved layout
                VStack(spacing: 32) {
                    // Loading phase text - better hierarchy
                    Text(currentPhase.message)
                        .font(AppFont.bodySecondary)
                        .foregroundColor(.white.opacity(Designs.Opacity.semiTransparent + 0.05))
                        .animation(Designs.Animation.standard, value: currentPhase)

                    // Progress bar container - cleaner design
                    VStack(spacing: 16) {
                        // Progress bar - improved sizing
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track - more visible
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(Designs.Opacity.veryLight + 0.02))
                                    .frame(height: Designs.Spacing.small)

                                // Progress fill with gradient - more vibrant
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.45, green: 0.65, blue: 1.0),
                                                Color(red: 0.35, green: 0.55, blue: 0.95),
                                                Color(red: 0.55, green: 0.75, blue: 1.0)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * (progress / 100), height: 10)
                                    .shadow(color: .blue.opacity(Designs.Opacity.semiOpaque + 0.1), radius: Designs.Spacing.small, x: 0, y: Designs.Opacity.medium * 10)

                                // Shimmer effect - more pronounced
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0),
                                                Color.white.opacity(Designs.Opacity.light),
                                                Color.white.opacity(0)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * (progress / 100), height: 10)
                                    .mask(
                                        RoundedRectangle(cornerRadius: 10)
                                            .frame(width: geometry.size.width * (progress / 100), height: 10)
                                    )
                            }
                        }
                        .frame(height: Designs.Spacing.small)
                        .frame(maxWidth: 320)

                        // Percentage text - larger, more readable
                        Text("\(Int(progress))%")
                            .font(AppFont.headlinePrimary)
                            .foregroundColor(.white.opacity(Designs.Opacity.almostTransparent))
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 80)
            }
        }
        .onAppear {
            startLoadingSequence()
        }
    }

    // MARK: - Loading Sequence

    private func startLoadingSequence() {
        // Reveal logo
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
            showLogo = true
        }

        // Start progress animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animateProgress()
        }
    }

    private func animateProgress() {
        // Phase 1: Initializing (0-25%)
        currentPhase = .initializing
        animateProgressTo(25, duration: 0.8) {
            // Phase 2: Loading Resources (25-50%)
            currentPhase = .loadingResources
            animateProgressTo(50, duration: 0.6) {
                // Phase 3: Preparing AI Models (50-75%)
                currentPhase = .preparingModels
                animateProgressTo(75, duration: 0.7) {
                    // Phase 4: Almost Ready (75-100%)
                    currentPhase = .almostReady
                    animateProgressTo(100, duration: 0.5) {
                        // Complete!
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeOut(duration: 0.4)) {
                                onComplete()
                            }
                        }
                    }
                }
            }
        }
    }

    private func animateProgressTo(_ target: Double, duration: Double, completion: @escaping () -> Void) {
        withAnimation(.easeInOut(duration: duration)) {
            progress = target
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            completion()
        }
    }
}

// MARK: - Loading Phases

private enum LoadingPhase {
    case initializing
    case loadingResources
    case preparingModels
    case almostReady

    var message: String {
        switch self {
        case .initializing:
            return "Initializing..."
        case .loadingResources:
            return "Loading resources..."
        case .preparingModels:
            return "Preparing AI models..."
        case .almostReady:
            return "Almost ready..."
        }
    }
}

// MARK: - Preview

#Preview {
    FancyLoadingScreen {
        AppLogger.ui.info("Loading complete!")
    }
}
