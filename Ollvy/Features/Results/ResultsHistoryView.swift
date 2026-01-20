//
//  ResultsHistoryView.swift
//  Ollvy
//
//  Gentler Streak themed history view
//  Created on 2025-10-27.
//

import SwiftUI
import CoreData

/// History list showing all past skin analysis sessions (Gentler Streak theme)
struct ResultsHistoryView: View {

    @Environment(\.managedObjectContext) private var viewContext

    // Gentler Streak colors
    private let gsBackground = Designs.GentlerStreak.background
    private let gsTextPrimary = Designs.GentlerStreak.textPrimary
    private let gsTextSecondary = Designs.GentlerStreak.textSecondary
    private let gsAccentCoral = Designs.GentlerStreak.accentCoral
    private let gsAccentTeal = Designs.GentlerStreak.accentTeal
    private let gsCardBackground = Designs.GentlerStreak.cardBackground

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
        // Filter out any deleted/faulted objects to prevent crashes
        let validSessions = sessions.filter { !$0.isDeleted && !$0.isFault }

        guard let daysBack = selectedTimeFilter.daysBack else {
            return validSessions
        }

        let calendar = Calendar.current
        // Safely handle calendar date calculation - fallback to showing all if calculation fails
        guard let cutoffDate = calendar.date(byAdding: .day, value: -daysBack, to: Date()) else {
            return validSessions
        }

        return validSessions.filter { $0.date >= cutoffDate }
    }

    var body: some View {
        ZStack {
            // Full screen background
            Color.white.ignoresSafeArea()

            Group {
                if let error = errorState {
                    errorView(error)
                } else {
                    contentView
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    InsightsTabView()
                } label: {
                    ZStack {
                        Circle()
                            .fill(gsAccentCoral.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(gsAccentCoral)
                    }
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
                if !session.isDeleted && !session.isFault && viewContext.registeredObject(for: session.objectID) != nil {
                    ResultsDetailView(session: session)
                        .environment(\.managedObjectContext, viewContext)
                        .onDisappear {
                            // Clear selection when sheet dismisses
                            selectedSession = nil
                        }
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
                    // Auto-dismiss if session was deleted
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            selectedSession = nil
                        }
                    }
                }
            }
        }
        // Safeguard: Clear invalid session reference when sessions change
        .onChange(of: sessions.count) { _, _ in
            if let selected = selectedSession,
               selected.isDeleted || selected.isFault {
                selectedSession = nil
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

    // MARK: - Filter Chips (Gentler Streak Style)

    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TimeFilter.allCases, id: \.self) { filter in
                    filterChip(filter)
                }
            }
        }
    }

    private func filterChip(_ filter: TimeFilter) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTimeFilter = filter
            }
        } label: {
            Text(filter.rawValue)
                .font(.system(size: 14, weight: selectedTimeFilter == filter ? .semibold : .medium, design: .rounded))
                .foregroundColor(
                    selectedTimeFilter == filter
                    ? .white
                    : gsTextPrimary
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    selectedTimeFilter == filter
                    ? gsAccentCoral
                    : gsTextSecondary.opacity(0.1)
                )
                .clipShape(Capsule())
        }
    }

    // MARK: - Enhanced Session Card (Gentler Streak Style)

    private func enhancedSessionCard(_ session: SessionResult) -> some View {
        // Guard against deleted sessions
        let isValidSession = !session.isDeleted && !session.isFault
        let score = isValidSession ? session.overallScore : 0
        let dateText = isValidSession ? session.relativeDate : ""
        let dateTimeText = isValidSession ? formattedDateTime(session.date) : ""

        return VStack(spacing: 0) {
            // Main content
            Button {
                guard isValidSession else { return }
                selectedSession = session
            } label: {
                HStack(spacing: 14) {
                    // Score circle
                    ZStack {
                        Circle()
                            .fill(gentlerScoreColor(score).opacity(0.15))
                            .frame(width: 52, height: 52)

                        Text("\(Int(score))")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(gentlerScoreColor(score))
                    }

                    // Name, Date Time
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateText)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(gsTextPrimary)

                        Text(dateTimeText)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(gsTextSecondary)
                    }

                    Spacer()

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(gsTextSecondary)
                }
                .padding(16)
            }
            .buttonStyle(PlainButtonStyle())

            // Compare button (for non-latest scans)
            // Check both sessions are valid (not deleted) before showing comparison
            if let latestSession = sessions.first,
               !session.isDeleted && !latestSession.isDeleted,
               session.id != latestSession.id {
                Rectangle()
                    .fill(gsTextSecondary.opacity(0.1))
                    .frame(height: 1)

                NavigationLink {
                    Comparison3DView(
                        beforeSession: session,
                        afterSession: latestSession
                    )
                } label: {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 14, weight: .medium))

                        Text("Compare with Latest")
                            .font(.system(size: 14, weight: .medium))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(gsAccentTeal)
                    .padding(12)
                    .padding(.horizontal, 4)
                }
            }
        }
        .background(gsCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private func gentlerScoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return Designs.GentlerStreak.softGreen
        case 60..<80: return Designs.GentlerStreak.softYellow
        default: return Designs.GentlerStreak.softRed
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

    // MARK: - Empty State (Gentler Streak Style - Curved Card)

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Curved empty state card
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(gsAccentCoral.opacity(0.12))
                        .frame(width: 100, height: 100)

                    Image(systemName: "face.smiling")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(gsAccentCoral)
                }

                VStack(spacing: 8) {
                    Text("No History Yet")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(gsTextPrimary)

                    Text("Complete your first skin scan\nto see your results here")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(gsTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 32) // More curved for empty state
                    .fill(gsCardBackground)
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            )
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Actions

    private func deleteSession(_ session: SessionResult) {
        // Clear any references to the session being deleted to prevent crashes
        if selectedSession?.id == session.id {
            selectedSession = nil
        }
        if sessionToDelete?.id == session.id {
            sessionToDelete = nil
        }

        // Perform deletion with animation
        withAnimation {
            // Check if session is still valid before deleting
            guard !session.isDeleted else { return }

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

    // Guard against deleted/faulted sessions
    private var isValidSession: Bool {
        !session.isDeleted && !session.isFault
    }

    var body: some View {
        // Return empty view if session is deleted
        if !isValidSession {
            EmptyView()
        } else {
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
    }

    private var compactDisplayText: String {
        guard isValidSession else { return "" }
        let name = UserProfileManager.shared.loadProfile().name ?? "User"
        let dateString = formattedDateTime
        let scoreString = "\(Int(session.overallScore))%"

        return "\(name), \(dateString), \(scoreString)"
    }

    private var formattedDateTime: String {
        guard isValidSession else { return "" }
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
