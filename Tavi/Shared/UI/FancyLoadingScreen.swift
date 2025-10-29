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
            // Premium gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color(red: 0.12, green: 0.08, blue: 0.16),
                    Color(red: 0.08, green: 0.12, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Animated background particles
            GeometryReader { geometry in
                ForEach(0..<20, id: \.self) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.03),
                                    Color.blue.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: CGFloat.random(in: 40...120))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .blur(radius: 40)
                        .animation(
                            Animation.easeInOut(duration: Double.random(in: 3...6))
                                .repeatForever(autoreverses: true)
                                .delay(Double.random(in: 0...2)),
                            value: pulseAnimation
                        )
                }
            }
            .onAppear {
                pulseAnimation.toggle()
            }

            VStack(spacing: 60) {
                Spacer()

                // Logo with reveal animation
                VStack(spacing: 16) {
                    // Logo circle with glow
                    ZStack {
                        // Outer glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.blue.opacity(0.3),
                                        Color.blue.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 50,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)
                            .blur(radius: 20)
                            .scaleEffect(showLogo ? 1.0 : 0.8)

                        // Main logo circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.6, blue: 1.0),
                                        Color(red: 0.2, green: 0.4, blue: 0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: .blue.opacity(0.5), radius: 30, x: 0, y: 10)
                            .scaleEffect(showLogo ? 1.0 : 0.5)
                            .opacity(showLogo ? 1.0 : 0.0)

                        // App icon content
                        Text("T")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color.white.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .scaleEffect(showLogo ? 1.0 : 0.5)
                            .opacity(showLogo ? 1.0 : 0.0)
                    }

                    // App name
                    Text("Tavi")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    .white,
                                    Color.white.opacity(0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(showLogo ? 1.0 : 0.0)
                        .offset(y: showLogo ? 0 : 20)
                }
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: showLogo)

                Spacer()

                // Progress section
                VStack(spacing: 24) {
                    // Loading phase text
                    Text(currentPhase.message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.7))
                        .animation(.easeInOut(duration: 0.3), value: currentPhase)

                    // Progress bar container
                    VStack(spacing: 12) {
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 8)

                                // Progress fill with gradient
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.4, green: 0.6, blue: 1.0),
                                                Color(red: 0.3, green: 0.5, blue: 0.9),
                                                Color(red: 0.5, green: 0.7, blue: 1.0)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * (progress / 100), height: 8)
                                    .shadow(color: .blue.opacity(0.5), radius: 8, x: 0, y: 2)

                                // Shimmer effect
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0),
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * (progress / 100), height: 8)
                                    .mask(
                                        RoundedRectangle(cornerRadius: 8)
                                            .frame(width: geometry.size.width * (progress / 100), height: 8)
                                    )
                            }
                        }
                        .frame(height: 8)
                        .frame(maxWidth: 280)

                        // Percentage text
                        Text("\(Int(progress))%")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
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
        print("Loading complete!")
    }
}
