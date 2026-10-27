//
//  RecordCypherView.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The recording screen for a cypher entry. The user gives it an
//  optional title, taps Record, gets a 3-2-1 countdown, records up to
//  60 seconds, then submits the entry to the server.
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
    // Whether the 3-2-1 countdown is showing, and the number currently displayed.
    @State private var showCountdown = false
    @State private var countdownValue = 3
    
    private let apiService = APIService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Recording Status
                VStack(spacing: 16) {
                    // The screen shows one of three things: the countdown, the recording
                    // indicator, or the ready-to-record state.
                    if showCountdown {
                        // Countdown View
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 120, height: 120)
                            
                            Text("\(countdownValue)")
                                .font(.system(size: 60, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        
                        Text("Get ready...")
                            .font(.headline)
                            .foregroundColor(.orange)
                    } else if recorder.isRecording {
                        // Recording Indicator
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
                        
                        Text(timeString(recorder.recordingTime))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("Max: 60 seconds")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        // Ready to Record
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "mic.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        }
                        
                        Text("Ready to Record")
                            .font(.headline)
                            .foregroundColor(.black)
                    }
                }
                .padding(.top, 40)
                
                // Title Input (Optional)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Entry Title (Optional)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField("My Cypher Entry", text: $entryTitle)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
                // Controls
                HStack(spacing: 40) {
                    if recorder.isRecording {
                        Button(action: {
                            _ = recorder.stopRecording()
                            // Recording stopped, ready to upload
                        }) {
                            VStack {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.red)
                                Text("Stop")
                                    .font(.caption)
                            }
                        }
                    } else {
                        Button(action: {
                            startCountdown()
                        }) {
                            VStack {
                                Image(systemName: "record.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.red)
                                Text("Record")
                                    .font(.caption)
                            }
                        }
                        .disabled(!recorder.hasPermission)
                    }
                }
                .padding()
                
                // Upload Button
                if !recorder.isRecording, recorder.getRecordingURL() != nil {
                    Button(action: {
                        Task {
                            if let audioURL = recorder.getRecordingURL() {
                                await uploadRecording(audioURL: audioURL)
                            }
                        }
                    }) {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                            }
                            Text(isUploading ? "Uploading..." : "Submit Entry")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isUploading ? Color.gray : Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(isUploading)
                    .padding(.horizontal)
                    
                    if isUploading {
                        ProgressView(value: uploadProgress)
                            .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
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
            // When the screen opens, ask for microphone permission if it has not been given. An
            // error is shown if the user says no.
            .task {
                if !recorder.hasPermission {
                    let granted = await recorder.requestPermission()
                    if !granted {
                        errorMessage = "Microphone permission is required to record"
                        showError = true
                    }
                }
            }
        }
    }
    
    private func timeString(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Counts down from 3, one number per second, then starts recording by itself.
    private func startCountdown() {
        showCountdown = true
        countdownValue = 3
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdownValue -= 1
            
            if countdownValue <= 0 {
                timer.invalidate()
                showCountdown = false
                
                // Start recording after countdown
                do {
                    try recorder.startRecording()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
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
            
            dismiss()
        } catch {
            errorMessage = "Failed to upload: \(error.localizedDescription)"
            showError = true
            isUploading = false
        }
    }
}

