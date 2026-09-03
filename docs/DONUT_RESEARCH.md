# Donut charts with native ESO UI controls

Spike for #99. Question: can the ESO UI toolkit draw a decent pie / donut chart
without hand-made wedge textures or per-frame math on our side?

## Short answer

Yes, almost certainly. `CT_COOLDOWN` in radial mode is a native pie-wedge
renderer. ZOS uses it for exactly this in the Tel Var meter and the objective
capture meter. One cooldown control per slice, a white ring texture tinted per
slice, and the engine draws the arc.

What still needs eyes in-game is the unit and direction of the origin angle.
The probe answers that in one look.

## What the control gives us (ESOUIDocumentation.txt, CooldownControl)

| Method | Use |
|---|---|
| `StartFixedCooldown(pct, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_REMAINING, false)` | Draw `pct` of the ring. Same call as the Tel Var meter (`hudtelvarmeter.lua:150`), where `TIME_REMAINING` gives a clockwise fill. |
| `SetPercentCompleteFixed(pct)` | Update a slice without restarting. |
| `SetRadialCooldownOriginAngle(angle)` | Where the wedge starts. This is what makes multi-slice trivial: slice *k* starts at the cumulative share of slices `1..k-1`. Unit not documented, see open questions. |
| `SetRadialCooldownClockwise(bool)` | Direction. |
| `SetRadialCooldownGradient(startAlpha, angularDistance)` | Soft leading edge, optional polish. |
| `SetFillColor(r, g, b, a)` | Tint. With a white ring texture this is the slice color. |
| `SetTexture(file)` | The ring. `assets/ring.dds`, 128x128 DXT5, outer radius 62, inner 40, anti-aliased. |
| `SetLeadingEdgeTexture(file)` | Ignored for us, `drawLeadingEdge=false`. |

Cost per donut: N cooldown controls, N anchor calls at build, and per update
one `SetRadialCooldownOriginAngle` + one `StartFixedCooldown` per slice. No
trigonometry, no per-frame work. Fits the cold-path budget with room to spare.

## Implementation

`lib/plot/donut.lua` — `Verdant.lib.plot.Donut`.

```lua
local d = Donut.new("VerdantSomeDonut", parent, 96, { mode = "origin", origin_unit = "rad" })
d:set({ 50, 30, 20 }, { green, gold, grey })
```

- `mode = "origin"` (default): one wedge per slice placed with the origin angle.
  `origin_unit` is `"rad"` or `"deg"` until the in-game check settles which the
  engine expects.
- `mode = "stack"`: fallback that never calls the origin method. Slice *k* draws
  the cumulative arc `0..share_1+..+share_k` and sits *under* slice *k-1*
  (draw level descending), so each slice shows only its own band. Works on any
  client where `SetRadialCooldownOriginAngle` turns out to be a no-op, at the
  price of overdraw.
- Zero values drop their slice, spare controls hide, empty data draws nothing.
- `gap` (fraction of the ring) shaves each wedge to leave a hairline between
  slices, origin mode only.

## The probe

`/verdant donut` (DEBUG builds) opens a small window with the same 50/30/20 data
drawn three ways, labelled `origin rad`, `origin deg`, `stacked`. Whichever of
the first two shows three distinct wedges is the correct unit. If neither does,
`stacked` still must look right and becomes the shipping mode.

Things to look at while it is open:

- the anti-aliasing of the ring edge at 96px and again at 48px (mip 3)
- whether a 2% slice is still visible or collapses (min slice angle)
- whether the leading edge of each wedge is crisp without `drawLeadingEdge`
- direction: clockwise from 12 o'clock is the expectation

## SimLab

The mock knows `CT_COOLDOWN` and the radial methods, and the SVG renderer draws
a cooldown as a true arc path (origin, sweep, clockwise honoured), so the donut
shows up in `test/simlab/out/donut_probe.svg` and the layout auditor sees the
window like any other. `test/harness/cases/donut_widget.lua` pins the share and
origin math for both modes.

## Open questions (need the game)

1. Origin angle unit and zero position. The probe answers this.
2. Whether `SetFillColor` tints the texture or replaces it. ZOS calls it on
   textured cooldowns, so tint is the expectation.
3. Minimum readable slice at 96px. Below that we probably merge into "other".

## Recommendation

Go. Once the origin unit is confirmed, delete the other unit and the stack mode
from the widget, keep the ring texture, and the first real use is the
per-ability share in the SKILL view hover, where a 5-slice donut beside the
list reads faster than five percentages.
