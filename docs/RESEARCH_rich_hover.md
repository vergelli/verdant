# Research — Rich hover tooltip (per-skill icons, % and number)

**Status:** investigated, NOT yet started · local tracking only (not a GitHub issue yet)
**Date:** 2026-06-28
**Idea:** when hovering a bar (post-STOP, frozen session), show the hover card as a
list of the **contributing skills as icons**, ordered by contribution, with two
columns — **%** and **absolute number**. This would be a big differentiator vs
other meters.

---

## Verdict: NOT feasible with the data we currently retain — but a modest, safe change unlocks it

The frozen session simply does not contain per-ability information. Per-ability
identity is destroyed at the **sample-tick aggregation** and never reaches the
temporal buffer, the decimator, or the hover. No amount of post-STOP processing
can recover it. **But** the fix does **not** touch the zero-alloc hot path and is
localized.

---

## Why it's not possible today (the data path, traced)

1. **Stored sample = collapsed group totals only.**
   `core/temporal_buffer.lua:24-25` — each slot is
   `{ t, eHPS, MPS, crit, noncrit, ehps_groups{count}, mps_groups{count} }`.
   `copy_groups` (`temporal_buffer.lua:30-40`) copies **only** `r,g,b,a,share,key`
   per group. No ability id, no ability name/icon, no per-ability amount — just a
   color, a fractional share, and a group-key string per skill-line color group.
   (The absolute number is reconstructed as `share * total`, already done in the
   hover at `ui/graph.lua:499`.)

2. **Ability IDs exist only transiently in the live ring buffers and are discarded
   at sample-tick.** The pooled event carries `ability_id`
   (`lib/mem/event.lua:16`, set in `pipeline/acquisition.lua`). They live in the
   metrics ring buffers (`core/metrics.lua`) within a rolling window only. The
   collapse-and-discard happens in `core/skill_colors.lua:350-389`
   (`group_shares_into`): line **358** reads `lookup_group(e.ability_id)`,
   accumulates into `gs_buckets[key]` keyed by **group string**, and emits only
   `{r,g,b,a,share,key}` (lines 372-375). The ability id is never propagated.
   `GetAbilityIcon(abilityId)` is already imported here (`skill_colors.lua:7`) but
   never tied to stored per-sample data.

3. **Hover reads per-column group bands built at render.** `hover_poll`
   (`ui/graph.lua:553-603`), hit indices `hit_main/hit_top/hit_bot`
   (`graph.lua:69-71`), bands pushed during `render_view2` with
   `key, lo, hi, share, total, r,g,b` (`graph.lua:803-814`, `868-879`).
   `show_card` (`graph.lua:492-503`) renders a single hovered group: swatch +
   `hover_label(band.key)` + `share*total`. The decimated `dec_cols`
   (`graph.lua:354-367`) carry forward only the collapsed `ehps_groups`/`mps_groups`.
   No finer granularity than group exists anywhere in the path.

---

## Minimum change to make it feasible (does NOT threaten zero-alloc hot path)

1. **Hot path untouched.** `ability_id` is already on every event in the ring
   buffers — no change to `acquisition.lua` / per-hit path. Zero-alloc invariant
   preserved.

2. **New per-ability accumulation at sample-tick time only** (~once/second,
   `SAMPLE_RATE_DEFAULT = 1000` ms — cost irrelevant). Extend `group_shares_into`
   (or add `ability_shares_into`) to keep a second bucket keyed by `ability_id`
   alongside `gs_buckets`, summing `amt` per ability and recording its group key.
   Allocates only into reused scratch tables (same pattern as `gs_buckets`).

3. **Store the per-ability list in the sample.** Extend the slot schema
   (`temporal_buffer.lua:24`) and `copy_groups`/`push` (`:30-56`) to carry, per
   ability, `{ ability_id, amount, share, group_key }`. Icon is derivable lazily
   after STOP via `GetAbilityIcon(ability_id)` — no need to store icon paths.

4. **Carry through decimator + hover.** Copy the new list reference in `decimate`
   (`graph.lua:354-367`, like `ehps_groups`), attach to the hover band
   (`graph.lua:803-814`), and render icon + % + absolute rows in an expanded card
   (`show_card`, `graph.lua:492-503`). The card is fixed-size (`CARD_W/H`,
   `graph.lua:78`) and would need to grow / add an icon-row pool.

### Cost / risk
- One extra sample-tick bucketization pass over the heal/shield ring buffers
  (parallel to the existing group-shares pass), a wider temporal-buffer slot, a
  richer card. Hot path and its zero-alloc guarantee are **not** involved.
- Memory: ~ capacity_samples × distinct_abilities_per_second × small-struct.
  At default 60 s window @ 1 Hz with a handful of active heals → negligible.

### Caveat to honor in the UI
The decimator folds raw samples into one pixel column by taking the **peak**
sample (`graph.lua:362-365`). So the hovered column's per-ability list reflects
that single peak sample's abilities — consistent with how `share`/`crit`/groups
are already chosen. The % column will then match the bar the user sees. State
this in the card design so the numbers reconcile.

---

## Why this is worth it
Post-STOP, FPS is irrelevant and decimation is already in place, so the expensive
part (render scaling) is solved. The only real work is **retaining ability-level
detail at sample-tick** and **a richer card**. This turns the hover from
"which skill-line" into "exactly which abilities, ranked" — a genuine
differentiator. If we ship it, it lands in all three siblings via the usual port.

## Next step when we pick this up
Prototype step 2 (the `ability_shares_into` sample-tick pass) behind a DEBUG flag,
dump the per-ability list to chat on hover to validate the data is correct and
complete, **then** build the card UI. Verditer/Vermilion get the same treatment
once Verdant's shape is proven.
