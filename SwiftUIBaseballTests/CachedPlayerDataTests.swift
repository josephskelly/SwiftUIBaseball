//
//  CachedPlayerDataTests.swift
//  SwiftUIBaseballTests
//

import Foundation
import Testing
import SwiftData
@testable import SwiftUIBaseball
@testable import SwiftBaseball

/// Tests for ``CachedPlayerData`` SwiftData model and Codable wrappers.
struct CachedPlayerDataTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CachedPlayerData.self, configurations: config)
        return ModelContext(container)
    }

    // MARK: - SwiftData Persistence

    @Test func storesAndRetrievesByKey() throws {
        let context = try makeContext()
        let record = CachedPlayerData(playerId: 592450, season: 2024)
        context.insert(record)

        let key = "592450-2024"
        let descriptor = FetchDescriptor<CachedPlayerData>(
            predicate: #Predicate { $0.cacheKey == key }
        )
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched.first?.playerId == 592450)
        #expect(fetched.first?.season == 2024)
    }

    @Test func cacheKeyIsUnique() throws {
        let context = try makeContext()
        let record1 = CachedPlayerData(playerId: 592450, season: 2024)
        let record2 = CachedPlayerData(playerId: 592450, season: 2024)
        context.insert(record1)
        context.insert(record2)
        try context.save()

        let descriptor = FetchDescriptor<CachedPlayerData>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
    }

    @Test func differentSeasonsAreSeparate() throws {
        let context = try makeContext()
        context.insert(CachedPlayerData(playerId: 592450, season: 2024))
        context.insert(CachedPlayerData(playerId: 592450, season: 2025))
        try context.save()

        let descriptor = FetchDescriptor<CachedPlayerData>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 2)
    }

    @Test func playerJSONRoundTrips() throws {
        let context = try makeContext()
        let record = CachedPlayerData(playerId: 592450, season: 2024)

        let player = Player.previewBatter
        record.playerJSON = try JSONEncoder().encode(player)
        context.insert(record)

        let decoded = try JSONDecoder().decode(Player.self, from: record.playerJSON!)
        #expect(decoded.id == player.id)
    }

    @Test func seasonStatsJSONRoundTrips() throws {
        let context = try makeContext()
        let record = CachedPlayerData(playerId: 592450, season: 2024)

        let stats = PlayerSeasonStats.previewBatting
        record.seasonStatsJSON = try JSONEncoder().encode(stats)
        context.insert(record)

        let decoded = try JSONDecoder().decode(PlayerSeasonStats.self, from: record.seasonStatsJSON!)
        #expect(decoded.season == stats.season)
    }

    // MARK: - Codable Wrappers

    @Test func platoonStatsRoundTrips() throws {
        let original = PlayerPlatoonStats.preview
        let wrapper = CodablePlatoonStats(original)
        let data = try JSONEncoder().encode(wrapper)
        let decoded = try JSONDecoder().decode(CodablePlatoonStats.self, from: data)
        let restored = decoded.toModel
        #expect(restored.vsLeft?.ops == original.vsLeft?.ops)
        #expect(restored.vsRight?.ops == original.vsRight?.ops)
    }

    @Test func pitcherPlatoonStatsRoundTrips() throws {
        let original = PitcherPlatoonStats.preview
        let wrapper = CodablePitcherPlatoonStats(original)
        let data = try JSONEncoder().encode(wrapper)
        let decoded = try JSONDecoder().decode(CodablePitcherPlatoonStats.self, from: data)
        let restored = decoded.toModel
        #expect(restored.vsLeft?.era == original.vsLeft?.era)
        #expect(restored.vsRight?.era == original.vsRight?.era)
    }

    @Test func platoonStatsHandlesNilSplits() throws {
        let original = PlayerPlatoonStats(vsLeft: nil, vsRight: nil)
        let wrapper = CodablePlatoonStats(original)
        let data = try JSONEncoder().encode(wrapper)
        let decoded = try JSONDecoder().decode(CodablePlatoonStats.self, from: data)
        let restored = decoded.toModel
        #expect(restored.vsLeft == nil)
        #expect(restored.vsRight == nil)
    }

    @Test func updatedAtIsRecent() throws {
        let before = Date()
        let record = CachedPlayerData(playerId: 1, season: 2024)
        #expect(record.updatedAt >= before)
    }
}

// MARK: - Seed Validation

struct CachedTeamSeedTests {

    @Test func seedContainsThirtyTeams() {
        #expect(CachedTeam.allMLBTeams.count == 30)
    }

    @Test func seedTeamIdsAreUnique() {
        let ids = CachedTeam.allMLBTeams.map(\.teamId)
        #expect(Set(ids).count == 30)
    }

    @Test func seedTeamsHaveDistantPastDate() {
        for team in CachedTeam.allMLBTeams {
            #expect(team.updatedAt == .distantPast)
        }
    }

    @Test func seedCoversAllDivisions() {
        let divisions = Set(CachedTeam.allMLBTeams.map(\.divisionName))
        #expect(divisions.count == 6)
        for expected in CachedTeam.divisionOrder {
            #expect(divisions.contains(expected))
        }
    }

    @Test func seedIfNeededInsertsWhenEmpty() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CachedTeam.self, configurations: config)
        let context = ModelContext(container)

        CachedTeam.seedIfNeeded(into: context)

        let descriptor = FetchDescriptor<CachedTeam>()
        let count = try context.fetchCount(descriptor)
        #expect(count == 30)
    }

    @Test func seedIfNeededSkipsWhenPopulated() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CachedTeam.self, configurations: config)
        let context = ModelContext(container)

        // Insert one team manually.
        context.insert(CachedTeam(
            teamId: 147, name: "New York Yankees", abbreviation: "NYY",
            divisionName: "American League East", leagueName: "American League",
            venueName: "Yankee Stadium"
        ))
        try context.save()

        CachedTeam.seedIfNeeded(into: context)

        let descriptor = FetchDescriptor<CachedTeam>()
        let count = try context.fetchCount(descriptor)
        #expect(count == 1)
    }
}

// MARK: - TTL Tests

/// Serialized to prevent races on the shared `StatsCache.modelContainer` static.
@Suite(.serialized) struct StatsCacheTTLTests {

    @Test func cacheTTLIsTwentyFourHours() {
        #expect(StatsCache.cacheTTL == 86_400)
    }

    @Test func persistAndRetrievePlayer() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CachedPlayerData.self,
            configurations: config
        )
        StatsCache.modelContainer = container

        let cache = StatsCache()
        let player = Player.previewBatter
        let stats = PlayerSeasonStats.previewBatting

        await cache.persistPlayer(
            id: 592450, season: 2024,
            player: player, stats: stats
        )

        let cached = await cache.cachedPlayer(id: 592450, season: 2024)
        #expect(cached != nil)
        #expect(cached?.player?.id == 592450)
        #expect(cached?.stats?.season == stats.season)
    }

    @Test func returnsNilForMissingPlayer() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CachedPlayerData.self,
            configurations: config
        )
        StatsCache.modelContainer = container

        let cache = StatsCache()
        let result = await cache.cachedPlayer(id: 99999, season: 2024)
        #expect(result == nil)
    }

    @Test func returnsNilWithoutModelContainer() async {
        StatsCache.modelContainer = nil
        let cache = StatsCache()
        let result = await cache.cachedPlayer(id: 592450, season: 2024)
        #expect(result == nil)
    }

    @Test func removeEntryEvictsL1Cache() async {
        let cache = StatsCache()
        let entry = StatsCache.Entry(
            awayRoster: [], homeRoster: [],
            players: [:], playerStats: [:],
            batterPlatoon: [:], pitcherPlatoon: [:]
        )
        await cache.set(entry, for: 12345)
        #expect(await cache.entry(for: 12345) != nil)

        await cache.removeEntry(for: 12345)
        #expect(await cache.entry(for: 12345) == nil)
    }

    @Test func persistSkipsAllNilFields() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CachedPlayerData.self,
            configurations: config
        )
        StatsCache.modelContainer = container

        let cache = StatsCache()

        // Persist with all nil data (simulates cancelled fetch).
        await cache.persistPlayer(id: 111111, season: 2024)

        // No record should exist — the guard should have returned early.
        let result = await cache.cachedPlayer(id: 111111, season: 2024)
        #expect(result == nil)
    }

    @Test func cachedPlayerReturnsNilForEmptyRecord() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CachedPlayerData.self,
            configurations: config
        )
        StatsCache.modelContainer = container

        // Manually insert an empty record (simulates a record with corrupt JSON).
        let context = ModelContext(container)
        let record = CachedPlayerData(playerId: 222222, season: 2024)
        context.insert(record)
        try context.save()

        let cache = StatsCache()
        let result = await cache.cachedPlayer(id: 222222, season: 2024)
        #expect(result == nil)
    }
}
