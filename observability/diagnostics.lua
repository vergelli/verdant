Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Diagnostics = {}
local M = Verdant.Diagnostics

local GetGameTimeMilliseconds = Verdant.zenimax.api.GetGameTimeMilliseconds
local d           = d
local pairs       = pairs
local tostring    = tostring
local math_min    = math.min
local table_sort  = table.sort

-- ── config ────────────────────────────────────────────────────────────────
local EVENT_CAP   = 200   -- ring buffer capacity for discrete events
local TS_CAP      = 120   -- timeseries samples (1 Hz → 2 min of history)
local TICK_MS     = 1000  -- sample interval

-- ── state ─────────────────────────────────────────────────────────────────
local counters    = {}    -- [key:string] = number
local ev_buf      = {}    -- ring of { t, cat, payload }
local ev_head     = 0     -- next write index (1-based, wraps)
local ev_count    = 0     -- total events ever logged (for overflow detection)
local ts_buf      = {}    -- ring of { t, snap }
local ts_head     = 0
local ts_count    = 0
local start_time  = 0

-- ── counters ──────────────────────────────────────────────────────────────
function M.bump(key, n)
  counters[key] = (counters[key] or 0) + (n or 1)
end

function M.get(key)
  return counters[key] or 0
end

-- ── event log ─────────────────────────────────────────────────────────────
function M.log_event(cat, payload)
  ev_head = (ev_head % EVENT_CAP) + 1
  ev_buf[ev_head] = { t = GetGameTimeMilliseconds(), cat = cat, p = payload }
  ev_count = ev_count + 1
end

-- ── timeseries ────────────────────────────────────────────────────────────
local function ts_sample()
  local snap = {
    t      = GetGameTimeMilliseconds(),
    -- engine ingestion totals
    heals  = counters["engine.heal.accepted"]      or 0,
    shields= counters["engine.shield.accepted"]    or 0,
    dmg    = counters["engine.damage.accepted"]    or 0,
    -- groupset size
    grp_sz = Verdant.GroupSet and Verdant.GroupSet.size() or 0,
    -- live metric snapshot (contribution summary)
    metric = (function()
      if not Verdant.Metrics then return nil end
      local ok, r = pcall(Verdant.Metrics.contribution, GetGameTimeMilliseconds())
      if ok then return { eHPS=r.eHPS, MPS=r.MPS, EMS=r.EMS } end
      return nil
    end)(),
  }
  ts_head = (ts_head % TS_CAP) + 1
  ts_buf[ts_head] = snap
  ts_count = ts_count + 1
end

-- ── snapshot (for SavedVars) ───────────────────────────────────────────────
function M.snapshot()
  -- ordered copy of event ring (oldest → newest)
  local events = {}
  if ev_count <= EVENT_CAP then
    for i = 1, ev_count do events[i] = ev_buf[i] end
  else
    -- ring has wrapped; start from ev_head+1 (oldest)
    local n = 0
    for i = 1, EVENT_CAP do
      local idx = (ev_head - 1 + i) % EVENT_CAP + 1
      n = n + 1
      events[n] = ev_buf[idx]
    end
  end

  -- ordered timeseries
  local ts = {}
  local ts_len = math.min(ts_count, TS_CAP)
  if ts_count <= TS_CAP then
    for i = 1, ts_count do ts[i] = ts_buf[i] end
  else
    local n = 0
    for i = 1, TS_CAP do
      local idx = (ts_head - 1 + i) % TS_CAP + 1
      n = n + 1
      ts[n] = ts_buf[idx]
    end
  end

  -- module snapshots
  local group_snap    = Verdant.GroupSet     and Verdant.GroupSet.snapshot()     or {}
  local coverage_snap = Verdant.Coverage     and Verdant.Coverage.snapshot()     or {}
  local shield_snap   = Verdant.ShieldRegistry and Verdant.ShieldRegistry.snapshot() or {}
  local mode_snap     = Verdant.Mode         and Verdant.Mode.snapshot()         or {}

  return {
    start_time  = start_time,
    counters    = counters,
    events      = events,
    ev_total    = ev_count,
    timeseries  = ts,
    ts_total    = ts_count,
    group       = group_snap,
    coverage    = coverage_snap,
    shield_reg  = shield_snap,
    mode        = mode_snap,
  }
end

-- ── diag dump (/verdant diag) ─────────────────────────────────────────────
-- In DEBUG, output goes to the CopyBox (selectable / copyable). Otherwise
-- chat output as before. The CopyBox itself also no-ops outside DEBUG.
local function build_diag_lines()
  local lines = {}
  lines[#lines+1] = "[V:diag] uptime=" .. (GetGameTimeMilliseconds() - start_time)
                    .. "ms  ev_total=" .. ev_count .. "  ts_samples=" .. ts_count
  lines[#lines+1] = "[V:diag] counters:"
  local keys = {}
  for k in pairs(counters) do keys[#keys+1] = k end
  table_sort(keys)
  for _, k in ipairs(keys) do
    lines[#lines+1] = "  " .. k .. " = " .. tostring(counters[k])
  end
  lines[#lines+1] = "[V:diag] last events (up to 10):"
  local n_show = math_min(ev_count, 10)
  local base   = math_min(ev_count, EVENT_CAP)
  for i = base - n_show + 1, base do
    local idx = (ev_head - base + i - 1 + EVENT_CAP) % EVENT_CAP + 1
    local e = ev_buf[idx]
    if e then
      lines[#lines+1] = "  t=" .. e.t .. " [" .. (e.cat or "?") .. "] " .. tostring(e.p)
    end
  end
  if Verdant.Mode then
    lines[#lines+1] = "[V:diag] mode=" .. tostring(Verdant.Mode.current())
  end
  if Verdant.GroupSet then
    lines[#lines+1] = "[V:diag] group_set.size=" .. Verdant.GroupSet.size()
  end
  if Verdant.Metrics and Verdant.Metrics.pool_capacity then
    lines[#lines+1] = "[V:diag] event_pool=" .. Verdant.Metrics.pool_in_use()
                      .. "/" .. Verdant.Metrics.pool_capacity()
  end
  return lines
end

function M.print_diag()
  local lines = build_diag_lines()
  if Verdant.Constants.DEBUG and Verdant.CopyBox then
    Verdant.CopyBox.show("Verdant /diag", table.concat(lines, "\n"))
  else
    for _, line in ipairs(lines) do d(line) end
  end
end

-- ── reset ─────────────────────────────────────────────────────────────────
function M.reset()
  counters = {}
  ev_buf   = {}
  ev_head  = 0
  ev_count = 0
  ts_buf   = {}
  ts_head  = 0
  ts_count = 0
  start_time = GetGameTimeMilliseconds()
end

-- ── init ──────────────────────────────────────────────────────────────────
function M.init()
  start_time = GetGameTimeMilliseconds()
  Verdant.zenimax.events.register_update("Verdant_DiagTick", TICK_MS, ts_sample)
end
