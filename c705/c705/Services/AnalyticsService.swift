//
//  AnalyticsService.swift
//  c705
//
//  Created by Avery Harris on 12/22/25.
//
//  PURPOSE: Records what people do in the app (likes, plays, profile views, app
//  opens). For now the events only print to the console and are kept
//  on the phone; a real analytics service can be plugged in later.
//

import Foundation

// Call AnalyticsService.shared.trackSomething() from any screen. Each tracking function below
// just names the event and passes the details.
class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    // Events about how people use content: likes, comments, follows and plays.
    // MARK: - Engagement Events
    
    func trackLike(trackId: String) {
        logEvent("track_liked", parameters: ["track_id": trackId])
    }
    
    func trackUnlike(trackId: String) {
        logEvent("track_unliked", parameters: ["track_id": trackId])
    }
    
    func trackComment(trackId: String, commentLength: Int) {
        logEvent("comment_created", parameters: [
            "track_id": trackId,
            "comment_length": commentLength
        ])
    }
    
    func trackFollow(artistId: String) {
        logEvent("artist_followed", parameters: ["artist_id": artistId])
    }
    
    func trackUnfollow(artistId: String) {
        logEvent("artist_unfollowed", parameters: ["artist_id": artistId])
    }
    
    func trackTrackPlay(trackId: String, duration: TimeInterval? = nil) {
        var params: [String: Any] = ["track_id": trackId]
        if let duration = duration {
            params["play_duration"] = duration
        }
        logEvent("track_played", parameters: params)
    }
    
    func trackTrackUpload(trackId: String) {
        logEvent("track_uploaded", parameters: ["track_id": trackId])
    }
    
    func trackProfileView(artistId: String) {
        logEvent("profile_viewed", parameters: ["artist_id": artistId])
    }
    
    func trackFeedView() {
        logEvent("feed_viewed")
    }
    
    // Events that show whether people come back: when the app opens, closes or goes to the
    // background.
    // MARK: - Retention Events
    
    func trackSessionStart() {
        logEvent("session_start", parameters: [
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    func trackSessionEnd(duration: TimeInterval) {
        logEvent("session_end", parameters: [
            "duration": duration,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    func trackAppOpen() {
        logEvent("app_opened", parameters: [
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    func trackAppBackground() {
        logEvent("app_backgrounded", parameters: [
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    // MARK: - Private
    
    // Every tracking function funnels through here. To connect Firebase or Mixpanel later, this
    // is the one place to change.
    private func logEvent(_ eventName: String, parameters: [String: Any] = [:]) {
        // In production, integrate with analytics service (Firebase, Mixpanel, etc.)
        // For now, log to console and optionally save to local storage
        
        let event: [String: Any] = [
            "event": eventName,
            "parameters": parameters,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        print("📊 Analytics: \(eventName) - \(parameters)")
        
        // Save to UserDefaults for local analytics
        saveEventToLocalStorage(event)
    }
    
    // Keeps the latest 1000 events in UserDefaults (the phone's small settings storage) and
    // drops older ones.
    private func saveEventToLocalStorage(_ event: [String: Any]) {
        var events = UserDefaults.standard.array(forKey: "analytics_events") as? [[String: Any]] ?? []
        events.append(event)
        
        // Keep only last 1000 events
        if events.count > 1000 {
            events = Array(events.suffix(1000))
        }
        
        UserDefaults.standard.set(events, forKey: "analytics_events")
    }
    
    // Helpers to read or clear the saved events, for example when debugging.
    // MARK: - Analytics Export
    
    func getStoredEvents() -> [[String: Any]] {
        return UserDefaults.standard.array(forKey: "analytics_events") as? [[String: Any]] ?? []
    }
    
    func clearStoredEvents() {
        UserDefaults.standard.removeObject(forKey: "analytics_events")
    }
}

