//
//  BeatDetailView.swift
//  c705
//
//  Created for Beats feature
//
//  PURPOSE: The detail screen for one beat: its info, a preview player, a
//  Purchase button, and a Report option. It also holds the purchase
//  sheet and the report sheet. Playback and real purchasing are not
//  finished yet (see the TODOs).
//

import SwiftUI
import StoreKit

// Opened from a beat card. It is given the Beat to show.
struct BeatDetailView: View {
    let beat: Beat
    @EnvironmentObject var authService: AuthService
    // Apple's in-app purchase helper. It is created here so the purchase sheet can use it.
    @StateObject private var iapManager = IAPManager()
    @State private var isPlaying = false
    @State private var showPurchaseSheet = false
    @State private var showReportSheet = false
    @State private var errorMessage: String?
    @State private var showError = false
    // The link to the full-length beat. It stays empty until the server confirms this user owns
    // the beat.
    @State private var fullBeatUrl: String?
    @State private var isLoadingFullBeat = false
    
    var isPurchased: Bool {
        beat.isPurchased == true || fullBeatUrl != nil
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Beat info header
                VStack(alignment: .leading, spacing: 12) {
                    Text(beat.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    
                    if let producer = beat.producer {
                        Text("by \(producer.username ?? producer.email)")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Preview player
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal)
                    
                    // Preview player placeholder
                    HStack {
                        Button(action: {
                            // TODO: Implement audio playback
                            isPlaying.toggle()
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("20-30 second preview")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                            Text("Tap to play preview")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Theme.card)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Beat details
                VStack(alignment: .leading, spacing: 16) {
                    DetailRow(label: "Genre", value: beat.genre)
                    DetailRow(label: "BPM", value: "\(beat.bpm)")
                    if let mood = beat.mood {
                        DetailRow(label: "Mood", value: mood)
                    }
                    DetailRow(label: "Price", value: formatPrice(beat.price))
                }
                .padding(.horizontal)
                
                // Purchase section
                if !isPurchased {
                    VStack(spacing: 12) {
                        Button(action: {
                            showPurchaseSheet = true
                        }) {
                            HStack {
                                Spacer()
                                Text("Purchase Beat")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // License disclosure
                        Text("Purchasing a beat grants a license as defined by the producer. Copyright ownership remains with the producer.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 12) {
                        if isLoadingFullBeat {
                            ProgressView("Loading full beat...")
                                .padding()
                        } else if fullBeatUrl != nil {
                            // Full beat player
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Full Beat")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Theme.textPrimary)
                                
                                HStack {
                                    Button(action: {
                                        // TODO: Implement full beat playback using fullBeatUrl
                                        isPlaying.toggle()
                                    }) {
                                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(.green)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Full version unlocked")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Theme.textPrimary)
                                        Text("Tap to play full beat")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        
                        Button(action: {
                            Task {
                                await loadFullBeat()
                            }
                        }) {
                            HStack {
                                Spacer()
                                Text("Load Full Beat")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Report button
                Button(action: {
                    showReportSheet = true
                }) {
                    HStack {
                        Spacer()
                        Text("Report Beat")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 40)
        }
        .themedScreen()
        .navigationTitle("Beat Details")
        .navigationBarTitleDisplayMode(.inline)
        // Slides up the purchase screen.
        .sheet(isPresented: $showPurchaseSheet) {
            PurchaseBeatView(beat: beat, iapManager: iapManager)
        }
        // Slides up the form to report this beat.
        .sheet(isPresented: $showReportSheet) {
            ReportBeatView(beat: beat)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }
    
    // Prices are stored in cents. This turns 999 into $9.99.
    private func formatPrice(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return String(format: "$%.2f", dollars)
    }
    
    // Asks the server for the full beat's link. The server only allows it if the user has
    // bought the beat.
    private func loadFullBeat() async {
        isLoadingFullBeat = true
        errorMessage = nil
        
        do {
            let url = try await APIService.shared.getFullBeatUrl(beatId: beat.id)
            fullBeatUrl = url
        } catch {
            errorMessage = "Failed to load full beat: \(error.localizedDescription)"
            showError = true
        }
        
        isLoadingFullBeat = false
    }
}

// One label and value line in the beat's details.
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(Theme.textPrimary)
        }
    }
}

// The purchase sheet: shows the price and what the buyer gets, with a Buy button.
struct PurchaseBeatView: View {
    let beat: Beat
    @ObservedObject var iapManager: IAPManager
    @Environment(\.dismiss) var dismiss
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text(beat.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(formatPrice(beat.price))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.blue)
                }
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("What you get:")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    
                    FeatureRow(text: "Full beat download")
                    FeatureRow(text: "Lease license (non-exclusive)")
                    FeatureRow(text: "High-quality audio file")
                }
                .padding()
                .background(Theme.card)
                .cornerRadius(12)
                .padding(.horizontal)
                
                // License disclosure
                Text("Purchasing a beat grants a license as defined by the producer. Copyright ownership remains with the producer.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await purchaseBeat()
                    }
                }) {
                    HStack {
                        Spacer()
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Purchase with Apple Pay")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(isPurchasing ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isPurchasing)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .themedScreen()
            .navigationTitle("Purchase Beat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }
    
    // The same price helper again. It is repeated from the beat screen above.
    private func formatPrice(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return String(format: "$%.2f", dollars)
    }
    
    // Sends the purchase to the server. It currently sends a made-up placeholder receipt
    // instead of a real Apple one, so the server would record a purchase with no payment. Real
    // StoreKit buying must replace this before beats are sold.
    private func purchaseBeat() async {
        isPurchasing = true
        errorMessage = nil
        
        do {
            // TODO: Implement actual IAP purchase flow
            // For now, this is a placeholder
            // In production, you would:
            // 1. Request product from StoreKit
            // 2. Initiate purchase
            // 3. Get receipt
            // 4. Send receipt to backend
            
            // Placeholder receipt
            let receipt = "placeholder_receipt_\(UUID().uuidString)"
            
            let _ = try await APIService.shared.purchaseBeat(beatId: beat.id, receipt: receipt)
            
            dismiss()
        } catch {
            errorMessage = "Failed to purchase beat: \(error.localizedDescription)"
            showError = true
        }
        
        isPurchasing = false
    }
}

// One bullet in the list of what the buyer gets.
struct FeatureRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Theme.textPrimary)
        }
    }
}

// The sheet for reporting a beat. The user types a reason and submits it.
struct ReportBeatView: View {
    let beat: Beat
    @Environment(\.dismiss) var dismiss
    @State private var reason = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Why are you reporting this beat?")) {
                    TextEditor(text: $reason)
                        .frame(minHeight: 100)
                }
            }
            .themedScreen()
            .navigationTitle("Report Beat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        Task {
                            await submitReport()
                        }
                    }
                    .disabled(reason.count < 10 || isSubmitting)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Beat reported successfully. Our team will review it.")
            }
        }
    }
    
    // Sends the report to the server, then shows a success message or an error.
    private func submitReport() async {
        guard reason.count >= 10 else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        do {
            try await APIService.shared.reportBeat(beatId: beat.id, reason: reason)
            showSuccess = true
        } catch {
            errorMessage = "Failed to report beat: \(error.localizedDescription)"
            showError = true
        }
        
        isSubmitting = false
    }
}

