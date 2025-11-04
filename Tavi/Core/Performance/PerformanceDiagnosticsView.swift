//
//  PerformanceDiagnosticsView.swift
//  Tavi
//
//  Real-time performance monitoring and bottleneck visualization
//  Created on 2025-11-04.
//

import SwiftUI
import Charts

/// Performance diagnostics and profiling UI
public struct PerformanceDiagnosticsView: View {

    @State private var analyzer = PerformanceAnalyzer.shared
    @State private var measurements: [PerformanceAnalyzer.Measurement] = []
    @State private var sequentialOps: [PerformanceAnalyzer.SequentialOperation] = []
    @State private var isProfilingEnabled = false
    @State private var showingReport = false
    @State private var reportText = ""

    public var body: some View {
        List {
            // Profiling Control
            profilingControlSection

            // Sequential Operations (Bottlenecks)
            if !sequentialOps.isEmpty {
                bottlenecksSection
            }

            // Recent Measurements
            if !measurements.isEmpty {
                measurementsSection
            }

            // Statistics
            if !measurements.isEmpty {
                statisticsSection
            }

            // Actions
            actionsSection
        }
        .navigationTitle("Performance Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingReport) {
            ReportView(reportText: reportText)
        }
        .onAppear {
            refreshData()
        }
    }

    // MARK: - Sections

    private var profilingControlSection: some View {
        Section {
            Toggle("Enable Profiling", isOn: $isProfilingEnabled)
                .onChange(of: isProfilingEnabled) { _, newValue in
                    if newValue {
                        analyzer.enableProfiling()
                    } else {
                        analyzer.disableProfiling()
                    }
                }

            if isProfilingEnabled {
                HStack {
                    Image(systemName: "record.circle")
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse)
                    Text("Recording...")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh") {
                        refreshData()
                    }
                }
            }
        } header: {
            Text("Profiling")
        } footer: {
            Text("Enable profiling to track operation performance. Profiling adds minimal overhead (~0.1ms per operation).")
        }
    }

    private var bottlenecksSection: some View {
        Section {
            ForEach(sequentialOps, id: \.location) { op in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(op.location)
                            .font(.headline)
                        Spacer()
                        priorityBadge(for: op)
                    }

                    HStack {
                        Label("\(op.operationCount) ops", systemImage: "repeat")
                        Spacer()
                        Label(formatDuration(op.totalDuration), systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if op.canParallelize {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(.yellow)
                            Text("Potential speedup: \(String(format: "%.1f", op.estimatedSpeedup))x")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    } else {
                        HStack {
                            Image(systemName: "link")
                                .foregroundStyle(.gray)
                            Text("Dependencies prevent parallelization")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            HStack {
                Text("Sequential Operations")
                Spacer()
                Text("\(sequentialOps.count)")
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("Operations that could benefit from parallelization are highlighted by priority.")
        }
    }

    private var measurementsSection: some View {
        Section {
            ForEach(measurements.prefix(20), id: \.timestamp) { measurement in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(measurement.operation)
                            .font(.caption)
                        Text(measurement.threadInfo)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(measurement.formattedDuration)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(colorForDuration(measurement.duration))
                }
            }
        } header: {
            HStack {
                Text("Recent Operations")
                Spacer()
                Text("\(measurements.count) total")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statisticsSection: some View {
        Section("Statistics") {
            let totalDuration = measurements.reduce(0) { $0 + $1.duration }
            let avgDuration = totalDuration / Double(measurements.count)
            let slowest = measurements.max(by: { $0.duration < $1.duration })

            StatRow(label: "Total Time", value: formatDuration(totalDuration))
            StatRow(label: "Average Time", value: formatDuration(avgDuration))
            StatRow(label: "Operations", value: "\(measurements.count)")

            if let slowest = slowest {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Slowest Operation")
                        .foregroundStyle(.secondary)
                    Text(slowest.operation)
                        .font(.caption)
                    Text(slowest.formattedDuration)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button {
                generateReport()
            } label: {
                Label("Generate Report", systemImage: "doc.text")
            }
            .disabled(measurements.isEmpty)

            Button(role: .destructive) {
                clearData()
            } label: {
                Label("Clear Data", systemImage: "trash")
            }
            .disabled(measurements.isEmpty)
        }
    }

    // MARK: - Helper Methods

    private func priorityBadge(for op: PerformanceAnalyzer.SequentialOperation) -> some View {
        Group {
            if op.estimatedSpeedup > 3.0 {
                Text("High Priority")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.2))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
            } else if op.estimatedSpeedup > 2.0 {
                Text("Medium Priority")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            } else {
                Text("Low Priority")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }
        }
    }

    private func colorForDuration(_ duration: TimeInterval) -> Color {
        if duration > 0.5 {
            return .red
        } else if duration > 0.1 {
            return .orange
        } else {
            return .secondary
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 0.001 {
            return String(format: "%.3f ms", duration * 1000)
        } else if duration < 1.0 {
            return String(format: "%.1f ms", duration * 1000)
        } else {
            return String(format: "%.2f s", duration)
        }
    }

    private func refreshData() {
        measurements = analyzer.getMeasurements()
        sequentialOps = analyzer.analyzeSequentialOperations()
    }

    private func generateReport() {
        reportText = analyzer.generateReport()
        showingReport = true
    }

    private func clearData() {
        analyzer.clearMeasurements()
        refreshData()
    }
}

// MARK: - Supporting Views

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

private struct ReportView: View {
    @Environment(\.dismiss) private var dismiss
    let reportText: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(reportText)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Performance Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: reportText)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PerformanceDiagnosticsView()
    }
}
