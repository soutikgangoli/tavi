//
//  HistogramView.swift
//  Ollvy
//
//  Created on 2025-10-27.
//

import SwiftUI

/// Live histogram visualization for luma values
struct HistogramView: View {

    let histogram: [Int]
    let height: CGFloat

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard !histogram.isEmpty else { return }

                // Find max value for scaling
                let maxValue = histogram.max() ?? 1
                let barWidth = size.width / CGFloat(histogram.count)

                // Draw bars
                for (index, value) in histogram.enumerated() {
                    let barHeight = CGFloat(value) / CGFloat(maxValue) * size.height
                    let x = CGFloat(index) * barWidth
                    let y = size.height - barHeight

                    let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                    let path = Path(rect)

                    // Color based on position (shadows, midtones, highlights)
                    let color = colorForBin(index: index, total: histogram.count)
                    context.fill(path, with: .color(color))
                }

                // Draw clipping indicators (first 5 and last 5 bins)
                drawClippingIndicators(context: context, size: size, barWidth: barWidth)
            }
        }
        .frame(height: height)
    }

    private func colorForBin(index: Int, total: Int) -> Color {
        let normalizedIndex = Double(index) / Double(total)

        if normalizedIndex < 0.33 {
            // Shadows - blue tint
            return Color.blue.opacity(0.7)
        } else if normalizedIndex < 0.67 {
            // Midtones - white
            return Color.white.opacity(0.8)
        } else {
            // Highlights - yellow tint
            return Color.yellow.opacity(0.7)
        }
    }

    private func drawClippingIndicators(context: GraphicsContext, size: CGSize, barWidth: CGFloat) {
        // Shadow clipping zone (first 5 bins)
        let shadowRect = CGRect(x: 0, y: 0, width: barWidth * 5, height: size.height)
        context.stroke(
            Path(shadowRect),
            with: .color(.red.opacity(0.5)),
            lineWidth: 2
        )

        // Highlight clipping zone (last 5 bins)
        let highlightRect = CGRect(
            x: size.width - (barWidth * 5),
            y: 0,
            width: barWidth * 5,
            height: size.height
        )
        context.stroke(
            Path(highlightRect),
            with: .color(.red.opacity(0.5)),
            lineWidth: 2
        )
    }
}

// MARK: - Compact Histogram View

struct CompactHistogramView: View {

    let histogram: [Int]

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard !histogram.isEmpty else { return }

                let maxValue = histogram.max() ?? 1
                let barWidth = size.width / CGFloat(histogram.count)

                for (index, value) in histogram.enumerated() {
                    let barHeight = CGFloat(value) / CGFloat(maxValue) * size.height
                    let x = CGFloat(index) * barWidth
                    let y = size.height - barHeight

                    let rect = CGRect(x: x, y: y, width: max(barWidth, 1), height: barHeight)
                    let path = Path(rect)

                    context.fill(path, with: .color(.white.opacity(0.7)))
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Histogram") {
    VStack(spacing: 20) {
        // Sample histogram with normal distribution
        let normalHist = (0..<256).map { x in
            let mu = 128.0
            let sigma = 40.0
            let value = exp(-pow(Double(x) - mu, 2) / (2 * sigma * sigma))
            return Int(value * 1000)
        }

        HistogramView(histogram: normalHist, height: 150)
            .background(Color.black.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding()

        // Clipped histogram
        let clippedHist: [Int] = {
            var hist = Array(repeating: 0, count: 256)
            hist[0] = 500 // Shadow clipping
            hist[255] = 500 // Highlight clipping
            for i in 100..<150 {
                hist[i] = 300
            }
            return hist
        }()

        HistogramView(histogram: clippedHist, height: 150)
            .background(Color.black.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding()

        Text("Normal Distribution vs Clipped")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .preferredColorScheme(.dark)
}

#Preview("Compact") {
    let normalHist = (0..<256).map { x in
        let mu = 128.0
        let sigma = 40.0
        let value = exp(-pow(Double(x) - mu, 2) / (2 * sigma * sigma))
        return Int(value * 1000)
    }

    CompactHistogramView(histogram: normalHist)
        .frame(height: 60)
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding()
        .preferredColorScheme(.dark)
}
