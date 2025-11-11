//
//  ScanPreparationView.swift
//  Tavi
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
            HeadspaceDesign.Colors.coolGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top spacer
                Spacer()

                // Breathing circle
                breathingCircle
                    .padding(.bottom, HeadspaceDesign.Spacing.xxxl)

                // Title
                VStack(spacing: HeadspaceDesign.Spacing.md) {
                    Text(isReady ? "Ready to begin" : "Preparing scan")
                        .font(.gilroy(size: 30, weight: .bold))
                        .foregroundColor(.white)

                    Text(isReady ? "Find a comfortable position" : "Take a deep breath")
                        .font(.gilroy(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                }

                Spacer()

                // Checklist
                VStack(spacing: HeadspaceDesign.Spacing.md) {
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
                .padding(.horizontal, HeadspaceDesign.Spacing.xxl)

                Spacer()

                // Start button
                if isReady {
                    Button {
                        onStart()
                    } label: {
                        Text("Start scan")
                            .font(.gilroy(size: 18, weight: .bold))
                            .foregroundColor(HeadspaceDesign.Colors.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(HeadspaceDesign.Colors.elevatedCard)
                            .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.lg))
                    }
                    .padding(.horizontal, HeadspaceDesign.Spacing.xl)
                }

                Spacer().frame(height: HeadspaceDesign.Spacing.xxxl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
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
                    .stroke(Color.white.opacity(0.15), lineWidth: 2)
                    .frame(width: 180 + CGFloat(index * 35), height: 180 + CGFloat(index * 35))
                    .scaleEffect(breatheScale)
                    .opacity(1.0 - (Double(index) * 0.3))
            }

            // Main circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white, Color.white.opacity(0.85)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 90
                    )
                )
                .frame(width: 160, height: 160)
                .scaleEffect(breatheScale)

            // Counter or checkmark
            if !isReady {
                Text("\(countdown)")
                    .font(.gilroy(size: 72, weight: .bold))
                    .foregroundColor(HeadspaceDesign.Colors.secondary)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(HeadspaceDesign.Colors.success)
            }
        }
    }

    private func checklistItem(icon: String, text: String, isComplete: Bool) -> some View {
        HStack(spacing: HeadspaceDesign.Spacing.lg) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isComplete ? 0.25 : 0.15))
                    .frame(width: 48, height: 48)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            // Text
            Text(text)
                .font(.gilroy(size: 17, weight: .medium))
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
            if countdown > 1 {
                countdown -= 1
            } else {
                timer.invalidate()
                withAnimation(HeadspaceDesign.Animations.gentle) {
                    isReady = true
                }
            }
        }
    }
}
