//
//  ArtistProfile.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: Shapes of an artist's public profile page and of following other
//  artists.
//

import Foundation

// Everything the profile screen shows: name, bio, city, social links, follower and track
// counts, and the tracks themselves.
struct ArtistProfile: Codable, Identifiable {
    let id: String
    let name: String
    let bio: String?
    let email: String
    let role: String
    let city: String?
    let avatarUrl: String?
    let instagramUrl: String?
    let youtubeUrl: String?
    let xUrl: String?
    let tiktokUrl: String?
    let followersCount: Int
    let tracksCount: Int
    let tracks: [Track]?
    let isFollowing: Bool?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case bio
        case email
        case role
        case city
        case avatarUrl
        case instagramUrl
        case youtubeUrl
        case xUrl
        case tiktokUrl
        case followersCount
        case tracksCount
        case tracks
        case isFollowing
        case createdAt
    }
}

// A page of one artist's tracks.
struct ArtistTracksResponse: Codable {
    let tracks: [Track]
    let pagination: Pagination
}

// The server's confirmation after following or unfollowing an artist.
struct FollowResponse: Codable {
    let message: String
    let artistId: String
}

// A page of the people who follow an artist.
struct FollowersResponse: Codable {
    let followers: [Follower]
    let pagination: Pagination
}

// One follower and when they followed.
struct Follower: Codable, Identifiable {
    let id: String
    let email: String
    let role: String
    let followedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case role
        case followedAt
    }
}

