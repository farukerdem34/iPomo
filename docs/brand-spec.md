# iPomo brand spec — Warm Editorial

**Direction:** a quiet paper planner with a single terracotta accent, New York serif
display type, warm neutral surfaces, and editorial ledgers instead of card grids.
The app should feel intentionally crafted, calm, and legible for long focus sessions.

## Principles

1. **Paper, not chrome.** Warm neutral surfaces and hairlines; avoid glassmorphism,
   heavy shadows, and glossy gradients.
2. **One accent.** Terracotta carries focus, selection, and primary actions. Stage
   colors (sage for short breaks, slate for long breaks) are the only additional hues.
3. **Editorial hierarchy.** Serif display titles; sans UI labels; overline metadata;
   tabular numerals for time and counts.
4. **Ledgers over cards.** Prefer rows, rules, and whitespace. Avoid symmetric grids
   of rounded feature cards.
5. **Content first.** No hero marketing blocks, no emoji icons, no decorative clipart.
6. **One signature per screen.** Dashboard timeline and metric ledger; Timer ring;
   Tasks ledger; Reports chart; Settings rules; Menus with overline sections.

## Color tokens

| Token | Light | Dark | Use |
|---|---|---|---|
| `canvas` | `#F5F0E7` | `#171411` | Page background |
| `sidebar` | `#EFE8DC` | `#1D1915` | Sidebar surface |
| `surface` | `#FBF7F0` | `#221E19` | Fields, raised paper |
| `surfaceMuted` | `#ECE4D7` | `#2B2620` | Hover, quiet fills |
| `ink` | `#211C17` | `#F1E9DD` | Primary text |
| `inkSecondary` | `#6D6458` | `#B7AB9B` | Body secondary |
| `inkTertiary` | `#9B8F7F` | `#8A7E6E` | Overlines, metadata |
| `hairline` | `#DCD2C3` | `#3B342C` | Rules and borders |
| `accent` (Tomato) | `#B85C43` | `#E08C72` | Primary accent |
| `onAccent` | `#FFF9F2` | `#241A15` | Text/knob on accent |
| `switchKnob` | `#FFFDF8` | `#F1E9DD` | Knob on an off switch |
| `sage` | `#6E7F5E` | `#9CB18A` | Short break |
| `slate` | `#596A78` | `#8FA9B7` | Long break |
| `success` | `#5F7A50` | `#9CB18A` | Success |
| `warning` | `#A9762F` | `#D8AA63` | Warning |
| `danger` | `#A8433A` | `#E28B82` | Destructive |

Theme presets are defined in `AppTheme` and map to light/dark accent pairs:
Tomato, Emerald, Ocean, Violet, Amber, Teal, Rose, Indigo.

Project palette: 12 muted earth tones (terracotta through sage/slate/clay), defined
in `ProjectPalette`. They are used only for project identity and progress.

## Typography

| Role | Font | Size | Notes |
|---|---|---|---|
| Display | New York / system serif | 38–40 | Page titles |
| Section | New York / system serif | 21–26 | Section headings, project names |
| Number | New York / system serif | 28–88 | Timer, metrics; `.monospacedDigit()` |
| Heading | SF Pro | 15–16 semibold | Row titles, buttons |
| Body | SF Pro | 12–14 | Reading text |
| Caption | SF Pro | 10–12 | Metadata, secondary |
| Overline | SF Pro | 9–10 semibold | Uppercased, tracking 1.1 |

Use `.system(design: .serif)` rather than bundling fonts. No Inter/Roboto.

## Spacing and shape

- 8pt grid: 4, 8, 16, 24, 32, 48.
- Radii: 6 (chips/fields), 8 (buttons/tags), 12 (accent panels), 16 (rare).
- Hairlines are 1pt; no heavy strokes.
- Minimum interactive target: 28×28 for icon buttons, 40×40 for checkboxes,
  44×44 for primary touch targets where practical.

## Components

- **Sidebar:** paper surface, serif wordmark with a small timer mark, overline
  sections, selected row = accent 12% fill + accent text, shortcut hints at trailing.
- **Page title:** overline date/section, serif display title, optional content summary.
- **Metric ledger:** flat row of serif numbers with overline labels and 1pt dividers.
- **Timer ring:** 330pt circle, 7pt ring, tick marks, serif countdown, stage overline.
- **Focus panel:** solid accent/stage color block with white/dark text depending on
  appearance; Start + Skip, progress hairline.
- **Task row:** 40pt checkbox, serif-free title, project dot, due/priority metadata,
  estimate numerals; hover reveals edit; flat hairline separators.
- **Project row:** project dot, serif name, status tag, progress hairline, stats,
  actions on the right; no card grid.
- **Report chart:** solid accent bars, hairline grid, small axis captions.
- **Settings:** overline group titles, hairline rules, right-aligned controls.
  Switches are custom paper switches: accent track when on, muted track when off,
  and a knob chosen for contrast in each appearance.
- **Fields:** paper surface, hairline border, 6–8pt radius. Dates open a graphical
  calendar popover and follow the app's 12/24-hour setting; integers use explicit
  minus/value/plus steppers.
- **Tabs:** labels spread evenly; only the selected label carries a 2pt accent
  underline, hugging the text rather than the full segment.
- **Progress:** 3–4pt capsule rules with the accent or project color; no stock
  progress chrome. At zero only the track is visible.
- **Menus:** native menus with plain button styling so custom labels (project dot,
  name, chevron) render consistently; indicators are hidden when the label carries
  its own chevron.
- **Buttons:** primary filled accent; secondary hairline outline; quiet text accent;
  danger outlined red. Consistent 8pt radius.
- **Sheets:** paper canvas, overline + serif title, xmark close, fields on paper,
  footer buttons aligned right.

## Motion

- Subtle only. `Motion.calm` in DesignSystem is the single preset: `smooth` from
  0.12s to 0.4s, and nil under Reduce Motion.
- 0.12s row hover · 0.15s sidebar selection, checkbox, switch knob, and revealed
  editor fields · 0.18s page crossfade · 0.2s task list changes, tab underline, and
  banner slide · 0.25s countdown roll and ring progress · 0.3s stage-color crossfade
  and metric counts · 0.35s report chart · 0.4s progress bars.
- Play/pause symbols use `.symbolEffect(.replace)` and are removed under Reduce Motion.
- No bouncing cards, no decorative confetti, no parallax.

## Anti-slop checklist

- [x] No purple-blue gradients. Solid warm accent and stage colors.
- [x] No emoji as icons. SF Symbols only.
- [x] No symmetric three-column feature grid. Ledgers and asymmetric two-column layouts.
- [x] No centered hero text over a gradient.
- [x] No Inter/Roboto display. New York serif display, SF Pro body.
- [x] No neon-on-dark cyber palette. Warm paper / warm charcoal.
- [x] No AI-drawn illustrations. One custom vector wordmark/ring drawn in SwiftUI.
- [x] One signature detail per screen (ledger, ring, timeline, chart).
- [x] Dark mode tokens defined; semantic colors adapt automatically.
- [x] SF Symbols throughout; 44pt-ish tap targets for primary actions.
- [x] No `GeometryReader` for page layout; only the fractional progress rule measures
  its own track.

## Implementation

- Tokens, typography, environment accent, buttons, fields, ledgers, tabs, switches,
  date fields, progress rules, and empty states:
  `Sources/iPomoUI/Support/DesignSystem.swift`.
- Integer stepper: `Sources/iPomoUI/Views/Components.swift`.
- Theme accent pairs: `Sources/iPomoCore/Models/Enums.swift`.
- Screens: `Sources/iPomoUI/Views/`.
- Icon: `Resources/AppIcon-1024.png` generated by `scripts/make-icon.swift`.
- DMG install window: `scripts/make-dmg-background.swift`, rendered during packaging.
- Visual QA: opt-in `SnapshotTests` renders light, dark, and wide layouts to
  `$IPOMO_SNAPSHOT_DIR`.

The direction is deliberately narrow: if a new element does not serve planning,
focus, or reporting, it does not belong on the canvas.
