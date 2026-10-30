//
//  AudioRecorderService.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The one microphone recorder the whole app shares. It asks for
//  microphone permission, loops the chosen beat as a preview, runs the
//  3-2-1 countdown, records up to 60 seconds to a file on the phone with
//  the beat restarted from the top, and reports the time so screens can
//  show it.
//

import Foundation
import AVFoundation
import Combine

// @Published values below (recording or not, elapsed time, permission) redraw any screen
// watching them, the same way the audio player does.
class AudioRecorderService: NSObject, ObservableObject {
    static let shared = AudioRecorderService()
    
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var hasPermission = false
    // The beat that plays under the take. It loops so the artist can catch the vibe first.
    @Published var isBeatLoaded = false
    @Published var isBeatPlaying = false
    // The number showing during the 3-2-1 countdown, or nil when no countdown is running.
    @Published var countdownValue: Int?
    // The last finished take, already lined up with the beat. It stays after Stop so a screen
    // can play it back and offer Retake or Use This Take.
    @Published private(set) var lastRecordingURL: URL?
    // True for the moment after Stop while the take is being lined up with the beat.
    @Published private(set) var isAligningTake = false
    
    private var audioRecorder: AVAudioRecorder?
    private var beatPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var countdownTimer: Timer?
    // How late the voice lands in the file compared with the beat the artist heard: the time
    // the beat takes to reach their ears plus the time their voice takes to reach the file.
    // Wireless headphones make this much bigger. Measured when the take starts.
    private var takeLatency: TimeInterval = 0
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    // Maximum recording length in seconds (60 seconds for cyphers)
    // The longest a cypher entry can be. The recorder stops by itself when it is reached.
    let maxRecordingLength: TimeInterval = 60.0
    
    private override init() {
        super.init()
        checkPermission()
    }
    
    // MARK: - Permission Check
    
    // Looks up whether the user already allowed microphone access. iOS 17 changed the way to
    // ask, so there are two versions.
    func checkPermission() {
        if #available(iOS 17.0, *) {
            hasPermission = AVAudioApplication.shared.recordPermission == .granted
        } else {
            let status = audioSession.recordPermission
            hasPermission = status == .granted
        }
    }
    
    // Shows the iOS pop-up asking to use the microphone and returns true if the user allows it.
    func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            // Save the answer too, or the Record button stays disabled after the user taps Allow.
            let granted = await AVAudioApplication.requestRecordPermission()
            await MainActor.run { self.hasPermission = granted }
            return granted
        } else {
            return await withCheckedContinuation { continuation in
                audioSession.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        self.hasPermission = granted
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
    
    // MARK: - Beat
    
    // Loads the beat from a file on the phone or a web link and sets it to loop forever.
    // It does not start playing; the screen's play button does that.
    @MainActor
    func loadBeat(from url: URL) async throws {
        unloadBeat()
        // Only one thing plays at a time, so pause any entry or track that was playing.
        AudioPlayerService.shared.pause()
        
        let data: Data
        if url.isFileURL {
            data = try Data(contentsOf: url)
        } else {
            let (downloaded, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw AudioRecorderError.beatLoadFailed
            }
            data = downloaded
        }
        
        try configureSessionForRecording()
        let player = try AVAudioPlayer(data: data)
        player.numberOfLoops = -1 // -1 means repeat until stopped
        player.prepareToPlay()
        beatPlayer = player
        isBeatLoaded = true
    }
    
    // Play/pause for the beat preview. It does nothing mid-take, since the beat must keep time.
    func toggleBeatPreview() {
        guard let player = beatPlayer, !isRecording, countdownValue == nil,
              !isAligningTake, lastRecordingURL == nil else { return }
        if player.isPlaying {
            player.pause()
        } else {
            try? audioSession.setActive(true)
            player.play()
        }
        isBeatPlaying = player.isPlaying
    }
    
    // Stops and forgets the beat, and puts the audio session back to normal playback. Screens
    // call this when they close.
    func unloadBeat() {
        beatPlayer?.stop()
        beatPlayer = nil
        isBeatLoaded = false
        isBeatPlaying = false
        guard !isRecording else { return }
        try? audioSession.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP])
    }
    
    // Record mode that still plays out loud. A2DP lets wireless headphones play the beat in
    // full quality while the phone's own mic records.
    private func configureSessionForRecording() throws {
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try audioSession.setActive(true)
    }
    
    // MARK: - Countdown
    
    // Starts a take. With countdown on, it counts 3-2-1 with the beat playing, then records.
    // With countdown off (the Instant option), it records right away. onError reports a
    // failure that happens after the countdown, when the caller is no longer waiting.
    func beginTake(countdown: Bool, onError: @escaping (Error) -> Void) {
        guard !isRecording, countdownValue == nil else { return }
        
        guard countdown else {
            do { try startRecording() } catch { onError(error) }
            return
        }
        
        if let player = beatPlayer, !player.isPlaying {
            try? audioSession.setActive(true)
            player.play()
            isBeatPlaying = true
        }
        countdownValue = 3
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, let value = self.countdownValue else {
                timer.invalidate()
                return
            }
            if value > 1 {
                self.countdownValue = value - 1
            } else {
                timer.invalidate()
                self.countdownTimer = nil
                self.countdownValue = nil
                do { try self.startRecording() } catch { onError(error) }
            }
        }
    }
    
    // Stops a countdown before recording starts. The beat keeps looping.
    func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownValue = nil
    }
    
    // Forgets the last take without deleting its file. Screens call this when they open, so
    // a take from another screen does not show up as ready to submit.
    func clearLastRecording() {
        lastRecordingURL = nil
    }
    
    // MARK: - Recording
    
    // Starts recording. It checks permission first, switches the audio session to record mode,
    // and saves AAC audio (a compact format) to a new .m4a file in the app's documents folder.
    // If a beat is loaded, it restarts from the top on the same audio-clock tick as the mic, so
    // the vocal lines up with bar 1 when they are played together.
    func startRecording() throws {
        guard hasPermission else {
            throw AudioRecorderError.permissionDenied
        }
        
        // Stop any listen-back first. This must come before the session setup below: the first
        // use of the shared player sets the session to playback-only, which would block the mic.
        AudioPlayerService.shared.stop()
        try configureSessionForRecording()
        lastRecordingURL = nil
        
        // Get documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("cypher-recording-\(Date().timeIntervalSince1970).m4a")
        
        // Audio settings for AAC compression
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        
        // Create recorder
        let recorder = try AVAudioRecorder(url: audioFilename, settings: settings)
        recorder.delegate = self
        recorder.prepareToRecord()
        audioRecorder = recorder
        
        if let beat = beatPlayer {
            beat.stop()
            beat.currentTime = 0
            beat.prepareToPlay()
            // A short lead gives both a moment to get ready, then they start together.
            let lead: TimeInterval = 0.1
            beat.play(atTime: beat.deviceCurrentTime + lead)
            recorder.record(atTime: recorder.deviceCurrentTime + lead)
            isBeatPlaying = true
            takeLatency = audioSession.outputLatency + audioSession.inputLatency
        } else {
            recorder.record()
            takeLatency = 0
        }
        
        isRecording = true
        recordingTime = 0
        
        // Start timer
        // Ticks every 0.1 seconds to update the elapsed time and to stop automatically at the
        // maximum length.
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingTime += 0.1
            
            // Auto-stop at max length
            if self.recordingTime >= self.maxRecordingLength {
                self.stopRecording()
            }
        }
    }
    
    @discardableResult
    // Finishes the recording and returns where the file was saved. @discardableResult just
    // means callers may ignore that return value.
    func stopRecording() -> URL? {
        guard let recorder = audioRecorder, isRecording else {
            return nil
        }
        
        recorder.stop()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        stopBeatAfterTake()
        
        let audioURL = recorder.url
        audioRecorder = nil
        
        // Line the take up with the beat, then hand it to the screen for review.
        isAligningTake = true
        let latency = takeLatency
        Task {
            let aligned = await Self.trimStart(of: audioURL, by: latency)
            lastRecordingURL = aligned
            isAligningTake = false
        }
        
        return audioURL
    }
    
    // Cuts `seconds` off the front of a take so the voice sits on the beat. Returns the new
    // file and deletes the old one, or returns the original if there is nothing to trim or
    // trimming fails.
    private static func trimStart(of url: URL, by seconds: TimeInterval) async -> URL {
        guard seconds > 0.005 else { return url }
        
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration),
              duration.seconds > seconds,
              let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            return url
        }
        
        let output = url.deletingPathExtension().appendingPathExtension("aligned.m4a")
        try? FileManager.default.removeItem(at: output)
        export.timeRange = CMTimeRange(start: CMTime(seconds: seconds, preferredTimescale: 44100), end: duration)
        
        do {
            if #available(iOS 18.0, *) {
                try await export.export(to: output, as: .m4a)
            } else {
                export.outputURL = output
                export.outputFileType = .m4a
                await export.export()
                guard export.status == .completed else { return url }
            }
        } catch {
            return url
        }
        
        try? FileManager.default.removeItem(at: url)
        return output
    }
    
    // Throws away the take under review, for Retake.
    func discardLastRecording() {
        AudioPlayerService.shared.stop()
        if let url = lastRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        lastRecordingURL = nil
    }
    
    // Stops the beat and rewinds it, so the next preview starts from the top.
    private func stopBeatAfterTake() {
        beatPlayer?.stop()
        beatPlayer?.currentTime = 0
        isBeatPlaying = false
    }
    
    // Stops any countdown, and stops and deletes a take in progress, for when the user backs
    // out. A finished take is left alone.
    func cancelRecording() {
        cancelCountdown()
        guard let recorder = audioRecorder, isRecording else {
            return
        }
        
        recorder.stop()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        stopBeatAfterTake()
        
        // Delete the file
        try? FileManager.default.removeItem(at: recorder.url)
        
        audioRecorder = nil
    }
    
    // MARK: - Get Recording Data
    
    // Reads the finished recording into memory so it can be uploaded.
    func getRecordingData() -> Data? {
        guard let url = getRecordingURL() else {
            return nil
        }
        
        return try? Data(contentsOf: url)
    }
    
    // Where the last finished take was saved. stopRecording clears audioRecorder, so this
    // reads lastRecordingURL; reading the recorder here made Submit never appear.
    func getRecordingURL() -> URL? {
        guard !isRecording else {
            return nil
        }
        
        return lastRecordingURL
    }
}

// MARK: - AVAudioRecorderDelegate

// A delegate is a helper that Apple's recorder calls back when something happens, such as an
// error.
extension AudioRecorderService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording finished unsuccessfully")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Errors

// The error messages a user can see when recording fails.
enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case recordingFailed
    case fileNotFound
    case beatLoadFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required to record audio"
        case .recordingFailed:
            return "Failed to start recording"
        case .fileNotFound:
            return "Recording file not found"
        case .beatLoadFailed:
            return "Couldn't load the beat"
        }
    }
}

