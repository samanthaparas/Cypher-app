//
//  CypherDetailViewModel.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The data and logic for one cypher's detail screen: the cypher
//  itself, its entries, the leaderboard, and sending votes.
//

import Foundation
import Combine

@MainActor
class CypherDetailViewModel: ObservableObject {
    @Published var cypher: CypherDetail?
    @Published var entries: [CypherEntry] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var isLoadingEntries = false
    @Published var isLoadingLeaderboard = false
    @Published var errorMessage: String?
    
    // The signed-in user's own entry in this cypher, if they have posted one.
    var userEntry: CypherEntry? {
        cypher?.userEntry
    }
    
    private let apiService = APIService.shared
    
    // Loads the cypher's details.
    func loadCypher(id: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let detail = try await apiService.getCypherById(id)
            cypher = detail
        } catch {
            errorMessage = "Failed to load cypher: \(error.localizedDescription)"
            print("Error loading cypher: \(error)")
        }
        
        isLoading = false
    }
    
    // Loads up to 100 entries for the cypher.
    func loadEntries(cypherId: String) async {
        isLoadingEntries = true
        
        do {
            let response = try await apiService.getCypherEntries(cypherId: cypherId, page: 1, limit: 100)
            entries = response.entries
        } catch {
            errorMessage = "Failed to load entries: \(error.localizedDescription)"
            print("Error loading entries: \(error)")
        }
        
        isLoadingEntries = false
    }
    
    // Loads the ranked list of entries.
    func loadLeaderboard(cypherId: String) async {
        isLoadingLeaderboard = true
        
        do {
            leaderboard = try await apiService.getCypherLeaderboard(cypherId: cypherId, limit: 50)
        } catch {
            errorMessage = "Failed to load leaderboard: \(error.localizedDescription)"
            print("Error loading leaderboard: \(error)")
        }
        
        isLoadingLeaderboard = false
    }
    
    // Sends a vote, then reloads the entries so the new scores show.
    func voteEntry(entryId: String, bars: Int, flow: Int, creativity: Int) async {
        do {
            let _ = try await apiService.voteCypherEntry(entryId: entryId, bars: bars, flow: flow, creativity: creativity)
            // Reload entries to update scores
            if let cypherId = cypher?.id {
                await loadEntries(cypherId: cypherId)
            }
        } catch {
            errorMessage = "Failed to vote: \(error.localizedDescription)"
            print("Error voting: \(error)")
        }
    }
}

