//
//  Cypher.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: All the data shapes for cyphers: a cypher, its entries, votes, the
//  leaderboard, the top-cyphers list and invites. These must match
//  what the backend sends, field for field.
//

import Foundation

// The kind of cypher. The text in quotes is exactly what the server sends and expects.
enum CypherType: String, Codable {
    case open = "OPEN"
    case competitive = "COMPETITIVE"
    case beatLocked = "BEAT_LOCKED"
}

// Who can see a cypher: everyone (public) or only people who were invited.
enum CypherVisibility: String, Codable {
    case `public` = "PUBLIC"
    case inviteOnly = "INVITE_ONLY"
}

// Whether a cypher is still taking entries.
enum CypherStatus: String, Codable {
    case open = "OPEN"
    case closed = "CLOSED"
}

// One cypher as shown in lists. entryCount is read from a nested _count field in the server's
// JSON.
struct Cypher: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let beatUrl: String?
    let isActive: Bool
    let cypherType: CypherType
    let startDate: String
    let endDate: String?
    let createdAt: String
    let entryCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case beatUrl
        case isActive
        case cypherType
        case startDate
        case endDate
        case createdAt
        case _count
    }
    
    struct Count: Codable {
        let entries: Int
    }
    
    // Decoding by hand, because entryCount does not sit at the top level of the JSON. try?
    // means a missing _count just becomes nil instead of an error.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        beatUrl = try container.decodeIfPresent(String.self, forKey: .beatUrl)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        cypherType = try container.decode(CypherType.self, forKey: .cypherType)
        startDate = try container.decode(String.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        
        // Handle nested _count structure
        if let count = try? container.decode(Count.self, forKey: ._count) {
            entryCount = count.entries
        } else {
            entryCount = nil
        }
    }
    
    // The reverse: turn the cypher back into JSON, putting entryCount back inside _count.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(beatUrl, forKey: .beatUrl)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(cypherType, forKey: .cypherType)
        try container.encode(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(createdAt, forKey: .createdAt)
        
        // Encode _count if entryCount is available
        if let entryCount = entryCount {
            let count = Count(entries: entryCount)
            try container.encode(count, forKey: ._count)
        }
    }
}

// A page of cyphers plus paging numbers.
struct CypherResponse: Codable {
    let cyphers: [Cypher]
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int
}

// One artist's recording inside a cypher. audioUrl is the sound file, averageScore the current
// rating, and voteCount how many people voted.
struct CypherEntry: Codable, Identifiable {
    let id: String
    let cypherId: String
    let userId: String
    let audioUrl: String
    let title: String?
    let createdAt: String
    let averageScore: Double?
    let voteCount: Int
    let user: CypherEntryUser?
    
    struct CypherEntryUser: Codable {
        let id: String
        let username: String?
        let email: String
    }
}

// A page of entries plus paging numbers.
struct CypherEntriesResponse: Codable {
    let entries: [CypherEntry]
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int
}

// A full cypher with all of its entries, shown on the cypher's detail screen. userEntry is the
// signed-in user's own entry, if they posted one.
struct CypherDetail: Codable {
    let id: String
    let title: String
    let description: String?
    let beatUrl: String?
    let isActive: Bool
    let cypherType: CypherType
    let startDate: String
    let endDate: String?
    let createdAt: String
    let entries: [CypherEntry]
    let userEntry: CypherEntry?
}

// One entry together with its rank on the leaderboard.
struct LeaderboardEntry: Codable {
    let rank: Int
    let entry: CypherEntry
}

// What the app sends when someone votes: a 1 to 5 score for each of Bars, Flow and Creativity.
struct VoteRequest: Codable {
    let bars: Int
    let flow: Int
    let creativity: Int
}

// The server's reply after a vote, with the entry's new average score and vote count.
struct VoteResponse: Codable {
    let message: String
    let averageScore: Double
    let voteCount: Int
}

// MARK: - Top Cyphers

// A cypher in the Popular list, with engagement numbers the server worked out (entries, votes,
// artists, score).
struct TopCypher: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let beatUrl: String?
    let host: HostInfo
    let entryCount: Int
    let voteCount: Int
    let uniqueArtists: Int
    let score: Int
    let createdAt: String
    let startDate: String
    let endDate: String?
    
    struct HostInfo: Codable {
        let id: String
        let username: String?
        let email: String
    }
}

// A wrapper around the list of top cyphers.
struct TopCyphersResponse: Codable {
    let cyphers: [TopCypher]
}

// MARK: - Cypher Invites

// An invitation to join a cypher. status is pending, accepted or declined.
struct CypherInvite: Codable, Identifiable {
    let id: String
    let cypherId: String
    let invitedArtistId: String
    let invitedByArtistId: String
    let status: String // pending, accepted, declined
    let createdAt: String
    let respondedAt: String?
    let cypher: InviteCypherInfo
    let invitedBy: InviteUserInfo
    
    struct InviteCypherInfo: Codable {
        let id: String
        let title: String
        let host: HostInfo
        let entryCount: Int
    }
    
    struct InviteUserInfo: Codable {
        let id: String
        let username: String?
        let email: String
    }
    
    struct HostInfo: Codable {
        let id: String
        let username: String?
        let email: String
    }
}

// What the app sends to invite someone to a cypher.
struct InviteArtistRequest: Codable {
    let artistId: String
}

// What the app sends to accept or decline an invite.
struct RespondToInviteRequest: Codable {
    let response: String // "accepted" or "declined"
}

