# SwiftUIBaseball

A demo SwiftUI app showcasing the [SwiftBaseball](https://github.com/josephskelly/SwiftBaseball.git) Swift package. Displays live MLB schedule data, rosters, player stats, and Statcast metrics — all powered by SwiftBaseball's type-safe API wrappers around the public MLB Stats API and Baseball Savant.

## Features

- **Instant-loading home screen**: 30 MLB teams hardcoded as seed data and cached locally via SwiftData — the teams list renders immediately on fresh installs with no network wait. Background API refresh triggers only when data is older than 24 hours
- **Two-tier stats cache**: L1 in-memory actor cache for instant same-session access; L2 SwiftData persistence for player bio, season stats, and platoon splits that survive app restarts with a 24-hour TTL. Empty records from failed or cancelled fetches are rejected to prevent cache poisoning. L1 cache only stores complete rosters — partial data from rate-limited or failed API calls is excluded so re-visits re-fetch only the missing players. Teams not playing today use their team ID as the cache key, so rosters load from cache on revisit just like game-based rosters
- **Reliable API fetching**: roster stats load in chunks of 6 players to stay within MLB API rate limits, with automatic single-retry on transient errors; player cards independently fetch any data the roster load missed. When both home and away rosters are needed, they fetch concurrently via `async let`
- **Favorite player cards load instantly** for previously viewed players — bio, stats, and platoon splits are served from the persistent cache without network calls
- Teams list with today's game status shown inline — scheduled games display the start time in the device's local time zone (e.g. "7:05 PM") instead of a generic "Scheduled" label
- Tap any team to view its roster; if playing today, opponent roster available as a tab
- Per-player OPS stats (batting or pitching) matching the game type (spring training stats for spring training games, regular season for regular season, etc.)
- Sortable roster columns using a `Grid` layout: tap any column header (Name, OPS, vL, vR, Handedness) to sort ascending/descending with a chevron indicator
- GB% and FB% columns in the roster grid (landscape / wide layouts), loaded progressively from Baseball Savant in the background with player-card-open prioritization
- Statcast batted-ball data on batter cards: exit velocity, launch angle, barrel rate, hard-hit rate, batted-ball distribution, and expected stats (xBA, xSLG, xwOBA)
- Statcast pitching data on pitcher cards: batted-ball-against metrics, pitch arsenal (fastball velocity, spin rate, whiff%, CSW%), and pitch-mix breakdown by pitch type
- "No season stats available" fallback on player cards when the API returns no data (e.g. spring training rosters)
- Suffix-aware name formatting: "Fernando Tatis Jr." abbreviates to "F. Tatis Jr." (not "F. Jr."); long and accented names scale gracefully without wrapping
- Handedness indicator (L / R / S) for batters and pitchers
- Pull-to-refresh on the home screen and roster view bypasses cache to force fresh data from the network; macOS roster view has a toolbar refresh button
- **Favorites with SwiftData persistence**: long-press any team or player row to favorite; favorites surface at the top of the home screen with tappable player cards; star toggle on player cards; data persists across app launches

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 16.0 or later |
| Deployment target | iOS 17.0+ / macOS 14.0+ |
| Swift | 6.0+ |
| macOS (build machine) | Sonoma (14) or later |

## Dependencies

| Package | Source |
|---------|--------|
| [SwiftBaseball](https://github.com/josephskelly/SwiftBaseball.git) | Swift Package Manager (resolved from `main` branch) |

No API key is required — the app talks directly to the public MLB Stats API.

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/SwiftUIBaseball.git
cd SwiftUIBaseball
```

### 2. Open in Xcode

```bash
open SwiftUIBaseball.xcodeproj
```

Xcode will automatically resolve the `SwiftBaseball` Swift package dependency on first open. Wait for the **Package Resolution** to complete before building (status shown in the top toolbar).

### 3. Select a target

In Xcode's toolbar, select either:
- A **simulator** (e.g. iPhone 16 Pro) — no provisioning needed
- A **connected physical device** — see [Device Signing](#device-signing) below

### 4. Build and run

Press **⌘R** or click the Run button.

## Device Signing

To run on a physical iPhone or iPad:

1. In the Project navigator, select the **SwiftUIBaseball** project.
2. Go to **Signing & Capabilities**.
3. Check **Automatically manage signing**.
4. Set your **Team** to your personal Apple ID (free) or a paid developer account.
5. Change the **Bundle Identifier** to something unique (e.g. `com.yourname.SwiftUIBaseball`).

A free Apple ID allows sideloading to your own device for 7 days before re-signing is required.

## Project Structure

```
SwiftUIBaseball/
├── SwiftUIBaseball/
│   ├── SwiftUIBaseballApp.swift   # App entry point, SwiftData container setup
│   ├── ContentView.swift          # Teams list + favorites home screen
│   ├── GameDetailView.swift       # Roster + player stats (single team or game)
│   ├── PlayerCardView.swift       # Player detail modal (bio, stats, Statcast)
│   ├── FavoriteItem.swift         # SwiftData model for persisted favorites
│   ├── CachedTeam.swift           # SwiftData model for cached MLB teams + 30-team seed
│   ├── CachedPlayerData.swift     # SwiftData model for persistent player stats cache
│   ├── CodableWrappers.swift      # Codable bridges for non-Codable SwiftBaseball types
│   ├── StatsCache.swift           # Two-tier cache actor (L1 in-memory, L2 SwiftData)
│   ├── Formatters.swift           # OPS formatting, name abbreviation & suffix-aware helpers
│   └── PreviewHelpers.swift       # Mock data for SwiftUI previews
├── SwiftUIBaseballTests/          # Unit tests
└── SwiftUIBaseballUITests/        # UI tests
```

## Running Tests

```bash
# macOS (no simulator required)
xcodebuild test \
  -scheme SwiftUIBaseball \
  -destination 'platform=macOS' \
  -only-testing:SwiftUIBaseballTests

# iOS Simulator
xcodebuild test \
  -scheme SwiftUIBaseball \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:SwiftUIBaseballTests
```

Or press **⌘U** in Xcode.

## Disclaimer

This project is not affiliated with, endorsed by, or sponsored by Major League Baseball (MLB), Baseball Savant, or any MLB team. All MLB team names, logos, and trademarks are the property of their respective owners and are used here solely for informational purposes.

Player statistics, schedules, and Statcast data are retrieved from publicly available MLB Stats API and Baseball Savant endpoints. This data is provided by MLB and is subject to MLB's terms of use. This project is intended for personal, educational, and demonstration purposes only — not for commercial use.

Use of MLB data is governed by the [MLB Terms of Use](https://www.mlb.com/official-information/terms-of-use). Users of this project are responsible for ensuring their own compliance with those terms.
