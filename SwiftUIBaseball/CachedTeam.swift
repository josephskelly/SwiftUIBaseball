//
//  CachedTeam.swift
//  SwiftUIBaseball
//

import Foundation
import SwiftData

/// A locally cached MLB team, persisted via SwiftData for instant home screen rendering.
///
/// Populated from `SwiftBaseball.teams(.all(season:))` on first launch and refreshed
/// in the background on subsequent launches. Stores just enough metadata to display a
/// grouped teams list and navigate to a roster view.
@Model
final class CachedTeam {

    /// MLB team ID.
    @Attribute(.unique) var teamId: Int

    /// Full team name (e.g. "New York Yankees").
    var name: String

    /// Standard abbreviation (e.g. "NYY").
    var abbreviation: String

    /// Division name for grouping (e.g. "American League East").
    var divisionName: String

    /// League name (e.g. "American League").
    var leagueName: String

    /// Home venue name (e.g. "Yankee Stadium").
    var venueName: String

    /// When this record was last updated from the API.
    var updatedAt: Date

    /// Creates a cached team record.
    ///
    /// - Parameters:
    ///   - teamId: MLB team ID.
    ///   - name: Full team name.
    ///   - abbreviation: Standard abbreviation.
    ///   - divisionName: Division name for grouping.
    ///   - leagueName: League name.
    ///   - venueName: Home venue name.
    init(
        teamId: Int,
        name: String,
        abbreviation: String,
        divisionName: String,
        leagueName: String,
        venueName: String
    ) {
        self.teamId = teamId
        self.name = name
        self.abbreviation = abbreviation
        self.divisionName = divisionName
        self.leagueName = leagueName
        self.venueName = venueName
        self.updatedAt = Date()
    }

    // MARK: - Division Ordering

    /// The canonical display order for MLB divisions.
    static let divisionOrder = [
        "American League East",
        "American League Central",
        "American League West",
        "National League East",
        "National League Central",
        "National League West",
    ]

    /// Returns the sort index for this team's division, used for ordered grouping.
    var divisionSortIndex: Int {
        Self.divisionOrder.firstIndex(of: divisionName) ?? Self.divisionOrder.count
    }

    /// Short division label for section headers (e.g. "AL East").
    var divisionShortName: String {
        divisionName
            .replacingOccurrences(of: "American League", with: "AL")
            .replacingOccurrences(of: "National League", with: "NL")
    }
}
