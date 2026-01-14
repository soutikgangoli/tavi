//
//  OllvyApp.swift
//  Ollvy
//
//  Created on 2025-10-27.
//

import SwiftUI

@main
struct OllvyApp: App {
    // CRITICAL: Do NOT initialize PersistenceController here - it blocks app startup!
    // Core Data is initialized lazily after the loading screen appears
    @State private var showLoadingScreen = true
    @State private var isInitialized = false

    // Match FancyLoadingScreen background to prevent white flash
    private let launchBackgroundColor = Color(red: 252/255, green: 250/255, blue: 245/255)

    var body: some Scene {
        WindowGroup {
            ZStack {
                // CRITICAL: Background color prevents white flash during initial render
                launchBackgroundColor
                    .ignoresSafeArea()

                // Main app content - only show after initialization
                if isInitialized {
                    ContentView()
                        .environment(\.managedObjectContext, PersistenceController.shared.viewContext)
                        .opacity(showLoadingScreen ? 0 : 1)
                }

                // Fancy loading screen (shows IMMEDIATELY on launch)
                if showLoadingScreen {
                    FancyLoadingScreen {
                        // When loading animation completes, fade out
                        showLoadingScreen = false
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .animation(Designs.Animation.easeOut, value: showLoadingScreen)
            .preferredColorScheme(.light)
            .task {
                // Initialize everything AFTER the loading screen is visible
                await initializeApp()
            }
        }
    }

    /// Deferred initialization - runs AFTER loading screen appears
    @MainActor
    private func initializeApp() async {
        // Minimal delay - just enough for SwiftUI to commit first frame
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms (was 50ms)

        // Now do heavy initialization (loading screen is already visible)

        // 1. Initialize Core Data (this triggers PersistenceController.shared)
        _ = PersistenceController.shared

        // 2. Configure crash reporting
        CrashReporter.shared.configure()
        CrashReporter.shared.logUserAction("app_launched")
        CrashReporter.shared.setCustomKey("device_model", value: UIDevice.current.model)
        CrashReporter.shared.setCustomKey("ios_version", value: UIDevice.current.systemVersion)

        // 3. Start memory monitoring
        MemoryMonitor.shared.startMonitoring()

        // 4. Process Core Data queue and migrations (background)
        Task {
            await CoreDataSaveQueue.shared.processQueue()
            let migratedCount = await FallbackStorage.shared.migrateToCoreDataIfPossible()
            if migratedCount > 0 {
                AppLogger.storage.info("✅ Migrated \(migratedCount) sessions from fallback to Core Data")
            }
        }

        // Mark as initialized - ContentView will now render
        isInitialized = true
    }
}
