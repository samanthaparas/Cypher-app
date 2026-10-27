//
//  FeedView.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The Home screen: a search bar, a profile button, a row of section
//  tabs (Trending, Articles, Events, City) and the content of
//  whichever tab is selected.
//

import SwiftUI

struct FeedView: View {
    // Loads the feed data and keeps it alive while the screen is on.
    @StateObject private var viewModel = FeedViewModel()
    // Which section tab is open. Changing it swaps the content below.
    @State private var selectedTab = "Trending"
    @State private var searchText = ""
    @State private var showProfile = false
    // The shared sign-in service, passed down from the top of the app.
    @EnvironmentObject var authService: AuthService
    
        // The section names. They also decide which screen is shown below.
        let tabs = ["Trending", "Articles", "Events", "City"]
    
    func getSearchPlaceholder() -> String {
        return "Search"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar with Search and Profile
            HStack(spacing: 12) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.textSecondary)
                    TextField(getSearchPlaceholder(), text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            // Trigger search when user presses return
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.card)
                .cornerRadius(10)
                
                // Profile Button
                Button(action: {
                    showProfile = true
                }) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.textPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.background)
            
            // Tab Navigation
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(tabs, id: \.self) { tab in
                        Button(action: {
                            selectedTab = tab
                        }) {
                            VStack(spacing: 4) {
                                Text(tab)
                                    .font(.system(size: 16, weight: selectedTab == tab ? .bold : .regular))
                                    .foregroundColor(selectedTab == tab ? Theme.textPrimary : Theme.textSecondary)
                                
                                if selectedTab == tab {
                                    Rectangle()
                                        .fill(Theme.accent)
                                        .frame(height: 2)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)
            .background(Theme.background)
            
            // Tab Content
            Group {
                // Shows the screen for the selected tab. All four share one search box through
                // searchText.
                switch selectedTab {
                case "Trending":
                    TrendingView(searchText: $searchText)
                        .environmentObject(authService)
                case "Articles":
                    ArticlesView(searchText: $searchText)
                        .environmentObject(authService)
                case "Events":
                    EventsView(searchText: $searchText)
                        .environmentObject(authService)
                case "City":
                    CityView(searchText: $searchText)
                        .environmentObject(authService)
                default:
                    TrendingView(searchText: $searchText)
                        .environmentObject(authService)
                }
            }
            // This commented-out block is the floating mic button. It did nothing, so it was
            // hidden (PR #9). Delete it or bring it back once recording from Home exists.
            // .overlay(alignment: .bottomTrailing) {
            //     // Floating Action Button (FAB)
            //     Button(action: {
            //         // TODO: Implement recording functionality
            //     }) {
            //         Image(systemName: "mic.fill")
            //             .font(.system(size: 20, weight: .medium))
            //             .foregroundColor(.white)
            //             .frame(width: 56, height: 56)
            //             .background(Theme.accent)
            //             .clipShape(Circle())
            //             .shadow(color: Theme.accent.opacity(0.5), radius: 10, x: 0, y: 4)
            //     }
            //     .padding(.trailing, 20)
            //     .padding(.bottom, 20)
            // }
                }
        .background(Theme.background.ignoresSafeArea())
        // Forces dark appearance for this screen and everything inside it.
        .environment(\.colorScheme, .dark)
        // Runs once when the screen first appears: it loads the feed and records that the feed
        // was viewed. The loaded items are not shown on screen right now, since each tab loads its
        // own data.
        .task {
            if viewModel.feedItems.isEmpty {
                await viewModel.loadFeed()
                AnalyticsService.shared.trackFeedView()
            }
        }
        // Shows an Error pop-up, with OK and Retry, whenever the view model holds an error
        // message.
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
            Button("Retry") {
                Task {
                    await viewModel.refresh()
                }
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        // Slides up the Profile screen when the profile button is tapped.
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .environmentObject(authService)
        }
    }
}

// ProfileView moved to separate file: ProfileView.swift

#Preview {
    FeedView()
        .environmentObject(AuthService())
}

