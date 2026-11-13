# iPomo workflows

Every user-facing workflow, in the order a new user is likely to encounter it.

## 1. First launch

1. Open `iPomo.app`.
2. A window titled **iPomo** appears with the sidebar: Today, Timer, Tasks, Projects, Reports, Settings.
3. A menu-bar item appears with the timer text (or “iPomo” while idle).
4. No account or onboarding is required. The optional GitHub update check is the only network request. The first permission prompt appears only when you start a focus round or enable notifications.
5. The database is created lazily at `~/Library/Application Support/iPomo/data.json` on the first change.

**Expected:** the Today dashboard shows zeroed stats and an empty plan with a quick-add field.

## 2. Today dashboard

1. Open **Today**.
2. Read the metric ledger: focus time today, current/longest streak, active task count, daily-goal percentage.
3. Use **Quick add a task for today** and press Return. The task is created with the default estimate, flagged for today, and appears in the plan.
4. Use the star on any row to add/remove it from today's plan.
5. The **Today's plan** section shows tasks as a projected timeline with start times, remaining pomodoros, and planned break time.
6. Start the timer from the accent focus panel, or click **Open Timer**.
7. The Projects section shows up to four active projects with progress and all-time focus time.

**Notes:** today's tasks include starred tasks, tasks due today, and overdue tasks. The finish estimate uses the current timer settings and break schedule.

## 3. Create a task

1. Click **Add Task** on Today or Tasks, or press ⌘N.
2. Enter:
   - **Title** (required).
   - **Notes** (Markdown supported; use **Preview** to check the formatted note).
   - **Project** (No Project or any existing project).
   - **Estimated pomodoros** (0.1–99; estimates below 1 shorten the focus round).
   - **Priority** (Low / Medium / High).
   - **Add to today's plan** (default on for new tasks).
   - **Due date** (optional); the field opens a calendar popover.
3. Click **Add Task** (or Return).

**Expected:** the task appears in the active list, ordered by priority, due date, then manual order.

## 4. Edit, duplicate, complete, delete

- **Edit:** double-click a row or use the row menu → **Edit…**. The same form opens with history (completed pomodoros, created/updated).
- **Duplicate:** row menu → **Duplicate**; the copy starts at zero completed pomodoros and is not completed.
- **Complete:** click the circle checkbox. Completed tasks stay visible with a strikethrough. If **Move completed tasks to a Completed section** is on (default), they collect in a Completed section at the bottom.
- **Delete:** row menu → **Delete Task**, confirm. Focus history is kept.
- **Clean up:** Tasks toolbar → **Clean up** → Delete completed tasks.
- **Focus today:** click the star on the row or in the editor.

## 5. Search and filter tasks

1. Open **Tasks**.
2. Type in the search field (⌘F focuses it).
3. Search matches:
   - titles, notes, and project names;
   - any whitespace-separated terms, in any order (AND);
   - case, diacritics, and width are ignored;
   - titles rank above project names and notes.
4. Use the **Scope** picker: Active / Completed. Active shows every task and keeps completed tasks in a Completed section by default.
5. Use the project menu to restrict to one project.
6. Clear the field with the × button.
7. If a scope or project filter hides every task, the empty state says so and offers **Show all tasks**.

**Design note:** search covers every task, splits on any whitespace, and treats missing fields as empty strings rather than literal `"undefined"`/`"null"`.

## 6. Reorder tasks

- Drag a row within its due-date section.
- Manual order is stored as `sortOrder` and wins inside that section.
- Search results keep relevance order and cannot be dragged.

## 7. Create and manage projects

1. Open **Projects** → **New Project** (⇧⌘N).
2. Enter name, details, color, status (Active / On Hold / Completed / Archived), optional target date (chosen from a calendar popover), optional pomodoro target.
3. Click **Create**.
4. On a project ledger row:
   - **Open Tasks** switches to Tasks filtered to that project.
   - **Edit** reopens the editor.
   - **⋯ → Delete…** offers:
     - **Delete and keep tasks** — tasks move to No Project;
     - **Delete project and its tasks** — tasks are removed;
     - **Cancel**.
5. Project progress is always computed from its tasks: completed vs estimated pomodoros, completed/total tasks, and all-time focus time.

**Design note:** projects are free; the same project data feeds tasks, search, and reports.

## 8. Focus with the timer

### Choose a task

1. Open **Timer**.
2. Open the task menu above the timer and pick an active task, or **No task**.
3. If the timer is running and **Confirm when switching tasks mid-round** is on, confirm the switch. The current round resets for the new task; partial time is recorded if enabled.

### Run a round

1. Pick a stage (Focus / Short Break / Long Break) or use ⌥⌘1/2/3.
2. Press **Start** (⌥⌘P). The countdown, progress bar, and menu-bar text update.
3. Press **Pause** to stop the clock. The elapsed time stays on the current round.
4. Press **Skip** to treat the current stage as completed: a skipped focus round credits the task and advances the long-break cycle; a skipped break is recorded as a completed break. The next stage is selected exactly as on a natural finish.
5. Press **Reset** to discard the current round; partial focus time is recorded (if the setting is on).
6. **Reset Cycle** (Timer menu) returns to Focus, round #1, and clears the long-break counter.

### Round completion

When the countdown reaches zero:

- the focus time is recorded as a completed session;
- the active task gets `pomodoroUnit` credit (1, or the fractional estimate);
- if **Auto-check** is on and the estimate is reached, the task is completed and moved to the bottom;
- the next stage is chosen: break after focus, focus after a break, long break every N completed focus rounds;
- a banner, local notification (if permitted), and alarm sound fire;
- if **Auto-start** is enabled for the next stage, it starts after a short delay.

**Note:** round completion is idempotent across sleep/quit. A running snapshot stores its start timestamp; on relaunch an overdue round is completed once, at its expected end time.

### Partial focus time

- Pausing does **not** split the session; the accumulated time stays on the round.
- Reset, stage switch, or task switch record the uncommitted focus time as a partial session. Skip is different: it counts the stage as completed.
- Partial sessions count toward reports and CSV but do not increment the task's completed pomodoros.
- Turn this off with **Record partial focus time on reset/stage switch/task switch** in Settings.

## 9. Reports

1. Open **Reports**.
2. Pick a range: Today / Week / Month / Year.
3. Optionally filter by project.
4. Read the metric ledger: focus time, active days, tasks completed, current/longest streak.
5. The chart buckets focus minutes by day (week), week (month), or month (year).
6. The project breakdown shows focus time, share, and session counts.
7. The session table lists date, task, project, minutes, and badges for **Manual** and **Partial** entries.
8. Delete a session with the trash button (confirmation).
9. Add a correction or offline entry with **Add Entry**:
   - task/description, notes (Markdown), project, date/time (calendar popover; time follows the 12/24-hour setting), minutes;
   - manual entries count in reports and CSV but do not change task pomodoro counts.
10. **Export CSV** (⇧⌘E) writes a UTF-8 BOM CSV with date, start, end, task, project, stage, minutes, completed, manual.

**Design note:** reports are always local and free; no account, network, or premium state is required.

## 10. Settings

Open **Settings** from the sidebar, the menu (⌘,), or the account-free app menu.

### Timer
- Pomodoro / short break / long break minutes.
- Long-break interval.
- Auto-start breaks and focus rounds.

### Tasks
- Auto-check when estimate is reached.
- Move completed to bottom.
- Confirm task switches.
- Record partial focus time on reset, stage switch, or task switch (skip always counts as completion).

### Sounds
- Enable sounds.
- Alarm sound and volume; repeat count; preview.
- Focus sound (None / Tick Fast / Tick Slow) and volume; preview.

### Appearance
- Theme color swatches.
- Dark mode while the timer is running.
- 12/24-hour clock.
- Start of week (Monday / Sunday / Saturday), used by reports.
- Show/hide the menu-bar timer.

### Notifications
- Enable notifications.
- Notify on round end.
- In-round reminders: mode (Last / Every) and minutes.
- Request permission / Test.
- If macOS denies permission, in-app banners still work.

### Reports
- Default report range.

### Planning
- Daily focus goal (used by the Today goal metric).
- Default estimate for new tasks.
- Plan horizon.

### Data
- Reveal the database in Finder.
- Export/import a JSON backup.
- Reset all data (confirmation required).

### Updates
- **Version** shows the installed release (or “Development build” when run from source).
- **Check for updates automatically** (on by default) asks GitHub at most once a day.
- **Check Now** performs a manual check; **Download Update** appears when a newer release exists.
- **iPomo → Check for Updates…** in the app menu also runs a manual check.
- Manual checks report “up to date” or failures in a banner; automatic checks fail silently.
- A newer version opens an in-app alert. **Download** opens the release DMG (or the release page when no DMG is attached) and **Release Notes** opens the release page. Install manually by dragging iPomo into Applications; the app never replaces itself.
- `swift run` builds have no bundle identifier or version, so update checks are disabled.

## 11. Backup, import, reset

- **Export Backup:** writes the complete database JSON to a chosen file. Use it before upgrades or experiments.
- **Import Backup:** opens a JSON file, asks for confirmation, then atomically replaces the local database. The timer is stopped and reset.
- **Automatic backups:** before a save, if the last backup is older than 24 hours, the current database is copied to `Backups/data-<timestamp>.json`; the newest seven are kept.
- **Corrupt file recovery:** if the database cannot be decoded, it is moved to `Backups/corrupt-<timestamp>.json` and the app starts fresh; a banner explains what happened.
- **Reset All Data:** deletes tasks, projects, sessions, and settings. Export first if needed.

## 12. Menu bar

- The menu-bar label shows the remaining time when a round is running or paused, and “iPomo” when idle.
- Click it to open a panel with stage, countdown, active task, Start/Pause, Skip, Reset, today's focus time, active task count, **Open iPomo**, and **Quit**.
- This is a native model read: the label updates from the timer snapshot, not from polling a page.

## 13. Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘N | New task |
| ⇧⌘N | New project |
| Space | Start / pause (when not typing in a text field or dialog) |
| ⌥⌘P | Start / pause |
| ⇧⌘] | Skip stage (counts as completed) |
| ⇧⌘R | Reset round |
| ⌥⌘1/2/3 | Focus / Short Break / Long Break |
| ⌘1…⌘6 | Navigate sections |
| ⌘F | Search tasks |
| ⇧⌘E | Export CSV |
| ⇧⌘B | Export backup |
| ⌘, | Settings |

iPomo uses conventional macOS platform accelerators.

## 14. Failure and recovery behaviour

- **App closed mid-round:** on relaunch, the snapshot is read. If the round already ended, it is completed once at its expected end time; otherwise it resumes with the correct remaining time.
- **Mac slept mid-round:** the next tick observes the elapsed time and completes or resumes accordingly.
- **Notifications denied:** in-app banners and alarm sounds still notify you.
- **Database corrupt:** the file is quarantined, a fresh database starts, and the banner points to the backup.
- **Import fails:** the current database is untouched and a warning banner is shown.
- **Save fails:** a warning banner appears; the in-memory state remains available until the next save attempt.
