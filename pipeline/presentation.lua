-- pipeline/presentation.lua
--
-- Stage 4 of the pipeline. Read-side: builds a stable RenderPayload from
-- metrics state. Mutated in place each tick — zero per-tick allocation.
--
-- Per SPEC_05 Phase 4, this module is created as a *parallel* read path.
-- The current ui/bar.lua, ui/graph.lua continue reading directly from
-- core/metrics. UI migration to RenderPayload is scheduled for a later
-- phase. Today's consumer is /verdant readout (validation aid).

Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Pipeline = Verdant.Pipeline or {}
Verdant.Pipeline.Presentation = {}
local M = Verdant.Pipeline.Presentation

-- The single stable payload instance, reused every tick.
local payload = {
  ts          = 0,
  ehps        = 0,
  mps         = 0,
  ems         = 0,
  ohps        = 0,
  d_group     = 0,
  o_self      = 0,
  c_self      = 0,
  c_heal      = 0,
  c_shield    = 0,
  mode        = "",   -- "group" | "open"
}

-- Builds the snapshot for now_ms. Returns the same payload table every
-- call; consumers must read fields (or copy) before the next snapshot.
function M.snapshot(now_ms)
  local r = Verdant.Metrics.contribution(now_ms)
  payload.ts       = now_ms
  payload.ehps     = r.eHPS
  payload.mps      = r.MPS
  payload.ems      = r.EMS
  payload.ohps     = r.OHPS
  payload.d_group  = r.D_group
  payload.o_self   = r.O_self
  payload.c_self   = r.C_self
  payload.c_heal   = r.C_heal
  payload.c_shield = r.C_shield
  payload.mode     = r.mode
  return payload
end

function M.payload()
  return payload
end
