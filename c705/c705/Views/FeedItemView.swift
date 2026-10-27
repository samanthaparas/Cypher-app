//
//  FeedItemView.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: How one item in the feed is drawn. A feed holds two kinds of item,
//  tracks and articles, so this file has a wrapper that picks the
//  right card for each. Right now only the preview at the bottom uses it,
//  because Home shows the Trending, Articles, Events and City tabs instead
//  of a mixed feed.
//

import SwiftUI

// The outer card. It checks the item's type and shows a track card or an article card inside
// the same rounded shape.
struct FeedItemView: View {
    let item: FeedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if item.type == .track {
                TrackFeedItemView(item: item)
            } else {
                ArticleFeedItemView(item: item)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// A track card: title, artist link, an audio player, like and comment buttons, and how long ago
// it was posted.
struct TrackFeedItemView: View {
    let item: FeedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and artist
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let artist = item.artist {
                        NavigationLink(destination: ArtistProfileView(artistId: artist.id)) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.circle.fill")
                                    .font(.caption)
                                Text(artist.user?.email ?? "Unknown Artist")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            
            // Audio Player
            if let audioUrl = item.audioUrl {
                // A feed item is not a full Track, so a Track is assembled from its fields to
                // give the player what it needs.
                CompactAudioPlayerView(track: Track(
                    id: item.id,
                    title: item.title,
                    audioUrl: audioUrl,
                    artistId: item.artist?.id ?? "",
                    likeCount: item.likeCount ?? 0,
                    createdAt: item.createdAt,
                    artist: item.artist,
                    isLiked: item.isLiked
                ))
            }
            
            // Engagement buttons
            HStack(spacing: 20) {
                // Like Button
                LikeButtonView(
                    trackId: item.id,
                    likeCount: item.likeCount ?? 0,
                    isLiked: item.isLiked ?? false
                )
                
                // Comment Button
                NavigationLink(destination: CommentsView(trackId: item.id)) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Timestamp
                Text(formatDate(item.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // Turns the server's date text into short relative wording like "2h". If the date cannot be
    // read it shows the original text.
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

// An article card: title, a three-line preview, the city, and the author.
struct ArticleFeedItemView: View {
    let item: FeedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(item.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Content preview
            if let content = item.content {
                Text(content)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            // Metadata
            HStack {
                if let city = item.city {
                    Label(city, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let author = item.author {
                    Text("by \(author.email)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formatDate(item.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // The same date helper again. This copy and the one above are identical and could be
    // shared.
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
    ScrollView {
        LazyVStack {
            FeedItemView(item: FeedItem(
                id: "1",
                type: .track,
                title: "Sample Track",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                audioUrl: "https://example.com/audio.mp3",
                likeCount: 42,
                isLiked: false,
                artist: nil,
                content: nil,
                city: nil,
                author: nil
            ))
        }
        .padding()
    }
}

