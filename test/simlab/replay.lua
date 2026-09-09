SIMLAB_ROOT   = arg[1] or "."
HARNESS_ROOT  = SIMLAB_ROOT
HARNESS_DEBUG = true

local sv_path = arg[2]
local want_svg = false
local force_window, force_rate = nil, nil
for i = 3, #arg do
  if arg[i] == "--svg" then want_svg = true end
  local w = arg[i]:match("^%-%-window=(%d+)$")
  if w then force_window = tonumber(w) end
  local r = arg[i]:match("^%-%-rate=(%d+)$")
  if r then force_rate = tonumber(r) end
end
if not sv_path then
  print("usage: lua test/simlab/replay.lua <root> <path/to/SavedVariables/Verdant.lua> [--svg]")
  os.exit(2)
end

dofile(SIMLAB_ROOT .. "/test/harness/mock_eso.lua")

local svg = want_svg and dofile(SIMLAB_ROOT .. "/test/simlab/svg.lua") or nil
if svg then svg.apply_xml(SIMLAB_ROOT .. "/ui/graph.xml") end

dofile(SIMLAB_ROOT .. "/test/harness/loader.lua")
HARNESS.fire(EVENT_ADD_ON_LOADED, "Verdant")

local H           = HARNESS
local codec       = dofile(SIMLAB_ROOT .. "/test/simlab/tracecodec.lua")
local make_oracle = dofile(SIMLAB_ROOT .. "/test/simlab/oracle.lua")

dofile(sv_path)
local sv_root = VerdantSavedVars
if not sv_root then
  print("VerdantSavedVars not found in " .. sv_path)
  os.exit(2)
end

local trace
local function find_trace(t, depth)
  if type(t) ~= "table" or depth > 8 or trace then return end
  if type(t.trace) == "table" and t.trace.chunks then
    trace = t.trace
    return
  end
  for _, v in pairs(t) do
    if type(v) == "table" then find_trace(v, depth + 1) end
  end
end
find_trace(sv_root, 0)
if not trace then
  print("no trace node with chunks found in " .. sv_path)
  os.exit(2)
end

local events = codec.decode_chunks(trace.chunks)
print(string.format("replay: %d events  trace_build=%s  world=%s",
  #events, tostring(trace.build), tostring(trace.world)))

if trace.constants then
  local drift = 0
  for k, v in pairs(trace.constants) do
    if k ~= "API_VERSION" then
      local mv = rawget(_G, k)
      if mv ~= v then
        drift = drift + 1
        print(string.format("  const mismatch: %-34s live=%s  mock=%s", k, tostring(v), tostring(mv)))
      end
    end
  end
  print(string.format("constants: api=%s  mismatches=%d",
    tostring(trace.constants.API_VERSION), drift))
end
if #events == 0 then os.exit(2) end

local O = make_oracle(H)
local orig_fire = H.fire
H.fire = function(code, ...)
  O.on_fire(code, ...)
  return orig_fire(code, ...)
end

do
  local ts = trace.settings or {}
  local window = force_window or ts.time_window_s
  local rate   = force_rate or ts.sample_rate_ms
  if window or rate then
    local sv = Verdant.SavedVars
    sv.temporal = sv.temporal or {}
    sv.temporal.time_window_s  = window or sv.temporal.time_window_s or 60
    sv.temporal.sample_rate_ms = rate or sv.temporal.sample_rate_ms or 1000
    local hz = math.floor(1000 / sv.temporal.sample_rate_ms)
    Verdant.TemporalBuffer.init(sv.temporal.time_window_s * hz)
    print(string.format("settings: window=%ds  rate=%dms  (%s)",
      sv.temporal.time_window_s, sv.temporal.sample_rate_ms,
      (force_window or force_rate) and "from arguments" or "recorded with the trace"))
  else
    print("settings: window=60s  rate=1000ms  (trace carries none, harness defaults)")
  end
end

if svg then Verdant.Visibility.set("graph", true) end
Verdant.Graph.on_record_click()

local offset = events[1].t - H.now()
local next_check = H.now() + 250
local t0_wall = os.clock()

for _, e in ipairs(events) do
  local target = e.t - offset
  while next_check <= target do
    if next_check > H.now() then H.advance(next_check - H.now()) end
    O.check(H.now())
    next_check = next_check + 250
  end
  if target > H.now() then H.advance(target - H.now()) end
  codec.fire(H, e)
end
O.check(H.now())
local wall = os.clock() - t0_wall

Verdant.Graph.on_stop_click()
H.fire = orig_fire

local D = Verdant.Diagnostics
print(string.format(
  "engine: heal_acc=%d shield_acc=%d dmg_acc=%d shield_foreign=%d dmg_foreign=%d pool_exhausted=%d",
  D.get("engine.heal.accepted"), D.get("engine.shield.accepted"),
  D.get("engine.damage.accepted"), D.get("engine.shield.foreign"),
  D.get("engine.damage.not_in_groupset"), D.get("engine.pool.exhausted")))

if Verdant.Triage then
  local ps = Verdant.Triage.power_stats()
  local ts = Verdant.Triage.summary()
  print(string.format(
    "triage: power_updates=%d rate=%.1f/s heals matched=%d unmatched=%d",
    ps.count, ps.rate, ps.matched, ps.unmatched))
  print(string.format(
    "triage: episodes=%d S=%d (S*=%d) O=%d L=%d M=%d X=%d oneshot=%d RT50=%dms RT95=%dms",
    ts.episodes, ts.counts.s, ts.counts.s_star, ts.counts.o, ts.counts.l,
    ts.counts.m, ts.counts.x, ts.counts.oneshot, ts.rt50, ts.rt95))
end

local s = Verdant.TemporalBuffer.summary()
if s.count > 0 then
  print(string.format(
    "session: samples=%d dur=%.0fs avg_ems=%.0f peak_ems=%.0f crit=%.0f%% active=%.0f%%",
    s.count, s.dur_ms / 1000, s.avg_ems, s.peak_ems, s.crit_pct * 100, s.active_pct * 100))
end

print(string.format(
  "oracle: checks=%d divergences=%d max_rel_err=%.2e  wall=%.2fs",
  O.checks, O.fails, O.max_rel_err, wall))
for _, line in ipairs(O.fail_lines) do print("  " .. line) end

local numeric_fail = {}
do
  local TB = Verdant.TemporalBuffer
  local n = TB.count()
  local grouped = H.state.grouped and (H.state.group_size or 0) > 1
  local function in_m(e)
    if not grouped then return true end
    return e.tt == COMBAT_UNIT_TYPE_PLAYER or e.tt == COMBAT_UNIT_TYPE_GROUP
        or e.tt == COMBAT_UNIT_TYPE_PLAYER_PET
  end
  local times = {}
  for i = 1, n do times[i] = TB.at(i).t end
  local function integral_expected(list, W_ms)
    local raw, expected = 0, 0
    for _, e in ipairs(list) do
      if in_m(e) then
        raw = raw + e.amount
        local w = 0
        for i = 2, n do
          local ti = times[i]
          if ti - W_ms < e.t and e.t <= ti then
            w = w + (ti - times[i - 1]) / W_ms
          end
        end
        expected = expected + e.amount * w
      end
    end
    return raw, expected
  end
  local W  = Verdant.Metrics.window_seconds() * 1000
  local WS = Verdant.Metrics.shield_window_seconds() * 1000
  local heal_raw, heal_exp = integral_expected(O.heals, W)
  local sh_raw, sh_exp = integral_expected(O.shields, WS)
  local function rel(got, want)
    local denom = (math.abs(want) > 1) and math.abs(want) or 1
    return math.abs(got - want) / denom
  end
  local heal_rel = rel(s.total_heal, heal_exp)
  local sh_rel = rel(s.total_shield, sh_exp)
  if heal_rel > 1e-6 then numeric_fail[#numeric_fail + 1] = string.format("heal integral off by %.2e", heal_rel) end
  if sh_rel > 1e-6 then numeric_fail[#numeric_fail + 1] = string.format("shield integral off by %.2e", sh_rel) end

  local shares_bad, ticks_bad, id0 = 0, 0, 0
  local function check_shares(list)
    local sum = 0
    for k = 1, (list.count or 0) do
      local ab = list[k]
      sum = sum + (ab.share or 0)
      if ab.id == 0 then id0 = id0 + 1 end
    end
    return math.abs(sum - 1) < 1e-6
  end
  for i = 1, n do
    local smp = TB.at(i)
    if smp.eHPS > 0 then
      if not check_shares(smp.ehps_abilities) or not check_shares(smp.ehps_groups) then shares_bad = shares_bad + 1 end
    end
    if smp.MPS > 0 then
      if not check_shares(smp.mps_abilities) or not check_shares(smp.mps_groups) then shares_bad = shares_bad + 1 end
    end
    if i > 1 then
      local dt = smp.t - times[i - 1]
      local rate = Verdant.SavedVars.temporal and Verdant.SavedVars.temporal.sample_rate_ms or 1000
      if dt <= 0 or dt < rate * 0.5 or dt > rate * 1.5 then ticks_bad = ticks_bad + 1 end
    end
  end
  if shares_bad > 0 then numeric_fail[#numeric_fail + 1] = shares_bad .. " ticks whose shares do not sum to one" end
  if ticks_bad > 0 then numeric_fail[#numeric_fail + 1] = ticks_bad .. " ticks off the sample rate" end
  local unmatched = Verdant.Triage and Verdant.Triage.power_stats().unmatched or 0
  if unmatched > 0 then numeric_fail[#numeric_fail + 1] = unmatched .. " heals the triage could not match" end

  print(string.format(
    "numeric: heal events=%.0f expected=%.0f integral=%.0f rel=%.1e | shield events=%.0f expected=%.0f integral=%.0f rel=%.1e | shares_bad=%d ticks_bad=%d id0=%d unmatched=%d",
    heal_raw, heal_exp, s.total_heal, heal_rel, sh_raw, sh_exp, s.total_shield, sh_rel,
    shares_bad, ticks_bad, id0, unmatched))
  if #numeric_fail == 0 then
    print("NUMERIC: ok")
  else
    print("NUMERIC: FAIL " .. table.concat(numeric_fail, "; "))
  end
end

if svg then
  for _ = 1, 7 do
    local view = tostring(VerdantGraphWindowViewLabel._text or "view"):lower()
    local out = SIMLAB_ROOT .. "/test/simlab/out/replay_" .. view .. ".svg"
    svg.snapshot(H, VerdantGraphWindow, out)
    print("  svg -> " .. out)
    Verdant.Graph.next_view()
  end
end

os.exit((O.fails == 0 and #numeric_fail == 0) and 0 or 1)
