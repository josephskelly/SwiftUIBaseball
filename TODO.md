//: TODO

[X] Jr. not a last name. Fixed. Also handles roman numerals

[X] tests take way too long on the simulator. Workaround; just do unit tests, no UI tests. UI test target removed from Xcode project.

[ ] Spray chart / batted ball visualization — Plot a player's batted balls on a field diagram using Statcast hit coordinates (the CSV data already includes hc_x and hc_y fields). Color-code by outcome (hit, out, HR). Demonstrates custom drawing with Canvas or Shape, data visualization skills, and creative use of an existing data source.

[ ] Fix bug where both teams show @ the other team. and you can click on a team but get their opponents roster. This happened with the giants and Rockies on THursday, Mar 19, 2026.

[ ] Confirm that the bug where user cannot interact or scroll for the first 20 seconds on a fresh Run was determined to be overhead from debugger. 

[ ] Dodgers roster not loading right. THey didn't play today. its showing Hand, and GB% and FB% but nothing else. No way to force a refresh like a pull to refresh. Same issue with the Tigers who also did not play today. Teams that are playing today work as expected.

[ ] App crashed when i tried to go back from the Dodgers roster.

[ ] The very first initial load after a fresh install shows "No Teams" for a second before saying "Loading Teams." and then locking up for a bit. I'd like to show a list of all 30 teams immediately upon load after a fresh install.

[X] Favorite Players lettering is blue instead of white. Fixed with .buttonStyle(.plain). Favorite players don’t have MLB stats api data like Bio and season stats.

[ ] Spring Training sometimes has split squads where a team plays two games on the same day against different opponents. Home page UI does not handle this at all. There could also be doubleheaders and they could even be against different opponents in the regular season.

[] First long press on a team to bring up .contextmenu hangs for a few seconds.

[X] App doesn't build for macOS — Fixed. Wrapped iOS-only APIs with #if os(iOS) guards. Unit tests now run on macOS without the simulator.
