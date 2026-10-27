//
//  ArtistsListViewModel.swift
//  c705
//
//  Created for Artists list
//
//  PURPOSE: The data and logic for the list of artists, including searching and
//  loading more pages.
//

import Foundation
import Combine

@MainActor
class ArtistsListViewModel: ObservableObject {
    @Published var artists: [ArtistSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var currentPage = 1
    private let pageLimit = 20
    private var hasMorePages = true
    // The search text currently applied, used when loading each page.
    private var currentSearchQuery = ""
    
    // Loads the next page of artists. The first page replaces the list, and later pages are
    // added to it.
    func loadArtists() async {
        guard !isLoading && hasMorePages else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.getAllArtists(
                page: currentPage,
                limit: pageLimit,
                search: currentSearchQuery.isEmpty ? nil : currentSearchQuery
            )
            
            if currentPage == 1 {
                artists = response.artists
            } else {
                artists.append(contentsOf: response.artists)
            }
            
            hasMorePages = currentPage < response.totalPages
            currentPage += 1
        } catch {
            errorMessage = "Failed to load artists: \(error.localizedDescription)"
            print("Error loading artists: \(error)")
        }
        
        isLoading = false
    }
    
    // Starts a fresh search: it resets to page 1, clears the list and loads again.
    func searchArtists(query: String) {
        currentSearchQuery = query
        currentPage = 1
        hasMorePages = true
        artists = []
        Task {
            await loadArtists()
        }
    }
}

