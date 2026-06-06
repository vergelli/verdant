# Changelog

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
