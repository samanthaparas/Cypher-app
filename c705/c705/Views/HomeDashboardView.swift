//
//  HomeDashboardView.swift
//  c705
//
//  PURPOSE: The Home tab, laid out like docs/design/cypher-app-mockup.png:
//  the C705 header and tagline, four feature cards that open their tabs,
//  the Feats of the Week banner with the top cypher, and a link to the
//  feed (Trending, Articles, Events, City). Icons and gradients stand in
//  for the mockup's photos until real images exist.
//

import SwiftUI

struct HomeDashboardView: View {
    // The tab bar's selection, shared with MainTabView, so cards can switch tabs.
    @Binding var selectedTab: Int
    @StateObject private var viewModel = HomeDashboardViewModel()
    // Set when the banner's button is tapped, which opens that cypher full screen.
    @State private var selectedCypherId: String?

    // Tab numbers, matching the tags in MainTabView.
    private enum Tab {
        static let discover = 1
        static let arena = 2
        static let beats = 3
        static let profile = 4
    }

    // Two equal columns, like the mockup's card grid.
    private let columns = [
        GridItem(.flexible(), spacing: Theme.spacing),
        GridItem(.flexible(), spacing: Theme.spacing)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLarge) {
                    header

                    LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.spacing) {
                        FeatureCard(
                            title: "Artist Profiles",
                            icon: "music.mic",
                            artIcon: "person.wave.2.fill",
                            gradient: [Color(hex: 0x2F7BFF), Color(hex: 0x6A3DE8)],
                            bullets: ["Upload songs & freestyles", "City-based discovery", "Skill-driven engagement"],
                            buttonTitle: "Upload Freestyle",
                            action: { selectedTab = Tab.arena }
                        )
                        FeatureCard(
                            title: "Producer Beat Store",
                            icon: "slider.horizontal.3",
                            artIcon: "waveform",
                            gradient: [Color(hex: 0x0FB5AE), Color(hex: 0x2F7BFF)],
                            bullets: ["Upload & sell beats", "Browse by vibe, BPM, mood", "Licensing handled directly"],
                            buttonTitle: "Browse Beats",
                            action: { selectedTab = Tab.beats }
                        )
                        FeatureCard(
                            title: "Engineer Hub",
                            icon: "dial.medium",
                            artIcon: "headphones",
                            gradient: [Color(hex: 0x24304A), Color(hex: 0x4A5878)],
                            bullets: ["Find mixing & mastering engineers", "Compare ratings and genres", "Book sessions in the app"],
                            tag: "Coming Soon"
                        )
                        FeatureCard(
                            title: "Freestyle Arena",
                            icon: "flame.fill",
                            artIcon: "mic.fill",
                            gradient: [Color(hex: 0xFF6A3D), Color(hex: 0xE83D8C)],
                            bullets: ["App picks the beat", "Post freestyles, community rates", "Ranked by city, week, theme"],
                            tag: "Signature",
                            buttonTitle: "Enter Arena",
                            action: { selectedTab = Tab.arena }
                        )
                    }

                    FeatsOfTheWeekBanner(
                        cypher: viewModel.topCypher,
                        isThisWeek: viewModel.isThisWeek,
                        isLoading: viewModel.isLoading,
                        onOpen: { selectedCypherId = $0 },
                        onStart: { selectedTab = Tab.arena }
                    )

                    feedLink
                }
                .padding(.horizontal, 16)
                .padding(.bottom, Theme.spacingLarge)
            }
            .themedScreen()
            .toolbar(.hidden, for: .navigationBar)
            // Pull down to reload the banner.
            .refreshable {
                await viewModel.loadTopCypher()
            }
            .task {
                if viewModel.topCypher == nil {
                    await viewModel.loadTopCypher()
                }
            }
            // Opens a cypher full screen, the same way the Arena does.
            .fullScreenCover(item: Binding(
                get: { selectedCypherId.map { CypherNavigation(id: $0) } },
                set: { selectedCypherId = $0?.id }
            )) { nav in
                CypherDetailView(cypherId: nav.id)
            }
        }
    }

    // The logo, the app name, the shortcut icons and the tagline.
    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.accent)
                    .shadow(color: Theme.accent.opacity(0.7), radius: 8)
                Text("C705")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                // The mockup's icon group. Messages is left out until messaging exists.
                HStack(spacing: 4) {
                    headerIcon("magnifyingglass", label: "Discover") { selectedTab = Tab.discover }
                    headerIcon("music.note", label: "Beats") { selectedTab = Tab.beats }
                    headerIcon("person.fill", label: "Profile") { selectedTab = Tab.profile }
                }
                .padding(4)
                .background(Theme.card, in: Capsule())
                .overlay(Capsule().stroke(Theme.cardBorder, lineWidth: 1))
            }

            Text("Connect, Compete & Discover in Hip-Hop's Ultimate Ecosystem")
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.top, Theme.spacing)
    }

    private func headerIcon(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .frame(width: 38, height: 38)
        }
        .accessibilityLabel(label)
    }

    // A card that opens the original Home feed, so nothing from before is lost.
    private var feedLink: some View {
        NavigationLink {
            FeedView()
        } label: {
            HStack(spacing: Theme.spacing) {
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Explore the Feed")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("Trending, Articles, Events & City")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.textSecondary)
            }
            .themeCard(padding: 16)
        }
        .buttonStyle(.plain)
    }
}

// One of the four mockup cards: a title with an icon, a gradient picture area, three bullets
// and an optional button. Leave out buttonTitle for a card with nothing to open yet.
private struct FeatureCard: View {
    let title: String
    let icon: String
    let artIcon: String
    let gradient: [Color]
    let bullets: [String]
    var tag: String? = nil
    var buttonTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title row
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(Theme.accent)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            // Picture area: a gradient with a large glowing icon where the mockup has a photo.
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 76)
                    .overlay(
                        Image(systemName: artIcon)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .white.opacity(0.5), radius: 8)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))

                if let tag {
                    Text(tag)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.35), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                        .padding(6)
                }
            }

            // Bullets with the mockup's small blue dots
            VStack(alignment: .leading, spacing: 6) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 5, height: 5)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
                        Text(bullet)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer(minLength: 0)

            if let buttonTitle, let action {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.buttonRadius))
                        .shadow(color: Theme.accent.opacity(0.5), radius: 6)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .themeCard()
    }
}

// The wide banner under the cards. It shows the #1 cypher, or an invitation to start one when
// there is none.
private struct FeatsOfTheWeekBanner: View {
    let cypher: TopCypher?
    let isThisWeek: Bool
    let isLoading: Bool
    let onOpen: (String) -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: Theme.spacing) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                Text("Feats of the Week")
                    .font(.system(size: 18, weight: .bold))
                Image(systemName: "sparkle")
            }
            .foregroundColor(Theme.textPrimary)

            if let cypher {
                Text(isThisWeek ? "This week's #1" : "All-time #1")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: 0xFFC24D))

                Text(cypher.title)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let username = cypher.host.username {
                    Text("Hosted by @\(username)")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }

                HStack(spacing: Theme.spacingLarge) {
                    stat(icon: "person.2.fill", value: cypher.entryCount, label: cypher.entryCount == 1 ? "entry" : "entries")
                    stat(icon: "hand.thumbsup.fill", value: cypher.voteCount, label: cypher.voteCount == 1 ? "vote" : "votes")
                    stat(icon: "flame.fill", value: cypher.score, label: "score")
                }

                bannerButton("Watch the Cypher") { onOpen(cypher.id) }
            } else if isLoading {
                ProgressView()
                    .tint(Theme.textPrimary)
                    .padding(.vertical, Theme.spacingLarge)
            } else {
                Text("No cypher has taken the crown yet.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)
                bannerButton("Start One in the Arena", action: onStart)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.spacingLarge)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x1B2A55), Theme.card, Color(hex: 0x3A1F4D)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: Theme.cardRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(Theme.accent.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Theme.accent.opacity(0.25), radius: 12)
    }

    private func stat(icon: String, value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.accent)
                Text("\(value)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
        }
    }

    private func bannerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Theme.accent, in: Capsule())
                .shadow(color: Theme.accent.opacity(0.6), radius: 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeDashboardView(selectedTab: .constant(0))
        .environmentObject(AuthService())
}
