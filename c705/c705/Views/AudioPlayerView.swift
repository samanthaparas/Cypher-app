//
//  AudioPlayerView.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: Two audio player controls for tracks: a full player (progress bar,
//  stop, play and pause) and a compact one-line player for lists. Both
//  play through the app's shared AudioPlayerService.
//

import SwiftUI

// The full player. It starts playing its track as soon as it appears.
struct AudioPlayerView: View {
    // A view model that talks to the shared player. Several views can have their own while the
    // sound itself stays shared.
    @StateObject private var viewModel = AudioPlayerViewModel()
    let track: Track
    
    var body: some View {
        VStack(spacing: 16) {
            // Track Info
            VStack(spacing: 8) {
                Text(track.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if let artist = track.artist {
                    Text(artist.user?.email ?? "Unknown Artist")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Progress Bar
            VStack(spacing: 4) {
                // A bar that fills from 0 to 1 as the track plays.
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                HStack {
                    Text(viewModel.formattedCurrentTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(viewModel.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Controls
            HStack(spacing: 40) {
                // Stop button
                Button(action: {
                    viewModel.stop()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                
                // Play/Pause button
                Button(action: {
                    if viewModel.isPlaying {
                        viewModel.pause()
                    } else {
                        viewModel.play()
                    }
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                }
                .disabled(viewModel.isLoading)
                
                // Spacer for alignment
                Color.clear
                    .frame(width: 30, height: 30)
            }
            .padding()
            
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .padding()
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 8)
        // When the player appears, start loading and playing the track.
        .onAppear {
            Task {
                await viewModel.playTrack(track)
            }
        }
    }
}

// MARK: - Compact Player View (for feed)

// A small one-row player for lists such as the feed. The track id is compared with the loaded
// track so only the right row shows pause.
struct CompactAudioPlayerView: View {
    @StateObject private var viewModel = AudioPlayerViewModel()
    let track: Track
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause button
            Button(action: {
                if viewModel.isPlaying && viewModel.currentTrack?.id == track.id {
                    viewModel.pause()
                } else {
                    Task {
                        await viewModel.playTrack(track)
                    }
                }
            }) {
                Image(systemName: (viewModel.isPlaying && viewModel.currentTrack?.id == track.id) ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .disabled(viewModel.isLoading)
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.subheadline)
                    .lineLimit(1)
                
                if viewModel.isPlaying && viewModel.currentTrack?.id == track.id {
                    Text("\(viewModel.formattedCurrentTime) / \(viewModel.formattedDuration)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    if let artist = track.artist {
                        Text(artist.user?.email ?? "Unknown Artist")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if viewModel.isLoading && viewModel.currentTrack?.id == track.id {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    VStack {
        AudioPlayerView(track: Track(
            id: "1",
            title: "Sample Track",
            audioUrl: "https://example.com/audio.mp3",
            artistId: "1",
            likeCount: 0,
            createdAt: "",
            artist: nil,
            isLiked: false
        ))
        
        CompactAudioPlayerView(track: Track(
            id: "1",
            title: "Sample Track",
            audioUrl: "https://example.com/audio.mp3",
            artistId: "1",
            likeCount: 0,
            createdAt: "",
            artist: nil,
            isLiked: false
        ))
    }
    .padding()
}

