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
                // Verify session is still valid before showing detail view
                if viewContext.registeredObject(for: session.objectID) != nil {
                    ResultsDetailView(session: session)
                        .environment(\.managedObjectContext, viewContext)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(AppFont.displayLight)
                            .foregroundColor(.orange)

                        Text("Session Not Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("This session may have been deleted or is no longer available.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button {
                            selectedSession = nil
                        } label: {
                            Text("Close")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: 200)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(Designs.Radius.medium)
                        }
                    }
                    .padding()
                }
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
                .font(AppFont.displayLight)
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
            VStack(alignment: .leading, spacing: Designs.Spacing.lg) {
                // Filter chips
                filterChipsView

                // Sessions list with swipe-to-delete
                LazyVStack(spacing: 16) {
                    ForEach(filteredSessions, id: \.id) { session in
                        enhancedSessionCard(session)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        deleteSession(session)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
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
            HStack(spacing: Designs.Spacing.sm) {
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
                .font(.app(size: 14, weight: selectedTimeFilter == filter ? .semibold : .medium, design: .rounded))
                .foregroundColor(
                    selectedTimeFilter == filter
                    ? .white
                    : Designs.Colors.textPrimary
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    selectedTimeFilter == filter
                    ? Designs.Colors.primary
                    : Designs.Colors.textSecondary.opacity(Designs.Opacity.veryLight)
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
                            .fill(scoreColor(session.overallScore).opacity(Designs.Opacity.veryLight + 0.05))
                            .frame(width: Designs.Sizes.frameWidthSmall, height: Designs.Sizes.frameWidthSmall)

                        Text("\(Int(session.overallScore))")
                            .font(AppFont.headlineSecondary)
                            .foregroundColor(scoreColor(session.overallScore))
                    }

                    // Name, Date Time, Score% in one line
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.relativeDate)
                            .font(AppFont.subheadingPrimary)
                            .foregroundColor(Designs.Colors.textPrimary)

                        Text(formattedDateTime(session.date))
                            .font(AppFont.caption)
                            .foregroundColor(Designs.Colors.textSecondary)
                    }

                    Spacer()

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(AppFont.metricLabel)
                        .foregroundColor(Designs.Colors.textTertiary)
                }
                .padding(Designs.Spacing.md)
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
                            .font(AppFont.metricLabel)

                        Text("Compare with Latest")
                            .font(AppFont.label)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(AppFont.captionSmall)
                    }
                    .foregroundColor(Designs.Colors.primary)
                    .padding(Designs.Spacing.sm)
                    .padding(.horizontal, Designs.Spacing.xs)
                }
            }
        }
        .background(Designs.Colors.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: Designs.Radius.md))
        .shadow(
            color: Designs.Shadows.card.color.opacity(Designs.Opacity.semiOpaque),
            radius: Designs.Shadows.card.radius / 2,
            x: Designs.Shadows.card.x,
            y: Designs.Shadows.card.y
        )
    }

    private func scoreColor(_ score: Double) -> Color {
        return Designs.ScoreColors.color(for: Int(score))
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
                .font(AppFont.scoreDisplayLarge)
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
            .background(gradeColor.opacity(Designs.Opacity.light))
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
