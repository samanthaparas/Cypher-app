//
//  HomeDashboardViewModel.swift
//  c705
//
//  PURPOSE: The data for the Home dashboard. Right now that is the top
//  cypher shown in the Feats of the Week banner.
//

import Foundation
import Combine

@MainActor
class HomeDashboardViewModel: ObservableObject {
    // The cypher shown in the banner, or nil when there is none yet.
    @Published var topCypher: TopCypher?
    // True when topCypher came from this week's list, false when it is the all-time fallback.
    // The banner uses it to say "This week's #1" or "All-time #1" honestly.
    @Published var isThisWeek = true
    @Published var isLoading = false

    private let apiService = APIService.shared

    // Asks for this week's #1 cypher. The server's "week" only counts cyphers created in the last
    // 7 days, so fall back to all-time when the week is empty. Errors leave the banner in its
    // empty state instead of showing an alert, since the rest of Home still works.
    func loadTopCypher() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if let weekly = try await apiService.getTopCyphers(range: "week", limit: 1).first {
                topCypher = weekly
                isThisWeek = true
            } else {
                topCypher = try await apiService.getTopCyphers(range: "all-time", limit: 1).first
                isThisWeek = false
            }
        } catch {
            print("⚠️ Could not load top cypher for Home: \(error.localizedDescription)")
        }
    }
}
