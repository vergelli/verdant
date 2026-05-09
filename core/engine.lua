Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Engine = {}

-- Phase 4a: engine.lua is being split into pipeline/* stages. This module
-- still owns ZOS event subscriptions, but each handler delegates to
-- Verdant.Pipeline.dispatch_* in pipeline/pipeline.lua. Behavior is
-- preserved 1:1 for behavioral diff.
--
-- In Phase 4b the subscription registration moves into pipeline/pipeline.lua
-- and this module becomes a thin shim. In Phase 4c it goes away entirely.

local M = Verdant.Engine

local C = Verdant.zenimax.constants
local EVENT_COMBAT_EVENT          = C.EVENT_COMBAT_EVENT
local EVENT_EFFECT_CHANGED        = C.EVENT_EFFECT_CHANGED
local EVENT_GROUP_MEMBER_JOINED   = C.EVENT_GROUP_MEMBER_JOINED
local EVENT_GROUP_MEMBER_LEFT     = C.EVENT_GROUP_MEMBER_LEFT
local EVENT_GROUP_UPDATE          = C.EVENT_GROUP_UPDATE
local EVENT_PLAYER_ACTIVATED      = C.EVENT_PLAYER_ACTIVATED
local REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE = C.REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE
local REGISTER_FILTER_COMBAT_RESULT           = C.REGISTER_FILTER_COMBAT_RESULT
local REGISTER_FILTER_IS_ERROR                = C.REGISTER_FILTER_IS_ERROR
local COMBAT_UNIT_TYPE_PLAYER     = C.COMBAT_UNIT_TYPE_PLAYER
local ACTION_RESULT_HEAL              = C.ACTION_RESULT_HEAL
local ACTION_RESULT_HOT_TICK          = C.ACTION_RESULT_HOT_TICK
local ACTION_RESULT_CRITICAL_HEAL     = C.ACTION_RESULT_CRITICAL_HEAL
local ACTION_RESULT_HOT_TICK_CRITICAL = C.ACTION_RESULT_HOT_TICK_CRITICAL
local ACTION_RESULT_DAMAGE_SHIELDED   = C.ACTION_RESULT_DAMAGE_SHIELDED
local ACTION_RESULT_DAMAGE            = C.ACTION_RESULT_DAMAGE
local ACTION_RESULT_DOT_TICK          = C.ACTION_RESULT_DOT_TICK
local ACTION_RESULT_CRITICAL_DAMAGE   = C.ACTION_RESULT_CRITICAL_DAMAGE
local ACTION_RESULT_DOT_TICK_CRITICAL = C.ACTION_RESULT_DOT_TICK_CRITICAL
local ACTION_RESULT_BLOCKED_DAMAGE    = C.ACTION_RESULT_BLOCKED_DAMAGE
local ACTION_RESULT_FALL_DAMAGE       = C.ACTION_RESULT_FALL_DAMAGE

function M.init()
  local E = Verdant.zenimax.events
  local P = Verdant.Pipeline

  Verdant.Diagnostics.init()
  Verdant.Metrics.init()
  Verdant.Coverage.refresh_mode()

  E.register("Verdant_E_HealOut", EVENT_COMBAT_EVENT, function(...)
    local r = ...
    if r == ACTION_RESULT_HEAL
       or r == ACTION_RESULT_HOT_TICK
       or r == ACTION_RESULT_CRITICAL_HEAL
       or r == ACTION_RESULT_HOT_TICK_CRITICAL then
      P.dispatch_heal_out(...)
    end
  end)
  E.add_filter("Verdant_E_HealOut", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
  E.add_filter("Verdant_E_HealOut", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  E.register("Verdant_E_ShieldAbs", EVENT_COMBAT_EVENT, P.dispatch_shield_abs)
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
      P.dispatch_group_damage(...)
    end
  end)
  E.add_filter("Verdant_E_GroupDmg", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  E.register("Verdant_E_EffectPlayer", EVENT_EFFECT_CHANGED, P.dispatch_effect_player_src)
  E.add_filter("Verdant_E_EffectPlayer", EVENT_EFFECT_CHANGED,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

  E.register("Verdant_E_GroupJ", EVENT_GROUP_MEMBER_JOINED, P.dispatch_group_change)
  E.register("Verdant_E_GroupL", EVENT_GROUP_MEMBER_LEFT,   P.dispatch_group_left)
  E.register("Verdant_E_GroupU", EVENT_GROUP_UPDATE,        P.dispatch_group_change)
  E.register("Verdant_E_PlayerAct", EVENT_PLAYER_ACTIVATED, P.dispatch_group_change)
end
