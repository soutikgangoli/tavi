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

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
            .environment(\.managedObjectContext, persistenceController.viewContext)
            .sheet(isPresented: .constant(!hasCompletedOnboarding)) {
                OnboardingView()
                    .interactiveDismissDisabled()
            }
        }
    }
}
