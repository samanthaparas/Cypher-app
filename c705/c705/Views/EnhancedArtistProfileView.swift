//
//  EnhancedArtistProfileView.swift
//  c705
//
//  Enhanced Artist Profile with all sections
//
//  PURPOSE: The current design of an artist's profile page, built from small
//  pieces: header, stats, action buttons, music, cypher highlights,
//  about and social links. The same page serves your own profile (with
//  Edit and Upload) and other artists' profiles (with Follow, Message
//  and Invite).
//

import SwiftUI

// Given an artist id, it loads that profile and arranges the sections below in order.
struct EnhancedArtistProfileView: View {
    let artistId: String
    @StateObject private var viewModel = ArtistProfileViewModel()
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var showEditProfile = false
    @State private var showReportSheet = false
    // Set when Invite to Cypher is tapped, but no sheet is connected to it yet, so that button
    // does nothing.
    @State private var showCypherInvite = false
    
    var isOwnProfile: Bool {
        viewModel.artistProfile?.id == authService.currentUser?.id
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView("Loading artist profile...")
                        .padding()
                } else if let profile = viewModel.artistProfile {
                    // 1️⃣ Artist Header
                    ArtistHeaderView(profile: profile)
                        .padding(.top, 20)
                    
                    // 2️⃣ Stats Row
                    StatsRowView(
                        followersCount: viewModel.followersCount,
                        tracksCount: profile.tracksCount,
                        cypherWins: 0 // TODO: Get from cypher entries
                    )
                    .padding(.vertical, 20)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // 3️⃣ Action Buttons
                    ActionButtonsView(
                        isOwnProfile: isOwnProfile,
                        isFollowing: viewModel.isFollowing,
                        onFollow: {
                            Task {
                                await viewModel.toggleFollow(artistId: artistId)
                            }
                        },
                        onEdit: {
                            showEditProfile = true
                        },
                        onMessage: {
                            // TODO: Navigate to messages
                        },
                        onInviteCypher: {
                            showCypherInvite = true
                        },
                        onUploadTrack: {
                            // TODO: Navigate to upload
                        }
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // 4️⃣ Music Section
                    MusicSectionView(
                        tracks: viewModel.tracks,
                        isLoading: viewModel.isLoadingTracks,
                        hasMore: viewModel.hasMoreTracks,
                        onLoadMore: {
                            Task {
                                await viewModel.loadMoreTracks(artistId: artistId)
                            }
                        }
                    )
                    .padding(.top, 20)
                    
                    // 5️⃣ Cypher Highlights
                    CypherHighlightsView(artistId: artistId)
                        .padding(.top, 20)
                    
                    // 6️⃣ About / Bio
                    AboutSectionView(profile: profile)
                        .padding(.top, 20)
                    
                    // 7️⃣ Social Links
                    ArtistSocialLinksView(
                        instagramUrl: profile.instagramUrl,
                        youtubeUrl: profile.youtubeUrl,
                        xUrl: profile.xUrl,
                        tiktokUrl: profile.tiktokUrl
                    )
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task {
                            await viewModel.loadArtistProfile(artistId: artistId)
                        }
                    }
                }
            }
        }
        .themedScreen()
        .navigationTitle("Artist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if !isOwnProfile {
                        Button(action: {
                            showReportSheet = true
                        }) {
                            Label("Report Artist", systemImage: "flag")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        // Slides up the edit screen, which is still a placeholder.
        .sheet(isPresented: $showEditProfile) {
            EditArtistProfileView(profile: viewModel.artistProfile!)
        }
        // Slides up the report screen, which is still a placeholder.
        .sheet(isPresented: $showReportSheet) {
            ReportArtistView(artistId: artistId)
        }
        // Loads the profile when the screen first appears.
        .task {
            await viewModel.loadArtistProfile(artistId: artistId)
        }
    }
}

// Each struct below is one section of the page, kept small so it is easy to find and change.
// MARK: - Artist Header
struct ArtistHeaderView: View {
    let profile: ArtistProfile
    
    var body: some View {
        VStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                if let avatarUrl = profile.avatarUrl, !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Text(String(profile.name.prefix(1)).uppercased())
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                } else {
                    Text(String(profile.name.prefix(1)).uppercased())
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            
            // Name
            Text(profile.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            
            // Account Type - Show role under name
            Text(profile.role.capitalized)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
                .padding(.top, -4)
            
            // City
            if let city = profile.city, !city.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                    Text(city)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
    }
}

// The row of numbers: followers, tracks and cypher wins. The cypher wins number is still a
// fixed 0.
// MARK: - Stats Row
struct StatsRowView: View {
    let followersCount: Int
    let tracksCount: Int
    let cypherWins: Int
    
    var body: some View {
        HStack(spacing: 40) {
            StatItem(value: "\(followersCount)", label: "Followers")
            StatItem(value: "\(tracksCount)", label: "Tracks")
            StatItem(value: "\(cypherWins)", label: "Cypher Wins")
        }
        .padding(.horizontal)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
    }
}

// Shows different buttons for your own profile (Edit, Upload) and for someone else's (Follow,
// Message, Invite). Message and Upload are not connected yet.
// MARK: - Action Buttons
struct ActionButtonsView: View {
    let isOwnProfile: Bool
    let isFollowing: Bool
    let onFollow: () -> Void
    let onEdit: () -> Void
    let onMessage: () -> Void
    let onInviteCypher: () -> Void
    let onUploadTrack: () -> Void
    
    var body: some View {
        if isOwnProfile {
            // Own profile actions
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit Profile")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: onUploadTrack) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Upload")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
        } else {
            // Other user's profile actions
            HStack(spacing: 12) {
                Button(action: onFollow) {
                    HStack {
                        Image(systemName: isFollowing ? "person.badge.minus" : "person.badge.plus")
                        Text(isFollowing ? "Unfollow" : "Follow")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isFollowing ? Color.red : Color.blue)
                    .cornerRadius(8)
                }
                
                Button(action: onMessage) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Button(action: onInviteCypher) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
    }
}

// The artist's tracks.
// MARK: - Music Section
struct MusicSectionView: View {
    let tracks: [Track]
    let isLoading: Bool
    let hasMore: Bool
    let onLoadMore: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Music")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal)
            
            if tracks.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No tracks yet")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(tracks) { track in
                    TrackRowView(track: track)
                        .padding(.horizontal)
                }
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if hasMore {
                    Button(action: onLoadMore) {
                        Text("Load More")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// A row of the artist's cypher entries.
// MARK: - Cypher Highlights
struct CypherHighlightsView: View {
    let artistId: String
    @State private var cypherEntries: [CypherEntry] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cypher Highlights")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if cypherEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "mic.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No cypher entries yet")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(cypherEntries.prefix(5)) { entry in
                            CypherHighlightCard(entry: entry)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task {
            await loadCypherEntries()
        }
    }
    
    // Not built yet. It always sets an empty list, so the section shows "No cypher entries
    // yet".
    private func loadCypherEntries() async {
        isLoading = true
        // TODO: Load cypher entries for this artist
        // For now, empty array
        cypherEntries = []
        isLoading = false
    }
}

struct CypherHighlightCard: View {
    let entry: CypherEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = entry.title {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
            }
            
            HStack {
                if let score = entry.averageScore {
                    Label(String(format: "%.1f", score), systemImage: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                Button(action: {
                    // TODO: Play cypher entry
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .frame(width: 150)
        .background(Theme.card)
        .cornerRadius(12)
    }
}

// The artist's bio.
// MARK: - About Section
struct AboutSectionView: View {
    let profile: ArtistProfile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal)
            
            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textPrimary)
                    .lineSpacing(4)
                    .padding(.horizontal)
            } else {
                Text("No bio available")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
        }
    }
}

// Buttons that open the artist's Instagram, YouTube, X and TikTok.
// MARK: - Social Links
struct ArtistSocialLinksView: View {
    let instagramUrl: String?
    let youtubeUrl: String?
    let xUrl: String?
    let tiktokUrl: String?
    
    var hasAnyLinks: Bool {
        instagramUrl != nil || youtubeUrl != nil || xUrl != nil || tiktokUrl != nil
    }
    
    var body: some View {
        if hasAnyLinks {
            VStack(alignment: .leading, spacing: 12) {
                Text("Connect")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal)
                
                HStack(spacing: 16) {
                    if let instagram = instagramUrl {
                        ArtistSocialLinkButton(icon: "camera.fill", url: instagram, color: .pink)
                    }
                    if let youtube = youtubeUrl {
                        ArtistSocialLinkButton(icon: "play.rectangle.fill", url: youtube, color: .red)
                    }
                    if let x = xUrl {
                        ArtistSocialLinkButton(icon: "at", url: x, color: .black)
                    }
                    if let tiktok = tiktokUrl {
                        ArtistSocialLinkButton(icon: "music.note", url: tiktok, color: .black)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct ArtistSocialLinkButton: View {
    let icon: String
    let url: String
    let color: Color
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(color)
                .cornerRadius(8)
        }
    }
}

// Shown when the profile cannot be loaded, with a retry button.
// MARK: - Error View
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// These two screens only say "Coming Soon". They exist so the buttons have somewhere to go.
// Placeholder views for edit and report
struct EditArtistProfileView: View {
    let profile: ArtistProfile
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("Edit Profile - Coming Soon")
                .themedScreen()
                .navigationTitle("Edit Profile")
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

struct ReportArtistView: View {
    let artistId: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("Report Artist - Coming Soon")
                .themedScreen()
                .navigationTitle("Report Artist")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

