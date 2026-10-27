//
//  LikeViewModel.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The logic behind one like button: whether the track is liked and
//  how many likes it has. It updates the heart immediately and tells
//  the server in the background.
//

import Foundation
import Combine

@MainActor
class LikeViewModel: ObservableObject {
    @Published var isLiked: Bool
    @Published var likeCount: Int
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private let trackId: String
    
    // Each like button gets its own view model, started with the track's current numbers.
    init(trackId: String, initialLikeCount: Int, initialIsLiked: Bool = false) {
        self.trackId = trackId
        self.likeCount = initialLikeCount
        self.isLiked = initialIsLiked
    }
    
    // Flips like or unlike. guard !isLoading stops a second tap while the first is still being
    // sent.
    func toggleLike() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Optimistic update: change the screen right away so it feels instant, and remember the
        // old values in case the request fails.
        // Optimistic update
        let previousIsLiked = isLiked
        let previousCount = likeCount
        
        if isLiked {
            isLiked = false
            likeCount = max(0, likeCount - 1)
        } else {
            isLiked = true
            likeCount += 1
        }
        
        do {
            if previousIsLiked {
                // Unlike
                _ = try await apiService.unlikeTrack(trackId: trackId)
                AnalyticsService.shared.trackUnlike(trackId: trackId)
            } else {
                // Like
                _ = try await apiService.likeTrack(trackId: trackId)
                AnalyticsService.shared.trackLike(trackId: trackId)
            }
        } catch {
            // If the server request failed, put the heart and count back the way they were and
            // show the error.
            // Revert on error
            isLiked = previousIsLiked
            likeCount = previousCount
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

