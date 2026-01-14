//
//  ScanPreparationView.swift
//  Ollvy
//
//  Professional preparation screen matching Headspace
//  Created on 2025-01-03
//

import SwiftUI

/// Clean preparation screen with countdown - no emojis, professional design
public struct ScanPreparationView: View {

    @Environment(\.dismiss) var dismiss
    @State private var countdown: Int = 3
    @State private var isReady: Bool = false
    @State private var breatheScale: CGFloat = 1.0

    let onStart: () -> Void

    public init(onStart: @escaping () -> Void) {
        self.onStart = onStart
    }

    public var body: some View {
        ZStack {
            // Clean gradient background
            Designs.Colors.coolGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top spacer
                Spacer()

                // Breathing circle
                breathingCircle
                    .padding(.bottom, Designs.Spacing.xxxl)

                // Title
                VStack(spacing: Designs.Spacing.md) {
                    Text(isReady ? "Ready to begin" : "Preparing scan")
                        .font(AppFont.title)
                        .foregroundColor(.white)

                    Text(isReady ? "Find a comfortable position" : "Take a deep breath")
                        .font(AppFont.headlineSecondary)
                        .foregroundColor(.white.opacity(Designs.Opacity.almostTransparent))
                }

                Spacer()

                // Checklist
                VStack(spacing: Designs.Spacing.md) {
                    checklistItem(
                        icon: "sun.max.fill",
                        text: "Find bright, natural lighting",
                        isComplete: true
                    )

                    checklistItem(
                        icon: "eyeglasses",
                        text: "Remove glasses if wearing",
                        isComplete: true
                    )

                    checklistItem(
                        icon: "iphone",
                        text: "Hold device at eye level",
                        isComplete: isReady
                    )
                }
                .padding(.horizontal, Designs.Spacing.xxl)

                Spacer()

                // Start button
                if isReady {
                    Button {
                        onStart()
                    } label: {
                        Text("Start scan")
                            .font(AppFont.headlineSecondary)
                            .foregroundColor(Designs.Colors.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Designs.Colors.elevatedCard)
                            .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.lg))
                    }
                    .padding(.horizontal, Designs.Spacing.xl)
                }

                Spacer().frame(height: Designs.Spacing.xxxl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.app(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(Designs.Opacity.almostOpaque))
                }
            }
        }
        .onAppear {
            startBreathingAnimation()
            startCountdown()
        }
    }

    // MARK: - Components

    private var breathingCircle: some View {
        ZStack {
            // Outer rings
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(Designs.Opacity.veryLight + 0.05), lineWidth: Designs.Border.widthThick)
                    .frame(width: Designs.Sizes.displayLarge + CGFloat(index * 35), height: Designs.Sizes.displayLarge + CGFloat(index * 35))
                    .scaleEffect(breatheScale)
                    .opacity(1.0 - (Double(index) * 0.3))
            }

            // Main circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white, Color.white.opacity(Designs.Opacity.semiTransparent + 0.15)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 90
                    )
                )
                .frame(width: Designs.Sizes.scoreCircleLarge, height: Designs.Sizes.scoreCircleLarge)
                .scaleEffect(breatheScale)

            // Counter or checkmark
            if !isReady {
                Text("\(countdown)")
                    .font(AppFont.scoreDisplayLarge)
                    .foregroundColor(Designs.Colors.secondary)
            } else {
                Image(systemName: "checkmark")
                    .font(.app(size: 64, weight: .bold))
                    .foregroundColor(Designs.Colors.success)
            }
        }
    }

    private func checklistItem(icon: String, text: String, isComplete: Bool) -> some View {
        HStack(spacing: Designs.Spacing.lg) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isComplete ? 0.25 : 0.15))
                    .frame(width: Designs.Sizes.cardIcon, height: Designs.Sizes.cardIcon)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.app(size: 20, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: icon)
                        .font(.app(size: 22, weight: .medium))
                        .foregroundColor(.white.opacity(Designs.Opacity.semiTransparent + 0.15))
                }
            }

            // Text
            Text(text)
                .font(AppFont.bodyMedium)
                .foregroundColor(.white.opacity(isComplete ? 1.0 : 0.8))

            Spacer()
        }
    }

    // MARK: - Animations

    private func startBreathingAnimation() {
        withAnimation(
            Animation.easeInOut(duration: 2.5)
                .repeatForever(autoreverses: true)
        ) {
            breatheScale = 1.15
        }
    }

    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            // FIXED: Wrap state updates in DispatchQueue.main.async to avoid
            // "Publishing changes from within view updates" warnings
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
                if countdown > 1 {
                    countdown -= 1
                } else {
                    timer.invalidate()
                    withAnimation(Designs.Animations.gentle) {
                        isReady = true
                    }
                }
            }
        }
    }
}
