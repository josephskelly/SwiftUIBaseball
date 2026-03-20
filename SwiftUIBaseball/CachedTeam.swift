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

    // MARK: - Seed Data

    /// The 30 MLB teams hardcoded for instant first-launch display.
    ///
    /// Seed records use `.distantPast` for `updatedAt` so the TTL check
    /// triggers a background refresh on first launch while the list is
    /// already visible.
    static let allMLBTeams: [CachedTeam] = {
        let teams: [(Int, String, String, String, String, String)] = [
            // AL East
            (110, "Baltimore Orioles",    "BAL", "American League East",    "American League", "Oriole Park at Camden Yards"),
            (111, "Boston Red Sox",       "BOS", "American League East",    "American League", "Fenway Park"),
            (147, "New York Yankees",     "NYY", "American League East",    "American League", "Yankee Stadium"),
            (139, "Tampa Bay Rays",       "TB",  "American League East",    "American League", "Tropicana Field"),
            (141, "Toronto Blue Jays",    "TOR", "American League East",    "American League", "Rogers Centre"),
            // AL Central
            (145, "Chicago White Sox",    "CWS", "American League Central", "American League", "Guaranteed Rate Field"),
            (114, "Cleveland Guardians",  "CLE", "American League Central", "American League", "Progressive Field"),
            (116, "Detroit Tigers",       "DET", "American League Central", "American League", "Comerica Park"),
            (118, "Kansas City Royals",   "KC",  "American League Central", "American League", "Kauffman Stadium"),
            (142, "Minnesota Twins",      "MIN", "American League Central", "American League", "Target Field"),
            // AL West
            (117, "Houston Astros",       "HOU", "American League West",    "American League", "Minute Maid Park"),
            (108, "Los Angeles Angels",   "LAA", "American League West",    "American League", "Angel Stadium"),
            (133, "Oakland Athletics",    "OAK", "American League West",    "American League", "Oakland Coliseum"),
            (136, "Seattle Mariners",     "SEA", "American League West",    "American League", "T-Mobile Park"),
            (140, "Texas Rangers",        "TEX", "American League West",    "American League", "Globe Life Field"),
            // NL East
            (144, "Atlanta Braves",       "ATL", "National League East",    "National League", "Truist Park"),
            (146, "Miami Marlins",        "MIA", "National League East",    "National League", "loanDepot park"),
            (121, "New York Mets",        "NYM", "National League East",    "National League", "Citi Field"),
            (143, "Philadelphia Phillies","PHI", "National League East",    "National League", "Citizens Bank Park"),
            (120, "Washington Nationals", "WSH", "National League East",    "National League", "Nationals Park"),
            // NL Central
            (112, "Chicago Cubs",         "CHC", "National League Central", "National League", "Wrigley Field"),
            (113, "Cincinnati Reds",      "CIN", "National League Central", "National League", "Great American Ball Park"),
            (158, "Milwaukee Brewers",    "MIL", "National League Central", "National League", "American Family Field"),
            (134, "Pittsburgh Pirates",   "PIT", "National League Central", "National League", "PNC Park"),
            (138, "St. Louis Cardinals",  "STL", "National League Central", "National League", "Busch Stadium"),
            // NL West
            (109, "Arizona Diamondbacks", "AZ",  "National League West",    "National League", "Chase Field"),
            (115, "Colorado Rockies",     "COL", "National League West",    "National League", "Coors Field"),
            (119, "Los Angeles Dodgers",  "LAD", "National League West",    "National League", "Dodger Stadium"),
            (135, "San Diego Padres",     "SD",  "National League West",    "National League", "Petco Park"),
            (137, "San Francisco Giants", "SF",  "National League West",    "National League", "Oracle Park"),
        ]
        return teams.map { id, name, abbr, div, league, venue in
            let team = CachedTeam(
                teamId: id, name: name, abbreviation: abbr,
                divisionName: div, leagueName: league, venueName: venue
            )
            team.updatedAt = .distantPast
            return team
        }
    }()

    /// Inserts the 30 hardcoded MLB teams if the store is empty.
    ///
    /// Call once at app launch to guarantee the home screen always has data.
    /// Seed records have `updatedAt = .distantPast` so the TTL check will
    /// trigger a background refresh immediately.
    ///
    /// - Parameter context: The model context to insert into.
    static func seedIfNeeded(into context: ModelContext) {
        let descriptor = FetchDescriptor<CachedTeam>()
        guard (try? context.fetchCount(descriptor)) == 0 else { return }
        for team in allMLBTeams {
            context.insert(team)
        }
        try? context.save()
    }
}
