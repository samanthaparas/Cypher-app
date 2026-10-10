//
//  AuthService.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//

import Foundation
import Combine

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: AppUser?
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private let keychain = KeychainService.shared
    
    // Keychain keys
    private let tokenKey = "authToken"
    private let userKey = "currentUser"
    
    // UserDefaults key to track if user has completed first authentication
    private let hasCompletedFirstAuthKey = "hasCompletedFirstAuth"
    
    init() {
        // Always start with isAuthenticated = false to show login screen first
        // Auto-login will be handled after the login screen loads
        self.isAuthenticated = false
        self.currentUser = nil
    }
    
    func attemptAutoLogin() {
        // Only enable auto-login if user has completed their first login/signup
        // This ensures new users always see the login screen first
        let hasCompletedFirstAuth = UserDefaults.standard.bool(forKey: hasCompletedFirstAuthKey)
        
        if hasCompletedFirstAuth {
            // User has logged in before, attempt auto-login
            if let token = keychain.get(forKey: tokenKey),
               let user = keychain.get(forKey: userKey, as: AppUser.self) {
                apiService.setAuthToken(token)
                self.currentUser = user
                self.isAuthenticated = true
            }
        }
        // If hasCompletedFirstAuth is false, don't auto-login (first time user)
    }
    
    func login(email: String, password: String) async {
        do {
            print("📝 Starting login process...")
            print("   - Email: \(email)")
            
            // Send login request to backend
            let response = try await apiService.login(email: email, password: password)
            
            print("✅ Login successful, saving credentials...")
            print("   - User ID: \(response.user.id)")
            print("   - User Email: \(response.user.email)")
            
            // Store token securely in Keychain
            let tokenSaved = keychain.save(response.accessToken, forKey: tokenKey)
            let userSaved = keychain.save(response.user, forKey: userKey)
            
            if tokenSaved && userSaved {
                // Mark that user has completed first authentication
                UserDefaults.standard.set(true, forKey: hasCompletedFirstAuthKey)
                
                // Update app state
                apiService.setAuthToken(response.accessToken)
                currentUser = response.user
                isAuthenticated = true
                errorMessage = nil
                print("✅ Login complete - user authenticated")
            } else {
                errorMessage = "Failed to save authentication data"
                isAuthenticated = false
                print("❌ Failed to save to Keychain")
            }
        } catch let error as APIError {
            print("❌ API Error during login: \(error)")
            print("   - Error Description: \(error.localizedDescription)")
            switch error {
            case .httpError(let code):
                if code == 400 {
                    errorMessage = "Invalid email or password. Please check your credentials and try again."
                } else if code == 401 {
                    errorMessage = "Invalid email or password. Please try again."
                } else if code == 500 {
                    errorMessage = "Server error. Please try again later."
                } else {
                    errorMessage = "Server error (Code: \(code)). Please try again."
                }
            case .httpErrorWithMessage(_, let message):
                errorMessage = message
            case .networkError(let message):
                errorMessage = message
            case .decodingError:
                errorMessage = "Invalid response from server. Please try again."
            case .invalidURL:
                errorMessage = "Invalid server URL. Please check your connection settings."
            case .invalidResponse:
                errorMessage = "Invalid response from server. Please try again."
            }
            isAuthenticated = false
        } catch {
            print("❌ Unexpected error during login: \(error)")
            print("   - Error Type: \(type(of: error))")
            print("   - Error Description: \(error.localizedDescription)")
            errorMessage = "Failed to log in: \(error.localizedDescription)"
            isAuthenticated = false
        }
    }
    
    func signup(username: String?, email: String, password: String, role: String = "ARTIST", accessCode: String? = nil) async {
        do {
            print("📝 Starting signup process...")
            print("   - Username: \(username ?? "nil")")
            print("   - Email: \(email)")
            print("   - Role: \(role)")
            print("   - Access Code: \(accessCode != nil ? "provided" : "none")")
            
            // Send signup request to backend
            let response = try await apiService.signup(username: username, email: email, password: password, role: role, accessCode: accessCode)
            
            print("✅ Signup successful, saving credentials...")
            print("   - User ID: \(response.user.id)")
            print("   - User Email: \(response.user.email)")
            
            // Store token securely in Keychain
            let tokenSaved = keychain.save(response.accessToken, forKey: tokenKey)
            let userSaved = keychain.save(response.user, forKey: userKey)
            
            if tokenSaved && userSaved {
                // Mark that user has completed first authentication
                UserDefaults.standard.set(true, forKey: hasCompletedFirstAuthKey)
                
                // Update app state
                apiService.setAuthToken(response.accessToken)
                currentUser = response.user
                isAuthenticated = true
                errorMessage = nil
                print("✅ Signup complete - user authenticated")
            } else {
                errorMessage = "Failed to save authentication data"
                isAuthenticated = false
                print("❌ Failed to save to Keychain")
            }
        } catch let error as APIError {
            print("❌ API Error during signup: \(error)")
            print("   - Error Description: \(error.localizedDescription)")
            switch error {
            case .httpError(let code):
                if code == 400 {
                    errorMessage = "Invalid request. Please check your information and try again."
                } else if code == 409 {
                    errorMessage = "An account with this email already exists."
                } else if code == 500 {
                    errorMessage = "Server error. Please try again later."
                } else {
                    errorMessage = "Server error (Code: \(code)). Please try again."
                }
            case .httpErrorWithMessage(_, let message):
                errorMessage = message
            case .networkError(let message):
                errorMessage = message
            case .decodingError:
                errorMessage = "Invalid response from server. Please try again."
            case .invalidURL:
                errorMessage = "Invalid server URL. Please check your connection settings."
            case .invalidResponse:
                errorMessage = "Invalid response from server. Please try again."
            }
            isAuthenticated = false
        } catch {
            print("❌ Unexpected error during signup: \(error)")
            print("   - Error Type: \(type(of: error))")
            print("   - Error Description: \(error.localizedDescription)")
            errorMessage = "Failed to create account: \(error.localizedDescription)"
            isAuthenticated = false
        }
    }
    
    func signInWithApple(identityToken: String, email: String?, fullName: String?, role: String) async {
        do {
            let baseURL = apiService.getBaseURL()
            print("📡 Sending Apple Sign In request to backend...")
            print("   - Email: \(email ?? "nil")")
            print("   - Role: \(role)")
            print("   - Identity Token Length: \(identityToken.count)")
            print("   - Base URL: \(baseURL)")
            
            // Check if using HTTP on physical device (will fail for Apple Sign In)
            #if !targetEnvironment(simulator)
            if baseURL.hasPrefix("http://") && !baseURL.contains("localhost") {
                print("⚠️ WARNING: Using HTTP on physical device - Apple Sign In requires HTTPS")
                print("⚠️ This request will likely timeout. Please configure an HTTPS URL (ngrok or production)")
            }
            #endif
            
            let response = try await apiService.signInWithApple(
                identityToken: identityToken,
                email: email,
                fullName: fullName,
                role: role
            )
            
            print("✅ Backend response received")
            print("   - User ID: \(response.user.id)")
            print("   - User Email: \(response.user.email)")
            print("   - User Role: \(response.user.role)")
            
            let tokenSaved = keychain.save(response.accessToken, forKey: tokenKey)
            let userSaved = keychain.save(response.user, forKey: userKey)
            
            if tokenSaved && userSaved {
                // Mark that user has completed first authentication
                UserDefaults.standard.set(true, forKey: hasCompletedFirstAuthKey)
                
                apiService.setAuthToken(response.accessToken)
                currentUser = response.user
                
                // Check if this is a new user who needs to select account type
                // For Apple Sign In, if isNewUser is true, we'll show account type selection
                // The LoginView will handle routing based on this
                if let isNewUser = response.isNewUser, isNewUser {
                    // Don't set isAuthenticated to true yet - let user select account type first
                    // Store a flag that account type selection is needed
                    UserDefaults.standard.set(true, forKey: "needsAccountTypeSelection")
                    print("✅ New user authenticated - account type selection needed")
                } else {
                    isAuthenticated = true
                    UserDefaults.standard.set(false, forKey: "needsAccountTypeSelection")
                    print("✅ Authentication successful and saved to Keychain")
                }
                errorMessage = nil
            } else {
                errorMessage = "Failed to save authentication data securely"
                isAuthenticated = false
                print("❌ Failed to save to Keychain")
            }
        } catch let error as APIError {
            // Handle API errors with better messages
            print("❌ API Error: \(error)")
            print("   - Error Type: APIError")
            print("   - Localized Description: \(error.localizedDescription)")
            
            // Special handling for Apple Sign In timeout errors on physical devices
            let baseURL = apiService.getBaseURL()
            let isPhysicalDevice = !baseURL.contains("localhost")
            let isUsingHTTP = baseURL.hasPrefix("http://")
            
            switch error {
            case .httpError(let code):
                print("   - HTTP Status Code: \(code)")
                if code == 400 {
                    errorMessage = "Invalid sign-in request. Please check your information and try again."
                } else if code == 401 {
                    errorMessage = "Authentication failed. Please try again."
                } else if code == 500 {
                    errorMessage = "Server error. Please try again later."
                } else {
                    errorMessage = "Server error (Code: \(code)). Please try again later."
                }
            case .httpErrorWithMessage(_, let message):
                print("   - HTTP Error with Message: \(message)")
                errorMessage = message
            case .decodingError(let decodeError):
                print("   - Decoding Error: \(decodeError)")
                errorMessage = "Invalid response from server. Please try again."
            case .networkError(let message):
                print("   - Network Error: \(message)")
                // Provide helpful guidance for timeout errors on physical devices
                if message.contains("timed out") && isPhysicalDevice && isUsingHTTP {
                    errorMessage = """
                    Connection timeout. This backend is currently using HTTP.

                    Apple Sign In on physical devices requires HTTPS.
                    For now, basic API calls may work over HTTP, but Apple Sign In may fail until the backend is served over HTTPS with a real domain or IP certificate.
                    """
                } else {
                    errorMessage = message
                }
            case .invalidURL:
                errorMessage = "Invalid server URL. Please check your connection settings."
            case .invalidResponse:
                errorMessage = "Invalid response from server. Please try again."
            }
            isAuthenticated = false
        } catch {
            print("❌ Unexpected Error: \(error)")
            print("   - Error Type: \(type(of: error))")
            print("   - Error Description: \(error.localizedDescription)")
            print("   - Full Error: \(error)")
            
            // Provide more helpful error message
            let errorDescription = error.localizedDescription
            if errorDescription.contains("network") || errorDescription.contains("connection") {
                errorMessage = "Cannot connect to server. Please check if the backend is running and your network connection."
            } else if errorDescription.contains("timeout") {
                errorMessage = "Request timed out. The server may be unavailable. Please try again."
            } else if errorDescription.isEmpty {
                errorMessage = "An unknown error occurred. Please check the Xcode console for details."
            } else {
                errorMessage = "Failed to sign in: \(errorDescription)"
            }
            isAuthenticated = false
        }
    }
    
    func signInWithGoogle(idToken: String, email: String?, fullName: String?, role: String) async {
        do {
            let response = try await apiService.signInWithGoogle(
                idToken: idToken,
                email: email,
                fullName: fullName,
                role: role
            )
            
            let tokenSaved = keychain.save(response.accessToken, forKey: tokenKey)
            let userSaved = keychain.save(response.user, forKey: userKey)
            
            if tokenSaved && userSaved {
                // Mark that user has completed first authentication
                UserDefaults.standard.set(true, forKey: hasCompletedFirstAuthKey)
                
                apiService.setAuthToken(response.accessToken)
                currentUser = response.user
                isAuthenticated = true
                errorMessage = nil
            } else {
                errorMessage = "Failed to save authentication data"
                isAuthenticated = false
            }
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
    }
    
    /// Deletes the account on the server first. Only signs out if that succeeds,
    /// so a failed request never leaves the user believing their data is gone.
    func deleteAccount() async throws {
        _ = try await apiService.deleteAccount()
        logout()
    }

    func logout() {
        // Clear API token
        apiService.clearAuthToken()
        
        // Remove from Keychain
        _ = keychain.delete(forKey: tokenKey)
        _ = keychain.delete(forKey: userKey)
        
        // Update app state
        currentUser = nil
        isAuthenticated = false
    }
}

