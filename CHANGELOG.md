# Changelog

## [1.1.0] - 2026-05-05

### Added
- **Temporal Analytics** — a new graph window (toggle via the icon on the bar) that records eHPS / MPS / EMS over time. Two views: a stacked EMS view with Y-axis grid and time labels, and a SKILL view with two sub-plots breaking down healing and shield contribution by class / skill-line over time. Both views share the same Y-axis range so they are directly comparable.
- **Datadog-style fixed-width bars** — sample bars now have a stable width derived from the buffer capacity, so the chart slides left at a steady cadence once the buffer is full instead of compressing as samples accumulate.
- **Auto-hide on UI scenes** — bar, graph and tribar windows hide automatically while the player has the inventory, map, journal or any other full-screen UI open, and restore on return to gameplay. User intent is preserved across scene transitions.
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
