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
        isLoading = true
        errorMessage = nil
        do {
            games = try await SwiftBaseball.schedule(.date(todayString)).fetch()
        } catch is CancellationError {
            // Refresh task was cancelled (e.g. the refreshable context was torn down);
            // leave existing games/error state intact rather than surfacing a spurious error.
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct GameRow: View {
    let game: ScheduleEntry

    /// True only when this team won outright (not a tie).
    /// The MLB API sets isWinner=true for both teams on a tied game,
    /// so we require exactly one winner before applying bold.
    private var awayWonOutright: Bool {
        game.teams.away.isWinner == true && game.teams.home.isWinner != true
    }

    private var homeWonOutright: Bool {
        game.teams.home.isWinner == true && game.teams.away.isWinner != true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(game.teams.away.team.name)
                    .fontWeight(awayWonOutright ? .bold : .regular)
                Spacer()
                if let score = game.teams.away.score {
                    Text("\(score)")
                        .monospacedDigit()
                        .fontWeight(awayWonOutright ? .bold : .regular)
                }
            }
            HStack {
                Text(game.teams.home.team.name)
                    .fontWeight(homeWonOutright ? .bold : .regular)
                Spacer()
                if let score = game.teams.home.score {
                    Text("\(score)")
                        .monospacedDigit()
                        .fontWeight(homeWonOutright ? .bold : .regular)
                }
            }
            HStack {
                Text(game.status.rawValue)
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
