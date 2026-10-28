//
//  CypherVotingView.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The sheet where someone scores one cypher entry. They must listen
//  to the whole entry first, then rate it from 1 to 5 on Bars, Flow and
//  Creativity, and submit.
//

import SwiftUI

struct CypherVotingView: View {
    let entry: CypherEntry
    // The cypher's beat, played under the entry. nil plays the voice alone.
    var beatUrl: String? = nil
    // Called when the vote is submitted. The three numbers are the scores.
    let onVote: (Int, Int, Int) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var bars: Double = 3.0
    @State private var flow: Double = 3.0
    @State private var creativity: Double = 3.0
    // Stays false until the audio has played to the end. The Submit button
    // is disabled until this becomes true.
    @State private var hasPlayedFullEntry = false
    @State private var isSubmitting = false

    // The app's shared audio player (see AudioPlayerService.swift).
    // @ObservedObject redraws this screen whenever the player changes.
    @ObservedObject private var player = AudioPlayerService.shared
    @State private var audioError: String?

    // These two are worked out from the player each time, so they cannot get
    // out of sync with what is really playing.
    private var isPlaying: Bool {
        player.isPlaying && player.currentURL == entry.audioUrl
    }
    private var playbackProgress: Double {
        // Once the whole entry has been heard (and it is not replaying), keep the bar full.
        if hasPlayedFullEntry && !isPlaying { return 1.0 }
        guard player.currentURL == entry.audioUrl, player.duration > 0 else {
            return hasPlayedFullEntry ? 1.0 : 0
        }
        return player.currentTime / player.duration
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Entry Info
                    VStack(spacing: 8) {
                        Text(entry.user?.username ?? entry.user?.email ?? "Unknown")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let title = entry.title {
                            Text(title)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    
                    // Audio Player: plays the real entry and shows how far along it is.
                    VStack(spacing: 12) {
                        HStack {
                            // Play/pause. If loading fails, the message is saved
                            // so the alert at the bottom of this view can show it.
                            Button(action: {
                                Task {
                                    do {
                                        try await player.togglePlayback(urlString: entry.audioUrl, beatURLString: beatUrl)
                                    } catch {
                                        audioError = error.localizedDescription
                                    }
                                }
                            }) {
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.blue)
                            }
                            
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 4)
                                    
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: geometry.size.width * playbackProgress, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        .padding(.horizontal)
                        
                        if !hasPlayedFullEntry {
                            Text("Please listen to the full entry before voting")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("✓ Entry played")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Theme.card)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Voting Sliders: three 1 to 5 scores. Each card below follows the
                    // same pattern: a label, the current number, and a slider.
                    VStack(spacing: 20) {
                        Text("Rate this entry")
                            .font(.headline)
                            .padding(.top)
                        
                        // Bars Rating
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Bars")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Text("\(Int(bars))")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            
                            Slider(value: $bars, in: 1...5, step: 1)
                                .accentColor(.blue)
                            
                            HStack {
                                Text("1")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("5")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .themeCard(padding: 0)
                        
                        // Flow Rating
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Flow")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Text("\(Int(flow))")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            
                            Slider(value: $flow, in: 1...5, step: 1)
                                .accentColor(.blue)
                            
                            HStack {
                                Text("1")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("5")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .themeCard(padding: 0)
                        
                        // Creativity Rating
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Creativity")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Text("\(Int(creativity))")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            
                            Slider(value: $creativity, in: 1...5, step: 1)
                                .accentColor(.blue)
                            
                            HStack {
                                Text("1")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("5")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .themeCard(padding: 0)
                    }
                    .padding(.horizontal)
                    
                    // Submit Vote Button. It stays gray and disabled until the
                    // entry has been played all the way through.
                    Button(action: {
                        isSubmitting = true
                        onVote(Int(bars), Int(flow), Int(creativity))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isSubmitting = false
                            dismiss()
                        }
                    }) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(isSubmitting ? "Submitting..." : "Submit Vote")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(hasPlayedFullEntry ? Color.blue : Color.gray)
                        .cornerRadius(10)
                    }
                    .disabled(!hasPlayedFullEntry || isSubmitting)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .themedScreen()
            .navigationTitle("Vote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            // When the sheet opens: stop anything already playing, then check whether this entry
            // was already played all the way through earlier (on the entries list or in this sheet).
            // An entry that was stopped early does not count.
            .onAppear {
                player.stop()
                hasPlayedFullEntry = player.finishedURLs.contains(entry.audioUrl)
            }
            // The player records an entry here when it plays to the end. If it is this entry,
            // unlock the Submit button.
            .onChange(of: player.finishedURLs) { _, finished in
                if finished.contains(entry.audioUrl) {
                    hasPlayedFullEntry = true
                }
            }
            // Stop the audio when the sheet closes so it does not keep playing.
            .onDisappear {
                player.stop()
            }
            // Pops up a message if the audio could not be loaded.
            .alert("Couldn't play this entry", isPresented: Binding(
                get: { audioError != nil },
                set: { if !$0 { audioError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(audioError ?? "")
            }
        }
    }
}

