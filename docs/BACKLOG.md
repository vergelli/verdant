# Verdant — Backlog

> Status 2026-09-03 (night): 2.5.0 is feature complete on develop
> (PRs #85–#138): the report chip and card, OHEAL, per-bar ultimate
> rows, TRIAGE rebuilt around a donut, view tabs, tooltips and sounds on
> every button, custom categories, session names and rings in the
> library, buff-watch chimes, keybinds, the hitch watcher, a stop path
> that no longer stutters. First in-game rounds done by Fede; still
> pending before tagging: his TRIAGE / tabs verdict and the joint pass
> over every explanation string. Listing materials are drafted in
> `VerdantWorkingdir/esoui/2.5.0/`. Items 1–3 below shipped back in
> 2.3/2.4 and stay for reference.
>
> Open after 2.5.0: #99 (switch the donut to origin mode only if the
> in-game probe ever proves the unit), #103 part 2 (diff-based anchoring,
> only if in-game profiling asks for it), #110 predictive layer
> (deprioritized by Fede).

Engineering backlog for Verdant. Items here are committed intent, not
speculation; ideas that have not earned a slot yet live in
`development/projects.md`.

Ordering is by intended sequence, not priority: each block is small
enough to land on its own without leaving the addon half-migrated.

---

## 1. BUFFS view — Gantt of self-applied buff uptime

A fourth view (`EMS / SKILL / CRIT / BUFFS`) rendering one horizontal
Gantt row per buff **I** applied, over the recorded session timeline.

**Semantics**

- A row's bar is the *union* interval during which at least one unit
  still carries the buff I applied. The bar only breaks when the buff
  has faded from **every** target.
- Concurrency (how many players hold the buff right now) is encoded
  visually inside the bar. Working proposal: alpha/intensity ramp
  normalized to the max concurrency observed in the session. Fallback
  under discussion: sub-bar height, or a thin stacked count strip.
- While recording, the view is bars-only — no hover — exactly like the
  existing views (`hover_allowed()` already gates on
  `TemporalBuffer.is_recording()`).

**Hover card (frozen session only)**

- Buff name + icon.
- Total uptime (ms) and uptime % of session length.
- Unique players reached.
- Max concurrent holders / average concurrent holders.
- Application count (re-casts) and longest gap.

**Data source**

`EVENT_EFFECT_CHANGED` is already registered with
`REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE = COMBAT_UNIT_TYPE_PLAYER`
(`pipeline/pipeline.lua`, `Verdant_E_EffectPlayer`), so the feed exists
and `ShieldRegistry` already consumes it. The new tracker mirrors that
module's shape: keyed by `(abilityId, unitId)`, with `endTime`-based
stale expiry for the case where FADED never arrives.

**Known risks — resolve with a spike before building UI**

- Whether FADED reliably fires for group members that go out of range
  or die. `ShieldRegistry.expire_stale` exists precisely because it
  does not always.
- Effect volume: passives, food, proc sets and mundus all arrive on the
  same feed. The view needs a relevance filter and a row cap, or it
  becomes unreadable.
- Interval storage must not allocate per event on the hot path.

---

## 2. Post-STOP header metrics

Derived session metrics shown in the graph header, computed once on
STOP from the frozen `TemporalBuffer`. Blank during recording.

Non-negotiable constraint: **clarity**. Users have specifically praised
Verdant for being readable without a statistics background. Three
slots maximum, plain words, no jargon.

Candidates (pick the three that carry most meaning):

- `AVG` — mean EMS across the session.
- `PEAK` — max EMS, optionally with its timestamp.
- `CRIT%` — crit share of healing.
- `TOTAL` — absolute healed + shielded for the session.
- `ACTIVE` — share of the session with non-zero output.

---

## 3. Automatic recording (PvE boss fights)

Start recording when a boss encounter begins, stop when it ends, so the
user never has to reach for the Record button mid-pull.

**Detection**

- Primary: `EVENT_BOSSES_CHANGED` plus the `boss1..bossN` unit tags
  (`BOSS_RANK_ITERATION_BEGIN..END`, see
  `esoui/ingame/unitframes/bossbar.lua`) gated on `IsUnitInCombat`.
- Fallback for trash / bossless pulls: `EVENT_PLAYER_COMBAT_STATE`
  with a grace period before committing a stop.
- Scope the whole feature to group/instance content; it should stay
  dormant in the overland.

**Behaviour**

- Setting with three states: off / boss only / any combat.
- Auto-record must never silently discard a frozen session the user is
  currently inspecting — `on_record_click` clears the buffer today.
- Optional pre-roll so the opening seconds of the pull are not lost.

---

## Carried over / cross-addon

- Sub-pixel moiré on bar rendering — RESOLVED here (uniform bar width
  per render, fractional slack absorbed by the gaps, PR #93). Still
  pending the same one-line port in Vermilion, Verditer and bgmeter.
- Zero-alloc render pass — DONE: scratch arrays live in one table (SCR),
  the iterate closures are gone (indexed `TemporalBuffer.at`), and the
  render path has its own tripwire (400 B/tick over the hidden baseline)
  next to the sample-path one. Numbers and tool in docs/RENDER_BUDGET.md.
  Next step, only if in-game profiling asks for it: diff-based anchoring
  instead of release-all / re-anchor (~500 anchors per tick on EMS).
