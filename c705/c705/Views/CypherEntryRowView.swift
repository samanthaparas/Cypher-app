//
//  CypherEntryRowView.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The small cards shown inside a cypher. This file has three views:
//  CypherEntryRowView (one artist's entry, with play, report and vote buttons),
//  LeaderboardRowView (one ranked line on the leaderboard) and ReportEntryView
//  (the sheet where someone reports an entry).
//

import SwiftUI

// One entry in a cypher: who posted it, its score, a play button, and a vote button.
struct CypherEntryRowView: View {
    let entry: CypherEntry
    let onVote: (Int, Int, Int) -> Void

    // The app's shared audio player. @ObservedObject makes this row redraw
    // whenever the player changes, so the play button flips to pause by itself.
    @ObservedObject private var player = AudioPlayerService.shared
    @State private var isLoadingAudio = false
    @State private var audioError: String?
    @State private var hasVoted = false
    @State private var showReportSheet = false
    @State private var showVotingSheet = false

    // True only when THIS entry is the audio currently playing. Without the URL
    // check, every row would show "pause" whenever any entry played.
    private var isPlayingThisEntry: Bool {
        player.isPlaying && player.currentURL == entry.audioUrl
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User Info
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String((entry.user?.username ?? entry.user?.email ?? "U").prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.user?.username ?? entry.user?.email ?? "Unknown")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    
                    if let title = entry.title {
                        Text(title)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Score
                if let score = entry.averageScore, score > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f", score))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.blue)
                        Text("\(entry.voteCount) votes")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Audio Player
            HStack {
                // Play/pause. The Task { } wrapper lets a button start work that
                // has to wait (the download) without freezing the screen.
                Button(action: {
                    Task { await togglePlayback() }
                }) {
                    if isLoadingAudio {
                        ProgressView()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: isPlayingThisEntry ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                    }
                }
                .disabled(isLoadingAudio)
                
                // Waveform placeholder: decoration only, not drawn from the audio.
                HStack(spacing: 2) {
                    ForEach(0..<20, id: \.self) { index in
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 3, height: waveformHeight(index))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                
                // Report Button
                Button(action: {
                    showReportSheet = true
                }) {
                    Image(systemName: "flag")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
            }
            
            // Voting Section
            if !hasVoted {
                Button(action: {
                    showVotingSheet = true
                }) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.blue)
                        Text("Vote on this entry")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            } else {
                Text("You've voted on this entry")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .themeCard(padding: 0)
        // Pops up a message if the audio could not be loaded, for example when
        // the file is not public or the phone is offline.
        .alert("Couldn't play this entry", isPresented: Binding(
            get: { audioError != nil },
            set: { if !$0 { audioError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(audioError ?? "")
        }
        .sheet(isPresented: $showReportSheet) {
            ReportEntryView(entryId: entry.id)
        }
        .sheet(isPresented: $showVotingSheet) {
            CypherVotingView(entry: entry) { bars, flow, creativity in
                onVote(bars, flow, creativity)
                hasVoted = true
            }
        }
    }

    // Asks the shared player to play, pause, or resume this entry's audio.
    // If it fails, the message is saved so the alert above can show it.
    private func togglePlayback() async {
        isLoadingAudio = true
        defer { isLoadingAudio = false }
        do {
            try await player.togglePlayback(urlString: entry.audioUrl)
        } catch {
            audioError = error.localizedDescription
        }
    }

    // Picks a bar height from the entry's id, so the same entry always gets the
    // same bars. Random heights would flicker every time the player updates.
    private func waveformHeight(_ index: Int) -> CGFloat {
        let seed = (entry.id + String(index)).unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 1000 }
        return 10 + CGFloat(seed % 21)
    }
}

// One line on a cypher's leaderboard: rank number, artist, and score.
// The top three ranks get an orange highlight.
struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(entry.rank)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(entry.rank <= 3 ? .orange : .gray)
                .frame(width: 40)
            
            // User
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String((entry.entry.user?.username ?? entry.entry.user?.email ?? "U").prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.entry.user?.username ?? entry.entry.user?.email ?? "Unknown")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                
                if let title = entry.entry.title {
                    Text(title)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", entry.entry.averageScore ?? 0))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.blue)
                Text("\(entry.entry.voteCount) votes")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(entry.rank <= 3 ? Color.orange.opacity(0.15) : Theme.card)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// The sheet for reporting an entry. The user must type a reason before the
// Submit button turns on. Reports reach the admin panel for review.
struct ReportEntryView: View {
    let entryId: String
    @Environment(\.dismiss) var dismiss
    @State private var reason = ""
    @State private var isSubmitting = false
    
    private let apiService = APIService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Report Entry")
                    .font(.headline)
                    .padding(.top)
                
                Text("Please provide a reason for reporting this entry")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextEditor(text: $reason)
                    .frame(height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                
                Button(action: {
                    Task {
                        await submitReport()
                    }
                }) {
                    Text(isSubmitting ? "Submitting..." : "Submit Report")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(reason.isEmpty ? Color.gray : Color.red)
                        .cornerRadius(10)
                }
                .disabled(reason.isEmpty || isSubmitting)
                .padding(.horizontal)
                
                Spacer()
            }
            .themedScreen()
            .navigationTitle("Report")
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
    
    // Sends the report to the server and closes the sheet when it succeeds.
    private func submitReport() async {
        isSubmitting = true
        
        do {
            try await apiService.reportCypherEntry(entryId: entryId, reason: reason)
            dismiss()
        } catch {
            print("Error reporting entry: \(error)")
            // TODO: Show error alert
        }
        
        isSubmitting = false
    }
}
