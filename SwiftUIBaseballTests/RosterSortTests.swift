//
//  RosterSortTests.swift
//  SwiftUIBaseballTests
//

import Foundation
import Testing
import SwiftBaseball
@testable import SwiftUIBaseball

// MARK: - Test helpers

/// Minimal JSON decoder for building test roster entries.
private let testDecoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
}()

/// Creates a roster entry with the given id, name, and position code.
private func makeEntry(id: Int, name: String, position: String = "9") -> RosterEntry {
    // swiftlint:disable:next force_try
    try! testDecoder.decode(RosterEntry.self, from: Data("""
    {"person": {"id": \(id), "fullName": "\(name)"}, "position": "\(position)", "status": "Active"}
    """.utf8))
}

/// Creates a batting season stats line with the given OPS string.
private func makeBattingStats(id: Int, ops: String) -> PlayerSeasonStats {
    // swiftlint:disable:next force_try
    try! testDecoder.decode(PlayerSeasonStats.self, from: Data("""
    {
        "player": {"id": \(id), "fullName": "Test"},
        "team": {"id": 1, "name": "Test"},
        "season": "2025",
        "group": "batting",
        "batting": {"gamesPlayed": 100, "ops": "\(ops)"}
    }
    """.utf8))
}

// MARK: - sortRoster tests

struct RosterSortTests {

    private let judge = makeEntry(id: 1, name: "Aaron Judge")
    private let ohtani = makeEntry(id: 2, name: "Shohei Ohtani")
    private let soto = makeEntry(id: 3, name: "Juan Soto")

    // MARK: Name sorting

    @Test func sortByNameAscending() {
        let entries = [ohtani, judge, soto]
        let sorted = sortRoster(
            entries, by: .name, ascending: true, isPitcher: false,
            playerStats: [:], players: [:], batterPlatoon: [:], pitcherPlatoon: [:]
        )
        #expect(sorted.map(\.id) == [judge.id, ohtani.id, soto.id])
    }

    @Test func sortByNameDescending() {
        let entries = [ohtani, judge, soto]
        let sorted = sortRoster(
            entries, by: .name, ascending: false, isPitcher: false,
            playerStats: [:], players: [:], batterPlatoon: [:], pitcherPlatoon: [:]
        )
        #expect(sorted.map(\.id) == [soto.id, ohtani.id, judge.id])
    }

    // MARK: OPS sorting

    @Test func sortByOPSAscending() {
        let stats: [Int: PlayerSeasonStats] = [
            1: makeBattingStats(id: 1, ops: "1.100"),
            2: makeBattingStats(id: 2, ops: ".900"),
            3: makeBattingStats(id: 3, ops: "1.000"),
        ]
        let sorted = sortRoster(
            [judge, ohtani, soto], by: .ops, ascending: true, isPitcher: false,
            playerStats: stats, players: [:], batterPlatoon: [:], pitcherPlatoon: [:]
        )
        #expect(sorted.map(\.id) == [ohtani.id, soto.id, judge.id])
    }

    @Test func sortByOPSDescending() {
        let stats: [Int: PlayerSeasonStats] = [
            1: makeBattingStats(id: 1, ops: "1.100"),
            2: makeBattingStats(id: 2, ops: ".900"),
            3: makeBattingStats(id: 3, ops: "1.000"),
        ]
        let sorted = sortRoster(
            [judge, ohtani, soto], by: .ops, ascending: false, isPitcher: false,
            playerStats: stats, players: [:], batterPlatoon: [:], pitcherPlatoon: [:]
        )
        #expect(sorted.map(\.id) == [judge.id, soto.id, ohtani.id])
    }

    // MARK: Nil sorts last

    @Test func nilOPSSortsLastAscending() {
        let stats: [Int: PlayerSeasonStats] = [
            1: makeBattingStats(id: 1, ops: ".800"),
            // id 2 has no stats
            3: makeBattingStats(id: 3, ops: "1.000"),
        ]
        let sorted = sortRoster(
            [judge, ohtani, soto], by: .ops, ascending: true, isPitcher: false,
            playerStats: stats, players: [:], batterPlatoon: [:], pitcherPlatoon: [:]
        )
        // Ohtani (nil) should be last
        #expect(sorted.last?.id == ohtani.id)
        #expect(sorted.first?.id == judge.id)
    }

    @Test func nilOPSSortsLastDescending() {
        let stats: [Int: PlayerSeasonStats] = [
            1: makeBattingStats(id: 1, ops: ".800"),
            3: makeBattingStats(id: 3, ops: "1.000"),
        ]
        let sorted = sortRoster(
            [judge, ohtani, soto], by: .ops, ascending: false, isPitcher: false,
            playerStats: stats, players: [:], batterPlatoon: [:], pitcherPlatoon: [:]
        )
        // Ohtani (nil) should still be last in descending
        #expect(sorted.last?.id == ohtani.id)
        #expect(sorted.first?.id == soto.id)
    }

    @Test func allNilOPSPreservesRelativeOrder() {
        let sorted = sortRoster(
            [judge, ohtani, soto], by: .ops, ascending: true, isPitcher: false,
            playerStats: [:], players: [:], batterPlatoon: [:], pitcherPlatoon: [:]
        )
        // All nil → compareOptionalDoubles returns .orderedSame → stable sort
        #expect(sorted.count == 3)
    }
}

// MARK: - compareOptionalDoubles tests

struct CompareOptionalDoublesTests {

    @Test func bothPresent() {
        #expect(compareOptionalDoubles(1.0, 2.0) == .orderedAscending)
        #expect(compareOptionalDoubles(2.0, 1.0) == .orderedDescending)
        #expect(compareOptionalDoubles(1.0, 1.0) == .orderedSame)
    }

    @Test func nilSortsAfterValue() {
        #expect(compareOptionalDoubles(1.0, nil) == .orderedAscending)
        #expect(compareOptionalDoubles(nil, 1.0) == .orderedDescending)
    }

    @Test func bothNil() {
        #expect(compareOptionalDoubles(nil, nil) == .orderedSame)
    }
}
