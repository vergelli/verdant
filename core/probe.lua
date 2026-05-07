Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Probe = {}

local d                          = d
local string_format              = string.format
local table_remove               = table.remove
local pairs                      = pairs
local type                       = type
local tostring                   = tostring
local GetGameTimeMilliseconds    = GetGameTimeMilliseconds
local GetAPIVersion              = GetAPIVersion
local GetString                  = GetString
local IsUnitGrouped              = IsUnitGrouped
local GetGroupSize               = GetGroupSize
local GetUnitName                = GetUnitName
local GetUnitDisplayName         = GetUnitDisplayName
local GetUnitClass               = GetUnitClass
local GetUnitRace                = GetUnitRace
local GetUnitLevel               = GetUnitLevel
local GetUnitChampionPoints      = GetUnitChampionPoints
local GetUnitAlliance            = GetUnitAlliance
local GetCurrentMapZoneIndex     = GetCurrentMapZoneIndex
local GetZoneNameByIndex         = GetZoneNameByIndex
local GetSlotName                = GetSlotName
local GetSlotBoundId             = GetSlotBoundId
local GetAbilityName             = GetAbilityName

local M = Verdant.Probe

-- --- Buffer / state ------------------------------------------------------

local function new_state()
  return {
    enabled       = false,
    filter        = "all",
    last_chat_ms  = 0,
    last_save_ms  = 0,
    in_combat     = false,
    session_id    = (M.state and M.state.session_id or 0) + 1,
    buffers = {
      heal          = {},  -- heals from player (filtered: hit>0 or overflow>0)
      shield        = {},  -- DAMAGE_SHIELDED with source=player (current §3 model)
      shield_raw    = {},  -- DAMAGE_SHIELDED with NO source filter (V2 ground truth)
      heal_absorbed = {},  -- HEAL_ABSORBED with source=player
      damage        = {},  -- damage with target=group (D_group denominator)
      effect        = {},  -- effects with source=player
      effect_self   = {},  -- effects with target=player
      casts         = {},  -- EVENT_ACTION_SLOT_ABILITY_USED
      combat        = {},  -- combat state transitions
      group         = {},  -- group composition snapshots
    },
    stats = {
      heal=0, shield=0, shield_raw=0, heal_absorbed=0, damage=0,
      effect=0, effect_self=0, casts=0, combat=0, group=0,
      noise_dropped=0, autosaves=0,
    },
    universe = {
      abilities = {},  -- [abilityId] = name (first-seen)
      targets   = {},  -- [unitId]    = { name=, lastType= } (first-seen)
    },
    context = nil,    -- filled by snapshot_context
    last_ping_stats = nil,
    player_unit_id  = nil,  -- learned lazily from first combat event with source=player
    session_tag     = nil,  -- user-supplied label for this test run
  }
end

local state = new_state()
M.state = state

-- --- Helpers -------------------------------------------------------------

local function now() return GetGameTimeMilliseconds() end

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
  local t = now()
  if t - state.last_chat_ms < Verdant.Constants.PROBE.CHAT_INTERVAL_MS then return end
  state.last_chat_ms = t
  d("[V] " .. line)
end

local function remember_ability(abilityId, abilityName)
  if not abilityId or abilityId == 0 then return end
  if state.universe.abilities[abilityId] == nil then
    state.universe.abilities[abilityId] = abilityName or ""
  end
end

local function remember_target(unitId, name, unitType)
  if not unitId or unitId == 0 then return end
  local prior = state.universe.targets[unitId]
  if prior == nil then
    state.universe.targets[unitId] = { name = name or "", lastType = unitType or 0 }
  elseif unitType then
    prior.lastType = unitType
  end
end

local function effect_change_label(c)
  if c == EFFECT_RESULT_GAINED       then return "GAIN" end
  if c == EFFECT_RESULT_FADED        then return "FADE" end
  if c == EFFECT_RESULT_UPDATED      then return "UPD"  end
  if c == EFFECT_RESULT_FULL_REFRESH then return "REFR" end
  if c == EFFECT_RESULT_TRANSFER     then return "TRAN" end
  return tostring(c)
end

-- --- Combat handlers -----------------------------------------------------

-- EVENT_COMBAT_EVENT signature (17 args):
--   result, isError, abilityName, abilityGraphic, abilitySlotType,
--   sourceName, sourceType, targetName, targetType, hitValue,
--   powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow
local function on_combat_out(result, isError, abilityName, _g, _slot,
                             sourceName, sourceType, targetName, targetType, hitValue,
                             _pt, _dt, _log, sourceUnitId, targetUnitId,
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
  else
    return
  end

  -- Drop noise: ESO emits ACTION_RESULT_HEAL with hit=0/ovf=0 mirrors per HoT tick.
  if (hitValue or 0) == 0 and (overflow or 0) == 0 then
    state.stats.noise_dropped = state.stats.noise_dropped + 1
    return
  end

  if not state.player_unit_id and sourceType == COMBAT_UNIT_TYPE_PLAYER and sourceUnitId and sourceUnitId ~= 0 then
    state.player_unit_id = sourceUnitId
    if state.context and state.context.player then state.context.player.unitId = sourceUnitId end
  end

  remember_ability(abilityId, abilityName)
  remember_target(targetUnitId, targetName, targetType)

  push(category, {
    t          = now(),
    result     = result,
    ability    = abilityName,
    abilityId  = abilityId,
    target     = targetName,
    targetType = targetType,
    targetUnit = targetUnitId,
    sourceName = sourceName,
    sourceType = sourceType,
    sourceUnit = sourceUnitId,
    hit        = hitValue,
    overflow   = overflow,
  })
  state.stats[category] = state.stats[category] + 1

  if should_log(category) then
    chat_emit(string_format(
      "%s | r=%d | %s -> %s | hit=%d ovf=%d | tuid=%d ab=%d",
      category, result or 0, abilityName or "?", targetName or "?",
      hitValue or 0, overflow or 0, targetUnitId or 0, abilityId or 0
    ))
  end
end

-- Catches every shield-absorption regardless of source attribution.
-- The data here is the ground truth for V2: by inspecting source/target ids
-- we deduce whether ESO attributes shields to caster, attacker, or target.
local function on_shield_raw(result, isError, abilityName, _g, _slot,
                             sourceName, sourceType, targetName, targetType, hitValue,
                             _pt, _dt, _log, sourceUnitId, targetUnitId,
                             abilityId, overflow)
  if isError then return end
  if result ~= ACTION_RESULT_DAMAGE_SHIELDED then return end

  remember_ability(abilityId, abilityName)
  remember_target(targetUnitId, targetName, targetType)
  remember_target(sourceUnitId, sourceName, sourceType)

  push("shield_raw", {
    t          = now(),
    ability    = abilityName,
    abilityId  = abilityId,
    sourceName = sourceName,
    sourceType = sourceType,
    sourceUnit = sourceUnitId,
    targetName = targetName,
    targetType = targetType,
    targetUnit = targetUnitId,
    hit        = hitValue,
    overflow   = overflow,
  })
  state.stats.shield_raw = state.stats.shield_raw + 1

  if should_log("shield_raw") then
    chat_emit(string_format(
      "shldRAW | %s (st=%d,suid=%d) -> %s (tt=%d,tuid=%d) | abs=%d ab=%s",
      sourceName or "?", sourceType or 0, sourceUnitId or 0,
      targetName or "?", targetType or 0, targetUnitId or 0,
      hitValue or 0, abilityName or "?"
    ))
  end
end

local function on_heal_absorbed(result, isError, abilityName, _g, _slot,
                                sourceName, sourceType, targetName, targetType, hitValue,
                                _pt, _dt, _log, sourceUnitId, targetUnitId,
                                abilityId, overflow)
  if isError then return end
  if result ~= ACTION_RESULT_HEAL_ABSORBED then return end

  remember_ability(abilityId, abilityName)
  remember_target(targetUnitId, targetName, targetType)

  push("heal_absorbed", {
    t          = now(),
    ability    = abilityName,
    abilityId  = abilityId,
    target     = targetName,
    targetType = targetType,
    targetUnit = targetUnitId,
    sourceName = sourceName,
    sourceType = sourceType,
    sourceUnit = sourceUnitId,
    hit        = hitValue,
    overflow   = overflow,
  })
  state.stats.heal_absorbed = state.stats.heal_absorbed + 1

  if should_log("heal_abs") then
    chat_emit(string_format(
      "healABS | %s -> %s | absorbed=%d ab=%s",
      sourceName or "?", targetName or "?", hitValue or 0, abilityName or "?"
    ))
  end
end

local function on_combat_in_group(result, isError, abilityName, _g, _slot,
                                  sourceName, sourceType, targetName, targetType, hitValue,
                                  _pt, _dt, _log, sourceUnitId, targetUnitId,
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

  remember_ability(abilityId, abilityName)
  remember_target(targetUnitId, targetName, targetType)
  remember_target(sourceUnitId, sourceName, sourceType)

  push("damage", {
    t          = now(),
    result     = result,
    ability    = abilityName,
    abilityId  = abilityId,
    sourceName = sourceName,
    sourceType = sourceType,
    sourceUnit = sourceUnitId,
    target     = targetName,
    targetType = targetType,
    targetUnit = targetUnitId,
    hit        = hitValue,
  })
  state.stats.damage = state.stats.damage + 1

  if should_log("damage") then
    chat_emit(string_format(
      "dmg | r=%d | %s -> %s | %d | tuid=%d",
      result or 0, sourceName or "?", targetName or "?", hitValue or 0, targetUnitId or 0
    ))
  end
end

-- EVENT_EFFECT_CHANGED signature (16 args):
--   changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount,
--   iconName, deprecatedBuffType, effectType, abilityType, statusEffectType,
--   unitName, unitId, abilityId, sourceType
local function make_effect_handler(category)
  return function(changeType, _slot, effectName, unitTag, beginTime, endTime,
                  stackCount, _icon, _depBuff, effectType, abilityType,
                  _stat, unitName, unitId, abilityId, sourceType)
    remember_ability(abilityId, effectName)
    remember_target(unitId, unitName ~= "" and unitName or unitTag, sourceType)

    push(category, {
      t           = now(),
      change      = changeType,
      effect      = effectName,
      unitTag     = unitTag,
      unitName    = unitName,
      unitId      = unitId,
      abilityId   = abilityId,
      abilityType = abilityType,
      effectType  = effectType,
      sourceType  = sourceType,
      beginTime   = beginTime,
      endTime     = endTime,
      stacks      = stackCount,
    })
    state.stats[category] = state.stats[category] + 1

    if should_log(category) then
      chat_emit(string_format(
        "%s | %s | %s on %s (uid=%d) | etype=%d atype=%d ab=%d srct=%d",
        category, effect_change_label(changeType), effectName or "?",
        unitName ~= "" and unitName or unitTag or "?",
        unitId or 0, effectType or 0, abilityType or 0, abilityId or 0, sourceType or 0
      ))
    end
  end
end

local on_effect_player_src   = make_effect_handler("effect")
local on_effect_on_self      = make_effect_handler("effect_self")

local function on_combat_state(inCombat)
  local entry = { t = now(), inCombat = inCombat and true or false }
  state.in_combat = entry.inCombat
  push("combat", entry)
  state.stats.combat = state.stats.combat + 1
  if should_log("combat") then
    chat_emit(string_format("combat | %s", entry.inCombat and "ENTER" or "EXIT"))
  end
  if not entry.inCombat then
    M.maybe_autosave()
  end
end

local function on_action_slot_used(actionSlotIndex)
  local abilityId   = GetSlotBoundId(actionSlotIndex)
  local abilityName = (abilityId and abilityId > 0) and GetAbilityName(abilityId, "player") or GetSlotName(actionSlotIndex)
  remember_ability(abilityId, abilityName)
  push("casts", {
    t           = now(),
    slot        = actionSlotIndex,
    abilityId   = abilityId,
    abilityName = abilityName,
  })
  state.stats.casts = state.stats.casts + 1
  if should_log("cast") then
    chat_emit(string_format("cast | slot=%d ab=%d %s", actionSlotIndex, abilityId or 0, abilityName or "?"))
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
        tag     = tag,
        name    = GetUnitName(tag),
        display = GetUnitDisplayName(tag),
        class   = GetUnitClass(tag),
        -- unitId is not directly retrievable from API; correlate via universe.targets after events fire.
      }
    end
  end
  push("group", {
    t       = now(),
    reason  = reason,
    grouped = grouped,
    size    = size,
    members = members,
  })
  state.stats.group = state.stats.group + 1
  if should_log("group") then
    chat_emit(string_format("group | %s | grouped=%s size=%d", reason or "?", tostring(grouped), size))
  end
end

-- --- Context snapshot ----------------------------------------------------

local function snapshot_bars()
  local bars = {}
  for _, hotbar in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
    local slots = {}
    for slot = 3, 8 do
      local abilityId = GetSlotBoundId(slot, hotbar)
      slots[#slots + 1] = {
        slot      = slot,
        abilityId = abilityId,
        name      = (abilityId and abilityId > 0) and GetAbilityName(abilityId, "player") or "",
      }
    end
    bars[#bars + 1] = { hotbar = hotbar, slots = slots }
  end
  return bars
end

function M.snapshot_context()
  local zoneIdx = GetCurrentMapZoneIndex()
  state.context = {
    t           = now(),
    api_version = GetAPIVersion(),
    player = {
      name      = GetUnitName("player"),
      display   = GetUnitDisplayName("player"),
      -- unitId is filled lazily from the first combat event with sourceType=PLAYER.
      unitId    = state.player_unit_id or 0,
      level     = GetUnitLevel("player"),
      cp        = GetUnitChampionPoints("player"),
      class     = GetUnitClass("player"),
      race      = GetUnitRace("player"),
      alliance  = GetUnitAlliance("player"),
    },
    zone = {
      index = zoneIdx,
      name  = zoneIdx and GetZoneNameByIndex(zoneIdx) or "",
    },
    bars = snapshot_bars(),
  }
end

-- --- Public API ----------------------------------------------------------

function M.set_enabled(v)        state.enabled = v and true or false end
function M.set_filter(category)  state.filter = category end
function M.set_tag(tag)          state.session_tag = tag and tag ~= "" and tag or nil end
function M.get_tag()             return state.session_tag end

function M.clear()
  for k in pairs(state.buffers) do state.buffers[k] = {} end
  for k in pairs(state.stats)   do state.stats[k]   = 0  end
  state.universe = { abilities = {}, targets = {} }
end

function M.format_entry(category, e)
  if category == "heal" or category == "shield" then
    return string_format("t=%d r=%d ab=%s tgt=%s tuid=%d hit=%d ovf=%d",
      e.t or 0, e.result or 0, e.ability or "?", e.target or "?", e.targetUnit or 0, e.hit or 0, e.overflow or 0)
  elseif category == "shield_raw" then
    return string_format("t=%d ab=%s | src=%s(t=%d,uid=%d) tgt=%s(t=%d,uid=%d) abs=%d",
      e.t or 0, e.ability or "?",
      e.sourceName or "?", e.sourceType or 0, e.sourceUnit or 0,
      e.targetName or "?", e.targetType or 0, e.targetUnit or 0, e.hit or 0)
  elseif category == "heal_absorbed" then
    return string_format("t=%d ab=%s tgt=%s absorbed=%d",
      e.t or 0, e.ability or "?", e.target or "?", e.hit or 0)
  elseif category == "damage" then
    return string_format("t=%d r=%d ab=%s src=%s tgt=%s tuid=%d hit=%d",
      e.t or 0, e.result or 0, e.ability or "?", e.sourceName or "?", e.target or "?", e.targetUnit or 0, e.hit or 0)
  elseif category == "effect" or category == "effect_self" then
    return string_format("t=%d ch=%s fx=%s unit=%s uid=%d etype=%s atype=%s srct=%s",
      e.t or 0, effect_change_label(e.change), e.effect or "?",
      (e.unitName ~= "" and e.unitName) or e.unitTag or "?",
      e.unitId or 0, tostring(e.effectType), tostring(e.abilityType), tostring(e.sourceType))
  elseif category == "casts" then
    return string_format("t=%d slot=%d ab=%d %s",
      e.t or 0, e.slot or 0, e.abilityId or 0, e.abilityName or "?")
  elseif category == "combat" then
    return string_format("t=%d %s", e.t or 0, e.inCombat and "ENTER" or "EXIT")
  elseif category == "group" then
    return string_format("t=%d %s grouped=%s size=%d", e.t or 0, e.reason or "?", tostring(e.grouped), e.size or 0)
  end
  return "?"
end

function M.print_stats()
  local s = state.stats
  d(string_format(
    "[V] stats: heal=%d shld=%d shldRAW=%d healABS=%d dmg=%d fx=%d fxSelf=%d cast=%d combat=%d group=%d | noise=%d saves=%d",
    s.heal, s.shield, s.shield_raw, s.heal_absorbed, s.damage,
    s.effect, s.effect_self, s.casts, s.combat, s.group, s.noise_dropped, s.autosaves
  ))
end

function M.print_ping()
  local s = state.stats
  local snapshot = {
    heal=s.heal, shield=s.shield, shield_raw=s.shield_raw,
    heal_absorbed=s.heal_absorbed, damage=s.damage,
    effect=s.effect, effect_self=s.effect_self, casts=s.casts,
  }
  if state.last_ping_stats then
    local prev = state.last_ping_stats
    d(string_format(
      "[V] ping: dHeal=%d dShld=%d dShldRAW=%d dHealAbs=%d dDmg=%d dFx=%d dFxSelf=%d dCast=%d",
      snapshot.heal-prev.heal, snapshot.shield-prev.shield, snapshot.shield_raw-prev.shield_raw,
      snapshot.heal_absorbed-prev.heal_absorbed, snapshot.damage-prev.damage,
      snapshot.effect-prev.effect, snapshot.effect_self-prev.effect_self, snapshot.casts-prev.casts
    ))
  else
    d("[V] ping: baseline set, run /verdant ping again to see deltas.")
  end
  state.last_ping_stats = snapshot
end

function M.print_context()
  local c = state.context
  if not c then d("[V] context not yet captured (waits for EVENT_PLAYER_ACTIVATED).") return end
  local p = c.player
  d(string_format("[V] %s %s lv%d cp%d %s/%s | zone=%s (idx=%d) | api=%d",
    p.display or "?", p.name or "?", p.level or 0, p.cp or 0,
    tostring(p.class), tostring(p.race), c.zone.name or "", c.zone.index or 0, c.api_version or 0))
  for i, bar in ipairs(c.bars) do
    local parts = { "bar" .. i .. ":" }
    for _, slot in ipairs(bar.slots) do
      parts[#parts + 1] = string_format("[%d]%s", slot.slot, slot.name ~= "" and slot.name or "-")
    end
    d("[V] " .. table.concat(parts, " "))
  end
end

function M.dump()
  local total = 0
  for _, buf in pairs(state.buffers) do total = total + #buf end
  if total == 0 then d("[V] " .. GetString(VERDANT_DUMP_EMPTY)) return end
  d("[V] " .. GetString(VERDANT_DUMP_HEADER))
  M.print_stats()
  for category, buf in pairs(state.buffers) do
    if #buf > 0 then
      d(string_format("[V] -- %s (%d) --", category, #buf))
      for i = 1, #buf do
        d(string_format("[V]   %s", M.format_entry(category, buf[i])))
      end
    end
  end
end

local function deep_copy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = deep_copy(v) end
  return out
end

function M.persist_to_savedvars(sv)
  if not sv then return false end
  sv.probe = sv.probe or {}
  sv.probe.dumps = sv.probe.dumps or {}

  local snapshot = {
    taken_at_ms = now(),
    session_id  = state.session_id,
    session_tag = state.session_tag,
    in_combat   = state.in_combat,
    context     = deep_copy(state.context),
    stats       = deep_copy(state.stats),
    universe    = deep_copy(state.universe),
    buffers     = deep_copy(state.buffers),
    engine      = Verdant.Diagnostics and deep_copy(Verdant.Diagnostics.snapshot()) or nil,
  }

  table.insert(sv.probe.dumps, 1, snapshot)
  while #sv.probe.dumps > Verdant.Constants.PROBE.DUMP_HISTORY_LIMIT do
    sv.probe.dumps[#sv.probe.dumps] = nil
  end
  -- Keep `last_dump` as a convenience pointer to the newest snapshot.
  sv.probe.last_dump = sv.probe.dumps[1]

  state.last_save_ms = now()
  state.stats.autosaves = state.stats.autosaves + 1
  return true
end

function M.maybe_autosave()
  local cooldown = Verdant.Constants.PROBE.AUTOSAVE_COOLDOWN_MS
  if now() - state.last_save_ms < cooldown then return end
  if Verdant.SavedVars then
    M.persist_to_savedvars(Verdant.SavedVars)
  end
end

-- --- Wiring --------------------------------------------------------------

function M.init()
  local P = Verdant.Constants.PROBE
  local E = Verdant.zenimax.events

  -- 1) Heals/shields where I am the source (current §3.4 model assumption).
  E.register(P.SRC_COMBAT_OUT, EVENT_COMBAT_EVENT, on_combat_out)
  E.add_filter(P.SRC_COMBAT_OUT, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
  E.add_filter(P.SRC_COMBAT_OUT, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  -- 2) DAMAGE_SHIELDED everywhere — V2 ground truth, no source filter.
  E.register(P.SRC_SHIELD_RAW, EVENT_COMBAT_EVENT, on_shield_raw)
  E.add_filter(P.SRC_SHIELD_RAW, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DAMAGE_SHIELDED)
  E.add_filter(P.SRC_SHIELD_RAW, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  -- 3) HEAL_ABSORBED with source=player — symmetric diagnostic.
  E.register(P.SRC_HEAL_ABSORBED, EVENT_COMBAT_EVENT, on_heal_absorbed)
  E.add_filter(P.SRC_HEAL_ABSORBED, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_HEAL_ABSORBED)
  E.add_filter(P.SRC_HEAL_ABSORBED, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

  -- 4) Damage landing on the group (D_group denominator).
  E.register(P.SRC_COMBAT_IN, EVENT_COMBAT_EVENT, on_combat_in_group)
  E.add_filter(P.SRC_COMBAT_IN, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_GROUP)
  E.add_filter(P.SRC_COMBAT_IN, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  -- 5) Effects with source=player (shields applied, debuffs cast, purges).
  E.register(P.SRC_EFFECT, EVENT_EFFECT_CHANGED, on_effect_player_src)
  E.add_filter(P.SRC_EFFECT, EVENT_EFFECT_CHANGED,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

  -- 6) Effects on player (any source) — shields received, debuffs to purge.
  E.register(P.SRC_EFFECT_ON_SELF, EVENT_EFFECT_CHANGED, on_effect_on_self)
  E.add_filter(P.SRC_EFFECT_ON_SELF, EVENT_EFFECT_CHANGED,
    REGISTER_FILTER_UNIT_TAG, "player")

  -- 7) Player combat state — auto-save trigger and episode boundaries.
  E.register(P.SRC_COMBAT_STATE, EVENT_PLAYER_COMBAT_STATE, on_combat_state)

  -- 8) Cast tracking (for V9/V10 purge correlation).
  E.register(P.SRC_CAST, EVENT_ACTION_SLOT_ABILITY_USED, on_action_slot_used)

  -- 9) Auto-persist on deactivation (logout / /reloadui / zoning).
  E.register(P.SRC_AUTOSAVE, EVENT_PLAYER_DEACTIVATED, function()
    if Verdant.SavedVars then M.persist_to_savedvars(Verdant.SavedVars) end
  end)

  -- 10) Group state observers.
  E.register(P.SRC_GROUP_J, EVENT_GROUP_MEMBER_JOINED, function() snapshot_group("joined") end)
  E.register(P.SRC_GROUP_L, EVENT_GROUP_MEMBER_LEFT,   function() snapshot_group("left") end)
  E.register(P.SRC_GROUP_U, EVENT_GROUP_UPDATE,        function() snapshot_group("update") end)
  E.register(P.SRC_PLAYER,  EVENT_PLAYER_ACTIVATED, function()
    M.snapshot_context()
    snapshot_group("activated")
  end)
end
