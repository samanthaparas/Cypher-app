//
//  AudioPlayerViewModel.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The screen-friendly layer on top of AudioPlayerService. It exposes
//  simple values (is it playing, what time is it, how far along) and
//  forwards play, pause and seek requests.
//

import Foundation
import Combine

@MainActor
class AudioPlayerViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // The shared player that actually makes the sound. This class only reads from it and sends
    // it commands.
    private let audioPlayer = AudioPlayerService.shared
    private var cancellables = Set<AnyCancellable>()
    
    var isPlaying: Bool {
        audioPlayer.isPlaying
    }
    
    var currentTrack: Track? {
        audioPlayer.currentTrack
    }
    
    var currentTime: TimeInterval {
        audioPlayer.currentTime
    }
    
    var duration: TimeInterval {
        audioPlayer.duration
    }
    
    // How far through the audio we are, from 0 (start) to 1 (end). Progress bars use this.
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    var formattedCurrentTime: String {
        formatTime(currentTime)
    }
    
    var formattedDuration: String {
        formatTime(duration)
    }
    
    // Subscribes to the player's changes and tells the screen to redraw whenever playing, time
    // or track change.
    init() {
        // Observe audio player changes
        audioPlayer.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        audioPlayer.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        audioPlayer.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // Loads and plays a track, showing a loading state and recording the play for analytics.
    func playTrack(_ track: Track) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await audioPlayer.loadTrack(track)
            audioPlayer.play()
            AnalyticsService.shared.trackTrackPlay(trackId: track.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func play() {
        audioPlayer.play()
    }
    
    func pause() {
        audioPlayer.pause()
    }
    
    func stop() {
        audioPlayer.stop()
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer.seek(to: time)
    }
    
    // Jumps to a spot given as a fraction (0.5 means halfway), for dragging a progress bar.
    func seekToProgress(_ progress: Double) {
        let time = duration * progress
        seek(to: time)
    }
    
    // Turns seconds into text like 2:05.
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

