# iPomo

**A free, ad-free, local-first Pomodoro timer and project planner for macOS.**

<p align="center">
  <img src="Resources/AppIcon-1024.png" alt="iPomo icon" width="160">
</p>

iPomo is a native SwiftUI app: a focus timer, a task and project manager, and a
local reporting dashboard in one window, plus a menu-bar countdown. It has **no
accounts, ads, analytics, or third-party dependencies**. The only outbound request
is the optional GitHub update check; your data stays on your Mac in one
inspectable JSON file.

## What is this program?

iPomo is a local desktop tool:

- **Timer** — focus, short break, and long break rounds with configurable durations,
  auto-start, long-break intervals, fractional estimates, and background-safe state.
- **Tasks and projects** — priorities, due dates, estimates, notes, drag reordering,
  and project progress. Global ranked search works across every task.
- **Reports** — today, week, month, and year views with focus time, streaks, project
  breakdowns, manual entries, and CSV export.
- **Menu bar** — a native countdown with start, pause, skip, and stage controls.
- **Local data** — `~/Library/Application Support/iPomo/data.json` with rolling
  backups and JSON import/export. Your data never leaves the machine.

For the full feature list, design notes, and architecture, read
[`docs/FEATURES.md`](docs/FEATURES.md). Every user workflow is documented in
[`docs/WORKFLOWS.md`](docs/WORKFLOWS.md).

## How to install and use?

### Install

1. Download the latest `iPomo-<version>.dmg` from
   [Releases](../../releases/latest).
2. Open the DMG and drag **iPomo** into **Applications**.
3. Launch iPomo from Applications or Spotlight.

iPomo requires **macOS 14 or later**. Release builds are universal binaries for
Apple Silicon and Intel Macs.

The release is ad-hoc signed but **not notarized** by Apple. On first launch macOS
may block it:

- Right-click (or Control-click) iPomo → **Open** → **Open**; or
- open **System Settings → Privacy & Security** and choose **Open Anyway**; or
- if macOS reports the app is damaged, remove the quarantine flag:

  ```bash
  xattr -dr com.apple.quarantine /Applications/iPomo.app
  ```

### Update

iPomo checks GitHub for a newer published release at most once a day; this is on
by default and can be turned off in **Settings → About**. To check immediately,
use **iPomo → Check for Updates…** in the app menu. When an update is available,
**Download** opens the release DMG (or the release page if no DMG is attached).
Install it the same way as the first time: open the DMG and drag **iPomo** into
**Applications**. The app never downloads or replaces its own bundle.

### Use

1. On **Today**, click **Quick add a task** or press ⌘N, and set an estimate in
   pomodoros.
2. Open **Timer**, choose the task, and press **Start** (Space or ⌥⌘P).
3. Focus, short-break, and long-break rounds run automatically according to the
   settings. Completed focus rounds credit the selected task.
4. Use **Tasks** for search, filters, and project assignment, **Projects** for
   project tracking, and **Reports** for focus history and CSV export.
5. Adjust durations, alarms, notifications, theme, and menu-bar behavior in
   **Settings** (⌘,).

Data stays local; the optional update check is the only network request. Back up
or move the data with **Export JSON backup** in Settings (⇧⌘B). Keyboard shortcuts
are listed in
[`docs/WORKFLOWS.md#13-keyboard-shortcuts`](docs/WORKFLOWS.md#13-keyboard-shortcuts).

## How to contribute?

Bug reports, feature requests, and pull requests are welcome.

- **Issues** — include the macOS version, the iPomo version (release tag), what
  you did, what you expected, and what happened. Screenshots help for UI problems.
- **Pull requests** — keep each change focused; explain the problem and the fix.
  For behavior changes, run `swift test` and add or update tests.
- **Project conventions** — `iPomoCore` must stay free of SwiftUI and AppKit,
  and the package must not gain third-party dependencies. The single GitHub update
  check is the only allowed network call; do not add other network calls, accounts,
  analytics, or telemetry.
- **Documentation** — update the relevant file under `docs/` and the
  README when behavior or workflows change.

iPomo is released under the [GNU General Public License v2.0](LICENSE). By
contributing, you agree that your contributions are licensed under the same terms.

## How to build?

Requirements: macOS 14 or later and a Swift 6.1 toolchain. The Command Line Tools
are enough for a native build; a universal release build also needs full Xcode.

```bash
git clone <repository-url>
cd <cloned-repository>

swift test                        # run the test suite
./scripts/build-app.sh release    # build dist/iPomo.app
open dist/iPomo.app
# or: ./scripts/run-app.sh release
```

Build a DMG (created at `dist/iPomo.dmg` with a `.sha256` beside it):

```bash
./scripts/make-dmg.sh
```

Build a universal binary (Apple Silicon + Intel) and inject a version:

```bash
IPOMO_ARCHS="arm64 x86_64" \
IPOMO_VERSION=1.2.3 \
IPOMO_BUILD=42 \
./scripts/build-app.sh release
```

`IPOMO_VERSION` sets `CFBundleShortVersionString` and `IPOMO_BUILD` sets
`CFBundleVersion`. Without an override, the version comes from the nearest `v*`
git tag (falling back to `1.0.0`), so local builds report their real version to
the in-app update check; the build number defaults to `1`.

For development, `swift build`, `swift run iPomo`, or opening `Package.swift`
in Xcode works too. The opt-in visual snapshot suite can render every screen:

```bash
IPOMO_SNAPSHOT_DIR=/tmp/ipomo-snapshots swift test --filter SnapshotTests
```

### Continuous integration and releases

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on every push and pull
request: it runs `swift test`, builds a universal app, creates a versioned DMG, and
uploads it as a workflow artifact.

To publish a release, push a version tag:

```bash
git tag v1.2.3
git push origin v1.2.3
```

For `v*` tags the workflow also creates a GitHub Release and attaches the DMG and
its SHA-256 checksum. The tag version becomes the app's version; use a full
`vX.Y.Z` tag. GitHub also attaches source `.zip`/`.tar.gz` archives to every
release automatically; these are not app builds. The in-app update check reads
`/releases/latest`, which ignores drafts and prereleases, so only a published,
non-prerelease `vX.Y.Z` release is offered. You can also run the workflow manually
from the **Actions** tab to get a build artifact without creating a release.

### Repository layout

```
Package.swift             Swift package manifest
Sources/                  App, UI, and core targets
Tests/                    Core and app-model tests
Resources/                App icon
docs/                     Feature, workflow, architecture, and brand docs
scripts/                  Build, run, DMG, icon, and smoke-check scripts
.github/workflows/        CI/CD pipeline
```
