Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Triage = {}
local M = Verdant.Triage

local math_floor = math.floor
local table_sort = table.sort
local pairs      = pairs

local THETA          = 0.50
local THETA_EXIT     = 0.55
local DELTA_MS       = 1000
local GRACE_RES_MS   = 3000
local SIGMA_MS       = 2000
local MIN_EPISODE_MS = 400
local LOG_CAP        = 128
local MAX_SLOTS      = 12
local CENSOR_TICK_MS = 1000

local CLASS_S       = 1
local CLASS_O       = 2
local CLASS_L       = 3
local CLASS_M       = 4
local CLASS_X       = 5
local CLASS_ONESHOT = 6

M.CLASS_S       = CLASS_S
M.CLASS_O       = CLASS_O
M.CLASS_L       = CLASS_L
M.CLASS_M       = CLASS_M
M.CLASS_X       = CLASS_X
M.CLASS_ONESHOT = CLASS_ONESHOT

local TAG_SLOT = {}
for i = 1, MAX_SLOTS do TAG_SLOT["group" .. i] = i end

local slots = {}
for i = 1, MAX_SLOTS do
  slots[i] = {
    open = false, dead = false,
    start = 0, last_t = 0, grace_until = 0,
    rt = -1, responded = false, overflow = false,
    last_heal_t = -1, min_rho = 1,
  }
end

local ep_log = { n = 0 }
local ep_dropped = 0

local name_slot = {}
local name_count = 0
local session_active = false
local pu_count = 0
local pu_first_t = 0
local pu_last_t = 0
local heal_matched = 0
local heal_unmatched = 0

local log
local api
local GetGameTimeMilliseconds

local function bump(k) Verdant.Diagnostics.bump(k) end

local function log_episode(slot_i, s, t_end, class, star)
  if ep_log.n >= LOG_CAP then
    ep_dropped = ep_dropped + 1
    return
  end
  ep_log.n = ep_log.n + 1
  local e = ep_log[ep_log.n]
  if not e then e = {}; ep_log[ep_log.n] = e end
  e.slot    = slot_i
  e.t_start = s.start
  e.t_end   = t_end
  e.class   = class
  e.star    = star or false
  e.rt      = s.rt
  e.min_rho = s.min_rho
end

local function close_episode(slot_i, s, now, kind)
  local class, star = CLASS_X, false
  if kind == 1 then
    if s.responded then
      class = CLASS_S
      star  = s.overflow or (s.last_heal_t >= 0 and (now - s.last_heal_t) <= DELTA_MS)
    else
      class = CLASS_O
    end
  elseif kind == 2 then
    if s.responded then
      class = CLASS_L
    elseif (now - s.start) < MIN_EPISODE_MS then
      class = CLASS_ONESHOT
    else
      class = CLASS_M
    end
  end
  log_episode(slot_i, s, now, class, star)
  bump("triage.episode.closed")
  s.open = false
end

function M.on_power(unitTag, _idx, _ptype, value, _max, effMax)
  pu_count = pu_count + 1
  local now = GetGameTimeMilliseconds()
  if pu_first_t == 0 then pu_first_t = now end
  pu_last_t = now
  if not session_active then return end
  local i = TAG_SLOT[unitTag]
  if not i then return end
  local s = slots[i]
  s.last_t = now
  if s.dead or now < s.grace_until then return end
  if not effMax or effMax <= 0 then return end
  local rho = value / effMax
  if s.open then
    if rho < s.min_rho then s.min_rho = rho end
    if rho >= THETA_EXIT then close_episode(i, s, now, 1) end
  elseif rho < THETA then
    s.open        = true
    s.start       = now
    s.rt          = -1
    s.responded   = false
    s.overflow    = false
    s.last_heal_t = -1
    s.min_rho     = rho
    bump("triage.episode.opened")
  end
end

function M.on_own_heal(targetName, hit, overflow, now)
  if not session_active or name_count == 0 then return end
  local i = name_slot[targetName]
  if not i then
    heal_unmatched = heal_unmatched + 1
    return
  end
  heal_matched = heal_matched + 1
  local s = slots[i]
  if not s.open then return end
  if hit and hit > 0 then
    if s.rt < 0 then s.rt = now - s.start end
    s.responded   = true
    s.last_heal_t = now
  end
  if overflow and overflow > 0 then s.overflow = true end
end

function M.on_unit_death(unitTag, isDead)
  if not session_active then return end
  local i = TAG_SLOT[unitTag]
  if not i then return end
  local s = slots[i]
  local now = GetGameTimeMilliseconds()
  if isDead then
    if s.open then close_episode(i, s, now, 2) end
    s.dead = true
  else
    s.dead = false
    s.grace_until = now + GRACE_RES_MS
  end
end

local function censor_tick()
  if not session_active then return end
  local now = GetGameTimeMilliseconds()
  for i = 1, MAX_SLOTS do
    local s = slots[i]
    if s.open and (now - s.last_t) > SIGMA_MS then
      close_episode(i, s, now, 3)
      bump("triage.episode.censored_stale")
    end
  end
end

function M.refresh_names()
  for k in pairs(name_slot) do name_slot[k] = nil end
  name_count = 0
  local n = api.GetGroupSize() or 0
  for i = 1, MAX_SLOTS do
    if i <= n then
      local nm = api.GetUnitName("group" .. i)
      if nm and nm ~= "" then
        name_slot[nm] = i
        name_count = name_count + 1
      end
    end
  end
end

function M.on_session_start()
  session_active = true
  ep_log.n = 0
  ep_dropped = 0
  pu_count = 0
  pu_first_t = 0
  pu_last_t = 0
  heal_matched = 0
  heal_unmatched = 0
  for i = 1, MAX_SLOTS do
    local s = slots[i]
    s.open = false
    s.dead = false
    s.grace_until = 0
    s.last_t = 0
  end
  M.refresh_names()
  Verdant.zenimax.events.register_update("Verdant_TriageCensor", CENSOR_TICK_MS, censor_tick)
end

function M.on_session_stop()
  if not session_active then return end
  local now = GetGameTimeMilliseconds()
  for i = 1, MAX_SLOTS do
    local s = slots[i]
    if s.open then close_episode(i, s, now, 3) end
  end
  session_active = false
  Verdant.zenimax.events.unregister_update("Verdant_TriageCensor")
end

local rt_scratch = {}

function M.summary()
  local c = { s = 0, s_star = 0, o = 0, l = 0, m = 0, x = 0, oneshot = 0 }
  local rn = 0
  for i = 1, ep_log.n do
    local e = ep_log[i]
    if e.class == CLASS_S then
      c.s = c.s + 1
      if e.star then c.s_star = c.s_star + 1 end
    elseif e.class == CLASS_O then c.o = c.o + 1
    elseif e.class == CLASS_L then c.l = c.l + 1
    elseif e.class == CLASS_M then c.m = c.m + 1
    elseif e.class == CLASS_X then c.x = c.x + 1
    elseif e.class == CLASS_ONESHOT then c.oneshot = c.oneshot + 1
    end
    if e.rt >= 0 then
      rn = rn + 1
      rt_scratch[rn] = e.rt
    end
  end
  for i = rn + 1, #rt_scratch do rt_scratch[i] = nil end
  table_sort(rt_scratch)
  local rt50, rt95 = -1, -1
  if rn > 0 then
    local i50 = math_floor(rn * 0.50 + 0.5)
    local i95 = math_floor(rn * 0.95 + 0.5)
    if i50 < 1 then i50 = 1 end
    if i95 < 1 then i95 = 1 end
    rt50 = rt_scratch[i50]
    rt95 = rt_scratch[i95]
  end
  local denom = c.s + c.o + c.l + c.m
  return {
    episodes  = ep_log.n,
    dropped   = ep_dropped,
    counts    = c,
    responded = rn,
    rt50      = rt50,
    rt95      = rt95,
    coverage  = (denom > 0) and (c.s / denom) or -1,
  }
end

function M.episodes() return ep_log, ep_log.n end
function M.is_active() return session_active end

function M.power_stats()
  local dur = (pu_last_t > pu_first_t) and (pu_last_t - pu_first_t) or 0
  return {
    count = pu_count,
    rate  = (dur > 0) and (pu_count / (dur / 1000)) or 0,
    matched = heal_matched,
    unmatched = heal_unmatched,
  }
end

function M.report_lines()
  local lines = {}
  local ps = M.power_stats()
  lines[#lines + 1] = string.format(
    "params: theta=%.2f exit=%.2f delta=%dms grace=%dms sigma=%dms min_ep=%dms",
    THETA, THETA_EXIT, DELTA_MS, GRACE_RES_MS, SIGMA_MS, MIN_EPISODE_MS)
  lines[#lines + 1] = string.format(
    "power_updates=%d  rate=%.1f/s  heals matched=%d unmatched=%d",
    ps.count, ps.rate, ps.matched, ps.unmatched)
  lines[#lines + 1] = string.format(
    "session_active=%s  name_map=%d entries", tostring(session_active), name_count)
  local s = M.summary()
  lines[#lines + 1] = string.format(
    "episodes=%d (dropped=%d)  S=%d (S*=%d)  O=%d  L=%d  M=%d  X=%d  oneshot=%d",
    s.episodes, s.dropped, s.counts.s, s.counts.s_star, s.counts.o,
    s.counts.l, s.counts.m, s.counts.x, s.counts.oneshot)
  if s.responded > 0 then
    lines[#lines + 1] = string.format(
      "RT50=%dms  RT95=%dms  responded=%d  coverage=%.0f%%",
      s.rt50, s.rt95, s.responded,
      (s.coverage >= 0) and s.coverage * 100 or 0)
  else
    lines[#lines + 1] = "RT: no responded episodes"
  end
  for i = 1, MAX_SLOTS do
    local sl = slots[i]
    if sl.open or sl.dead or sl.last_t > 0 then
      lines[#lines + 1] = string.format(
        "  group%d: open=%s dead=%s last_t=%d min_rho=%.2f",
        i, tostring(sl.open), tostring(sl.dead), sl.last_t, sl.min_rho)
    end
  end
  return lines
end

function M.init()
  log = Verdant.Log.for_module("triage")
  api = Verdant.zenimax.api
  GetGameTimeMilliseconds = api.GetGameTimeMilliseconds
  log:info("init: theta=", THETA, "exit=", THETA_EXIT, "slots=", MAX_SLOTS)
end
