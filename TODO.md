//: TODO

[X] Jr. not a last name. Fixed. Also handles roman numerals

[X] tests take way too long on the simulator. Workaround; just do unit tests, no UI tests. UI test target removed from Xcode project.

[ ] Spray chart / batted ball visualization — Plot a player's batted balls on a field diagram using Statcast hit coordinates (the CSV data already includes hc_x and hc_y fields). Color-code by outcome (hit, out, HR). Demonstrates custom drawing with Canvas or Shape, data visualization skills, and creative use of an existing data source.

[ ] Fix bug where both teams show @ the other team. and you can click on a team but get their opponents roster. This happened with the giants and Rockies on THursday, Mar 19, 2026.

[ ] Confirm that the bug where user cannot interact or scroll for the first 20 seconds on a fresh Run was determined to be overhead from debugger. 

[ ] Dodgers roster not loading right. THey didn't play today. its showing Hand, and GB% and FB% but nothing else. No way to force a refresh like a pull to refresh. Same issue with the Tigers who also did not play today. Teams that are playing today work as expected.

[ ] App crashed when i tried to go back from the Dodgers roster.

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

[ ] Need a way to refresh the GameDetailView

[X] L2 cache poisoning: cancelled or failed API fetches created empty SwiftData records that masked as cache hits for 24 hours, preventing re-fetch of player bios and platoon splits. Fixed with guards in persistPlayer and cachedPlayer.
