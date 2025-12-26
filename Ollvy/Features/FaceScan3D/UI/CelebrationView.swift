//
//  CelebrationView.swift
//  Ollvy
//
//  Celebration UI with animations for metric improvements
//  Make progress tracking FUN and motivating!
//

import SwiftUI

/// Celebration view for improvements
public struct CelebrationView: View {
    let improvements: [MetricImprovement]
    let overallChange: Float
    @Environment(\.dismiss) private var dismiss

    @State private var showConfetti: Bool = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    public var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [celebrationColor.opacity(Designs.Opacity.light), celebrationColor.opacity(Designs.Opacity.veryLight / 2)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Celebration icon with animation
                celebrationIcon
                    .font(.app(size: 100))
                    .foregroundColor(celebrationColor)
                    .scaleEffect(scale)
                    .opacity(opacity)

                // Main message
                Text(celebrationMessage)
                    .font(.app(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .opacity(opacity)

                // Subtitle
                Text(celebrationSubtitle)
                    .font(.app(size: 18))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .opacity(opacity)

                // Improvement list
                VStack(spacing: 12) {
                    ForEach(improvements.prefix(3), id: \.name) { improvement in
                        ImprovementRow(improvement: improvement)
                            .opacity(opacity)
                    }
                }
                .padding()

                Spacer()

                // Close button
                Button(action: {
                    dismiss()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(celebrationColor)
                        .cornerRadius(Designs.Radius.large)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
                .opacity(opacity)
            }

            // Confetti overlay
            if showConfetti {
                ConfettiView()
            }
        }
        .onAppear {
            animateCelebration()
        }
    }

    private func animateCelebration() {
        // Bounce in animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            scale = 1.2
            opacity = 1.0
        }

        // Show confetti after a delay
        if overallChange > 5 {  // Only for significant improvements
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    showConfetti = true
                }
            }
        }

        // Scale back to normal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3)) {
                scale = 1.0
            }
        }
    }

    private var celebrationIcon: Image {
        if overallChange > 10 {
            return Image(systemName: "star.fill")
        } else if overallChange > 5 {
            return Image(systemName: "sparkles")
        } else {
            return Image(systemName: "checkmark.circle.fill")
        }
    }

    private var celebrationColor: Color {
        if overallChange > 10 {
            return .yellow
        } else if overallChange > 5 {
            return .green
        } else {
            return .blue
        }
    }

    private var celebrationMessage: String {
        if overallChange > 10 {
            return "Amazing Progress!"
        } else if overallChange > 5 {
            return "Great Improvement!"
        } else {
            return "You're Improving!"
        }
    }

    private var celebrationSubtitle: String {
        "Your skin health improved by \(String(format: "%.1f", overallChange))%"
    }
}

/// Single improvement row
struct ImprovementRow: View {
    let improvement: MetricImprovement

    var body: some View {
        HStack {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundColor(.green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(improvement.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("+\(String(format: "%.1f", improvement.percentChange))% improvement")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text("\(String(format: "%.0f", improvement.before)) → \(String(format: "%.0f", improvement.after))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white.opacity(Designs.Opacity.semiTransparent))
        .cornerRadius(Designs.Radius.medium)
    }
}

/// Confetti animation overlay
struct ConfettiView: View {
    @State private var animate = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<50) { index in
                    ConfettiPiece(index: index)
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: animate ? geometry.size.height + 100 : -50
                        )
                        .animation(
                            .linear(duration: Double.random(in: 2...4))
                            .repeatForever(autoreverses: false)
                            .delay(Double.random(in: 0...0.5)),
                            value: animate
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            animate = true
        }
    }
}

/// Single confetti piece
struct ConfettiPiece: View {
    let index: Int
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .fill(randomColor)
            .frame(width: CGFloat.random(in: 6...12), height: CGFloat.random(in: 6...12))
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }

    var randomColor: Color {
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink]
        return colors.randomElement() ?? .blue
    }
}

/// Metric improvement data
public struct MetricImprovement {
    let name: String
    let before: Float
    let after: Float
    let percentChange: Float
}

/// Milestone achievements
public struct MilestoneView: View {
    let milestone: Milestone

    public var body: some View {
        VStack(spacing: 20) {
            // Badge
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [milestone.color, milestone.color.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                    .shadow(color: milestone.color.opacity(0.3), radius: 10)

                Image(systemName: milestone.icon)
                    .font(.app(size: 50))
                    .foregroundColor(.white)
            }

            // Title
            Text(milestone.title)
                .font(.title2)
                .bold()

            // Description
            Text(milestone.description)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Reward
            if let reward = milestone.reward {
                Text(reward)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.gray.opacity(Designs.Opacity.veryLight))
                    .cornerRadius(Designs.Radius.medium)
            }
        }
        .padding()
    }
}

/// Milestone data
public struct Milestone {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let reward: String?

    public static let firstScan = Milestone(
        title: "First Scan Complete!",
        description: "You've taken the first step towards better skin health",
        icon: "star.fill",
        color: .blue,
        reward: nil
    )

    public static let weekStreak = Milestone(
        title: "7-Day Streak!",
        description: "Consistent tracking leads to better results",
        icon: "flame.fill",
        color: .orange,
        reward: "Keep it up!"
    )

    public static let monthStreak = Milestone(
        title: "30-Day Champion!",
        description: "You've been tracking for a full month",
        icon: "trophy.fill",
        color: .yellow,
        reward: "You're dedicated!"
    )

    public static let firstImprovement = Milestone(
        title: "First Improvement!",
        description: "Your skincare routine is working",
        icon: "arrow.up.circle.fill",
        color: .green,
        reward: "Keep going!"
    )

    public static let tenScans = Milestone(
        title: "10 Scans Complete!",
        description: "You have enough data to see real trends",
        icon: "chart.line.uptrend.xyaxis",
        color: .purple,
        reward: "Data-driven skincare!"
    )
}

/// Streak tracker
public struct StreakTracker: View {
    let currentStreak: Int
    let longestStreak: Int

    public var body: some View {
        HStack(spacing: 30) {
            // Current streak
            VStack {
                Image(systemName: "flame.fill")
                    .font(.app(size: 40))
                    .foregroundColor(.orange)

                Text("\(currentStreak)")
                    .font(.app(size: 32, weight: .bold))

                Text("Day Streak")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Divider()
                .frame(height: Designs.Sizes.frameMedium + 20)

            // Longest streak
            VStack {
                Image(systemName: "trophy.fill")
                    .font(.app(size: 40))
                    .foregroundColor(.yellow)

                Text("\(longestStreak)")
                    .font(.app(size: 32, weight: .bold))

                Text("Best Streak")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(Designs.Opacity.veryLight / 2))
        .cornerRadius(Designs.Radius.large)
    }
}
