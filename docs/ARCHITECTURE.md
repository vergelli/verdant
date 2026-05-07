# Verdant — Architecture

This document is a high-level overview of how Verdant is organized
internally. Detailed specifications (SPEC_00..SPEC_05) live alongside
the codebase in `specs/` and are intended for maintainers; this file
is the entry point for anyone reading the code for the first time.

## Shape of the system

Verdant is a **dataflow pipeline**. Combat events arrive from the
ZeniMax client, get normalized, filtered, ingested into rolling
metrics, and then projected onto bar / graph / tribar widgets. The
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
                shield registry, skill colors, mode. No I/O.

lib/            Reusable utilities. lib/plot/ owns visualization;
                lib/mem/ owns pools and ring buffers.

ui/             Widgets (bar, graph, tribar, settings). Read from
                pipeline/presentation; do not reach into core/.

observability/  Logging, profiling, validation. Cross-cutting; may
                be called from anywhere; release-mode no-op.

config/         User-configurable settings: schema, defaults, presets.
                Read by anyone, written by the settings UI.
```

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

The SPEC files are not shipped with the addon and are not part of the
release zip; they are working documents for the codebase maintainers.
