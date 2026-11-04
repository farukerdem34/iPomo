# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

iPomo is a local-first Pomodoro timer, task/project planner, and focus-reporting macOS app. SwiftUI + AppKit, macOS 14+, Swift 6.1 toolchain. There are **no third-party dependencies, network code, accounts, analytics, or telemetry** — keep it that way. User data is one JSON file at `~/Library/Application Support/iPomo/data.json` with rolling backups beside it.

## Commands

```bash
swift test                                              # all tests (Swift Testing)
swift test --filter PlanningTests                       # one suite
swift test --filter TimerMathTests/stageDurations       # one test
IPOMO_SNAPSHOT_DIR=/tmp/ipomo-snapshots swift test --filter SnapshotTests  # opt-in PNG snapshots
swift build
swift run iPomo                                         # dev run; notifications are disabled (no bundle ID)
./scripts/run-app.sh [debug|release]                    # build bundle and open it
./scripts/build-app.sh release                          # dist/iPomo.app (ad-hoc signed)
IPOMO_ARCHS="arm64 x86_64" IPOMO_VERSION=1.2.3 IPOMO_BUILD=42 ./scripts/build-app.sh release
./scripts/make-dmg.sh                                   # dist/iPomo.dmg + .sha256
./scripts/smoke-check.sh                                # builds release, relaunches app, checks windows + crash reports
```

`smoke-check.sh` kills any running iPomo instance. CI (`.github/workflows/ci.yml`) runs `swift test`, then a universal build + DMG on pushes/PRs; `v*` tags publish a GitHub Release. PRs touching only Markdown skip CI.

## Architecture

### Targets

- `iPomoCore` — pure Foundation domain code: models, timer math, planning, reports, persistence. **Must never import SwiftUI or AppKit**, so it stays testable without a UI.
- `iPomoUI` — SwiftUI views, `AppModel` state/engine, AppKit bridges, design system.
- `iPomoApp` — only launches `iPomoRoot.main()`.

Tests use **Swift Testing** (`import Testing`, `@Suite`, `@Test`), not XCTest. `Tests/iPomoCoreTests/TestSupport.swift` provides a fixed UTC/en_US_POSIX calendar, deterministic dates, and task/session factories — use it instead of `Calendar.current` and `Date()` in core tests. App-model tests use a temporary `DatabaseStore` and are `@MainActor`.

### State and data flow

`AppModel` (`@MainActor`, `ObservableObject`) owns the single `database: AppDatabase` and is the only mutation path. Views are thin: they call `AppModel` intents and render; all pure logic lives in `iPomoCore`.

- `mutate { ... }` copies the database, applies the change, publishes it, and schedules a debounced save (0.4 s). Round completion saves immediately; scene deactivation and app termination call `flush()`.
- `AppModel+Timer.swift` is the timer engine; `AppModel+Reports.swift` is report/CSV/manual-entry logic.
- `AppDatabase.normalize()` repairs duplicate IDs, dangling project references, and clamps imported numbers. Normalization also runs during decoding.

### Timer state machine

`TimerSnapshot` stores `stage`, `isRunning`, `accumulatedSeconds`, `startedAt`, `focusRoundCount`, and `activeTaskID`. **Remaining time is always derived** via `TimerMath` — never count down in memory. This makes pause/sleep/relaunch share one code path.

- Finish is idempotent: record the session, credit the task if focus, advance `focusRoundCount`, select the next stage, clear running state, persist immediately.
- Restore: a running snapshot that is overdue finishes exactly once at its expected end; otherwise it resumes.
- Skip routes through `finishCurrentRound` (counts as completed). Reset/stage switch/task switch record a partial session instead.
- Auto-start is a cancellable 1.2 s `DispatchWorkItem`.
- Fractional estimates (`0 < estimatedPomodoros < 1`) scale the focus duration and the task credit.

### Persistence

`DatabaseStore` returns a `DatabaseLoadOutcome`: `.loaded`, `.fresh`, `.recovered`, `.unsupported`, or `.unreadable`. It writes pretty-printed, sorted-key, ISO-8601 JSON atomically; creates at most one backup per 24 h (keeps 7); moves corrupt files to `Backups/corrupt-*.json`.

**Never overwrite an unsupported or unreadable file.** In those outcomes `AppModel` enters read-only mode and skips saves until the user imports or resets. Import/export use the same `encode`/`decode` path; a newer `schemaVersion` is rejected with an error.

### Settings decoding

Every settings group implements `decodeIfPresent` defaults plus a `clamp()`. Add new settings the same way (`Sources/iPomoCore/Models/AppSettings.swift`) so older files remain readable without migrations; do not bump `schemaVersion` for additive settings. Unknown keys are ignored.

### Reports and planning

- Reports count only `.focus` sessions; bucket rules (today = one bucket, week = days, month = weeks, year = months) live in `ReportRange`. Sessions snapshot `taskTitle`/`projectName` so reports survive deletion.
- CSV escaping guards against spreadsheet formula injection by prefixing `= + - @` cells with `'`; the export path adds a UTF-8 BOM.
- `PlanningLogic` owns Today selection (`isFocusToday`, due today, overdue), `planSort`, and project progress. `FinishTimeCalculator` estimates remaining focus + break time including the round currently in progress.
- Core APIs take an injected `Calendar`; the app uses `AppModel.calendar`/`CalendarFactory` so the user's week-start setting is honored.

### UI composition

- `iPomoRoot` declares the main `Window`, `MenuBarExtra` (`.window` style), and `Settings` scene; all inject the current theme accent via `EnvironmentValues.editorialAccent`.
- `RootView` owns sheets, the task-switch alert, banner overlay, scene-phase flush, and conditional dark mode while running. Sidebar navigation is explicit buttons backed by `SidebarItem`.
- The "Warm Editorial" design system is `Sources/iPomoUI/Support/DesignSystem.swift`: use `DesignTokens` (8pt grid, dynamic light/dark colors), `Typography`, and the shared editorial controls instead of hardcoded colors/fonts. Spec: `docs/brand-spec.md`.
- Spacebar start/pause is a local `NSEvent` monitor that only acts on `MainWindowRegistry.window` and bails for text fields, sheets, modals, and controls.
- `NotificationManager` returns `nil` without `Bundle.main.bundleIdentifier` so `swift run` cannot crash; `SoundPlayer` uses built-in `NSSound` names (no shipped audio assets).

## Working conventions

- Keep each change focused; update `docs/` and README when behavior or workflows change.
- Any new mutation should go through `AppModel.mutate` and therefore be persisted automatically; never write the store directly from a view.
- Respect read-only mode (`dataIsReadOnly`) and never silently replace user data — use `backupIfNeeded(force:)` before import/reset.
- Cross-section drag reordering preserves existing `sortOrder` values; don't renumber globally.
- `private/` is gitignored analysis material and must never be published.

## Reference docs

`docs/ARCHITECTURE.md` is the deep architecture reference (domain model, timer transitions, persistence, reports, extension points). `docs/WORKFLOWS.md` covers every user workflow and keyboard shortcut; `docs/FEATURES.md` and `docs/brand-spec.md` cover product and visual design. `docs/VERIFICATION.md` records the last verification run.
