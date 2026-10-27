//
//  CardStyle.swift
//  c705
//
//  The mockup's card look as a reusable style:
//  dark surface, rounded corners, subtle outline.
//  Usage: SomeView().themeCard()
//
//  PURPOSE: The reusable look for a card: dark background, rounded corners and
//  a thin outline. Any view becomes a card by adding .themeCard(), so
//  cards stay consistent.
//

import SwiftUI

// A ViewModifier is a bundle of styling that can be applied to any view.
struct CardStyle: ViewModifier {
    var padding: CGFloat = Theme.spacing

    // Takes the view being styled (content) and wraps it with padding, a background and a
    // border.
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
    }
}

// An extension adds a new method to every view, giving us the short .themeCard() shortcut.
extension View {
    /// Wraps the view in the standard Cypher card look.
    func themeCard(padding: CGFloat = Theme.spacing) -> some View {
        modifier(CardStyle(padding: padding))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        Text("Weekly Cypher")
            .font(.headline)
            .foregroundColor(Theme.textPrimary)
        Text("Post your best 16 bars")
            .foregroundColor(Theme.textSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .themeCard()
    .padding()
    .background(Theme.background)
}