//
//  AudioPlayerService.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The one audio player the whole app shares. It downloads a sound
//  file, plays it, and tells the screens what is happening (playing, paused,
//  how far along). It can play a Track (loadTrack) or any other audio URL,
//  such as a cypher entry (loadAudio / togglePlayback).
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer

// A "service" holds logic that is not tied to one screen. `shared` below means
// every screen uses this same player, so only one thing can play at a time.
class AudioPlayerService: NSObject, ObservableObject {
    static let shared = AudioPlayerService()
    
    // @Published values: when one changes, any screen watching this player
    // redraws itself automatically.
    @Published var isPlaying = false
    @Published var currentTrack: Track?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackRate: Float = 1.0
    
    // Which audio URL is loaded right now. Entry rows compare this to their own
    // URL to know if THEY are the one playing.
    @Published var currentURL: String?
    // Every audio URL that has played all the way to its natural end during this app session.
    // Stopping early, pausing and leaving, or switching to another entry does NOT add to it.
    // The voting screen uses this to know the listener really heard the whole entry,
    // wherever they listened (the entries list or the vote sheet).
    @Published var finishedURLs: Set<String> = []

    // AVAudioPlayer is Apple's built-in class that actually makes the sound.
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    // MARK: - Audio Session Setup
    
    // The audio session tells iOS what kind of audio this app plays. The
    // .playback category lets sound play even with the silent switch on.
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Remote Command Center (Lock Screen Controls)
    
    // Connects the lock screen and headphone buttons (play, pause, scrub)
    // to this player.
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        // Toggle play/pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            if self?.isPlaying == true {
                self?.pause()
            } else {
                self?.play()
            }
            return .success
        }
        
        // Next track (optional)
        commandCenter.nextTrackCommand.isEnabled = false
        
        // Previous track (optional)
        commandCenter.previousTrackCommand.isEnabled = false
        
        // Change playback position
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
                return .success
            }
            return .commandFailed
        }
    }
    
    // MARK: - Playback Control
    
    // Loads a Track (a song with an artist and a like count) and gets it ready.
    func loadTrack(_ track: Track) async throws {
        // Stop current playback
        stop()
        
        // Update current track
        currentTrack = track
        
        // Load audio from URL
        guard let url = URL(string: track.audioUrl) else {
            throw AudioPlayerError.invalidURL
        }
        
        // Download audio data
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Create audio player
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        
        // Update duration
        duration = audioPlayer?.duration ?? 0
        
        // Update now playing info
        updateNowPlayingInfo()
    }
    
    // Loads audio from any URL. Cypher entries use this because an entry is
    // not a Track. "async" means it waits for the download without freezing
    // the screen. @MainActor makes it run on the main thread, which is where
    // changes to @Published values must happen.
    @MainActor
    func loadAudio(urlString: String) async throws {
        stop()
        guard let url = URL(string: urlString) else {
            throw AudioPlayerError.invalidURL
        }
        currentURL = urlString

        let (data, response) = try await URLSession.shared.data(from: url)
        // A file that is not public comes back as an error page, not audio.
        // Catch it here so the user sees "Failed to load audio".
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw AudioPlayerError.loadFailed
        }

        // If the user tapped a different entry while this one was downloading,
        // drop this download so it does not take over the player.
        guard currentURL == urlString else { return }

        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        duration = audioPlayer?.duration ?? 0
    }

    // One call for a play/pause button: pauses if it is playing, resumes if it
    // is paused, and downloads it first if it has not been loaded yet.
    @MainActor
    func togglePlayback(urlString: String) async throws {
        if currentURL == urlString, audioPlayer != nil {
            isPlaying ? pause() : play()
        } else {
            try await loadAudio(urlString: urlString)
            play()
        }
    }

    func play() {
        guard let player = audioPlayer else { return }
        
        do {
            try audioSession.setActive(true)
            player.play()
            isPlaying = true
            startTimer()
            updateNowPlayingInfo()
        } catch {
            print("Failed to play audio: \(error.localizedDescription)")
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
        updateNowPlayingInfo()
    }
    
    // Stops playback and clears everything the player was holding.
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopTimer()
        currentTrack = nil
        currentURL = nil
    }
    
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = time
        currentTime = time
        updateNowPlayingInfo()
    }
    
    func setPlaybackRate(_ rate: Float) {
        guard let player = audioPlayer else { return }
        player.rate = rate
        playbackRate = rate
    }
    
    // MARK: - Timer
    
    // While audio plays, copy the current position into currentTime ten times
    // a second. This is what makes progress bars move.
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Now Playing Info (Lock Screen)
    
    // Fills in the title and artist shown on the lock screen. Only Tracks have
    // this info, so cypher entries show nothing there.
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
        
        if let artist = track.artist {
            nowPlayingInfo[MPMediaItemPropertyArtist] = artist.user?.email ?? "Unknown Artist"
        }
        
        // Load and set artwork (optional)
        // You can add album artwork here if available
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}

// MARK: - AVAudioPlayerDelegate

// A "delegate" is a helper that Apple's player calls back when something
// happens, like the audio ending or being interrupted by a phone call.
extension AudioPlayerService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Remember which audio just finished. iOS only calls this when the audio reaches its end
        // (flag is true), not when it is stopped early, so only complete listens are recorded.
        if flag, let url = currentURL { finishedURLs.insert(url) }
        isPlaying = false
        currentTime = 0
        stopTimer()
        updateNowPlayingInfo()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio decode error: \(error?.localizedDescription ?? "Unknown error")")
        stop()
    }
    
    func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        pause()
    }
    
    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        if flags == AVAudioSession.InterruptionOptions.shouldResume.rawValue {
            play()
        }
    }
}

// MARK: - Errors

// The error messages the player can show. errorDescription is the plain text
// a user would see.
enum AudioPlayerError: LocalizedError {
    case invalidURL
    case loadFailed
    case playbackFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid audio URL"
        case .loadFailed:
            return "Failed to load audio"
        case .playbackFailed:
            return "Failed to play audio"
        }
    }
}
