//
//  User.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The app's user type, used for signed-in users and for people shown
//  in lists.
//

import Foundation

// One person. username is optional because the server does not always send one.
struct AppUser: Codable, Identifiable {
    let id: String
    let email: String
    let role: String
    let username: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case role
        case username
    }
    
    // Encoding means turning this user back into JSON, for example to save it.
    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(username, forKey: .username)
    }
    
    // Make username optional for decoding - handle missing username gracefully
    // Decoding by hand lets the app accept a missing or null username instead of failing.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        role = try container.decode(String.self, forKey: .role)
        // Username is optional - backend may not always include it, or it may be null
        // decodeIfPresent handles both missing key and null value automatically
        username = try container.decodeIfPresent(String.self, forKey: .username)
    }
}

// Typealias for backward compatibility with API responses
// An alias is a second name for the same type, so older code that says User keeps working.
typealias User = AppUser

