//
//  TopCypherCardView.swift
//  c705
//
//  Created for Top Cypher card display
//
//  PURPOSE: Two ways to draw a top cypher: a wide card for horizontal scrolling
//  and a compact row for lists. Neither is used anywhere right now
//  (the Arena uses PopularCypherCardView instead), so they can likely
//  be removed.
//

import SwiftUI

// A 280-point wide card with a score badge, title, host and counts of entries, votes and
// artists.
struct TopCypherCardView: View {
    let topCypher: TopCypher
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Score Badge
                HStack {
                    Spacer()
                    Text("Score: \(topCypher.score)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
                
                Text(topCypher.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                
                if let description = topCypher.description {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                // Host Info
                HStack {
                    Text("Host: \(topCypher.host.username ?? topCypher.host.email)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                }
                
                // Stats
                HStack(spacing: 16) {
                    Label("\(topCypher.entryCount)", systemImage: "person.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Label("\(topCypher.voteCount)", systemImage: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Label("\(topCypher.uniqueArtists)", systemImage: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .frame(width: 280)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// A shorter row version: score on the left, title and host on the right.
struct TopCypherRowView: View {
    let topCypher: TopCypher
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Score Badge
                VStack {
                    Text("\(topCypher.score)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("pts")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(width: 50)
                .padding(.vertical, 8)
                .background(Color.orange)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(topCypher.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    Text("Host: \(topCypher.host.username ?? topCypher.host.email)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 12) {
                        Label("\(topCypher.entryCount)", systemImage: "person.2.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        
                        Label("\(topCypher.voteCount)", systemImage: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

