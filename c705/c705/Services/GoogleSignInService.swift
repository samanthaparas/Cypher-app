//
//  GoogleSignInService.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: Shows Google's sign-in screen and returns the result, the same job
//  AppleSignInService does for Apple. It only works if Google's
//  sign-in library has been added to the project.
//

import Foundation
// This line only compiles the Google code when Google's library is installed, so the app still
// builds without it.
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@MainActor
// Use GoogleSignInService.shared to start a Google sign-in.
class GoogleSignInService {
    static let shared = GoogleSignInService()
    
    private init() {
        // Configure Google Sign In
        // Note: You'll need to add your Google Client ID to Info.plist
        // and configure it in GoogleSignIn.configure() when ready
    }
    
    // Finds the screen to show Google's sheet on, runs the sign-in, and returns the token,
    // email and name.
    func signIn() async throws -> GoogleSignInResult {
        #if canImport(GoogleSignIn)
        // Get the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw GoogleSignInError.noRootViewController
        }
        
        // Check for Google Client ID in multiple locations
        var clientID: String?
        
        // Check environment variable
        clientID = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"]
        
        // Check Info.plist
        if clientID == nil {
            clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String
        }
        
        // Check for GoogleService-Info.plist (Firebase style)
        if clientID == nil, let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let clientIdFromPlist = plist["CLIENT_ID"] as? String {
            clientID = clientIdFromPlist
        }
        
        guard let clientID = clientID, !clientID.isEmpty else {
            throw GoogleSignInError.notConfigured
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Perform sign in
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInError.failedToGetToken
        }
        
        let email = result.user.profile?.email
        let fullName = result.user.profile?.name
        let givenName = result.user.profile?.givenName
        let familyName = result.user.profile?.familyName
        
        return GoogleSignInResult(
            userID: result.user.userID ?? "",
            email: email,
            fullName: fullName,
            givenName: givenName,
            familyName: familyName,
            idToken: idToken
        )
        #else
        // Google Sign In SDK not installed
        throw GoogleSignInError.sdkNotInstalled
        #endif
    }
}

// What a successful Google sign-in gives back.
struct GoogleSignInResult {
    let userID: String
    let email: String?
    let fullName: String?
    let givenName: String?
    let familyName: String?
    let idToken: String
}

// The messages shown when Google sign-in fails or is not set up.
enum GoogleSignInError: LocalizedError {
    case notConfigured
    case sdkNotInstalled
    case noRootViewController
    case failedToGetToken
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Google Sign In is not configured. Please add your Google Client ID to Info.plist or install the Google Sign In SDK."
        case .sdkNotInstalled:
            return "Google Sign In SDK is not installed. Please add it via Swift Package Manager or CocoaPods."
        case .noRootViewController:
            return "Unable to find root view controller. Please try again."
        case .failedToGetToken:
            return "Failed to get ID token from Google. Please try again."
        }
    }
}

