# Changelog

## [Unreleased]

### Added
- **Landed ring in the library** — every saved session shows a small ring
  of landed versus overflowed healing, so nights compare at a glance
  without opening them.
- **Copy the report** — click the summary chip and the report opens as
  plain text in the copy box, ready to paste in group chat.
- **Ability donut on the SKILL hover** — hovering a group shows its
  abilities as a ring beside the list, shades of the group colour, small
  ones merged into grey.
- **Healing report card** — hover the summary chip (it now wears a help
  icon) for the report: how much of your healing landed, how much
  overflowed, and the overflow split into HoT ticks on full targets
  (normal) versus direct heals that overflowed (the part to work on).
  Small donut included. Library sessions keep the split. The card also
  says how long an ultimate sat ready and unused, how many casts and how
  far apart, when the peak was, and the saves tally.
- **Active and shield share in the report** — the summary chip also says
  how much of the recording you were actually healing (`ACTIVE n%`) and,
  when shields were involved, how much of your output they were
  (`SHIELD n%`).
- **Wasted healing in the report** — the summary chip that appears after a
  recording (and on library sessions) now reads `WASTED n%`: overhealing
  integrated over the whole session against effective healing. The chip folds
  to two lines when the window is too narrow for one.
- **OHEAL view** — overhealing finally gets its place: effective healing
  stacked under the wasted overflow, sharing one axis so the proportion
  reads at a glance. Hover shows the wasted percentage per moment. Context,
  not a score — it never becomes a headline number.
- **Ultimate rows** — a strip at the top of every graph view with one row
  per bar: the ultimate slotted on each bar, its icon, the charge against
  that bar's own cost (soft green ramp), bright gold once it is ready, a
  white tick at each cast on the row that cast. The plot scales below the
  strip so nothing overlaps. Saved with the session, so library sessions
  bring the rows back.
- **Light Mode** (Settings > Recording, off by default) — while recording,
  the window sheds its border, title and buttons and dims to a configurable
  opacity; hover restores it and reveals stop + view navigation. Stopping
  brings the normal window back.
- **The addon introduces itself** — a one-time welcome card on the first
  open of the graph window, a one-sentence tooltip on the view label
  explaining each view in plain words, and the title now says it outright:
  Verdant counts your output only.
- **Buff watch** — star any buff in the BUFFS view to get a recast banner:
  click the star to arm it and cycle the warning threshold (3s / 5s / 8s /
  off). A small movable banner counts down when a watched buff is about to
  drop, and calls for a recast if it falls off mid-combat.

### Changed
- **TRIAGE view rebuilt around a donut** — outcomes as a donut with
  `n% saved` in the centre, a legend that counts and explains every
  class in five words, and below it the episodes of the selected class
  only, latest first, with wheel scrolling. Click a legend row to switch.
  Long fights no longer overflow and the colours finally say what they
  mean.
- **Every button explains itself** — one-sentence tooltips on all 32
  buttons across the graph, bar, library and settings, and the same sound
  vocabulary everywhere: windows open and close with their sounds, record
  and stop confirm, flush and delete decline.
- **Render pass allocates nothing per tick** — the bar views no longer
  create closures on every sample, so long recordings put less pressure
  on the garbage collector. Offline tripwire keeps it that way.
- **The graph grows into its window** — a fresh recording no longer starts
  as tiny bars on a huge empty axis: the live bar stays pinned to the right
  edge as always, but the axis starts short and expands in steps until it
  reaches the configured window, then slides as before. Time ticks read as
  a lookback ("-30s ... now").
- **Settings panel in two columns** (600 wide) — no more tower taller than
  the window it docks to.
- **Compact bar layout** — the value gets its own full-width row (it used
  to run under the graph button on narrow widths), the graph and settings
  buttons move to their own row, and the brand logo replaces the clipped
  title text.
- **Hover card widens to fit** — long ability names no longer truncate in
  the per-skill breakdown.
- **Cards are solid** — opaque body, dark warm ground with a thin gold
  frame instead of the green tint, drawn above every label of the window,
  and the explanation text no longer clips.
- **Less to read** — the window title drops its subtitle and the healing
  report drops its explanation paragraph; the rows say it.
- **Ultimate icons are 14px** and the OHEAL legend sits below the
  ultimate rows instead of across them.

### Fixed
- **A new recording no longer inherits the previous one** — rates from
  heals that landed before you pressed Record leaked into the first
  samples (and into PEAK / ACTIVE / WASTED). Record now starts from zero.
- Bars keep one uniform width in every graph view — the "one thicker bar
  every few" artifact is gone.
- Closing the bar with its X no longer resurrects it after visiting any
  menu.
- The y-axis max label steps aside on short canvases instead of colliding
  with the 75% label.

## [2.4.0] - 2026-08-23

The rescue update: a fifth graph view that scores your clutch heals, a
session library that remembers every fight, and a settings panel that grew
into its role. Battle-tested in trials, dungeons and battlegrounds, and
verified on the Update 51 PTS — ships declaring API 101051.

### Added
- **TRIAGE view** — a rescue-episode feed with your reaction time. When an
  ally drops below the configurable threshold (default 50%), Verdant tracks
  the episode: who, minimum health reached, outcome (your save / recovered
  without you / died / missed) and your response time, measured on direct
  casts only — HoTs attribute the save but never fake reflexes. Session
  strip with outcome dots, per-episode rows with class icons, RT graded by
  speed, and a Saves / RT50 / RT95 header. Hovering an episode explains its
  outcome in plain words.
- **Session Library** — with Session Autosave enabled (Settings >
  Recording, off by default) every recording is saved: last 24 sessions,
  lock favorites so they never rotate out. Open any session from the Lib
  button (or `/verdant lib`) and every view is restored exactly as it
  looked at Stop. Sessions are stored in a compact self-describing format
  (~3 KB each) with integrity checks.
- **Group death/res markers** on the timeline, toggleable (off by
  default), drawn smaller and dimmed under your own. Your own deaths wear
  a red skull, teammates' stay white.
- **Triage Threshold control** (30–75%) and **Session Autosave** toggle in
  a settings panel reorganized into titled sections (Profile / Bar / Graph
  / Recording / General). Unknown Contributions shows its pending count.
- **RT50 on the session summary chip** when reaction times were measured.

### Changed
- Windows dock magnetically: settings beside the graph window, the session
  library under it.
- Time window extends to 20 minutes (one-minute steps past 10m) for long
  boss fights, with bars that stay readable at any window length.
- The BUFFS view no longer hitches after long fights — rendering is
  bounded by screen pixels, not fight length — and buff timelines are
  time-quantized in memory.

### Fixed
- The assignment window's category picker is no longer transparent, and
  its confirmation dialog can't be covered by other windows.
- Heal attribution is immune to the game's power-update/combat-event
  ordering race.
- Roster names no longer degrade to "group N" after leaving the group.
- Buff-row icons no longer inherit tint from other views.
- The session library's list background no longer renders white under
  Update 51's backdrop behavior (found on the PTS, fixed for both APIs).

## [2.3.0] - 2026-08-22

The BUFFS update: a fourth graph view showing the uptime of every buff you
give your group, plus automatic recording, death markers and quality passes
across the whole graph window. Battle-tested in Hel Ra Citadel and Sanctum
Ophidia.

### Added
- **BUFFS view** — a Gantt timeline with one row per buff you applied while
  recording. Bars are union intervals (open while at least one group member
  still holds the buff), bar intensity encodes how many players hold it,
  and each row shows its uptime % once the session freezes. Hovering a row
  shows uptime, players reached, max/avg holders, applications, longest gap
  and what the buff actually does — pulled live from the game's own tooltip
  APIs, localized for free, nothing hardcoded.
- **Smart buff filtering** — the view shows the buffs your skills grant,
  not the skills themselves: cast auras, heal effects, debuffs, passive
  procs (Sacred Ground, Frost Safeguard, Tri Focus) and class mechanic
  states (Crux) are recognized structurally and excluded, and two curated
  tables (veto / block) always get the last word. Buffs whose single cast
  emits several ability ids merge into one row.
- **Automatic recording** — three modes: Off (default), Boss fights, Any
  combat. Starts when the fight starts, stops a few seconds after combat
  ends (re-entering combat during the grace window cancels the stop, so
  wipe-checks don't split the pull). Auto sessions show an AUTO marker and
  never overwrite a session you recorded manually.
- **Death and resurrection markers** — your deaths appear as a vertical
  line with a skull on every view; resurrections in green with the res
  icon.
- **Session summary** — after Stop, the window header shows AVG / PEAK /
  CRIT for the frozen session, colored in the chart's own language (green
  healing, pink EMS peak, gold crit).
- **Group damage overlay** — the EMS view draws incoming group damage as a
  red curve with a subtle area fill behind the healing bars, so you can see
  whether your output lined up with the damage. Hover shows the rate.
- **User-savable profiles** — save the current settings under your own name
  from the settings panel, load them from the dropdown, overwrite or delete
  them. Built-in presets unchanged.

### Changed
- Chart numbers (axis, hover, summary) show one decimal and the Y axis got
  a top label with the true chart maximum.
- Title-bar buttons aligned; BUFFS rows grow with window height instead of
  stretching; explicit draw layering across the whole chart.
- The graph window gained a header strip for the session summary (viewport
  moved down 22px).

### Internal
- Offline mock-ESO test harness (`test/harness/`, 15 cases, excluded from
  the release zip) and a build fingerprint in `/verdant report`.
- Release workflow now fails if DEBUG is left enabled.

---

## [2.2.0] - 2026-06-28

The big visual + performance pass: pixel-perfect chart decimation (M4), a
per-ability rich hover, and a redesigned SKILL view. The chart now stays smooth
at any sample rate or window length.

### Added
- **Pixel-perfect decimation (M4)** — the chart aggregates samples per pixel
  column, so it never draws more bars than the screen has pixels. FPS stays flat
  whether the recording holds 300 samples or 6000.
- **Rich hover** — hovering a skill segment now lists that group's abilities as
  icons, ranked by contribution, each with its healing number and percentage.
- **Datadog-style hover card** — crosshair, group highlight/dim, and a cursor
  card, built off the decimated hit-index.
- **Shield orientation toggle** — a SKILL-view setting to switch the shield
  subplot between growing up from the floor and hanging down from the healing
  bars (a diverging, mirror layout).
- **GC pacing** — incremental garbage collection per frame for smoother long
  fights.

### Changed
- **Independent SKILL-view scales** — healing (eHPS) and shields (MPS) now use
  separate vertical scales, so shields are no longer squashed against the
  healing peak.
- **Sampling rate capped at 5 Hz** (was 10) — above ~5 Hz only adds redundant
  bars, so the cap keeps long recordings light. Existing presets above 5 Hz
  snap down when the settings panel is next opened.

---

## [2.1.1] - 2026-06-06

Packaging fix — removed stray empty `.gitkeep` placeholder files from the
distributed zip (flagged on upload). No code or behavior changes from 2.1.0.

---

## [2.1.0] - 2026-06-07

A feature + performance pass on top of the 2.0.0 rewrite. New CRIT view,
two more skill-line colors, locale-aware number formatting, and a
zero-allocation graph sampling path. Update 50 ready.

### Added
- **CRIT view** — a third graph view splitting your healing into a muted
  green non-crit base and a bright gold crit cap, scaled against the
  window's max eHPS so the crit ratio reads at full vertical resolution.
  Cycles alongside EMS and SKILL.
- **Two new skill-line colors** — **Werewolf** (blood-moon russet) and
  **Psijic Order** (astral gold), bringing the classifier to 18 groups.

### Changed
- **Locale-aware number formatting** — abbreviated graph values now go
  through `ZO_AbbreviateAndLocalizeNumber` and raw bar values through
  `ZO_CommaDelimitNumber`, so DE/FR clients get the correct decimal and
  thousands separators (e.g. "12,3k" / "8.500"). EN output is unchanged.
- **Update 50 compatible** — manifest declares both API 101049 and
  101050, so the addon runs clean across the U49 → U50 transition with
  no out-of-date warning.

### Internal
- **Zero-allocation graph sampling path** — the per-sample data path now
  allocates 0 bytes. Group-share aggregation reuses module-level buckets
  with an in-place insertion sort (no `table.sort` over a reused array),
  metrics fill caller-owned tables (`eHPS_by_group_into` /
  `MPS_by_group_into`), and the temporal buffer copies groups in place.
  Verified on Live (`/verdant gcprobe` reports 0.00 B/sample under load).
- **Render scratch hoisted** — per-render scratch arrays moved to reused
  module-level tables (one set per render function, no cross-view
  aliasing), removing ~90% of per-frame render garbage.
- **Diagnostics gated to no-ops** in release builds before the 1 Hz
  sample tick is wired, keeping dev instrumentation fully out of the
  release hot path.
- **`/verdant gcprobe`** and **`/verdant report gc`** expose the GC probe
  (note: the probe clears the temporal buffer, so it is opt-in).

---

## [2.0.0] - 2026-05-09

A foundation rewrite focused on architecture, observability, and UX
polish. Numbers and visual behavior are unchanged from 1.1.0; the
internals are substantially different.

### Added
- **Configuration profiles** — Solo PvE / Group Dungeons / Trials / PvP
  / Custom presets at the top of the settings panel. Selecting a profile
  applies all gameplay-related sliders at once. Touching any slider
  switches to "Custom" automatically so manual tweaks aren't overwritten.
- **Reset to Defaults** button restores all sliders to a known-good
  state and reapplies it to the live state in one click.
- **Settings is now its own movable window** with title, close button,
  and persistent position. Both the bar and graph windows expose a gear
  button targeting it.
- **Time Window range extended** from 5 min to 10 min so end-game PvE
  boss fights fit a full recording. Combinations that produce a heavy
  capacity (`window_s × sample_hz > 1500`) emit a chat warning.
- **Visible slider tracks** with a dark inner panel; empty sliders no
  longer look like blank space.
- **/verdant help** lists the user-facing commands.

### Changed
- Slider fill color softened from primary yellow to warm amber, matching
  ESO's tooltip border palette.
- Settings gear icon enlarged (26x26 on the bar, 28x28 on the graph)
  and given a more contrasted texture so it reads as a real button.
- Graph window now has its own gear button — settings reachable from
  either window.

### Internal
- **ACL boundary**: every ZOS API access (events, constants, window manager,
  ZO_SavedVars, etc.) routes through `Verdant.zenimax.*`. Outside that
  namespace, no live code touches a bare ZOS global.
- **Event pool**: a 4096-record `VerdantEvent` pool replaces per-event `{}`
  allocation on the heal/shield/damage hot path. New `lib/mem/`
  with `buffer_pool`, `ring_buffer` and `event` modules.
- **Pipeline**: `core/engine.lua` is gone; combat events flow through
  `pipeline/{acquisition, filter, processing, presentation}.lua`. Each
  stage has a single responsibility; counter accounting preserved
  exactly through validation.
- **Plot library**: `lib/plot/` provides reusable visualization
  scaffolding (`style`, `primitives`, `pool`, `plot_stacked_bar`). The
  bar and graph widgets share the pool factory; the StackedBar composer
  absorbed per-skill segment rendering that was previously duplicated.
- **Observability**: profiler, validation, structured log, and a
  unified `/verdant report` command. Load-time `if not DEBUG then return end`
  gating keeps release-mode overhead negligible.
- **Localization**: hardcoded strings moved to `locales/`; `/verdant help`
  lists user-facing commands.

### Fixed during the rewrite
- ZO_ObjectPool reset callback signature documented as one-arg
  (`function(t)`) — saved future maintainers from the `function(_, c)`
  trap that nil'd the object.
- Self-fulfilling artifact in `/verdant report` — `validation.run_all_checks`
  is now a pure query and no longer mutates the log ring it's reporting on.
- `lib/plot/*` manifest order: must load **after** `zenimax/*` because
  it references `Verdant.zenimax.{constants,ui}` at module load time.

---

## [1.1.0] - 2026-05-05

### Added
- **Temporal Analytics** — a new graph window (toggle via the icon on the bar) that records eHPS / MPS / EMS over time. Two views: a stacked EMS view with Y-axis grid and time labels, and a SKILL view with two sub-plots breaking down healing and shield contribution by class / skill-line over time. Both views share the same Y-axis range so they are directly comparable.
- **Datadog-style fixed-width bars** — sample bars now have a stable width derived from the buffer capacity, so the chart slides left at a steady cadence once the buffer is full instead of compressing as samples accumulate.
- **Auto-hide on UI scenes** — bar and graph windows hide automatically while the player has the inventory, map, journal or any other full-screen UI open, and restore on return to gameplay. User intent is preserved across scene transitions.
- **Master keybind toggle** — the Verdant keybind now closes every open window in one shot, or opens the bar if everything is closed.
- **Settings — Sampling Rate** slider (1, 2, 5, 10 Hz) controlling the temporal buffer's sample cadence.
- **Settings — Time Window** slider (15 s → 5 min in 15 s steps) controlling the temporal buffer's capacity.
- **Settings — Heal/Shield window** sliders unified to a 1–30 s range with 1 s step so the two are directly comparable.
- **Flush button** on the graph window: stops recording and clears the buffer in one action.
- **Resize bounds** for the graph window so the layout cannot collapse below a usable size.

### Changed
- Graph window restructured into a two-layer architecture: outer container holds the controls (Start / Stop / Flush / view nav), inner viewport hosts the canvases — produces a clearer "embedded panel" visual hierarchy.
- Polylines are now suppressed when bars are too narrow for the line to add visual signal (saves up to 65% of the per-render control count at high capacities).
- Icon overhaul on the bar and graph windows using native ESO art (`tree_closed`, `swatchframe`, `scrollbox_downarrow`, `pointsplus`, `large_*arrow`, `decline`, `chat_options`).

### Fixed
- Phantom polyline segments that lingered during recording at high sample rates: lines now invalidate their cached geometry every render via `SetThickness`, so the descent line never duplicates as the buffer slides.
- Time labels on the SKILL view's MPS sub-canvas now render even when only healing has been recorded (previously suppressed because the empty MPS scale skipped the entire grid).

---

## [1.0.1] - 2026-05-03

### Fixed
- SavedVars now include `GetWorldName()` as namespace — EU, NA and PTS settings are kept separate for the same `@account`.
- Skill-color fill pools migrated from a hand-rolled pre-allocated table to `ZO_ObjectPool`, as recommended by ESOUI best practices.

### Changed
- Localization strings moved from a private `Verdant.L` table to the standard ESO `ZO_CreateStringId` / `GetString` pattern.
- Locale file renamed from `locales/en.lua` to `locales/default.lua`; manifest now also loads `locales/$(language).lua` so future community translations can be dropped in without touching the manifest.

---

## [1.0.0] - 2026-05-02

Initial public release.

- Real-time contribution bar tracking eHPS, MPS and EMS.
- Four display modes: EMS (stacked heal+shield fill), eHPS, MPS, ALL (three columns).
- Skill-color segmentation — one color per class / skill-line.
- Configurable refresh rate, heal window and shield window.
- Open-world efficiency mode and group coverage mode with automatic switching.
- Keybinding to toggle the bar (Controls → Verdant).
- Account-wide SavedVars.
