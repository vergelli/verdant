# Verdant — Architecture

This document is a high-level overview of how Verdant is organized
internally. Detailed specifications (SPEC_00..SPEC_05) live alongside
the codebase in `specs/` and are intended for maintainers; this file
is the entry point for anyone reading the code for the first time.

## Shape of the system

Verdant is a **dataflow pipeline**. Combat events arrive from the
ZeniMax client, get normalized, filtered, ingested into rolling
metrics, and then projected onto bar / graph widgets. The
implementation pattern is **pipeline architecture** combined with a
**hexagonal boundary** at the ZOS API edge — not full Clean
Architecture. The single Clean rule we keep is: **dependencies flow
inward**.

## Layers

```
zenimax/        Anti-Corruption Layer. The ONLY place that imports
                ZeniMax globals (EVENT_MANAGER, GetUnitName, …).

pipeline/       Dataflow stages: acquisition → filter → processing
                → presentation. Drives the addon at runtime.

core/           Pure domain logic: metrics, coverage, group set,
                shield registry, skill colors (built-in and user
                categories), mode, the temporal buffer, the session
                store, the session trackers (triage, buffs, ultimate
                per bar, buff watch) and the frame hitch watcher.
                No I/O.

lib/            Reusable utilities. lib/plot/ owns visualization
                (pools, stacked bars, the cooldown-based donut);
                lib/mem/ owns pools and ring buffers; lib/vsf.lua
                is the session serialization format.

ui/             Widgets (bar, graph with its view tabs, hover cards
                and healing report, settings, library, assign with
                its category creator, watch overlay, logo, the DEBUG
                donut probe). Read from core state; do not own
                domain logic.

observability/  Logging, profiling, validation, diagnostics, copy
                box. Cross-cutting; may be called from anywhere;
                profiler and diagnostics are release-mode no-ops,
                the copy box and the hitch log are not.

test/           The offline lab: mock-ESO harness, SimLab scenarios
                with an error-zero oracle, SVG snapshots and the
                layout auditor (docs/SIMLAB.md). Never shipped.
```

Configuration has no layer of its own: presets and persistence live in
`ui/settings.lua` over the SavedVars table the ACL opens.

Inner layers know nothing about outer layers. Circular dependencies
are not allowed.

## Hot path vs cold path

Two execution regimes shape implementation choices:

- **Hot path** — event handlers, render loops. Allocations cause GC
  spikes; indirection costs measurable frame time. Pool everything.
- **Cold path** — bootstrap, settings changes, slash commands.
  Allocations and indirection are free.

Modules and functions should be classifiable as one or the other.
Mixing both regimes in a single module without clear separation is
a smell.

Two offline tripwires keep the hot path honest (`test/harness/cases/
zero_alloc.lua`): the sample path must allocate under 200 bytes per
tick and every view's render under 400 bytes per tick over the hidden
baseline, both measured addon-side. `docs/RENDER_BUDGET.md` has the
numbers and the tool (`test/harness/perf.lua`).

The one deliberately slow operation, session capture at Stop, runs as
a cooperative coroutine over the frames after the click (`core/
session_store.lua`); anything that clears the buffer calls
`finish_autosave()` first. In-game, `/verdant hitch` lists frames over
80ms and whether Verdant did anything in them.

## Globals discipline

Verdant exposes exactly **one** Lua global: `Verdant`. All sub-modules
attach to it as `Verdant.X`. The bootstrap (`Verdant.lua`) is the only
file that wires modules together.

## Single-threaded reality

The addon runs in a single Lua VM on the game's main thread. There is
no OS-level threading. The "pipeline" we build is sequential within a
frame; the value is separation of concerns, not parallelism.

## Entry points

- `Verdant.lua` — bootstrap and slash-command dispatch.
- `Verdant.txt` — manifest, declares the load order and addon metadata.
- `bindings.xml` — keybinding declarations.

## Further reading

For maintainers, the `specs/` folder contains the authoritative design:

- `SPEC_00_ARCHITECTURE.md` — principles, target tree, dependency rules.
- `SPEC_01_ZENIMAX_LIB.md` — the ACL contract.
- `SPEC_02_PLOT_LIB.md` — plot library (lib/plot).
- `SPEC_03_PIPELINE.md` — stage contracts and event schemas.
- `SPEC_04_OBSERVABILITY.md` — log, profiler, validation layers.
- `SPEC_05_MIGRATION.md` — phased plan from v1.1.0 to v2.0.
- `SPEC_VSF.md` — the session serialization format.

Working notes that are kept up to date with the code:

- `docs/SIMLAB.md` — the offline lab and how to run it.
- `docs/RENDER_BUDGET.md` — per-tick budgets, the stop path, the
  200-local ceiling of `ui/graph.lua`.
- `docs/DONUT_RESEARCH.md` — why the donut is a cooldown control.
- `docs/BACKLOG.md` — engineering backlog.

The SPEC files are not shipped with the addon and are not part of the
release zip; they are working documents for the codebase maintainers.
