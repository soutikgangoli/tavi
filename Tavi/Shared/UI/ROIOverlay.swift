//
//  ROIOverlay.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

// MARK: - ROI Overlay

public struct ROIOverlay: View {
    let roiSets: [FaceROISet]
    let imageSize: CGSize
    let viewSize: CGSize
    let isMirrored: Bool
    let showLabels: Bool

    public init(
        roiSets: [FaceROISet],
        imageSize: CGSize,
        viewSize: CGSize,
        isMirrored: Bool = false,
        showLabels: Bool = true
    ) {
        self.roiSets = roiSets
        self.imageSize = imageSize
        self.viewSize = viewSize
        self.isMirrored = isMirrored
        self.showLabels = showLabels
    }

    public var body: some View {
        ZStack {
            ForEach(Array(roiSets.enumerated()), id: \.offset) { _, roiSet in
                ROISetView(
                    roiSet: roiSet,
                    imageSize: imageSize,
                    viewSize: viewSize,
                    isMirrored: isMirrored,
                    showLabels: showLabels
                )
            }
        }
    }
}

// MARK: - ROI Set View

struct ROISetView: View {
    let roiSet: FaceROISet
    let imageSize: CGSize
    let viewSize: CGSize
    let isMirrored: Bool
    let showLabels: Bool

    var body: some View {
        ZStack {
            ForEach(roiSet.allROIs, id: \.type.identifier) { roi in
                ROIRectangleView(
                    roi: roi,
                    imageSize: imageSize,
                    viewSize: viewSize,
                    isMirrored: isMirrored,
                    showLabel: showLabels
                )
            }
        }
    }
}

// MARK: - ROI Rectangle View

struct ROIRectangleView: View {
    let roi: ROIDisplayInfo
    let imageSize: CGSize
    let viewSize: CGSize
    let isMirrored: Bool
    let showLabel: Bool

    private var convertedRect: CGRect {
        ROIBuilder.convertROIToViewCoordinates(
            roi,
            imageSize: imageSize,
            viewSize: viewSize,
            isMirrored: isMirrored
        )
    }

    private var color: Color {
        switch roi.type {
        case .leftCheek:
            return .blue
        case .rightCheek:
            return .cyan
        case .forehead:
            return .purple
        case .chin:
            return .orange
        case .noseBridge:
            return .green
        }
    }

    var body: some View {
        ZStack {
            // ROI rectangle
            Rectangle()
                .stroke(color, lineWidth: 2)
                .frame(width: convertedRect.width, height: convertedRect.height)
                .position(x: convertedRect.midX, y: convertedRect.midY)

            // Corner markers
            CornerMarkers(rect: convertedRect, color: color)

            // Label
            if showLabel {
                ROILabel(roi: roi, rect: convertedRect, color: color)
            }

            // Center crosshair
            Crosshair(center: CGPoint(x: convertedRect.midX, y: convertedRect.midY), color: color)
        }
    }
}

// MARK: - Corner Markers

struct CornerMarkers: View {
    let rect: CGRect
    let color: Color
    let markerSize: CGFloat = 12

    var body: some View {
        ZStack {
            // Top-left
            CornerMarker(
                position: CGPoint(x: rect.minX, y: rect.minY),
                corners: [.topLeft],
                color: color,
                size: markerSize
            )

            // Top-right
            CornerMarker(
                position: CGPoint(x: rect.maxX, y: rect.minY),
                corners: [.topRight],
                color: color,
                size: markerSize
            )

            // Bottom-left
            CornerMarker(
                position: CGPoint(x: rect.minX, y: rect.maxY),
                corners: [.bottomLeft],
                color: color,
                size: markerSize
            )

            // Bottom-right
            CornerMarker(
                position: CGPoint(x: rect.maxX, y: rect.maxY),
                corners: [.bottomRight],
                color: color,
                size: markerSize
            )
        }
    }
}

struct CornerMarker: View {
    let position: CGPoint
    let corners: [Corner]
    let color: Color
    let size: CGFloat

    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    var body: some View {
        Path { path in
            for corner in corners {
                switch corner {
                case .topLeft:
                    path.move(to: CGPoint(x: position.x, y: position.y + size))
                    path.addLine(to: position)
                    path.addLine(to: CGPoint(x: position.x + size, y: position.y))
                case .topRight:
                    path.move(to: CGPoint(x: position.x - size, y: position.y))
                    path.addLine(to: position)
                    path.addLine(to: CGPoint(x: position.x, y: position.y + size))
                case .bottomLeft:
                    path.move(to: CGPoint(x: position.x, y: position.y - size))
                    path.addLine(to: position)
                    path.addLine(to: CGPoint(x: position.x + size, y: position.y))
                case .bottomRight:
                    path.move(to: CGPoint(x: position.x - size, y: position.y))
                    path.addLine(to: position)
                    path.addLine(to: CGPoint(x: position.x, y: position.y - size))
                }
            }
        }
        .stroke(color, lineWidth: 3)
    }
}

// MARK: - Crosshair

struct Crosshair: View {
    let center: CGPoint
    let color: Color
    let size: CGFloat = 8

    var body: some View {
        Path { path in
            // Horizontal line
            path.move(to: CGPoint(x: center.x - size, y: center.y))
            path.addLine(to: CGPoint(x: center.x + size, y: center.y))

            // Vertical line
            path.move(to: CGPoint(x: center.x, y: center.y - size))
            path.addLine(to: CGPoint(x: center.x, y: center.y + size))
        }
        .stroke(color, lineWidth: 2)
        .opacity(0.8)
    }
}

// MARK: - ROI Label

struct ROILabel: View {
    let roi: ROIDisplayInfo
    let rect: CGRect
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(roi.type.displayName)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text(String(format: "%.0f%%", roi.confidence * 100))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.9))
        .cornerRadius(6)
        .position(x: rect.midX, y: rect.minY - 25)
    }
}

// MARK: - ROI Info Panel

public struct ROIInfoPanel: View {
    let roiSet: FaceROISet

    public init(roiSet: FaceROISet) {
        self.roiSet = roiSet
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Regions of Interest")
                .font(.headline)
                .foregroundStyle(.white)

            Divider()
                .background(.white.opacity(0.3))

            // IPD info
            HStack {
                Text("Inter-Pupil Distance:")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(String(format: "%.1f px", roiSet.interPupilDistance))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
            }

            Divider()
                .background(.white.opacity(0.3))

            // ROI list
            ForEach(roiSet.allROIs.sorted(by: { $0.type.displayName < $1.type.displayName }), id: \.type.identifier) { roi in
                ROIInfoRow(roi: roi)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct ROIInfoRow: View {
    let roi: ROIDisplayInfo

    private var color: Color {
        switch roi.type {
        case .leftCheek: return .blue
        case .rightCheek: return .cyan
        case .forehead: return .purple
        case .chin: return .orange
        case .noseBridge: return .green
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Color indicator
            Rectangle()
                .fill(color)
                .frame(width: 4, height: 20)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 2) {
                Text(roi.type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    Text(String(format: "%.0f×%.0f", roi.imageRect.width, roi.imageRect.height))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))

                    Text(String(format: "%.1f IPD", roi.scaleFactorIPD))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    Text(String(format: "%.0f%%", roi.confidence * 100))
                        .font(.caption2)
                        .foregroundStyle(color)
                }
            }
        }
    }
}

// MARK: - ROI Legend

public struct ROILegend: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ROI Regions")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            ROILegendItem(color: .blue, label: "Left Cheek")
            ROILegendItem(color: .cyan, label: "Right Cheek")
            ROILegendItem(color: .purple, label: "Forehead")
            ROILegendItem(color: .orange, label: "Chin")
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct ROILegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(color)
                .frame(width: 16, height: 3)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Extracted ROI Grid

public struct ExtractedROIGrid: View {
    let extractedROIs: [ExtractedROIImage]
    let columns: Int

    public init(extractedROIs: [ExtractedROIImage], columns: Int = 2) {
        self.extractedROIs = extractedROIs
        self.columns = columns
    }

    private var gridItems: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: columns)
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(columns: gridItems, spacing: 16) {
                ForEach(extractedROIs, id: \.type.identifier) { extractedROI in
                    ExtractedROICard(extractedROI: extractedROI)
                }
            }
            .padding()
        }
    }
}

struct ExtractedROICard: View {
    let extractedROI: ExtractedROIImage

    private var color: Color {
        switch extractedROI.type {
        case .leftCheek: return .blue
        case .rightCheek: return .cyan
        case .forehead: return .purple
        case .chin: return .orange
        case .noseBridge: return .green
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Image
            Image(uiImage: UIImage(cgImage: extractedROI.image))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 150)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color, lineWidth: 2)
                )

            // Label
            VStack(spacing: 4) {
                Text(extractedROI.type.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)

                Text("\(Int(extractedROI.size.width))×\(Int(extractedROI.size.height))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            ROILegend()
                .padding()
        }
    }
}
