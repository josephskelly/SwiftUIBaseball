//
//  ContentView.swift
//  SwiftUIBaseball
//
//  Created by Joseph Kelly on 3/16/26.
//

import SwiftUI
import SwiftData
import SwiftBaseball

struct ContentView: View {
    @State private var games: [ScheduleEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedFavoritePlayer: FavoriteItem?

    @Query(sort: \FavoriteItem.name) private var allFavorites: [FavoriteItem]
    @Environment(\.modelContext) private var modelContext

    /// Favorite teams filtered from the single `@Query`.
    private var favoriteTeams: [FavoriteItem] {
        allFavorites.filter { $0.kind == .team }
    }

    /// Favorite players filtered from the single `@Query`.
    private var favoritePlayers: [FavoriteItem] {
        allFavorites.filter { $0.kind == .player }
    }

    /// Set of favorited team IDs for quick lookup in game rows.
    private var favoriteTeamIds: Set<Int> {
        Set(favoriteTeams.map(\.entityId))
    }

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading schedule…")
                } else if let errorMessage {
                    ContentUnavailableView(
                        "Unable to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if games.isEmpty && allFavorites.isEmpty {
                    ContentUnavailableView(
                        "No Games Today",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("There are no MLB games scheduled for today.")
                    )
                } else {
                    scheduleList
                }
            }
            .navigationTitle("Today's Games")
            .task {
                await loadSchedule()
            }
            .refreshable {
                await loadSchedule()
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

    // MARK: - Schedule List

    /// The main list with optional Favorites sections above Today's Games.
    private var scheduleList: some View {
        List {
            if !favoriteTeams.isEmpty {
                Section("Favorite Teams") {
                    ForEach(favoriteTeams) { team in
                        favoriteTeamRow(team)
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

            Section("Today's Games") {
                ForEach(games) { game in
                    NavigationLink(destination: GameDetailView(game: game)) {
                        GameRow(game: game, favoriteTeamIds: favoriteTeamIds)
                    }
                    .contextMenu {
                        teamContextMenuButtons(for: game)
                    }
                }
            }
        }
    }

    // MARK: - Favorite Rows

    /// A row for a favorited team, linking to its game if playing today.
    @ViewBuilder
    private func favoriteTeamRow(_ team: FavoriteItem) -> some View {
        let matchingGame = games.first {
            $0.teams.away.team.id == team.entityId ||
            $0.teams.home.team.id == team.entityId
        }
        if let game = matchingGame {
            NavigationLink(destination: GameDetailView(game: game)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                    Text(gameDescription(for: team, in: game))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contextMenu {
                unfavoriteButton(team)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(team.name)
                Text("No game today")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contextMenu {
                unfavoriteButton(team)
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
            unfavoriteButton(player)
        }
    }

    /// Builds a short game description for a favorited team, e.g. "vs Red Sox · Scheduled".
    private func gameDescription(for team: FavoriteItem, in game: ScheduleEntry) -> String {
        let isHome = game.teams.home.team.id == team.entityId
        let opponent = isHome ? game.teams.away.team.name : game.teams.home.team.name
        let prefix = isHome ? "vs" : "@"
        return "\(prefix) \(opponent) · \(game.status.displayText)"
    }

    // MARK: - Context Menus

    /// Context menu buttons offering to favorite/unfavorite both teams in a game.
    @ViewBuilder
    private func teamContextMenuButtons(for game: ScheduleEntry) -> some View {
        let awayId = game.teams.away.team.id
        let awayName = game.teams.away.team.name
        let homeId = game.teams.home.team.id
        let homeName = game.teams.home.team.name

        let awayIsFav = FavoriteItem.isFavorited(entityId: awayId, in: modelContext)
        let homeIsFav = FavoriteItem.isFavorited(entityId: homeId, in: modelContext)

        Button {
            FavoriteItem.toggle(kind: .team, entityId: awayId, name: awayName, in: modelContext)
        } label: {
            Label(
                awayIsFav ? "Unfavorite \(awayName)" : "Favorite \(awayName)",
                systemImage: awayIsFav ? "star.slash" : "star"
            )
        }

        Button {
            FavoriteItem.toggle(kind: .team, entityId: homeId, name: homeName, in: modelContext)
        } label: {
            Label(
                homeIsFav ? "Unfavorite \(homeName)" : "Favorite \(homeName)",
                systemImage: homeIsFav ? "star.slash" : "star"
            )
        }
    }

    /// An unfavorite button for use in favorite-row context menus.
    private func unfavoriteButton(_ item: FavoriteItem) -> some View {
        Button(role: .destructive) {
            modelContext.delete(item)
        } label: {
            Label("Remove from Favorites", systemImage: "star.slash")
        }
    }

    // MARK: - Data Loading

    private func loadSchedule() async {
        // Only show the loading spinner on a cold first load.
        // Re-appears and background refreshes update the list in place.
        if games.isEmpty {
            isLoading = true
        }
        errorMessage = nil
        do {
            games = try await SwiftBaseball.schedule(.date(todayString)).fetch()
        } catch is CancellationError {
            // Refresh task was cancelled (e.g. the refreshable context was torn down);
            // leave existing games/error state intact rather than surfacing a spurious error.
        } catch {
            // Only surface an error if there's nothing to show.
            if games.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
}

private extension GameStatus {
    /// Display label for use in the UI.
    /// All terminal states (final, completed early, game over) collapse to "Final"
    /// so the presentation is consistent regardless of how the game ended.
    var displayText: String {
        switch self {
        case .final, .completedEarly, .gameOver: "Final"
        default: rawValue
        }
    }
}

/// A spoiler-free row displaying two team names, game status, and venue.
///
/// Scores and winner indicators are intentionally omitted.
/// A small star icon appears next to favorited team names.
struct GameRow: View {
    let game: ScheduleEntry
    var favoriteTeamIds: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(game.teams.away.team.name)
                if favoriteTeamIds.contains(game.teams.away.team.id) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                Spacer()
            }
            HStack {
                Text(game.teams.home.team.name)
                if favoriteTeamIds.contains(game.teams.home.team.id) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                Spacer()
            }
            HStack {
                Text(game.status.displayText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let venue = game.venue {
                    Text("• \(venue.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: FavoriteItem.self, inMemory: true)
}
