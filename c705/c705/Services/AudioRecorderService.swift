//
//  AudioRecorderService.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The one microphone recorder the whole app shares. It asks for
//  microphone permission, records up to 60 seconds to a file on the
//  phone, and reports the time so screens can show it.
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
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
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
            return await AVAudioApplication.requestRecordPermission()
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
    
    // MARK: - Recording
    
    // Starts recording. It checks permission first, switches the audio session to record mode,
    // and saves AAC audio (a compact format) to a new .m4a file in the app's documents folder.
    func startRecording() throws {
        guard hasPermission else {
            throw AudioRecorderError.permissionDenied
        }
        
        // Configure audio session for recording
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true)
        
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
        audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.record()
        
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
        
        let audioURL = recorder.url
        
        // Deactivate audio session
        try? audioSession.setActive(false)
        
        audioRecorder = nil
        
        return audioURL
    }
    
    // Stops and deletes the recording, for when the user backs out.
    func cancelRecording() {
        guard let recorder = audioRecorder, isRecording else {
            return
        }
        
        recorder.stop()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Delete the file
        try? FileManager.default.removeItem(at: recorder.url)
        
        // Deactivate audio session
        try? audioSession.setActive(false)
        
        audioRecorder = nil
    }
    
    // MARK: - Get Recording Data
    
    // Reads the finished recording into memory so it can be uploaded.
    func getRecordingData() -> Data? {
        guard let recorder = audioRecorder, !isRecording else {
            return nil
        }
        
        return try? Data(contentsOf: recorder.url)
    }
    
    func getRecordingURL() -> URL? {
        guard let recorder = audioRecorder, !isRecording else {
            return nil
        }
        
        return recorder.url
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
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required to record audio"
        case .recordingFailed:
            return "Failed to start recording"
        case .fileNotFound:
            return "Recording file not found"
        }
    }
}

