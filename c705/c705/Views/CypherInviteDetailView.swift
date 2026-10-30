//
//  CypherInviteDetailView.swift
//  c705
//
//  Created for Cypher Invite response view
//
//  PURPOSE: The sheet for a cypher invite: it shows who invited you and lets
//  you accept or decline. At the moment nothing in the app opens it,
//  because the Arena never sets the invite it should show.
//

import SwiftUI

struct CypherInviteDetailView: View {
    let invite: CypherInvite
    // Shares the Arena's view model, so accepting an invite can refresh the Arena's data.
    @ObservedObject var viewModel: CypherHubViewModel
    @Environment(\.dismiss) var dismiss
    // True while a response is being sent, which disables both buttons to prevent double taps.
    @State private var isResponding = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Invite Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You've been invited!")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("\(invite.invitedBy.username ?? invite.invitedBy.email) invited you to join")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .padding()
                    
                    // Cypher Info Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text(invite.cypher.title)
                            .font(.system(size: 20, weight: .bold))
                        
                        Text("Host: \(invite.cypher.host.username ?? invite.cypher.host.email)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Label("\(invite.cypher.entryCount) entries", systemImage: "person.2.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            respondToInvite(response: "accepted")
                        }) {
                            Text("Accept Invite")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                        .disabled(isResponding)
                        
                        Button(action: {
                            respondToInvite(response: "declined")
                        }) {
                            Text("Decline")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                        .disabled(isResponding)
                    }
                    .padding()
                }
            }
            .themedScreen()
            .navigationTitle("Cypher Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Sends "accepted" or "declined" to the server, reloads the Arena, and closes the sheet.
    // Task { } lets this wait on the network without freezing the screen.
    private func respondToInvite(response: String) {
        isResponding = true
        Task {
            do {
                try await APIService.shared.respondToCypherInvite(inviteId: invite.id, response: response)
                await viewModel.loadCyphers() // Reload to update invites
                dismiss()
            } catch {
                print("Error responding to invite: \(error)")
            }
            isResponding = false
        }
    }
}

