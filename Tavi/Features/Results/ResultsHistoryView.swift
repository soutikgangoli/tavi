//
//  ResultsHistoryView.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI
import CoreData

/// History list showing all past skin analysis sessions
struct ResultsHistoryView: View {

    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SessionResult.date, ascending: false)],
        animation: .default
    )
    private var sessions: FetchedResults<SessionResult>

    @State private var sessionToDelete: SessionResult?
    @State private var showingDeleteAlert = false
    @State private var selectedSession: SessionResult?
    @State private var selectedTimeFilter: TimeFilter = .all
    @State private var errorState: ErrorState?

    enum TimeFilter: String, CaseIterable {
        case all = "All"
        case last30Days = "Last 30 Days"
        case last3Months = "Last 3 Months"

        var daysBack: Int? {
            switch self {
            case .all: return nil
            case .last30Days: return 30
            case .last3Months: return 90
            }
        }
    }

    private var filteredSessions: [SessionResult] {
        guard let daysBack = selectedTimeFilter.daysBack else {
            return Array(sessions)
        }

        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -daysBack, to: Date())!

        return sessions.filter { $0.date >= cutoffDate }
    }

    var body: some View {
        Group {
            if let error = errorState {
                errorView(error)
            } else {
                contentView
            }
        }
        .navigationTitle("Analysis History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    InsightsTabView()
                } label: {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                }
            }
        }
        .alert("Delete Session", isPresented: $showingDeleteAlert, presenting: sessionToDelete) { session in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSession(session)
            }
        } message: { session in
            Text("Are you sure you want to delete the session from \(session.formattedDate)?")
        }
        .sheet(item: $selectedSession) { session in
            NavigationStack {
                ResultsDetailView(session: session)
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        ZStack {
            if sessions.isEmpty {
                emptyStateView
            } else {
                sessionsList
            }
        }
    }

    // MARK: - Error View

    private func errorView(_ error: ErrorState) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Unable to Load History")
                .font(.title2)
                .fontWeight(.semibold)

            Text(error.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                errorState = nil
            } label: {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top)
        }
        .padding()
    }

    // MARK: - Sessions List

    private var sessionsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeadspaceDesign.Spacing.lg) {
                // Filter chips
                filterChipsView

                // Sessions list
                LazyVStack(spacing: 16) {
                    ForEach(filteredSessions, id: \.id) { session in
                        enhancedSessionCard(session)
                            .contextMenu {
                                Button(role: .destructive) {
                                    sessionToDelete = session
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .padding()
        }
        .refreshable {
            // Refresh all CoreData objects from persistent store
            viewContext.refreshAllObjects()
        }
    }

    // MARK: - Filter Chips

    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HeadspaceDesign.Spacing.sm) {
                ForEach(TimeFilter.allCases, id: \.self) { filter in
                    filterChip(filter)
                }
            }
        }
    }

    private func filterChip(_ filter: TimeFilter) -> some View {
        Button {
            selectedTimeFilter = filter
        } label: {
            Text(filter.rawValue)
                .font(.system(size: 14, weight: selectedTimeFilter == filter ? .semibold : .medium, design: .rounded))
                .foregroundColor(
                    selectedTimeFilter == filter
                    ? .white
                    : HeadspaceDesign.Colors.textPrimary
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    selectedTimeFilter == filter
                    ? HeadspaceDesign.Colors.primary
                    : HeadspaceDesign.Colors.textSecondary.opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Enhanced Session Card

    private func enhancedSessionCard(_ session: SessionResult) -> some View {
        VStack(spacing: 0) {
            // Main content
            Button {
                selectedSession = session
            } label: {
                HStack(spacing: 12) {
                    // Score circle
                    ZStack {
                        Circle()
                            .fill(scoreColor(session.overallScore).opacity(0.15))
                            .frame(width: 50, height: 50)

                        Text("\(Int(session.overallScore))")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(scoreColor(session.overallScore))
                    }

                    // Name, Date Time, Score% in one line
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.relativeDate)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.textPrimary)

                        Text(formattedDateTime(session.date))
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(HeadspaceDesign.Colors.textSecondary)
                    }

                    Spacer()

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(HeadspaceDesign.Colors.textTertiary)
                }
                .padding(HeadspaceDesign.Spacing.md)
            }
            .buttonStyle(PlainButtonStyle())

            // Compare button (for non-latest scans)
            if let latestSession = sessions.first, session.id != latestSession.id {
                Divider()

                NavigationLink {
                    Comparison3DView(
                        beforeSession: session,
                        afterSession: latestSession
                    )
                } label: {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 14, weight: .semibold))

                        Text("Compare with Latest")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(HeadspaceDesign.Colors.primary)
                    .padding(HeadspaceDesign.Spacing.sm)
                    .padding(.horizontal, HeadspaceDesign.Spacing.xs)
                }
            }
        }
        .background(HeadspaceDesign.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: HeadspaceDesign.Radius.md))
        .shadow(
            color: HeadspaceDesign.Shadows.card.color.opacity(0.5),
            radius: HeadspaceDesign.Shadows.card.radius / 2,
            x: HeadspaceDesign.Shadows.card.x,
            y: HeadspaceDesign.Shadows.card.y
        )
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 90...100: return Color(red: 76/255, green: 217/255, blue: 100/255)
        case 80..<90: return Color(red: 101/255, green: 188/255, blue: 126/255)
        case 50..<80: return Color(red: 149/255, green: 218/255, blue: 176/255)
        case 30..<50: return Color(red: 255/255, green: 204/255, blue: 0/255)
        default: return Color(red: 255/255, green: 59/255, blue: 48/255)
        }
    }

    private func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()

        // Get day with ordinal suffix (1st, 2nd, 3rd, etc.)
        let day = Calendar.current.component(.day, from: date)
        let daySuffix = ordinalSuffix(for: day)

        // Format: "19th May 3pm"
        formatter.dateFormat = "d'\(daySuffix)' MMM ha"

        return formatter.string(from: date).lowercased()
    }

    private func ordinalSuffix(for day: Int) -> String {
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "face.smiling")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            Text("No Analysis Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Complete your first skin analysis\nto see your results here")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Actions

    private func deleteSession(_ session: SessionResult) {
        withAnimation {
            viewContext.delete(session)
            do {
                try viewContext.save()
            } catch {
                handleError(error, context: "deleting session")
            }
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error, context: String) {
        AppLogger.ui.error("ResultsHistoryView error (\(context)): \(error)")
        CrashReporter.shared.logError(error, context: ["view": "ResultsHistoryView", "operation": context])
        errorState = ErrorState(
            message: "Unable to \(context). Please try again.",
            error: error
        )
    }

    private struct ErrorState {
        let message: String
        let error: Error
    }
}

// MARK: - Session Card

struct SessionCard: View {

    let session: SessionResult

    var body: some View {
        HStack(spacing: 12) {
            // Name, Date Time, Score% in one line
            Text(compactDisplayText)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scan from \(session.relativeDate), overall score \(Int(session.overallScore)) percent")
        .accessibilityHint("Double tap to view detailed results")
        .accessibilityAddTraits(.isButton)
    }

    private var compactDisplayText: String {
        let name = UserProfileManager.shared.loadProfile().name ?? "User"
        let dateString = formattedDateTime
        let scoreString = "\(Int(session.overallScore))%"

        return "\(name), \(dateString), \(scoreString)"
    }

    private var formattedDateTime: String {
        let date = session.date
        let formatter = DateFormatter()

        // Get day with ordinal suffix (1st, 2nd, 3rd, etc.)
        let day = Calendar.current.component(.day, from: date)
        let daySuffix = ordinalSuffix(for: day)

        // Format: "19th May 3pm"
        formatter.dateFormat = "d'\(daySuffix)' MMM ha"

        return formatter.string(from: date).lowercased() // "3pm" instead of "3PM"
    }

    private func ordinalSuffix(for day: Int) -> String {
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }
}

// MARK: - Grade Badge

struct GradeBadge: View {

    let grade: ScoreGrade

    var body: some View {
        Text(grade.rawValue)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(gradeColor.opacity(0.2))
            .foregroundColor(gradeColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var gradeColor: Color {
        switch grade {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .veryPoor: return .red
        }
    }
}

// MARK: - Preview

#Preview("With Data") {
    NavigationStack {
        ResultsHistoryView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}

#Preview("Empty State") {
    let controller = PersistenceController(inMemory: true)
    return NavigationStack {
        ResultsHistoryView()
            .environment(\.managedObjectContext, controller.viewContext)
    }
}
