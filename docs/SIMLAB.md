# SimLab — offline simulation laboratory

Runs the full addon (pipeline, metrics, buff tracker, graph render) against
scripted combat without the game. Built on the mock-ESO harness
(`test/harness/`). Nothing under `test/` ships in the release zip.

## What it validates

| Aspect | Coverage | Still needs in-game |
|---|---|---|
| Metric math (eHPS/OHPS/MPS/EMS/D_group/crit) | Oracle recomputes every metric naively from the raw event log and compares against the addon's incremental hot path at 4 Hz. Tolerance 1e-6. | New ZOS API behavior never captured |
| Triage FSM (episodes, S/S*/O/L/M/X matrix, RT quantiles) | Batch oracle re-derives episodes from the recorded power/heal/death streams and compares exact counts and RT50/RT95 at stop | Real EVENT_POWER_UPDATE rates (the trace answers this) |
| Window/config semantics | Oracle reads the live window config, so changing heal/shield windows is covered | — |
| Foreign-event filtering | Scenarios and replayed traces include events the addon must reject | First sighting of each engine quirk |
| UI geometry & palette | Layout-aware mock resolves the real anchor chains; SVG snapshots render the window | DDS textures, fonts, feel |
| Zero-alloc / perf | gcprobe runs in the harness; wall-clock printed per scenario | Havok VM timing |
| Real-world event streams | Trace capture + replay (see below) | Capturing the trace |

## Commands

```
lua test/simlab/run.lua .                    all scenarios
lua test/simlab/run.lua . trial_boss        one scenario
lua test/simlab/run.lua . --svg             + SVG snapshots of all 6 views
lua test/simlab/mockups.lua .               window mockups (settings, bar, watch, library, donut probe, report card)
lua test/simlab/audit.lua .                 layout audit over out/*.svg
lua test/simlab/replay.lua . <SavedVars/Verdant.lua> [--svg]
                                            (then audit; the three traces under
                                            VerdantWorkingdir/traces/ are the
                                            pre-release corpus)
bash test/gate.sh                           the merge gate: everything below plus
                                            the trace replays, one exit code
lua test/harness/run.lua . 1                unit cases, DEBUG on
lua test/harness/perf.lua . 0 40 [VIEW]     render budget per view (docs/RENDER_BUDGET.md)
```

The audit parses every snapshot in `out/` and flags controls drawn outside
their window, text pairs that overlap, and text running under a button.
Labels carry their real width (`data-w`) so clipping and wrapping are
modeled; the text-width estimate is ~0.55px per char per font pixel.

SVGs land in `test/simlab/out/` (gitignored). Open in any browser; grey
rectangles are DDS textures (path in the tooltip).

## Scenarios

- `trial_boss` — 12 players, 180 s, sustained AoE + tank spikes + scripted
  deaths/resurrections. ~25 events/s.
- `dungeon_pull` — 4 players, 90 s, bursty trash pulls with reactive healing.
- `burst` — 12 players, 30 s stress at ~110 events/s.

Scenarios are deterministic (seeded LCG). The engine models per-member HP, so
overheal emerges from the model instead of being scripted.

## Trace capture (the bridge to reality)

In-game, DEBUG build only — every path is a no-op stub for release users:

```
/verdant trace start      begin capturing raw event streams (cap 40k)
/verdant trace stop
/verdant trace save       stage to SavedVars, then /reloadui to flush
/verdant trace clear      wipe buffer + SavedVars
```

Then offline:

```
lua test/simlab/replay.lua . "C:/Users/<you>/Documents/Elder Scrolls Online/live/SavedVariables/Verdant.lua"
```

One captured trial becomes a permanent regression corpus: real multi-tag
duplicates, engine mistags and foreign events, replayable forever without
re-entering the game. The oracle runs during replay, so divergences between
the formal model and the hot path surface on real data too.

The trace also records group health power updates (C++-filtered to
health + group tags), so a single captured dungeon answers the open
triage question: the real EVENT_POWER_UPDATE rate under load. The report's
triage section prints the observed rate live (`power_updates=N rate=X/s`).

## Extending

New metric → add its naive recompute to `oracle.lua` and a `cmp` line in
`O.check`. New scenario → drop a spec in `scenarios/` and list it in
`run.lua`. The engine API: `group, at, every, hit, heal, shield_on, absorb,
res, combat, bosses, lowest`.
