//
//  MainTabView.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            FeedView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

            // Discover Tab
            UniversalSearchView()
                .tabItem {
                    Label("Discover", systemImage: "magnifyingglass")
                }
                .tag(1)

            // Arena Tab
            FreestyleArenaView()
                .tabItem {
                    Label("Arena", systemImage: "mic.fill")
                }
                .tag(2)

            // Beats Tab
            BeatsView()
                .tabItem {
                    Label("Beats", systemImage: "music.note")
                }
                .tag(3)

            // Profile Tab
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CypherTabBar(selectedTab: $selectedTab)
        }
    }
}

// Artists tab view
struct ArtistsView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        ArtistsListView()
            .environmentObject(authService)
    }
}

struct FreestyleArenaView: View {
    @StateObject private var viewModel = CypherHubViewModel()
    
    var body: some View {
        CypherHubView(viewModel: viewModel)
    }
}

struct BeatsView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        BeatsHubView()
            .environmentObject(authService)
    }
}

#Preview {
    MainTabView()
}

