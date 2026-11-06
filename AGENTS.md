# AGENTS.md

iPomo (repo `rea-pomofocus`) is a local-first Pomodoro timer, task/project planner, and
focus-reporting macOS app. SwiftUI + AppKit, macOS 14+, Swift 6.1 toolchain. There are
**no third-party dependencies**. The only outbound request is the optional GitHub update
check — do not add other network calls, accounts, analytics, or telemetry.

Detailed companion: `CLAUDE.md`. Deep architecture reference: `docs/ARCHITECTURE.md`.

## Commands

```bash
swift test                                              # all tests
swift test --filter PlanningTests                       # one suite
swift test --filter TimerMathTests/stageDurations       # one test
IPOMO_SNAPSHOT_DIR=/tmp/ipomo-snapshots swift test --filter SnapshotTests  # opt-in PNGs
swift build
swift run iPomo                                         # dev run; notifications/update checks disabled
./scripts/run-app.sh [debug|release]                    # build bundle and open it
./scripts/build-app.sh release                          # dist/iPomo.app (ad-hoc signed)
IPOMO_ARCHS="arm64 x86_64" IPOMO_VERSION=1.2.3 IPOMO_BUILD=42 ./scripts/build-app.sh release
./scripts/make-dmg.sh                                   # dist/iPomo.dmg + .sha256
./scripts/smoke-check.sh                                # builds release, relaunches app, checks windows + crash reports
```

- No linter/formatter/typecheck config exists; `swift test` is the verification gate.
- `swift run iPomo` has no bundle identifier, so notifications and update checks are
  disabled. Use `./scripts/run-app.sh` for anything bundle-dependent.
- `smoke-check.sh` **kills any running iPomo instance** before rebuilding and launching.
- `build-app.sh` reads the version from the nearest `v*` tag unless `IPOMO_VERSION` is set.

## Architecture

- `iPomoCore` — pure Foundation: models, timer math, planning, reports, persistence.
  **Must never import SwiftUI or AppKit.**
- `iPomoUI` — SwiftUI views, `AppModel` state/timer engine, AppKit bridges, design system.
- `iPomoApp` — only launches `iPomoRoot.main()`.

`AppModel` (`@MainActor`, `ObservableObject`) owns the single `AppDatabase` and is the only
mutation path. Views are thin: they call intents and render; pure logic lives in iPomoCore.

## Non-obvious invariants

- Remaining timer time is **always derived** via `TimerMath`; never count down in memory.
  Finish is idempotent. Skip counts as completed; reset/stage switch/task switch records a
  partial session.
- All mutations go through `AppModel.mutate`, which publishes then debounces saving (~0.4 s).
  Round completion saves immediately; scene deactivation/termination call `flush()`.
  Never write `DatabaseStore` directly from a view.
- `DatabaseStore.load()` returns `.loaded`, `.fresh`, `.recovered`, `.unsupported`, or
  `.unreadable`. On `.unsupported`/`.unreadable`, `AppModel` is read-only — never overwrite
  the file or silently replace user data.
- Settings groups decode with defaults plus `clamp()`. Add settings the same way; do not bump
  `schemaVersion` for additive fields.
- Core APIs take an injected `Calendar`; use `CalendarFactory`/`AppModel.calendar` so the
  user's week-start setting is honored.
- UI uses `DesignTokens`/`Typography` and shared editorial controls from
  `Sources/iPomoUI/Support/DesignSystem.swift`; avoid hardcoded colors and fonts.
  Visual spec: `docs/brand-spec.md`.
- Cross-section drag reordering preserves existing `sortOrder` values; don't renumber globally.
- Reports count only `.focus` sessions. Sessions snapshot `taskTitle`/`projectName` so reports
  survive deletion. CSV prefixes `= + - @` cells with `'` and adds a UTF-8 BOM.

## Tests

- Tests use **Swift Testing** (`import Testing`, `@Suite`, `@Test`), not XCTest.
- Core tests: use `Tests/iPomoCoreTests/TestSupport.swift` (fixed UTC/en_US_POSIX calendar and
  deterministic factories) instead of `Calendar.current` and `Date()`.
- App-model tests: `@MainActor`, temporary `DatabaseStore`.
- `SnapshotTests` only runs when `IPOMO_SNAPSHOT_DIR` is set. It renders PNGs for layout QA;
  it does not click or type.

## Repo and release conventions

- Commit style: `feat:`, `fix:`, `docs:`, `ci:`; one feature/fix per commit.
- Update the relevant file under `docs/` and the README when behavior or workflows change.
  `docs/VERIFICATION.md` records the last verification run.
- CI (`.github/workflows/ci.yml`) runs `swift test`, then a universal build + DMG on pushes to
  `master`/`v*` tags and on PRs (Markdown-only PRs are skipped).
- **Pushing a `v*` tag publishes a GitHub Release.** Only push a tag when intentionally cutting
  a release.
- `private/` is gitignored analysis material and must never be published. `.build/`, `dist/`,
  `.claude/`, `.agents/`, and `skills-lock.json` are also gitignored.
