//
//  GameDetailView.swift
//  SwiftUIBaseball
//
//  Created by Joseph Kelly on 3/16/26.
//

import SwiftUI
import SwiftBaseball

/// Column that the roster list can be sorted by.
enum SortField: String, CaseIterable {
    case number, name, ops, vsLeft, vsRight, hand
}

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
    @State private var sortField: SortField = .name
    @State private var sortAscending: Bool = true

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass)   private var verticalSizeClass
    private var isWide: Bool { horizontalSizeClass == .regular || verticalSizeClass == .compact }

    /// Use the game's own season, falling back to current calendar year.
    private var gameSeason: Int {
        Int(game.season) ?? Calendar.current.component(.year, from: Date())
    }

    /// The season year used for stats fetches — always matches the game's own season.
    private var statsSeasonYear: Int { gameSeason }

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
        .onChange(of: selectedTeam) {
            sortField = .name
            sortAscending = true
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
        let pitchers = sorted(roster.filter { $0.position == .pitcher }, isPitcher: true)
        let positionPlayers = sorted(roster.filter { $0.position != .pitcher }, isPitcher: false)

        List {
            if !positionPlayers.isEmpty {
                Section {
                    ForEach(positionPlayers) { entry in
                        Button { selectedRosterEntry = entry } label: {
                            rosterRow(entry: entry, isPitcher: false)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    rosterHeader(title: "Position Players", isPitcher: false)
                }
            }
            if !pitchers.isEmpty {
                Section {
                    ForEach(pitchers) { entry in
                        Button { selectedRosterEntry = entry } label: {
                            rosterRow(entry: entry, isPitcher: true)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    rosterHeader(title: "Pitchers", isPitcher: true)
                }
            }
        }
        .sheet(item: $selectedRosterEntry) { entry in
            PlayerCardView(
                entry: entry,
                player: players[entry.id],
                stats: playerStats[entry.id],
                batterPlatoon: batterPlatoon[entry.id],
                pitcherPlatoon: pitcherPlatoon[entry.id],
                season: statsSeasonYear
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

            Group {
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
            }
            .frame(width: 70, alignment: .trailing)

            Text(handednessLabel(entry: entry, isPitcher: isPitcher))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Column Header

    /// Tappable column header row that mirrors the layout of ``rosterRow(entry:isPitcher:)``.
    private func rosterHeader(title: String, isPitcher: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            HStack {
                sortButton("#", field: .number)
                    .frame(width: 40, alignment: .leading)

                sortButton("Name", field: .name)

                Spacer()

                if isWide {
                    HStack(spacing: 14) {
                        sortButton("vL", field: .vsLeft)
                            .frame(width: 80, alignment: .trailing)
                        sortButton("vR", field: .vsRight)
                            .frame(width: 80, alignment: .trailing)
                    }
                }

                sortButton("OPS", field: .ops)
                    .frame(width: 70, alignment: .trailing)

                sortButton("H", field: .hand)
                    .frame(width: 30, alignment: .trailing)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    /// A tappable label that toggles sort direction for the given field.
    private func sortButton(_ label: String, field: SortField) -> some View {
        Button {
            if sortField == field {
                sortAscending.toggle()
            } else {
                sortField = field
                sortAscending = true
            }
        } label: {
            HStack(spacing: 2) {
                Text(label)
                if sortField == field {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .imageScale(.small)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sortAccessibilityLabel(label, field: field))
    }

    /// Accessibility label describing the current sort state for a column header.
    private func sortAccessibilityLabel(_ label: String, field: SortField) -> String {
        if sortField == field {
            return "\(label), sorted \(sortAscending ? "ascending" : "descending")"
        }
        return "Sort by \(label)"
    }

    // MARK: - Sorting

    /// Returns roster entries sorted by the current ``sortField`` and ``sortAscending`` state.
    private func sorted(_ entries: [RosterEntry], isPitcher: Bool) -> [RosterEntry] {
        sortRoster(
            entries,
            by: sortField,
            ascending: sortAscending,
            isPitcher: isPitcher,
            playerStats: playerStats,
            players: players,
            batterPlatoon: batterPlatoon,
            pitcherPlatoon: pitcherPlatoon
        )
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
            awayRoster     = cached.awayRoster
            homeRoster     = cached.homeRoster
            players        = cached.players
            playerStats    = cached.playerStats
            batterPlatoon  = cached.batterPlatoon
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
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return
        }

        // Roster is ready — show the list now. Stats load in the background.
        isLoading = false

        let allEntries = awayRoster + homeRoster
        await loadPlayerStats(for: allEntries)

        // Cache after stats are complete so re-visits are instant and fully populated.
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
    }

    private func loadPlayerStats(for entries: [RosterEntry]) async {
        let season = statsSeasonYear
        let gameType = game.gameType
        await withTaskGroup(of: (Int, Player?, PlayerSeasonStats?, PlayerPlatoonStats?, PitcherPlatoonStats?).self) { group in
            for entry in entries {
                let isPitcher = entry.position == .pitcher
                group.addTask {
                    let statGroup: StatGroup = isPitcher ? .pitching : .batting
                    async let playerResult = SwiftBaseball.player(id: entry.id).fetch()

                    // Season stats filtered by game type
                    let stats = try? await SwiftBaseball
                        .playerStats(id: entry.id)
                        .season(season)
                        .group(statGroup)
                        .gameType(gameType)
                        .fetch().first

                    // Platoon splits filtered by game type
                    var bPlatoon: PlayerPlatoonStats?
                    var pPlatoon: PitcherPlatoonStats?
                    if isPitcher {
                        if let result = try? await SwiftBaseball
                            .pitcherPlatoonStats(id: entry.id)
                            .season(season)
                            .gameType(gameType)
                            .fetch(),
                           result.vsLeft?.ops != nil || result.vsRight?.ops != nil {
                            pPlatoon = result
                        }
                    } else {
                        if let result = try? await SwiftBaseball
                            .playerPlatoonStats(id: entry.id)
                            .season(season)
                            .gameType(gameType)
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

// MARK: - Roster Sorting

/// Sorts roster entries by the given field and direction.
///
/// Nil stat values always sort to the bottom regardless of sort direction.
/// This is a free function so it can be unit-tested independently of the view.
func sortRoster(
    _ entries: [RosterEntry],
    by field: SortField,
    ascending: Bool,
    isPitcher: Bool,
    playerStats: [Int: PlayerSeasonStats],
    players: [Int: Player],
    batterPlatoon: [Int: PlayerPlatoonStats],
    pitcherPlatoon: [Int: PitcherPlatoonStats]
) -> [RosterEntry] {
    entries.sorted { a, b in
        /// Extracts the optional value used for sorting a given entry.
        func optionalValue(_ entry: RosterEntry) -> Double? {
            switch field {
            case .number:
                return entry.jerseyNumber.flatMap(Double.init)
            case .ops:
                return opsValue(entry, isPitcher: isPitcher, stats: playerStats)
            case .vsLeft:
                return platoonOPS(entry, vsLeft: true, isPitcher: isPitcher,
                                  batter: batterPlatoon, pitcher: pitcherPlatoon)
            case .vsRight:
                return platoonOPS(entry, vsLeft: false, isPitcher: isPitcher,
                                  batter: batterPlatoon, pitcher: pitcherPlatoon)
            case .name, .hand:
                return nil  // not used for string fields
            }
        }

        // For numeric fields, pin nil values to the bottom regardless of direction.
        if field == .number || field == .ops || field == .vsLeft || field == .vsRight {
            let valA = optionalValue(a)
            let valB = optionalValue(b)
            switch (valA, valB) {
            case (nil, nil): return false
            case (_, nil): return true
            case (nil, _): return false
            case let (l?, r?):
                return ascending ? l < r : l > r
            }
        }

        // String-based fields (name, hand).
        let result: ComparisonResult
        switch field {
        case .name:
            let lastA = a.person.fullName.split(separator: " ").last.map(String.init)
                ?? a.person.fullName
            let lastB = b.person.fullName.split(separator: " ").last.map(String.init)
                ?? b.person.fullName
            result = lastA.localizedCaseInsensitiveCompare(lastB)
        case .hand:
            let handA = handLabel(a, isPitcher: isPitcher, players: players)
            let handB = handLabel(b, isPitcher: isPitcher, players: players)
            result = handA.compare(handB)
        default:
            return false
        }
        return ascending ? result == .orderedAscending : result == .orderedDescending
    }
}

/// Extracts the overall OPS for a roster entry from the stats dictionary.
private func opsValue(
    _ entry: RosterEntry, isPitcher: Bool, stats: [Int: PlayerSeasonStats]
) -> Double? {
    guard let s = stats[entry.id] else { return nil }
    return isPitcher ? s.pitching?.ops : s.batting?.ops
}

/// Extracts the platoon OPS for a roster entry.
private func platoonOPS(
    _ entry: RosterEntry, vsLeft: Bool, isPitcher: Bool,
    batter: [Int: PlayerPlatoonStats], pitcher: [Int: PitcherPlatoonStats]
) -> Double? {
    if isPitcher {
        let splits = pitcher[entry.id]
        return vsLeft ? splits?.vsLeft?.ops : splits?.vsRight?.ops
    } else {
        let splits = batter[entry.id]
        return vsLeft ? splits?.vsLeft?.ops : splits?.vsRight?.ops
    }
}

/// Handedness label for a roster entry.
private func handLabel(_ entry: RosterEntry, isPitcher: Bool, players: [Int: Player]) -> String {
    guard let player = players[entry.id] else { return "" }
    let hand = isPitcher ? player.pitchHand : player.batSide
    switch hand {
    case .left: return "L"
    case .right: return "R"
    case .both: return "S"
    case .unknown: return ""
    }
}

/// Compares two optional doubles, sorting nil values to the bottom.
func compareOptionalDoubles(_ lhs: Double?, _ rhs: Double?) -> ComparisonResult {
    switch (lhs, rhs) {
    case let (l?, r?):
        if l < r { return .orderedAscending }
        if l > r { return .orderedDescending }
        return .orderedSame
    case (_?, nil):
        return .orderedAscending
    case (nil, _?):
        return .orderedDescending
    case (nil, nil):
        return .orderedSame
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
