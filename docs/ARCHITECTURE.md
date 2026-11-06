# iPomo architecture

## Targets

```
iPomoCore (library, no UI dependencies)
  Models/         Codable domain types and tolerant settings decoding
  Logic/          TimerMath, PlanningLogic, finish estimates, TaskSearch
  Reporting/      ReportRange, ReportAggregator, ReportCSV
  Persistence/    DatabaseStore (JSON, atomic writes, backups, recovery)

iPomoUI (library, SwiftUI + AppKit)
  AppModel*.swift App observable state, timer engine, mutations, reports, data intents
  Views/          Dashboard, Timer, Tasks, Projects, Reports, Settings, menu bar
  Support/        DesignSystem, SoundPlayer, NotificationManager, Theme/formatting

iPomoApp (executable)
  iPomoApp.swift  Launcher for iPomoRoot.main()

iPomoCoreTests + iPomoAppTests (Swift Testing)
  Search, timer math, planning, reports, persistence, app-model flows, snapshots
```

The core library has no SwiftUI or AppKit imports. All pure logic and persistence is
testable without launching the UI. The app target depends on the core; the core never
depends on the app.

## Domain model

### `Project`
- `id`, `name`, `details`, `colorHex`, `status`, `dueDate`, `targetPomodoros`, `sortOrder`, timestamps.
- `status`: Active, On Hold, Completed, Archived.
- Progress is derived from tasks, never stored separately.

### `PlanTask`
- `id`, `title`, `notes`, `projectID`, `estimatedPomodoros`, `completedPomodoros`, `dueDate`, `priority`, `isCompleted`, `completedAt`, `isFocusToday`, `sortOrder`, timestamps.
- **`pomodoroUnit`** returns the fractional estimate when `0 < estimate < 1`, otherwise `1`.
- `progress`, `remainingPomodoros`, `displayProgress`, `isOverdue`.
- Task scopes are Active (all tasks, completed grouped at the bottom) and Completed. Tasks have no archive state.

### `FocusSession`
- Snapshots `taskTitle` and `projectName` so reports survive task/project deletion.
- `stage` may be Focus, Short Break, or Long Break; reports count only Focus.
- `actualSeconds` can be shorter than `plannedSeconds` for partial sessions.
- `isManual` marks user-entered corrections.
- `completed` distinguishes a full round from a partial/abandoned round.

### `AppSettings`
Nested settings groups:

| Group | Fields |
|---|---|
| `timer` | focus/short/long minutes, long-break interval, auto-start breaks/focus |
| `behavior` | auto-check, move completed to bottom, confirm task switch, record partial |
| `sound` | enabled, alarm sound/volume/repeat, focus sound/volume |
| `appearance` | theme, dark while running, hour format, week start, menu-bar timer |
| `notifications` | enabled, round end, reminders, reminder mode/minutes |
| `reports` | default range |
| `planning` | daily goal minutes, default estimate, plan horizon |
| `updates` | automatic GitHub release checks (on by default) |

Every nested group implements `decodeIfPresent` defaults. Unknown future keys are
ignored and missing keys fall back to documented defaults; this keeps older/newer
database files readable without migration code.

### `TimerSnapshot`
```swift
stage: Stage
isRunning: Bool
accumulatedSeconds: Double   // consumed before startedAt
startedAt: Date?             // current running segment
focusRoundCount: Int         // completed focus rounds
activeTaskID: UUID?
```
The remaining time is always derived: `duration - accumulated - (now - startedAt)`.

### `AppDatabase`
- `schemaVersion`, timestamps, projects, tasks, sessions, settings, timer.
- `normalize()` repairs duplicate IDs, removes dangling project references, and rebuilds project sort order.
- Lookup helpers and aggregate conveniences.

## Timer state machine

```
            start                       finish (timer)
  .focus ───────────────► .shortBreak ──────────────► .focus
    │                         ▲
    │ finish at interval      │
    ▼                         │
  .longBreak ─────────────────┘

Any stage ── skip ─────────────► treated as completed: credit + next stage
Any stage ── reset/stage/task switch ──► partial session + paused
```

- **Duration:** `TimerMath.durationSeconds(stage:settings:task:)`. Focus rounds scale for fractional task estimates.
- **Next stage:** `TimerMath.nextStage(after:completedFocusRounds:longBreakInterval:)`.
  The soon-to-complete focus round is `completedFocusRounds + 1`; every Nth gets a long break.
- **Start:** sets `isRunning`, `startedAt = now`; starts ticking sound; schedules reminders.
- **Pause:** computes consumed seconds, stores it in `accumulatedSeconds`, clears `startedAt`; no session is split.
- **Finish:** records a completed session ending at the expected completion time, credits the active task (if focus), increments `focusRoundCount`, selects the next stage, stops audio/reminders, emits banner/notification/alarm, optionally auto-starts.
- **Restore:** if a persisted snapshot was running and is overdue, finish exactly once at the expected end; otherwise resume the countdown with the correct remaining time.
- **Skip:** routes through `finishCurrentRound(allowAlarm: false)`, so the focus round is credited, the long-break cycle advances, or the break is completed; auto-start still applies if configured.
- **Partial sessions:** reset, stage switch, and task switch call `recordCurrentPartialIfNeeded()`; the session is saved with `completed = false` and no task credit. Pause keeps the accumulated time on the current round.
- **Auto-start:** a cancellable 1.2 s work item starts the next stage; any manual action cancels it.

### Why this shape

The timer stores `startedAt`/`accumulatedSeconds` and derives the remaining time
instead of counting down in memory. The transition is explicit, testable, and
idempotent. The UI is a pure function of the snapshot plus `now`, so pausing,
sleeping, and relaunching all use the same code path.

## Persistence

`DatabaseStore`:

- Default directory: `~/Library/Application Support/iPomo/`.
- `data.json`, pretty-printed, sorted keys, ISO-8601 dates.
- Atomic writes (`Data.write(options: .atomic)`).
- **Backups:** before a save, if the latest backup is older than 24 h, copy the existing file to `Backups/data-<yyyyMMdd-HHmmss>.json`; keep seven.
- **Corrupt recovery:** on decode failure, move the file to `Backups/corrupt-<timestamp>.json` and return a fresh database plus a user-facing message.
- **Newer or unreadable files:** a file with a newer schema version, or a file that cannot be read, is left in place. The app shows a warning and saves nothing until the user imports a backup or resets the data.
- **Export/import:** `encode(_:)`/`decode(_:)` are the same code path used by the UI. Newer schema versions are rejected with a clear error.
- **Settings tolerance:** all settings groups decode missing keys to defaults, so adding a setting does not invalidate existing files.

`AppModel` debounces saves by 0.4 s after mutations, saves immediately on round
completion, flushes on scene deactivation and app termination, and exposes the file
path plus import/export/reset actions in Settings.

## Updates

- `UpdateVersion.isNewer(_:than:)` (iPomoCore) compares dotted numeric components, tolerating a leading `v` and `-`/`+` suffixes. A string without a numeric version never compares as newer.
- `UpdateChecker` (iPomoUI) requests `https://api.github.com/repos/farukerdem34/iPomo/releases/latest` with an ephemeral `URLSession` (no cookies, cache, or credentials), a 15 s timeout, `Accept: application/vnd.github+json`, and an `iPomo/<version>` User-Agent.
- `parseRelease` reads `tag_name`, `html_url`, and DMG assets. Only HTTPS `github.com/farukerdem34/iPomo/releases/…` URLs are trusted: an untrusted release page rejects the payload, and untrusted assets are ignored.
- Automatic checks run on first appearance and when the app becomes active, gated to once per 24 h by the `com.ipomo.app.lastUpdateCheck` UserDefaults key (written before the request so failures do not retry on every activation). Users can opt out with `settings.updates.automaticallyChecksForUpdates`.
- There is no self-installation: the alert's Download button opens the DMG (or the release page when no DMG is attached), and the user installs by dragging iPomo into Applications. Development builds without a bundle identifier or version skip checks.

## Search

`TaskSearch.search(tasks:query:projects:scope:now:calendar:)`:

1. Normalize with case/diacritic/width folding and lowercase.
2. Split the query on any whitespace; empty query returns the scoped list in plan order.
3. Join title, notes, and project name into a haystack built from non-optional strings. Missing fields become `""`, never `"undefined"`/`"null"`.
4. Require every term to be a substring (AND), then score:
   - exact title, title prefix, title contains;
   - per-term title/project/note matches;
   - focus-today bonus and priority.
5. Sort by score, then plan order (priority, due date, manual order, created date).

This is deliberately a local, in-memory search. It searches every task, splits on any
whitespace, treats missing fields as empty strings, and ranks title matches above
project and note matches. Tests in `SearchTests.swift` assert each rule.

## Reports

`ReportAggregator.summary(database:range:projectFilter:now:calendar:)`:

- Interval and bucket definitions live in `ReportRange`:
  - Today: one bucket.
  - Week: day buckets.
  - Month: week buckets.
  - Year: month buckets.
- Focus sessions only (`stage == .focus`), optionally filtered by project.
- Totals: focus seconds, session count, completed tasks, active days, average per active day.
- Project totals: grouped by `projectID`; deleted projects use the session's snapshot name; share = project seconds / total seconds.
- Streaks: unique focus days; current streak walks back from today (or yesterday if today has none); longest streak scans consecutive days.
- CSV: `Date,Start,End,Task,Project,Stage,Minutes,Completed,Manual`, quoted/escaped, UTF-8 BOM added by the export path.

Reports never require an account, network, or premium state.

## Planning

- `PlanningLogic.todayTasks` = active tasks that are starred, due today, or overdue.
- `PlanningLogic.planSort` = priority desc, due date asc (undated last), manual order, created date.
- The Tasks screen groups tasks by due date, then orders each group by `sortOrder` so drag order is authoritative; search results keep relevance order and cannot be dragged.
- `PlanningLogic.projectProgress` = completed vs estimated pomodoros and task counts.
- `FinishTimeCalculator.estimate` = remaining focus seconds for a task list plus short/long breaks between rounds; used by the Today plan and project planning. Task starts account for the round in progress and the current focus-round count.
- `PlanningSettings.planHorizonDays` sets how many days ahead the Tasks screen's Next bucket covers.

## UI composition

- `iPomoApp` scenes:
  - `Window("iPomo", id: "main")` — main NavigationSplitView.
  - `MenuBarExtra` — native menu-bar panel.
  - `Settings` — the same settings form as the sidebar.
- `RootView` owns sheets (task/project editors), the task-switch confirmation, the update alert, auto-check triggers, the banner overlay, scene-phase flush, and conditional dark mode while running.
- `SidebarView`: Today, Timer, Tasks, Projects, Reports, Settings.
- Views are intentionally thin: all mutations go through `AppModel` methods; all pure calculations live in core.
- `AppCommands` provides menu and keyboard access; `TasksView` has a custom search field so ⌘F can focus it.
- Sidebar rows are explicit selection buttons (reliable click/keyboard state) rather than a tagged `List` selection.
- A local `NSEvent` key monitor starts/pauses on Space unless a text control has focus or a sheet/modal is active.
- The Warm Editorial design system lives in `Support/DesignSystem.swift`: dynamic light/dark tokens, New York serif display type, SF Pro body type, 8pt spacing, environment accent, buttons, fields, ledgers, tabs, and empty states. The full spec is [`brand-spec.md`](brand-spec.md).
- `Support/MarkdownText.swift` parses notes with Foundation's Markdown reader (`PresentationIntent`) into paragraphs, headings, lists, code blocks, quotes, tables, and thematic breaks, then renders them with design tokens. Inline emphasis, code spans, and links keep their Markdown attributes. Parsed documents are cached by source string so the once-per-second timer redraw does not re-parse the note.
- Screens use flat ledgers, hairlines, and asymmetric compositions instead of card grids. Theme accents flow through `EnvironmentValues.editorialAccent`; the sidebar, Settings scene, and menu-bar panel each inject it from the current theme.
- Shared controls keep native semantics but use the paper language: `EditorialToggleStyle` (accent track, contrast-aware knob), `EditorialIntStepper` (minus/value/plus), `EditorialDateField` (calendar popover, app hour format), `EditorialTabs` (text-hugging underline), and `EditorialProgressViewStyle` (3–4pt rule). Menus use `.button` style with plain button styling so custom labels render consistently.

## Notifications and sound

- `NotificationManager` guards on `Bundle.main.bundleIdentifier` so `swift run` cannot crash the notification service; requests authorization on first timer start or from Settings; posts local notifications and schedules/removes reminder IDs with a shared prefix.
- `SoundPlayer` uses built-in `NSSound` names, keeps strong references, supports volume/repeat, and runs a configurable ticking timer on the main run loop.
- If notifications are denied, banners and alarms still communicate round completion.

## Concurrency and lifecycle

- `AppModel` is `@MainActor` and `ObservableObject`.
- A main-queue `DispatchSourceTimer` ticks every 0.5 s, updates `now`, and checks completion.
- Debounced saves and auto-start are cancellable `DispatchWorkItem`s.
- App termination and scene deactivation flush the database.
- Round completion is idempotent because it clears `isRunning`/`startedAt` and persists immediately.

## Verification

- `swift test` — Swift Testing suites for core logic/persistence/reports, app-model flows, and the opt-in snapshot suite.
- `IPOMO_SNAPSHOT_DIR=… swift test --filter SnapshotTests` — renders every screen in light, Today/Timer/Settings in dark, a wide-window dashboard, the sidebar, the editors, the manual-entry sheet, and the menu-bar panel through an offscreen `NSHostingView`.
- `swift build` — compiles the app.
- `./scripts/build-app.sh release` — bundles, lints `Info.plist`, ad-hoc signs.
- Launch smoke check: the built app opens the main window and a menu-bar item. On this machine:
  - `pgrep -x iPomo` → process present;
  - `CGWindowListCopyWindowInfo` shows the main window and the menu-bar window;
  - no crash reports in `~/Library/Logs/DiagnosticReports`.
- UI interaction was not automated (the environment has no Accessibility permission); rendered snapshots validate layout, while the behavioural contracts are covered by core tests and by the deterministic state machine.
- The recorded run is in [`VERIFICATION.md`](VERIFICATION.md); `./scripts/smoke-check.sh` reproduces the launch/window check.

## Extension points

- **Storage:** swap `DatabaseStore` for SQLite/SwiftData; the rest of the app uses `AppDatabase` values.
- **Subtasks:** add `parentID` to `PlanTask` and render children explicitly so a matching child of a non-matching parent stays visible.
- **Templates:** copy `[PlanTask]` snapshots into a new day; the domain already snapshots sessions.
- **Widgets/App Intents:** the timer/report functions are pure and can back a widget timeline.
- **Menu-bar-only mode:** `MenuBarExtra` and `AppModel` already stand alone; hide the main window on request.
- **Importers:** map external JSON/CSV or Todoist exports into `PlanTask`/`FocusSession`; no network required.
- **Distribution:** add App Sandbox entitlements, Developer ID signing, notarization, and a universal build to the bundling script.

## Known limitations

- Single-user and local by design; no sync.
- No subtasks, templates, webhooks, Todoist, or cross-device alarms in v1.
- The menu-bar timer updates on the model tick; it is not a system-wide status item with custom drawing.
- The app is not sandboxed in the development bundle.
- Notification delivery depends on macOS permission; unsigned/ad-hoc builds may need the app in `/Applications` for reliable notification registration.
- Reports recompute on each view update; fine for personal-scale histories, not optimized for millions of sessions.
