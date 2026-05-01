Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Probe = {}

local d                       = d
local string_format           = string.format
local table_remove            = table.remove
local pairs                   = pairs
local tostring                = tostring
local GetGameTimeMilliseconds = GetGameTimeMilliseconds
local IsUnitGrouped           = IsUnitGrouped
local GetGroupSize            = GetGroupSize
local GetUnitName             = GetUnitName
local GetUnitDisplayName      = GetUnitDisplayName
local GetUnitId               = GetUnitId

local M = Verdant.Probe

local state = {
  enabled      = false,
  filter       = "all",
  last_chat_ms = 0,
  buffers      = {
    heal   = {},
    shield = {},
    damage = {},
    effect = {},
    group  = {},
  },
}
M.state = state

local function should_log(category)
  local f = state.filter
  return f == "all" or f == category
end

local function push(category, entry)
  local buf = state.buffers[category]
  if not buf then return end
  buf[#buf + 1] = entry
  if #buf > Verdant.Constants.PROBE.BUFFER_LIMIT then
    table_remove(buf, 1)
  end
end

local function chat_emit(line)
  if not state.enabled then return end
  local now = GetGameTimeMilliseconds()
  if now - state.last_chat_ms < Verdant.Constants.PROBE.CHAT_INTERVAL_MS then return end
  state.last_chat_ms = now
  d("[V] " .. line)
end

-- EVENT_COMBAT_EVENT signature (17 args):
--   result, isError, abilityName, abilityGraphic, abilitySlotType,
--   sourceName, sourceType, targetName, targetType, hitValue,
--   powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow
local function on_combat_out(result, isError, abilityName, _abilityGraphic, _abilitySlot,
                             _sourceName, _sourceType, targetName, _targetType, hitValue,
                             _powerType, _damageType, _log, sourceUnitId, targetUnitId,
                             abilityId, overflow)
  if isError then return end

  local category
  if result == ACTION_RESULT_HEAL
    or result == ACTION_RESULT_HOT_TICK
    or result == ACTION_RESULT_CRITICAL_HEAL
    or result == ACTION_RESULT_HOT_TICK_CRITICAL then
    category = "heal"
  elseif result == ACTION_RESULT_DAMAGE_SHIELDED then
    category = "shield"
  elseif result == ACTION_RESULT_HEAL_ABSORBED then
    -- Heal that landed on a target with a heal-absorption debuff. Worth observing.
    category = "heal"
  else
    return
  end

  push(category, {
    t          = GetGameTimeMilliseconds(),
    result     = result,
    ability    = abilityName,
    abilityId  = abilityId,
    target     = targetName,
    targetUnit = targetUnitId,
    sourceUnit = sourceUnitId,
    hit        = hitValue,
    overflow   = overflow,
  })

  if should_log(category) then
    chat_emit(string_format(
      "%s | r=%d | %s -> %s | hit=%d ovf=%d | tuid=%d ab=%d",
      category, result or 0, abilityName or "?", targetName or "?",
      hitValue or 0, overflow or 0, targetUnitId or 0, abilityId or 0
    ))
  end
end

local function on_combat_in_group(result, isError, abilityName, _abilityGraphic, _abilitySlot,
                                  sourceName, _sourceType, targetName, _targetType, hitValue,
                                  _powerType, _damageType, _log, sourceUnitId, targetUnitId,
                                  abilityId, _overflow)
  if isError then return end
  if result ~= ACTION_RESULT_DAMAGE
    and result ~= ACTION_RESULT_DOT_TICK
    and result ~= ACTION_RESULT_CRITICAL_DAMAGE
    and result ~= ACTION_RESULT_DOT_TICK_CRITICAL
    and result ~= ACTION_RESULT_BLOCKED_DAMAGE
    and result ~= ACTION_RESULT_FALL_DAMAGE then
    return
  end

  push("damage", {
    t          = GetGameTimeMilliseconds(),
    result     = result,
    ability    = abilityName,
    abilityId  = abilityId,
    source     = sourceName,
    sourceUnit = sourceUnitId,
    target     = targetName,
    targetUnit = targetUnitId,
    hit        = hitValue,
  })

  if should_log("damage") then
    chat_emit(string_format(
      "dmg | r=%d | %s -> %s | %d | tuid=%d",
      result or 0, sourceName or "?", targetName or "?", hitValue or 0, targetUnitId or 0
    ))
  end
end

local function effect_change_label(changeType)
  if changeType == EFFECT_RESULT_GAINED       then return "GAIN" end
  if changeType == EFFECT_RESULT_FADED        then return "FADE" end
  if changeType == EFFECT_RESULT_UPDATED      then return "UPD"  end
  if changeType == EFFECT_RESULT_FULL_REFRESH then return "REFR" end
  if changeType == EFFECT_RESULT_TRANSFER     then return "TRAN" end
  return tostring(changeType)
end

-- EVENT_EFFECT_CHANGED signature (16 args):
--   changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount,
--   iconName, deprecatedBuffType, effectType, abilityType, statusEffectType,
--   unitName, unitId, abilityId, sourceType
local function on_effect_changed(changeType, _effectSlot, effectName, unitTag, beginTime, endTime,
                                 stackCount, _iconName, _deprecatedBuffType, effectType, abilityType,
                                 _statusEffectType, unitName, unitId, abilityId, sourceType)
  push("effect", {
    t          = GetGameTimeMilliseconds(),
    change     = changeType,
    effect     = effectName,
    unitTag    = unitTag,
    unitName   = unitName,
    unitId     = unitId,
    abilityId  = abilityId,
    abilityType = abilityType,
    effectType = effectType,
    sourceType = sourceType,
    beginTime  = beginTime,
    endTime    = endTime,
    stacks     = stackCount,
  })

  if should_log("effect") then
    chat_emit(string_format(
      "fx | %s | %s on %s (uid=%d) | etype=%d atype=%d ab=%d",
      effect_change_label(changeType), effectName or "?", unitName ~= "" and unitName or unitTag or "?",
      unitId or 0, effectType or 0, abilityType or 0, abilityId or 0
    ))
  end
end

local function snapshot_group(reason)
  local size = GetGroupSize() or 0
  local grouped = IsUnitGrouped("player")
  local members = {}
  if grouped and size > 0 then
    for i = 1, size do
      local tag = "group" .. i
      members[#members + 1] = {
        tag       = tag,
        name      = GetUnitName(tag),
        display   = GetUnitDisplayName(tag),
        unitId    = GetUnitId(tag),
      }
    end
  end
  push("group", {
    t       = GetGameTimeMilliseconds(),
    reason  = reason,
    grouped = grouped,
    size    = size,
    members = members,
  })

  if should_log("group") then
    chat_emit(string_format("group | %s | grouped=%s size=%d", reason or "?", tostring(grouped), size))
  end
end

-- --- Public API ----------------------------------------------------------

function M.set_enabled(v)
  state.enabled = v and true or false
end

function M.set_filter(category)
  state.filter = category
end

function M.clear()
  for k in pairs(state.buffers) do
    state.buffers[k] = {}
  end
end

function M.format_entry(category, e)
  if category == "heal" or category == "shield" then
    return string_format("t=%d r=%d ab=%s tgt=%s tuid=%d hit=%d ovf=%d",
      e.t or 0, e.result or 0, e.ability or "?", e.target or "?", e.targetUnit or 0, e.hit or 0, e.overflow or 0)
  elseif category == "damage" then
    return string_format("t=%d r=%d ab=%s src=%s tgt=%s tuid=%d hit=%d",
      e.t or 0, e.result or 0, e.ability or "?", e.source or "?", e.target or "?", e.targetUnit or 0, e.hit or 0)
  elseif category == "effect" then
    return string_format("t=%d ch=%s fx=%s unit=%s uid=%d etype=%s atype=%s",
      e.t or 0, effect_change_label(e.change), e.effect or "?",
      (e.unitName ~= "" and e.unitName) or e.unitTag or "?",
      e.unitId or 0, tostring(e.effectType), tostring(e.abilityType))
  elseif category == "group" then
    return string_format("t=%d %s grouped=%s size=%d", e.t or 0, e.reason or "?", tostring(e.grouped), e.size or 0)
  end
  return "?"
end

function M.dump()
  local L = Verdant.L
  local total = 0
  for _, buf in pairs(state.buffers) do total = total + #buf end
  if total == 0 then
    d("[V] " .. L.DUMP_EMPTY)
    return
  end
  d("[V] " .. L.DUMP_HEADER)
  for category, buf in pairs(state.buffers) do
    d(string_format("[V] -- %s (%d) --", category, #buf))
    for i = 1, #buf do
      d(string_format("[V]   %s", M.format_entry(category, buf[i])))
    end
  end
end

local function shallow_copy(t)
  local out = {}
  for k, v in pairs(t) do
    if type(v) == "table" then
      out[k] = shallow_copy(v)
    else
      out[k] = v
    end
  end
  return out
end

function M.persist_to_savedvars(sv)
  if not sv then return end
  sv.probe = sv.probe or {}
  local snapshot = { taken_at_ms = GetGameTimeMilliseconds(), buffers = {} }
  for k, buf in pairs(state.buffers) do
    local out = {}
    for i = 1, #buf do
      out[i] = shallow_copy(buf[i])
    end
    snapshot.buffers[k] = out
  end
  sv.probe.last_dump = snapshot
end

-- --- Wiring --------------------------------------------------------------

function M.init()
  local P = Verdant.Constants.PROBE
  local E = Verdant.Events

  -- Heals/shields where I am the source.
  E.register(P.SRC_COMBAT_OUT, EVENT_COMBAT_EVENT, on_combat_out)
  E.add_filter(P.SRC_COMBAT_OUT, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
  E.add_filter(P.SRC_COMBAT_OUT, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  -- Damage landing on the group (my potential D_group denominator).
  E.register(P.SRC_COMBAT_IN, EVENT_COMBAT_EVENT, on_combat_in_group)
  E.add_filter(P.SRC_COMBAT_IN, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_GROUP)
  E.add_filter(P.SRC_COMBAT_IN, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  -- Effects whose source is me (shields applied, purges I cast, debuffs, etc.).
  E.register(P.SRC_EFFECT, EVENT_EFFECT_CHANGED, on_effect_changed)
  E.add_filter(P.SRC_EFFECT, EVENT_EFFECT_CHANGED,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

  -- Group state
  E.register(P.SRC_GROUP_J, EVENT_GROUP_MEMBER_JOINED, function() snapshot_group("joined") end)
  E.register(P.SRC_GROUP_L, EVENT_GROUP_MEMBER_LEFT,   function() snapshot_group("left") end)
  E.register(P.SRC_GROUP_U, EVENT_GROUP_UPDATE,        function() snapshot_group("update") end)
  E.register(P.SRC_PLAYER,  EVENT_PLAYER_ACTIVATED,    function() snapshot_group("activated") end)
end
