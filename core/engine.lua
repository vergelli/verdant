Verdant = Verdant or {}
local Verdant = Verdant

-- Phase 4b shim: engine.lua's responsibilities (event subscription,
-- per-ZOS bookkeeping, dispatch) have moved to pipeline/pipeline.lua.
-- This file is kept ONLY to preserve Verdant.Engine.init() as a stable
-- entry point for any external caller during the migration window.
-- Phase 4c removes it entirely.

Verdant.Engine = {}
local M = Verdant.Engine

function M.init()
  Verdant.Pipeline.init()
end
