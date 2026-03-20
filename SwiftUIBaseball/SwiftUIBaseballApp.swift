//
//  SwiftUIBaseballApp.swift
//  SwiftUIBaseball
//
//  Created by Joseph Kelly on 3/16/26.
//

import SwiftUI
import SwiftData
import SwiftBaseball

@main
struct SwiftUIBaseballApp: App {
    /// Shared SwiftData container for all models.
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FavoriteItem.self,
            CachedTeam.self,
            CachedPlayerData.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// Configure the SwiftBaseball client and seed teams at launch.
    ///
    /// Bumps the client cache TTL to 24 hours (matching ``StatsCache/cacheTTL``)
    /// and seeds the 30 MLB teams into SwiftData on fresh installs so the home
    /// screen renders instantly.
    init() {
        SwiftBaseball.configure(.init(cacheEnabled: true, cacheTTL: 86_400))
        StatsCache.modelContainer = sharedModelContainer
        let context = ModelContext(sharedModelContainer)
        CachedTeam.seedIfNeeded(into: context)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
