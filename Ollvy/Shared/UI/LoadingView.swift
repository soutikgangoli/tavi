//
//  LoadingView.swift
//  Ollvy
//
//  Clean inline loading indicator - matches app theme
//  Created on 2025-10-27.
//

import SwiftUI

public struct LoadingView: View {
    let message: String

    // Theme colors (matching onboarding)
    private let textSecondary = Color(red: 120/255, green: 115/255, blue: 110/255)
    private let accentGreen = Color(red: 0/255, green: 180/255, blue: 110/255)

    public init(message: String = "Loading...") {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Custom spinner
            LoadingSpinner(color: accentGreen)
                .frame(width: 32, height: 32)

            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(textSecondary)
        }
        .padding()
    }
}

/// Custom animated loading spinner
struct LoadingSpinner: View {
    let color: Color
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    colors: [color.opacity(0.1), color],
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(270)
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                .linear(duration: 0.8)
                .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

#Preview {
    VStack(spacing: 40) {
        LoadingView()
        LoadingView(message: "Analyzing...")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(red: 252/255, green: 250/255, blue: 245/255))
}
