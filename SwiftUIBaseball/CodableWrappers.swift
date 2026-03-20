//
//  CodableWrappers.swift
//  SwiftUIBaseball
//

import Foundation
import SwiftBaseball

/// Codable wrappers for non-Codable SwiftBaseball platoon types.
///
/// These structs bridge ``PlayerPlatoonStats`` and ``PitcherPlatoonStats``
/// to JSON for SwiftData persistence via ``CachedPlayerData``. They mirror
/// the public properties of the original types and provide round-trip
/// conversion methods.

/// Codable mirror of ``PlayerPlatoonStats``.
struct CodablePlatoonStats: Sendable {
    /// Batting stats vs left-handed pitchers.
    let vsLeft: BattingStats?
    /// Batting stats vs right-handed pitchers.
    let vsRight: BattingStats?

    /// Wraps a ``PlayerPlatoonStats`` for encoding.
    nonisolated init(_ stats: PlayerPlatoonStats) {
        self.vsLeft = stats.vsLeft
        self.vsRight = stats.vsRight
    }

    /// Reconstructs the original model type.
    nonisolated var toModel: PlayerPlatoonStats {
        PlayerPlatoonStats(vsLeft: vsLeft, vsRight: vsRight)
    }
}

extension CodablePlatoonStats: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.vsLeft = try container.decodeIfPresent(BattingStats.self, forKey: .vsLeft)
        self.vsRight = try container.decodeIfPresent(BattingStats.self, forKey: .vsRight)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(vsLeft, forKey: .vsLeft)
        try container.encodeIfPresent(vsRight, forKey: .vsRight)
    }

    private enum CodingKeys: String, CodingKey {
        case vsLeft, vsRight
    }
}

/// Codable mirror of ``PitcherPlatoonStats``.
struct CodablePitcherPlatoonStats: Sendable {
    /// Pitching stats vs left-handed batters.
    let vsLeft: PitchingStats?
    /// Pitching stats vs right-handed batters.
    let vsRight: PitchingStats?

    /// Wraps a ``PitcherPlatoonStats`` for encoding.
    nonisolated init(_ stats: PitcherPlatoonStats) {
        self.vsLeft = stats.vsLeft
        self.vsRight = stats.vsRight
    }

    /// Reconstructs the original model type.
    nonisolated var toModel: PitcherPlatoonStats {
        PitcherPlatoonStats(vsLeft: vsLeft, vsRight: vsRight)
    }
}

extension CodablePitcherPlatoonStats: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.vsLeft = try container.decodeIfPresent(PitchingStats.self, forKey: .vsLeft)
        self.vsRight = try container.decodeIfPresent(PitchingStats.self, forKey: .vsRight)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(vsLeft, forKey: .vsLeft)
        try container.encodeIfPresent(vsRight, forKey: .vsRight)
    }

    private enum CodingKeys: String, CodingKey {
        case vsLeft, vsRight
    }
}
