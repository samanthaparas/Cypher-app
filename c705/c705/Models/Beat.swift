//
//  Beat.swift
//  c705
//
//  Created for Beats feature
//
//  PURPOSE: Data shapes for the beats marketplace: a beat, its producer, and
//  the requests and replies for buying, previewing and reporting.
//

import Foundation

// MARK: - Beat Response Models

// One beat for sale. previewUrl is a short sample anyone can hear, fullUrl is the whole file,
// and price is in cents.
struct Beat: Codable, Identifiable {
    let id: String
    let title: String
    let genre: String
    let bpm: Int
    let mood: String?
    let previewUrl: String
    let fullUrl: String
    let price: Int // Price in cents
    let producerId: String
    let createdAt: String
    let isPurchased: Bool?
    let purchaseCount: Int?
    
    // Producer info
    let producer: BeatProducer?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case genre
        case bpm
        case mood
        case previewUrl
        case fullUrl
        case price
        case producerId
        case createdAt
        case isPurchased
        case producer
        case _count
    }
    
    // Helper struct for nested _count
    struct Count: Codable {
        let purchases: Int
    }
    
    // Decoding by hand so purchaseCount can be read from the nested _count field the server
    // sends.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        genre = try container.decode(String.self, forKey: .genre)
        bpm = try container.decode(Int.self, forKey: .bpm)
        mood = try container.decodeIfPresent(String.self, forKey: .mood)
        previewUrl = try container.decode(String.self, forKey: .previewUrl)
        fullUrl = try container.decode(String.self, forKey: .fullUrl)
        price = try container.decode(Int.self, forKey: .price)
        producerId = try container.decode(String.self, forKey: .producerId)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        isPurchased = try container.decodeIfPresent(Bool.self, forKey: .isPurchased)
        producer = try container.decodeIfPresent(BeatProducer.self, forKey: .producer)
        
        // Decode purchase count from _count
        if let count = try? container.decode(Count.self, forKey: ._count) {
            purchaseCount = count.purchases
        } else {
            purchaseCount = nil
        }
    }
    
    // The reverse: turn the beat back into JSON.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(genre, forKey: .genre)
        try container.encode(bpm, forKey: .bpm)
        try container.encodeIfPresent(mood, forKey: .mood)
        try container.encode(previewUrl, forKey: .previewUrl)
        try container.encode(fullUrl, forKey: .fullUrl)
        try container.encode(price, forKey: .price)
        try container.encode(producerId, forKey: .producerId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(isPurchased, forKey: .isPurchased)
        try container.encodeIfPresent(producer, forKey: .producer)
    }
}

// The producer who made the beat.
struct BeatProducer: Codable {
    let id: String
    let username: String?
    let email: String
}

// A page of beats plus paging numbers.
struct BeatsResponse: Codable {
    let beats: [Beat]
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int
}

// A record that a user bought a beat. receipt is Apple's proof of purchase.
struct BeatPurchase: Codable {
    let id: String
    let beatId: String
    let userId: String
    let receipt: String
    let createdAt: String
    let beat: Beat
}

// What the app sends after an in-app purchase so the server can record it.
struct PurchaseBeatRequest: Codable {
    let receipt: String
}

struct PurchaseBeatResponse: Codable {
    let id: String
    let beatId: String
    let userId: String
    let receipt: String
    let createdAt: String
    let beat: Beat
}

// The server's reply when the app asks for a beat's preview link.
struct PreviewUrlResponse: Codable {
    let previewUrl: String
}

struct FullUrlResponse: Codable {
    let fullUrl: String
}

// What the app sends when someone reports a beat.
struct ReportBeatRequest: Codable {
    let reason: String
}

struct ReportBeatResponse: Codable {
    let message: String
}

