//
//  AccountTypeSelectionView.swift
//  c705
//
//  Account type selection after Apple Sign In
//
//  PURPOSE: A screen where a user who has no account type yet chooses Artist,
//  Producer or Engineer, and the choice is saved to the server. It
//  uses the same login background photo as the sign-in screens.
//

import SwiftUI

// Shown when a signed-in user still needs to pick their account type (the
// needsAccountTypeSelection flag).
struct AccountTypeSelectionView: View {
    @EnvironmentObject var authService: AuthService
    // The card the user has tapped. Artist is pre-selected.
    @State private var selectedRole: String = "ARTIST"
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Journalist is invite-only (assigned via admin); only these three are self-selectable
    let roles = [
        ("ARTIST", "Artist", "music.note", "Create music, rap battles, and purchase beats"),
        ("PRODUCER", "Producer", "slider.horizontal.3", "Connect with artists, engineers, and journalists"),
        ("ENGINEER", "Engineer", "wrench.and.screwdriver", "Upload and sell beats")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Image
                Image("loginBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea(.all)
                    .overlay(
                        Color.black.opacity(0.5)
                            .ignoresSafeArea(.all)
                    )
                
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: geometry.size.height * 0.1)
                        
                        // Title
                        VStack(spacing: 8) {
                            Text("Choose Your Account Type")
                                .font(.system(size: min(geometry.size.width * 0.08, 32), weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Select the type of account that best describes you")
                                .font(.system(size: min(geometry.size.width * 0.04, 16)))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.bottom, 20)
                        
                        // Role Selection Cards
                        VStack(spacing: 16) {
                            ForEach(roles, id: \.0) { role in
                                RoleSelectionCard(
                                    role: role.0,
                                    title: role.1,
                                    icon: role.2,
                                    description: role.3,
                                    isSelected: selectedRole == role.0,
                                    onSelect: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedRole = role.0
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, min(geometry.size.width * 0.08, 32))
                        
                        // Continue Button
                        Button(action: {
                            Task {
                                await updateRole()
                            }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Continue")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(selectedRole.isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading || selectedRole.isEmpty)
                        .padding(.horizontal, min(geometry.size.width * 0.08, 32))
                        .padding(.top, 8)
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal, 32)
                        }
                        
                        Spacer(minLength: geometry.size.height * 0.1)
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // Sends the chosen type to the server, which replies with a fresh login token and user.
    // These are saved to the Keychain and to AuthService, and the "needs selection" flag is
    // cleared. Errors become friendly messages.
    private func updateRole() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.updateUserRole(selectedRole)
            
            // Update auth service with new token and user
            let keychain = KeychainService.shared
            let tokenSaved = keychain.save(response.accessToken, forKey: "authToken")
            let userSaved = keychain.save(response.user, forKey: "currentUser")
            
            if tokenSaved && userSaved {
                APIService.shared.setAuthToken(response.accessToken)
                authService.currentUser = response.user
                authService.isAuthenticated = true
                authService.errorMessage = nil
                // Clear the account type selection flag
                UserDefaults.standard.set(false, forKey: "needsAccountTypeSelection")
            } else {
                errorMessage = "Failed to save account type. Please try again."
            }
        } catch let error as APIError {
            switch error {
            case .httpError(let code):
                if code == 400 {
                    errorMessage = "Invalid account type. Please try again."
                } else {
                    errorMessage = "Server error. Please try again."
                }
            case .networkError(let message):
                errorMessage = message
            default:
                errorMessage = "Failed to update account type. Please try again."
            }
        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
        }
        
        isLoading = false
    }
}

// One tappable card for an account type: icon, title, description, and a highlight when
// selected.
struct RoleSelectionCard: View {
    let role: String
    let title: String
    let icon: String
    let description: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .white.opacity(0.7))
                    .frame(width: 50, height: 50)
                    .background(isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.1))
                    .cornerRadius(12)
                
                // Text Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(16)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AccountTypeSelectionView()
        .environmentObject(AuthService())
}
