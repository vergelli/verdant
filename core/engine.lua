Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Engine = {}

-- Routes EVENT_COMBAT_EVENT and EVENT_EFFECT_CHANGED into the metrics
-- pipeline. Lives parallel to the Probe — Probe is for diagnostics; the
-- Engine is what feeds the contribution bar.

local M = Verdant.Engine

local GetGameTimeMilliseconds = GetGameTimeMilliseconds

local function now() return GetGameTimeMilliseconds() end

local function on_heal_out(result, isError, _name, _g, _slot,
                           _src, sourceType, _tgt, targetType, hit,
                           _pt, _dt, _log, _suid, targetUnitId,
                           abilityId, overflow)
  if isError then return end
  if (hit or 0) == 0 and (overflow or 0) == 0 then return end
  if not Verdant.Mode.uses("heal") and not Verdant.Mode.uses("overheal") then return end

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
  if isError then return end
  if not Verdant.Mode.uses("shield_abs") then return end
  if not Verdant.ShieldRegistry.is_self_cast(abilityId, targetUnitId) then return end

  local t = now()
  Verdant.Metrics.ingest_shield(t, hit, targetUnitId, targetType, abilityId)
  Verdant.Coverage.touch(targetUnitId, t)
end

local function on_group_damage(result, isError, _name, _g, _slot,
                               _src, _sourceType, _tgt, _targetType, hit,
                               _pt, _dt, _log, _suid, targetUnitId,
                               _abilityId, _overflow)
  if isError then return end
  if not Verdant.Mode.uses("damage") then return end
  Verdant.Metrics.ingest_damage_group(now(), hit, targetUnitId)
end

local function on_effect_player_src(changeType, _slot, _name, _tag, _bt, endTime,
                                    _stack, _icon, _depBuff, _et, _at,
                                    _stat, _uname, unitId, abilityId, sourceType)
  Verdant.ShieldRegistry.on_effect(changeType, abilityId, unitId, sourceType, endTime)
end

local function on_group_change()
  Verdant.Coverage.refresh_mode()
end

function M.init()
  local E = Verdant.Events

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
    REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_GROUP)
  E.add_filter("Verdant_E_GroupDmg", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  E.register("Verdant_E_EffectPlayer", EVENT_EFFECT_CHANGED, on_effect_player_src)
  E.add_filter("Verdant_E_EffectPlayer", EVENT_EFFECT_CHANGED,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

  E.register("Verdant_E_GroupJ", EVENT_GROUP_MEMBER_JOINED, on_group_change)
  E.register("Verdant_E_GroupL", EVENT_GROUP_MEMBER_LEFT,   on_group_change)
  E.register("Verdant_E_GroupU", EVENT_GROUP_UPDATE,        on_group_change)
  E.register("Verdant_E_PlayerAct", EVENT_PLAYER_ACTIVATED, on_group_change)
end
