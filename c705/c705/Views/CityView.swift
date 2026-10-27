//
//  CityView.swift
//  c705
//
//  Created for City tab showing major music cities and artists
//
//  PURPOSE: The City tab on Home: pick a major city from a row of pills to see
//  the artists based there, or search by name or city.
//

import SwiftUI
import Combine

struct CityView: View {
    @StateObject private var viewModel = CityViewModel()
    @EnvironmentObject var authService: AuthService
    @Binding var searchText: String
    // The city the user tapped. nil means none chosen yet.
    @State private var selectedCity: String?
    
    init(searchText: Binding<String> = .constant("")) {
        _searchText = searchText
    }
    
    // The cities shown as pills. To add a city, add it to this list.
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
                // Nothing to show: prompt the user to pick a city, or say no artists were
                // found.
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
        // Lets the user pull down to reload.
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
    
    // The artists to display, narrowed by the search box if something is typed.
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
    
    // Searches when there is text in the search box. Otherwise it reloads the selected city's
    // artists.
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
// Holds the artists and loading state for this screen.
class CityViewModel: ObservableObject {
    @Published var artists: [ArtistSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Fetches artists matching the city, then keeps only those whose city really contains that
    // name.
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
    
    // Fetches artists matching the typed text in their name or city.
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

