# Render budget

What one sample tick costs while the graph window is open, measured offline
against the mock. The sample path (metrics → temporal buffer) has been
zero-alloc since 2.4; this is about the render pass that runs after it.

## How to measure

```
lua test/harness/perf.lua . 0 40            release build, 40 ticks per view
lua test/harness/perf.lua . 1 40            DEBUG build
lua test/harness/perf.lua . 0 40 EMS        + allocation by function for one view
```

Per view the report gives CPU per tick (mock time, only useful relative to
other views), bytes allocated per tick by addon code, and the number of
control method calls broken down by method. The mock counts every method
call through its control metatable and attributes allocations to the
addon function on top of the Lua stack, with C functions charged to their
caller and the harness itself excluded. The addon's own GC pacer frees
memory during the window, so the meter only sums positive buckets.

`HARNESS.addon_alloc(fn)` is the primitive; `test/harness/cases/zero_alloc.lua`
uses it as a tripwire: every view must allocate less than 400 bytes per
tick over the hidden-window baseline, in both build modes.

## Numbers (release build, 60s window, 14 events per tick)

| view   | alloc before | alloc after | calls/tick | anchors/tick |
|--------|-------------:|------------:|-----------:|-------------:|
| EMS    | 1254 B       | 302 B       | 2445       | 509          |
| SKILL  | 1145 B       | 193 B       | 1118       | 223          |
| CRIT   | 1145 B       | 193 B       | 1080       | 213          |
| OHEAL  | 1145 B       | 193 B       | 1501       | 273          |
| BUFFS  | 86 B         | 86 B        | 17         | 0            |
| TRIAGE | 495 B        | 495 B       | 17         | 0            |
| hidden | 72 B         | 72 B        | 3          | 0            |

What went away: the closure each view created for `TemporalBuffer.iterate`
(224 B), the one inside `decimate` (336 B) and the `flush` closure inside
the ultimate band painter (392 B). Views now walk the buffer with
`TemporalBuffer.at(i)` and the band uses a module-level segment painter.
`Triage.summary()` also stopped returning fresh tables; callers only read
scalars off it, like `TemporalBuffer.summary()` already did.

What remains, and why it stays:

- `ultimate.lua:45` (100 to 400 B, order dependent): the charge curve
  arrays growing while the ultimate tracker records. Session data, capped
  at 4800 steps, not render work. It shows up under whichever view is
  measured last.
- `graph.lua:137` (82 B): the `m:ss` string for the status label. One
  string per second is the floor for a label that changes every second.
- `shield_registry.lua:20` (40 to 80 B): shield event bookkeeping in the
  sample path, present with the window hidden too.

## Calls per tick

The EMS view touches ~2400 control methods per tick, ~500 of them anchors.
That is the pool pattern: release everything, re-acquire, re-anchor. It is
the next thing to attack if the in-game profiler ever shows the render
pass on top, and the way to do it is diffing (only re-anchor bars whose
geometry changed). Not done: nothing measured in-game says it is needed,
and the diff path is where bugs live.

## The 200-local ceiling

`ui/graph.lua` compiles at the Lua limit of 200 locals in the main chunk.
Adding any module-level `local` fails with "too many local variables".
This pass grouped the triage layout constants into `TRI_L` and the summary
colours into `C_SUM` to buy headroom (now 193). When the file needs more,
group another family the same way rather than fighting the limit.

## The stop path

The in-game hitch log blamed one 104ms frame on Stop: finalize, summary,
session capture and autosave all ran in the click's frame. Measured in the
harness on a 60-sample, 20-buff, 4-member session:

| step | before | after |
|------|-------:|------:|
| stop click frame | 50 ms · 533 KB | 34 KB (finalize + summary + render) |
| session capture + store | in the click | next frames, cooperative, ~11 KB per resume |

What changed: `vsf.pack` writes digits into a reused buffer and checksums as
it goes instead of building a string per field; the series stream is packed
straight from the ring buffer through an accessor instead of a table per
sample; and `SessionStore.capture(true)` yields every 40 records so the
autosave runs as a coroutine driven by a per-frame update. Record, New and
library loads call `finish_autosave()` first, so a capture never reads a
buffer being cleared under it. `/verdant hitch` tags those frames as `stop`.

## The compact bar

Measured the same way with the bar visible (`scratchpad/barcost.lua`
pattern, now part of the `zero_alloc` case): the refresh allocated 578,
952, 632 and 1528 bytes per tick in EMS, eHPS, MPS and ALL. Three
sources: `Metrics.contribution()` returned a fresh table, the bar used the
allocating `group_shares` instead of the `_into` variant, and ALL mode
built its three value tables per refresh. All reuse scratch tables now
(80 to 138 bytes per tick, the rest is the sample path). The stacked bar
honours `segments.count` so the `_into` output can be handed to it.

