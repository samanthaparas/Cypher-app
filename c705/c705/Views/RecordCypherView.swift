//
//  RecordCypherView.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The recording screen for a cypher entry. The cypher's beat
//  loops as a preview; the user gives an optional title, taps Record, gets
//  a 3-2-1 countdown (or Instant), records up to 60 seconds over the beat
//  from the top, then submits the entry to the server.
//

import SwiftUI
import AVFoundation

// Opened from a cypher's Details tab. It is told which cypher the entry belongs to.
struct RecordCypherView: View {
    let cypherId: String
    let cypher: CypherDetail?
    @Environment(\.dismiss) var dismiss
    // The app's shared microphone recorder. The screen redraws as it records and its timer
    // ticks.
    @StateObject private var recorder = AudioRecorderService.shared
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var entryTitle = ""
    @State private var beatState: BeatLoadState = .none
    // The beat's link once it has loaded, so the listen-back can play it under the take.
    @State private var loadedBeatURL: URL?
    // Countdown or Instant. @AppStorage remembers the choice between visits.
    @AppStorage("recordWithCountdown") private var useCountdown = true
    
    private let apiService = APIService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if beatState != .none {
                        BeatPreviewCard(title: "Cypher beat", state: beatState, recorder: recorder)
                    }
                    
                    RecordingStatusView(recorder: recorder)
                        .padding(.top, beatState == .none ? 40 : 8)
                    
                    // Title Input (Optional)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Entry Title (Optional)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        TextField("My Cypher Entry", text: $entryTitle)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)
                    
                    if let take = recorder.getRecordingURL() {
                        // After Stop: listen back with the beat, then Retake or submit.
                        TakeReviewPanel(
                            takeURL: take,
                            beatURL: loadedBeatURL,
                            useLabel: "Submit This Take",
                            isBusy: isUploading,
                            onRetake: { recorder.discardLastRecording() },
                            onUse: { Task { await uploadRecording(audioURL: take) } }
                        )
                        
                        if isUploading {
                            ProgressView(value: uploadProgress)
                                .padding(.horizontal)
                        }
                    } else if !recorder.isAligningTake {
                        CountdownModePicker(
                            useCountdown: $useCountdown,
                            isLocked: recorder.isRecording || recorder.countdownValue != nil
                        )
                        
                        RecordControls(
                            recorder: recorder,
                            useCountdown: useCountdown,
                            onError: { error in
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        )
                        
                        if beatState != .none {
                            HeadphonesTip()
                        }
                    }
                }
                .padding(.vertical)
            }
            // Stretch to the full sheet so the navy background reaches both edges.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .themedScreen()
            .navigationTitle("Record Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        recorder.cancelRecording()
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            // When the screen opens: forget any take from another screen, ask for microphone
            // permission if it has not been given (an error shows if the user says no), then
            // load the cypher's beat.
            .task {
                recorder.clearLastRecording()
                if !recorder.hasPermission {
                    let granted = await recorder.requestPermission()
                    if !granted {
                        errorMessage = "Microphone permission is required to record"
                        showError = true
                    }
                }
                await loadBeat()
            }
            // Swiping the sheet away skips the Cancel button, so stop everything here too.
            .onDisappear {
                recorder.cancelRecording()
                recorder.unloadBeat()
            }
        }
    }
    
    // Loads the cypher's beat so it can loop before the take and play under it.
    private func loadBeat() async {
        guard let link = cypher?.beatUrl, let url = URL(string: link) else {
            beatState = .none
            return
        }
        beatState = .loading
        do {
            try await recorder.loadBeat(from: url)
            loadedBeatURL = url
            beatState = .ready
        } catch {
            beatState = .failed("Couldn't load the beat. You can still record.")
        }
    }
    
    // Reads the recording file, uploads it as the cypher entry with the title, deletes the
    // local file and closes the screen. If it fails, an error message appears.
    private func uploadRecording(audioURL: URL) async {
        isUploading = true
        uploadProgress = 0
        
        do {
            guard let audioData = try? Data(contentsOf: audioURL) else {
                throw NSError(domain: "RecordCypherView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read recording file"])
            }
            
            let fileName = "cypher-entry-\(Date().timeIntervalSince1970).m4a"
            
            uploadProgress = 0.5
            
            let _ = try await apiService.submitCypherEntry(
                cypherId: cypherId,
                audioData: audioData,
                fileName: fileName,
                title: entryTitle.isEmpty ? nil : entryTitle
            )
            
            uploadProgress = 1.0
            
            // Clean up recording file
            try? FileManager.default.removeItem(at: audioURL)
            recorder.clearLastRecording()
            
            dismiss()
        } catch {
            errorMessage = "Failed to upload: \(error.localizedDescription)"
            showError = true
            isUploading = false
        }
    }
}

// MARK: - Shared recording pieces
// Used by both record screens: joining a cypher (above) and Record Over Beat when creating one
// (CreateCypherView.swift).

// Where the beat for a record screen stands. .none means there is no beat to play.
enum BeatLoadState: Equatable {
    case none
    case loading
    case ready
    case failed(String)
}

// Shows the beat with a play/pause button so the artist can loop it before recording.
struct BeatPreviewCard: View {
    let title: String
    let state: BeatLoadState
    @ObservedObject var recorder: AudioRecorderService
    
    var body: some View {
        HStack(spacing: Theme.spacing) {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundColor(Theme.accent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            if state == .loading {
                ProgressView()
            } else if state == .ready {
                Button(action: { recorder.toggleBeatPreview() }) {
                    Image(systemName: recorder.isBeatPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.accent)
                }
                // Mid-take the beat has to keep time, so it can't be paused. During review the
                // listen-back plays its own copy of the beat.
                .disabled(isLocked)
                // The color is set by hand, so dim it ourselves to show it can't be tapped.
                .opacity(isLocked ? 0.4 : 1)
            }
        }
        .themeCard()
        .padding(.horizontal)
    }
    
    private var isLocked: Bool {
        recorder.isRecording || recorder.countdownValue != nil
            || recorder.isAligningTake || recorder.getRecordingURL() != nil
    }
    
    private var statusText: String {
        switch state {
        case .none: return "No beat"
        case .loading: return "Loading beat…"
        case .failed(let message): return message
        case .ready:
            if recorder.isRecording { return "Playing from the top" }
            if recorder.getRecordingURL() != nil { return "Plays under your take below" }
            return recorder.isBeatPlaying ? "Looping. Record when you're ready" : "Tap play to loop it"
        }
    }
}

// Picks between a 3-2-1 countdown and recording the instant Record is tapped. The choice is
// remembered for next time.
struct CountdownModePicker: View {
    @Binding var useCountdown: Bool
    let isLocked: Bool
    
    var body: some View {
        Picker("Start", selection: $useCountdown) {
            Text("3-2-1 Countdown").tag(true)
            Text("Instant").tag(false)
        }
        .pickerStyle(.segmented)
        .disabled(isLocked)
        .padding(.horizontal)
    }
}

// Without headphones the phone speaker plays the beat straight into the mic, so the take
// ends up with the beat recorded on top of itself.
struct HeadphonesTip: View {
    var body: some View {
        Label("Wear headphones so the beat doesn't bleed into your vocals.", systemImage: "headphones")
            .font(.caption)
            .foregroundColor(Theme.textSecondary)
            .padding(.horizontal)
    }
}

// The big circle in the middle: the countdown number, the live recording timer, or ready.
struct RecordingStatusView: View {
    @ObservedObject var recorder: AudioRecorderService
    
    var body: some View {
        VStack(spacing: 16) {
            if let count = recorder.countdownValue {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Text("\(count)")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                Text("Get ready...")
                    .font(.headline)
                    .foregroundColor(.orange)
            } else if recorder.isRecording {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .fill(Color.red)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                
                Text("Recording...")
                    .font(.headline)
                    .foregroundColor(.red)
                
                Text(Self.timeString(recorder.recordingTime))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                
                Text("Max: 60 seconds")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else if recorder.isAligningTake {
                ProgressView()
                    .frame(width: 120, height: 120)
                
                Text("Lining up your take…")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: recorder.getRecordingURL() == nil ? "mic.fill" : "headphones")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                }
                
                Text(recorder.getRecordingURL() == nil ? "Ready to Record" : "Check your take")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
        }
    }
    
    static func timeString(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// The round button under the status: Record, Cancel during the countdown, or Stop mid-take.
// After Stop, the screen shows TakeReviewPanel instead.
struct RecordControls: View {
    @ObservedObject var recorder: AudioRecorderService
    let useCountdown: Bool
    let onError: (Error) -> Void
    
    var body: some View {
        Group {
            if recorder.isRecording {
                controlButton(icon: "stop.circle.fill", label: "Stop") {
                    recorder.stopRecording()
                }
            } else if recorder.countdownValue != nil {
                controlButton(icon: "xmark.circle.fill", label: "Cancel") {
                    recorder.cancelCountdown()
                }
            } else {
                controlButton(icon: "record.circle.fill", label: "Record") {
                    recorder.beginTake(countdown: useCountdown, onError: onError)
                }
                .disabled(!recorder.hasPermission)
            }
        }
        .padding()
    }
    
    private func controlButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                Text(label)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
}

// Shown after Stop: plays the take with the beat underneath, lined up the way it will post, so
// the artist can check their voice came through and sits on the beat. Then Retake or use it.
struct TakeReviewPanel: View {
    let takeURL: URL
    // The beat to play under the take, or nil to play the voice alone.
    let beatURL: URL?
    let useLabel: String
    // True while the take is being used (for example uploading), which locks both buttons.
    let isBusy: Bool
    let onRetake: () -> Void
    let onUse: () -> Void
    
    @ObservedObject private var player = AudioPlayerService.shared
    @State private var loadError: String?
    @State private var isLoading = false
    
    private var isThisTake: Bool { player.currentURL == takeURL.absoluteString }
    private var isPlayingTake: Bool { isThisTake && player.isPlaying }
    private var progress: Double {
        guard isThisTake, player.duration > 0 else { return 0 }
        return min(player.currentTime / player.duration, 1)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("Listen back")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            Text(beatURL == nil ? "Your voice, exactly as it will post." : "Your voice over the beat, lined up the way it will post.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            
            HStack(spacing: Theme.spacing) {
                Button(action: { Task { await togglePlayback() } }) {
                    if isLoading {
                        ProgressView()
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: isPlayingTake ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(Theme.accent)
                    }
                }
                .disabled(isLoading || isBusy)
                
                ProgressView(value: progress)
                    .tint(Theme.accent)
                
                Text(RecordingStatusView.timeString(isThisTake ? player.duration : 0))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(Theme.textSecondary)
            }
            
            if let loadError {
                Text(loadError)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            HStack(spacing: Theme.spacing) {
                Button(action: onRetake) {
                    Label("Retake", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.buttonRadius)
                                .stroke(Theme.cardBorder, lineWidth: 1)
                        )
                        .cornerRadius(Theme.buttonRadius)
                }
                
                Button(action: onUse) {
                    HStack {
                        if isBusy {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "checkmark")
                        }
                        Text(useLabel)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent)
                    .cornerRadius(Theme.buttonRadius)
                }
            }
            .disabled(isBusy)
        }
        .themeCard()
        .padding(.horizontal)
        // Leaving the review (Retake, Use This Take, or closing) stops the listen-back.
        .onDisappear {
            if isThisTake { player.stop() }
        }
    }
    
    private func togglePlayback() async {
        isLoading = !isThisTake
        defer { isLoading = false }
        do {
            loadError = nil
            try await player.togglePlayback(urlString: takeURL.absoluteString, beatURLString: beatURL?.absoluteString)
        } catch {
            loadError = "Couldn't play your take: \(error.localizedDescription)"
        }
    }
}
