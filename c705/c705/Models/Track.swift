 //
//  Track.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: Shapes of a track (a song an artist uploaded) and the Artist
//  attached to it.
//

import Foundation

// One uploaded song. audioUrl is where the sound file lives, and likeCount is how many people
// liked it.
struct Track: Codable, Identifiable {
    let id: String
    let title: String
    let audioUrl: String
    let artistId: String
    let likeCount: Int
    let createdAt: String
    let artist: Artist?
    // This is a var (changeable) because the app flips it right away when the user taps like.
    var isLiked: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case audioUrl
        case artistId
        case likeCount
        case createdAt
        case artist
        case isLiked
    }
}

// A short artist profile: a bio plus the AppUser account behind it.
struct Artist: Codable, Identifiable {
    let id: String
    let bio: String?
    let user: AppUser?
    
    enum CodingKeys: String, CodingKey {
        case id
        case bio
        case user
    }
}

