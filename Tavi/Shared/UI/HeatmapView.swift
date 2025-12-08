//
//  HeatmapView.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

// MARK: - Heatmap View

public struct HeatmapView: View {
    let faceImage: CGImage
    let scores: ScoreSummary
    let roiSet: FaceROISet
    @Binding var isPresented: Bool

    @State private var showingHeatmap = true
    @State private var selectedMetric: HeatmapType = .composite
    @State private var isGenerating = false
    @State private var heatmapImages: [HeatmapType: CGImage] = [:]
    @State private var errorMessage: String?

    public init(
        faceImage: CGImage,
        scores: ScoreSummary,
        roiSet: FaceROISet,
        isPresented: Binding<Bool>
    ) {
        self.faceImage = faceImage
        self.scores = scores
        self.roiSet = roiSet
        self._isPresented = isPresented
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Image display
                GeometryReader { geometry in
                    ZStack {
                        if showingHeatmap, let heatmap = heatmapImages[selectedMetric] {
                            Image(uiImage: UIImage(cgImage: heatmap))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Image(uiImage: UIImage(cgImage: faceImage))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        if isGenerating {
                            ProgressView("Generating heatmap...")
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(Designs.Radius.medium)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Controls
                VStack(spacing: 16) {
                    // Toggle button
                    Button {
                        withAnimation {
                            showingHeatmap.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: showingHeatmap ? "photo" : "map")
                                .font(.title3)
                            Text(showingHeatmap ? "Show Original" : "Show Heatmap")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(showingHeatmap ? Color.orange : Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }

                    // Metric selector
                    if showingHeatmap {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Metric")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(HeatmapType.allCases, id: \.self) { metric in
                                        MetricButton(
                                            metric: metric,
                                            isSelected: selectedMetric == metric,
                                            action: {
                                                selectedMetric = metric
                                                generateHeatmapIfNeeded(for: metric)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Color legend
                    if showingHeatmap {
                        ColorLegend()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Error message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(Designs.Spacing.xSmall)
                            .background(Color.red.opacity(Designs.Opacity.veryLight))
                            .cornerRadius(Designs.Radius.small)
                    }
                }
                .padding()
                .background(Color(UIColor.systemGroupedBackground))
            }
            .navigationTitle("Heatmap Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .task {
            await generateInitialHeatmap()
        }
    }

    private func generateInitialHeatmap() async {
        await generateHeatmap(for: selectedMetric)
    }

    private func generateHeatmapIfNeeded(for metric: HeatmapType) {
        guard heatmapImages[metric] == nil else { return }

        Task {
            await generateHeatmap(for: metric)
        }
    }

    private func generateHeatmap(for metric: HeatmapType) async {
        guard heatmapImages[metric] == nil else { return }

        isGenerating = true
        errorMessage = nil

        do {
            // Generate heatmap using thermal color scheme (blue → green → yellow → red)
            let heatmap = try await generateThermalHeatmap(for: metric)
            heatmapImages[metric] = heatmap
        } catch {
            errorMessage = "Failed to generate heatmap: \(error.localizedDescription)"
            AppLogger.ui.error("Heatmap generation error: \(error)")
            // Fallback to original image on error
            heatmapImages[metric] = faceImage
        }

        isGenerating = false
    }

    private func generateThermalHeatmap(for metric: HeatmapType) async throws -> CGImage {
        // Create intensity map from metric scores
        let width = faceImage.width
        let height = faceImage.height

        // Calculate metric value (0-1) for color mapping (available but ROI-based scores are used instead)
        _ = getMetricValue(for: metric)

        // Generate heatmap overlay using thermal color scheme
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        // Fill ROI areas with thermal colors based on their scores
        for (roi, bounds) in getROIBounds() {
            let roiScore = getROIScore(for: roi, metric: metric)
            let color = thermalColor(for: roiScore)

            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)

            // Fill pixels in this ROI
            for y in 0..<height {
                for x in 0..<width {
                    let u = Float(x) / Float(width)
                    let v = 1.0 - Float(y) / Float(height)

                    if bounds.contains(u: u, v: v) {
                        let idx = (y * width + x) * 4
                        pixelData[idx] = UInt8(r * 255)
                        pixelData[idx + 1] = UInt8(g * 255)
                        pixelData[idx + 2] = UInt8(b * 255)
                        pixelData[idx + 3] = UInt8(153) // 60% opacity
                    }
                }
            }
        }

        // Create heatmap image from pixel data
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let provider = CGDataProvider(data: Data(pixelData) as CFData) else {
            throw HeatmapError.dataProviderCreationFailed
        }

        guard let heatmapImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            throw HeatmapError.imageCreationFailed
        }

        // Composite heatmap over original face image
        return try compositeHeatmap(heatmapImage, over: faceImage)
    }

    private func getMetricValue(for metric: HeatmapType) -> Float {
        switch metric {
        case .composite: return Float(scores.overallScore) / 100.0
        case .sharpness: return Float(scores.roughnessScore) / 100.0
        case .texture: return Float(scores.roughnessScore) / 100.0
        case .pigmentation: return Float(scores.pigmentationScore) / 100.0
        case .moisture: return Float(scores.hydrationScore ?? 0) / 100.0
        }
    }

    private func getROIBounds() -> [(Face3DROI, UVBounds)] {
        return Face3DROI.allCases.map { ($0, $0.uvBounds) }
    }

    private func getROIScore(for roi: Face3DROI, metric: HeatmapType) -> Float {
        // Use overall score as baseline - in a real implementation,
        // this would extract from Face3DMetrics roiMetrics
        let baseScore = Float(scores.overallScore) / 100.0

        // Add slight variation for different ROIs (placeholder)
        let variation = Float.random(in: -0.1...0.1)
        return max(0, min(1, baseScore + variation))
    }

    private func thermalColor(for value: Float) -> UIColor {
        // Thermal color scheme: Blue (0) → Green (0.25) → Yellow (0.5) → Red (1.0)
        // Inverted: Low scores (problems) = Red, High scores (good) = Blue
        let inverted = 1.0 - value

        if inverted < 0.25 {
            // Blue to Cyan (0.0 to 0.25)
            let t = CGFloat(inverted / 0.25)
            return interpolateColor(
                from: UIColor(red: 0, green: 0, blue: 1, alpha: 1),
                to: UIColor(red: 0, green: 1, blue: 1, alpha: 1),
                t: t
            )
        } else if inverted < 0.5 {
            // Cyan to Green (0.25 to 0.5)
            let t = CGFloat((inverted - 0.25) / 0.25)
            return interpolateColor(
                from: UIColor(red: 0, green: 1, blue: 1, alpha: 1),
                to: UIColor(red: 0, green: 1, blue: 0, alpha: 1),
                t: t
            )
        } else if inverted < 0.75 {
            // Green to Yellow (0.5 to 0.75)
            let t = CGFloat((inverted - 0.5) / 0.25)
            return interpolateColor(
                from: UIColor(red: 0, green: 1, blue: 0, alpha: 1),
                to: UIColor(red: 1, green: 1, blue: 0, alpha: 1),
                t: t
            )
        } else {
            // Yellow to Red (0.75 to 1.0)
            let t = CGFloat((inverted - 0.75) / 0.25)
            return interpolateColor(
                from: UIColor(red: 1, green: 1, blue: 0, alpha: 1),
                to: UIColor(red: 1, green: 0, blue: 0, alpha: 1),
                t: t
            )
        }
    }

    private func interpolateColor(from: UIColor, to: UIColor, t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }

    private func compositeHeatmap(_ heatmap: CGImage, over base: CGImage) throws -> CGImage {
        let width = base.width
        let height = base.height

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw HeatmapError.contextCreationFailed
        }

        // Draw base image
        context.draw(base, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Draw heatmap with blending
        context.setAlpha(0.6)
        context.draw(heatmap, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let result = context.makeImage() else {
            throw HeatmapError.imageCreationFailed
        }

        return result
    }
}

// MARK: - Heatmap Errors

enum HeatmapError: LocalizedError {
    case dataProviderCreationFailed
    case imageCreationFailed
    case contextCreationFailed

    var errorDescription: String? {
        switch self {
        case .dataProviderCreationFailed: return "Failed to create data provider"
        case .imageCreationFailed: return "Failed to create heatmap image"
        case .contextCreationFailed: return "Failed to create graphics context"
        }
    }
}

// MARK: - Metric Button

struct MetricButton: View {
    let metric: HeatmapType
    let isSelected: Bool
    let action: () -> Void

    private var icon: String {
        switch metric {
        case .composite: return "square.stack.3d.up.fill"
        case .sharpness: return "circle.hexagonpath"
        case .texture: return "waveform.path"
        case .pigmentation: return "paintpalette"
        case .moisture: return "drop.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)

                Text(metric.displayName)
                    .font(.caption2)
            }
            .frame(width: 80, height: 60)
            .background(isSelected ? Color.blue : Color(UIColor.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(12)
        }
    }
}

// MARK: - Color Legend

struct ColorLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color Scale")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                // Gradient bar
                LinearGradient(
                    colors: [
                        Color(red: 0, green: 0, blue: 1),      // Blue
                        Color(red: 0, green: 1, blue: 1),      // Cyan
                        Color(red: 0, green: 1, blue: 0),      // Green
                        Color(red: 1, green: 1, blue: 0),      // Yellow
                        Color(red: 1, green: 0, blue: 0)       // Red
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: Designs.Sizes.iconSmall)
                .cornerRadius(Designs.Radius.xSmall)
            }

            HStack {
                Text("0% (Low)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("50%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("100% (High)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    // Note: Preview requires actual image data
    Text("Heatmap View")
}
