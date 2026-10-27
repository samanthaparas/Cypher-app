//
//  ArtistsListView.swift
//  c705
//
//  Created for Artists tab
//
//  PURPOSE: A browsable list of artists with a search bar that shows a dropdown
//  of matches as you type. This file also defines ArtistCardView (one
//  artist card) and the ArtistSummary data shape that several other
//  screens use. Nothing in the app currently opens the list itself.
//

import SwiftUI

// Loads artists from the server a page at a time and shows them as cards that open the artist's
// profile.
struct ArtistsListView: View {
    @StateObject private var viewModel = ArtistsListViewModel()
    @EnvironmentObject var authService: AuthService
    @State private var searchText = ""
    // True while the search box is being used. It decides whether the dropdown of matches is
    // showing.
    @State private var isSearchFocused = false
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // Main content
                VStack(spacing: 0) {
                    // Search Bar at top
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                                .padding(.leading, 12)
                            
                            TextField("Search artists...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.vertical, 10)
                                .focused($isSearchFieldFocused)
                                // Each time the search text changes, the view model fetches
                                // matching artists.
                                .onChange(of: searchText) { oldValue, newValue in
                                    viewModel.searchArtists(query: newValue)
                                }
                                .onChange(of: isSearchFieldFocused) { oldValue, newValue in
                                    withAnimation(AppAnimations.fastSpring) {
                                        isSearchFocused = newValue
                                    }
                                }
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                    viewModel.searchArtists(query: "")
                                    isSearchFieldFocused = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .padding(.trailing, 12)
                                }
                            }
                        }
                        .background(Theme.card)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        
                        // Search Results Dropdown
                        if isSearchFocused && !searchText.isEmpty {
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    if viewModel.isLoading {
                                        HStack {
                                            Spacer()
                                            ProgressView()
                                                .padding()
                                            Spacer()
                                        }
                                    } else if viewModel.artists.isEmpty {
                                        VStack(spacing: 12) {
                                            Image(systemName: "person.slash")
                                                .font(.system(size: 32))
                                                .foregroundColor(.gray)
                                            Text("No results for \"\(searchText)\"")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.vertical, 40)
                                    } else {
                                        ForEach(viewModel.artists) { artist in
                                            NavigationLink(destination: ArtistProfileView(artistId: artist.id)) {
                                                SearchResultArtistRow(artist: artist)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            
                                            if artist.id != viewModel.artists.last?.id {
                                                Divider()
                                                    .padding(.leading, 60)
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 400)
                            .themeCard(padding: 0)
                            .padding(.horizontal)
                            .transition(AppAnimations.listTransition)
                            .animation(AppAnimations.fastSpring, value: isSearchFocused)
                        }
                    }
                    .zIndex(1)
                    
                    // Artists List (shown when not searching)
                    if !isSearchFocused || searchText.isEmpty {
                        if viewModel.isLoading && viewModel.artists.isEmpty {
                            ProgressView("Loading artists...")
                                .padding()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if viewModel.artists.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text("No artists found")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 60)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    ForEach(viewModel.artists) { artist in
                                        NavigationLink(destination: ArtistProfileView(artistId: artist.id)) {
                                            ArtistCardView(artist: artist)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .padding()
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 12)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                }
            }
            .themedScreen()
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            // Lets the user pull down to reload the list.
            .refreshable {
                await viewModel.loadArtists()
            }
            // Loads the first page when the screen first appears.
            .task {
                await viewModel.loadArtists()
            }
            .onTapGesture {
                if isSearchFocused {
                    isSearchFieldFocused = false
                }
            }
        }
    }
}

// Search result row for dropdown
struct SearchResultArtistRow: View {
    let artist: ArtistSummary
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                if let avatarUrl = artist.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Text(String(artist.name.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Text(String(artist.name.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            
            // Artist Info
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                
                if let city = artist.city, !city.isEmpty {
                    Text(city)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// One artist as a card: avatar (or first letter), name, city, and follower and track counts.
struct ArtistCardView: View {
    let artist: ArtistSummary
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                if let avatarUrl = artist.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Text(String(artist.name.prefix(1)).uppercased())
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                } else {
                    Text(String(artist.name.prefix(1)).uppercased())
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            
            // Artist Info
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                
                if let city = artist.city, !city.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                        Text(city)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                
                HStack(spacing: 16) {
                    Label("\(artist.followersCount)", systemImage: "person.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Label("\(artist.tracksCount)", systemImage: "music.note")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding()
        .themeCard(padding: 0)
    }
}

// Artist Summary model for list view
// The short artist record the server sends for lists. The City tab uses it too.
struct ArtistSummary: Codable, Identifiable {
    let id: String
    let name: String
    let city: String?
    let avatarUrl: String?
    let followersCount: Int
    let tracksCount: Int
}

// A page of artists plus paging numbers.
struct ArtistsListResponse: Codable {
    let artists: [ArtistSummary]
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int
}

