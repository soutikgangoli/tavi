//
//  MemoryDiagnosticsView.swift
//  Ollvy
//
//  Memory monitoring and diagnostics UI for developers and advanced users
//  Created on 2025-11-04.
//

import SwiftUI
import Charts

/// Real-time memory diagnostics and management interface
public struct MemoryDiagnosticsView: View {

    @StateObject private var monitor = AdvancedMemoryMonitor.shared
    @StateObject private var budgetManager = MemoryBudgetManager.shared
    @StateObject private var resourceManager = MemoryResourceManager.shared

    @State private var refreshTimer: Timer?

    public var body: some View {
        List {
            // Overall Status
            overallStatusSection

            // Memory Budgets
            budgetSection

            // Managed Resources
            resourcesSection

            // Actions
            actionsSection

            // Device Info
            deviceInfoSection
        }
        .navigationTitle("Memory Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            startRefreshing()
        }
        .onDisappear {
            stopRefreshing()
        }
    }

    // MARK: - Sections

    private var overallStatusSection: some View {
        Section {
            if let stats = monitor.currentStats {
                VStack(spacing: 16) {
                    // Pressure Indicator
                    HStack {
                        Image(systemName: pressureIcon(stats.pressure))
                            .font(.title2)
                            .foregroundStyle(pressureColor(stats.pressure))

                        VStack(alignment: .leading) {
                            Text("Memory Pressure")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(stats.pressure.description)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text(stats.formattedUsed)
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("of \(stats.formattedTotal)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Usage Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(.quaternary)

                            Rectangle()
                                .fill(pressureGradient(stats.pressure))
                                .frame(width: geometry.size.width * (stats.usagePercentage / 100))
                        }
                        .frame(height: 8)
                        .clipShape(Capsule())
                    }
                    .frame(height: 8)

                    // Percentage
                    Text("\(String(format: "%.1f", stats.usagePercentage))% Used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                Text("Memory stats unavailable")
                    .foregroundStyle(.secondary)
            }
        } header: {
            HStack {
                Text("Overall Status")
                Spacer()
                if monitor.isMonitoring {
                    if #available(iOS 17.0, *) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .symbolEffect(.variableColor.iterative)
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }

    private var budgetSection: some View {
        Section {
            ForEach(budgetManager.getComponentsByPriority(), id: \.component) { budget in
                BudgetRow(budget: budget)
            }

            // Total
            HStack {
                Text("Total Budget")
                    .fontWeight(.semibold)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(String(format: "%.1f", budgetManager.totalAllocatedMB)) MB")
                        .fontWeight(.semibold)
                    Text("of \(String(format: "%.1f", budgetManager.totalBudgetMB)) MB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Component Budgets")
        } footer: {
            Text("Memory budgets prevent individual components from using too much memory.")
        }
    }

    private var resourcesSection: some View {
        Section {
            if resourceManager.registeredResources.isEmpty {
                Text("No managed resources")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(resourceManager.getAllMetadata(), id: \.identifier) { metadata in
                    ResourceRow(metadata: metadata)
                }

                // Summary
                HStack {
                    Text("Total Managed")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(String(format: "%.1f", resourceManager.getLoadedMemoryMB())) MB")
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Managed Resources")
        } footer: {
            Text("These resources can be automatically released under memory pressure.")
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                monitor.forceCleanup(atPressure: .moderate)
            } label: {
                Label("Release Low Priority Resources", systemImage: "trash")
            }

            Button {
                monitor.forceCleanup(atPressure: .high)
            } label: {
                Label("Release Medium Priority Resources", systemImage: "trash.fill")
            }
            .foregroundStyle(.orange)

            Button(role: .destructive) {
                monitor.forceCleanup(atPressure: .critical)
            } label: {
                Label("Force Critical Cleanup", systemImage: "exclamationmark.triangle.fill")
            }
        } header: {
            Text("Manual Actions")
        } footer: {
            Text("Use these to manually free memory. The app will automatically reload data when needed.")
        }
    }

    private var deviceInfoSection: some View {
        Section("Device Information") {
            InfoRow(
                label: "Total Memory",
                value: String(format: "%.2f GB", Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0)
            )

            InfoRow(
                label: "Device Model",
                value: UIDevice.current.model
            )

            InfoRow(
                label: "iOS Version",
                value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
            )
        }
    }

    // MARK: - Helper Methods

    private func pressureIcon(_ pressure: AdvancedMemoryMonitor.MemoryPressure) -> String {
        switch pressure {
        case .normal: return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.circle.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    private func pressureColor(_ pressure: AdvancedMemoryMonitor.MemoryPressure) -> Color {
        switch pressure {
        case .normal: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }

    private func pressureGradient(_ pressure: AdvancedMemoryMonitor.MemoryPressure) -> LinearGradient {
        switch pressure {
        case .normal:
            return LinearGradient(colors: [.green, .green], startPoint: .leading, endPoint: .trailing)
        case .moderate:
            return LinearGradient(colors: [.green, .yellow], startPoint: .leading, endPoint: .trailing)
        case .high:
            return LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
        case .critical:
            return LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
        }
    }

    private func startRefreshing() {
        // Start memory monitoring
        if !monitor.isMonitoring {
            monitor.startMonitoring()
        }

        // Refresh UI every 2 seconds
        // FIXED: Use DispatchQueue.main.async instead of Task { @MainActor } to ensure
        // state updates are deferred to next run loop, avoiding "Publishing changes" warnings
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            DispatchQueue.main.async {
                // Force UI update
                _ = monitor.getMemoryStats()
            }
        }
    }

    private func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Supporting Views

private struct BudgetRow: View {
    let budget: MemoryBudgetManager.Budget

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(budget.component)
                    .font(.body)
                Spacer()
                Text("\(String(format: "%.1f", budget.allocatedMB)) / \(String(format: "%.1f", budget.maxMB)) MB")
                    .font(.caption)
                    .foregroundStyle(budget.isOverBudget ? .red : .secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.quaternary)

                    Rectangle()
                        .fill(budget.isOverBudget ? Color.red : Color.blue)
                        .frame(width: geometry.size.width * min(1.0, budget.utilizationPercentage / 100))
                }
                .frame(height: 4)
                .clipShape(Capsule())
            }
            .frame(height: 4)
        }
        .padding(.vertical, 4)
    }
}

private struct ResourceRow: View {
    let metadata: ResourceMetadata

    var body: some View {
        HStack {
            Circle()
                .fill(metadata.isLoaded ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(metadata.identifier)
                    .font(.caption)
                Text("\(String(format: "%.2f", metadata.estimatedSizeMB)) MB · Priority: \(String(describing: metadata.priority))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !metadata.isLoaded {
                Text("Released")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MemoryDiagnosticsView()
    }
}
