-- VerdantEvent: pooled record passed across pipeline stages. Per
-- SPEC_03 §3.1, fixed shape, mutated, plain table (hstructure decision
-- deferred). The reduced field set below covers Phase 2 needs (metrics
-- ingestion); fields the full pipeline will add later (seq, role enums,
-- ability_kind, raw/effective split) are out of Phase 2 scope.

Verdant = Verdant or {}
Verdant.lib = Verdant.lib or {}
Verdant.lib.mem = Verdant.lib.mem or {}

local Event = {}
Verdant.lib.mem.Event = Event

-- Factory: produce a fresh, zero-initialized event. Called once per pool
-- slot at pool construction. After that, fields are overwritten on
-- acquire-and-populate; nothing nils them on release (microopt).
function Event.factory()
  return {
    t              = 0,
    kind           = 0,    -- AbilityKind enum (see core/constants.lua)
    result         = 0,    -- ACTION_RESULT_* (used by the crit-heal split)
    amount         = 0,
    target_unit_id = 0,
    target_type    = 0,
    ability_id     = 0,
    -- _pool_idx written by BufferPool.new
  }
end
