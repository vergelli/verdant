Verdant = Verdant or {}
local Verdant = Verdant

Verdant.GroupSet = {}

-- Tracks unitIds known to be in our group. ESO's REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE
-- = COMBAT_UNIT_TYPE_GROUP doesn't match incoming damage to teammates because
-- targetType in those events is COMBAT_UNIT_TYPE_PLAYER (the type is relative to
-- source's perspective). LibCombat solves this by maintaining its own map; we copy
-- the pattern. Population: every outgoing heal whose event-reported targetType is
-- GROUP marks that targetUnitId here. The damage handler then filters by lookup.

local M = Verdant.GroupSet

local pairs = pairs

local members = {}   -- [unitId] = true
local player_unit_id = nil

function M.add(unitId)
  if not unitId or unitId == 0 then return end
  members[unitId] = true
end

function M.set_player(unitId)
  if unitId and unitId ~= 0 then player_unit_id = unitId end
end

function M.contains(unitId)
  if not unitId then return false end
  return members[unitId] == true or unitId == player_unit_id
end

function M.reset()
  members = {}
  player_unit_id = nil
end

function M.size()
  local n = 0
  for _ in pairs(members) do n = n + 1 end
  return n
end
