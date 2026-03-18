# ~/Developer/SwiftUIBaseball/CLAUDE.md

import ~/.claude/CLAUDE_SWIFT_DEVELOPER.md

## Project Dependencies

- Use the swift package, [SwiftBaseball](https://github.com/josephskelly/SwiftBaseball.git), to fetch MLB stats.
- After pushing any changes to the SwiftBaseball repo, run the following in SwiftUIBaseball to advance Package.resolved to the new commit:
  ```bash
  xcodebuild -resolvePackageDependencies -project /Users/joe/Developer/SwiftUIBaseball/SwiftUIBaseball.xcodeproj
  ```
  Then commit and push the updated Package.resolved.

## Required Workflow After Every Code Change

These steps are **mandatory** after any code change, no exceptions:

1. **Unit tests** — Write or update XCTest unit tests covering the changed logic. New public methods, ViewModels, and Services must have test coverage.
2. **SwiftUI Previews** — Add or update `#Preview` macros for every changed or new View. Cover at minimum: default state, dark mode, and any loading/error/empty states.
3. **Documentation comments** — Add or update `///` DocC comments on all public and internal declarations touched by the change (see DocC section in the Swift reference above).
4. **README.md** — Update `README.md` to reflect any new features, changed behavior, setup steps, or architecture decisions. Keep it current.
5. **Commit** — Follow the commit convention from `~/.claude/CLAUDE_SWIFT_DEVELOPER.md` and the global `~/.claude/CLAUDE.md`:
   - One-line subject in imperative mood, ≤72 chars
   - Blank line, then a paragraph explaining *what* and *why*
   - `Co-Authored-By:` trailer
6. **Push** — Push the commit to the remote branch immediately after committing.

