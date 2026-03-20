//
//  StatsCache.swift
//  SwiftUIBaseball
//

import Foundation
import SwiftBaseball
import SwiftData

/// Two-tier cache for roster and player stats.
///
/// L1 (in-memory dictionaries) provides instant access within the current session.
/// L2 (SwiftData via ``CachedPlayerData``) persists across launches with a 24-hour TTL.
/// Game-keyed ``Entry`` data stays in-memory only (it's a composite of per-player data).
actor StatsCache {

    /// Shared singleton used throughout the app.
    static let shared = StatsCache()

    /// Cache time-to-live: 24 hours.
    static let cacheTTL: TimeInterval = 86_400

    /// The SwiftData container for L2 persistence. Set from app init.
    static var modelContainer: ModelContainer?

    /// Lazily created `ModelContext` scoped to this actor instance.
    ///
    /// Reads from ``modelContainer`` on first access so test suites that
    /// set the static before creating a fresh `StatsCache()` get isolated contexts.
    private var _context: ModelContext?
    private var context: ModelContext? {
        if let _context { return _context }
        guard let container = Self.modelContainer else { return nil }
        let ctx = ModelContext(container)
        _context = ctx
        return ctx
    }

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

    /// Removes the cached entry for `gamePk` so the next load re-fetches from the network.
    func removeEntry(for gamePk: Int) {
        cache.removeValue(forKey: gamePk)
    }

    // MARK: - Statcast Cache (L1)

    /// Statcast data keyed by `"playerId-season"`.
    private var statcastCache: [String: StatcastBatting] = [:]

    private static func statcastKey(playerId: Int, season: Int) -> String {
        "\(playerId)-\(season)"
    }

    /// Returns cached Statcast data for a player/season pair, or `nil` if not cached.
    func statcast(playerId: Int, season: Int) -> StatcastBatting? {
        statcastCache[Self.statcastKey(playerId: playerId, season: season)]
    }

    /// Stores Statcast data for a player/season pair.
    func setStatcast(_ data: StatcastBatting, playerId: Int, season: Int) {
        statcastCache[Self.statcastKey(playerId: playerId, season: season)] = data
    }

    // MARK: - Statcast Pitching Cache (L1)

    /// Statcast pitching data keyed by `"playerId-season"`.
    private var statcastPitchingCache: [String: StatcastPitching] = [:]

    /// Returns cached Statcast pitching data for a player/season pair, or `nil` if not cached.
    func statcastPitching(playerId: Int, season: Int) -> StatcastPitching? {
        statcastPitchingCache[Self.statcastKey(playerId: playerId, season: season)]
    }

    /// Stores Statcast pitching data for a player/season pair.
    func setStatcastPitching(_ data: StatcastPitching, playerId: Int, season: Int) {
        statcastPitchingCache[Self.statcastKey(playerId: playerId, season: season)] = data
    }

    // MARK: - SwiftData L2 Cache

    /// Returns `true` if the given date is older than ``cacheTTL``.
    private static func isStale(_ date: Date) -> Bool {
        date.timeIntervalSinceNow < -cacheTTL
    }

    /// Loads cached player data from SwiftData if fresh.
    ///
    /// Returns a tuple of all available cached data for the player/season, or `nil`
    /// for any field that isn't cached or is stale.
    ///
    /// - Parameters:
    ///   - id: MLB player ID.
    ///   - season: Season year.
    /// - Returns: Tuple of decoded data, or `nil` if not cached or stale.
    func cachedPlayer(id: Int, season: Int) -> (
        player: Player?,
        stats: PlayerSeasonStats?,
        batterPlatoon: PlayerPlatoonStats?,
        pitcherPlatoon: PitcherPlatoonStats?
    )? {
        guard let context else { return nil }
        let key = "\(id)-\(season)"
        let descriptor = FetchDescriptor<CachedPlayerData>(
            predicate: #Predicate { $0.cacheKey == key }
        )
        guard let cached = try? context.fetch(descriptor).first,
              !Self.isStale(cached.updatedAt) else { return nil }

        let decoder = JSONDecoder()
        let player = cached.playerJSON.flatMap { try? decoder.decode(Player.self, from: $0) }
        let stats = cached.seasonStatsJSON.flatMap { try? decoder.decode(PlayerSeasonStats.self, from: $0) }
        let bPlatoon = cached.batterPlatoonJSON.flatMap {
            (try? decoder.decode(CodablePlatoonStats.self, from: $0))?.toModel
        }
        let pPlatoon = cached.pitcherPlatoonJSON.flatMap {
            (try? decoder.decode(CodablePitcherPlatoonStats.self, from: $0))?.toModel
        }

        // Treat all-nil decoded fields as a cache miss so the entry gets re-fetched.
        guard player != nil || stats != nil || bPlatoon != nil || pPlatoon != nil else { return nil }

        return (player, stats, bPlatoon, pPlatoon)
    }

    /// Persists player data to SwiftData, upserting by player ID + season.
    ///
    /// Only persists types that support round-trip serialization (Player,
    /// PlayerSeasonStats, platoon stats). Statcast data stays in L1 only.
    ///
    /// - Parameters:
    ///   - id: MLB player ID.
    ///   - season: Season year.
    ///   - player: Player bio.
    ///   - stats: Season stats.
    ///   - batterPlatoon: Batter platoon splits.
    ///   - pitcherPlatoon: Pitcher platoon splits.
    func persistPlayer(
        id: Int,
        season: Int,
        player: Player? = nil,
        stats: PlayerSeasonStats? = nil,
        batterPlatoon: PlayerPlatoonStats? = nil,
        pitcherPlatoon: PitcherPlatoonStats? = nil
    ) {
        // Don't create empty records — they poison the cache for 24 hours.
        guard player != nil || stats != nil || batterPlatoon != nil || pitcherPlatoon != nil else { return }
        guard let context else { return }
        let key = "\(id)-\(season)"
        let descriptor = FetchDescriptor<CachedPlayerData>(
            predicate: #Predicate { $0.cacheKey == key }
        )

        let record: CachedPlayerData
        if let existing = try? context.fetch(descriptor).first {
            record = existing
        } else {
            record = CachedPlayerData(playerId: id, season: season)
            context.insert(record)
        }

        let encoder = JSONEncoder()
        if let player { record.playerJSON = try? encoder.encode(player) }
        if let stats { record.seasonStatsJSON = try? encoder.encode(stats) }
        if let batterPlatoon { record.batterPlatoonJSON = try? encoder.encode(CodablePlatoonStats(batterPlatoon)) }
        if let pitcherPlatoon { record.pitcherPlatoonJSON = try? encoder.encode(CodablePitcherPlatoonStats(pitcherPlatoon)) }
        record.updatedAt = Date()

        try? context.save()
    }
}

/// Retries an async throwing operation once on transient errors.
///
/// Returns `nil` when all attempts fail. Permanent URL errors
/// (`.badURL`, `.unsupportedURL`) skip the retry to avoid wasting time.
///
/// - Parameters:
///   - maxAttempts: Total number of attempts (default 2 = one retry).
///   - operation: The async throwing closure to execute.
/// - Returns: The result on success, or `nil` if all attempts fail.
func withRetry<T: Sendable>(
    maxAttempts: Int = 2,
    _ operation: @Sendable () async throws -> T
) async -> T? {
    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch let urlError as URLError
            where urlError.code == .badURL || urlError.code == .unsupportedURL {
            return nil
        } catch {
            if attempt < maxAttempts {
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
    return nil
}
