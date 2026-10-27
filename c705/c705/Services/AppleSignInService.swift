//
//  AppleSignInService.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: Shows Apple's "Sign in with Apple" sheet and returns the result.
//  AuthService then sends that result to the backend.
//

import Foundation
import AuthenticationServices

@MainActor
// NSObject is needed because Apple's sign-in system talks to this class through delegate
// methods.
class AppleSignInService: NSObject {
    static let shared = AppleSignInService()
    
    // A continuation bridges the old callback style to async/await: signIn() pauses here until
    // a delegate method below delivers the result.
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    
    private override init() {
        super.init()
    }
    
    // Builds the Apple request (asking for name and email), shows Apple's sheet, and waits
    // until the user finishes.
    func signIn() async throws -> AppleSignInResult {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            
            // Perform requests on main thread
            DispatchQueue.main.async {
                authorizationController.performRequests()
            }
        }
    }
}

// These methods are called by Apple when the sheet finishes: one for success and one for an
// error or cancel.
extension AppleSignInService: ASAuthorizationControllerDelegate {
    // Success: pulls the identity token, name and email out of Apple's reply and hands them
    // back to signIn().
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = appleIDCredential.user
            let email = appleIDCredential.email
            let fullName = appleIDCredential.fullName
            
            var name: String? = nil
            if let givenName = fullName?.givenName, let familyName = fullName?.familyName {
                name = "\(givenName) \(familyName)"
            } else if let givenName = fullName?.givenName {
                name = givenName
            } else if let familyName = fullName?.familyName {
                name = familyName
            }
            
            // Get identity token
            guard let identityToken = appleIDCredential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                continuation?.resume(throwing: AppleSignInError.failedToGetToken)
                continuation = nil
                return
            }
            
            let result = AppleSignInResult(
                userIdentifier: userIdentifier,
                email: email,
                fullName: name,
                identityToken: tokenString
            )
            
            continuation?.resume(returning: result)
            continuation = nil
        } else {
            continuation?.resume(throwing: AppleSignInError.invalidCredential)
            continuation = nil
        }
    }
    
    // Failure or cancel: turns Apple's error into a friendlier AppleSignInError.
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Provide more user-friendly error messages
        if let authError = error as? ASAuthorizationError {
            let userFriendlyError: AppleSignInError
            switch authError.code {
            case .canceled:
                userFriendlyError = .userCanceled
            case .failed:
                userFriendlyError = .authorizationFailed
            case .invalidResponse:
                userFriendlyError = .invalidResponse
            case .notHandled:
                userFriendlyError = .notHandled
            case .unknown:
                userFriendlyError = .unknown
            case .notInteractive:
                userFriendlyError = .authorizationFailed
            case .matchedExcludedCredential:
                userFriendlyError = .authorizationFailed
            case .credentialImport:
                userFriendlyError = .authorizationFailed
            case .credentialExport:
                userFriendlyError = .authorizationFailed
            case .preferSignInWithApple:
                userFriendlyError = .authorizationFailed
            case .deviceNotConfiguredForPasskeyCreation:
                userFriendlyError = .notConfigured
            @unknown default:
                userFriendlyError = .unknown
            }
            continuation?.resume(throwing: userFriendlyError)
            continuation = nil
            return
        }
        
        // If it's not an ASAuthorizationError, wrap it
        continuation?.resume(throwing: AppleSignInError.unknown)
        continuation = nil
    }
}

// Tells Apple which window to show the sign-in sheet on.
extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        // Fallback: create a new window with the first available window scene
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return UIWindow(windowScene: windowScene)
        }
        // Last resort fallback - create a window with a default scene
        // This should rarely be needed, but provides a safe fallback
        if #available(iOS 15.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                return UIWindow(windowScene: windowScene)
            }
        }
        // This should never be reached in modern iOS, but provides compilation safety
        fatalError("Unable to find window scene for Apple Sign In")
    }
}

// What a successful sign-in gives back: the identity token plus the optional email and name.
struct AppleSignInResult {
    let userIdentifier: String
    let email: String?
    let fullName: String?
    let identityToken: String
}

// The messages shown when Apple sign-in fails.
enum AppleSignInError: LocalizedError {
    case failedToGetToken
    case invalidCredential
    case userCanceled
    case authorizationFailed
    case invalidResponse
    case notHandled
    case unknown
    case notConfigured
    
    var errorDescription: String? {
        switch self {
        case .failedToGetToken:
            return "Failed to get identity token from Apple. Please try again."
        case .invalidCredential:
            return "Invalid Apple credential. Please try again."
        case .userCanceled:
            return "Sign in was canceled."
        case .authorizationFailed:
            return "Authorization failed. Please make sure Sign in with Apple is enabled in your device settings."
        case .invalidResponse:
            return "Invalid response from Apple. Please try again."
        case .notHandled:
            return "Sign in with Apple is not properly configured. Please contact support."
        case .unknown:
            return "An unknown error occurred. Please try again."
        case .notConfigured:
            return "Sign in with Apple is not configured. Please enable it in Xcode project settings."
        }
    }
}

