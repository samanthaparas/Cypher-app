//
//  News.swift
//  c705
//
//  Created for Hip-Hop News models
//
//  PURPOSE: Shapes of the hip-hop news data the server sends for the Latest
//  News section.
//

import Foundation

// The wrapper the server sends back: a list of news stories plus a total count.
struct HipHopNewsResponse: Codable {
    let articles: [NewsArticle]
    let total: Int
}

// One news story. A type followed by ? (like String?) means the server may leave that field
// out.
struct NewsArticle: Codable, Identifiable {
    let id: String
    let title: String
    let summary: String
    let source: String
    let url: String
    let imageUrl: String?
    let publishedAt: String
    let author: String?
}

