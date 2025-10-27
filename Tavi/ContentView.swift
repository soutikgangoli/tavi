//
//  ContentView.swift
//  Tavi
//
//  Created on 2025-10-27.
//  Updated on 2025-10-28 with emotional design
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        HomeView()
    }
}

#Preview {
    NavigationStack {
        ContentView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
