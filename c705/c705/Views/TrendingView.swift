//
//  TrendingView.swift
//  c705
//
//  Created for Trending tab with sub-navigation
//

import SwiftUI

struct TrendingView: View {
    @State private var selectedSubTab = "Beats"
    @EnvironmentObject var authService: AuthService
    @Binding var searchText: String
    
    init(searchText: Binding<String> = .constant("")) {
        _searchText = searchText
    }
    
    let subTabs = ["Beats", "Cyphers"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Sub-navigation (pill buttons style)
            HStack(spacing: 16) {
                ForEach(subTabs, id: \.self) { tab in
                    SubTabButton(
                        title: tab,
                        isSelected: selectedSubTab == tab,
                        action: {
                            withAnimation(AppAnimations.fastSpring) {
                                selectedSubTab = tab
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.background)
            
            // Sub-tab content
            Group {
                switch selectedSubTab {
                case "Beats":
                    TrendingBeatsView(searchText: $searchText)
                        .environmentObject(authService)
                        .transition(AppAnimations.slideTransition)
                case "Cyphers":
                    TrendingCyphersView(searchText: $searchText)
                        .environmentObject(authService)
                        .transition(AppAnimations.slideTransition)
                default:
                    TrendingBeatsView(searchText: $searchText)
                        .environmentObject(authService)
                        .transition(AppAnimations.slideTransition)
                }
            }
            .animation(AppAnimations.smoothSpring, value: selectedSubTab)
        }
    }
}

struct SubTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Theme.accent : Theme.card)
                .cornerRadius(20)
                .scaleEffect(isSelected ? 1.0 : 0.95)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(AppAnimations.quickSpring, value: isSelected)
    }
}

struct TrendingBeatsView: View {
    @StateObject private var viewModel = BeatsHubViewModel()
    @EnvironmentObject var authService: AuthService
    @Binding var searchText: String
    @State private var showError = false
    
    init(searchText: Binding<String> = .constant("")) {
        _searchText = searchText
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading && viewModel.beats.isEmpty {
                    ProgressView("Loading trending beats...")
                        .padding()
                } else if viewModel.beats.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No trending beats found")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)
                } else {
                    // Filter and sort beats
                    ForEach(filteredBeats) { beat in
                        NavigationLink(destination: BeatDetailView(beat: beat)) {
                            BeatCardView(beat: beat)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(AppAnimations.listTransition)
                    }
                    .animation(AppAnimations.fastSpring, value: filteredBeats.count)
                }
            }
            .padding()
        }
        .refreshable {
            await performSearch()
        }
        .task {
            await performSearch()
        }
        .onChange(of: searchText) { oldValue, newValue in
            Task {
                await performSearch()
            }
        }
        .onChange(of: viewModel.errorMessage) { oldValue, newValue in
            if newValue != nil {
                showError = true
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
            Button("Retry") {
                Task {
                    await performSearch()
                }
            }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred while loading beats.")
        }
    }
    
    var filteredBeats: [Beat] {
        var beats = viewModel.beats
        
        // Filter by search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            beats = beats.filter { beat in
                beat.title.lowercased().contains(searchLower) ||
                beat.genre.lowercased().contains(searchLower) ||
                beat.producer?.username?.lowercased().contains(searchLower) ?? false ||
                beat.producer?.email.lowercased().contains(searchLower) ?? false
            }
        }
        
        // Sort by trending (most purchased - in production, backend should provide this)
        return beats
    }
    
    func performSearch() async {
        if !searchText.isEmpty {
            viewModel.searchText = searchText
            await viewModel.refreshBeats()
        } else {
            await viewModel.loadBeats()
        }
    }
}

struct TrendingCyphersView: View {
    @StateObject private var viewModel = CypherHubViewModel()
    @EnvironmentObject var authService: AuthService
    @Binding var searchText: String
    
    init(searchText: Binding<String> = .constant("")) {
        _searchText = searchText
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading && viewModel.cyphers.isEmpty {
                    ProgressView("Loading trending cyphers...")
                        .padding()
                } else if viewModel.cyphers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No trending cyphers found")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)
                } else {
                    // Filter and sort cyphers
                    ForEach(filteredCyphers) { cypher in
                        NavigationLink(destination: CypherDetailView(cypherId: cypher.id)) {
                            CypherCardView(cypher: cypher) {
                                // Empty action closure
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(AppAnimations.listTransition)
                    }
                    .animation(AppAnimations.fastSpring, value: filteredCyphers.count)
                }
            }
            .padding()
        }
        .refreshable {
            await performSearch()
        }
        .task {
            await performSearch()
        }
        .onChange(of: searchText) { oldValue, newValue in
            Task {
                await performSearch()
            }
        }
    }
    
    var filteredCyphers: [Cypher] {
        var cyphers = viewModel.cyphers
        
        // Filter by search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            cyphers = cyphers.filter { cypher in
                cypher.title.lowercased().contains(searchLower) ||
                cypher.description?.lowercased().contains(searchLower) ?? false
            }
        }
        
        // Sort by entry count (trending = most entries)
        return cyphers.sorted(by: { ($0.entryCount ?? 0) > ($1.entryCount ?? 0) })
    }
    
    func performSearch() async {
        await viewModel.loadCyphers()
    }
}

#Preview {
    TrendingView()
        .environmentObject(AuthService())
}

