-- ZOS API surface used by Verdant. Per SPEC_01 §6/§7.1, functions are
-- forwarded by value (M.X = X), captured at module load. This is the same
-- call cost as the bare global with the wrapper benefit of a namespace.
-- Consumers may local-cache hot-path entries (SPEC_01 §5.2):
--   local GetGameTimeMs = Verdant.zenimax.api.GetGameTimeMilliseconds

Verdant = Verdant or {}
Verdant.zenimax = Verdant.zenimax or {}
local Verdant = Verdant

Verdant.zenimax.api = {}
local M = Verdant.zenimax.api

-- ── time / version ────────────────────────────────────────────────────────
M.GetGameTimeMilliseconds = GetGameTimeMilliseconds
M.GetAPIVersion           = GetAPIVersion
M.GetWorldName            = GetWorldName

-- ── localization ──────────────────────────────────────────────────────────
M.GetString = GetString

-- ── group / unit ──────────────────────────────────────────────────────────
M.IsUnitGrouped           = IsUnitGrouped
M.GetGroupSize            = GetGroupSize
M.GetUnitName             = GetUnitName
M.GetUnitDisplayName      = GetUnitDisplayName
M.GetUnitClass            = GetUnitClass
M.GetUnitRace             = GetUnitRace
M.GetUnitLevel            = GetUnitLevel
M.GetUnitChampionPoints   = GetUnitChampionPoints
M.GetUnitAlliance         = GetUnitAlliance

-- ── world / zone ──────────────────────────────────────────────────────────
M.GetCurrentMapZoneIndex  = GetCurrentMapZoneIndex
M.GetZoneNameByIndex      = GetZoneNameByIndex

-- ── action bar / abilities ────────────────────────────────────────────────
M.GetSlotName                            = GetSlotName
M.GetSlotBoundId                         = GetSlotBoundId
M.GetAbilityName                         = GetAbilityName
M.GetAbilityIcon                         = GetAbilityIcon
M.GetSpecificSkillAbilityKeysByAbilityId = GetSpecificSkillAbilityKeysByAbilityId
M.GetSkillLineId                         = GetSkillLineId

-- ── input ─────────────────────────────────────────────────────────────────
M.GetUIMousePosition = GetUIMousePosition
