-- observability/profiler.lua
--
-- Per-stage timing with negligible release-mode overhead. Decision is
-- baked at load time: if DEBUG=false the public functions are no-ops
-- with no branch and no work. Callers may locally cache them.
--
-- Per SPEC_04 §5: enter/exit balance via stack; mismatches log to
-- log.write("error", "profiler.unbalanced"). Time source is the only
-- millisecond clock available (zenimax.api.GetGameTimeMilliseconds);
-- sub-ms stages will report 0 most of the time — that's fine, what
-- matters is catching spikes.

Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Profiler = {}
local M = Verdant.Profiler

local DEBUG = Verdant.Constants.DEBUG

local now_ms = Verdant.zenimax.api.GetGameTimeMilliseconds

-- ── histograms ────────────────────────────────────────────────────────────
-- One histogram per stage name. We use a fixed-bin approach (logarithmic
-- buckets in ms) plus running totals: cheap, no allocation per sample.

local BUCKET_BOUNDS = { 0, 1, 2, 4, 8, 16, 32, 64, 128, 256 }
local BUCKET_COUNT  = #BUCKET_BOUNDS

local function new_histogram()
  local h = {
    count   = 0,
    total   = 0,
    max     = 0,
    buckets = {},  -- buckets[i] = count of samples in [BUCKET_BOUNDS[i], BUCKET_BOUNDS[i+1])
  }
  for i = 1, BUCKET_COUNT do h.buckets[i] = 0 end
  return h
end

local function bucket_for(ms)
  -- linear scan; small N, faster than binary search at this scale
  for i = BUCKET_COUNT, 1, -1 do
    if ms >= BUCKET_BOUNDS[i] then return i end
  end
  return 1
end

local function percentile(h, p)
  if h.count == 0 then return 0 end
  local target = h.count * p
  local cum = 0
  for i = 1, BUCKET_COUNT do
    cum = cum + h.buckets[i]
    if cum >= target then return BUCKET_BOUNDS[i] end
  end
  return BUCKET_BOUNDS[BUCKET_COUNT]
end

-- ── state ─────────────────────────────────────────────────────────────────
local stages       = {}    -- [stage_name] = histogram
local enter_stack  = {}    -- stack of { name, t0 }
local stack_top    = 0
local started_at   = 0

-- ── implementations ──────────────────────────────────────────────────────
local function real_enter(name)
  stack_top = stack_top + 1
  local frame = enter_stack[stack_top]
  if not frame then
    frame = {}
    enter_stack[stack_top] = frame
  end
  frame.name = name
  frame.t0   = now_ms()
end

local function real_exit(name)
  if stack_top == 0 then
    if Verdant.Log and Verdant.Log.write then
      Verdant.Log.write("error", "profiler.unbalanced", { exit = name, stack_top = 0 })
    end
    return
  end
  local frame = enter_stack[stack_top]
  if frame.name ~= name then
    if Verdant.Log and Verdant.Log.write then
      Verdant.Log.write("error", "profiler.unbalanced",
        { expected = frame.name, got = name })
    end
    -- Pop anyway to recover.
    stack_top = stack_top - 1
    return
  end
  local dt = now_ms() - frame.t0
  stack_top = stack_top - 1

  local h = stages[name]
  if not h then
    h = new_histogram()
    stages[name] = h
  end
  h.count = h.count + 1
  h.total = h.total + dt
  if dt > h.max then h.max = dt end
  h.buckets[bucket_for(dt)] = h.buckets[bucket_for(dt)] + 1

  -- Budget check (rate-limited via log key).
  local budgets = Verdant.Constants.PROFILER_BUDGETS_MS
  local budget  = budgets and budgets[name]
  if budget and dt > budget then
    if Verdant.Log and Verdant.Log.write then
      Verdant.Log.write("warn", "profiler.budget_exceeded",
        { stage = name, dt_ms = dt, budget_ms = budget })
    end
  end
end

local function real_span(name, fn, ...)
  real_enter(name)
  local ok, ret = pcall(fn, ...)
  real_exit(name)
  if not ok then error(ret) end
  return ret
end

local function real_reset()
  stages = {}
  stack_top = 0
  started_at = now_ms()
end

local function real_report()
  local r = {}
  for name, h in pairs(stages) do
    r[name] = {
      count = h.count,
      total_ms = h.total,
      avg_ms = h.count > 0 and (h.total / h.count) or 0,
      max_ms = h.max,
      p50    = percentile(h, 0.50),
      p95    = percentile(h, 0.95),
      p99    = percentile(h, 0.99),
    }
  end
  return r, (now_ms() - started_at) / 1000
end

local function real_dump_to_chat()
  local r, window_s = real_report()
  local d = d
  d(string.format("[prof] window: %.1f sec", window_s))
  -- sort by total_ms desc for visibility
  local names = {}
  for k in pairs(r) do names[#names+1] = k end
  table.sort(names, function(a, b) return r[a].total_ms > r[b].total_ms end)
  for _, name in ipairs(names) do
    local s = r[name]
    d(string.format("  %s  count=%d p50=%d p95=%d p99=%d max=%d total=%d",
      name, s.count, s.p50, s.p95, s.p99, s.max_ms, s.total_ms))
  end
  -- Also dump to CopyBox if available (DEBUG implies CopyBox).
  if Verdant.CopyBox and Verdant.CopyBox.show then
    local lines = { string.format("[prof] window: %.1f sec", window_s) }
    for _, name in ipairs(names) do
      local s = r[name]
      lines[#lines+1] = string.format("  %s  count=%d p50=%d p95=%d p99=%d max=%d total=%d",
        name, s.count, s.p50, s.p95, s.p99, s.max_ms, s.total_ms)
    end
    Verdant.CopyBox.show("Verdant /prof", table.concat(lines, "\n"))
  end
end

-- ── public surface (load-time bound) ─────────────────────────────────────
local NOOP = function() end

if DEBUG then
  M.enter         = real_enter
  M.exit          = real_exit
  M.span          = real_span
  M.report        = real_report
  M.dump_to_chat  = real_dump_to_chat
  M.reset         = real_reset
  started_at = now_ms()
else
  -- Span still needs to call fn so the program keeps working in release.
  M.enter         = NOOP
  M.exit          = NOOP
  M.span          = function(_name, fn, ...) return fn(...) end
  M.report        = function() return {}, 0 end
  M.dump_to_chat  = function() d("[prof] disabled (DEBUG=false)") end
  M.reset         = NOOP
end
