//
//  PlayerCardViewTests.swift
//  SwiftUIBaseballTests
//

import Testing
import SwiftBaseball
@testable import SwiftUIBaseball

struct PlayerCardViewTests {

    /// Verify the view initializes with a full batter data set.
    @Test func initializesWithFullBatterData() {
        let view = PlayerCardView(
            entry: .previewBatter,
            player: .previewBatter,
            stats: .previewBatting,
            batterPlatoon: .preview,
            pitcherPlatoon: nil,
            season: 2024
        )
        _ = view
    }

    /// Verify the view initializes with a full pitcher data set.
    @Test func initializesWithFullPitcherData() {
        let view = PlayerCardView(
            entry: .previewPitcher,
            player: .previewPitcher,
            stats: .previewPitching,
            batterPlatoon: nil,
            pitcherPlatoon: .preview,
            season: 2023
        )
        _ = view
    }

    /// Verify the view initializes gracefully when all optionals are nil.
    @Test func initializesWithNilOptionals() {
        let view = PlayerCardView(
            entry: .previewBatter,
            player: nil,
            stats: nil,
            batterPlatoon: nil,
            pitcherPlatoon: nil,
            season: 2024
        )
        _ = view
    }

    /// Verify the preview batter fixture has the expected identity.
    @Test func previewBatterFixtureHasExpectedId() {
        #expect(RosterEntry.previewBatter.id == 592450)
    }

    /// Verify the preview pitcher fixture has the expected identity.
    @Test func previewPitcherFixtureHasExpectedId() {
        #expect(RosterEntry.previewPitcher.id == 543037)
    }

    /// Verify the preview batting stats fixture decoded the season correctly.
    @Test func previewBattingStatsHasCorrectSeason() {
        #expect(PlayerSeasonStats.previewBatting.season == "2024")
    }

    /// Verify the preview pitching stats fixture decoded the season correctly.
    @Test func previewPitchingStatsHasCorrectSeason() {
        #expect(PlayerSeasonStats.previewPitching.season == "2023")
    }

    /// Verify the platoon batter fixture has non-nil splits.
    @Test func previewBatterPlatoonHasBothSplits() {
        let splits = PlayerPlatoonStats.preview
        #expect(splits.vsLeft != nil)
        #expect(splits.vsRight != nil)
    }

    /// Verify the platoon pitcher fixture has non-nil splits.
    @Test func previewPitcherPlatoonHasBothSplits() {
        let splits = PitcherPlatoonStats.preview
        #expect(splits.vsLeft != nil)
        #expect(splits.vsRight != nil)
    }

    /// Verify the statcast preview fixture has expected batted ball events.
    @Test func previewStatcastHasExpectedBBE() {
        #expect(StatcastBatting.preview.battedBallEvents == 392)
    }

    /// Verify statcast preview has non-nil quality-of-contact metrics.
    @Test func previewStatcastHasQualityMetrics() {
        let sc = StatcastBatting.preview
        #expect(sc.avgExitVelocity != nil)
        #expect(sc.maxExitVelocity != nil)
        #expect(sc.barrelRate != nil)
        #expect(sc.hardHitRate != nil)
        #expect(sc.xBA != nil)
        #expect(sc.xSLG != nil)
        #expect(sc.xwOBA != nil)
    }
}
