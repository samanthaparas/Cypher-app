//
//  EventsView.swift
//  c705
//
//  Created for Events tab (placeholder)
//
//  PURPOSE: The Events screen. It is a placeholder ("Events Coming Soon")
//  because the events feature has not been built yet. The view model
//  is wired for searching but returns nothing.
//

import SwiftUI
import Combine

// Shown under Home, in the Events tab.
struct EventsView: View {
    @EnvironmentObject var authService: AuthService
    // The search text lives in the parent screen. This view gets a live link to it.
    @Binding var searchText: String
    @StateObject private var viewModel = EventsViewModel()
    
    init(searchText: Binding<String> = .constant("")) {
        _searchText = searchText
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView("Searching events...")
                        .padding()
                // Shown when the user searched and nothing matched.
                } else if !searchText.isEmpty && viewModel.events.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No events found")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)
                } else {
                    // The default "coming soon" message, shown when nothing has been searched.
                    Image(systemName: "calendar")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("Events Coming Soon")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Stay tuned for upcoming music events, concerts, and cypher battles in your area.")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .padding(.top, 100)
        }
        // Runs a new event search every time the search text changes.
        .onChange(of: searchText) { oldValue, newValue in
            Task {
                await viewModel.searchEvents(query: newValue)
            }
        }
    }
}

@MainActor
// Holds the events list. events is a placeholder list of text until a real Event model exists.
class EventsViewModel: ObservableObject {
    @Published var events: [String] = [] // Placeholder - replace with Event model
    @Published var isLoading = false
    
    // Not built yet. It clears the results for now (see the TODO).
    func searchEvents(query: String) async {
        if query.isEmpty {
            events = []
            return
        }
        
        isLoading = true
        // TODO: Implement actual event search API call
        // For now, just clear results
        events = []
        isLoading = false
    }
}

#Preview {
    EventsView()
        .environmentObject(AuthService())
}

