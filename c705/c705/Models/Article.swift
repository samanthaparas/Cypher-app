//
//  Article.swift
//  c705
//
//  Created for Article models
//
//  PURPOSE: Shapes of the articles section: a page of articles, one article,
//  and its author.
//

import Foundation

// A page of articles plus paging info, so the app knows if more pages can be loaded.
struct ArticlesResponse: Codable {
    let articles: [Article]
    let pagination: Pagination
    
    struct Pagination: Codable {
        let page: Int
        let limit: Int
        let total: Int
        let totalPages: Int
    }
}

// One article written by a journalist, tied to a city.
struct Article: Codable, Identifiable {
    let id: String
    let title: String
    let content: String
    let city: String
    let author: ArticleAuthor
    let createdAt: String
}

// The small author record shown with each article.
struct ArticleAuthor: Codable {
    let id: String
    let email: String
    let username: String?
}
