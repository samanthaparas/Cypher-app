//
//  PillButton.swift
//  c705
//
//  The single rounded "pill" button used for sub-navigation and filters
//  (Trending: Beats/Cyphers, Articles: sources, City: city names).
//

import SwiftUI

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
                .background(isSelected ? Theme.accent : Theme.card, in: Capsule())
                .scaleEffect(isSelected ? 1.0 : 0.95)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(AppAnimations.quickSpring, value: isSelected)
    }
}

#Preview {
    HStack(spacing: 12) {
        PillButton(title: "Beats", isSelected: true) {}
        PillButton(title: "Cyphers", isSelected: false) {}
    }
    .padding()
    .background(Theme.background)
}