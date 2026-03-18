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
    /// Configure the SwiftBaseball client at launch.
    ///
    /// Enables the in-memory response cache (1-hour TTL) so that same-session
    /// re-appears and roster re-fetches resolve instantly from cache rather than
    /// hitting the network on every view appearance.
    init() {
        SwiftBaseball.configure(.init(cacheEnabled: true, cacheTTL: 3600))
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
