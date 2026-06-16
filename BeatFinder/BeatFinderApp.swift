//
//  BeatFinderApp.swift
//  BeatFinder
//
//  Created by Tracie Constantin on 12/30/25.
//

import SwiftUI

@main
struct BeatFinderApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var savedMatches = SavedMatchesStore()
    @StateObject private var savedBeatStore = SavedBeatStore()
    @StateObject private var likes = LikeService()
    @StateObject private var searchService = SearchService()
    @StateObject private var settings = SettingsStore()
    @StateObject private var messagingStore = MessagingStore()
    @StateObject private var lyricPadStore = LyricPadStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(appState.authStore)
                .environmentObject(appState.subscriptionManager)
                .environmentObject(savedMatches)
                .environmentObject(savedBeatStore)
                .environmentObject(likes)
                .environmentObject(searchService)
                .environmentObject(settings)
                .environmentObject(messagingStore)
                .environmentObject(lyricPadStore)
        }
    }
}
