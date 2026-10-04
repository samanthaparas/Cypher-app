//
//  CypherTabBar.swift
//  c705
//
//  Custom bottom tab bar styled with Theme tokens.
//  Matches docs/design/cypher-app-mockup.png
//

import SwiftUI

struct CypherTabBar: View {
    @Binding var selectedTab: Int

    private let items: [TabItem] = [
        TabItem(tag: 0, title: "Home",     icon: "house.fill"),
        TabItem(tag: 1, title: "Discover", icon: "magnifyingglass"),
        TabItem(tag: 2, title: "Arena",    icon: "mic.fill", isRaised: true),
        TabItem(tag: 3, title: "Beats",    icon: "music.note"),
        TabItem(tag: 4, title: "Profile",  icon: "person.fill"),
    ]

    var body: some View {
        HStack {
            ForEach(items) { item in
                tabButton(for: item)
            }
        }
        .padding(.horizontal, Theme.spacing)
        .padding(.top, Theme.spacingSmall)
        .padding(.bottom, Theme.spacingSmall)
        .background(Theme.card.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Theme.cardBorder.frame(height: 1)
        }
    }

    private func tabButton(for item: TabItem) -> some View {
        let isSelected = selectedTab == item.tag
        let tint = isSelected ? Theme.accent : Theme.textSecondary

        return Button {
            selectedTab = item.tag
        } label: {
            VStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.system(size: item.isRaised ? 22 : 20, weight: .semibold))
                    .foregroundStyle(item.isRaised ? Color.white : tint)
                    .frame(height: 24)
                    .background {
                        if item.isRaised {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 52, height: 52)
                                .shadow(color: Theme.accent.opacity(0.6),
                                        radius: isSelected ? 12 : 6)
                        }
                    }
                    .offset(y: item.isRaised ? -16 : 0)

                Text(item.title)
                    .font(.caption2)
                    .foregroundStyle(tint)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct TabItem: Identifiable {
    let tag: Int
    let title: String
    let icon: String
    var isRaised: Bool = false

    var id: Int { tag }
}

#Preview {
    VStack {
        Spacer()
        CypherTabBar(selectedTab: .constant(2))
    }
    .background(Theme.background)
}