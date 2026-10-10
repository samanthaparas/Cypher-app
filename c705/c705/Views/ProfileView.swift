//
//  ProfileView.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//

import SwiftUI
import SafariServices


struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: String
    @State private var showEditBio = false
    @State private var showEditUsername = false
    @State private var editUsernameText = ""
    @State private var usernameErrorMessage: String?
    @State private var isUpdatingUsername = false
    @State private var showSettings = false
    @State private var bioText = ""
    @State private var searchText = ""
    @State private var purchasedBeats: [ProfileBeat] = []
    @State private var importedBeats: [ProfileBeat] = []
    @State private var showImportSheet = false
    @State private var isLoadingBeats = false
    @State private var cypherInvites: [CypherInvite] = []
    @State private var isLoadingCyphers = false
    @State private var showCypherPage = false
    
    // Hidden when the profile is a root tab, where dismiss() has nothing to close
    let showsBackButton: Bool

    // Initialize selectedTab based on user role
    init(showsBackButton: Bool = true) {
        self.showsBackButton = showsBackButton
        // We'll set this in onAppear since we need access to authService
        _selectedTab = State(initialValue: "Articles")
    }
    
    // Computed property for tabs based on role
    // All account types except ADMIN get: Articles, Beats, Cyphers
    var tabs: [String] {
        // Exclude ADMIN accounts
        if authService.currentUser?.role == "ADMIN" {
            return []
        }
        // All other account types get the same tabs
        return ["Articles", "Beats", "Cyphers"]
    }
    
    // Computed property for display name
    var displayName: String {
        if let username = authService.currentUser?.username, !username.isEmpty {
            return username
        } else if let email = authService.currentUser?.email {
            return email.components(separatedBy: "@").first?.capitalized ?? "User"
        }
        return "User"
    }
    
    // Computed property for account type display
    var accountTypeTitle: String {
        guard let role = authService.currentUser?.role else {
            return ""
        }
        // Format role for display (e.g., "ARTIST" -> "Artist", "JOURNALIST" -> "Journalist")
        return role.capitalized
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Header
                    VStack(spacing: 16) {
                        // Profile Picture
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    // Profile image placeholder
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                )
                            
                            // Camera icon
                            Button(action: {
                                // TODO: Add photo picker
                            }) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                            }
                            .offset(x: 5, y: 5)
                        }
                        .padding(.top, 20)
                        
                        // User Name - tappable to change username (all account types)
                        HStack(spacing: 8) {
                            Text(displayName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.black)
                            Button(action: { editUsernameText = authService.currentUser?.username ?? ""; usernameErrorMessage = nil; showEditUsername = true }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Account Type - Show role under username
                        if !accountTypeTitle.isEmpty {
                            Text(accountTypeTitle)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.top, -4)
                        }
                        
                        // Bio
                        Button(action: {
                            showEditBio = true
                        }) {
                            if bioText.isEmpty {
                                Text("No bio yet. Tap to add one.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            } else {
                                Text(bioText)
                                    .font(.system(size: 14))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 24)
                    
                    // Tabs - Dynamic based on user role
                    VStack(spacing: 0) {
                        // Main Tabs
                        HStack(spacing: 0) {
                            ForEach(tabs, id: \.self) { tab in
                                TabButton(title: tab, isSelected: selectedTab == tab) {
                                    selectedTab = tab
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    
                    // Content based on selected tab
                    if selectedTab == "Beats" {
                        // All account types can see beats
                        BeatsSectionView(
                            searchText: $searchText,
                            purchasedBeats: $purchasedBeats,
                            importedBeats: $importedBeats,
                            showImportSheet: $showImportSheet,
                            isLoadingBeats: $isLoadingBeats
                        )
                    } else if selectedTab == "Cyphers" {
                        // All account types except ADMIN can see cyphers
                        if authService.currentUser?.role != "ADMIN" {
                            CyphersSectionView(
                                invites: $cypherInvites,
                                isLoading: $isLoadingCyphers,
                                showCypherPage: $showCypherPage
                            )
                        } else {
                            VStack {
                                Text("Cyphers content not available")
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    } else if selectedTab == "Articles" {
                        // Articles content for all account types except ADMIN
                        if authService.currentUser?.role != "ADMIN" {
                            // Show articles view or placeholder
                            VStack {
                                Text("Articles content coming soon")
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            VStack {
                                Text("Articles content not available")
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    } else {
                        // Placeholder for other tabs
                        VStack {
                            Text("\(selectedTab) content coming soon")
                                .foregroundColor(.gray)
                                .padding()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }
            .navigationTitle(displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsBackButton {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.black)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.black)
                    }
                }
            }
            .sheet(isPresented: $showEditBio) {
                EditBioView(bioText: $bioText)
            }
            .sheet(isPresented: $showEditUsername) {
                EditUsernameSheet(
                    username: $editUsernameText,
                    errorMessage: $usernameErrorMessage,
                    isUpdating: $isUpdatingUsername,
                    onSave: saveUsername,
                    onDismiss: { showEditUsername = false }
                )
                .environmentObject(authService)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(authService: authService, showEditBio: $showEditBio)
            }
            .sheet(isPresented: $showImportSheet) {
                ImportBeatView(importedBeats: $importedBeats)
            }
            .onAppear {
                // Set initial tab - default to Articles for all account types except ADMIN
                if authService.currentUser?.role == "ADMIN" {
                    selectedTab = "Beats" // Fallback for ADMIN
                } else {
                    selectedTab = "Articles"
                }
                // Load beats when Beats tab is selected (all account types)
                if selectedTab == "Beats" {
                    loadBeats()
                } else if selectedTab == "Cyphers" && authService.currentUser?.role != "ADMIN" {
                    loadCypherInvites()
                }
            }
            .onChange(of: selectedTab) { oldValue, newTab in
                if newTab == "Beats" {
                    // All account types can load beats
                    loadBeats()
                } else if newTab == "Cyphers" && authService.currentUser?.role != "ADMIN" {
                    loadCypherInvites()
                }
            }
            .fullScreenCover(isPresented: $showCypherPage) {
                FreestyleArenaView()
            }
        }
    }

    private func saveUsername() async {
        let trimmed = editUsernameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            await MainActor.run { usernameErrorMessage = "Username must be at least 2 characters" }
            return
        }
        await MainActor.run { isUpdatingUsername = true; usernameErrorMessage = nil }
        do {
            let response = try await APIService.shared.updateUsername(trimmed)
            let keychain = KeychainService.shared
            _ = keychain.save(response.accessToken, forKey: "authToken")
            _ = keychain.save(response.user, forKey: "currentUser")
            await MainActor.run {
                APIService.shared.setAuthToken(response.accessToken)
                authService.currentUser = response.user
                showEditUsername = false
            }
        } catch let error as APIError {
            await MainActor.run {
                switch error {
                case .httpErrorWithMessage(_, let message): usernameErrorMessage = message
                case .httpError(400): usernameErrorMessage = "Invalid username."
                case .httpError(409): usernameErrorMessage = "Username is already taken."
                default: usernameErrorMessage = "Could not update username. Try again."
                }
            }
        } catch {
            await MainActor.run { usernameErrorMessage = "Could not update username. Try again." }
        }
        await MainActor.run { isUpdatingUsername = false }
    }
    
    func loadBeats() {
        isLoadingBeats = true
        
        Task {
            do {
                // Load purchased beats from API
                let response = try await APIService.shared.getPurchasedBeats()
                await MainActor.run {
                    purchasedBeats = response.beats.map { apiBeat in
                        ProfileBeat(from: apiBeat, isPurchased: true)
                    }
                }
                
                // Load imported beats from UserDefaults (local storage)
                if let importedData = UserDefaults.standard.data(forKey: "importedBeats"),
                   let decoded = try? JSONDecoder().decode([ProfileBeat].self, from: importedData) {
                    await MainActor.run {
                        importedBeats = decoded
                    }
                }
            } catch {
                print("Error loading beats: \(error)")
            }
            
            await MainActor.run {
                isLoadingBeats = false
            }
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString) ?? formatter.date(from: dateString.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression))
    }
    
    func loadCypherInvites() {
        isLoadingCyphers = true
        
        Task {
            do {
                let invites = try await APIService.shared.getUserCypherInvites()
                await MainActor.run {
                    cypherInvites = invites
                    isLoadingCyphers = false
                }
            } catch {
                print("Error loading cypher invites: \(error)")
                await MainActor.run {
                    isLoadingCyphers = false
                }
            }
        }
    }
}

// MARK: - Cypher Invite Model (moved to Cypher.swift)
// Using CypherInvite from Models/Cypher.swift

// MARK: - Cyphers Section View
struct CyphersSectionView: View {
    @Binding var invites: [CypherInvite]
    @Binding var isLoading: Bool
    @Binding var showCypherPage: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("Loading cypher invites...")
                    .padding()
            } else if invites.isEmpty {
                // Empty State
                VStack(spacing: 12) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No cypher invites yet")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    Text("You'll see invites here when other artists challenge you")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(invites) { invite in
                            CypherInviteRowView(invite: invite) {
                                showCypherPage = true
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Cypher Invite Row View
struct CypherInviteRowView: View {
    let invite: CypherInvite
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Invite Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 50, height: 50)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                
                // Invite Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(invite.cypher.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    HStack(spacing: 4) {
                        Text("From:")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text(invite.invitedBy.username ?? invite.invitedBy.email)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text("\(invite.cypher.entryCount) entries")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Status Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(invite.status.capitalized)
                        .font(.system(size: 12))
                        .foregroundColor(statusColor)
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    var statusColor: Color {
        switch invite.status.lowercased() {
        case "pending":
            return .orange
        case "accepted":
            return .green
        case "declined":
            return .red
        default:
            return .gray
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .black : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .overlay(
                    Rectangle()
                        .fill(isSelected ? Color.blue : Color.clear)
                        .frame(height: 2)
                        .offset(y: 20),
                    alignment: .bottom
                )
        }
    }
}

// Beat model for purchased/imported beats in ProfileView
struct ProfileBeat: Identifiable, Codable {
    let id: String
    let title: String
    let audioUrl: String?
    let localFilePath: String?
    let isPurchased: Bool
    let isImported: Bool
    let purchaseDate: Date?
    let importDate: Date?
    
    init(id: String = UUID().uuidString, title: String, audioUrl: String? = nil, localFilePath: String? = nil, isPurchased: Bool = false, isImported: Bool = false, purchaseDate: Date? = nil, importDate: Date? = nil) {
        self.id = id
        self.title = title
        self.audioUrl = audioUrl
        self.localFilePath = localFilePath
        self.isPurchased = isPurchased
        self.isImported = isImported
        self.purchaseDate = purchaseDate
        self.importDate = importDate
    }
    
    // Convert from API Beat model
    init(from apiBeat: Beat, isPurchased: Bool = true) {
        self.id = apiBeat.id
        self.title = apiBeat.title
        self.audioUrl = apiBeat.fullUrl
        self.localFilePath = nil
        self.isPurchased = isPurchased
        self.isImported = false
        self.purchaseDate = nil // Parse from createdAt if needed
        self.importDate = nil
    }
}

struct BeatsSectionView: View {
    @Binding var searchText: String
    @Binding var purchasedBeats: [ProfileBeat]
    @Binding var importedBeats: [ProfileBeat]
    @Binding var showImportSheet: Bool
    @Binding var isLoadingBeats: Bool
    
    var filteredPurchasedBeats: [ProfileBeat] {
        if searchText.isEmpty {
            return purchasedBeats
        }
        return purchasedBeats.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredImportedBeats: [ProfileBeat] {
        if searchText.isEmpty {
            return importedBeats
        }
        return importedBeats.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Import Beat Button
            Button(action: {
                showImportSheet = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16))
                    Text("Import Beat")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search beats...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            
            if isLoadingBeats {
                ProgressView("Loading beats...")
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Purchased Beats Section
                        if !filteredPurchasedBeats.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Purchased Beats")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal)
                                
                                ForEach(filteredPurchasedBeats) { beat in
                                    BeatRowView(beat: beat)
                                }
                            }
                        }
                        
                        // Imported Beats Section
                        if !filteredImportedBeats.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Imported Beats")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal)
                                
                                ForEach(filteredImportedBeats) { beat in
                                    BeatRowView(beat: beat)
                                }
                            }
                        }
                        
                        // Empty State
                        if filteredPurchasedBeats.isEmpty && filteredImportedBeats.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text(searchText.isEmpty ? "No beats yet" : "No beats found")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                if searchText.isEmpty {
                                    Text("Import or purchase beats to get started")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray.opacity(0.7))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

struct BeatRowView: View {
    let beat: ProfileBeat
    
    var body: some View {
        HStack(spacing: 12) {
            // Beat Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: "music.note")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            
            // Beat Info
            VStack(alignment: .leading, spacing: 4) {
                Text(beat.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                
                HStack(spacing: 8) {
                    if beat.isPurchased {
                        Label("Purchased", systemImage: "cart.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                    if beat.isImported {
                        Label("Imported", systemImage: "square.and.arrow.down.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Play Button
            Button(action: {
                // TODO: Play beat
            }) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct ImportBeatView: View {
    @Binding var importedBeats: [ProfileBeat]
    @Environment(\.dismiss) var dismiss
    @State private var documentPickerPresented = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Import a beat from your device")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button(action: {
                    // TODO: Implement document picker for audio files
                    // For now, add a sample imported beat
                    let newBeat = ProfileBeat(
                        title: "Imported Beat \(importedBeats.count + 1)",
                        isImported: true,
                        importDate: Date()
                    )
                    importedBeats.append(newBeat)
                    
                    // Save to UserDefaults
                    if let encoded = try? JSONEncoder().encode(importedBeats) {
                        UserDefaults.standard.set(encoded, forKey: "importedBeats")
                    }
                    
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "folder")
                            .font(.system(size: 18))
                        Text("Choose File")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Text("Note: Full file picker integration coming soon")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Import Beat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EditUsernameSheet: View {
    @Binding var username: String
    @Binding var errorMessage: String?
    @Binding var isUpdating: Bool
    var onSave: () async -> Void
    var onDismiss: () -> Void
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(.horizontal)
                if let msg = errorMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Change Username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                    .disabled(isUpdating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await onSave()
                            await MainActor.run { if errorMessage == nil { dismiss() } }
                        }
                    }
                    .disabled(isUpdating || username.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                }
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var authService: AuthService
    @Binding var showEditBio: Bool
    @Environment(\.dismiss) var dismiss
    @State private var settings = UserSettings()
    @State private var showDeleteAccount = false
    @State private var showChangeEmail = false
    @State private var showChangePassword = false
    @State private var showTwoFactor = false
    @State private var showBlockedUsers = false
    @State private var legalURL: URL?
    
    var userRole: String {
        authService.currentUser?.role ?? ""
    }
    
    // Initialize optional settings based on role (called once in onAppear)
    private func initializeSettingsForRole() {
        if userRole == "ARTIST" && settings.artist == nil {
            settings.artist = ArtistSettings()
        }
        if userRole == "PRODUCER" && settings.producer == nil {
            settings.producer = ProducerSettings()
        }
        if userRole == "ENGINEER" && settings.engineer == nil {
            settings.engineer = EngineerSettings()
        }
        if userRole == "JOURNALIST" && settings.journalist == nil {
            settings.journalist = JournalistSettings()
        }
        if (userRole == "ARTIST" || userRole == "PRODUCER") && settings.freestyleArena == nil {
            settings.freestyleArena = FreestyleArenaSettings()
        }
    }
    
    // Helper to create binding for artist location
    private var artistLocationBinding: Binding<String> {
        Binding(
            get: {
                return settings.artist?.location ?? ""
            },
            set: { newValue in
                if settings.artist == nil {
                    settings.artist = ArtistSettings()
                }
                settings.artist?.location = newValue
            }
        )
    }
    
    // Helper to create binding for artist allowDuets
    private var artistAllowDuetsBinding: Binding<Bool> {
        Binding(
            get: {
                return settings.artist?.allowDuets ?? true
            },
            set: { newValue in
                if settings.artist == nil {
                    settings.artist = ArtistSettings()
                }
                settings.artist?.allowDuets = newValue
            }
        )
    }
    
    // Helper to create binding for artist allowFreestyleChallenges
    private var artistAllowFreestyleChallengesBinding: Binding<Bool> {
        Binding(
            get: {
                return settings.artist?.allowFreestyleChallenges ?? true
            },
            set: { newValue in
                if settings.artist == nil {
                    settings.artist = ArtistSettings()
                }
                settings.artist?.allowFreestyleChallenges = newValue
            }
        )
    }
    
    // Helper to create binding for artist pinnedTrackId
    private var artistPinnedTrackIdBinding: Binding<String> {
        Binding(
            get: {
                return settings.artist?.pinnedTrackId ?? ""
            },
            set: { newValue in
                if settings.artist == nil {
                    settings.artist = ArtistSettings()
                }
                settings.artist?.pinnedTrackId = newValue
            }
        )
    }
    
    // Helper to create binding for artist hideOldTracks
    private var artistHideOldTracksBinding: Binding<Bool> {
        Binding(
            get: {
                return settings.artist?.hideOldTracks ?? false
            },
            set: { newValue in
                if settings.artist == nil {
                    settings.artist = ArtistSettings()
                }
                settings.artist?.hideOldTracks = newValue
            }
        )
    }
    
    // MARK: - Producer Helper Bindings
    private var producerNameBinding: Binding<String> {
        Binding(
            get: {
                return settings.producer?.producerName ?? ""
            },
            set: { newValue in
                if settings.producer == nil {
                    settings.producer = ProducerSettings()
                }
                settings.producer?.producerName = newValue
            }
        )
    }
    
    private var producerTagsBinding: Binding<[String]> {
        Binding(
            get: {
                return settings.producer?.tags ?? []
            },
            set: { newValue in
                if settings.producer == nil {
                    settings.producer = ProducerSettings()
                }
                settings.producer?.tags = newValue
            }
        )
    }
    
    private var producerPriceBinding: Binding<Double> {
        Binding(
            get: {
                return settings.producer?.defaultBeatPrice ?? 0
            },
            set: { newValue in
                if settings.producer == nil {
                    settings.producer = ProducerSettings()
                }
                settings.producer?.defaultBeatPrice = newValue
            }
        )
    }
    
    private var producerOfferLeaseBinding: Binding<Bool> {
        Binding(
            get: {
                return settings.producer?.offerLease ?? true
            },
            set: { newValue in
                if settings.producer == nil {
                    settings.producer = ProducerSettings()
                }
                settings.producer?.offerLease = newValue
            }
        )
    }
    
    private var producerOfferExclusiveBinding: Binding<Bool> {
        Binding(
            get: {
                return settings.producer?.offerExclusive ?? true
            },
            set: { newValue in
                if settings.producer == nil {
                    settings.producer = ProducerSettings()
                }
                settings.producer?.offerExclusive = newValue
            }
        )
    }
    
    private var producerAutoDeliveryBinding: Binding<Bool> {
        Binding(
            get: {
                return settings.producer?.autoDelivery ?? true
            },
            set: { newValue in
                if settings.producer == nil {
                    settings.producer = ProducerSettings()
                }
                settings.producer?.autoDelivery = newValue
            }
        )
    }
    
    private var producerShowInSearchBinding: Binding<Bool> {
        Binding(
            get: {
                return settings.producer?.showInSearch ?? true
            },
            set: { newValue in
                if settings.producer == nil {
                    settings.producer = ProducerSettings()
                }
                settings.producer?.showInSearch = newValue
            }
        )
    }
    
    private var producerAllowPreviewsBinding: Binding<Bool> {
        Binding(
            get: {
                return settings.producer?.allowPreviews ?? true
            },
            set: { newValue in
                if settings.producer == nil {
                    settings.producer = ProducerSettings()
                }
                settings.producer?.allowPreviews = newValue
            }
        )
    }
    
    private var producerAllowFreeDownloadsBinding: Binding<Bool> {
        Binding(
            get: {
                return settings.producer?.allowFreeDownloads ?? false
            },
            set: { newValue in
                if settings.producer == nil {
                    settings.producer = ProducerSettings()
                }
                settings.producer?.allowFreeDownloads = newValue
            }
        )
    }
    
    // MARK: - Engineer Helper Bindings
    private var engineerStudioNameBinding: Binding<String> {
        Binding(
            get: {
                return settings.engineer?.studioName ?? ""
            },
            set: { newValue in
                if settings.engineer == nil {
                    settings.engineer = EngineerSettings()
                }
                settings.engineer?.studioName = newValue
            }
        )
    }
    
    private var engineerLocationBinding: Binding<String> {
        Binding(
            get: {
                return settings.engineer?.location ?? ""
            },
            set: { newValue in
                if settings.engineer == nil {
                    settings.engineer = EngineerSettings()
                }
                settings.engineer?.location = newValue
            }
        )
    }
    
    private var engineerSessionLengthsBinding: Binding<[Int]> {
        Binding(
            get: {
                return settings.engineer?.sessionLengths ?? []
            },
            set: { newValue in
                if settings.engineer == nil {
                    settings.engineer = EngineerSettings()
                }
                settings.engineer?.sessionLengths = newValue
            }
        )
    }
    
    private var engineerEnableReviewsBinding: Binding<Bool> {
        Binding(
            get: {
                return settings.engineer?.enableReviews ?? true
            },
            set: { newValue in
                if settings.engineer == nil {
                    settings.engineer = EngineerSettings()
                }
                settings.engineer?.enableReviews = newValue
            }
        )
    }
    
    // MARK: - Freestyle Arena Helper Bindings
    private var freestyleCountdownBinding: Binding<Bool> {
        Binding(
            get: {
                return settings.freestyleArena?.countdownTimer ?? true
            },
            set: { newValue in
                if settings.freestyleArena == nil {
                    settings.freestyleArena = FreestyleArenaSettings()
                }
                settings.freestyleArena?.countdownTimer = newValue
            }
        )
    }
    
    private var freestyleAutoTrimBinding: Binding<Bool> {
        Binding(
            get: {
                return settings.freestyleArena?.autoTrimSilence ?? true
            },
            set: { newValue in
                if settings.freestyleArena == nil {
                    settings.freestyleArena = FreestyleArenaSettings()
                }
                settings.freestyleArena?.autoTrimSilence = newValue
            }
        )
    }
    
    private var freestyleSaveDraftsBinding: Binding<Bool> {
        Binding(
            get: {
                return settings.freestyleArena?.saveDrafts ?? true
            },
            set: { newValue in
                if settings.freestyleArena == nil {
                    settings.freestyleArena = FreestyleArenaSettings()
                }
                settings.freestyleArena?.saveDrafts = newValue
            }
        )
    }
    
    private var freestyleBattleInvitesBinding: Binding<Bool> {
        Binding(
            get: {
                return settings.freestyleArena?.allowBattleInvites ?? true
            },
            set: { newValue in
                if settings.freestyleArena == nil {
                    settings.freestyleArena = FreestyleArenaSettings()
                }
                settings.freestyleArena?.allowBattleInvites = newValue
            }
        )
    }
    
    private var freestyleShowRankingBinding: Binding<Bool> {
        Binding(
            get: {
                return settings.freestyleArena?.showRanking ?? true
            },
            set: { newValue in
                if settings.freestyleArena == nil {
                    settings.freestyleArena = FreestyleArenaSettings()
                }
                settings.freestyleArena?.showRanking = newValue
            }
        )
    }
    
    private var freestyleNotifyLeaderboardBinding: Binding<Bool> {
        Binding(
            get: {
                return settings.freestyleArena?.notifyLeaderboardUpdates ?? true
            },
            set: { newValue in
                if settings.freestyleArena == nil {
                    settings.freestyleArena = FreestyleArenaSettings()
                }
                settings.freestyleArena?.notifyLeaderboardUpdates = newValue
            }
        )
    }
    
    // MARK: - Journalist Helper Bindings
    private var journalistCitiesBinding: Binding<[String]> {
        Binding(
            get: {
                return settings.journalist?.citiesCovered ?? []
            },
            set: { newValue in
                if settings.journalist == nil {
                    settings.journalist = JournalistSettings()
                }
                settings.journalist?.citiesCovered = newValue
            }
        )
    }
    
    private var journalistGenresBinding: Binding<[String]> {
        Binding(
            get: {
                return settings.journalist?.genresCovered ?? []
            },
            set: { newValue in
                if settings.journalist == nil {
                    settings.journalist = JournalistSettings()
                }
                settings.journalist?.genresCovered = newValue
            }
        )
    }
    
    // MARK: - Artist Settings Sections (extracted to reduce complexity)
    @ViewBuilder
    private var artistSettingsSections: some View {
        Section(header: Text("Artist Profile")) {
            NavigationLink(destination: ArtistProfileSettingsView(settings: $settings.artist)) {
                SettingsRow(icon: "person.circle", title: "Display name", color: .black)
            }
            
            Button(action: {
                dismiss()
                showEditBio = true
            }) {
                SettingsRow(icon: "pencil", title: "Bio", color: .black)
            }
            
            NavigationLink(destination: LocationSettingsView(location: artistLocationBinding)) {
                SettingsRow(icon: "location", title: "Location", color: .black)
            }
            
            NavigationLink(destination: SocialLinksView(settings: $settings.artist)) {
                SettingsRow(icon: "link", title: "Social links", color: .black)
            }
        }
        
        Section(header: Text("Fan Interaction")) {
            Toggle(isOn: artistAllowDuetsBinding) {
                SettingsRow(icon: "person.2", title: "Allow duets / collaborations", color: .black)
            }
            
            Toggle(isOn: artistAllowFreestyleChallengesBinding) {
                SettingsRow(icon: "mic.fill", title: "Allow freestyle challenges", color: .black)
            }
            
            NavigationLink(destination: PinTrackView(trackId: artistPinnedTrackIdBinding)) {
                SettingsRow(icon: "pin.fill", title: "Pin a track to profile", color: .black)
            }
        }
        
        Section(header: Text("Promotion Controls")) {
            Toggle(isOn: artistHideOldTracksBinding) {
                SettingsRow(icon: "eye.slash", title: "Hide old tracks", color: .black)
            }
        }
    }
    
    // MARK: - Producer Settings Sections
    @ViewBuilder
    private var producerSettingsSections: some View {
        Section(header: Text("Producer Profile")) {
            NavigationLink(destination: ProducerNameView(name: producerNameBinding)) {
                SettingsRow(icon: "person.circle", title: "Producer name", color: .black)
            }
            
            NavigationLink(destination: TagsView(tags: producerTagsBinding)) {
                SettingsRow(icon: "tag", title: "Tags (genre, BPM style)", color: .black)
            }
        }
        
        Section(header: Text("Beat Sales Settings")) {
            NavigationLink(destination: BeatPriceView(price: producerPriceBinding)) {
                SettingsRow(icon: "dollarsign.circle", title: "Default beat price", color: .black)
            }
            
            Toggle(isOn: producerOfferLeaseBinding) {
                SettingsRow(icon: "doc.text", title: "Offer lease license", color: .black)
            }
            
            Toggle(isOn: producerOfferExclusiveBinding) {
                SettingsRow(icon: "star.fill", title: "Offer exclusive license", color: .black)
            }
            
            Toggle(isOn: producerAutoDeliveryBinding) {
                SettingsRow(icon: "paperplane.fill", title: "Auto-delivery after purchase", color: .black)
            }
        }
        
        Section(header: Text("Marketplace Visibility")) {
            Toggle(isOn: producerShowInSearchBinding) {
                SettingsRow(icon: "magnifyingglass", title: "Show beats in search", color: .black)
            }
            
            Toggle(isOn: producerAllowPreviewsBinding) {
                SettingsRow(icon: "play.circle", title: "Allow previews", color: .black)
            }
            
            Toggle(isOn: producerAllowFreeDownloadsBinding) {
                SettingsRow(icon: "arrow.down.circle", title: "Allow free downloads", color: .black)
            }
        }
    }
    
    // MARK: - Engineer Settings Sections
    @ViewBuilder
    private var engineerSettingsSections: some View {
        Section(header: Text("Engineer Profile")) {
            NavigationLink(destination: StudioNameView(name: engineerStudioNameBinding)) {
                SettingsRow(icon: "building.2", title: "Studio name", color: .black)
            }
            
            NavigationLink(destination: LocationSettingsView(location: engineerLocationBinding)) {
                SettingsRow(icon: "location", title: "Location", color: .black)
            }
        }
        
        Section(header: Text("Booking Settings")) {
            NavigationLink(destination: BookingSettingsView(settings: $settings.engineer)) {
                SettingsRow(icon: "calendar", title: "Available days/times", color: .black)
            }
            
            NavigationLink(destination: SessionLengthView(lengths: engineerSessionLengthsBinding)) {
                SettingsRow(icon: "clock", title: "Session length options", color: .black)
            }
        }
        
        Section(header: Text("Reviews")) {
            Toggle(isOn: engineerEnableReviewsBinding) {
                SettingsRow(icon: "star.fill", title: "Enable reviews", color: .black)
            }
        }
    }
    
    // MARK: - Freestyle Arena Settings Section
    @ViewBuilder
    private var freestyleArenaSettingsSection: some View {
        Section(header: Text("Freestyle Arena")) {
            Toggle(isOn: freestyleCountdownBinding) {
                SettingsRow(icon: "timer", title: "Countdown timer", color: .black)
            }
            
            Toggle(isOn: freestyleAutoTrimBinding) {
                SettingsRow(icon: "scissors", title: "Auto-trim silence", color: .black)
            }
            
            Toggle(isOn: freestyleSaveDraftsBinding) {
                SettingsRow(icon: "doc", title: "Save drafts", color: .black)
            }
            
            Toggle(isOn: freestyleBattleInvitesBinding) {
                SettingsRow(icon: "gamecontroller", title: "Allow battle invites", color: .black)
            }
            
            Toggle(isOn: freestyleShowRankingBinding) {
                SettingsRow(icon: "trophy.fill", title: "Show ranking publicly", color: .black)
            }
            
            Toggle(isOn: freestyleNotifyLeaderboardBinding) {
                SettingsRow(icon: "bell.badge", title: "Notify when leaderboard updates", color: .black)
            }
        }
    }
    
    // MARK: - Journalist Settings Section
    @ViewBuilder
    private var journalistSettingsSection: some View {
        Section(header: Text("Coverage Preferences")) {
            NavigationLink(destination: CitiesView(cities: journalistCitiesBinding)) {
                SettingsRow(icon: "map", title: "Cities covered", color: .black)
            }
            
            NavigationLink(destination: GenresView(genres: journalistGenresBinding)) {
                SettingsRow(icon: "music.note.list", title: "Genres covered", color: .black)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Account Section (All Users)
                Section(header: Text("Account")) {
                    Button(action: {
                        showChangeEmail = true
                    }) {
                        SettingsRow(icon: "envelope", title: "Change Email", color: .black)
                    }
                    
                    Button(action: {
                        showChangePassword = true
                    }) {
                        SettingsRow(icon: "lock", title: "Change Password", color: .black)
                    }
                    
                    Toggle(isOn: Binding(
                        get: { false }, // TODO: Load from settings
                        set: { _ in showTwoFactor = true }
                    )) {
                        SettingsRow(icon: "shield.checkered", title: "Two-Factor Authentication", color: .black)
                    }
                    
                    Button(action: {
                        authService.logout()
                        dismiss()
                    }) {
                        SettingsRow(icon: "arrow.right.square", title: "Sign Out", color: .red)
                    }
                    
                    Button(action: {
                        showDeleteAccount = true
                    }) {
                        SettingsRow(icon: "trash", title: "Delete Account", color: .red)
                    }
                }
                
                // MARK: - Privacy & Safety (All Users)
                Section(header: Text("Privacy & Safety")) {
                    Toggle(isOn: $settings.privacy.privateProfile) {
                        SettingsRow(icon: "lock.fill", title: "Private Profile", color: .black)
                    }
                    
                    NavigationLink(destination: CommentPermissionView(permission: $settings.privacy.whoCanComment)) {
                        SettingsRow(icon: "bubble.left", title: "Who Can Comment", color: .black, value: settings.privacy.whoCanComment.rawValue.capitalized)
                    }
                    
                    NavigationLink(destination: MessagePermissionView(permission: $settings.privacy.whoCanMessage)) {
                        SettingsRow(icon: "message", title: "Who Can Message Me", color: .black, value: settings.privacy.whoCanMessage.rawValue.capitalized)
                    }
                    
                    Button(action: {
                        showBlockedUsers = true
                    }) {
                        SettingsRow(icon: "person.crop.circle.badge.xmark", title: "Blocked Users", color: .black)
                    }
                    
                    Button(action: {
                        // TODO: Report user functionality
                    }) {
                        SettingsRow(icon: "exclamationmark.triangle", title: "Report a User", color: .black)
                    }
                }
                
                // MARK: - Notifications (All Users)
                Section(header: Text("Notifications")) {
                    Toggle(isOn: $settings.notifications.likes) {
                        SettingsRow(icon: "heart", title: "Likes on my posts", color: .black)
                    }
                    
                    Toggle(isOn: $settings.notifications.comments) {
                        SettingsRow(icon: "bubble.left", title: "Comments on my content", color: .black)
                    }
                    
                    Toggle(isOn: $settings.notifications.followers) {
                        SettingsRow(icon: "person.badge.plus", title: "New followers", color: .black)
                    }
                    
                    Toggle(isOn: $settings.notifications.mentions) {
                        SettingsRow(icon: "at", title: "Mentions", color: .black)
                    }
                    
                    Toggle(isOn: $settings.notifications.events) {
                        SettingsRow(icon: "calendar", title: "Event announcements", color: .black)
                    }
                }
                
                // MARK: - Playback & Media (All Users)
                Section(header: Text("Playback & Media")) {
                    Toggle(isOn: $settings.playback.autoplayNext) {
                        SettingsRow(icon: "play.circle", title: "Autoplay next track", color: .black)
                    }
                    
                    Toggle(isOn: $settings.playback.streamOverCellular) {
                        SettingsRow(icon: "antenna.radiowaves.left.and.right", title: "Stream over cellular", color: .black)
                    }
                    
                    NavigationLink(destination: AudioQualityView(quality: $settings.playback.audioQuality)) {
                        SettingsRow(icon: "waveform", title: "Audio quality", color: .black, value: settings.playback.audioQuality.rawValue.capitalized)
                    }
                    
                    Toggle(isOn: $settings.playback.downloadOverWiFiOnly) {
                        SettingsRow(icon: "wifi", title: "Download over Wi-Fi only", color: .black)
                    }
                }
                
                // MARK: - Artist Settings
                if userRole == "ARTIST" {
                    artistSettingsSections
                }
                
                // MARK: - Producer Settings
                if userRole == "PRODUCER" {
                    producerSettingsSections
                }
                
                // MARK: - Engineer Settings
                if userRole == "ENGINEER" {
                    engineerSettingsSections
                }
                
                // MARK: - Freestyle Arena Settings
                if userRole == "ARTIST" || userRole == "PRODUCER" {
                    freestyleArenaSettingsSection
                }
                
                // MARK: - Journalist Settings
                if userRole == "JOURNALIST" {
                    journalistSettingsSection
                }
                
                // MARK: - Legal & App Info (All Users)
                Section(header: Text("Legal & App Info")) {
                    Button(action: {
                        legalURL = URL(string: "https://c705.online/terms")
                    }) {
                        SettingsRow(icon: "doc.text", title: "Terms of Service", color: .black)
                    }

                    Button(action: {
                        legalURL = URL(string: "https://c705.online/privacy")
                    }) {
                        SettingsRow(icon: "hand.raised.fill", title: "Privacy Policy", color: .black)
                    }
                    
                    Button(action: {
                        legalURL = URL(string: "https://c705.online/community-guidelines")
                    }) {
                        SettingsRow(icon: "book.fill", title: "Community Guidelines", color: .black)
                    }
                    
                    HStack {
                        SettingsRow(icon: "info.circle", title: "App Version", color: .black)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                    
                    Button(action: {
                        // TODO: Contact support
                    }) {
                        SettingsRow(icon: "envelope.fill", title: "Contact Support", color: .black)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // TODO: Save settings to backend
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDeleteAccount) {
                DeleteAccountView(authService: authService) {
                    dismiss()
                }
            }
            .sheet(isPresented: $showChangeEmail) {
                ChangeEmailView()
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView()
            }
            .sheet(isPresented: $showTwoFactor) {
                TwoFactorView()
            }
            .sheet(isPresented: $showBlockedUsers) {
                BlockedUsersView(blockedUsers: $settings.privacy.blockedUsers)
            }
            .sheet(item: $legalURL) { url in
                SafariView(url: url)
            }
            .onAppear {
                loadSettings()
            }
        }
    }
    
    private func loadSettings() {
        // TODO: Load settings from backend API
        // For now, initialize with defaults
        initializeSettingsForRole()
    }
}

// MARK: - Settings Row Component
struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    var value: String? = nil
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 14))
                .frame(width: 24)
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.black)
            Spacer()
            if let value = value {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Placeholder Views for Settings Sub-pages
struct CommentPermissionView: View {
    @Binding var permission: CommentPermission
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            Picker("Who Can Comment", selection: $permission) {
                Text("Everyone").tag(CommentPermission.everyone)
                Text("Followers").tag(CommentPermission.followers)
            }
        }
        .navigationTitle("Who Can Comment")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MessagePermissionView: View {
    @Binding var permission: MessagePermission
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            Picker("Who Can Message Me", selection: $permission) {
                Text("Everyone").tag(MessagePermission.everyone)
                Text("Followers").tag(MessagePermission.followers)
                Text("None").tag(MessagePermission.none)
            }
        }
        .navigationTitle("Who Can Message Me")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AudioQualityView: View {
    @Binding var quality: AudioQuality
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            Picker("Audio Quality", selection: $quality) {
                Text("Low").tag(AudioQuality.low)
                Text("Medium").tag(AudioQuality.medium)
                Text("High").tag(AudioQuality.high)
            }
        }
        .navigationTitle("Audio Quality")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Delete Account View (App Store Requirement)
struct DeleteAccountView: View {
    @ObservedObject var authService: AuthService
    let dismiss: () -> Void
    @Environment(\.dismiss) var sheetDismiss
    @State private var confirmText = ""
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)

                    Text("Delete Account")
                        .font(.title2)
                        .bold()

                    Text("This action cannot be undone. Your profile, tracks, beats, entries, votes and comments will be permanently deleted. Any cypher you host will be deleted too, including other artists' entries in it.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("To confirm, type 'DELETE' below:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("DELETE", text: $confirmText)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.allCharacters)
                }
                .padding(.horizontal)
                
                if let deleteError {
                    Text(deleteError)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button(action: {
                    if confirmText == "DELETE" {
                        isDeleting = true
                        deleteError = nil
                        Task {
                            do {
                                // Delete on the server first; only sign out if it worked.
                                try await authService.deleteAccount()
                                sheetDismiss()
                                dismiss()
                            } catch {
                                deleteError = error.localizedDescription
                                isDeleting = false
                            }
                        }
                    }
                }) {
                    Text(isDeleting ? "Deleting..." : "Delete My Account")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(confirmText == "DELETE" && !isDeleting ? Color.red : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(confirmText != "DELETE" || isDeleting)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        sheetDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Placeholder Views (to be implemented)
struct ChangeEmailView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            Text("Change Email - Coming Soon")
                .navigationTitle("Change Email")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

struct ChangePasswordView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            Text("Change Password - Coming Soon")
                .navigationTitle("Change Password")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

struct TwoFactorView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            Text("Two-Factor Authentication - Coming Soon")
                .navigationTitle("Two-Factor Authentication")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

struct BlockedUsersView: View {
    @Binding var blockedUsers: [String]
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            List {
                ForEach(blockedUsers, id: \.self) { userId in
                    Text("User: \(userId)")
                }
            }
            .navigationTitle("Blocked Users")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct LegalDocumentView: View {
    let title: String
    let content: String
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                Text(content)
                    .padding()
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Role-Specific Settings Views (Placeholders)
struct ArtistProfileSettingsView: View {
    @Binding var settings: ArtistSettings?
    var body: some View {
        Text("Artist Profile Settings")
    }
}

struct LocationSettingsView: View {
    @Binding var location: String
    var body: some View {
        TextField("Location", text: $location)
            .navigationTitle("Location")
    }
}

struct SocialLinksView: View {
    @Binding var settings: ArtistSettings?
    var body: some View {
        Text("Social Links")
    }
}

struct PinTrackView: View {
    @Binding var trackId: String
    var body: some View {
        Text("Pin Track")
    }
}

struct ProducerNameView: View {
    @Binding var name: String
    var body: some View {
        TextField("Producer Name", text: $name)
            .navigationTitle("Producer Name")
    }
}

struct TagsView: View {
    @Binding var tags: [String]
    var body: some View {
        Text("Tags")
    }
}

struct BeatPriceView: View {
    @Binding var price: Double
    var body: some View {
        Text("Beat Price")
    }
}

struct StudioNameView: View {
    @Binding var name: String
    var body: some View {
        TextField("Studio Name", text: $name)
            .navigationTitle("Studio Name")
    }
}

struct BookingSettingsView: View {
    @Binding var settings: EngineerSettings?
    var body: some View {
        Text("Booking Settings")
    }
}

struct SessionLengthView: View {
    @Binding var lengths: [Int]
    var body: some View {
        Text("Session Lengths")
    }
}

struct CitiesView: View {
    @Binding var cities: [String]
    var body: some View {
        Text("Cities")
    }
}

struct GenresView: View {
    @Binding var genres: [String]
    var body: some View {
        Text("Genres")
    }
}

struct EditBioView: View {
    @Binding var bioText: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $bioText)
                    .padding()
                    .frame(maxHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Edit Bio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dismiss()
                    }
                }
            }
        }
    }
}



struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { }
}



extension URL: Identifiable {
    public var id: String { absoluteString }
}



#Preview {
    ProfileView()
        .environmentObject(AuthService())
}

