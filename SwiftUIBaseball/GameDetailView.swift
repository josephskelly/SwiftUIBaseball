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
    case number, name, ops, vsLeft, vsRight, gbPercent, fbPercent, hand
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
    @State private var statcastBatting: [Int: StatcastBatting] = [:]
    @State private var statcastPitching: [Int: StatcastPitching] = [:]
    @State private var statcastTask: Task<Void, Never>?
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
        .onChange(of: selectedRosterEntry) { _, newEntry in
            guard let entry = newEntry else { return }
            startStatcastLoading(prioritizeId: entry.id)
        }
        .onDisappear {
            statcastTask?.cancel()
        }
    }

    private var navigationTitle: String {
        let away = game.teams.away.team.name
        let home = game.teams.home.team.name
        return "\(away) @ \(home)"
    }

    // MARK: - Roster Grid

    /// Scrollable roster grid for the selected team side.
    ///
    /// Uses a `Grid` layout so that column alignment is automatic across
    /// section headers and data rows, eliminating manual frame-width matching.
    @ViewBuilder
    private func rosterList(for side: TeamSide) -> some View {
        let roster = side == .away ? awayRoster : homeRoster
        let pitchers = sorted(roster.filter { $0.position == .pitcher }, isPitcher: true)
        let positionPlayers = sorted(roster.filter { $0.position != .pitcher }, isPitcher: false)

        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 0) {
                if !positionPlayers.isEmpty {
                    rosterSection(title: "Position Players", entries: positionPlayers, isPitcher: false)
                }
                if !pitchers.isEmpty {
                    rosterSection(title: "Pitchers", entries: pitchers, isPitcher: true)
                }
            }
            .padding(.horizontal)
        }
        .sheet(item: $selectedRosterEntry) { entry in
            PlayerCardView(
                entry: entry,
                player: players[entry.id],
                stats: playerStats[entry.id],
                batterPlatoon: batterPlatoon[entry.id],
                pitcherPlatoon: pitcherPlatoon[entry.id],
                season: statsSeasonYear,
                preloadedStatcast: statcastBatting[entry.id],
                preloadedStatcastPitching: statcastPitching[entry.id]
            )
        }
    }

    /// Produces grid rows for a roster section: title, column headers, and data rows.
    @ViewBuilder
    private func rosterSection(title: String, entries: [RosterEntry], isPitcher: Bool) -> some View {
        // Section title — not inside a GridRow, so it spans all columns.
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 16)
            .padding(.bottom, 4)

        // Column headers
        GridRow {
            sortButton("#", field: .number)
                .gridColumnAlignment(.leading)

            sortButton("Name", field: .name)
                .gridColumnAlignment(.leading)

            if isWide {
                Color.clear
                    .gridCellUnsizedAxes([.horizontal, .vertical])

                sortButton("vL", field: .vsLeft, alignment: .trailing)
                    .gridColumnAlignment(.trailing)
                sortButton("vR", field: .vsRight, alignment: .trailing)
                    .gridColumnAlignment(.trailing)
            } else {
                Color.clear
                    .gridCellUnsizedAxes([.horizontal, .vertical])
                    .gridCellColumns(5)
            }

            sortButton("OPS", field: .ops, alignment: .trailing)
                .gridColumnAlignment(.trailing)

            if isWide {
                sortButton("GB%", field: .gbPercent, alignment: .trailing)
                    .gridColumnAlignment(.trailing)
                sortButton("FB%", field: .fbPercent, alignment: .trailing)
                    .gridColumnAlignment(.trailing)
            }

            sortButton("H", field: .hand, alignment: .trailing)
                .gridColumnAlignment(.trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

        // Data rows
        ForEach(entries) { entry in
            Divider()

            GridRow {
                Text("#\(entry.jerseyNumber ?? "-")")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Text(abbreviatedName(entry.person.fullName))

                if isWide {
                    Color.clear
                        .gridCellUnsizedAxes([.horizontal, .vertical])

                    splitOPSLabel(
                        isPitcher
                            ? pitcherPlatoon[entry.id]?.vsLeft?.ops
                            : batterPlatoon[entry.id]?.vsLeft?.ops,
                        prefix: "vL"
                    )
                    splitOPSLabel(
                        isPitcher
                            ? pitcherPlatoon[entry.id]?.vsRight?.ops
                            : batterPlatoon[entry.id]?.vsRight?.ops,
                        prefix: "vR"
                    )
                } else {
                    Color.clear
                        .gridCellUnsizedAxes([.horizontal, .vertical])
                        .gridCellColumns(5)
                }

                opsCell(entry: entry, isPitcher: isPitcher)

                if isWide {
                    statcastPercentCell(
                        isPitcher
                            ? statcastPitching[entry.id]?.gbPercent
                            : statcastBatting[entry.id]?.gbPercent
                    )
                    statcastPercentCell(
                        isPitcher
                            ? statcastPitching[entry.id]?.fbPercent
                            : statcastBatting[entry.id]?.fbPercent
                    )
                }

                Text(handednessLabel(entry: entry, isPitcher: isPitcher))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture { selectedRosterEntry = entry }
            .accessibilityAddTraits(.isButton)
            .accessibilityElement(children: .combine)
        }
    }

    /// OPS value cell for a roster grid row.
    @ViewBuilder
    private func opsCell(entry: RosterEntry, isPitcher: Bool) -> some View {
        let ops: Double? = if isPitcher {
            playerStats[entry.id]?.pitching?.ops
        } else {
            playerStats[entry.id]?.batting?.ops
        }
        if let ops {
            Text(formatOPS(ops))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        } else {
            Text("")
        }
    }

    /// Formatted percentage cell for Statcast batted-ball data (GB%, FB%).
    private func statcastPercentCell(_ value: Double?) -> some View {
        Text(formatPercent(value))
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(value == nil ? .tertiary : .secondary)
    }

    /// A tappable label that toggles sort direction for the given field.
    private func sortButton(
        _ label: String,
        field: SortField,
        alignment: Alignment = .leading
    ) -> some View {
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
            .frame(minWidth: 44, minHeight: 44, alignment: alignment)
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
            pitcherPlatoon: pitcherPlatoon,
            statcastBatting: statcastBatting,
            statcastPitching: statcastPitching
        )
    }

    // MARK: - Formatting

    private func splitOPSLabel(_ ops: Double?, prefix: String) -> some View {
        HStack {
            Text(prefix)
            Spacer()
            Text(ops.map { formatOPS($0) } ?? "—")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(ops == nil ? .tertiary : .secondary)
        .frame(maxWidth: 80)
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

        // Begin background Statcast loading after season stats are ready.
        startStatcastLoading()
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

    // MARK: - Background Statcast Loading

    /// Starts (or restarts) serial Statcast fetching for all roster entries.
    ///
    /// Savant's CSV endpoint is rate-limited, so requests run one at a time.
    /// If `prioritizeId` is provided, that player is fetched first so a
    /// freshly-opened player card gets data as quickly as possible.
    private func startStatcastLoading(prioritizeId: Int? = nil) {
        statcastTask?.cancel()
        let season = statsSeasonYear
        let allEntries = awayRoster + homeRoster

        statcastTask = Task {
            var ordered = allEntries
            if let priorityId = prioritizeId,
               let idx = ordered.firstIndex(where: { $0.id == priorityId }) {
                let entry = ordered.remove(at: idx)
                ordered.insert(entry, at: 0)
            }

            for entry in ordered {
                guard !Task.isCancelled else { return }

                let isPitcher = entry.position == .pitcher

                if isPitcher {
                    guard statcastPitching[entry.id] == nil else { continue }
                    if let cached = await StatsCache.shared.statcastPitching(
                        playerId: entry.id, season: season
                    ) {
                        statcastPitching[entry.id] = cached
                        continue
                    }
                    if let result = try? await SwiftBaseball
                        .statcastPitching(playerId: entry.id)
                        .season(season)
                        .fetch() {
                        guard !Task.isCancelled else { return }
                        statcastPitching[entry.id] = result
                        await StatsCache.shared.setStatcastPitching(
                            result, playerId: entry.id, season: season
                        )
                    }
                } else {
                    guard statcastBatting[entry.id] == nil else { continue }
                    if let cached = await StatsCache.shared.statcast(
                        playerId: entry.id, season: season
                    ) {
                        statcastBatting[entry.id] = cached
                        continue
                    }
                    if let result = try? await SwiftBaseball
                        .statcastBatting(playerId: entry.id)
                        .season(season)
                        .fetch() {
                        guard !Task.isCancelled else { return }
                        statcastBatting[entry.id] = result
                        await StatsCache.shared.setStatcast(
                            result, playerId: entry.id, season: season
                        )
                    }
                }
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
    pitcherPlatoon: [Int: PitcherPlatoonStats],
    statcastBatting: [Int: StatcastBatting] = [:],
    statcastPitching: [Int: StatcastPitching] = [:]
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
            case .gbPercent:
                return isPitcher
                    ? statcastPitching[entry.id]?.gbPercent
                    : statcastBatting[entry.id]?.gbPercent
            case .fbPercent:
                return isPitcher
                    ? statcastPitching[entry.id]?.fbPercent
                    : statcastBatting[entry.id]?.fbPercent
            case .name, .hand:
                return nil  // not used for string fields
            }
        }

        // For numeric fields, pin nil values to the bottom regardless of direction.
        if field == .number || field == .ops || field == .vsLeft || field == .vsRight
            || field == .gbPercent || field == .fbPercent {
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
