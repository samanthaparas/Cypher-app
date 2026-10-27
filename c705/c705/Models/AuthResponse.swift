//
//  AuthResponse.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: Shapes of the data sent to and received from the sign-in and
//  sign-up requests.
//

import Foundation

// What the server returns after a successful login or sign-up: a token proving who you are,
// plus your user.
struct AuthResponse: Codable {
    let accessToken: String
    let user: AppUser
    let isNewUser: Bool? // Optional: indicates if user was just created (for OAuth flows)
    
    // The server names the token access_token; this maps it to the Swift name accessToken.
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case user
        case isNewUser
    }
    
    // Let Codable automatically synthesize the decoder using CodingKeys
    // This ensures proper mapping from "access_token" to accessToken
}

// What the app sends when someone logs in.
struct LoginRequest: Codable {
    let email: String
    let password: String
}

// What the app sends to create an account. role is the account type, and accessCode is only
// used by journalists.
struct SignupRequest: Codable {
    let username: String?
    let email: String
    let password: String
    let role: String
    let accessCode: String?
    
    enum CodingKeys: String, CodingKey {
        case username
        case email
        case password
        case role
        case accessCode
    }
    
    init(username: String?, email: String, password: String, role: String, accessCode: String? = nil) {
        self.username = username
        self.email = email
        self.password = password
        self.role = role
        self.accessCode = accessCode
    }
}

