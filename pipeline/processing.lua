-- pipeline/processing.lua
--
-- Stage 3 of the pipeline. Routes a filtered VerdantEvent to the
-- appropriate ingestor in metrics. The event becomes the buffer's owned
-- entry from this point — the caller MUST NOT release it. Buffer trim
-- (on_evict) returns it to the pool when the time window passes.
--
-- Per-ZOS-event side effects (counters that fire regardless of HEAL/OVERHEAL
-- split, set_player, GroupSet.add, Coverage.touch on shields) live in
-- pipeline/pipeline.lua. This module is the per-event ingestion sink.

Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Pipeline = Verdant.Pipeline or {}
Verdant.Pipeline.Processing = {}
local M = Verdant.Pipeline.Processing

local AK = Verdant.Constants.ABILITY_KIND
local KIND_HEAL         = AK.HEAL
local KIND_OVERHEAL     = AK.OVERHEAL
local KIND_SHIELD       = AK.SHIELD
local KIND_DAMAGE_GROUP = AK.DAMAGE_GROUP

function M.process(ev)
  local k = ev.kind
  if k == KIND_HEAL then
    Verdant.Metrics.ingest_heal(ev)
    Verdant.Coverage.touch(ev.target_unit_id, ev.t)
  elseif k == KIND_OVERHEAL then
    Verdant.Metrics.ingest_overheal(ev)
  elseif k == KIND_SHIELD then
    Verdant.Metrics.ingest_shield(ev)
    -- Shield Coverage.touch fires unconditionally per ZOS event in
    -- pipeline.lua, even on foreign drops. Don't touch here.
  elseif k == KIND_DAMAGE_GROUP then
    Verdant.Metrics.ingest_damage_group(ev)
  end
end
