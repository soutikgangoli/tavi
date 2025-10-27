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

    var body: some View {
        ZStack {
            if sessions.isEmpty {
                emptyStateView
            } else {
                sessionsList
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
            try? viewContext.save()
        }
    }
}

// MARK: - Session Card

struct SessionCard: View {

    let session: SessionResult

    var body: some View {
        CardView {
            HStack(spacing: 16) {
                // Thumbnail
                thumbnailView

                // Info
                VStack(alignment: .leading, spacing: 8) {
                    // Date
                    Text(session.relativeDate)
                        .font(.headline)

                    // Score with grade
                    HStack(spacing: 8) {
                        Text("\(Int(session.overallScore))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor(for: session.overallScore))

                        GradeBadge(grade: session.grade)
                    }

                    // Device
                    Text(session.deviceModel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(4)
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnailImage = session.thumbnailImage {
            Image(uiImage: thumbnailImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "face.smiling")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func scoreColor(for score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
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
