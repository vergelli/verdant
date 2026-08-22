SIMLAB_ROOT   = arg[1] or "."
HARNESS_ROOT  = SIMLAB_ROOT
HARNESS_DEBUG = true

local sv_path = arg[2]
local want_svg = false
for i = 3, #arg do
  if arg[i] == "--svg" then want_svg = true end
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
if #events == 0 then os.exit(2) end

local O = make_oracle(H)
local orig_fire = H.fire
H.fire = function(code, ...)
  O.on_fire(code, ...)
  return orig_fire(code, ...)
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

if svg then
  for _ = 1, 4 do
    local view = tostring(VerdantGraphWindowViewLabel._text or "view"):lower()
    local out = SIMLAB_ROOT .. "/test/simlab/out/replay_" .. view .. ".svg"
    svg.snapshot(H, VerdantGraphWindow, out)
    print("  svg -> " .. out)
    Verdant.Graph.next_view()
  end
end

os.exit(O.fails == 0 and 0 or 1)
