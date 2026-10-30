//
//  ArtistProfileView.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: An artist's profile screen reached from a list or search. It now
//  shows EnhancedArtistProfileView, but the older version of the
//  profile is still below it in this file, so the file holds two
//  profile designs.
//

import SwiftUI

struct ArtistProfileView: View {
    let artistId: String
    @StateObject private var viewModel = ArtistProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        // The newer profile design. The older profile code below it (ScrollView) is left over
        // and could be removed once it is confirmed unused.
        EnhancedArtistProfileView(artistId: artistId)
            .environmentObject(authService)
        // The original profile screen: avatar circle, bio, counts, a follow button and the
        // artist's tracks.
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView("Loading artist profile...")
                        .padding()
                } else if let profile = viewModel.artistProfile {
                    // Profile Header
                    VStack(spacing: 12) {
                        // Profile Image Placeholder
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(String(profile.name.prefix(1)).uppercased())
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.blue)
                            )
                        
                        // Name
                        Text(profile.name)
                            .font(.title)
                            .bold()
                        
                        // Bio
                        if let bio = profile.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Stats
                        HStack(spacing: 30) {
                            VStack {
                                Text("\(profile.tracksCount)")
                                    .font(.title2)
                                    .bold()
                                Text("Tracks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("\(viewModel.followersCount)")
                                    .font(.title2)
                                    .bold()
                                Text("Followers")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical)
                        
                        // Follow Button
                        Button(action: {
                            Task {
                                await viewModel.toggleFollow(artistId: artistId)
                            }
                        }) {
                            HStack {
                                Image(systemName: viewModel.isFollowing ? "person.badge.minus" : "person.badge.plus")
                                Text(viewModel.isFollowing ? "Unfollow" : "Follow")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.isFollowing ? Color.red : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    
                    Divider()
                    
                    // Tracks Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tracks")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        
                        ForEach(viewModel.tracks) { track in
                            TrackRowView(track: track)
                        }
                        
                        if viewModel.isLoadingTracks {
                            ProgressView()
                                .padding()
                        } else if viewModel.hasMoreTracks {
                            Button("Load More Tracks") {
                                Task {
                                    await viewModel.loadMoreTracks(artistId: artistId)
                                }
                            }
                            .padding()
                        }
                    }
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("Retry") {
                            Task {
                                await viewModel.loadArtistProfile(artistId: artistId)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
        }
        .themedScreen()
        .navigationTitle("Artist Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadArtistProfile(artistId: artistId)
            AnalyticsService.shared.trackProfileView(artistId: artistId)
        }
    }
}

// One track in an artist's list, with a play button, like count and date.
struct TrackRowView: View {
    let track: Track
    @StateObject private var audioViewModel = AudioPlayerViewModel()
    
    var body: some View {
        HStack(spacing: 12) {
            // Play button
            Button(action: {
                Task {
                    await audioViewModel.playTrack(track)
                }
            }) {
                Image(systemName: (audioViewModel.isPlaying && audioViewModel.currentTrack?.id == track.id) ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Label("\(track.likeCount)", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(formatDate(track.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    // Turns the server's date text into a short date such as 10/15/26.
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

#Preview {
    NavigationView {
        ArtistProfileView(artistId: "artist-id")
    }
}

