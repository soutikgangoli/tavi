//
//  SAVE_INTEGRATION_EXAMPLE.swift
//  Tavi
//
//  Example of how to integrate save functionality into CameraView
//  This is a REFERENCE file - not part of the actual app
//

import SwiftUI

/*
 EXAMPLE 1: Add Save Button After Analysis

 Add this to your CameraView after showing results
 */

struct CameraViewWithSaveExample: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var showingResults = false
    @State private var navigateToHistory = false

    var body: some View {
        VStack {
            // ... existing camera UI

            // After analysis completes, show save option
            if let scores = viewModel.lastScoreSummary {
                VStack(spacing: 16) {
                    // Show existing score summary
                    ScoreSummaryView(
                        scores: scores,
                        faceImage: viewModel.lastCaptureResult?.combinedImage,
                        roiSet: viewModel.lastCaptureResult?.roiSet,
                        isPresented: $showingResults
                    )

                    // Save button
                    saveButton

                    // Success message
                    if viewModel.sessionSaved {
                        successMessage
                    }
                }
                .padding()
            }
        }
        .navigationDestination(isPresented: $navigateToHistory) {
            ResultsHistoryView()
        }
    }

    private var saveButton: some View {
        PrimaryButton(title: viewModel.sessionSaved ? "Saved ✓" : "Save Results") {
            Task {
                await viewModel.saveSession()

                // Optional: Auto-navigate to history after save
                if viewModel.sessionSaved {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        navigateToHistory = true
                    }
                }
            }
        }
        .disabled(viewModel.saveInProgress || viewModel.sessionSaved)
    }

    private var successMessage: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)

            Text("Results saved successfully!")
                .font(.subheadline)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .transition(.scale.combined(with: .opacity))
    }
}

/*
 EXAMPLE 2: Results Modal with Save

 Show results in a modal sheet with save option
 */

struct CameraViewWithModalExample: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var showingResultsModal = false

    var body: some View {
        VStack {
            // Camera preview and controls

            // Capture button
            PrimaryButton(title: "Analyze") {
                Task {
                    await viewModel.startMultiFrameCapture()

                    // Show results when ready
                    if viewModel.lastScoreSummary != nil {
                        showingResultsModal = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingResultsModal) {
            ResultsModalView(viewModel: viewModel)
        }
    }
}

struct ResultsModalView: View {
    @ObservedObject var viewModel: CameraViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToHistory = false
    @State private var showingResults = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Show scores
                    if let scores = viewModel.lastScoreSummary {
                        ScoreSummaryView(
                            scores: scores,
                            faceImage: viewModel.lastCaptureResult?.combinedImage,
                            roiSet: viewModel.lastCaptureResult?.roiSet,
                            isPresented: $showingResults
                        )
                    }

                    // Show heatmap if available
                    if let _ = viewModel.lastCaptureResult {
                        Text("Heatmap visualization")
                        // Add HeatmapView here
                    }

                    // Save button
                    VStack(spacing: 12) {
                        PrimaryButton(title: "Save Results") {
                            Task {
                                await viewModel.saveSession()
                            }
                        }
                        .disabled(viewModel.saveInProgress || viewModel.sessionSaved)

                        if viewModel.saveInProgress {
                            LoadingView(message: "Saving session...")
                        }

                        if viewModel.sessionSaved {
                            Button("View History") {
                                dismiss()
                                navigateToHistory = true
                            }
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Analysis Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/*
 EXAMPLE 3: Auto-Save After Analysis

 Automatically save results after analysis completes
 */

struct CameraViewAutoSaveExample: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var autoSaved = false
    @State private var hasScores = false

    var body: some View {
        VStack {
            // Camera UI

            Text("Auto-save enabled")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: viewModel.lastScoreSummary != nil) { newValue in
            if newValue, !autoSaved {
                Task {
                    await viewModel.saveSession()
                    autoSaved = true
                }
            }
        }
    }
}

/*
 EXAMPLE 4: Save with User Confirmation

 Ask user before saving
 */

struct CameraViewWithConfirmation: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var showingSaveConfirmation = false

    var body: some View {
        VStack {
            // Camera UI

            if viewModel.lastScoreSummary != nil {
                PrimaryButton(title: "Save Results") {
                    showingSaveConfirmation = true
                }
            }
        }
        .alert("Save Results?", isPresented: $showingSaveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                Task {
                    await viewModel.saveSession()
                }
            }
        } message: {
            Text("This will save your analysis results to your history.")
        }
    }
}

/*
 EXAMPLE 5: Complete Flow with Navigation

 Full flow from camera to results to history
 */

struct CompleteFlowExample: View {
    @StateObject private var viewModel = CameraViewModel()

    enum NavigationDestination {
        case results
        case history
    }

    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                // Camera view
                Text("Camera View")

                // Capture button
                PrimaryButton(title: "Analyze Skin") {
                    Task {
                        await viewModel.startMultiFrameCapture()
                        if viewModel.lastScoreSummary != nil {
                            // Navigate to results
                            navigationPath.append(NavigationDestination.results)
                        }
                    }
                }
            }
            .navigationTitle("Skin Analysis")
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .results:
                    resultsView
                case .history:
                    ResultsHistoryView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        navigationPath.append(NavigationDestination.history)
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
        }
    }

    @State private var showingResults = true

    private var resultsView: some View {
        VStack(spacing: 24) {
            if let scores = viewModel.lastScoreSummary {
                ScoreSummaryView(
                    scores: scores,
                    faceImage: viewModel.lastCaptureResult?.combinedImage,
                    roiSet: viewModel.lastCaptureResult?.roiSet,
                    isPresented: $showingResults
                )

                VStack(spacing: 12) {
                    PrimaryButton(title: "Save Results") {
                        Task {
                            await viewModel.saveSession()

                            // After save, navigate to history
                            if viewModel.sessionSaved {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    navigationPath.append(NavigationDestination.history)
                                }
                            }
                        }
                    }
                    .disabled(viewModel.saveInProgress || viewModel.sessionSaved)

                    Button("Skip & View History") {
                        navigationPath.append(NavigationDestination.history)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .navigationTitle("Your Results")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/*
 USAGE NOTES:

 1. Choose the pattern that best fits your app flow
 2. All examples use the existing viewModel.saveSession() method
 3. Check viewModel.sessionSaved for success state
 4. Handle viewModel.saveInProgress for loading state
 5. Display viewModel.errorMessage for errors

 RECOMMENDED FLOW:
 1. User completes analysis
 2. Show results with ScoreSummaryView
 3. Offer "Save Results" button
 4. On save success, navigate to history
 5. User can view past sessions anytime

 INTEGRATION CHECKLIST:
 ☐ Import SwiftUI and CoreData
 ☐ Inject .environment(\.managedObjectContext) in TaviApp
 ☐ Call viewModel.saveSession() after analysis
 ☐ Show loading state during save
 ☐ Display success message on save
 ☐ Navigate to ResultsHistoryView
 ☐ Test save, view, and delete flows
 */
