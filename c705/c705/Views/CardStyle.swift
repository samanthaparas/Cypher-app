//
//  CardStyle.swift
//  c705
//
//  The mockup's card look as a reusable style:
//  dark surface, rounded corners, subtle outline.
//  Usage: SomeView().themeCard()
//

import SwiftUI

struct CardStyle: ViewModifier {
    var padding: CGFloat = Theme.spacing

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