//
//  LikeButtonView.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The small heart-and-count button used on tracks. It shows whether
//  you liked the track and how many likes it has, and handles taps
//  through LikeViewModel.
//

import SwiftUI

struct LikeButtonView: View {
    let trackId: String
    let initialLikeCount: Int
    let initialIsLiked: Bool
    
    // Each button owns its own LikeViewModel. @StateObject keeps it alive when the screen
    // redraws.
    @StateObject private var viewModel: LikeViewModel
    
    // Needed because the view model must be built with the track's id and current numbers
    // before the button appears.
    init(trackId: String, likeCount: Int, isLiked: Bool = false) {
        self.trackId = trackId
        self.initialLikeCount = likeCount
        self.initialIsLiked = isLiked
        _viewModel = StateObject(wrappedValue: LikeViewModel(
            trackId: trackId,
            initialLikeCount: likeCount,
            initialIsLiked: isLiked
        ))
    }
    
    // A red filled heart when liked, an outline when not. The button dims and ignores taps
    // while a like is being sent.
    var body: some View {
        Button(action: {
            Task {
                await viewModel.toggleLike()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                    .foregroundColor(viewModel.isLiked ? .red : .secondary)
                    .font(.system(size: 16))
                
                Text("\(viewModel.likeCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .disabled(viewModel.isLoading)
        .opacity(viewModel.isLoading ? 0.6 : 1.0)
    }
}

// Previews only show in Xcode's canvas while designing. They are not part of the running app.
#Preview {
    HStack {
        LikeButtonView(trackId: "1", likeCount: 42, isLiked: false)
        LikeButtonView(trackId: "2", likeCount: 100, isLiked: true)
    }
    .padding()
}

