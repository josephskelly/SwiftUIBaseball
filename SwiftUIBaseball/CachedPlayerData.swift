//
//  CachedPlayerData.swift
//  SwiftUIBaseball
//

import Foundation
import SwiftData
import SwiftBaseball

/// Persistent cache for per-player MLB data, keyed by player ID and season.
///
/// Stores encoded JSON blobs for player bio, season stats, platoon splits, and
/// Statcast metrics. JSON avoids flattening 50+ stat fields into SwiftData
/// columns — queries only use `playerId` and `season` as keys.
@Model
final class CachedPlayerData {

    /// Composite key `"playerId-season"` for unique constraint.
    @Attribute(.unique) var cacheKey: String

    /// MLB player ID.
    var playerId: Int

    /// Season year for the cached data.
    var season: Int

    /// Encoded ``Player`` bio data.
    var playerJSON: Data?

    /// Encoded ``PlayerSeasonStats``.
    var seasonStatsJSON: Data?

    /// Encoded ``PlayerPlatoonStats`` via ``CodablePlatoonStats``.
    var batterPlatoonJSON: Data?

    /// Encoded ``PitcherPlatoonStats`` via ``CodablePitcherPlatoonStats``.
    var pitcherPlatoonJSON: Data?

    /// Encoded ``StatcastBatting``.
    var statcastBattingJSON: Data?

    /// Encoded ``StatcastPitching``.
    var statcastPitchingJSON: Data?

    /// When this record was last updated.
    var updatedAt: Date

    /// Creates a cached player data record.
    ///
    /// - Parameters:
    ///   - playerId: MLB player ID.
    ///   - season: Season year.
    init(playerId: Int, season: Int) {
        self.cacheKey = "\(playerId)-\(season)"
        self.playerId = playerId
        self.season = season
        self.updatedAt = Date()
    }
}
