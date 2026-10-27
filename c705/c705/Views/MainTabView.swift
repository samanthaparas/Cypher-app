//
//  MainTabView.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The main screen after signing in. It holds the five tabs (Home,
//  Discover, Arena, Beats, Profile) and puts the custom tab bar at the
//  bottom.
//

import SwiftUI

struct MainTabView: View {
    // Remembers which tab is open. @State means the screen redraws when it changes.
    @State private var selectedTab = 0

    var body: some View {
        // A TabView switches between full screens. Each one below is tagged with a number that
        // matches the custom bar.
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
            ProfileView(showsBackButton: false)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
        // Hides iOS's built-in tab bar, because the custom CypherTabBar is used instead.
        .toolbar(.hidden, for: .tabBar)
        // Pins the custom bar to the bottom and keeps screen content from sliding underneath
        // it.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CypherTabBar(selectedTab: $selectedTab)
        }
    }
}

// The small wrapper views below pass the shared sign-in service into each screen that needs it.
// Artists tab view
struct ArtistsView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        ArtistsListView()
            .environmentObject(authService)
    }
}

// The Arena tab. It creates the Cypher hub's view model once so the data survives tab switches.
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

