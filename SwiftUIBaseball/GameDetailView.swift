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
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// Use the game's own season, falling back to current calendar year.
    private var gameSeason: Int {
        Int(game.season) ?? Calendar.current.component(.year, from: Date())
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
        let pitchers = roster.filter { $0.position == .pitcher }
        let positionPlayers = roster.filter { $0.position != .pitcher }

        List {
            if !positionPlayers.isEmpty {
                Section("Position Players") {
                    ForEach(positionPlayers) { entry in
                        rosterRow(entry: entry, isPitcher: false)
                    }
                }
            }
            if !pitchers.isEmpty {
                Section("Pitchers") {
                    ForEach(pitchers) { entry in
                        rosterRow(entry: entry, isPitcher: true)
                    }
                }
            }
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

    private func abbreviatedName(_ fullName: String) -> String {
        let parts = fullName.split(separator: " ")
        guard let first = parts.first, let last = parts.last, parts.count > 1 else {
            return fullName
        }
        return "\(first.prefix(1)). \(last)"
    }

    private func formatOPS(_ ops: Double) -> String {
        if ops >= 1.0 {
            return String(format: "%.3f OPS", ops)
        } else {
            return String(format: ".%03.0f OPS", ops * 1000)
        }
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
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadPlayerStats(for entries: [RosterEntry]) async {
        let season = gameSeason
        await withTaskGroup(of: (Int, Player?, PlayerSeasonStats?).self) { group in
            for entry in entries {
                let isPitcher = entry.position == .pitcher
                group.addTask {
                    let statGroup: StatGroup = isPitcher ? .pitching : .batting
                    async let playerResult = SwiftBaseball.player(id: entry.id).fetch()

                    // Try game season first, fall back to previous year
                    var stats: PlayerSeasonStats?
                    if let result = try? await SwiftBaseball
                        .playerStats(id: entry.id)
                        .season(season)
                        .group(statGroup)
                        .fetch().first {
                        stats = result
                    } else if let result = try? await SwiftBaseball
                        .playerStats(id: entry.id)
                        .season(season - 1)
                        .group(statGroup)
                        .fetch().first {
                        stats = result
                    }

                    let player = try? await playerResult
                    return (entry.id, player, stats)
                }
            }
            for await (id, player, stats) in group {
                if let player { players[id] = player }
                if let stats { playerStats[id] = stats }
            }
        }
    }
}
