//
//  c705App.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The front door of the app. When the app launches, iOS starts here:
//  it records analytics, creates the shared sign-in service, and shows
//  the login screen.
//

import SwiftUI

// @main marks this as the starting point of the whole app.
@main
struct c705App: App {
    // Creates one AuthService (who is signed in) for the whole app. @StateObject keeps it alive
    // instead of recreating it whenever the screen redraws.
    @StateObject private var authService = AuthService()
    
    // Runs once at launch, before any screen appears.
    init() {
        // Track app open
        AnalyticsService.shared.trackAppOpen()
        AnalyticsService.shared.trackSessionStart()
        
        // Configure ngrok URL for physical device testing
        // TODO: Replace with your actual ngrok URL when testing on physical device
        // Get your ngrok URL from the ngrok terminal output (the https:// URL)
        // This block is only compiled for a real iPhone, not the Simulator. It is where a
        // temporary test server address (ngrok) can be set.
        #if !targetEnvironment(simulator)
        // Uncomment and set your ngrok URL here:
        // UserDefaults.standard.set("https://your-ngrok-url.ngrok.app", forKey: "customBackendURL")
        
        // Example (replace with your actual ngrok URL):
        // UserDefaults.standard.set("https://abc123-def456.ngrok.app", forKey: "customBackendURL")
        #endif
    }
    
    // Describes what the app shows. WindowGroup is the app's main window.
    var body: some Scene {
        WindowGroup {
            // Always show LoginView first - users must authenticate each time
            // The first screen. Once someone signs in, LoginView moves on to the main tabs.
            LoginView()
                // Shares the AuthService with every screen below, so any screen can check who
                // is signed in.
                .environmentObject(authService)
                .onChange(of: authService.isAuthenticated) { oldValue, newValue in
                    // Navigation to MainTabView will be handled within LoginView
                }
        }
    }
}
