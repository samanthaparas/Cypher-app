//
//  CommentsView.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The comments screen for a track: a scrolling list of comments with
//  a box at the bottom to write a new one. Today it is only opened
//  from the feed item card.
//

import SwiftUI

struct CommentsView: View {
    let trackId: String
    // This screen owns its own CommentsViewModel, built for one specific track.
    @StateObject private var viewModel: CommentsViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Builds the view model with the track's id before the screen appears.
    init(trackId: String) {
        self.trackId = trackId
        _viewModel = StateObject(wrappedValue: CommentsViewModel(trackId: trackId))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Comments List
                // If there are no comments (and nothing is loading), show an encouraging empty
                // message. Otherwise show the list.
                if viewModel.comments.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No comments yet")
                            .foregroundColor(.secondary)
                        Text("Be the first to comment!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.comments) { comment in
                                CommentRowView(comment: comment)
                            }
                            
                            // At the bottom of the list: a spinner while more load, or a Load
                            // More button if there are more pages.
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .padding()
                            } else if viewModel.hasMoreComments {
                                Button("Load More Comments") {
                                    Task {
                                        await viewModel.loadMoreComments()
                                    }
                                }
                                .padding()
                            }
                        }
                        .padding()
                    }
                }
                
                // Comment Input
                Divider()
                HStack(spacing: 12) {
                    // The text box grows up to 4 lines. $ means the box and the view model
                    // share the same text.
                    TextField("Add a comment...", text: $viewModel.newCommentText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                    
                    Button(action: {
                        Task {
                            await viewModel.postComment()
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(viewModel.newCommentText.isEmpty ? .gray : .blue)
                    }
                    .disabled(viewModel.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isPosting)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            // Loads the comments when the screen first appears.
            .task {
                await viewModel.loadComments()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

// One comment: a circle with the author's first letter, their name, the text, and how long ago.
struct CommentRowView: View {
    let comment: Comment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User Avatar
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String((comment.user?.email.prefix(1) ?? "U").uppercased()))
                        .font(.caption)
                        .foregroundColor(.blue)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // User name
                Text(comment.user?.email ?? "Unknown User")
                    .font(.subheadline)
                    .bold()
                
                // Comment text
                Text(comment.content)
                    .font(.body)
                
                // Timestamp
                Text(formatDate(comment.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // Turns the server's date text into short relative wording like "5m". If it cannot be read
    // it shows the original text.
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = RelativeDateTimeFormatter()
            displayFormatter.unitsStyle = .abbreviated
            return displayFormatter.localizedString(for: date, relativeTo: Date())
        }
        return dateString
    }
}

#Preview {
    CommentsView(trackId: "track-id")
}

