//
//  PillButton.swift
//  c705
//
//  The single rounded "pill" button used for sub-navigation and filters
//  (Trending: Beats/Cyphers, Articles: sources, City: city names).
//
//  PURPOSE: The one rounded pill button used for filters and sub-tabs (Beats
//  and Cyphers, article sources, city names). It replaced three nearly
//  identical copies, so a change here updates every pill in the app.
//

import SwiftUI

// Each pill is given its text, whether it is the selected one, and what to do when tapped.
struct PillButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                // The selected pill is blue and the others are dark. Capsule() is the rounded
                // pill shape.
                .background(isSelected ? Theme.accent : Theme.card, in: Capsule())
                .scaleEffect(isSelected ? 1.0 : 0.95)
        }
        .buttonStyle(PlainButtonStyle())
        // Animates the change when a pill becomes selected or unselected.
        .animation(AppAnimations.quickSpring, value: isSelected)
    }
}

// Previews only show up in Xcode's canvas to help while designing. They are not part of the
// running app.
#Preview {
    HStack(spacing: 12) {
        PillButton(title: "Beats", isSelected: true) {}
        PillButton(title: "Cyphers", isSelected: false) {}
    }
    .padding()
    .background(Theme.background)
}