//
//  FavoriteItemTests.swift
//  SwiftUIBaseballTests
//

import Testing
import SwiftData
import SwiftBaseball
@testable import SwiftUIBaseball

/// Tests for ``FavoriteItem`` SwiftData model and its static helper methods.
struct FavoriteItemTests {

    /// Creates an in-memory model context for isolated test execution.
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: FavoriteItem.self, configurations: config)
        return ModelContext(container)
    }

    @Test func toggleInsertsFavorite() throws {
        let context = try makeContext()

        let added = FavoriteItem.toggle(
            kind: .team, entityId: 147, name: "New York Yankees", in: context
        )

        #expect(added == true)
        let descriptor = FetchDescriptor<FavoriteItem>()
        let items = try context.fetch(descriptor)
        #expect(items.count == 1)
        #expect(items.first?.entityId == 147)
        #expect(items.first?.name == "New York Yankees")
        #expect(items.first?.kind == .team)
    }

    @Test func toggleDeletesExistingFavorite() throws {
        let context = try makeContext()

        FavoriteItem.toggle(kind: .team, entityId: 147, name: "New York Yankees", in: context)
        let removed = FavoriteItem.toggle(
            kind: .team, entityId: 147, name: "New York Yankees", in: context
        )

        #expect(removed == false)
        let descriptor = FetchDescriptor<FavoriteItem>()
        let items = try context.fetch(descriptor)
        #expect(items.isEmpty)
    }

    @Test func isFavoritedReturnsTrueWhenExists() throws {
        let context = try makeContext()

        FavoriteItem.toggle(kind: .player, entityId: 592450, name: "Aaron Judge", in: context)

        #expect(FavoriteItem.isFavorited(entityId: 592450, in: context) == true)
    }

    @Test func isFavoritedReturnsFalseWhenMissing() throws {
        let context = try makeContext()

        #expect(FavoriteItem.isFavorited(entityId: 999, in: context) == false)
    }

    @Test func toggleStoresPlayerMetadata() throws {
        let context = try makeContext()

        FavoriteItem.toggle(
            kind: .player,
            entityId: 592450,
            name: "Aaron Judge",
            teamName: "New York Yankees",
            position: "Right Fielder",
            positionCode: "9",
            jerseyNumber: "99",
            in: context
        )

        let descriptor = FetchDescriptor<FavoriteItem>()
        let item = try context.fetch(descriptor).first
        #expect(item?.teamName == "New York Yankees")
        #expect(item?.position == "Right Fielder")
        #expect(item?.positionCode == "9")
        #expect(item?.jerseyNumber == "99")
    }

    @Test func asRosterEntryReconstructsPlayer() throws {
        let item = FavoriteItem(
            kind: .player,
            entityId: 592450,
            name: "Aaron Judge",
            position: "Right Fielder",
            positionCode: "9",
            jerseyNumber: "99"
        )

        let entry = item.asRosterEntry
        #expect(entry != nil)
        #expect(entry?.id == 592450)
        #expect(entry?.person.fullName == "Aaron Judge")
        #expect(entry?.jerseyNumber == "99")
    }

    @Test func asRosterEntryReturnsNilForTeams() {
        let item = FavoriteItem(kind: .team, entityId: 147, name: "New York Yankees")
        #expect(item.asRosterEntry == nil)
    }
}
