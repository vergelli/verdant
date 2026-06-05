Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Metrics = {}

local M = Verdant.Metrics

local W_MS       = 5000
local W_SHIELD_MS = 30000   -- shields are sparse; wider window avoids permanent zero

local heal_buf, overheal_buf, shield_buf, damage_buf
local event_pool
local log = Verdant.Log.for_module("metrics")

local function in_M(entry)
  return Verdant.Coverage.is_in_M(entry.target_type)
end

-- Crit-heal result codes, bound in init (zenimax.constants is loaded by then).
local CRIT_HEAL, CRIT_HOT

local function is_crit(e)
  local r = e.result
  return r == CRIT_HEAL or r == CRIT_HOT
end

-- Pool acquired event from the engine. Used by both metrics.ingest_* (when
-- the engine hands off an event) and metrics.acquire (when a caller needs
-- to populate a fresh event before calling ingest_*).
function M.acquire_event()
  return event_pool:acquire()
end

function M.release_event(ev)
  event_pool:release(ev)
end

function M.pool_in_use()
  return event_pool:in_use()
end

function M.pool_capacity()
  return event_pool:capacity()
end

-- on_evict for buffers: when an entry leaves a window-trim or capacity
-- overflow, release the underlying pooled event back to the pool.
local function release_to_pool(entry)
  event_pool:release(entry)
end

function M.init()
  W_MS        = 5000
  W_SHIELD_MS = 30000

  local cap   = (Verdant.Constants.POOL and Verdant.Constants.POOL.EVENT_CAPACITY) or 4096
  event_pool  = Verdant.lib.mem.BufferPool.new(Verdant.lib.mem.Event.factory, cap, "event_pool")

  local RingBuffer = Verdant.lib.mem.RingBuffer
  heal_buf     = RingBuffer.new(W_MS,        1024, release_to_pool)
  overheal_buf = RingBuffer.new(W_MS,        1024, release_to_pool)
  shield_buf   = RingBuffer.new(W_SHIELD_MS,  512, release_to_pool)
  damage_buf   = RingBuffer.new(W_MS,        2048, release_to_pool)

  local zc = Verdant.zenimax.constants
  CRIT_HEAL = zc.ACTION_RESULT_CRITICAL_HEAL
  CRIT_HOT  = zc.ACTION_RESULT_HOT_TICK_CRITICAL

  log:info("init: window=", W_MS, "ms shield_window=", W_SHIELD_MS, "ms pool=", cap)
end

function M.set_window(ms)
  W_MS = ms or 5000
  heal_buf.window_ms     = W_MS
  overheal_buf.window_ms = W_MS
  damage_buf.window_ms   = W_MS
  log:info("window ->", W_MS, "ms")
  -- shield window is intentionally independent; use set_shield_window to change it
end

function M.set_shield_window(ms)
  W_SHIELD_MS = ms or 30000
  shield_buf.window_ms = W_SHIELD_MS
  log:info("shield_window ->", W_SHIELD_MS, "ms")
end

function M.window_seconds() return W_MS / 1000 end

-- Ingest a populated VerdantEvent. The event becomes the buffer's owned
-- entry — callers must NOT release it themselves; the buffer's on_evict
-- handles release when the entry trims out of the window.
--
-- For overheal, the engine acquires a separate event and passes it via
-- ingest_overheal. Splitting the two avoids buffer entries needing two
-- amount fields and keeps the heal-vs-overheal selection in the engine.
function M.ingest_heal(ev)
  if ev.amount > 0 then
    heal_buf:push(ev)
  else
    event_pool:release(ev)
  end
end

function M.ingest_overheal(ev)
  if ev.amount > 0 then
    overheal_buf:push(ev)
  else
    event_pool:release(ev)
  end
end

function M.ingest_shield(ev)
  if ev.amount > 0 then
    shield_buf:push(ev)
  else
    event_pool:release(ev)
  end
end

function M.ingest_damage_group(ev)
  if ev.amount > 0 then
    damage_buf:push(ev)
  else
    event_pool:release(ev)
  end
end

local function rate(buf, now_ms, predicate)
  return buf:sum(now_ms, "amount", predicate) / (W_MS / 1000)
end

function M.eHPS(now_ms)    return rate(heal_buf,     now_ms, in_M) end
function M.OHPS(now_ms)    return rate(overheal_buf, now_ms, in_M) end
function M.MPS(now_ms)     return shield_buf:sum(now_ms, "amount", in_M) / (W_SHIELD_MS / 1000) end
function M.D_group(now_ms) return rate(damage_buf,   now_ms, nil)  end

function M.EMS(now_ms)
  return M.eHPS(now_ms) + M.MPS(now_ms)
end

function M.O_self(now_ms)
  return M.eHPS(now_ms) + M.MPS(now_ms) + M.OHPS(now_ms)
end

function M.contribution(now_ms)
  local ems = M.EMS(now_ms)
  local heal_share, shield_share = 0, 0
  if ems > 0 then
    heal_share   = M.eHPS(now_ms) / ems
    shield_share = M.MPS(now_ms)  / ems
  end

  local c, mode_used
  if Verdant.Coverage.is_grouped() then
    local d = M.D_group(now_ms)
    mode_used = "group"
    if d <= 0 then
      c = 0
    else
      local ratio = ems / d
      c = ratio > 1 and 1 or ratio
    end
  else
    local o = M.O_self(now_ms)
    mode_used = "open"
    c = (o > 0) and (ems / o) or 0
  end

  return {
    mode    = mode_used,
    eHPS    = M.eHPS(now_ms),
    MPS     = M.MPS(now_ms),
    OHPS    = M.OHPS(now_ms),
    EMS     = ems,
    D_group = M.D_group(now_ms),
    O_self  = M.O_self(now_ms),
    C_self  = c,
    C_heal  = c * heal_share,
    C_shield = c * shield_share,
  }
end

-- Splits effective healing (eHPS) into its critical and non-critical halves in
-- one pass over the same window/buffer/predicate eHPS uses, so crit + noncrit
-- == eHPS exactly. Only landed (in-M) heals count. Returns (crit_hps, noncrit_hps).
function M.eHPS_crit_split(now_ms)
  heal_buf:trim(now_ms)
  local ws    = W_MS / 1000
  local crit  = 0
  local total = 0
  for i = heal_buf.head, heal_buf.tail do
    local e   = heal_buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 and in_M(e) then
      total = total + amt
      if is_crit(e) then crit = crit + amt end
    end
  end
  crit = crit / ws
  return crit, (total / ws) - crit
end

function M.eHPS_by_group(now_ms)
  return Verdant.SkillColors.group_shares(heal_buf, now_ms, in_M)
end

function M.MPS_by_group(now_ms)
  return Verdant.SkillColors.group_shares(shield_buf, now_ms, in_M)
end

function M.eHPS_by_group_into(out, now_ms)
  return Verdant.SkillColors.group_shares_into(out, heal_buf, now_ms, in_M)
end

function M.MPS_by_group_into(out, now_ms)
  return Verdant.SkillColors.group_shares_into(out, shield_buf, now_ms, in_M)
end

function M.reset()
  log:info("reset: heal=", heal_buf:size(), "overheal=", overheal_buf:size(),
           "shield=", shield_buf:size(), "damage=", damage_buf:size(),
           "pool_in_use=", event_pool:in_use())
  heal_buf:reset()
  overheal_buf:reset()
  shield_buf:reset()
  damage_buf:reset()
end

function M.size_snapshot()
  return {
    heal     = heal_buf:size(),
    overheal = overheal_buf:size(),
    shield   = shield_buf:size(),
    damage   = damage_buf:size(),
  }
end
