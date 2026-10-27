//
//  CommentsViewModel.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The data and logic for one track's comments: loading them, loading
//  more as you scroll, and posting a new one.
//

import Foundation
import Combine

@MainActor
class CommentsViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var newCommentText = ""
    @Published var isPosting = false
    @Published var currentPage = 1
    // Tracks whether there are more pages left to load.
    @Published var hasMoreComments = true
    
    private let apiService = APIService.shared
    private let trackId: String
    private let pageSize = 20
    
    init(trackId: String) {
        self.trackId = trackId
    }
    
    // Loads the first page of comments.
    func loadComments() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        currentPage = 1
        
        do {
            let response = try await apiService.getTrackComments(trackId: trackId, page: 1, limit: pageSize)
            comments = response.comments
            hasMoreComments = response.pagination.page < response.pagination.totalPages
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // Loads the next page and adds it to the end of the list. Called when the user scrolls near
    // the bottom.
    func loadMoreComments() async {
        guard hasMoreComments && !isLoadingMore else { return }
        
        isLoadingMore = true
        
        do {
            let response = try await apiService.getTrackComments(trackId: trackId, page: currentPage + 1, limit: pageSize)
            comments.append(contentsOf: response.comments)
            currentPage = response.pagination.page
            hasMoreComments = response.pagination.page < response.pagination.totalPages
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoadingMore = false
    }
    
    // Posts the typed comment. It ignores empty text, clears the box right away, adds the
    // comment at the top, and puts the text back if sending fails.
    func postComment() async {
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isPosting else { return }
        
        isPosting = true
        errorMessage = nil
        
        let commentText = newCommentText
        newCommentText = "" // Clear input immediately
        
        do {
            let comment = try await apiService.createComment(content: commentText, trackId: trackId)
            comments.insert(comment, at: 0) // Add to top
            AnalyticsService.shared.trackComment(trackId: trackId, commentLength: commentText.count)
        } catch {
            newCommentText = commentText // Restore on error
            errorMessage = error.localizedDescription
        }
        
        isPosting = false
    }
    
    // Starts over from page 1, for pull to refresh.
    func refresh() async {
        currentPage = 1
        comments = []
        await loadComments()
    }
}

