//
//  GameDetailView.swift
//  SwiftUIBaseball
//
//  Created by Joseph Kelly on 3/16/26.
//

import SwiftUI
import SwiftBaseball

struct GameDetailView: View {
    let game: ScheduleEntry

    @State private var selectedTeam: TeamSide = .away
    @State private var awayRoster: [RosterEntry] = []
    @State private var homeRoster: [RosterEntry] = []
    @State private var playerStats: [Int: PlayerSeasonStats] = [:]
    @State private var players: [Int: Player] = [:]
    @State private var batterPlatoon: [Int: PlayerPlatoonStats] = [:]
    @State private var pitcherPlatoon: [Int: PitcherPlatoonStats] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedRosterEntry: RosterEntry?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass)   private var verticalSizeClass
    private var isWide: Bool { horizontalSizeClass == .regular || verticalSizeClass == .compact }

    /// Use the game's own season, falling back to current calendar year.
    private var gameSeason: Int {
        Int(game.season) ?? Calendar.current.component(.year, from: Date())
    }

    /// The season year to use as the primary stats source.
    ///
    /// Spring training rosters pre-date any regular-season stats, so fetching
    /// `gameSeason - 1` directly avoids a guaranteed wasted network request.
    /// All other game types (regular season, postseason, all-star) use `gameSeason`.
    private var statsSeasonYear: Int {
        game.gameType == .springTraining ? gameSeason - 1 : gameSeason
    }

    enum TeamSide: String, CaseIterable, Identifiable {
        case away, home
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Team", selection: $selectedTeam) {
                Text(game.teams.away.team.name).tag(TeamSide.away)
                Text(game.teams.home.team.name).tag(TeamSide.home)
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                if isLoading {
                    ProgressView("Loading rosters…")
                        .frame(maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView(
                        "Unable to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else {
                    rosterList(for: selectedTeam)
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadRosters()
        }
    }

    private var navigationTitle: String {
        let away = game.teams.away.team.name
        let home = game.teams.home.team.name
        return "\(away) @ \(home)"
    }

    // MARK: - Roster List

    @ViewBuilder
    private func rosterList(for side: TeamSide) -> some View {
        let roster = side == .away ? awayRoster : homeRoster
        let pitchers = roster
            .filter { $0.position == .pitcher }
            .sorted { lastName($0) < lastName($1) }
        let positionPlayers = roster
            .filter { $0.position != .pitcher }
            .sorted { lastName($0) < lastName($1) }

        List {
            if !positionPlayers.isEmpty {
                Section("Position Players") {
                    ForEach(positionPlayers) { entry in
                        Button { selectedRosterEntry = entry } label: {
                            rosterRow(entry: entry, isPitcher: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !pitchers.isEmpty {
                Section("Pitchers") {
                    ForEach(pitchers) { entry in
                        Button { selectedRosterEntry = entry } label: {
                            rosterRow(entry: entry, isPitcher: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(item: $selectedRosterEntry) { entry in
            PlayerCardView(
                entry: entry,
                player: players[entry.id],
                stats: playerStats[entry.id],
                batterPlatoon: batterPlatoon[entry.id],
                pitcherPlatoon: pitcherPlatoon[entry.id]
            )
        }
    }

    private func rosterRow(entry: RosterEntry, isPitcher: Bool) -> some View {
        HStack {
            Text("#\(entry.jerseyNumber ?? "-")")
                .monospacedDigit()
                .frame(width: 40, alignment: .leading)
                .foregroundStyle(.secondary)

            Text(abbreviatedName(entry.person.fullName))

            Spacer()

            if isWide {
                HStack(spacing: 14) {
                    if isPitcher {
                        splitOPSLabel(pitcherPlatoon[entry.id]?.vsLeft?.ops, prefix: "vL")
                        splitOPSLabel(pitcherPlatoon[entry.id]?.vsRight?.ops, prefix: "vR")
                    } else {
                        splitOPSLabel(batterPlatoon[entry.id]?.vsLeft?.ops, prefix: "vL")
                        splitOPSLabel(batterPlatoon[entry.id]?.vsRight?.ops, prefix: "vR")
                    }
                }
            }

            if isPitcher {
                if let stats = playerStats[entry.id],
                   let pitching = stats.pitching,
                   let ops = pitching.ops {
                    Text(formatOPS(ops))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            } else {
                if let stats = playerStats[entry.id],
                   let batting = stats.batting,
                   let ops = batting.ops {
                    Text(formatOPS(ops))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Text(handednessLabel(entry: entry, isPitcher: isPitcher))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Formatting

    private func splitOPSLabel(_ ops: Double?, prefix: String) -> some View {
        Text(ops.map { "\(prefix) \(formatOPS($0))" } ?? "\(prefix) —")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(ops == nil ? .tertiary : .secondary)
            .frame(width: 80, alignment: .trailing)
    }

    /// Returns the last whitespace-delimited word of a player's full name.
    private func lastName(_ entry: RosterEntry) -> String {
        entry.person.fullName.split(separator: " ").last.map(String.init) ?? entry.person.fullName
    }

    private func handednessLabel(entry: RosterEntry, isPitcher: Bool) -> String {
        guard let player = players[entry.id] else { return "" }
        let hand = isPitcher ? player.pitchHand : player.batSide
        switch hand {
        case .left: return "L"
        case .right: return "R"
        case .both: return "S"
        case .unknown: return ""
        }
    }

    // MARK: - Data Loading

    private func loadRosters() async {
        // Warm path: return immediately from cache.
        if let cached = await StatsCache.shared.entry(for: game.id) {
            awayRoster    = cached.awayRoster
            homeRoster    = cached.homeRoster
            players       = cached.players
            playerStats   = cached.playerStats
            batterPlatoon = cached.batterPlatoon
            pitcherPlatoon = cached.pitcherPlatoon
            return
        }

        isLoading = true
        errorMessage = nil

        let awayId = game.teams.away.team.id
        let homeId = game.teams.home.team.id

        do {
            async let awayResult = SwiftBaseball.roster(teamId: awayId, season: gameSeason).fetch()
            async let homeResult = SwiftBaseball.roster(teamId: homeId, season: gameSeason).fetch()
            awayRoster = try await awayResult
            homeRoster = try await homeResult

            // Fetch stats for all rostered players concurrently
            let allEntries = awayRoster + homeRoster
            await loadPlayerStats(for: allEntries)

            // Store results so re-visits are instant.
            await StatsCache.shared.set(
                StatsCache.Entry(
                    awayRoster: awayRoster,
                    homeRoster: homeRoster,
                    players: players,
                    playerStats: playerStats,
                    batterPlatoon: batterPlatoon,
                    pitcherPlatoon: pitcherPlatoon
                ),
                for: game.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadPlayerStats(for entries: [RosterEntry]) async {
        let season = statsSeasonYear
        await withTaskGroup(of: (Int, Player?, PlayerSeasonStats?, PlayerPlatoonStats?, PitcherPlatoonStats?).self) { group in
            for entry in entries {
                let isPitcher = entry.position == .pitcher
                group.addTask {
                    let statGroup: StatGroup = isPitcher ? .pitching : .batting
                    async let playerResult = SwiftBaseball.player(id: entry.id).fetch()

                    // Season stats — single fetch, no fallback
                    let stats = try? await SwiftBaseball
                        .playerStats(id: entry.id)
                        .season(season)
                        .group(statGroup)
                        .fetch().first

                    // Platoon splits — single fetch, no fallback
                    var bPlatoon: PlayerPlatoonStats?
                    var pPlatoon: PitcherPlatoonStats?
                    if isPitcher {
                        if let result = try? await SwiftBaseball
                            .pitcherPlatoonStats(id: entry.id)
                            .season(season)
                            .fetch(),
                           result.vsLeft?.ops != nil || result.vsRight?.ops != nil {
                            pPlatoon = result
                        }
                    } else {
                        if let result = try? await SwiftBaseball
                            .playerPlatoonStats(id: entry.id)
                            .season(season)
                            .fetch(),
                           result.vsLeft?.ops != nil || result.vsRight?.ops != nil {
                            bPlatoon = result
                        }
                    }

                    let player = try? await playerResult
                    return (entry.id, player, stats, bPlatoon, pPlatoon)
                }
            }
            for await (id, player, stats, bPlatoon, pPlatoon) in group {
                if let player { players[id] = player }
                if let stats { playerStats[id] = stats }
                if let bPlatoon { batterPlatoon[id] = bPlatoon }
                if let pPlatoon { pitcherPlatoon[id] = pPlatoon }
            }
        }
    }
}

// MARK: - Previews

#Preview("iPhone – Compact") {
    NavigationStack {
        GameDetailView(game: .preview)
    }
}

#Preview("iPhone – Landscape", traits: .landscapeLeft) {
    NavigationStack {
        GameDetailView(game: .preview)
    }
    .environment(\.verticalSizeClass, .compact)
}

#Preview("iPad – Wide") {
    NavigationStack {
        GameDetailView(game: .preview)
    }
    .environment(\.horizontalSizeClass, .regular)
}
