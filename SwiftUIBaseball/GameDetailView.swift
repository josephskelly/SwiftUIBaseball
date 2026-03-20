//
//  GameDetailView.swift
//  SwiftUIBaseball
//
//  Created by Joseph Kelly on 3/16/26.
//

import SwiftUI
import SwiftData
import SwiftBaseball

/// Column that the roster list can be sorted by.
enum SortField: String, CaseIterable {
    case number, name, ops, vsLeft, vsRight, gbPercent, fbPercent, hand
}

/// How the roster view was entered — from a game or from a team.
enum RosterSource {
    /// Two-team game view (existing behavior).
    case game(ScheduleEntry)
    /// Single-team entry from the teams list, with an optional game for the opponent tab.
    case team(id: Int, name: String, game: ScheduleEntry?)
}

struct GameDetailView: View {
    let source: RosterSource

    /// Convenience init for navigating from a game (existing call sites).
    init(game: ScheduleEntry) {
        self.source = .game(game)
    }

    /// Convenience init for navigating from a team, with an optional game for opponent tab.
    init(teamId: Int, teamName: String, game: ScheduleEntry? = nil) {
        self.source = .team(id: teamId, name: teamName, game: game)
    }

    @State private var selectedSide: Int = 0
    @State private var primaryRoster: [RosterEntry] = []
    @State private var secondaryRoster: [RosterEntry] = []
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

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass)   private var verticalSizeClass
    private var isWide: Bool { horizontalSizeClass == .regular || verticalSizeClass == .compact }

    // MARK: - Source-derived Properties

    /// The primary team ID (the team the user navigated to, or the away team).
    private var primaryTeamId: Int {
        switch source {
        case .game(let entry): entry.teams.away.team.id
        case .team(let id, _, _): id
        }
    }

    /// The primary team name.
    private var primaryTeamName: String {
        switch source {
        case .game(let entry): entry.teams.away.team.name
        case .team(_, let name, _): name
        }
    }

    /// The secondary (opponent) team ID, if available.
    private var secondaryTeamId: Int? {
        switch source {
        case .game(let entry):
            return entry.teams.home.team.id
        case .team(let id, _, let game):
            guard let game else { return nil }
            // The opponent is whichever team is NOT the primary
            if game.teams.away.team.id == id {
                return game.teams.home.team.id
            } else {
                return game.teams.away.team.id
            }
        }
    }

    /// The secondary (opponent) team name, if available.
    private var secondaryTeamName: String? {
        switch source {
        case .game(let entry):
            return entry.teams.home.team.name
        case .team(let id, _, let game):
            guard let game else { return nil }
            if game.teams.away.team.id == id {
                return game.teams.home.team.name
            } else {
                return game.teams.away.team.name
            }
        }
    }

    /// Whether there is an opponent (i.e. whether the picker should show).
    private var hasOpponent: Bool { secondaryTeamId != nil }

    /// The season year for roster and stats fetches.
    private var seasonYear: Int {
        switch source {
        case .game(let entry):
            return Int(entry.season) ?? Calendar.current.component(.year, from: Date())
        case .team(_, _, let game):
            if let game { return Int(game.season) ?? Calendar.current.component(.year, from: Date()) }
            return Calendar.current.component(.year, from: Date())
        }
    }

    /// The game type filter for stats (e.g. `.regularSeason`).
    private var gameType: GameType {
        switch source {
        case .game(let entry): entry.gameType
        case .team(_, _, let game): game?.gameType ?? .regularSeason
        }
    }

    /// Cache key for the StatsCache (uses gamePk when available).
    private var cacheKey: Int? {
        switch source {
        case .game(let entry): entry.id
        case .team(_, _, let game): game?.id
        }
    }

    /// The team name for the currently selected roster side.
    private var selectedTeamName: String {
        selectedSide == 0 ? primaryTeamName : (secondaryTeamName ?? primaryTeamName)
    }

    var body: some View {
        VStack(spacing: 0) {
            if hasOpponent {
                Picker("Team", selection: $selectedSide) {
                    Text(primaryTeamName).tag(0)
                    Text(secondaryTeamName ?? "").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
            }

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
                    rosterList(primary: selectedSide == 0)
                }
            }
        }
        .navigationTitle(navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadRosters()
        }
        .onChange(of: selectedSide) {
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
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await refreshRosters() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
                .accessibilityLabel("Refresh roster data")
            }
        }
        #endif
    }

    private var navigationTitle: String {
        if let secondaryName = secondaryTeamName {
            return "\(primaryTeamName) @ \(secondaryName)"
        }
        return primaryTeamName
    }

    // MARK: - Roster Grid

    /// Scrollable roster grid for the selected team side.
    @ViewBuilder
    private func rosterList(primary: Bool) -> some View {
        let roster = primary ? primaryRoster : secondaryRoster
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
        .refreshable { await refreshRosters() }
        .sheet(item: $selectedRosterEntry) { entry in
            PlayerCardView(
                entry: entry,
                player: players[entry.id],
                stats: playerStats[entry.id],
                batterPlatoon: batterPlatoon[entry.id],
                pitcherPlatoon: pitcherPlatoon[entry.id],
                season: seasonYear,
                preloadedStatcast: statcastBatting[entry.id],
                preloadedStatcastPitching: statcastPitching[entry.id],
                teamName: selectedTeamName
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .gridColumnAlignment(.leading)

            if isWide {
                Color.clear
                    .gridCellUnsizedAxes([.horizontal, .vertical])

                sortButton("vL", field: .vsLeft, alignment: .trailing)
                    .gridColumnAlignment(.trailing)
                sortButton("vR", field: .vsRight, alignment: .trailing)
                    .gridColumnAlignment(.trailing)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
            .contextMenu { playerContextMenu(entry: entry) }
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

    // MARK: - Context Menu

    /// Context menu for a player row with a favorite/unfavorite action.
    @ViewBuilder
    private func playerContextMenu(entry: RosterEntry) -> some View {
        let isFav = FavoriteItem.isFavorited(entityId: entry.id, in: modelContext)

        Button {
            FavoriteItem.toggle(
                kind: .player,
                entityId: entry.id,
                name: entry.person.fullName,
                teamName: selectedTeamName,
                position: entry.position.displayName,
                positionCode: entry.position.rawValue,
                jerseyNumber: entry.jerseyNumber,
                in: modelContext
            )
        } label: {
            Label(
                isFav ? "Unfavorite \(abbreviatedName(entry.person.fullName))" : "Favorite \(abbreviatedName(entry.person.fullName))",
                systemImage: isFav ? "star.slash" : "star"
            )
        }
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

    /// Returns the family name of a player, ignoring generational suffixes.
    private func lastName(_ entry: RosterEntry) -> String {
        familyName(entry.person.fullName)
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
        if let key = cacheKey, let cached = await StatsCache.shared.entry(for: key) {
            primaryRoster  = cached.awayRoster
            secondaryRoster = cached.homeRoster
            players        = cached.players
            playerStats    = cached.playerStats
            batterPlatoon  = cached.batterPlatoon
            pitcherPlatoon = cached.pitcherPlatoon
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let primaryResult = try await SwiftBaseball.roster(teamId: primaryTeamId, season: seasonYear).fetch()
            primaryRoster = primaryResult

            if let secondaryId = secondaryTeamId {
                let secondaryResult = try await SwiftBaseball.roster(teamId: secondaryId, season: seasonYear).fetch()
                secondaryRoster = secondaryResult
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return
        }

        // Roster is ready — show the list now. Stats load in the background.
        isLoading = false

        let allEntries = primaryRoster + secondaryRoster
        await loadPlayerStats(for: allEntries)

        // Cache after stats are complete so re-visits are instant and fully populated.
        if let key = cacheKey {
            await StatsCache.shared.set(
                StatsCache.Entry(
                    awayRoster: primaryRoster,
                    homeRoster: secondaryRoster,
                    players: players,
                    playerStats: playerStats,
                    batterPlatoon: batterPlatoon,
                    pitcherPlatoon: pitcherPlatoon
                ),
                for: key
            )
        }

        // Begin background Statcast loading after season stats are ready.
        startStatcastLoading()
    }

    /// Evicts cached data and re-fetches rosters and player stats from the network.
    private func refreshRosters() async {
        statcastTask?.cancel()

        // Evict L1 entry so loadRosters bypasses the warm path.
        if let key = cacheKey {
            await StatsCache.shared.removeEntry(for: key)
        }

        // Clear all state so the view shows fresh data only.
        players = [:]
        playerStats = [:]
        batterPlatoon = [:]
        pitcherPlatoon = [:]
        statcastBatting = [:]
        statcastPitching = [:]
        primaryRoster = []
        secondaryRoster = []
        errorMessage = nil

        await loadRosters()
    }

    private func loadPlayerStats(for entries: [RosterEntry]) async {
        let season = seasonYear
        let gt = gameType

        // Partition into cached (from SwiftData L2) and uncached entries.
        var entriesToFetch: [RosterEntry] = []
        for entry in entries {
            if let cached = await StatsCache.shared.cachedPlayer(id: entry.id, season: season) {
                if let p = cached.player { players[entry.id] = p }
                if let s = cached.stats { playerStats[entry.id] = s }
                if let bp = cached.batterPlatoon { batterPlatoon[entry.id] = bp }
                if let pp = cached.pitcherPlatoon { pitcherPlatoon[entry.id] = pp }
            } else {
                entriesToFetch.append(entry)
            }
        }

        guard !entriesToFetch.isEmpty else { return }

        await withTaskGroup(of: (Int, Player?, PlayerSeasonStats?, PlayerPlatoonStats?, PitcherPlatoonStats?).self) { group in
            for entry in entriesToFetch {
                let isPitcher = entry.position == .pitcher
                group.addTask {
                    let statGroup: StatGroup = isPitcher ? .pitching : .batting
                    async let playerResult = SwiftBaseball.player(id: entry.id).fetch()

                    // Season stats filtered by game type
                    let stats = try? await SwiftBaseball
                        .playerStats(id: entry.id)
                        .season(season)
                        .group(statGroup)
                        .gameType(gt)
                        .fetch().first

                    // Platoon splits filtered by game type
                    var bPlatoon: PlayerPlatoonStats?
                    var pPlatoon: PitcherPlatoonStats?
                    if isPitcher {
                        if let result = try? await SwiftBaseball
                            .pitcherPlatoonStats(id: entry.id)
                            .season(season)
                            .gameType(gt)
                            .fetch(),
                           result.vsLeft?.ops != nil || result.vsRight?.ops != nil {
                            pPlatoon = result
                        }
                    } else {
                        if let result = try? await SwiftBaseball
                            .playerPlatoonStats(id: entry.id)
                            .season(season)
                            .gameType(gt)
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

                // Persist to SwiftData L2
                await StatsCache.shared.persistPlayer(
                    id: id, season: season,
                    player: player, stats: stats,
                    batterPlatoon: bPlatoon, pitcherPlatoon: pPlatoon
                )
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
        let season = seasonYear
        let allEntries = primaryRoster + secondaryRoster

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
            let lastA = familyName(a.person.fullName)
            let lastB = familyName(b.person.fullName)
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
    .modelContainer(for: FavoriteItem.self, inMemory: true)
}

#Preview("iPhone – Landscape", traits: .landscapeLeft) {
    NavigationStack {
        GameDetailView(game: .preview)
    }
    .environment(\.verticalSizeClass, .compact)
    .modelContainer(for: FavoriteItem.self, inMemory: true)
}

#Preview("iPad – Wide") {
    NavigationStack {
        GameDetailView(game: .preview)
    }
    .environment(\.horizontalSizeClass, .regular)
    .modelContainer(for: FavoriteItem.self, inMemory: true)
}

#Preview("Single Team") {
    NavigationStack {
        GameDetailView(teamId: 147, teamName: "New York Yankees")
    }
    .modelContainer(for: FavoriteItem.self, inMemory: true)
}
