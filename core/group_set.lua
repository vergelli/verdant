Verdant = Verdant or {}
local Verdant = Verdant

Verdant.GroupSet = {}

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

function M.snapshot()
  local ids = {}
  for uid in pairs(members) do ids[#ids + 1] = uid end
  return { player_unit_id = player_unit_id, member_count = #ids, members = ids }
end
