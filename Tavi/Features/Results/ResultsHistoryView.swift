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
    @State private var errorState: ErrorState?

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
            LazyVStack(spacing: 16) {
                ForEach(sessions) { session in
                    SessionCard(session: session)
                        .onTapGesture {
                            selectedSession = session
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
            .padding()
        }
        .refreshable {
            // Refresh all CoreData objects from persistent store
            viewContext.refreshAllObjects()
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
