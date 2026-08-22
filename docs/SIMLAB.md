# SimLab — offline simulation laboratory

Runs the full addon (pipeline, metrics, buff tracker, graph render) against
scripted combat without the game. Built on the mock-ESO harness
(`test/harness/`). Nothing under `test/` ships in the release zip.

## What it validates

| Aspect | Coverage | Still needs in-game |
|---|---|---|
| Metric math (eHPS/OHPS/MPS/EMS/D_group/crit) | Oracle recomputes every metric naively from the raw event log and compares against the addon's incremental hot path at 4 Hz. Tolerance 1e-6. | New ZOS API behavior never captured |
| Window/config semantics | Oracle reads the live window config, so changing heal/shield windows is covered | — |
| Foreign-event filtering | Scenarios and replayed traces include events the addon must reject | First sighting of each engine quirk |
| UI geometry & palette | Layout-aware mock resolves the real anchor chains; SVG snapshots render the window | DDS textures, fonts, feel |
| Zero-alloc / perf | gcprobe runs in the harness; wall-clock printed per scenario | Havok VM timing |
| Real-world event streams | Trace capture + replay (see below) | Capturing the trace |

## Commands

```
lua test/simlab/run.lua .                    all scenarios
lua test/simlab/run.lua . trial_boss        one scenario
lua test/simlab/run.lua . --svg             + SVG snapshots of all 4 views
lua test/simlab/replay.lua . <SavedVars/Verdant.lua> [--svg]
lua test/harness/run.lua . 1                unit cases, DEBUG on
```

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

## Extending

New metric → add its naive recompute to `oracle.lua` and a `cmp` line in
`O.check`. New scenario → drop a spec in `scenarios/` and list it in
`run.lua`. The engine API: `group, at, every, hit, heal, shield_on, absorb,
res, combat, bosses, lowest`.
