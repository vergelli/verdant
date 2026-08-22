# Changelog

## [Unreleased]

### Added
- **Death and resurrection markers** — your deaths show as a vertical line
  with a skull on every graph view (EMS, SKILL, CRIT, BUFFS), and the
  moment you are resurrected shows in green with a resurrect icon. Captured
  while recording via the player death-state event, cleared on Flush.

### Fixed (round 13, Sanctum Ophidia evidence)
- **Tri Focus resurrected by the veto** — the r12 veto used the skill-color
  override table, which serves a different purpose (SKILL-view shield
  coloring), so Tri Focus (69773, curated there for colors) slipped back
  into the gantt. The gantt now has its own dedicated curation tables:
  BUFF_VETO (force-include: the three Warding Contingency ids) and
  BUFF_BLOCK (force-exclude, empty so far). Color classification and gantt
  filtering no longer share state.

### Fixed (round 12, boss-fight evidence)
- **Skill procs shielding allies (Frost Safeguard) excluded** — the last
  leak category: passive procs with no skill keys that reach other players.
  The trial evidence exposed the discriminator we already computed:
  genuine granted buffs always classify as "other" (ability_buff_* icons)
  or "item"; anything classifying to a class/weapon skill line via its
  icon is the proc OF a skill. Those are now excluded as
  "skill-line proc (<line>)", with the curated-override veto still on top.

### Fixed (round 11, Hel Ra trial evidence)
- **Curated overrides veto the filters** — Warding Contingency fell to the
  new skill-aura rule because scribing grimoires do have skill keys. Ability
  ids you have explicitly classified (ABILITY_OVERRIDES or in-game
  assignments) now bypass the skill-aura and self-state exclusions: your
  curation is the human veto over the heuristics. Removing the override
  removes the veto.

### Fixed (round 10, trial evidence)
- **Self states leaking back in groups** — in a group you also carry a
  group tag, so your own buffs fire the effect event twice (player + groupN)
  and the duplicate broke the self-only detection: Crux, Sacred Ground and
  externally-granted synergy buffs (Feeding Frenzy) reappeared in trials.
  Self-detection now compares unit ids (the player id is learned from the
  player-tagged event), immune to the duplicate.
- **Skill auras (Tri Focus, Sacred Ground) excluded structurally** — any
  aura whose id resolves to valid skill-tree keys is the aura OF a skill
  (active or passive), not a granted buff, and is excluded with reason
  "skill aura". Granted Major/Minor buffs have no skill keys, so they are
  untouched.

### Fixed
- **Duplicate buff rows** — buffs whose single cast emits several ability ids
  (Combat Prayer, Channeled Focus, Warding Contingency...) now merge into one
  row by name; a unit holding two ids of the same buff counts as one holder.
  The report lists the merged ids and the classified group per row.
- **BUFFS rows vs window height** — the row cap is gone: resizing the window
  vertically now reveals more rows (bars stop stretching past 26px), so the
  "+N more" hint is finally honest. Tracker capacity raised 24 → 48.
- **Buffs now have their own identity color** — unclassified buffs render in
  Verdant's healing green (the same tone as the EMS chart) instead of grey.

### Added (BUFFS view)
- **Buff descriptions on hover** — the hover card now tells you what the buff
  actually does ("Increases your damage done by 5%"). Nothing hardcoded and
  localized for free: descriptions resolve through a three-step chain at the
  moment the buff lands — `GetAbilityDescription(id, nil, "player")` (caster
  context), then the plain id lookup, then the live buff-slot tooltip
  (`GetUnitBuffInfo` + `GetAbilityEffectDescription`, the same text the
  game's buff bar shows), which only exists while the buff is active. The
  report counts which source resolved each one (`buffs.desc_from_*`).
- **Session summary placement** — the AVG/PEAK/CRIT chip moved out of the
  viewport into its own strip in the window header, under the button row.
- **Profile save UX** — the name field sits right under the profile dropdown
  with a "save profile as..." hint instead of hiding at the bottom.
- **Bogus peak timestamp** — sessions with zero healing no longer report a
  negative `peak_at` in the summary.

### Changed (round 9)
- **Damage overlay presence** — the group-damage curve on the EMS view now
  has a subtle red area fill under the line (alpha 0.10) and a stronger
  line (alpha 0.60), sitting explicitly behind the healing bars via draw
  levels (fill 1 < bars 2 < lines 3). Visible on dense charts too, where
  the polyline alone used to vanish.

### Fixed (round 8, in-game evidence)
- **Blockade of Frost coming back** — the slot's display name depends on
  which bar is active when Record is pressed ("Elemental Blockade" vs
  "Blockade of Frost"), so a single scan could miss the elemental name. The
  tracker now rescans both bars on every weapon swap, accumulates the names,
  and retroactively purges rows that turn out to match a slotted skill.
- **Axis vs hover rounding** — values were abbreviated to whole units
  ("3K" for 3.2K), so bars could visually exceed a gridline their hover
  seemed to contradict. All chart numbers (axis, hover, summary chip) now
  show one decimal, and the Y axis gained a top label with the true chart
  maximum, so the scale is explicit.

### Fixed (round 7, regression)
- **Everything excluded as "renamed aura"** — the skill-keys API returns a
  0,0,0 sentinel for abilities that belong to no skill, and one slotted
  entry returned the same sentinel, so every generic buff matched it and
  the tracker went empty. Keys are now validated the same way SkillColors
  does (> 0), with a harness case pinning the sentinel behavior.
- **Rows vanishing at Stop** — self-only mechanic states were rendered
  during live recording and removed on finalize, which read as rows
  disappearing. The live view now applies the same visibility rule, so
  what you see while recording is what survives the Stop.

### Fixed (round 6, in-game evidence)
- **Renamed morph auras filtered** — "Blockade of Frost" escaped the slotted
  filter because the aura renames per staff element while the slot says
  "Elemental Blockade". Slotted skills are now also matched by skill keys
  (the same family identity SkillColors uses), which is invariant to morph
  and elemental renames.
- **Set procs get an honest tooltip line** — item-proc rows without an
  engine description (Ozezan's Plating, Pillager's Profit — now classified
  as Item Set) show "Item set effect - the game exposes no tooltip for this
  proc." instead of a silently missing line.
- **Description race fixed** — some buffs (Minor Vitality) raced the buff
  list at GAINED time and stayed descriptionless; the 1 Hz session tick now
  retries unresolved descriptions against your own buff bar.

### Fixed (round 5, in-game evidence)
- **Mechanic states filtered from the BUFFS view** — class resources and
  passive proc-states (Crux, Sacred Ground) are not buffs you maintain on
  the group, so they no longer occupy rows. Two layers: abilities flagged
  passive by the engine are rejected on sight, and rows that only ever
  touched yourself AND have no tooltip are dropped when the session freezes
  (item procs like Ozezan's Plating are exempt so they survive solo
  parses). Every exclusion is listed in the report with its reason, and
  tracked rows now show a `self=y/n` marker.

### Fixed (round 4, in-game evidence)
- **Ability auras filtered by your own action bars** — the engine types the
  short "Combat Prayer" aura as a legitimate buff, so type-based filtering
  could not catch it. The tracker now scans both hotbars at Record time and
  excludes any buff whose name matches a slotted ability: what remains is
  exactly what your skills grant (Minor Berserk, Major Courage...), not the
  skills themselves. The report prints the scanned slot names and every
  exclusion with its reason.
- **Description still ellipsized** — the label height was clamping the text
  measurement in a feedback loop; the card now measures against an
  unclamped height before sizing.
- **Build fingerprint** — the report header and the DEBUG load message now
  print the build tag, so evidence is unambiguous about which code ran.

### Fixed (round 3, in-game evidence)
- **Cast abilities no longer pollute the BUFFS view** — the tracker was
  ingesting every player-sourced effect, so the casting ability (Combat
  Prayer, Radiating Regeneration...) showed its own short bar next to the
  buffs it grants. Effects are now gated by the event's own typing: only
  `BUFF_EFFECT_TYPE_BUFF` and never `ABILITY_TYPE_HEAL`. Whatever gets
  filtered is listed in the report ("excluded as non-buffs") with its raw
  types, so misfires are visible instead of silent.
- **Buff description cut off with "..."** — the hover description now allows
  unlimited wrapped lines (`SetMaxLineCount(0)`).

### Fixed (round 2, in-game evidence)
- **Combat Prayer classified as Sorcerer** — the engine's skill-key API
  mistags its new effect ids (218784/218786/218787); pinned to Restoration
  Staff via ABILITY_OVERRIDES. This was the mysterious blue row.
- **Buff descriptions burning retries on tagless units** — description
  capture now only spends attempts on events that carry a unit tag, and
  retries up to 5 times, so short AoE buffs get more chances to resolve via
  the live buff-slot tooltip.

### Changed
- **UI consolidation pass** — title-bar buttons of the graph window now share
  one vertical center line; the summary chip uses the chart's own encoding
  (green = healing, pink = EMS peak, gold = crit) instead of two
  near-identical golds; the BUFFS view gained faint row lanes so bars read
  as a timeline, and each row shows its uptime % at rest once the session
  is frozen.

### Added
- **User-savable profiles** — type a name in the settings panel and Save to
  store the current configuration as your own profile (marked with * in the
  dropdown). Load it any time from the dropdown, overwrite it by saving with
  the name selected, or Delete it. The built-in presets stay as before.
- **Group damage overlay** — the EMS view now draws incoming group damage as
  a faint red line behind the healing bars, so you can see whether your
  output lined up with when the group was actually taking damage. The hover
  card on a frozen session includes the damage rate at that moment.
- **Automatic recording** — new setting with three modes: Off (default),
  Boss fights, Any combat. In boss mode the recording starts when a boss is
  up and you enter combat, and stops a few seconds after combat ends (the
  grace window survives wipe-checks: re-entering combat cancels the stop).
  Zone changes stop the recording. Auto sessions show an AUTO marker in the
  graph header and never overwrite a session you recorded manually. All
  transitions land in `/verdant report` under "auto record".
- **BUFFS hover card** — hovering a row in the frozen BUFFS view shows the
  buff's uptime %, total uptime, players reached, max/avg holders, casts and
  longest gap, plus the holder count at the exact time under the cursor.
  Other rows dim while hovering, same crosshair language as the other views.
- **BUFFS view** — fourth graph view: a Gantt timeline with one row per buff
  you applied during the recording. Each bar spans the union interval (open
  while at least one group member still holds the buff) and its intensity
  encodes how many players hold it at that moment. Rows show the ability icon
  and name, capped to what fits the window with a "+N more" hint.
- **Buff tracker (engine)** — while recording, Verdant now tracks every buff
  you apply: union uptime intervals (a bar stays open while at least one
  group member still holds the buff), concurrency curve, applications,
  unique targets and longest gap. Watchdog expiry covers targets that never
  send a FADED event. Full session detail lands in `/verdant report` under
  "buff tracker". Feeds the upcoming BUFFS view.
- **Session summary chip** — after Stop, the graph shows AVG / PEAK / CRIT for
  the frozen session in the top-right corner of the viewport. Computed once on
  Stop, cleared on Record/Flush. The same numbers appear in
  `/verdant report` under "session summary".

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
