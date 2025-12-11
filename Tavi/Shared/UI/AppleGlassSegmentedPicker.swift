//
//  AppleGlassSegmentedPicker.swift
//  Tavi
//
//  Apple-style glass segmented picker with smooth sliding animation
//  Created on 2025-12-11.
//

import SwiftUI

/// Apple-style glass segmented picker with smooth sliding capsule animation
/// Mimics the iOS Settings app segmented control appearance
struct AppleGlassSegmentedPicker<Option: Hashable, Content: View>: View {
    @Binding var selection: Option
    let options: [Option]
    let content: (Option) -> Content

    init(
        selection: Binding<Option>,
        options: [Option],
        @ViewBuilder content: @escaping (Option) -> Content
    ) {
        self._selection = selection
        self.options = options
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let segmentWidth = geometry.size.width / CGFloat(options.count)
            let selectedIndex = options.firstIndex(of: selection) ?? 0

            ZStack(alignment: .leading) {
                // Sliding selector capsule (behind content)
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.06), radius: 1, x: 0, y: 1)
                    .shadow(color: Color.black.opacity(0.04), radius: 0.5, x: 0, y: 0)
                    .frame(width: segmentWidth - 4, height: geometry.size.height - 4)
                    .offset(x: CGFloat(selectedIndex) * segmentWidth + 2)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selection)

                // Content layer (on top, never blurred)
                HStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selection = option
                            }
                        } label: {
                            content(option)
                                .font(.system(size: 13, weight: selection == option ? .semibold : .medium))
                                .foregroundColor(selection == option ? .primary : .secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: geometry.size.height)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .frame(height: 32)
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Preview

#Preview("Heatmap Picker") {
    struct PreviewWrapper: View {
        @State private var selected: HeatmapType = .composite

        var body: some View {
            VStack(spacing: 20) {
                AppleGlassSegmentedPicker(
                    selection: $selected,
                    options: HeatmapType.allCases
                ) { type in
                    Text(type.displayName)
                }
                .padding(.horizontal)

                Text("Selected: \(selected.displayName)")
            }
            .padding()
        }
    }

    return PreviewWrapper()
}

#Preview("Two Options") {
    struct PreviewWrapper: View {
        @State private var selected = 0

        var body: some View {
            AppleGlassSegmentedPicker(
                selection: $selected,
                options: [0, 1]
            ) { option in
                Text(option == 0 ? "Day" : "Night")
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
