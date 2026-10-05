//
//  UniversalSearchView.swift
//  c705
//
//  Universal search across users, cities, cyphers, and beats
//

import SwiftUI
import Combine

struct UniversalSearchView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = UniversalSearchViewModel()
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Title
                HStack {
                    Text("Discover")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .padding(.leading, 12)
                    
                    TextField("Search", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.vertical, 10)
                        .onChange(of: searchText) { oldValue, newValue in
                            // Cancel previous search
                            searchTask?.cancel()
                            
                            // Debounce search
                            searchTask = Task {
                                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                                if !Task.isCancelled && searchText == newValue {
                                    await viewModel.search(query: newValue)
                                }
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            viewModel.clearResults()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 12)
                        }
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 12)
                
                // Search Results
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if searchText.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Find artists, beats, and cyphers")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else if viewModel.hasResults {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Users Section
                            if !viewModel.users.isEmpty {
                                SearchSection(title: "Users", icon: "person.fill") {
                                    ForEach(viewModel.users) { user in
                                        UserSearchResultRow(user: user)
                                    }
                                }
                            }
                            
                            // Cities Section
                            if !viewModel.cities.isEmpty {
                                SearchSection(title: "Cities", icon: "location.fill") {
                                    ForEach(viewModel.cities, id: \.self) { city in
                                        CitySearchResultRow(city: city)
                                    }
                                }
                            }
                            
                            // Cyphers Section
                            if !viewModel.cyphers.isEmpty {
                                SearchSection(title: "Cyphers", icon: "mic.fill") {
                                    ForEach(viewModel.cyphers) { cypher in
                                        CypherSearchResultRow(cypher: cypher)
                                    }
                                }
                            }
                            
                            // Beats Section
                            if !viewModel.beats.isEmpty {
                                SearchSection(title: "Beats", icon: "music.note") {
                                    ForEach(viewModel.beats) { beat in
                                        BeatSearchResultRow(beat: beat)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No results found")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.gray)
                        Text("Try a different search term")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Search Section
struct SearchSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            content
        }
    }
}

// MARK: - User Search Result Row
struct UserSearchResultRow: View {
    let user: APIService.SearchUserResult
    
    var body: some View {
        NavigationLink(destination: EnhancedArtistProfileView(artistId: user.id)) {
            HStack(spacing: 12) {
                // Avatar
                AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let username = user.username {
                        Text("@\(username)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    if let city = user.city {
                        Text(city)
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - City Search Result Row
struct CitySearchResultRow: View {
    let city: String
    
    var body: some View {
        NavigationLink(destination: CityView()) {
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
                
                Text(city)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 12))
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Cypher Search Result Row
struct CypherSearchResultRow: View {
    let cypher: APIService.SearchCypherResult
    
    var body: some View {
        NavigationLink(destination: CypherDetailView(cypherId: cypher.id)) {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(cypher.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let description = cypher.description {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 8) {
                        Label("\(cypher.entryCount)", systemImage: "person.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 12))
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Beat Search Result Row
struct BeatSearchResultRow: View {
    let beat: APIService.SearchBeatResult
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note")
                .foregroundColor(.blue)
                .font(.system(size: 20))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(beat.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let genre = beat.genre {
                        Text(genre)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    if beat.bpm > 0 {
                        Text("\(beat.bpm) BPM")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                
                if let producer = beat.producer?.username ?? beat.producer?.email {
                    Text("by \(producer)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - View Model
@MainActor
class UniversalSearchViewModel: ObservableObject {
    @Published var users: [APIService.SearchUserResult] = []
    @Published var cities: [String] = []
    @Published var cyphers: [APIService.SearchCypherResult] = []
    @Published var beats: [APIService.SearchBeatResult] = []
    @Published var isLoading = false
    
    private let apiService = APIService.shared
    
    var hasResults: Bool {
        !users.isEmpty || !cities.isEmpty || !cyphers.isEmpty || !beats.isEmpty
    }
    
    func search(query: String) async {
        guard query.count >= 2 else {
            clearResults()
            return
        }
        
        isLoading = true
        
        do {
            let results = try await apiService.universalSearch(query: query)
            users = results.users
            cities = results.cities
            cyphers = results.cyphers
            beats = results.beats
        } catch {
            print("Search error: \(error.localizedDescription)")
            clearResults()
        }
        
        isLoading = false
    }
    
    func clearResults() {
        users = []
        cities = []
        cyphers = []
        beats = []
    }
}

// MARK: - Search Result Models (typealiases for APIService models)
typealias SearchUserResult = APIService.SearchUserResult
typealias SearchCypherResult = APIService.SearchCypherResult
typealias SearchBeatResult = APIService.SearchBeatResult

