//
//  CityView.swift
//  c705
//
//  Created for City tab showing major music cities and artists
//

import SwiftUI
import Combine

struct CityView: View {
    @StateObject private var viewModel = CityViewModel()
    @EnvironmentObject var authService: AuthService
    @Binding var searchText: String
    @State private var selectedCity: String?
    
    init(searchText: Binding<String> = .constant("")) {
        _searchText = searchText
    }
    
    let majorCities = [
        "New York", "Los Angeles", "Atlanta", "Chicago", "Houston",
        "Miami", "Detroit", "Philadelphia", "Memphis", "Oakland"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // City selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(majorCities, id: \.self) { city in
                            PillButton(
                                title: city,
                                isSelected: selectedCity == city,
                                action: {
                                    selectedCity = city
                                    Task {
                                        await viewModel.loadArtistsForCity(city)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                
                // Artists list
                if viewModel.isLoading {
                    ProgressView("Loading artists...")
                        .padding()
                } else if filteredArtists.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text(selectedCity == nil && searchText.isEmpty ? "Select a city to see artists" : "No artists found")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredArtists) { artist in
                            NavigationLink(destination: ArtistProfileView(artistId: artist.id)) {
                                ArtistCardView(artist: artist)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
        .refreshable {
            await performSearch()
        }
        .onChange(of: searchText) { oldValue, newValue in
            Task {
                await performSearch()
            }
        }
        .onChange(of: selectedCity) { oldValue, newValue in
            Task {
                await performSearch()
            }
        }
    }
    
    var filteredArtists: [ArtistSummary] {
        var artists = viewModel.artists
        
        // Filter by search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            artists = artists.filter { artist in
                (artist.name.localizedCaseInsensitiveContains(searchLower)) ||
                (artist.city?.localizedCaseInsensitiveContains(searchLower) ?? false)
            }
        }
        
        return artists
    }
    
    func performSearch() async {
        if !searchText.isEmpty {
            // Search artists and cities
            await viewModel.searchArtistsAndCities(query: searchText)
        } else if let city = selectedCity {
            // Load artists for selected city
            await viewModel.loadArtistsForCity(city)
        }
    }
}

@MainActor
class CityViewModel: ObservableObject {
    @Published var artists: [ArtistSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadArtistsForCity(_ city: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.getAllArtists(page: 1, limit: 100, search: city)
            artists = response.artists.filter { $0.city?.localizedCaseInsensitiveContains(city) ?? false }
        } catch {
            errorMessage = "Failed to load artists: \(error.localizedDescription)"
            print("Error loading artists for city: \(error)")
        }
        
        isLoading = false
    }
    
    func searchArtistsAndCities(query: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Search artists by name or city
            let response = try await APIService.shared.getAllArtists(page: 1, limit: 100, search: query)
            artists = response.artists.filter { artist in
                artist.name.localizedCaseInsensitiveContains(query) ||
                artist.city?.localizedCaseInsensitiveContains(query) ?? false
            }
        } catch {
            errorMessage = "Failed to search: \(error.localizedDescription)"
            print("Error searching artists and cities: \(error)")
        }
        
        isLoading = false
    }
}

#Preview {
    CityView()
        .environmentObject(AuthService())
}

