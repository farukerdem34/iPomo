# iPomo

**A free, ad-free, local-first project planning and focus timer for macOS.**

iPomo is a native SwiftUI app for focus sessions and project planning. It keeps the parts that matter — timer, tasks, projects, search, reports, configuration — and has no remote web content, accounts, premium gates, ads, analytics, or third-party network dependencies. The only outbound request is the optional GitHub update check.

<p align="center">
  <img src="Resources/AppIcon-1024.png" alt="iPomo icon" width="160">
</p>

## Features

### Timer
- Focus, short break, and long break stages with defaults of 25 / 5 / 15 minutes and a long break every 4 focus rounds.
- Auto-start breaks and auto-start focus rounds.
- Start (also Space), pause, skip, reset round, reset cycle, and stage switching. Skipping counts the stage as completed: a focus skip credits the round and task, a break skip completes the break.
- **Fractional estimates:** a task estimated at `0.5` pomodoros gets a half-length focus round and receives `0.5` credit on completion.
- **Background-safe state:** a running round is persisted with its start timestamp. After sleep, quit, or relaunch, the app recomputes the remaining time and completes an overdue round exactly once.
- **Partial-session recording:** resetting, switching stages, or switching tasks records the focus time already spent instead of silently discarding it.
- Native menu-bar countdown and controls.
- Local notifications for round endings and optional in-round reminders.
- Built-in macOS alarm sounds and optional ticking; no bundled audio assets or network calls.

### Tasks
- Create, edit, duplicate, complete, delete, and reorder tasks.
- Title, notes, project, estimated pomodoros, priority, due date, and a "today" flag.
- Drag reordering inside each due-date section; search results keep relevance order.
- Search across titles, notes, and project names with consistent semantics:
  - searches every task, not a Todoist import modal;
  - splits on any whitespace, not only a single ASCII space;
  - never injects literal `"undefined"` / `"null"` for missing fields;
  - case-, diacritic-, and width-insensitive;
  - ranks title matches above project and note matches.
- Task scopes (Active / Completed) and project filters. Active shows all tasks, with completed tasks grouped in a Completed section at the bottom when enabled.
- Auto-check when an estimate is reached; move completed tasks into that Completed section.

### Projects
- Create, edit, archive, complete, and delete projects.
- Color, status, target date, details, and optional pomodoro target.
- Progress is computed from the project's tasks (estimated vs completed pomodoros).
- Open a project directly in the filtered task list.
- Deleting a project lets you keep its tasks (moved to No Project) or delete them; focus history is always retained.

### Reports
- Today, week, month, and year ranges, with a configurable week start.
- Focus time, sessions, active days, completed tasks, current streak, and longest streak.
- Native Swift Charts bar chart with day/week/month buckets.
- Project breakdown with share bars and per-project focus time.
- Session detail with manual entries, partial-session badges, and deletion.
- **CSV export** with date, start, end, task, project, stage, minutes, completed, and manual columns; UTF-8 BOM for Excel.
- Every report exists for every user: no login, premium, or network check.

### Configuration
- Timer durations, long-break interval, auto-start breaks/focus.
- Auto-check, move-completed-to-a-Completed-section, task-switch confirmation, partial-session recording.
- Alarm sound, volume, repeat count, focus (ticking) sound, volume, previews.
- Theme color, dark mode while running, 12/24-hour format, week start, menu-bar timer visibility.
- Notification permission, round-end notifications, reminder mode (`last`/`every`) and minutes.
- Default report range, daily focus goal, default task estimate, plan horizon.
- Optional update check against GitHub's latest release, with manual **Check for Updates…**.
- Data folder reveal, JSON backup export/import, full reset.

## Requirements

- macOS 14 or later.
- Swift 6.1 toolchain. The package builds with the Command Line Tools alone (no full Xcode required).
- No third-party Swift packages.

## Build and run

```bash
swift test                       # run the test suite (core, app model, opt-in snapshots)
./scripts/build-app.sh release   # builds dist/iPomo.app
open dist/iPomo.app
# or:
./scripts/run-app.sh release
```

To render the visual QA snapshots (light, dark, wide-window, sheets, and menu bar):

```bash
IPOMO_SNAPSHOT_DIR=/tmp/ipomo-snapshots swift test --filter SnapshotTests
```

For development:

```bash
swift build
swift test
swift run iPomo
```

You can also open `Package.swift` in Xcode to run and debug the same targets.

`scripts/build-app.sh` creates an ad-hoc-signed `.app` bundle with an `Info.plist` and icon. The bundle is unsigned for distribution; for sharing, sign with a Developer ID, add the App Sandbox entitlement if desired, and notarize.

## Data and privacy

- Database: `~/Library/Application Support/iPomo/data.json`.
- Backups: `~/Library/Application Support/iPomo/Backups/` (rolling, up to 7, plus corrupt-file quarantine).
- The database is human-readable JSON with ISO-8601 dates. It is unencrypted; use FileVault or a protected user account if the machine is shared.
- **No accounts, ads, analytics, telemetry, or third-party scripts. The optional GitHub update check is the only network request.**
- Notifications use the macOS local notification service; they never leave the machine.
- Import/export uses standard macOS file panels; nothing is uploaded.
- The current build is not sandboxed. Add App Sandbox entitlements before Mac App Store distribution.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘N | New task |
| ⇧⌘N | New project |
| Space | Start / pause timer (when not typing in a text field or dialog) |
| ⌥⌘P | Start / pause timer |
| ⇧⌘] | Skip stage (counts as completed) |
| ⇧⌘R | Reset current round |
| ⌥⌘1 / ⌥⌘2 / ⌥⌘3 | Focus / Short Break / Long Break |
| ⌘1 … ⌘6 | Today / Timer / Tasks / Projects / Reports / Settings |
| ⌘F | Search tasks |
| ⇧⌘E | Export CSV report |
| ⇧⌘B | Export JSON backup |
| ⌘, | Settings |
| ⌘Q | Quit |

## Design — Warm Editorial

iPomo uses a deliberately narrow design system rather than default rounded-card
UI: warm paper surfaces, a single terracotta accent, New York serif display type,
SF Pro body copy, 8pt spacing, hairline rules, and editorial ledgers. Focus stages have
their own muted colors (sage for short breaks, slate for long breaks); everything else
stays neutral. Dark mode uses warm charcoal surfaces with the same accent logic.

Signature details: the Today metric ledger and projected day timeline, the Timer's
ring with tick marks and serif countdown, flat task/project/report ledgers, a paper
menu-bar panel, and an editorial app icon. No emoji icons, purple-blue gradients,
centered hero blocks, or symmetric feature-card grids.

Controls are part of the same language: paper switches with an accent track,
minus/plus number steppers, date fields that open a calendar popover, text-hugging
tab underlines, and thin progress rules instead of stock progress bars.

- Tokens, type scale, components: `Sources/iPomoUI/Support/DesignSystem.swift`
- Full brand specification and anti-slop checklist: [`brand-spec.md`](brand-spec.md)
- Theme accent pairs: `Sources/iPomoCore/Models/Enums.swift`
- Screens: `Sources/iPomoUI/Views/`

## Architecture

```
Sources/iPomoCore/          Pure, testable domain layer
  Models/                     Project, PlanTask, FocusSession, settings, database
  Logic/                      TimerMath, PlanningLogic, finish estimates, search
  Reporting/                  ReportRange, aggregation, streaks, CSV
  Persistence/                JSON database store, atomic writes, rolling backups
Sources/iPomoUI/            SwiftUI application library
  AppModel*.swift             Observable model, timer engine, mutations, reports
  Views/                      Dashboard, Timer, Tasks, Projects, Reports, Settings, menu bar
  Support/                    Design system, sound, notifications, formatting
Sources/iPomoApp/           Executable launcher
Tests/iPomoCoreTests/       Core Swift Testing suites
Tests/iPomoAppTests/        App-model and opt-in visual snapshot suites
docs/                          Features, workflows, architecture, brand spec
```

- **Core has no SwiftUI or AppKit dependency** and is covered by tests.
- **Persistence is JSON**, not SwiftData/Core Data, to keep the file inspectable, portable, and migration-friendly. The single `DatabaseStore` boundary makes swapping in SQLite/SwiftData straightforward.
- **Timer state is a small timestamp snapshot**, so the UI is a pure function of `now` plus the database. Background completion works across sleep, quit, and relaunch without a web runtime.
- **Search, reports, and CSV generation are pure core functions**, so they can be reused by a CLI, widget, or future platform target.

Read [`ARCHITECTURE.md`](ARCHITECTURE.md) for the data model, timer state machine, persistence guarantees, and extension points. Read [`WORKFLOWS.md`](WORKFLOWS.md) for every user workflow.

## Tests

`swift test` covers:

- search semantics, including the literal-`undefined` regression and diacritic folding;
- timer durations, fractional estimates, long-break scheduling, countdown formatting;
- finish-time calculation with breaks and long breaks;
- report buckets, project totals, streaks, filtered reports, CSV escaping;
- persistence round-trip, corrupt-file recovery, tolerant settings decoding, schema rejection, rolling backups;
- version comparison and GitHub release parsing, including URL trust validation;
- app-model flows: task persistence across reloads, round completion and task credit, long-break scheduling, auto-check, fractional credit, skip-as-completion for focus and breaks, partial-session recording, manual entries, and project deletion semantics;
- the opt-in visual snapshot suite renders every screen in light, Today/Timer/Settings in dark, a wide-window dashboard, the sidebar, the editors, the manual-entry sheet, and the menu-bar panel through an offscreen `NSHostingView`.

The UI is built with SwiftUI and validated by compilation, rendered snapshots, and a launch/window smoke check. See [`VERIFICATION.md`](VERIFICATION.md) for the recorded run and [`ARCHITECTURE.md`](ARCHITECTURE.md#verification) for the method.

## Scope and roadmap

Deliberately out of scope for v1 (and why):

- **Cloud sync / accounts** — contradicts the offline-first requirement.
- **Todoist, webhooks, web push** — network integrations; they contradict the offline-first requirement.
- **Ads/analytics/Sentry** — removed by design.
- **Browser-based feature parity** — no remote web content is loaded.

Natural next steps: subtasks, templates, calendar/ICS export, Shortcuts/App Intents, widget and menu-bar-only mode, universal binary and notarized distribution, optional SQLite backend for very large histories, and a JSON/CSV importer.

iPomo is an original implementation and is not affiliated with Pomofocus or FocusLab.
