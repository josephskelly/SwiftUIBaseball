//
//  ContentView.swift
//  SwiftUIBaseball
//
//  Created by Joseph Kelly on 3/16/26.
//

import SwiftUI
import SwiftBaseball

struct ContentView: View {
    @State private var games: [ScheduleEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

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
                } else if games.isEmpty {
                    ContentUnavailableView(
                        "No Games Today",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("There are no MLB games scheduled for today.")
                    )
                } else {
                    List(games) { game in
                        NavigationLink(destination: GameDetailView(game: game)) {
                            GameRow(game: game)
                        }
                    }
                }
            }
            .navigationTitle("Today's Games")
            .task {
                await loadSchedule()
            }
            .refreshable {
                await loadSchedule()
            }
        }
    }

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
/// Scores and winner indicators are intentionally omitted.
struct GameRow: View {
    let game: ScheduleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(game.teams.away.team.name)
                Spacer()
            }
            HStack {
                Text(game.teams.home.team.name)
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
}
