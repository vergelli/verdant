# Changelog

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

### Internal architecture (8-phase rewrite)
- **Phase 1**: every ZOS `EVENT_MANAGER` / constant access routes through
  `Verdant.zenimax.{events,constants}` — a single-file ACL boundary.
- **Phase 2**: `lib/mem/{buffer_pool,ring_buffer,event}.lua` —
  `VerdantEvent` pool (4096 records) eliminates per-event `{}` allocation
  on the heal/shield/damage hot path.
- **Phase 3**: `Verdant.zenimax.{api,ui,savedvars}` — completes the ACL.
  Outside `zenimax/`, no live code touches a bare ZOS global.
- **Phase 4**: `core/engine.lua` replaced by the four-stage pipeline
  (`pipeline/{acquisition,filter,processing,presentation,pipeline}.lua`).
  Each stage has a single responsibility; counter accounting preserved
  exactly through validation.
- **Phase 5**: `lib/plot/` — reusable visualization scaffolding
  (`style`, `primitives`, `pool`, `plot_stacked_bar`). Bar and graph
  widgets routed through the shared pool factory; the StackedBar
  composer absorbed the per-skill segment rendering previously
  duplicated four times.
- **Phase 6**: observability layer with negligible release-mode cost —
  load-time `if not DEBUG then return end` gating. New: `/verdant prof`
  per-stage percentile profiler, `/verdant validate` invariant checks,
  `/verdant log` structured ring, `/verdant report` one-shot dev dump.
- **Phase 7**: settings UX rebuild + profiles (this release's headline
  feature).
- **Phase 8**: ESOUI guideline compliance, locales, dead code removal,
  documentation pass.

### Fixed during the rewrite
- ZO_ObjectPool reset callback signature documented as one-arg
  (`function(t)`) — saved future maintainers from the `function(_, c)`
  trap that nil'd the object.
- `ZoFontGameMedium` does not exist in stock ESO and silently falls
  back to the default font; previously prototyped font scale slider was
  removed once this surfaced.
- Self-fulfilling artifact in `/verdant report` — `validation.run_all_checks`
  is now a pure query and no longer mutates the log ring it's reporting on.
- `lib/plot/*` manifest order: must load **after** `zenimax/*` because
  it references `Verdant.zenimax.{constants,ui}` at module load time.

### Out of scope (deferred to v2.x)
- Buff/debuff timeline view (`VerdantEffectEvent` pool + `plot_buff_timeline.lua`).
- Architectural extraction of a `config/` module per SPEC_05 §Phase 7.
  The settings UX rebuild was prioritized; the architecture refactor
  can land later if it earns its keep.

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
