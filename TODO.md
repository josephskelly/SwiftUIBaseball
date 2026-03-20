//: TODO

[X] Jr. not a last name. Fixed. Also handles roman numerals

[X] tests take way too long on the simulator. Workaround; just do unit tests, no UI tests. UI test target removed from Xcode project.

[ ] Spray chart / batted ball visualization — Plot a player's batted balls on a field diagram using Statcast hit coordinates (the CSV data already includes hc_x and hc_y fields). Color-code by outcome (hit, out, HR). Demonstrates custom drawing with Canvas or Shape, data visualization skills, and creative use of an existing data source.

[ ] Fix bug where both teams show @ the other team. and you can click on a team but get their opponents roster. This happened with the giants and Rockies on THursday, Mar 19, 2026.

[ ] Confirm that the bug where user cannot interact or scroll for the first 20 seconds on a fresh Run was determined to be overhead from debugger. 

[X] Dodgers roster not loading right. THey didn't play today. its showing Hand, and GB% and FB% but nothing else. No way to force a refresh like a pull to refresh. Same issue with the Tigers who also did not play today. Teams that are playing today work as expected. Fixed: cache key was nil for teams without a game — now falls back to teamId.

[X] App crashed when i tried to go back from the Dodgers roster. Fixed: unbounded re-fetches from missing cache key caused the crash; teamId fallback enables caching.

[X] The very first initial load after a fresh install shows "No Teams" for a second before saying "Loading Teams." and then locking up for a bit. I'd like to show a list of all 30 teams immediately upon load after a fresh install. Fixed with two-tier persistent cache and hardcoded team seeds.

[X] Favorite Players lettering is blue instead of white. Fixed with .buttonStyle(.plain). 

[X] Favorite players don’t have MLB stats api data like Bio and season stats. Fixed — PlayerCardView now self-fetches when data is nil.

[ ] Spring Training sometimes has split squads where a team plays two games on the same day against different opponents. Home page UI does not handle this at all. There could also be doubleheaders and they could even be against different opponents in the regular season.

[] First long press on a team to bring up .contextmenu hangs for a few seconds.

[X] App doesn't build for macOS — Fixed. Wrapped iOS-only APIs with #if os(iOS) guards. Unit tests now run on macOS without the simulator.

[X] Tapping on a Favorite player button empty space does nothing. Fixed with .contentShape(Rectangle()) on the HStack.

[ ] In general, there's too much fetching going on. Can we stream data or should we just cache everything?

[ ] macos app has no icon.

[ ] macos app just says "No Teams. Pull to refresh..." Can't pull.

[ ] Two Way Player is only listed as a batter with only batting stats.

[X] Show game start time instead of "Scheduled" on home screen. Done.

[ ] Game detail should also show location and broadcast info. The "Final" and "In Progress" statuses still give the impression this data updates in real time when it doesn't.

[ ] Design note: Statcast data (StatcastBatting/StatcastPitching) stays L1-only because those types have internal-only memberwise initializers and can't be
  reconstructed from outside the SwiftBaseball module. The L2 cache handles the highest-impact types: player bio, season stats, and platoon splits. Deeper Exploration needed.

[X] Need a way to refresh the GameDetailView. Added pull-to-refresh on iOS and a toolbar refresh button on macOS.

[X] L2 cache poisoning: cancelled or failed API fetches created empty SwiftData records that masked as cache hits for 24 hours, preventing re-fetch of player bios and platoon splits. Fixed with guards in persistPlayer and cachedPlayer.

---

## Code Review: Data Loading Reliability & Performance (2026-03-20)

Root causes for slow loading and intermittent missing stats.

### Critical — Intermittent Missing Stats

[ ] **SwiftData thread-safety violations in StatsCache actor** — `StatsCache.swift:109-138, 152-185`
  `cachedPlayer()` and `persistPlayer()` create a new `ModelContext` per call inside the actor. `ModelContext` is not `Sendable` — running on the actor's executor causes cross-thread access. SwiftData silently returns stale or empty results. Upsert in `persistPlayer` has no transactional guarantee — concurrent calls for the same player can race. Fix: Use a single dedicated background `ModelContext` owned by the actor.

[ ] **Unbounded concurrent API requests in loadPlayerStats** — `GameDetailView.swift:584-639`
  `withTaskGroup` fires requests for every uncached player simultaneously (~78 HTTP requests for a 26-man roster). MLB Stats API rate-limits or drops connections; `try?` silently eats errors. Fix: Add concurrency throttle (max 5-8 concurrent) using a semaphore or chunked batching.

[ ] **Silent error swallowing everywhere** — `GameDetailView.swift:592,603,612,622` and `PlayerCardView.swift:191,194,204,213`
  Every API call uses `try?`, converting timeouts, rate limits, and transient errors to nil. Indistinguishable from "player has no stats." Fix: Distinguish transient errors from empty data; add at least one retry with backoff.

[ ] **L1 cache written with incomplete data after partial failures** — `GameDetailView.swift:524-536`
  L1 entry written after `loadPlayerStats`, which silently drops failed players. Cache now contains a "complete" entry that's actually missing data. Every subsequent visit returns incomplete cached data until app is killed. Fix: Track which players failed; don't cache the entry or mark it as partial so next visit re-fetches missing players.

[ ] **PlayerCardView guard skips re-fetch when partially loaded** — `PlayerCardView.swift:169`
  `guard player == nil && stats == nil` — if player is pre-populated but stats is nil (failed fetch), the card skips stats fetch entirely. Fix: Check each field independently so the card fetches whatever is missing.

### Performance

[ ] **Serial Statcast loading is extremely slow** — `GameDetailView.swift:649-706`
  One player at a time due to Savant rate limits → 26 sequential calls → 30-50 seconds. Users who navigate away never see GB%/FB% data. Fix: Load only visible players, or batch if the package supports it.

[ ] **Redundant DateFormatter creation on every render** — `ContentView.swift:51-55`
  `todayString` allocates a new `DateFormatter` on each computed property access. Fix: Use a static cached formatter.

[X] **Roster fetches are sequential, not concurrent** — `GameDetailView.swift:503-515`
  Primary and secondary roster fetched back-to-back. Fixed: uses `async let` to fetch both concurrently.

[X] **Cache key is nil for team-only navigation** — `GameDetailView.swift:131-136`
  `.team(_, _, let game): game?.id` returns nil when no game today. L1 cache never checked or written — every visit re-fetches from scratch. Fixed: `RosterSource.cacheKey` falls back to `teamId`.

### Architectural

[ ] **No MVVM — Views own all state and business logic**
  `ContentView`, `GameDetailView`, `PlayerCardView` contain `@State` dictionaries, networking, caching, and data transformation. State recreated when SwiftUI reconstructs the view. No way to share loading state between views. Pre-population pattern (7+ optional params) is fragile. Fix: Extract `@Observable` ViewModels.

[ ] **L2 cache creates a new ModelContext per operation** — `StatsCache.swift:116, 163`
  26 individual `persistPlayer` calls = 26 separate `context.save()` disk writes. Each context has its own in-memory graph — concurrent reads/writes see inconsistent state. Fix: Batch persistence or reuse a single background context.

[ ] **No retry or backoff strategy**
  When MLB API fails, data is missing for the rest of the session. Fix: Add retry with exponential backoff (at least 1 retry for transient errors).

[ ] **Task.detached in ContentView doesn't help** — `ContentView.swift:271-273`
  `loadScheduleInBackground` wraps in `Task.detached` but awaits `.value` on the main actor. The detached task doesn't improve responsiveness. Fix: Drop `Task.detached` since `.task` already runs off-main.
