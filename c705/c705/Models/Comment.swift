//
//  Comment.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: Shapes of track comments: one comment, the request to post one, and
//  a page of comments.
//

import Foundation

// One comment on a track, with the user who wrote it.
struct Comment: Codable, Identifiable {
    let id: String
    let content: String
    let trackId: String?
    let userId: String
    let createdAt: String
    let user: AppUser?
    let track: Track?
    
    // CodingKeys lists which JSON field names map to which Swift properties.
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case trackId
        case userId
        case createdAt
        case user
        case track
    }
}

// What the app sends to the server to post a new comment.
struct CreateCommentRequest: Codable {
    let content: String
    let trackId: String
}

// A page of comments plus paging info (Pagination is defined in FeedItem.swift).
struct CommentsResponse: Codable {
    let comments: [Comment]
    let pagination: Pagination
}

