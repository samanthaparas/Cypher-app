//
//  Settings.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: The user's saved settings (notifications, privacy, playback and
//  role-specific options). The layout mirrors the backend's settings
//  JSON, and every property has a default so a new user starts with
//  sensible values.
//

import Foundation

// MARK: - Settings Model (matches backend JSON structure)
// All of one user's settings in one place. The role-specific groups are optional because most
// users only need one of them.
struct UserSettings: Codable {
    var notifications: NotificationSettings
    var privacy: PrivacySettings
    var playback: PlaybackSettings
    var artist: ArtistSettings?
    var producer: ProducerSettings?
    var engineer: EngineerSettings?
    var journalist: JournalistSettings?
    var freestyleArena: FreestyleArenaSettings?
    
    init() {
        self.notifications = NotificationSettings()
        self.privacy = PrivacySettings()
        self.playback = PlaybackSettings()
    }
}

// MARK: - Base Settings

// Which kinds of alerts the user wants. These are saved choices only; the app does not send
// push notifications yet.
struct NotificationSettings: Codable {
    var likes: Bool = true
    var comments: Bool = true
    var followers: Bool = true
    var mentions: Bool = true
    var events: Bool = true
}

// Who can see, comment on and message this user, and which users they have blocked.
struct PrivacySettings: Codable {
    var privateProfile: Bool = false
    var whoCanComment: CommentPermission = .everyone
    var whoCanMessage: MessagePermission = .everyone
    var blockedUsers: [String] = []
}

enum CommentPermission: String, Codable {
    case everyone = "everyone"
    case followers = "followers"
}

enum MessagePermission: String, Codable {
    case everyone = "everyone"
    case followers = "followers"
    case none = "none"
}

// How audio plays: autoplay, mobile data use and quality.
struct PlaybackSettings: Codable {
    var autoplayNext: Bool = true
    var streamOverCellular: Bool = false
    var audioQuality: AudioQuality = .medium
    var downloadOverWiFiOnly: Bool = true
}

enum AudioQuality: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

// MARK: - Artist Settings

// Options only artists see, such as bio, social links and whether others can start duets.
struct ArtistSettings: Codable {
    var displayName: String?
    var bio: String?
    var location: String?
    var instagram: String?
    var twitter: String?
    var youtube: String?
    var allowDuets: Bool = true
    var allowFreestyleChallenges: Bool = true
    var pinnedTrackId: String?
    var hideOldTracks: Bool = false
}

// MARK: - Producer Settings

// Options only producers see, such as tags, equipment and default beat price.
struct ProducerSettings: Codable {
    var producerName: String?
    var tags: [String] = []
    var equipment: [String] = []
    var defaultBeatPrice: Double?
    var offerLease: Bool = true
    var offerExclusive: Bool = true
    var autoDelivery: Bool = true
    var showInSearch: Bool = true
    var allowPreviews: Bool = true
    var allowFreeDownloads: Bool = false
}

// MARK: - Engineer Settings

// Options only engineers see, such as studio details and available days.
struct EngineerSettings: Codable {
    var studioName: String?
    var location: String?
    var equipment: [String] = []
    var availableDays: [String] = []
    var sessionLengths: [Int] = []
    var cancellationPolicy: String?
    var bufferTime: Int = 30 // minutes
    var enableReviews: Bool = true
}

// MARK: - Journalist Settings

// Options only journalists see: the cities and genres they cover.
struct JournalistSettings: Codable {
    var citiesCovered: [String] = []
    var genresCovered: [String] = []
}

// MARK: - Freestyle Arena Settings

// Options for the Arena (the cypher screens): countdown timer, silence trimming, drafts, battle
// invites and ranking.
struct FreestyleArenaSettings: Codable {
    var countdownTimer: Bool = true
    var autoTrimSilence: Bool = true
    var saveDrafts: Bool = true
    var allowBattleInvites: Bool = true
    var showRanking: Bool = true
    var notifyLeaderboardUpdates: Bool = true
}

