//
//  StatsCache.swift
//  SwiftUIBaseball
//

import SwiftBaseball

/// In-memory cache for roster and player stats keyed by game primary key.
///
/// Using a Swift `actor` provides data-race-free access from concurrent tasks.
/// Cache entries persist for the lifetime of the app session; a pull-to-refresh
/// in ``GameDetailView`` bypasses the cache to force a fresh fetch.
actor StatsCache {

    /// Shared singleton used throughout the app.
    static let shared = StatsCache()

    /// All data needed to populate a ``GameDetailView`` without network calls.
    struct Entry: Sendable {
        /// Away team's active roster.
        let awayRoster: [RosterEntry]
        /// Home team's active roster.
        let homeRoster: [RosterEntry]
        /// Player bio keyed by player ID.
        let players: [Int: Player]
        /// Season stats keyed by player ID.
        let playerStats: [Int: PlayerSeasonStats]
        /// Batter platoon splits keyed by player ID.
        let batterPlatoon: [Int: PlayerPlatoonStats]
        /// Pitcher platoon splits keyed by player ID.
        let pitcherPlatoon: [Int: PitcherPlatoonStats]
    }

    private var cache: [Int: Entry] = [:]

    /// Returns the cached entry for `gamePk`, or `nil` if not yet cached.
    func entry(for gamePk: Int) -> Entry? {
        cache[gamePk]
    }

    /// Stores `entry` for `gamePk`, replacing any existing value.
    func set(_ entry: Entry, for gamePk: Int) {
        cache[gamePk] = entry
    }
}
