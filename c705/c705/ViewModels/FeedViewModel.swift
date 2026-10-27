//
//  FeedViewModel.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The data and logic for the Home feed: loading it, loading more
//  pages as you scroll, and refreshing.
//

import Foundation
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    @Published var feedItems: [FeedItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var hasMorePages = true
    
    private let apiService = APIService.shared
    private let pageSize = 20
    // An extra guard so scrolling can never start the same page load twice.
    private var isLoadingNextPage = false // Prevent duplicate loads
    
    // Loads the first page of the feed and replaces whatever was showing.
    func loadFeed() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        currentPage = 1
        
        do {
            let response = try await apiService.getFeed(page: 1, limit: pageSize)
            feedItems = response.feed
            hasMorePages = response.pagination.page < response.pagination.totalPages
            currentPage = 1
        } catch APIError.httpErrorWithMessage(401, _), APIError.httpError(401) {
            // The saved token was rejected. AuthService signs out and shows the login screen, so
            // no alert here.
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // Loads the next page and adds it to the bottom. This is called infinite scrolling.
    func loadMore() async {
        // Prevent duplicate loads
        guard !isLoadingNextPage && !isLoadingMore && hasMorePages else { return }
        
        isLoadingNextPage = true
        isLoadingMore = true
        
        let nextPage = currentPage + 1
        
        do {
            let response = try await apiService.getFeed(page: nextPage, limit: pageSize)
            
            // Only append if we got new items
            if !response.feed.isEmpty {
                feedItems.append(contentsOf: response.feed)
                currentPage = nextPage
                hasMorePages = response.pagination.page < response.pagination.totalPages
            } else {
                hasMorePages = false
            }
        } catch {
            errorMessage = error.localizedDescription
            // Don't revert page on error - allow retry
        }
        
        isLoadingMore = false
        isLoadingNextPage = false
    }
    
    // Clears everything and reloads from page 1, for pull to refresh.
    func refresh() async {
        currentPage = 1
        feedItems = []
        hasMorePages = true
        isLoadingNextPage = false
        await loadFeed()
    }
    
    // Check if we should load more based on item index
    // Called as each row appears. When the user is within 3 items of the end, it quietly loads
    // the next page.
    func shouldLoadMore(for itemIndex: Int) {
        // Load more when user is 3 items away from the end
        let threshold = feedItems.count - 3
        if itemIndex >= threshold && hasMorePages && !isLoadingMore && !isLoadingNextPage {
            Task {
                await loadMore()
            }
        }
    }
}

