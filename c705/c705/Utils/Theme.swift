//
//  Theme.swift
//  c705
//
//  Central design tokens: colors, spacing, and shape values.
//  Source of truth: docs/design/cypher-app-mockup.png
//
//  PURPOSE: The app's single source for colors, spacing and corner sizes.
//  Screens ask Theme for a value instead of typing their own, so the
//  whole look can change by editing this one file.
//

import SwiftUI

// An enum with only fixed values (no cases) is a simple container that cannot be created by
// accident.
enum Theme {
    // MARK: - Colors
    // Colors are named by their job (background, card, accent), not by their color, so a future
    // redesign does not need renames.
    static let background    = Color(hex: 0x0A0F1A) // app background, near-black navy
    static let card          = Color(hex: 0x131B2B) // card surface, slightly lighter
    static let cardBorder    = Color(hex: 0x24304A) // subtle outline on cards
    static let accent = Color(hex: 0x2F7BFF) // electric blue
    static let textPrimary   = Color.white
    static let textSecondary = Color(hex: 0x9AA6BD) // muted blue-gray

    // Standard gaps between things, so spacing looks the same on every screen.
    // MARK: - Spacing
    static let spacingSmall: CGFloat  = 8
    static let spacing: CGFloat       = 12
    static let spacingLarge: CGFloat  = 20

    // MARK: - Shape
    static let cardRadius: CGFloat   = 16
    static let buttonRadius: CGFloat = 10
}

// Shortcut so every screen gets the mockup's navy background the same way (cards use
// .themeCard() from CardStyle.swift).
// MARK: - View helpers
extension View {
    /// The navy app background behind a whole screen. scrollContentBackground(.hidden) removes
    /// the gray that Lists and Forms draw by default, so the navy shows through.
    func themedScreen() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
    }
}

// Lets code write a color the way designers do, as a hex code like 0x2F7BFF.
// MARK: - Hex color helper
extension Color {
    /// Lets us write Color(hex: 0x4D8DFF) instead of three 0-1 decimals.
    // A hex code packs red, green and blue into one number. This splits it apart and converts
    // each part to the 0 to 1 scale SwiftUI uses.
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