Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Ultimate = {}
local M = Verdant.Ultimate

local log = Verdant.Log.for_module("ultimate")

local STEP_QUANT_MS = 250
local STEP_CAP      = 4800
local USED_CAP      = 100

local recording = false
local t_start   = 0
local t_end     = 0
local cost      = 0
local cur_value = 0
local cur_max   = 500
local n_steps   = 0
local step_t    = {}
local step_p    = {}
local n_used    = 0
local used_t    = {}
local saw_power = false
local ABIL_CAP  = 64
local n_abil    = 0
local abil_t    = {}
local abil_id   = {}
local cur_abil  = 0

local function bump(key) Verdant.Diagnostics.bump(key) end

local function now_ms()
  return Verdant.zenimax.api.GetGameTimeMilliseconds()
end

local function pct_now()
  local denom = (cost > 0) and cost or ((cur_max > 0) and cur_max or 500)
  local p = cur_value / denom
  if p > 1 then p = 1 end
  if p < 0 then p = 0 end
  return p
end

local function push_step(t)
  local p = pct_now()
  if n_steps > 0 and (t - step_t[n_steps]) < STEP_QUANT_MS then
    step_p[n_steps] = p
    return
  end
  if n_steps >= STEP_CAP then return end
  n_steps = n_steps + 1
  step_t[n_steps] = t
  step_p[n_steps] = p
end

local function push_ability(t, id)
  if n_abil >= ABIL_CAP then return end
  n_abil = n_abil + 1
  abil_t[n_abil]  = t
  abil_id[n_abil] = id
end

function M.refresh_slot()
  local api = Verdant.zenimax.api
  local zc  = Verdant.zenimax.constants
  if not (api.GetSlotBoundId and zc.ACTION_BAR_ULTIMATE_SLOT_INDEX) then return end
  local id = api.GetSlotBoundId(zc.ACTION_BAR_ULTIMATE_SLOT_INDEX + 1)
  if not id or id <= 0 or id == cur_abil then return end
  cur_abil = id
  bump("ult.slot_refresh")
  if recording then push_ability(now_ms(), id) end
end

function M.refresh_cost()
  M.refresh_slot()
  local api = Verdant.zenimax.api
  local zc  = Verdant.zenimax.constants
  if not (api.GetSlotAbilityCost and zc.ACTION_BAR_ULTIMATE_SLOT_INDEX
          and zc.COMBAT_MECHANIC_FLAGS_ULTIMATE) then
    return
  end
  local c = api.GetSlotAbilityCost(zc.ACTION_BAR_ULTIMATE_SLOT_INDEX + 1,
                                   zc.COMBAT_MECHANIC_FLAGS_ULTIMATE)
  if c and c > 0 and c ~= cost then
    cost = c
    bump("ult.cost_refresh")
    log:info("ultimate cost ->", cost)
    if recording then push_step(now_ms()) end
  end
end

function M.on_power(value, powerMax, effectiveMax)
  bump("ult.power_updates")
  saw_power = true
  cur_value = value or 0
  local m = effectiveMax or powerMax
  if m and m > 0 then cur_max = m end
  if recording then push_step(now_ms()) end
end

function M.on_used()
  bump("ult.used")
  if not recording or n_used >= USED_CAP then return end
  n_used = n_used + 1
  used_t[n_used] = now_ms()
end

function M.start_session(t)
  recording = true
  t_start   = t
  t_end     = 0
  n_steps   = 0
  n_used    = 0
  n_abil    = 0
  saw_power = false
  local api = Verdant.zenimax.api
  local zc  = Verdant.zenimax.constants
  if api.GetUnitPower and zc.COMBAT_MECHANIC_FLAGS_ULTIMATE then
    local v = api.GetUnitPower("player", zc.COMBAT_MECHANIC_FLAGS_ULTIMATE)
    if v then cur_value = v end
  end
  cur_abil = 0
  M.refresh_cost()
  if cur_abil > 0 and n_abil == 0 then push_ability(t, cur_abil) end
  push_step(t)
end

function M.finalize(t)
  if not recording then return end
  recording = false
  t_end = t
  log:info("session finalize: steps=", n_steps, "used=", n_used, "cost=", cost)
end

function M.reset()
  recording = false
  t_start   = 0
  t_end     = 0
  n_steps   = 0
  n_used    = 0
  n_abil    = 0
  saw_power = false
end

function M.steps()     return step_t, step_p, n_steps end
function M.used()      return used_t, n_used end
function M.abilities() return abil_t, abil_id, n_abil end
function M.has_data() return saw_power and n_steps > 0 end
function M.cost()     return cost end
function M.is_recording() return recording end

function M.load_session(steps, used, abilities)
  M.reset()
  for i = 1, #steps do
    step_t[i] = steps[i].t
    step_p[i] = steps[i].p or 0
  end
  n_steps = #steps
  for i = 1, #used do
    used_t[i] = used[i].t
  end
  n_used = #used
  abilities = abilities or {}
  for i = 1, #abilities do
    abil_t[i]  = abilities[i].t
    abil_id[i] = abilities[i].id or 0
  end
  n_abil = #abilities
  saw_power = n_steps > 0
  log:info("session loaded: steps=", n_steps, "used=", n_used, "abilities=", n_abil)
end

function M.pct_at(t)
  if n_steps == 0 then return 0 end
  if t < step_t[1] then return step_p[1] end
  local lo, hi = 1, n_steps
  while lo < hi do
    local mid = math.floor((lo + hi + 1) / 2)
    if step_t[mid] <= t then lo = mid else hi = mid - 1 end
  end
  return step_p[lo]
end

function M.snapshot()
  return {
    recording = recording, cost = cost, value = cur_value, max = cur_max,
    steps = n_steps, used = n_used, abilities = n_abil, ability = cur_abil,
    t_start = t_start, t_end = t_end,
  }
end

function M.report_lines()
  local dur_s = 0
  if t_start > 0 then
    local t_hi = (t_end > 0) and t_end or now_ms()
    dur_s = (t_hi - t_start) / 1000
  end
  local rate = (dur_s > 0) and (Verdant.Diagnostics.get("ult.power_updates") / dur_s) or 0
  return {
    string.format("cost=%d value=%d steps=%d used=%d power_rate=%.1f/s",
      cost, cur_value, n_steps, n_used, rate),
  }
end

function M.init()
  local zev = Verdant.zenimax.events
  local zc  = Verdant.zenimax.constants
  if not zc.COMBAT_MECHANIC_FLAGS_ULTIMATE then
    log:warn("no ultimate power type on this client; tracker disabled")
    return
  end
  zev.register("Verdant_E_UltPower", zc.EVENT_POWER_UPDATE,
    function(_unitTag, _idx, _ptype, value, powerMax, effectiveMax)
      M.on_power(value, powerMax, effectiveMax)
    end)
  zev.add_filter("Verdant_E_UltPower", zc.EVENT_POWER_UPDATE,
    zc.REGISTER_FILTER_POWER_TYPE, zc.COMBAT_MECHANIC_FLAGS_ULTIMATE)
  zev.add_filter("Verdant_E_UltPower", zc.EVENT_POWER_UPDATE,
    zc.REGISTER_FILTER_UNIT_TAG, "player")

  zev.register("Verdant_E_UltUsed", zc.EVENT_ACTION_SLOT_ABILITY_USED,
    function(actionSlotIndex)
      if zc.ACTION_BAR_ULTIMATE_SLOT_INDEX
         and actionSlotIndex == zc.ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 then
        M.on_used()
      end
    end)

  zev.register("Verdant_E_UltBars", zc.EVENT_ACTIVE_WEAPON_PAIR_CHANGED,
    function() M.refresh_cost() end)

  M.refresh_cost()
  log:info("init: cost=", cost)
end
