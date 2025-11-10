//
//  ContentView.swift
//  Tavi
//
//  Created on 2025-10-27.
//  Updated on 2025-01-10 with tab navigation
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    NavigationStack {
        ContentView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
