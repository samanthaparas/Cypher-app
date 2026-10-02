//
//  Theme.swift
//  c705
//
//  Central design tokens: colors, spacing, and shape values.
//  Source of truth: docs/design/cypher-app-mockup.png
//

import SwiftUI

enum Theme {
    // MARK: - Colors
    static let background    = Color(hex: 0x0A0F1A) // app background, near-black navy
    static let card          = Color(hex: 0x131B2B) // card surface, slightly lighter
    static let cardBorder    = Color(hex: 0x24304A) // subtle outline on cards
    static let accent = Color(hex: 0x2F7BFF) // electric blue
    static let textPrimary   = Color.white
    static let textSecondary = Color(hex: 0x9AA6BD) // muted blue-gray

    // MARK: - Spacing
    static let spacingSmall: CGFloat  = 8
    static let spacing: CGFloat       = 12
    static let spacingLarge: CGFloat  = 20

    // MARK: - Shape
    static let cardRadius: CGFloat   = 16
    static let buttonRadius: CGFloat = 10
}

// MARK: - Hex color helper
extension Color {
    /// Lets us write Color(hex: 0x4D8DFF) instead of three 0-1 decimals.
    init(hex: UInt32) {
        let red   = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue  = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: Theme.spacing) {
        swatch("background", Theme.background)
        swatch("card", Theme.card)
        swatch("accent", Theme.accent)
        swatch("textSecondary", Theme.textSecondary)
    }
    .padding(Theme.spacingLarge)
    .background(Theme.background)
}

private func swatch(_ name: String, _ color: Color) -> some View {
    RoundedRectangle(cornerRadius: Theme.cardRadius)
        .fill(color)
        .frame(height: 50)
        .overlay(Text(name).foregroundStyle(.white))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
}