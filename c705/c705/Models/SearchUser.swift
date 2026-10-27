//
//  SearchUser.swift
//  c705
//
//  Model for user search results
//
//  PURPOSE: Describes one person returned when the app searches for users, for
//  example when inviting someone to a cypher.
//

import Foundation

// Codable lets this be filled in automatically from the server's JSON. Identifiable gives each
// row a unique id so SwiftUI lists can tell rows apart.
struct SearchUser: Identifiable, Codable {
    let id: String
    let username: String?
    let email: String
    let role: String
}
