//
//  DebugScreen.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI
import AVFoundation

/// Comprehensive debug screen with live metrics, overlays, and performance stats
struct DebugScreen: View {

    @StateObject private var viewModel: DebugViewModel
    @State private var selectedTab = 0

    init(cameraSession: CameraSession) {
        _viewModel = StateObject(wrappedValue: DebugViewModel(cameraSession: cameraSession))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Live camera preview with overlays
                cameraPreviewSection

                // Tab selector
                tabPicker

                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    metricsTab
                        .tag(0)

                    eventsTab
                        .tag(1)

                    performanceTab
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            // ROI Metrics Popup
            if viewModel.showROIMetrics, let (roiSet, roiType) = viewModel.selectedROI {
                ROIMetricsPopup(
                    roiSet: roiSet,
                    roiType: roiType,
                    onDismiss: {
                        viewModel.dismissROIMetrics()
                    }
                )
            }
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        viewModel.toggleFaceBounds()
                    } label: {
                        Label(
                            viewModel.showFaceBounds ? "Hide Face Bounds" : "Show Face Bounds",
                            systemImage: viewModel.showFaceBounds ? "eye.slash" : "eye"
                        )
                    }

                    Button {
                        viewModel.toggleLandmarks()
                    } label: {
                        Label(
                            viewModel.showLandmarks ? "Hide Landmarks" : "Show Landmarks",
                            systemImage: viewModel.showLandmarks ? "face.dashed" : "face.smiling"
                        )
                    }

                    Divider()

                    Button(role: .destructive) {
                        viewModel.resetStats()
                    } label: {
                        Label("Reset Stats", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: - Camera Preview Section

    private var cameraPreviewSection: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview placeholder (actual camera view would be injected)
                if let frame = viewModel.latestFrame {
                    Image(uiImage: frame)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Text("Camera Preview")
                                .foregroundColor(.white.opacity(0.5))
                        )
                }

                // Face and ROI overlays
                if let imageSize = viewModel.latestFrame?.size {
                    DebugOverlayView(
                        faces: viewModel.detectedFaces,
                        roiSets: viewModel.faceROIs,
                        imageSize: imageSize,
                        showFaceBounds: viewModel.showFaceBounds,
                        showLandmarks: viewModel.showLandmarks,
                        onROITap: { roiSet, roiType, point in
                            viewModel.selectROI(roiSet: roiSet, roiType: roiType, at: point)
                        }
                    )
                }

                // Performance HUD (top-right corner)
                VStack {
                    HStack {
                        Spacer()
                        PerformanceHUD(
                            fps: viewModel.currentFPS,
                            latency: viewModel.processingLatency,
                            frameCount: viewModel.frameCount
                        )
                        .padding()
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 300)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("Tab", selection: $selectedTab) {
            Text("Metrics").tag(0)
            Text("Events").tag(1)
            Text("Performance").tag(2)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Metrics Tab

    private var metricsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Histogram
                histogramSection

                // Luma and Blur
                lumaBlurSection

                // Face Detection Info
                faceDetectionSection
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
    }

    private var histogramSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Histogram")
                .font(.headline)

            HistogramView(histogram: viewModel.histogram, height: 120)
                .background(Color.black.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if let metrics = viewModel.currentMetrics {
                HStack {
                    Image(systemName: metrics.isHistogramClipped ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(metrics.isHistogramClipped ? .orange : .green)

                    Text(metrics.isHistogramClipped ? "Histogram Clipped" : "Histogram OK")
                        .font(.caption)
                        .foregroundColor(metrics.isHistogramClipped ? .orange : .green)

                    Spacer()

                    Text(metrics.calibrationStatus.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var lumaBlurSection: some View {
        HStack(spacing: 12) {
            // Average Luma
            MetricCard(
                title: "Avg Luma",
                value: String(format: "%.3f", viewModel.averageLuma),
                subtitle: lumaStatus,
                icon: "sun.max.fill",
                color: lumaColor
            )

            // Blur Score
            MetricCard(
                title: "Blur Score",
                value: String(format: "%.1f", viewModel.blurScore),
                subtitle: blurStatus,
                icon: "camera.aperture",
                color: blurColor
            )
        }
    }

    private var lumaStatus: String {
        let luma = viewModel.averageLuma
        if luma < 0.35 {
            return "Too Dark"
        } else if luma > 0.65 {
            return "Too Bright"
        } else {
            return "Good"
        }
    }

    private var lumaColor: Color {
        let luma = viewModel.averageLuma
        if luma < 0.35 || luma > 0.65 {
            return .orange
        } else {
            return .green
        }
    }

    private var blurStatus: String {
        if viewModel.blurScore > 80 {
            return "Sharp"
        } else if viewModel.blurScore > 60 {
            return "OK"
        } else {
            return "Blurry"
        }
    }

    private var blurColor: Color {
        if viewModel.blurScore > 80 {
            return .green
        } else if viewModel.blurScore > 60 {
            return .orange
        } else {
            return .red
        }
    }

    private var faceDetectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Face Detection")
                .font(.headline)

            if viewModel.detectedFaces.isEmpty {
                CardView {
                    HStack {
                        Image(systemName: "face.dashed")
                            .foregroundStyle(.secondary)
                        Text("No faces detected")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            } else {
                ForEach(Array(viewModel.detectedFaces.enumerated()), id: \.offset) { index, face in
                    FaceInfoCard(face: face, index: index)
                }
            }
        }
    }

    // MARK: - Events Tab

    private var eventsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Current Status
                currentStatusSection

                // Exposure Lock Events
                eventLogSection(
                    title: "Exposure Lock Events",
                    events: viewModel.exposureLockEvents,
                    emptyMessage: "No exposure lock events"
                )

                // White Balance Events (if tracked)
                eventLogSection(
                    title: "White Balance Events",
                    events: viewModel.whiteBalanceLockEvents,
                    emptyMessage: "No white balance events"
                )
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
    }

    private var currentStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Status")
                .font(.headline)

            CardView {
                VStack(spacing: 12) {
                    StatusRow(
                        title: "Exposure",
                        isLocked: viewModel.isExposureLocked,
                        icon: "sun.max.fill"
                    )

                    Divider()

                    StatusRow(
                        title: "White Balance",
                        isLocked: viewModel.isWhiteBalanceLocked,
                        icon: "circle.lefthalf.filled"
                    )
                }
                .padding()
            }
        }
    }

    private func eventLogSection(title: String, events: [CameraEvent], emptyMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if events.isEmpty {
                CardView {
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            } else {
                ForEach(events) { event in
                    EventRow(event: event)
                }
            }
        }
    }

    // MARK: - Performance Tab

    private var performanceTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // FPS and Latency
                performanceMetricsSection

                // Frame Statistics
                frameStatsSection
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
    }

    private var performanceMetricsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Real-Time Performance")
                .font(.headline)

            VStack(spacing: 12) {
                MetricCard(
                    title: "FPS",
                    value: String(format: "%.1f", viewModel.currentFPS),
                    subtitle: fpsStatus,
                    icon: "speedometer",
                    color: fpsColor
                )

                HStack(spacing: 12) {
                    MetricCard(
                        title: "Current Latency",
                        value: String(format: "%.1f ms", viewModel.processingLatency),
                        subtitle: latencyStatus,
                        icon: "timer",
                        color: latencyColor
                    )

                    MetricCard(
                        title: "Avg Latency",
                        value: String(format: "%.1f ms", viewModel.averageLatency),
                        subtitle: "30-frame avg",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .blue
                    )
                }
            }
        }
    }

    private var fpsStatus: String {
        if viewModel.currentFPS >= 30 {
            return "Excellent"
        } else if viewModel.currentFPS >= 24 {
            return "Good"
        } else {
            return "Low"
        }
    }

    private var fpsColor: Color {
        if viewModel.currentFPS >= 30 {
            return .green
        } else if viewModel.currentFPS >= 24 {
            return .orange
        } else {
            return .red
        }
    }

    private var latencyStatus: String {
        if viewModel.processingLatency < 33 {
            return "< 33ms (30fps)"
        } else if viewModel.processingLatency < 50 {
            return "< 50ms (20fps)"
        } else {
            return "High"
        }
    }

    private var latencyColor: Color {
        if viewModel.processingLatency < 33 {
            return .green
        } else if viewModel.processingLatency < 50 {
            return .orange
        } else {
            return .red
        }
    }

    private var frameStatsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frame Statistics")
                .font(.headline)

            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    DebugStatRow(title: "Total Frames", value: "\(viewModel.frameCount)")
                    DebugStatRow(title: "Faces Detected", value: "\(viewModel.detectedFaces.count)")
                    DebugStatRow(title: "ROI Sets", value: "\(viewModel.faceROIs.count)")
                }
                .padding()
            }
        }
    }
}

// MARK: - Supporting Views

struct PerformanceHUD: View {
    let fps: Double
    let latency: Double
    let frameCount: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(String(format: "%.1f FPS", fps))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.green)

            Text(String(format: "%.1f ms", latency))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.cyan)

            Text("#\(frameCount)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        CardView {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}

struct FaceInfoCard: View {
    let face: FaceDetectionResult
    let index: Int

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Face \(index + 1)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text(String(format: "%.0f%% confidence", face.confidence * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                if let roll = face.roll {
                    DebugStatRow(title: "Roll", value: String(format: "%.1f°", roll))
                }
                if let yaw = face.yaw {
                    DebugStatRow(title: "Yaw", value: String(format: "%.1f°", yaw))
                }
                if let pitch = face.pitch {
                    DebugStatRow(title: "Pitch", value: String(format: "%.1f°", pitch))
                }
            }
            .padding()
        }
    }
}

struct StatusRow: View {
    let title: String
    let isLocked: Bool
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isLocked ? .green : .orange)

            Text(title)
                .font(.subheadline)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.caption)

                Text(isLocked ? "Locked" : "Unlocked")
                    .font(.caption)
            }
            .foregroundColor(isLocked ? .green : .orange)
        }
    }
}

struct EventRow: View {
    let event: CameraEvent

    var body: some View {
        CardView {
            HStack {
                Image(systemName: event.type.icon)
                    .foregroundColor(event.type.color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(event.relativeTime)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(event.formattedTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

struct DebugStatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - ROI Metrics Popup

struct ROIMetricsPopup: View {
    let roiSet: FaceROISet
    let roiType: ROIType
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 16) {
                // Header
                HStack {
                    Text(roiType.displayName)
                        .font(.headline)

                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // ROI Info
                if let roi = roiSet.rois[roiType] {
                    VStack(alignment: .leading, spacing: 12) {
                        DebugInfoRow(label: "Center", value: String(format: "(%.2f, %.2f)", roi.normalizedRect.midX, roi.normalizedRect.midY))
                        DebugInfoRow(label: "Size", value: String(format: "%.1f × %.1f", roi.normalizedRect.width, roi.normalizedRect.height))
                        DebugInfoRow(label: "Area", value: String(format: "%.4f", roi.normalizedRect.width * roi.normalizedRect.height))

                        Divider()

                        Text("Tap ROI after analysis to see metrics")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: 300)
            .frame(height: 250)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 20)
        }
    }
}

struct DebugInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DebugScreen(cameraSession: CameraSession())
    }
}
