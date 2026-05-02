Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Engine = {}

-- Routes EVENT_COMBAT_EVENT and EVENT_EFFECT_CHANGED into the metrics
-- pipeline. Lives parallel to the Probe — Probe is for diagnostics; the
-- Engine is what feeds the contribution bar.

local M = Verdant.Engine

local GetGameTimeMilliseconds = GetGameTimeMilliseconds
local tostring                = tostring

local function now() return GetGameTimeMilliseconds() end

local function bump(key)   Verdant.Diagnostics.bump(key)         end
local function log(cat, p) Verdant.Diagnostics.log_event(cat, p) end

local function on_heal_out(result, isError, _name, _g, _slot,
                           _src, sourceType, _tgt, targetType, hit,
                           _pt, _dt, _log, sourceUnitId, targetUnitId,
                           abilityId, overflow)
  bump("engine.heal.in")
  if isError then bump("engine.heal.dropped_error") return end
  if (hit or 0) == 0 and (overflow or 0) == 0 then
    bump("engine.heal.dropped_noise") return
  end
  if not Verdant.Mode.uses("heal") and not Verdant.Mode.uses("overheal") then
    bump("engine.heal.dropped_mode") return
  end

  if sourceType == COMBAT_UNIT_TYPE_PLAYER and sourceUnitId and sourceUnitId ~= 0 then
    Verdant.GroupSet.set_player(sourceUnitId)
  end
  if targetType == COMBAT_UNIT_TYPE_GROUP and targetUnitId and targetUnitId ~= 0 then
    Verdant.GroupSet.add(targetUnitId)
    bump("engine.heal.target_group")
  else
    bump("engine.heal.target_other")
  end

  bump("engine.heal.accepted")
  log("heal", "ab=" .. tostring(abilityId)
    .. " tgt=" .. tostring(targetUnitId)
    .. " hit=" .. tostring(hit)
    .. " ovfl=" .. tostring(overflow)
    .. " ttype=" .. tostring(targetType))

  local t = now()
  Verdant.Metrics.ingest_heal(t, hit, overflow, targetUnitId, targetType, abilityId)
  if (hit or 0) > 0 then
    Verdant.Coverage.touch(targetUnitId, t)
  end
end

local function on_shield_abs(result, isError, _name, _g, _slot,
                             _src, _sourceType, _tgt, targetType, hit,
                             _pt, _dt, _log, _suid, targetUnitId,
                             abilityId, _overflow)
  bump("engine.shield.in")
  if isError then bump("engine.shield.dropped_error") return end
  if not Verdant.Mode.uses("shield_abs") then
    bump("engine.shield.dropped_mode") return
  end
  if not Verdant.ShieldRegistry.is_self_cast(abilityId, targetUnitId) then
    bump("engine.shield.foreign") return
  end

  bump("engine.shield.accepted")
  log("shield_abs", "ab=" .. tostring(abilityId)
    .. " tgt=" .. tostring(targetUnitId)
    .. " hit=" .. tostring(hit)
    .. " ttype=" .. tostring(targetType))

  local t = now()
  Verdant.Metrics.ingest_shield(t, hit, targetUnitId, targetType, abilityId)
  Verdant.Coverage.touch(targetUnitId, t)
end

local function on_group_damage(result, isError, _name, _g, _slot,
                               _src, _sourceType, _tgt, _targetType, hit,
                               _pt, _dt, _log, _suid, targetUnitId,
                               _abilityId, _overflow)
  bump("engine.damage.in")
  if isError then bump("engine.damage.dropped_error") return end
  if not Verdant.Mode.uses("damage") then
    bump("engine.damage.dropped_mode") return
  end
  if not Verdant.GroupSet.contains(targetUnitId) then
    bump("engine.damage.not_in_groupset") return
  end

  bump("engine.damage.accepted")
  log("group_dmg", "tgt=" .. tostring(targetUnitId) .. " hit=" .. tostring(hit))

  Verdant.Metrics.ingest_damage_group(now(), hit, targetUnitId)
end

local function on_effect_player_src(changeType, _slot, _name, _tag, _bt, endTime,
                                    _stack, _icon, _depBuff, _et, _at,
                                    _stat, _uname, unitId, abilityId, sourceType)
  bump("engine.effect.in_player_src")
  if changeType == EFFECT_RESULT_GAINED then
    bump("engine.effect.gained")
  elseif changeType == EFFECT_RESULT_FADED then
    bump("engine.effect.faded")
  end
  Verdant.ShieldRegistry.on_effect(changeType, abilityId, unitId, sourceType, endTime)
end

local function on_group_change()
  bump("engine.group.changed")
  Verdant.Coverage.refresh_mode()
end

local function on_group_left()
  bump("engine.group.left")
  log("group_left", "resetting groupset sz=" .. Verdant.GroupSet.size())
  Verdant.Coverage.refresh_mode()
  Verdant.GroupSet.reset()
end

function M.init()
  local E = Verdant.Events

  Verdant.Diagnostics.init()
  Verdant.Metrics.init()
  Verdant.Coverage.refresh_mode()

  E.register("Verdant_E_HealOut", EVENT_COMBAT_EVENT, function(...)
    local r = ...
    if r == ACTION_RESULT_HEAL
       or r == ACTION_RESULT_HOT_TICK
       or r == ACTION_RESULT_CRITICAL_HEAL
       or r == ACTION_RESULT_HOT_TICK_CRITICAL then
      on_heal_out(...)
    end
  end)
  E.add_filter("Verdant_E_HealOut", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
  E.add_filter("Verdant_E_HealOut", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  E.register("Verdant_E_ShieldAbs", EVENT_COMBAT_EVENT, on_shield_abs)
  E.add_filter("Verdant_E_ShieldAbs", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DAMAGE_SHIELDED)
  E.add_filter("Verdant_E_ShieldAbs", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  E.register("Verdant_E_GroupDmg", EVENT_COMBAT_EVENT, function(...)
    local r = ...
    if r == ACTION_RESULT_DAMAGE
       or r == ACTION_RESULT_DOT_TICK
       or r == ACTION_RESULT_CRITICAL_DAMAGE
       or r == ACTION_RESULT_DOT_TICK_CRITICAL
       or r == ACTION_RESULT_BLOCKED_DAMAGE
       or r == ACTION_RESULT_FALL_DAMAGE then
      on_group_damage(...)
    end
  end)
  E.add_filter("Verdant_E_GroupDmg", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  E.register("Verdant_E_EffectPlayer", EVENT_EFFECT_CHANGED, on_effect_player_src)
  E.add_filter("Verdant_E_EffectPlayer", EVENT_EFFECT_CHANGED,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

  E.register("Verdant_E_GroupJ", EVENT_GROUP_MEMBER_JOINED, on_group_change)
  E.register("Verdant_E_GroupL", EVENT_GROUP_MEMBER_LEFT,   on_group_left)
  E.register("Verdant_E_GroupU", EVENT_GROUP_UPDATE,        on_group_change)
  E.register("Verdant_E_PlayerAct", EVENT_PLAYER_ACTIVATED, on_group_change)
end
