//
//  TaviApp.swift
//  Tavi
//
//  Created on 2025-10-27.
//

import SwiftUI

@main
struct TaviApp: App {
    let persistenceController = PersistenceController.shared
    @State private var showLoadingScreen = false  // Disabled for development

    init() {
        // Configure crash reporting (production monitoring)
        CrashReporter.shared.configure()

        // Start memory monitoring to prevent out-of-memory crashes
        Task { @MainActor in
            MemoryMonitor.shared.startMonitoring()
        }

        // Log app launch
        CrashReporter.shared.logUserAction("app_launched")
        CrashReporter.shared.setCustomKey("device_model", value: UIDevice.current.model)
        CrashReporter.shared.setCustomKey("ios_version", value: UIDevice.current.systemVersion)

        // Attempt to migrate fallback data to Core Data on launch
        Task { @MainActor in
            // Process any pending saves from queue
            await CoreDataSaveQueue.shared.processQueue()

            // Try to migrate fallback data if Core Data becomes available
            let migratedCount = await FallbackStorage.shared.migrateToCoreDataIfPossible()
            if migratedCount > 0 {
                AppLogger.storage.info("✅ Migrated \(migratedCount) sessions from fallback to Core Data on app launch")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app content (MainTabView has its own NavigationStack per tab)
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.viewContext)
                    .opacity(showLoadingScreen ? 0 : 1)

                // Fancy loading screen (shows on first launch)
                if showLoadingScreen {
                    FancyLoadingScreen {
                        // When loading completes, fade out loading screen
                        showLoadingScreen = false
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .animation(Designs.Animation.easeOut, value: showLoadingScreen)
            .preferredColorScheme(.light)  // Force light mode across the app
        }
    }
}
