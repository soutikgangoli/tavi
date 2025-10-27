//
//  CalibrationHUD.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

public struct CalibrationHUD: View {
    let metrics: CalibrationMetrics?
    let isCalibrated: Bool
    let isExposureLocked: Bool
    let onCalibrate: () -> Void

    public init(
        metrics: CalibrationMetrics?,
        isCalibrated: Bool,
        isExposureLocked: Bool,
        onCalibrate: @escaping () -> Void
    ) {
        self.metrics = metrics
        self.isCalibrated = isCalibrated
        self.isExposureLocked = isExposureLocked
        self.onCalibrate = onCalibrate
    }

    private var statusColor: Color {
        guard let metrics = metrics else { return .gray }

        switch metrics.calibrationStatus {
        case .tooLow:
            return .red
        case .clipped:
            return .yellow
        case .good:
            return .green
        }
    }

    private var statusIcon: String {
        guard let metrics = metrics else { return "exclamationmark.triangle" }

        if isCalibrated {
            return "checkmark.circle.fill"
        }

        switch metrics.calibrationStatus {
        case .tooLow:
            return "exclamationmark.circle.fill"
        case .clipped:
            return "exclamationmark.triangle.fill"
        case .good:
            return "checkmark.circle.fill"
        }
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Status indicator
            HStack(spacing: 12) {
                // Color indicator circle
                Circle()
                    .fill(statusColor)
                    .frame(width: 16, height: 16)
                    .shadow(color: statusColor.opacity(0.5), radius: 4)

                // Status icon and text
                HStack(spacing: 8) {
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)

                    if isExposureLocked {
                        Text("Locked")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    } else if let metrics = metrics {
                        Text(metrics.calibrationStatus.message)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    } else {
                        Text("Analyzing...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)

            // Metrics display
            if let metrics = metrics {
                HStack(spacing: 20) {
                    // Luma value
                    VStack(spacing: 4) {
                        Text("Luma")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(String(format: "%.2f", metrics.averageLuma))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }

                    Divider()
                        .frame(height: 30)
                        .background(.white.opacity(0.3))

                    // Histogram status
                    VStack(spacing: 4) {
                        Text("Histogram")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(metrics.isHistogramClipped ? "Clipped" : "OK")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(metrics.isHistogramClipped ? .yellow : .green)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            }

            // Calibrate button
            if let metrics = metrics, metrics.calibrationStatus == .good, !isCalibrated {
                Button(action: onCalibrate) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.circle.fill")
                        Text("Calibrate")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.green)
                    .cornerRadius(12)
                    .shadow(color: .green.opacity(0.4), radius: 8)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: metrics?.calibrationStatus)
        .animation(.easeInOut(duration: 0.3), value: isCalibrated)
        .animation(.easeInOut(duration: 0.3), value: isExposureLocked)
    }
}

// MARK: - Detailed Calibration View

public struct DetailedCalibrationView: View {
    let metrics: CalibrationMetrics
    @Binding var isPresented: Bool

    public init(metrics: CalibrationMetrics, isPresented: Binding<Bool>) {
        self.metrics = metrics
        self._isPresented = isPresented
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Calibration Details")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white)
                            .font(.title2)
                    }
                }

                Divider()
                    .background(.white.opacity(0.3))

                // Luma information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Average Luma: \(String(format: "%.3f", metrics.averageLuma))")
                        .font(.subheadline)
                        .foregroundStyle(.white)

                    Text("Target range: 0.35 - 0.65")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    // Luma bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.gray.opacity(0.3))

                            // Target range
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.green.opacity(0.3))
                                .frame(width: geometry.size.width * 0.3)
                                .offset(x: geometry.size.width * 0.35)

                            // Current value indicator
                            Circle()
                                .fill(statusColor)
                                .frame(width: 12, height: 12)
                                .offset(x: geometry.size.width * CGFloat(metrics.averageLuma) - 6)
                        }
                    }
                    .frame(height: 20)
                }

                Divider()
                    .background(.white.opacity(0.3))

                // Histogram visualization
                VStack(alignment: .leading, spacing: 8) {
                    Text("Histogram Distribution")
                        .font(.subheadline)
                        .foregroundStyle(.white)

                    CalibrationHistogramView(histogram: metrics.histogram, totalPixels: metrics.totalPixels)
                        .frame(height: 100)

                    if metrics.isHistogramClipped {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("Histogram clipped - adjust lighting")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                Divider()
                    .background(.white.opacity(0.3))

                // Status
                HStack {
                    Text("Status:")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(metrics.calibrationStatus.message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(statusColor)
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .padding(40)
        }
    }

    private var statusColor: Color {
        switch metrics.calibrationStatus {
        case .tooLow:
            return .red
        case .clipped:
            return .yellow
        case .good:
            return .green
        }
    }
}

// MARK: - Histogram View

struct CalibrationHistogramView: View {
    let histogram: [Int]
    let totalPixels: Int

    var body: some View {
        GeometryReader { geometry in
            let maxValue = histogram.max() ?? 1
            let barWidth = geometry.size.width / CGFloat(histogram.count)

            HStack(spacing: 0) {
                ForEach(0..<histogram.count, id: \.self) { index in
                    let normalizedHeight = CGFloat(histogram[index]) / CGFloat(maxValue)
                    let barHeight = geometry.size.height * normalizedHeight

                    Rectangle()
                        .fill(barColor(for: index))
                        .frame(width: barWidth, height: barHeight)
                        .frame(height: geometry.size.height, alignment: .bottom)
                }
            }
        }
    }

    private func barColor(for index: Int) -> Color {
        if index < 5 || index >= 251 {
            // Clipping zones
            return .red.opacity(0.8)
        } else {
            return .white.opacity(0.7)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()

            CalibrationHUD(
                metrics: CalibrationMetrics(
                    averageLuma: 0.5,
                    histogram: Array(repeating: 100, count: 256),
                    totalPixels: 1920 * 1080
                ),
                isCalibrated: false,
                isExposureLocked: false,
                onCalibrate: {}
            )
            .padding()

            Spacer()
        }
    }
}
