# SwiftUIBaseball

A SwiftUI app that displays live MLB schedule data and roster information using the [MLB Stats API](https://statsapi.mlb.com).

## Features

- Today's MLB schedule with live scores and game status
- Game detail view with away/home roster tabs
- Per-player OPS stats (batting or pitching) for the current season, with prior-season fallback
- Statcast batted-ball data on player cards: exit velocity, launch angle, barrel rate, hard-hit rate, batted-ball distribution, and expected stats (xBA, xSLG, xwOBA)
- "No season stats available" fallback on player cards when the API returns no data (e.g. spring training rosters)
- Handedness indicator (L / R / S) for batters and pitchers
- In-memory stats cache: re-visiting a game detail is instant (no network round-trips)

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 16.0 or later |
| iOS deployment target | iOS 17.0+ |
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
│   ├── ContentView.swift          # Today's schedule list
│   ├── GameDetailView.swift       # Roster + player stats per game
│   ├── StatsCache.swift           # In-memory actor cache (keyed by gamePk)
│   ├── Formatters.swift           # OPS formatting, name abbreviation helpers
│   └── PreviewHelpers.swift       # Mock data for SwiftUI previews
├── SwiftUIBaseballTests/          # Unit tests
└── SwiftUIBaseballUITests/        # UI tests
```

## Running Tests

```bash
xcodebuild test \
  -scheme SwiftUIBaseball \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or press **⌘U** in Xcode.
