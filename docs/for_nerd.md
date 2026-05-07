# Verdant — Technical Reference

This document covers the math, window parameters, and internals behind the contribution bar. The [README](../README.md) has the user-facing overview.

---

## Metric Definitions

### eHPS — Effective Healing Per Second

$$eHPS(t) = \frac{\displaystyle\sum_{\substack{i:\, t_i \in (t-5s,\, t] \\ in\_M(e_i)}} \text{hit}_i}{5}$$

Only `ACTION_RESULT_HEAL`, `HOT_TICK`, `CRITICAL_HEAL` and `HOT_TICK_CRITICAL` events where the source unit is the player are ingested. Overflow (overheal) is captured separately into `OHPS` and excluded from `eHPS`.

**`in_M` filter:** in group mode, only events whose `targetType` is `COMBAT_UNIT_TYPE_PLAYER`, `GROUP`, or `PLAYER_PET` are counted. In open world this filter is always true — every event qualifies.

**Window:** 5 seconds (half-open interval — entries at exactly `t − 5s` are excluded).

### MPS — Mitigation Per Second

$$MPS(t) = \frac{\displaystyle\sum_{\substack{i:\, t_i \in (t-30s,\, t] \\ in\_M(e_i)}} \text{absorbed}_i}{30}$$

Counts `ACTION_RESULT_DAMAGE_SHIELDED` events for abilities that the ShieldRegistry confirms were cast by the player (tracked via `EVENT_EFFECT_CHANGED`). Foreign shields — applied by other players — are excluded at ingestion time.

Same `in_M` target-type filter as eHPS applies here.

**Window:** 30 seconds. Shields are a bit sparse (at least comparing to heals) so a 5-second window would look weird if bar disapear between hits. The wider window smooths the signal at the cost of slower decay, anyway, this can be changed via configurations.

### OHPS — Overheal Per Second

$$OHPS(t) = \frac{\displaystyle\sum_{\substack{i:\, t_i \in (t-5s,\, t] \\ in\_M(e_i)}} \text{overflow}_i}{5}$$

The `overflow` parameter from `EVENT_COMBAT_EVENT` for heal results. Used only as a denominator component in `O_self`; never displayed on its own.

**Window:** 5 seconds.

### EMS — Effective Mitigation Score

$$EMS(t) = eHPS(t) + MPS(t)$$

The primary metric. Represents every point of damage that was either healed away or intercepted by a shield.

---

## Contribution Formula

### Open world (ungrouped)

$$C = \frac{EMS}{O_{self}}, \quad O_{self} = eHPS + MPS + OHPS$$

Special case: if $O_{self} = 0$, then $C = 0$.

This is an **efficiency ratio**. The denominator `O_self` is the total magical output including waste. `C = 1` (100%) when every cast was useful — no overheal. As overheal accumulates, `O_self` grows while `EMS` stays flat, so `C` drops.

### Grouped

$$C = \begin{cases} 0 & \text{if } D_{group} = 0 \\ \min\!\left(\dfrac{EMS}{D_{group}},\ 1\right) & \text{otherwise} \end{cases}$$

where $D_{group}$ is the sum of all damage taken by tracked group members in the last 5 seconds.

This is a **coverage ratio**. `C = 1` when your throughput matches or exceeds incoming group damage. In a demanding encounter `C` will sit well below 1.

The $D_{group} = 0$ case returns 0 rather than clamping to 1 — if the group is taking no damage there is nothing to cover, so a 100% reading would be misleading.

Group members are tracked via `EVENT_GROUP_MEMBER_JOINED / LEFT / UPDATE` and by observing heal targets: any unit that receives one of your heals is added to the GroupSet.

### EMS bar fill decomposition

$$C_{heal} = C \cdot \frac{eHPS}{EMS}, \quad C_{shield} = C \cdot \frac{MPS}{EMS}$$

Both are 0 when $EMS = 0$. Their sum always equals $C$. The green fill on the bar represents $C_{heal}$; the pink fill represents $C_{shield}$.

---
