//
//  GameDetailViewTests.swift
//  SwiftUIBaseballTests
//

import Testing
import SwiftBaseball
@testable import SwiftUIBaseball

// MARK: - formatOPS

struct FormatOPSTests {

    @Test func belowOne() {
        #expect(formatOPS(0.850) == ".850 OPS")
    }

    @Test func exactlyOne() {
        #expect(formatOPS(1.000) == "1.000 OPS")
    }

    @Test func aboveOne() {
        #expect(formatOPS(1.036) == "1.036 OPS")
    }

    @Test func zero() {
        #expect(formatOPS(0.0) == ".000 OPS")
    }

    @Test func leadingZeroPreserved() {
        // .050 should not become ".50 OPS"
        #expect(formatOPS(0.050) == ".050 OPS")
    }

    @Test func nearBoundary() {
        #expect(formatOPS(0.999) == ".999 OPS")
    }

    @Test func eliteOPS() {
        #expect(formatOPS(1.116) == "1.116 OPS")
    }
}

// MARK: - abbreviatedName

struct AbbreviatedNameTests {

    @Test func twoPartName() {
        #expect(abbreviatedName("Aaron Judge") == "A. Judge")
    }

    @Test func twoPartNameOhtani() {
        #expect(abbreviatedName("Shohei Ohtani") == "S. Ohtani")
    }

    @Test func singleName() {
        // No space → returned unchanged
        #expect(abbreviatedName("Ohtani") == "Ohtani")
    }

    @Test func threePartName() {
        // Uses first initial and last word
        #expect(abbreviatedName("José de la Cruz") == "J. Cruz")
    }

    @Test func hyphenatedLastName() {
        #expect(abbreviatedName("Corbin Burnes") == "C. Burnes")
    }

    @Test func emptyString() {
        #expect(abbreviatedName("") == "")
    }
}

// MARK: - formatRate

struct FormatRateTests {

    @Test func belowOne() {
        #expect(formatRate(0.310) == ".310")
    }

    @Test func exactlyOne() {
        #expect(formatRate(1.000) == "1.000")
    }

    @Test func aboveOne() {
        #expect(formatRate(1.036) == "1.036")
    }

    @Test func zero() {
        #expect(formatRate(0.0) == ".000")
    }

    @Test func leadingZeroPreserved() {
        #expect(formatRate(0.050) == ".050")
    }
}

// MARK: - formatIP

struct FormatIPTests {

    @Test func whole() {
        #expect(formatIP(162.0) == "162.0")
    }

    @Test func singleDigitFraction() {
        #expect(formatIP(5.1) == "5.1")
    }

    @Test func zero() {
        #expect(formatIP(0.0) == "0.0")
    }
}

// MARK: - StatsCache

struct StatsCacheTests {

    /// A minimal empty cache entry for use in tests.
    private static let emptyEntry = StatsCache.Entry(
        awayRoster: [],
        homeRoster: [],
        players: [:],
        playerStats: [:],
        batterPlatoon: [:],
        pitcherPlatoon: [:]
    )

    @Test func returnsNilForUnknownKey() async {
        let cache = StatsCache()
        #expect(await cache.entry(for: 99999) == nil)
    }

    @Test func storesAndRetrievesEntry() async {
        let cache = StatsCache()
        await cache.set(Self.emptyEntry, for: 1)
        let retrieved = await cache.entry(for: 1)
        #expect(retrieved != nil)
    }

    @Test func differentKeysAreIndependent() async {
        let cache = StatsCache()
        await cache.set(Self.emptyEntry, for: 1)
        #expect(await cache.entry(for: 1) != nil)
        #expect(await cache.entry(for: 2) == nil)
    }

    @Test func overwritesExistingEntry() async {
        let cache = StatsCache()
        await cache.set(Self.emptyEntry, for: 7)
        await cache.set(Self.emptyEntry, for: 7)
        #expect(await cache.entry(for: 7) != nil)
    }
}
