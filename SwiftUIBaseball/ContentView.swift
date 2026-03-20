//
//  ContentView.swift
//  SwiftUIBaseball
//
//  Created by Joseph Kelly on 3/16/26.
//

import SwiftUI
import SwiftData
import SwiftBaseball

/// Lightweight navigation value — destinations created lazily via `.navigationDestination`.
private struct TeamNavValue: Hashable {
    let teamId: Int
    let teamName: String
}

struct ContentView: View {
    @Query(sort: \FavoriteItem.name) private var allFavorites: [FavoriteItem]
    @Query(sort: \CachedTeam.name) private var cachedTeams: [CachedTeam]
    @Environment(\.modelContext) private var modelContext

    @State private var games: [ScheduleEntry] = []
    @State private var isLoadingTeams = false
    @State private var selectedFavoritePlayer: FavoriteItem?

    /// Favorite teams filtered from the single `@Query`.
    private var favoriteTeams: [FavoriteItem] {
        allFavorites.filter { $0.kind == .team }
    }

    /// Favorite players filtered from the single `@Query`.
    private var favoritePlayers: [FavoriteItem] {
        allFavorites.filter { $0.kind == .player }
    }

    /// Set of favorited team IDs for quick lookup.
    private var favoriteTeamIds: Set<Int> {
        Set(favoriteTeams.map(\.entityId))
    }

    /// Teams grouped by division in canonical order.
    private var teamsByDivision: [(division: String, teams: [CachedTeam])] {
        let grouped = Dictionary(grouping: cachedTeams, by: \.divisionName)
        return CachedTeam.divisionOrder.compactMap { division in
            guard let teams = grouped[division], !teams.isEmpty else { return nil }
            let shortName = teams.first?.divisionShortName ?? division
            return (shortName, teams.sorted { $0.name < $1.name })
        }
    }

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            Group {
                if cachedTeams.isEmpty && isLoadingTeams {
                    ProgressView("Loading teams…")
                } else if cachedTeams.isEmpty {
                    ContentUnavailableView(
                        "No Teams",
                        systemImage: "sportscourt",
                        description: Text("Pull to refresh to load MLB teams.")
                    )
                } else {
                    teamsList
                }
            }
            .navigationTitle("Teams")
            .navigationDestination(for: TeamNavValue.self) { nav in
                GameDetailView(teamId: nav.teamId, teamName: nav.teamName, game: gameForTeam(nav.teamId))
            }
            .task { await loadTeamsIfNeeded() }
            .task { await loadScheduleInBackground() }
            .refreshable {
                async let teams: () = refreshTeams()
                async let schedule: () = loadScheduleInBackground()
                _ = await (teams, schedule)
            }
            .sheet(item: $selectedFavoritePlayer) { favorite in
                if let entry = favorite.asRosterEntry {
                    PlayerCardView(
                        entry: entry,
                        player: nil,
                        stats: nil,
                        batterPlatoon: nil,
                        pitcherPlatoon: nil,
                        season: Calendar.current.component(.year, from: Date()),
                        preloadedStatcast: nil,
                        preloadedStatcastPitching: nil,
                        teamName: favorite.teamName
                    )
                }
            }
        }
    }

    // MARK: - Teams List

    /// The main list with favorites sections and all teams grouped by division.
    private var teamsList: some View {
        List {
            if !favoriteTeams.isEmpty {
                Section("Favorites") {
                    ForEach(favoriteTeams) { team in
                        teamRow(teamId: team.entityId, name: team.name, isFavoriteSection: true)
                    }
                }
            }

            if !favoritePlayers.isEmpty {
                Section("Favorite Players") {
                    ForEach(favoritePlayers) { player in
                        favoritePlayerRow(player)
                    }
                }
            }

            ForEach(teamsByDivision, id: \.division) { division, teams in
                Section(division) {
                    ForEach(teams, id: \.teamId) { team in
                        teamRow(teamId: team.teamId, name: team.name, isFavoriteSection: false)
                    }
                }
            }
        }
    }

    // MARK: - Row Builders

    /// A row for a team, navigating to its roster. Shows game status if playing today.
    private func teamRow(teamId: Int, name: String, isFavoriteSection: Bool) -> some View {
        let matchingGame = gameForTeam(teamId)
        let isFav = favoriteTeamIds.contains(teamId)

        return NavigationLink(value: TeamNavValue(teamId: teamId, teamName: name)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(name)
                        if isFav && !isFavoriteSection {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                    if let game = matchingGame {
                        Text(gameDescription(teamId: teamId, game: game))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .contextMenu {
            Button {
                FavoriteItem.toggle(kind: .team, entityId: teamId, name: name, in: modelContext)
            } label: {
                Label(
                    isFav ? "Unfavorite \(name)" : "Favorite \(name)",
                    systemImage: isFav ? "star.slash" : "star"
                )
            }
        }
    }

    /// A row for a favorited player, tapping opens a PlayerCardView sheet.
    private func favoritePlayerRow(_ player: FavoriteItem) -> some View {
        Button {
            selectedFavoritePlayer = player
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    HStack(spacing: 4) {
                        if let pos = player.position {
                            Text(pos)
                        }
                        if let team = player.teamName {
                            Text("·")
                            Text(team)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if let jersey = player.jerseyNumber {
                    Text("#\(jersey)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(player)
            } label: {
                Label("Remove from Favorites", systemImage: "star.slash")
            }
        }
    }

    // MARK: - Helpers

    /// Finds today's game for a team, if any.
    private func gameForTeam(_ teamId: Int) -> ScheduleEntry? {
        games.first {
            $0.teams.away.team.id == teamId || $0.teams.home.team.id == teamId
        }
    }

    /// Builds a short game description, e.g. "vs Red Sox · Scheduled".
    private func gameDescription(teamId: Int, game: ScheduleEntry) -> String {
        let isHome = game.teams.home.team.id == teamId
        let opponent = isHome ? game.teams.away.team.name : game.teams.home.team.name
        let prefix = isHome ? "vs" : "@"
        return "\(prefix) \(opponent) · \(game.status.displayText)"
    }

    // MARK: - Data Loading

    /// Loads teams from SwiftData cache on first launch only.
    private func loadTeamsIfNeeded() async {
        guard cachedTeams.isEmpty else { return }
        isLoadingTeams = true
        await refreshTeams()
        isLoadingTeams = false
    }

    /// Fetches all MLB teams from the API and upserts into SwiftData on a background context.
    ///
    /// The entire network call and SwiftData upsert run inside a detached task
    /// so no work executes on the main actor.
    private func refreshTeams() async {
        let container = modelContext.container
        let season = Calendar.current.component(.year, from: Date())
        await Task.detached {
            guard let teams = try? await SwiftBaseball.teams(.all(season: season)).fetch() else { return }
            let bgContext = ModelContext(container)
            for team in teams {
                let id = team.id
                let descriptor = FetchDescriptor<CachedTeam>(
                    predicate: #Predicate { $0.teamId == id }
                )
                if let existing = try? bgContext.fetch(descriptor).first {
                    existing.name = team.name
                    existing.abbreviation = team.abbreviation
                    existing.divisionName = team.division.name
                    existing.leagueName = team.league.name
                    existing.venueName = team.venue.name
                    existing.updatedAt = Date()
                } else {
                    bgContext.insert(CachedTeam(
                        teamId: team.id,
                        name: team.name,
                        abbreviation: team.abbreviation,
                        divisionName: team.division.name,
                        leagueName: team.league.name,
                        venueName: team.venue.name
                    ))
                }
            }
            try? bgContext.save()
        }.value
    }

    /// Loads today's schedule in the background without blocking the main actor.
    private func loadScheduleInBackground() async {
        let today = todayString
        guard let result = try? await Task.detached(operation: {
            try await SwiftBaseball.schedule(.date(today)).fetch()
        }).value else { return }
        games = result
    }
}

private extension GameStatus {
    /// Display label for use in the UI.
    var displayText: String {
        switch self {
        case .final, .completedEarly, .gameOver: "Final"
        default: rawValue
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FavoriteItem.self, CachedTeam.self], inMemory: true)
}
