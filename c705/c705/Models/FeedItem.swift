//
//  FeedItem.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: Shapes of the Home feed. The feed mixes tracks and articles, so one
//  FeedItem can be either kind.
//

import Foundation

// The two kinds of thing that can appear in the feed.
enum FeedItemType: String, Codable {
    case track
    case article
}

// One feed entry. Fields that only apply to tracks or only to articles are optional (?) and
// stay empty for the other kind.
struct FeedItem: Codable, Identifiable {
    let id: String
    let type: FeedItemType
    let title: String
    let createdAt: String
    
    // Track-specific properties
    let audioUrl: String?
    let likeCount: Int?
    let isLiked: Bool?
    let artist: Artist?
    
    // Article-specific properties
    let content: String?
    let city: String?
    let author: AppUser?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case createdAt
        case audioUrl
        case likeCount
        case isLiked
        case artist
        case content
        case city
        case author
    }
}

// A page of feed items plus paging info.
struct FeedResponse: Codable {
    let feed: [FeedItem]
    let pagination: Pagination
}

// Paging info shared by several lists in the app (the feed, comments, artist tracks): which
// page, how many per page, and the totals.
struct Pagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

