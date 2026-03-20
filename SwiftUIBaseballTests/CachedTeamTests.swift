//
//  CachedTeamTests.swift
//  SwiftUIBaseballTests
//

import Testing
import SwiftData
@testable import SwiftUIBaseball

/// Tests for ``CachedTeam`` SwiftData model.
struct CachedTeamTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CachedTeam.self, configurations: config)
        return ModelContext(container)
    }

    @Test func storesTeamData() throws {
        let context = try makeContext()

        let team = CachedTeam(
            teamId: 147,
            name: "New York Yankees",
            abbreviation: "NYY",
            divisionName: "American League East",
            leagueName: "American League",
            venueName: "Yankee Stadium"
        )
        context.insert(team)

        let descriptor = FetchDescriptor<CachedTeam>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched.first?.teamId == 147)
        #expect(fetched.first?.abbreviation == "NYY")
    }

    @Test func divisionSortIndexOrdersCorrectly() {
        let alEast = CachedTeam(teamId: 1, name: "A", abbreviation: "A",
                                divisionName: "American League East",
                                leagueName: "AL", venueName: "V")
        let nlWest = CachedTeam(teamId: 2, name: "B", abbreviation: "B",
                                divisionName: "National League West",
                                leagueName: "NL", venueName: "V")
        #expect(alEast.divisionSortIndex < nlWest.divisionSortIndex)
    }

    @Test func divisionShortNameAbbreviates() {
        let team = CachedTeam(teamId: 1, name: "A", abbreviation: "A",
                              divisionName: "American League East",
                              leagueName: "AL", venueName: "V")
        #expect(team.divisionShortName == "AL East")
    }

    @Test func unknownDivisionSortsLast() {
        let team = CachedTeam(teamId: 1, name: "A", abbreviation: "A",
                              divisionName: "Unknown Division",
                              leagueName: "?", venueName: "V")
        #expect(team.divisionSortIndex == CachedTeam.divisionOrder.count)
    }
}
