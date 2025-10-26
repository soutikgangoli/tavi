//
//  ResultsView.swift
//  Tavi
//
//  Created on 2025-10-27.
//
//  DEPRECATED: Use ResultsHistoryView instead
//

import SwiftUI

/// Legacy view - redirects to ResultsHistoryView
struct ResultsView: View {
    var body: some View {
        ResultsHistoryView()
    }
}

#Preview {
    NavigationStack {
        ResultsView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
