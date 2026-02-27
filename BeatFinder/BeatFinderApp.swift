//
//  BeatFinderApp.swift
//  BeatFinder
//
//  Created by Tracie Constantin on 12/30/25.
//

import SwiftUI

@main
struct BeatFinderApp: App {
    @StateObject private var auth = AuthStore()
    @StateObject private var savedMatches = SavedMatchesStore()
    @StateObject private var subscriptions = SubscriptionManager()
    @StateObject private var likes = LikeService()
    @StateObject private var searchService = SearchService()
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(savedMatches)
                .environmentObject(subscriptions)
                .environmentObject(likes)
                .environmentObject(searchService)
                .environmentObject(settings)
                .task {
                    await subscriptions.loadProducts()
                }
        }
    }
}
