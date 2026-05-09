-- observability/validation.lua
--
-- Invariant checks. Debug-only and intentionally heavyweight — they're
-- placed at boundaries (pool acquire/release, ZOS event entry, savedvars
-- migration) and run only when DEBUG=true. Failures log via log.write
-- and surface to chat in debug mode; they do not crash the addon.
--
-- Per SPEC_04 §6: load-time DEBUG decision (no runtime branch) — release
-- swaps every check to a no-op.

Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Validation = {}
local M = Verdant.Validation

local DEBUG = Verdant.Constants.DEBUG

local NOOP = function() end

-- ── pool balance tracking ────────────────────────────────────────────────
-- We keep a per-pool set of outstanding _pool_idx values. acquire adds,
-- release removes. /verdant validate dumps any leaked indices.

local outstanding = {}  -- [pool_label] = { [pool_idx] = true }
local failures    = {}  -- chronological list of failure records

local function record_failure(check, details)
  failures[#failures+1] = {
    t       = Verdant.zenimax.api.GetGameTimeMilliseconds(),
    check   = check,
    details = details,
  }
  if Verdant.Log and Verdant.Log.write then
    Verdant.Log.write("error", "validation." .. check, details)
  end
end

local function real_pool_acquired(label, rec)
  if not rec or not rec._pool_idx then return end
  local s = outstanding[label]
  if not s then s = {}; outstanding[label] = s end
  if s[rec._pool_idx] then
    record_failure("pool.double_acquire",
      { pool = label, pool_idx = rec._pool_idx })
  end
  s[rec._pool_idx] = true
end

local function real_pool_released(label, rec)
  if not rec or not rec._pool_idx then return end
  local s = outstanding[label]
  if not s or not s[rec._pool_idx] then
    record_failure("pool.released_unowned",
      { pool = label, pool_idx = rec and rec._pool_idx })
    return
  end
  s[rec._pool_idx] = nil
end

local function real_check_pool_balanced(label)
  local s = outstanding[label]
  local count = 0
  if s then for _ in pairs(s) do count = count + 1 end end
  return count
end

-- ── monotonic clock check ────────────────────────────────────────────────
local function real_check_monotonic_clock(prev_t, cur_t, where)
  if cur_t < prev_t then
    record_failure("clock.regression",
      { prev = prev_t, cur = cur_t, where = where })
  end
end

-- ── ring buffer sanity ───────────────────────────────────────────────────
local function real_check_ring_sane(ring, label)
  if not ring or not ring.head or not ring.tail or not ring.capacity then
    record_failure("ring.shape", { label = label })
    return
  end
  local size = ring.tail - ring.head + 1
  if size < 0 or size > ring.capacity then
    record_failure("ring.size_out_of_bounds",
      { label = label, head = ring.head, tail = ring.tail, capacity = ring.capacity })
  end
end

-- ── payload shape check ──────────────────────────────────────────────────
-- Compares actual keys to expected_keys (a set: { foo = true, bar = true }).
-- Reports both missing and unexpected keys.
local function real_check_payload_shape(payload, expected_keys, label)
  if type(payload) ~= "table" then
    record_failure("payload.not_table", { label = label })
    return
  end
  for k in pairs(expected_keys) do
    if payload[k] == nil then
      record_failure("payload.missing_key", { label = label, key = k })
    end
  end
  for k in pairs(payload) do
    if not expected_keys[k] and not tostring(k):match("^_") then
      record_failure("payload.unexpected_key", { label = label, key = k })
    end
  end
end

-- ── reports / commands ───────────────────────────────────────────────────
local function real_run_all_checks()
  -- Pool balance dump for the event pool (only one pool today).
  local leaked_count = 0
  for label, s in pairs(outstanding) do
    local n = 0
    for _ in pairs(s) do n = n + 1 end
    if n > 0 then leaked_count = leaked_count + n end
    if Verdant.Log and Verdant.Log.write then
      Verdant.Log.write("info", "validation.pool_outstanding",
        { pool = label, outstanding = n })
    end
  end
  return {
    failure_count    = #failures,
    pool_outstanding = leaked_count,
    failures         = failures,
  }
end

local function real_dump_to_chat()
  local r = real_run_all_checks()
  local d = d
  d(string.format("[validate] failures=%d  pool_outstanding=%d",
    r.failure_count, r.pool_outstanding))
  -- Show last 10 failures.
  local n_show = math.min(#failures, 10)
  for i = #failures - n_show + 1, #failures do
    local f = failures[i]
    if f then
      d(string.format("  t=%d %s %s", f.t, f.check, tostring(f.details)))
    end
  end
  if Verdant.CopyBox and Verdant.CopyBox.show then
    local lines = { string.format("[validate] failures=%d  pool_outstanding=%d",
      r.failure_count, r.pool_outstanding) }
    for _, f in ipairs(failures) do
      local detail_str = ""
      if type(f.details) == "table" then
        local parts = {}
        for k, v in pairs(f.details) do
          parts[#parts+1] = tostring(k) .. "=" .. tostring(v)
        end
        detail_str = table.concat(parts, " ")
      else
        detail_str = tostring(f.details)
      end
      lines[#lines+1] = string.format("  t=%d %s  %s", f.t, f.check, detail_str)
    end
    Verdant.CopyBox.show("Verdant /validate", table.concat(lines, "\n"))
  end
end

local function real_reset()
  outstanding = {}
  failures    = {}
end

-- ── public surface ────────────────────────────────────────────────────────
if DEBUG then
  M.pool_acquired         = real_pool_acquired
  M.pool_released         = real_pool_released
  M.check_pool_balanced   = real_check_pool_balanced
  M.check_monotonic_clock = real_check_monotonic_clock
  M.check_ring_sane       = real_check_ring_sane
  M.check_payload_shape   = real_check_payload_shape
  M.run_all_checks        = real_run_all_checks
  M.dump_to_chat          = real_dump_to_chat
  M.reset                 = real_reset
else
  M.pool_acquired         = NOOP
  M.pool_released         = NOOP
  M.check_pool_balanced   = function() return 0 end
  M.check_monotonic_clock = NOOP
  M.check_ring_sane       = NOOP
  M.check_payload_shape   = NOOP
  M.run_all_checks        = function() return { failure_count = 0, pool_outstanding = 0, failures = {} } end
  M.dump_to_chat          = function() d("[validate] disabled (DEBUG=false)") end
  M.reset                 = NOOP
end
