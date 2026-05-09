-- pipeline/acquisition.lua
--
-- Stage 1 of the pipeline. Acquires VerdantEvents from the pool and
-- populates them from the raw 17-arg ZOS combat event tuple. No filtering
-- logic here (filter is the next stage). No state mutation here (processing
-- is the third stage).
--
-- Each acquire_* function returns 0..N populated events depending on the
-- ZOS event semantics:
--   acquire_heal_out    → 0, 1, or 2 events (heal + overflow split)
--   acquire_shield_abs  → 0 or 1 event
--   acquire_damage_group→ 0 or 1 event
--
-- A nil return value means the pool was exhausted; callers must bump
-- engine.pool.exhausted.

Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Pipeline = Verdant.Pipeline or {}
Verdant.Pipeline.Acquisition = {}
local M = Verdant.Pipeline.Acquisition

local AK = Verdant.Constants.ABILITY_KIND
local KIND_HEAL         = AK.HEAL
local KIND_OVERHEAL     = AK.OVERHEAL
local KIND_SHIELD       = AK.SHIELD
local KIND_DAMAGE_GROUP = AK.DAMAGE_GROUP

local GetGameTimeMilliseconds = Verdant.zenimax.api.GetGameTimeMilliseconds

local function acquire()
  return Verdant.Metrics.acquire_event()
end

-- Heal out: ZOS sends one combat event with `hit` and `overflow` amounts.
-- Each non-zero amount becomes a separate VerdantEvent so the buffers in
-- metrics own them independently. Returns (ev_heal, ev_overheal); either
-- may be nil. Caller is responsible for processing each independently
-- (filter+process), or releasing on filter rejection.
function M.acquire_heal_out(t, hit, overflow, targetUnitId, targetType, abilityId)
  local ev_heal, ev_overheal
  if (hit or 0) > 0 then
    ev_heal = acquire()
    if ev_heal then
      ev_heal.t              = t
      ev_heal.kind           = KIND_HEAL
      ev_heal.amount         = hit
      ev_heal.target_unit_id = targetUnitId or 0
      ev_heal.target_type    = targetType   or 0
      ev_heal.ability_id     = abilityId    or 0
    end
  end
  if (overflow or 0) > 0 then
    ev_overheal = acquire()
    if ev_overheal then
      ev_overheal.t              = t
      ev_overheal.kind           = KIND_OVERHEAL
      ev_overheal.amount         = overflow
      ev_overheal.target_unit_id = targetUnitId or 0
      ev_overheal.target_type    = targetType   or 0
      ev_overheal.ability_id     = abilityId    or 0
    end
  end
  return ev_heal, ev_overheal
end

function M.acquire_shield_abs(t, hit, targetUnitId, targetType, abilityId)
  if (hit or 0) <= 0 then return nil end
  local ev = acquire()
  if not ev then return nil end
  ev.t              = t
  ev.kind           = KIND_SHIELD
  ev.amount         = hit
  ev.target_unit_id = targetUnitId or 0
  ev.target_type    = targetType   or 0
  ev.ability_id     = abilityId    or 0
  return ev
end

function M.acquire_damage_group(t, hit, targetUnitId)
  if (hit or 0) <= 0 then return nil end
  local ev = acquire()
  if not ev then return nil end
  ev.t              = t
  ev.kind           = KIND_DAMAGE_GROUP
  ev.amount         = hit
  ev.target_unit_id = targetUnitId or 0
  ev.target_type    = 0
  ev.ability_id     = 0
  return ev
end

function M.now()
  return GetGameTimeMilliseconds()
end
