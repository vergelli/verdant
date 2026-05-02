Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Mode = {}

-- Active metric (SPEC §5). Drives which event classes the engine processes,
-- so the event handler can short-circuit when the data isn't needed.

local M = Verdant.Mode

local METRICS = {
  EMS       = { heal = true, overheal = true, shield_abs = true, damage = true },
  eHPS_only = { heal = true, overheal = true, shield_abs = false, damage = true },
  MPS_only  = { heal = false, overheal = false, shield_abs = true, damage = true },
  eff_ratio = { heal = true, overheal = true, shield_abs = false, damage = false },
}

local active = "EMS"

function M.set(name)
  if METRICS[name] == nil then return false end
  active = name
  return true
end

function M.get()
  return active
end

function M.uses(class)
  local m = METRICS[active]
  return m and m[class] == true
end

function M.current()
  return active
end

function M.list()
  local out = {}
  for k in pairs(METRICS) do out[#out + 1] = k end
  return out
end

function M.snapshot()
  local flags = {}
  local m = METRICS[active]
  if m then
    for cls, v in pairs(m) do flags[cls] = v end
  end
  return { active = active, flags = flags }
end
