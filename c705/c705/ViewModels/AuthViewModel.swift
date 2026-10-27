//
//  AuthViewModel.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: Holds the login and sign-up form's data (username, email, password
//  and so on) and checks it before sending it on to AuthService. A
//  ViewModel keeps a screen's data and logic apart from how it looks.
//

import Foundation
import Combine

@MainActor
// @Published values (the typed text, loading state) redraw the login screen whenever they
// change.
class AuthViewModel: ObservableObject {
    @Published var username = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var selectedRole = "ARTIST"
    @Published var isSignupMode = false
    @Published var isLoading = false
    @Published var showEmailLogin = false
    
    // Use the shared AuthService from environment instead of creating a new one
    // The app-wide sign-in service, handed in by the screen instead of creating a second one.
    var authService: AuthService?
    
    // These three read-only values simply pass through what AuthService knows.
    var isAuthenticated: Bool {
        authService?.isAuthenticated ?? false
    }
    
    var currentUser: AppUser? {
        authService?.currentUser
    }
    
    var errorMessage: String? {
        authService?.errorMessage
    }
    
    // Sends the typed email and password to AuthService and shows a loading spinner while
    // waiting.
    func login() async {
        guard let authService = authService else { return }
        isLoading = true
        await authService.login(email: email, password: password)
        isLoading = false
    }
    
    // Checks the form first (passwords match, nothing left empty) and sets an error message if
    // not. Entering a journalist access code switches the account type to JOURNALIST.
    func signup(accessCode: String? = nil) async {
        guard let authService = authService else { return }
        
        guard password == confirmPassword else {
            authService.errorMessage = "Passwords do not match"
            return
        }
        
        guard !username.isEmpty else {
            authService.errorMessage = "Username is required"
            return
        }
        
        guard !email.isEmpty else {
            authService.errorMessage = "Email is required"
            return
        }
        
        guard !password.isEmpty else {
            authService.errorMessage = "Password is required"
            return
        }
        
        // If access code is provided, set role to JOURNALIST
        var role = selectedRole
        if let accessCode = accessCode, !accessCode.isEmpty {
            role = "JOURNALIST"
        }
        
        isLoading = true
        await authService.signup(username: username, email: email, password: password, role: role, accessCode: accessCode)
        isLoading = false
    }
    
    // Signs out and clears the typed passwords.
    func logout() {
        authService?.logout()
        email = ""
        password = ""
        confirmPassword = ""
    }
}

