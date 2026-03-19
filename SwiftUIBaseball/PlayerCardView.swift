//
//  PlayerCardView.swift
//  SwiftUIBaseball
//

import SwiftUI
import SwiftBaseball

/// A modal card displaying all available data for a single player.
///
/// Presents biographical information, season statistics, and platoon splits
/// for the player identified by `entry`. All data is passed in at init time —
/// no additional network requests are made.
struct PlayerCardView: View {

    // MARK: - Properties

    /// The roster entry identifying the player and their position.
    let entry: RosterEntry
    /// Biographical data for the player, if available.
    let player: Player?
    /// Season statistics, if available.
    let stats: PlayerSeasonStats?
    /// Batter platoon splits (position players only), if available.
    let batterPlatoon: PlayerPlatoonStats?
    /// Pitcher platoon splits (pitchers only), if available.
    let pitcherPlatoon: PitcherPlatoonStats?
    /// The season year used to fetch Statcast data on demand.
    let season: Int

    @State private var statcast: StatcastBatting?
    @State private var isLoadingStatcast = false
    @Environment(\.dismiss) private var dismiss

    private var isPitcher: Bool { entry.position == .pitcher }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection

                    if let player {
                        bioSection(player)
                    }

                    if let stats {
                        seasonStatsSection(stats)
                    }

                    if batterPlatoon != nil || pitcherPlatoon != nil {
                        platoonSection
                    }

                    if let statcast {
                        statcastSection(statcast)
                    } else if isLoadingStatcast {
                        cardSection(title: "Statcast") {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }

                    if stats == nil && batterPlatoon == nil && pitcherPlatoon == nil && statcast == nil && !isLoadingStatcast {
                        cardSection(title: "Season Stats (\(season))") {
                            Text("No \(season) season stats available.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(entry.person.fullName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await loadStatcast() }
        }
    }

    // MARK: - Data Loading

    /// Fetches Statcast batted-ball data for position players on card appear.
    private func loadStatcast() async {
        guard !isPitcher else { return }
        if let cached = await StatsCache.shared.statcast(playerId: entry.id, season: season) {
            statcast = cached
            return
        }
        isLoadingStatcast = true
        if let result = try? await SwiftBaseball
            .statcastBatting(playerId: entry.id)
            .season(season)
            .fetch() {
            statcast = result
            await StatsCache.shared.setStatcast(result, playerId: entry.id, season: season)
        }
        isLoadingStatcast = false
    }

    // MARK: - Header

    /// Full name, jersey number, position, and handedness.
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.person.fullName)
                .font(.title2)
                .bold()

            HStack(spacing: 6) {
                if let jersey = entry.jerseyNumber {
                    Text("#\(jersey)")
                }
                Text("·")
                Text(entry.position.displayName)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let player {
                let handedness = handednessDescription(player)
                if !handedness.isEmpty {
                    Text(handedness)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Bio Section

    /// Biographical data: age, height/weight, birthplace, and debut date.
    private func bioSection(_ player: Player) -> some View {
        cardSection(title: "Bio") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                if let age = player.currentAge {
                    bioRow(label: "Age", value: "\(age)")
                }
                if let height = player.height, let weight = player.weight {
                    bioRow(label: "Height / Weight", value: "\(height) / \(weight) lbs")
                } else if let height = player.height {
                    bioRow(label: "Height", value: height)
                } else if let weight = player.weight {
                    bioRow(label: "Weight", value: "\(weight) lbs")
                }
                if let city = player.birthCity, let country = player.birthCountry {
                    bioRow(label: "Born", value: "\(city), \(country)")
                } else if let country = player.birthCountry {
                    bioRow(label: "Born", value: country)
                }
                if let debut = player.mlbDebutDate {
                    bioRow(
                        label: "MLB Debut",
                        value: debut.formatted(.dateTime.month(.abbreviated).day().year())
                    )
                }
            }
        }
    }

    /// A two-column label/value row for the bio grid.
    private func bioRow(label: String, value: String) -> some View {
        GridRow {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.leading)
            Text(value)
                .font(.subheadline)
                .gridColumnAlignment(.leading)
        }
    }

    // MARK: - Season Stats Section

    /// Season statistics in a three-column grid.
    private func seasonStatsSection(_ stats: PlayerSeasonStats) -> some View {
        cardSection(title: "Season Stats (\(stats.season))") {
            if isPitcher, let p = stats.pitching {
                statsGrid(pitchingCells(p))
            } else if let b = stats.batting {
                statsGrid(battingCells(b))
            }
        }
    }

    private func statsGrid(_ cells: [StatCell]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(cells) { cell in
                VStack(alignment: .leading, spacing: 2) {
                    Text(cell.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(cell.value)
                        .font(.subheadline)
                        .bold()
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Statcast Section

    /// Statcast batted-ball quality metrics in a three-column grid.
    private func statcastSection(_ sc: StatcastBatting) -> some View {
        cardSection(title: "Statcast") {
            statsGrid(statcastCells(sc))
        }
    }

    private func statcastCells(_ sc: StatcastBatting) -> [StatCell] {
        [
            StatCell("Avg EV",      formatVelocity(sc.avgExitVelocity)),
            StatCell("Max EV",      formatVelocity(sc.maxExitVelocity)),
            StatCell("Avg LA",      formatAngle(sc.avgLaunchAngle)),
            StatCell("Barrel%",     formatPercent(sc.barrelRate)),
            StatCell("HardHit%",    formatPercent(sc.hardHitRate)),
            StatCell("BBE",         "\(sc.battedBallEvents)"),
            StatCell("GB%",         formatPercent(sc.gbPercent)),
            StatCell("FB%",         formatPercent(sc.fbPercent)),
            StatCell("LD%",         formatPercent(sc.ldPercent)),
            StatCell("xBA",         sc.xBA.map { formatRate($0) } ?? "—"),
            StatCell("xSLG",        sc.xSLG.map { formatRate($0) } ?? "—"),
            StatCell("xwOBA",       sc.xwOBA.map { formatRate($0) } ?? "—"),
        ]
    }

    // MARK: - Platoon Splits Section

    /// Platoon splits as a small split table.
    private var platoonSection: some View {
        cardSection(title: "Platoon Splits") {
            if isPitcher, let splits = pitcherPlatoon {
                pitcherPlatoonGrid(splits)
            } else if let splits = batterPlatoon {
                batterPlatoonGrid(splits)
            }
        }
    }

    private func batterPlatoonGrid(_ splits: PlayerPlatoonStats) -> some View {
        VStack(spacing: 0) {
            platoonHeaderRow(labels: ["", "AVG", "OBP", "SLG", "OPS"])
            Divider()
            platoonBatterRow(label: "vs L", stats: splits.vsLeft)
            Divider()
            platoonBatterRow(label: "vs R", stats: splits.vsRight)
        }
    }

    private func pitcherPlatoonGrid(_ splits: PitcherPlatoonStats) -> some View {
        VStack(spacing: 0) {
            platoonHeaderRow(labels: ["", "ERA", "WHIP", "K", "OPS"])
            Divider()
            platoonPitcherRow(label: "vs L", stats: splits.vsLeft)
            Divider()
            platoonPitcherRow(label: "vs R", stats: splits.vsRight)
        }
    }

    private func platoonHeaderRow(labels: [String]) -> some View {
        HStack {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: label.isEmpty ? .leading : .trailing)
            }
        }
        .padding(.vertical, 4)
    }

    private func platoonBatterRow(label: String, stats: BattingStats?) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            platoonCell(stats?.avg.map { formatRate($0) })
            platoonCell(stats?.obp.map { formatRate($0) })
            platoonCell(stats?.slg.map { formatRate($0) })
            platoonCell(stats?.ops.map { formatRate($0) })
        }
        .padding(.vertical, 6)
    }

    private func platoonPitcherRow(label: String, stats: PitchingStats?) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            platoonCell(stats?.era.map { String(format: "%.2f", $0) })
            platoonCell(stats?.whip.map { String(format: "%.2f", $0) })
            platoonCell(stats?.strikeOuts.map { "\($0)" })
            platoonCell(stats?.ops.map { formatRate($0) })
        }
        .padding(.vertical, 6)
    }

    private func platoonCell(_ text: String?) -> some View {
        Text(text ?? "—")
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(text == nil ? .tertiary : .primary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Section Container

    /// Wraps content in a card with a section title.
    private func cardSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Stat Cells

    /// A label/value pair used in the season stats grid.
    private struct StatCell: Identifiable {
        let id: String
        let label: String
        let value: String

        /// Create a cell with a pre-formatted string value.
        init(_ label: String, _ value: String) {
            self.id = label; self.label = label; self.value = value
        }

        /// Create a cell from an optional integer, showing `"—"` when nil.
        init(_ label: String, _ intValue: Int?) {
            self.id = label; self.label = label
            self.value = intValue.map { "\($0)" } ?? "—"
        }
    }

    private func battingCells(_ b: BattingStats) -> [StatCell] {
        [
            StatCell("G",     b.gamesPlayed),
            StatCell("PA",    b.plateAppearances),
            StatCell("AB",    b.atBats),
            StatCell("H",     b.hits),
            StatCell("2B",    b.doubles),
            StatCell("3B",    b.triples),
            StatCell("HR",    b.homeRuns),
            StatCell("RBI",   b.rbi),
            StatCell("BB",    b.baseOnBalls),
            StatCell("K",     b.strikeOuts),
            StatCell("SB",    b.stolenBases),
            StatCell("CS",    b.caughtStealing),
            StatCell("AVG",   b.avg.map { formatRate($0) } ?? "—"),
            StatCell("OBP",   b.obp.map { formatRate($0) } ?? "—"),
            StatCell("SLG",   b.slg.map { formatRate($0) } ?? "—"),
            StatCell("OPS",   b.ops.map { formatRate($0) } ?? "—"),
            StatCell("BABIP", b.babip.map { formatRate($0) } ?? "—"),
        ]
    }

    private func pitchingCells(_ p: PitchingStats) -> [StatCell] {
        [
            StatCell("G",    p.gamesPlayed),
            StatCell("GS",   p.gamesStarted),
            StatCell("W",    p.wins),
            StatCell("L",    p.losses),
            StatCell("SV",   p.saves),
            StatCell("HLD",  p.holds),
            StatCell("IP",   p.inningsPitched.map { formatIP($0) } ?? "—"),
            StatCell("H",    p.hits),
            StatCell("R",    p.runs),
            StatCell("ER",   p.earnedRuns),
            StatCell("HR",   p.homeRuns),
            StatCell("BB",   p.baseOnBalls),
            StatCell("K",    p.strikeOuts),
            StatCell("HBP",  p.hitByPitch),
            StatCell("WP",   p.wildPitches),
            StatCell("ERA",  p.era.map { String(format: "%.2f", $0) } ?? "—"),
            StatCell("WHIP", p.whip.map { String(format: "%.2f", $0) } ?? "—"),
            StatCell("AVG",  p.avg.map { formatRate($0) } ?? "—"),
        ]
    }

    // MARK: - Formatting Helpers

    /// Returns a human-readable bats/throws description, e.g. `"Bats: Right · Throws: Right"`.
    private func handednessDescription(_ player: Player) -> String {
        let bats = handStr(player.batSide)
        let throws_ = handStr(player.pitchHand)
        switch (bats.isEmpty, throws_.isEmpty) {
        case (true, true):   return ""
        case (true, false):  return "Throws: \(throws_)"
        case (false, true):  return "Bats: \(bats)"
        case (false, false): return "Bats: \(bats) · Throws: \(throws_)"
        }
    }

    private func handStr(_ side: HandSide) -> String {
        switch side {
        case .left:    return "Left"
        case .right:   return "Right"
        case .both:    return "Switch"
        case .unknown: return ""
        }
    }
}

// MARK: - Previews

#Preview("Batter – Full Data") {
    PlayerCardView(
        entry: .previewBatter,
        player: .previewBatter,
        stats: .previewBatting,
        batterPlatoon: .preview,
        pitcherPlatoon: nil,
        season: 2024
    )
}

#Preview("Pitcher – Full Data") {
    PlayerCardView(
        entry: .previewPitcher,
        player: .previewPitcher,
        stats: .previewPitching,
        batterPlatoon: nil,
        pitcherPlatoon: .preview,
        season: 2023
    )
}

#Preview("No Stats") {
    PlayerCardView(
        entry: .previewBatter,
        player: nil,
        stats: nil,
        batterPlatoon: nil,
        pitcherPlatoon: nil,
        season: 2024
    )
}

#Preview("Dark Mode") {
    PlayerCardView(
        entry: .previewBatter,
        player: .previewBatter,
        stats: .previewBatting,
        batterPlatoon: .preview,
        pitcherPlatoon: nil,
        season: 2024
    )
    .preferredColorScheme(.dark)
}
