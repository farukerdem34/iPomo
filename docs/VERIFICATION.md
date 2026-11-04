# Verification record

Recorded on 2026-11-04 on macOS 15.7.9 (arm64) with Swift 6.1.2 and the macOS 15.5
Command Line Tools SDK. This is a development verification record, not a claim of
exhaustive UI testing.

## Automated tests

```
$ swift test
...
✔ Test run with 51 tests passed after 0.011 seconds.
```

Coverage:

- **iPomoCoreTests (38):** search semantics and regressions, timer math, long-break
  scheduling, fractional estimates, round-aware finish estimates, report buckets/projects/
  streaks/CSV (including formula prefixes), JSON persistence (including legacy archive-flag
  tolerance), corrupt-file recovery, newer-schema preservation, tolerant settings decoding,
  schema rejection, backups, and import-value clamping.
- **iPomoAppTests (13):** task persistence across reloads, focus completion and task
  credit, long-break transition, auto-check clearing, fractional credit, skip-as-
  completion for focus and breaks, partial session on reset, manual report entries,
  project deletion with/without tasks, overdue-timer restore, and one opt-in visual
  snapshot case.

## Visual snapshots

```
$ IPOMO_SNAPSHOT_DIR=/tmp/ipomo-snapshots swift test --filter SnapshotTests
✔ Test renderScreens() passed after 3.346 seconds.
```

The snapshot test renders 16 PNGs through an offscreen `NSHostingView` in a borderless
window: the sidebar, Today, Timer, Tasks, a filtered empty-state Tasks view, Projects,
Reports, Settings, the task and project editors, the manual-entry sheet, the menu bar,
a 1600×900 wide-window dashboard, and dark-mode Today, Timer, and Settings. The light,
dark, and wide runs were reviewed for hierarchy, contrast, alignment, and the custom
switch/stepper/date/tab/progress components.
Snapshot rendering is layout verification only; it does not click or type into the UI.

## Build

```
$ swift build
Build complete.
$ ./scripts/build-app.sh release
Built .../iPomo/dist/iPomo.app
```

The bundle:

- `CFBundleIdentifier` `com.ipomo.app`, version 1.0.0, minimum macOS 14.
- Ad-hoc signed (`codesign --sign -`), no entitlements.
- Includes `Resources/AppIcon.icns` (generated from `Resources/AppIcon-1024.png`).

## Launch smoke check

```
$ ./scripts/smoke-check.sh
iPomo window bounds={
    Height = 43;
    Width = 81;
    X = 998;
    Y = 0;
} alpha=1
iPomo window bounds={
    Height = 1007;
    Width = 1710;
    X = 0;
    Y = 44;
} alpha=1
Found 2 iPomo window(s)
Smoke check passed.
```

The small window is the native `MenuBarExtra`; the large window is the main app.
The main window's restored size depends on the last session; the scene declares a
1180×760 default and the layout caps content at 1120pt and centers it at wider sizes.
No crash report appeared in `~/Library/Logs/DiagnosticReports`.

## Not verified automatically

- Mouse/keyboard UI interaction (the environment lacks Accessibility permission for
  `System Events`).
- Notification delivery (depends on the user granting permission).
- System sleep/wake timing end-to-end (the state machine and restore math are covered
  by unit tests).
- Distribution signing/notarization (the local bundle is ad-hoc signed).

These are documented as limitations in `ARCHITECTURE.md` and `README.md`.
