//
//  PreviewHelpers.swift
//  SwiftUIBaseball
//

#if DEBUG
import Foundation
@testable import SwiftBaseball

// MARK: - Date-aware decoder for previews

private let previewDecoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .custom { decoder in
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.dateFormat = "yyyy-MM-dd"
        if let date = fmt.date(from: s) { return date }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: s) { return date }
        throw DecodingError.dataCorruptedError(
            in: c, debugDescription: "Cannot decode date: \(s)"
        )
    }
    return d
}()

// MARK: - ScheduleEntry mock

extension ScheduleEntry {
    /// A mock Yankees @ Red Sox scheduled game for use in previews.
    static let preview: ScheduleEntry = {
        // swiftlint:disable:next force_try
        try! previewDecoder.decode(ScheduleEntry.self, from: Data("""
        {
            "gamePk": 1,
            "gameDate": "2025-04-01",
            "status": "Scheduled",
            "teams": {
                "away": {"team": {"id": 147, "name": "New York Yankees"}},
                "home": {"team": {"id": 111, "name": "Boston Red Sox"}}
            },
            "gameType": "R",
            "season": "2025"
        }
        """.utf8))
    }()
}
// MARK: - RosterEntry mocks

extension RosterEntry {
    /// A mock position-player roster entry (Aaron Judge, RF, #99).
    static let previewBatter: RosterEntry = {
        // swiftlint:disable:next force_try
        try! previewDecoder.decode(RosterEntry.self, from: Data("""
        {
            "person": {"id": 592450, "fullName": "Aaron Judge"},
            "jerseyNumber": "99",
            "position": "9",
            "status": "Active"
        }
        """.utf8))
    }()

    /// A mock pitcher roster entry (Gerrit Cole, SP, #45).
    static let previewPitcher: RosterEntry = {
        // swiftlint:disable:next force_try
        try! previewDecoder.decode(RosterEntry.self, from: Data("""
        {
            "person": {"id": 543037, "fullName": "Gerrit Cole"},
            "jerseyNumber": "45",
            "position": "1",
            "status": "Active"
        }
        """.utf8))
    }()
}

// MARK: - Player bio mocks

extension Player {
    /// A mock position player bio (Aaron Judge).
    static let previewBatter: Player = {
        // swiftlint:disable:next force_try
        try! previewDecoder.decode(Player.self, from: Data("""
        {
            "id": 592450,
            "fullName": "Aaron Judge",
            "firstName": "Aaron",
            "lastName": "Judge",
            "primaryNumber": "99",
            "birthDate": "1992-04-26",
            "currentAge": 32,
            "birthCity": "Linden",
            "birthCountry": "USA",
            "height": "6' 7\\"",
            "weight": 282,
            "active": true,
            "primaryPosition": "9",
            "batSide": "R",
            "pitchHand": "R",
            "currentTeam": {"id": 147, "name": "New York Yankees"},
            "mlbDebutDate": "2016-08-13"
        }
        """.utf8))
    }()

    /// A mock pitcher bio (Gerrit Cole).
    static let previewPitcher: Player = {
        // swiftlint:disable:next force_try
        try! previewDecoder.decode(Player.self, from: Data("""
        {
            "id": 543037,
            "fullName": "Gerrit Cole",
            "firstName": "Gerrit",
            "lastName": "Cole",
            "primaryNumber": "45",
            "birthDate": "1990-09-08",
            "currentAge": 33,
            "birthCity": "Newport Beach",
            "birthCountry": "USA",
            "height": "6' 4\\"",
            "weight": 225,
            "active": true,
            "primaryPosition": "1",
            "batSide": "R",
            "pitchHand": "R",
            "currentTeam": {"id": 147, "name": "New York Yankees"},
            "mlbDebutDate": "2013-06-11"
        }
        """.utf8))
    }()
}

// MARK: - PlayerSeasonStats mocks

extension PlayerSeasonStats {
    /// A mock batting season stats line (Aaron Judge, 2024).
    static let previewBatting: PlayerSeasonStats = {
        // swiftlint:disable:next force_try
        try! previewDecoder.decode(PlayerSeasonStats.self, from: Data("""
        {
            "player": {"id": 592450, "fullName": "Aaron Judge"},
            "team": {"id": 147, "name": "New York Yankees"},
            "season": "2024",
            "group": "batting",
            "batting": {
                "gamesPlayed": 158, "plateAppearances": 701, "atBats": 561,
                "runs": 122, "hits": 166, "doubles": 29, "triples": 1,
                "homeRuns": 58, "rbi": 144, "stolenBases": 10, "caughtStealing": 3,
                "baseOnBalls": 133, "intentionalWalks": 16, "strikeOuts": 171,
                "hitByPitch": 6, "sacFlies": 7, "sacBunts": 0,
                "groundIntoDoublePlay": 8, "totalBases": 344, "leftOnBase": 220,
                "avg": ".322", "obp": ".458", "slg": ".701", "ops": "1.159", "babip": ".349"
            }
        }
        """.utf8))
    }()

    /// A mock pitching season stats line (Gerrit Cole, 2023).
    static let previewPitching: PlayerSeasonStats = {
        // swiftlint:disable:next force_try
        try! previewDecoder.decode(PlayerSeasonStats.self, from: Data("""
        {
            "player": {"id": 543037, "fullName": "Gerrit Cole"},
            "team": {"id": 147, "name": "New York Yankees"},
            "season": "2023",
            "group": "pitching",
            "pitching": {
                "gamesPlayed": 33, "gamesStarted": 33, "wins": 15, "losses": 4,
                "saves": 0, "saveOpportunities": 0, "holds": 0, "blownSaves": 0,
                "completeGames": 1, "shutouts": 0,
                "hits": 168, "runs": 70, "earnedRuns": 67,
                "homeRuns": 24, "baseOnBalls": 34, "intentionalWalks": 0,
                "strikeOuts": 222, "hitByPitch": 3, "wildPitches": 7, "balks": 0,
                "battersFaced": 828,
                "era": "2.63", "whip": "0.99", "avg": ".205",
                "obp": ".252", "slg": ".346", "ops": ".598",
                "inningsPitched": "209.0"
            }
        }
        """.utf8))
    }()
}

// MARK: - Platoon split mocks

extension PlayerPlatoonStats {
    /// Mock batter platoon splits.
    static let preview: PlayerPlatoonStats = {
        // swiftlint:disable:next force_try
        let vsLeft = try! previewDecoder.decode(BattingStats.self, from: Data("""
        {"gamesPlayed": 75, "avg": ".280", "obp": ".390", "slg": ".530", "ops": ".920"}
        """.utf8))
        // swiftlint:disable:next force_try
        let vsRight = try! previewDecoder.decode(BattingStats.self, from: Data("""
        {"gamesPlayed": 83, "avg": ".350", "obp": ".510", "slg": ".800", "ops": "1.310"}
        """.utf8))
        return PlayerPlatoonStats(vsLeft: vsLeft, vsRight: vsRight)
    }()
}

extension PitcherPlatoonStats {
    /// Mock pitcher platoon splits.
    static let preview: PitcherPlatoonStats = {
        // swiftlint:disable:next force_try
        let vsLeft = try! previewDecoder.decode(PitchingStats.self, from: Data("""
        {"gamesPlayed": 33, "era": "2.80", "whip": "0.95", "strikeOuts": 115, "ops": ".580"}
        """.utf8))
        // swiftlint:disable:next force_try
        let vsRight = try! previewDecoder.decode(PitchingStats.self, from: Data("""
        {"gamesPlayed": 33, "era": "2.45", "whip": "1.02", "strikeOuts": 107, "ops": ".615"}
        """.utf8))
        return PitcherPlatoonStats(vsLeft: vsLeft, vsRight: vsRight)
    }()
}

// MARK: - StatcastBatting mock

extension StatcastBatting {
    /// Mock Statcast data modeled on Aaron Judge's 2024 batted-ball profile.
    static let preview = StatcastBatting(
        battedBallEvents: 392,
        groundBalls: 130,
        flyBalls: 145,
        lineDrives: 88,
        popups: 29,
        gbPercent: 0.332,
        fbPercent: 0.370,
        ldPercent: 0.224,
        popupPercent: 0.074,
        avgExitVelocity: 95.9,
        maxExitVelocity: 116.9,
        avgLaunchAngle: 17.2,
        barrelRate: 0.223,
        hardHitRate: 0.598,
        xBA: 0.310,
        xSLG: 0.680,
        xwOBA: 0.448
    )
}

// MARK: - StatcastPitching mock

extension StatcastPitching {
    /// Mock Statcast pitching data modeled on a frontline starter's profile.
    static let preview = StatcastPitching(
        battedBallEvents: 480,
        groundBalls: 192,
        flyBalls: 144,
        lineDrives: 110,
        popups: 34,
        gbPercent: 0.400,
        fbPercent: 0.300,
        ldPercent: 0.229,
        popupPercent: 0.071,
        avgExitVelocity: 87.2,
        maxExitVelocity: 112.4,
        avgLaunchAngle: 11.8,
        barrelRate: 0.058,
        hardHitRate: 0.312,
        xBA: 0.238,
        xSLG: 0.378,
        xwOBA: 0.298,
        totalPitches: 3245,
        avgFastballVelo: 95.2,
        maxFastballVelo: 98.7,
        avgSpinRate: 2320,
        whiffRate: 0.282,
        csw: 0.310,
        pitchMix: [
            PitchMixEntry(name: "4-Seam Fastball", count: 1102, percentage: 0.340,
                          avgVelocity: 95.2, avgSpinRate: 2380),
            PitchMixEntry(name: "Slider", count: 812, percentage: 0.250,
                          avgVelocity: 87.4, avgSpinRate: 2540),
            PitchMixEntry(name: "Changeup", count: 650, percentage: 0.200,
                          avgVelocity: 86.8, avgSpinRate: 1720),
            PitchMixEntry(name: "Sinker", count: 487, percentage: 0.150,
                          avgVelocity: 93.8, avgSpinRate: 2180),
            PitchMixEntry(name: "Curveball", count: 194, percentage: 0.060,
                          avgVelocity: 79.5, avgSpinRate: 2850),
        ]
    )
}
#endif
