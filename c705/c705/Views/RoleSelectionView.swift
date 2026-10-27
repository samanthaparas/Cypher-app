//
//  RoleSelectionView.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: A sign-up step where the user chooses their account type (Artist,
//  Producer or Engineer) over the login background photo, then taps
//  Continue.
//

import SwiftUI

struct RoleSelectionView: View {
    // These bindings are shared with the parent screen. Changing them here changes them there,
    // which is how the choice is passed along.
    @Binding var selectedRole: String
    @Binding var showLogin: Bool // When true, show login options
    @Binding var isSignupMode: Bool // Track if we're in signup mode
    var onBack: (() -> Void)? = nil // Callback to go back to previous page
    
    // The choices as (server value, label, icon). Journalists are invite-only, so they are not
    // listed.
    let roles = [
        ("ARTIST", "Artist", "music.note"),
        ("PRODUCER", "Producer", "slider.horizontal.3"),
        ("ENGINEER", "Engineer", "wrench.and.screwdriver")
        // JOURNALIST is invite-only and not available in public signup
    ]
    
    var body: some View {
        ZStack {
            // Background Image - sized perfectly for any iPhone screen, edge-to-edge
            // The photo behind the screen, stretched edge to edge with a dark layer on top so
            // the white text stays readable.
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
                
            // Reads the screen size so text and spacing scale to fit different iPhones. The
            // min(...) calls cap how big things can get.
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Back button at the top
                    HStack {
                        Button(action: {
                            if let onBack = onBack {
                                withAnimation(AppAnimations.smoothSpring) {
                                    onBack()
                                }
                            } else {
                                withAnimation(AppAnimations.smoothSpring) {
                                    showLogin = true
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        Spacer()
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    
                    Spacer()
                
                    // C705 Title - Responsive sizing
                    Text("C705")
                        .font(.system(size: min(geometry.size.width * 0.12, 48), weight: .bold))
                        .foregroundColor(.white)
                        .padding(.bottom, min(geometry.size.height * 0.05, 40))
                    
                    // Role Selection
                    Text("Choose Your Account Type")
                        .font(.system(size: min(geometry.size.width * 0.05, 20), weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.bottom, min(geometry.size.height * 0.03, 30))
                    
                    VStack(spacing: min(geometry.size.height * 0.02, 16)) {
                        // Draws one tappable row for each account type. The selected one gets a
                        // checkmark and a blue outline.
                        ForEach(roles, id: \.0) { role in
                            Button(action: {
                                selectedRole = role.0
                            }) {
                                HStack {
                                    Image(systemName: role.2)
                                        .font(.system(size: min(geometry.size.width * 0.05, 20)))
                                        .foregroundColor(selectedRole == role.0 ? .white : .white.opacity(0.7))
                                        .frame(width: min(geometry.size.width * 0.08, 30))
                                    
                                    Text(role.1)
                                        .font(.system(size: min(geometry.size.width * 0.045, 18), weight: .medium))
                                        .foregroundColor(selectedRole == role.0 ? .white : .white.opacity(0.7))
                                    
                                    Spacer()
                                    
                                    if selectedRole == role.0 {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, min(geometry.size.width * 0.08, 20))
                                .padding(.vertical, min(geometry.size.height * 0.02, 16))
                                .background(selectedRole == role.0 ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedRole == role.0 ? Color.blue : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, min(geometry.size.width * 0.08, 32))
                    .padding(.bottom, min(geometry.size.height * 0.05, 40))
                    
                    // Continue Button - Responsive sizing
                    Button(action: {
                        withAnimation(AppAnimations.quickSpring) {
                            showLogin = true
                        }
                    }) {
                        HStack {
                            Text("Continue")
                                .font(.system(size: min(geometry.size.width * 0.045, 18), weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: min(geometry.size.width * 0.04, 16), weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: min(geometry.size.height * 0.06, 50))
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, min(geometry.size.width * 0.08, 32))
                    .padding(.bottom, min(geometry.size.height * 0.05, 40))
                    .scaleEffect(selectedRole.isEmpty ? 0.95 : 1.0)
                    .animation(AppAnimations.fastSpring, value: selectedRole)
                    
                    Spacer()
                }
            }
        }
        // Hides the system navigation bar. This screen provides its own Back button.
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    RoleSelectionView(selectedRole: .constant("ARTIST"), showLogin: .constant(false), isSignupMode: .constant(false))
}

