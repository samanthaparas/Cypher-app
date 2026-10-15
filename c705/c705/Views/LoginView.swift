//
//  LoginView.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @EnvironmentObject var authService: AuthService
    @State private var showRoleSelection = false // Start with login/signup screen, not role selection
    @State private var selectedRole = "ARTIST"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isSignupMode = false // Track if we're in signup mode
    @State private var showAccountTypeSelection = false
    
    // Initialize viewModel with authService when LoginView appears
    init() {
        // ViewModel will be set up in onAppear
    }
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
                    .environmentObject(authService)
            } else if showAccountTypeSelection {
                AccountTypeSelectionView()
                    .environmentObject(authService)
            } else {
                loginContent
                    // The photo and overlay are dark, so use light status bar text.
                    // Black time/battery was unreadable on top of his dark hair.
                    .preferredColorScheme(.dark)
                    .onAppear {
                        // Set the shared AuthService in the view model
                        viewModel.authService = authService
                        // Check if account type selection is needed
                        if UserDefaults.standard.bool(forKey: "needsAccountTypeSelection") {
                            showAccountTypeSelection = true
                        } else {
                            // Attempt auto-login after login screen appears
                            // This ensures login screen shows first, then auto-login happens
                            authService.attemptAutoLogin()
                        }
                    }
            }
        }
    }
    
    private var loginContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Image - sized perfectly for any iPhone screen, edge-to-edge
                Image("loginBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea(.all)
                    .overlay(
                        // Dark overlay for better text readability
                        Color.black.opacity(0.4)
                            .ignoresSafeArea(.all)
                    )
            
            if showRoleSelection {
                RoleSelectionView(
                    selectedRole: $selectedRole,
                    showLogin: Binding(
                        get: { !showRoleSelection },
                        set: { newValue in
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                if isSignupMode {
                                    // For signup, go directly to email form after role selection
                                    showRoleSelection = false
                                    viewModel.selectedRole = selectedRole
                                    viewModel.isSignupMode = true
                                    viewModel.showEmailLogin = true
                                } else {
                                    // For login, show Apple/Email buttons
                                    showRoleSelection = !newValue
                                }
                            }
                        }
                    ),
                    isSignupMode: $isSignupMode,
                    onBack: {
                        // Go back to login/signup options page
                        showRoleSelection = false
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            } else if isSignupMode && viewModel.showEmailLogin {
                // Show email form directly for signup after role selection
                EmailLoginView(
                    viewModel: viewModel,
                    onCancel: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            viewModel.showEmailLogin = false
                            showRoleSelection = true
                        }
                    }
                )
                    .environmentObject(authService)
                    .onAppear {
                        // Set the shared AuthService in the view model
                        viewModel.authService = authService
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                ZStack {
                    // Background Image - sized perfectly for any iPhone screen, edge-to-edge
                    Image("loginBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea(.all)
                        .overlay(
                            // Dark overlay for better text readability
                            Color.black.opacity(0.4)
                                .ignoresSafeArea(.all)
                        )
                    
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // C705 Title with animation - Responsive sizing
                        Text("C705")
                            .font(.system(size: min(geometry.size.width * 0.12, 48), weight: .bold))
                            .foregroundColor(.white)
                            .padding(.bottom, min(geometry.size.height * 0.07, 60))
                            .transition(.scale.combined(with: .opacity))
                        
                        Spacer()
                        
                        // Social Login/Signup Buttons - Responsive sizing
                        VStack(spacing: min(geometry.size.height * 0.02, 16)) {
                            // Sign in/up with Apple
                            Button(action: {
                                Task {
                                    await handleAppleSignIn()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "applelogo")
                                        .font(.system(size: min(geometry.size.width * 0.045, 18), weight: .medium))
                                    Text(isSignupMode ? "Sign up with Apple" : "Log in with Apple")
                                        .font(.system(size: min(geometry.size.width * 0.04, 16), weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: min(geometry.size.height * 0.06, 50))
                                .background(Color.black)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            
                            // Sign in/up with Email
                            Button(action: {
                                viewModel.selectedRole = selectedRole
                                viewModel.isSignupMode = isSignupMode
                                viewModel.showEmailLogin = true
                            }) {
                                HStack {
                                    Image(systemName: "envelope")
                                        .font(.system(size: min(geometry.size.width * 0.045, 18), weight: .medium))
                                    Text(isSignupMode ? "Sign up with Email" : "Log in with Email")
                                        .font(.system(size: min(geometry.size.width * 0.04, 16), weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: min(geometry.size.height * 0.06, 50))
                                .background(Color.black)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        .padding(.horizontal, min(geometry.size.width * 0.08, 32))
                        .padding(.bottom, min(geometry.size.height * 0.03, 24))
                        
                        // Toggle between login and signup - Responsive sizing
                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                if isSignupMode {
                                    // Switching back to login mode
                                    isSignupMode = false
                                    viewModel.showEmailLogin = false
                                } else {
                                    // Switching to signup mode - show role selection first
                                    isSignupMode = true
                                    showRoleSelection = true
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(isSignupMode ? "Already have an account?" : "Don't have an account?")
                                    .foregroundColor(.white.opacity(0.7))
                                Text(isSignupMode ? "Log in" : "Sign up")
                                    .foregroundColor(.blue)
                            }
                            .font(.system(size: min(geometry.size.width * 0.035, 14)))
                        }
                        .padding(.bottom, min(geometry.size.height * 0.05, 40))
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                    if isLoading {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
            }
            }
        }
        .animation(AppAnimations.smoothSpring, value: showRoleSelection)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: Binding(
            get: { viewModel.showEmailLogin && !isSignupMode },
            set: { viewModel.showEmailLogin = $0 }
        )) {
            EmailLoginView(viewModel: viewModel, onCancel: {
                viewModel.showEmailLogin = false
            })
                .environmentObject(authService)
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func handleAppleSignIn() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await AppleSignInService.shared.signIn()
            
            // Debug: Print what we got from Apple
            print("🍎 Apple Sign In Result:")
            print("   - User ID: \(result.userIdentifier)")
            print("   - Email: \(result.email ?? "nil")")
            print("   - Full Name: \(result.fullName ?? "nil")")
            print("   - Identity Token: \(result.identityToken.prefix(50))...")
            
            // Don't pass role for Apple Sign In - let user select it after authentication
            await authService.signInWithApple(
                identityToken: result.identityToken,
                email: result.email,
                fullName: result.fullName,
                role: "" // Empty role - will be set in account type selection
            )
            
            // Check authentication result
            if UserDefaults.standard.bool(forKey: "needsAccountTypeSelection") {
                // User needs to select account type
                showAccountTypeSelection = true
                errorMessage = nil
            } else if authService.isAuthenticated {
                errorMessage = nil
            } else {
                // Show error from auth service, or provide a default message
                if let authError = authService.errorMessage, !authError.isEmpty {
                    errorMessage = authError
                    print("❌ Auth Service Error: \(authError)")
                } else {
                    errorMessage = "Failed to complete sign in. Please check your connection and try again."
                    print("❌ Auth Service Error: No specific error message provided")
                }
            }
        } catch let error as AppleSignInError {
            // Provide user-friendly error messages for Apple Sign In errors
            if error == .userCanceled {
                // Don't show error if user canceled - just reset loading state
                errorMessage = nil
            } else {
                errorMessage = error.errorDescription ?? "An unknown error occurred. Please try again."
            }
            print("❌ Apple Sign In Error: \(error.errorDescription ?? "Unknown")")
        } catch {
            // Catch-all for other errors - provide more details
            let errorMsg = error.localizedDescription
            print("❌ Unexpected Error: \(error)")
            print("   - Error Type: \(type(of: error))")
            print("   - Error Description: \(errorMsg)")
            
            // Provide more helpful error message
            if errorMsg.contains("network") || errorMsg.contains("connection") {
                errorMessage = "Network error. Please check your internet connection and try again."
            } else if errorMsg.contains("timeout") {
                errorMessage = "Request timed out. Please try again."
            } else {
                errorMessage = "Failed to sign in with Apple: \(errorMsg.isEmpty ? "An unknown error occurred. Please try again." : errorMsg)"
            }
        }
        
        isLoading = false
    }
    
    private func getRoleIcon(_ role: String) -> String {
        switch role {
        case "ARTIST": return "music.note"
        case "PRODUCER": return "slider.horizontal.3"
        case "ENGINEER": return "wrench.and.screwdriver"
        case "JOURNALIST": return "newspaper"
        default: return "person"
        }
    }
    
    private func getRoleName(_ role: String) -> String {
        switch role {
        case "ARTIST": return "Artist"
        case "PRODUCER": return "Producer"
        case "ENGINEER": return "Engineer"
        case "JOURNALIST": return "Journalist"
        default: return "User"
        }
    }
}

struct EmailLoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    @FocusState private var focusedField: Field?
    @State private var showJournalistAccessCode = false
    @State private var journalistAccessCode = ""
    var onCancel: (() -> Void)? = nil
    
    enum Field {
        case username, email, password, confirmPassword, accessCode
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Image - sized perfectly for any iPhone screen, edge-to-edge
                Image("loginBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea(.all)
                    .overlay(
                        // Dark overlay for better text readability
                        Color.black.opacity(0.5)
                            .ignoresSafeArea(.all)
                    )
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Cancel button at the top
                        HStack {
                            Spacer()
                            Button("Cancel") {
                                // Dismiss keyboard when canceling
                                focusedField = nil
                                if let onCancel = onCancel {
                                    onCancel()
                                } else {
                                    dismiss()
                                }
                            }
                            .foregroundColor(.white)
                            .padding()
                        }
                        
                        Spacer(minLength: geometry.size.height * 0.2)
                        
                        // Form fields container
                        VStack(spacing: 16) {
                            // Username field (only for signup)
                            if viewModel.isSignupMode {
                                TextField("Username", text: $viewModel.username)
                                    .focused($focusedField, equals: .username)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .foregroundColor(.black)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .email
                                    }
                            }
                            
                            TextField("Email", text: $viewModel.email)
                                .focused($focusedField, equals: .email)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(8)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .foregroundColor(.black)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .password
                                }
                            
                            SecureField("Password", text: $viewModel.password)
                                .focused($focusedField, equals: .password)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(8)
                                .foregroundColor(.black)
                                .submitLabel(viewModel.isSignupMode ? .next : .go)
                                .onSubmit {
                                    if viewModel.isSignupMode {
                                        focusedField = .confirmPassword
                                    } else {
                                        focusedField = nil
                                        // Trigger login
                                        Task {
                                            await viewModel.login()
                                        }
                                    }
                                }
                            
                            if viewModel.isSignupMode {
                                SecureField("Confirm Password", text: $viewModel.confirmPassword)
                                    .focused($focusedField, equals: .confirmPassword)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .foregroundColor(.black)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        if showJournalistAccessCode {
                                            focusedField = .accessCode
                                        } else {
                                            focusedField = nil
                                        }
                                    }
                                
                                // Journalist access code section
                                VStack(spacing: 8) {
                                    if !showJournalistAccessCode {
                                        Button(action: {
                                            withAnimation {
                                                showJournalistAccessCode = true
                                            }
                                        }) {
                                            HStack {
                                                Text("Have a journalist access code?")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white.opacity(0.8))
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white.opacity(0.8))
                                            }
                                        }
                                    } else {
                                        TextField("Journalist Access Code", text: $journalistAccessCode)
                                            .focused($focusedField, equals: .accessCode)
                                            .padding()
                                            .background(Color.white)
                                            .cornerRadius(8)
                                            .autocapitalization(.none)
                                            .autocorrectionDisabled()
                                            .foregroundColor(.black)
                                            .submitLabel(.go)
                                            .onSubmit {
                                                focusedField = nil
                                                // Trigger signup
                                                Task {
                                                    await viewModel.signup(accessCode: journalistAccessCode)
                                                }
                                            }
                                        
                                        Button(action: {
                                            withAnimation {
                                                showJournalistAccessCode = false
                                                journalistAccessCode = ""
                                            }
                                        }) {
                                            Text("Cancel")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                    }
                                }
                            }
                            
                            Button(viewModel.isSignupMode ? "Sign Up" : "Login") {
                                // Dismiss keyboard before submitting
                                focusedField = nil
                                Task {
                                    if viewModel.isSignupMode {
                                        await viewModel.signup(accessCode: showJournalistAccessCode ? journalistAccessCode : nil)
                                        // Wait a moment for state to update
                                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                                        // After signup, check if authentication succeeded
                                        if authService.isAuthenticated {
                                            // Navigation will happen automatically via LoginView's body
                                            // No need to dismiss - the view will switch to MainTabView
                                        }
                                    } else {
                                        await viewModel.login()
                                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                                        if authService.isAuthenticated {
                                            dismiss()
                                        }
                                    }
                                }
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                            .disabled(viewModel.isLoading)
                            
                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        Spacer(minLength: geometry.size.height * 0.2)
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onTapGesture {
            // Dismiss keyboard when tapping outside text fields
            focusedField = nil
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
}

