//
//  CypherHubViewModel.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The data and logic for the Arena (Cypher hub) screen: the active
//  cyphers, the Popular list and the user's invites.
//

import Foundation
import Combine

@MainActor
class CypherHubViewModel: ObservableObject {
    // The lists the Arena can show: topCyphers on the Top tab, cyphers on the All tab.
    @Published var cyphers: [Cypher] = []
    @Published var topCyphers: [TopCypher] = []
    @Published var trendingCyphers: [TopCypher] = []
    @Published var invites: [CypherInvite] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    // Stops a second load from starting while one is already running.
    private var isLoadingInProgress = false
    
    // Loads active cyphers, then the top cyphers of the week, then the user's invites. A
    // failure in the top list or the invites is handled quietly, so one problem does not blank
    // the whole screen.
    func loadCyphers() async {
        // Prevent multiple simultaneous loads
        guard !isLoadingInProgress else {
            return
        }
        
        isLoadingInProgress = true
        isLoading = true
        errorMessage = nil
        
        do {
            // Load all active cyphers
            let response = try await apiService.getActiveCyphers(page: 1, limit: 50)
            cyphers = response.cyphers
            
            // Load top cyphers (this week) - handle errors gracefully; no trending fetch (tab removed)
            do {
                // Asks the server for this week's most popular cyphers. The server's "week" only
                // counts cyphers created in the last 7 days, so fall back to all-time when it is
                // empty rather than showing no Popular list at all.
                topCyphers = try await apiService.getTopCyphers(range: "week", limit: 10)
                if topCyphers.isEmpty {
                    topCyphers = try await apiService.getTopCyphers(range: "all-time", limit: 10)
                }
            } catch {
                topCyphers = []
            }
            
            trendingCyphers = []
            
            // Load user's invites (handle errors gracefully - might fail if not authenticated)
            // Loads invitations the user has received.
            invites = try await apiService.getUserCypherInvites()
        } catch {
            errorMessage = "Failed to load cyphers: \(error.localizedDescription)"
            print("Error loading cyphers: \(error)")
        }
        
        isLoading = false
        isLoadingInProgress = false
    }
}

