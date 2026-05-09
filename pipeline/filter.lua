-- pipeline/filter.lua
--
-- Stage 2 of the pipeline. Pure predicate over a populated VerdantEvent.
-- Returns true to allow the event through, false to drop. Drops bump
-- the kind-specific drop counter so behavioral diff with the pre-pipeline
-- engine stays exact.
--
-- Pre-acquire filters (mode pre-check, isError, noise) live in
-- pipeline/pipeline.lua because they fire once per raw ZOS event,
-- whereas a HEAL+OVERHEAL pair shares one ZOS event but produces two
-- VerdantEvents — bumping a per-ZOS counter from a per-event filter
-- would double-count.
--
-- This stage handles only kind-specific predicates that operate on the
-- populated event:
--   SHIELD       — ShieldRegistry.is_self_cast (was-it-ours check)
--   DAMAGE_GROUP — GroupSet.contains (target-in-set check)
--   HEAL/OVERHEAL — no per-event predicate; always allow.

Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Pipeline = Verdant.Pipeline or {}
Verdant.Pipeline.Filter = {}
local M = Verdant.Pipeline.Filter

local AK = Verdant.Constants.ABILITY_KIND
local KIND_SHIELD       = AK.SHIELD
local KIND_DAMAGE_GROUP = AK.DAMAGE_GROUP

local function bump(key) Verdant.Diagnostics.bump(key) end

function M.allow(ev)
  local k = ev.kind
  if k == KIND_SHIELD then
    if not Verdant.ShieldRegistry.is_self_cast(ev.ability_id, ev.target_unit_id) then
      bump("engine.shield.foreign")
      return false
    end
    return true
  elseif k == KIND_DAMAGE_GROUP then
    if not Verdant.GroupSet.contains(ev.target_unit_id) then
      bump("engine.damage.not_in_groupset")
      return false
    end
    return true
  end
  -- HEAL / OVERHEAL: no per-event predicate.
  return true
end
