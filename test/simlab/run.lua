SIMLAB_ROOT   = arg[1] or "."
HARNESS_ROOT  = SIMLAB_ROOT
HARNESS_DEBUG = true

local only, want_svg = nil, false
for i = 2, #arg do
  if arg[i] == "--svg" then want_svg = true else only = arg[i] end
end

dofile(SIMLAB_ROOT .. "/test/harness/mock_eso.lua")

local svg = want_svg and dofile(SIMLAB_ROOT .. "/test/simlab/svg.lua") or nil
if svg then svg.apply_xml(SIMLAB_ROOT .. "/ui/graph.xml") end

dofile(SIMLAB_ROOT .. "/test/harness/loader.lua")
HARNESS.fire(EVENT_ADD_ON_LOADED, "Verdant")

local H            = HARNESS
local Prng         = dofile(SIMLAB_ROOT .. "/test/simlab/prng.lua")
local make_engine  = dofile(SIMLAB_ROOT .. "/test/simlab/engine.lua")
local make_oracle  = dofile(SIMLAB_ROOT .. "/test/simlab/oracle.lua")
local Engine       = make_engine(H, Prng)

local SCENARIOS = { "trial_boss", "dungeon_pull", "burst" }

local function reset_world()
  Verdant.Graph.on_flush_click()
  Verdant.TemporalBuffer.clear()
  Verdant.Metrics.reset()
  Verdant.ShieldRegistry.reset()
  Verdant.Coverage.reset()
  Verdant.GroupSet.reset()
  Verdant.Diagnostics.reset()
  Verdant.BuffTracker.reset()
  H.state.grouped = false
  H.state.group_size = 1
  H.state.in_combat = false
  H.state.bosses = {}
  H.clear_chat()
end

local total_fail = 0

for _, name in ipairs(SCENARIOS) do
  if not only or only == name then
    local spec = dofile(SIMLAB_ROOT .. "/test/simlab/scenarios/" .. name .. ".lua")
    reset_world()

    local O = make_oracle(H)
    local orig_fire = H.fire
    H.fire = function(code, ...)
      O.on_fire(code, ...)
      return orig_fire(code, ...)
    end

    local sim = Engine.new({ seed = spec.seed })
    sim.oracle = O
    sim:group(spec.group)
    if svg then Verdant.Visibility.set("graph", true) end
    if spec.record then Verdant.Graph.on_record_click() end
    spec.build(sim, H)

    local t0 = os.clock()
    local r = sim:run(spec.duration)
    local wall = os.clock() - t0

    local triage
    if spec.record then
      Verdant.Graph.on_stop_click()
      triage = O.triage_check(H.now())
    end
    H.fire = orig_fire

    local pool_exhausted = Verdant.Diagnostics.get("engine.pool.exhausted")
    local ok = (O.fails == 0) and (pool_exhausted == 0)
    if not ok then total_fail = total_fail + 1 end

    print(string.format(
      "%s  %-14s sim=%ds actions=%d checks=%d max_rel_err=%.2e events[h=%d o=%d s=%d d=%d] wall=%.2fs",
      ok and "PASS" or "FAIL", spec.name, spec.duration / 1000, r.actions, O.checks,
      r.max_rel_err, r.events.heals, r.events.overheals, r.events.shields, r.events.damage, wall))
    if triage then
      print(string.format(
        "      triage: episodes=%d S=%d (S*=%d) O=%d L=%d M=%d X=%d oneshot=%d RT50=%dms RT95=%dms",
        triage.episodes, triage.counts.s, triage.counts.s_star, triage.counts.o,
        triage.counts.l, triage.counts.m, triage.counts.x, triage.counts.oneshot,
        triage.rt50, triage.rt95))
    end
    if pool_exhausted > 0 then
      print("      pool exhausted " .. pool_exhausted .. " times")
    end
    for _, line in ipairs(r.fail_lines) do print("      " .. line) end

    local s = Verdant.TemporalBuffer.summary()
    if s.count > 0 then
      print(string.format(
        "      samples=%d dur=%.0fs avg_ems=%.0f peak_ems=%.0f crit=%.0f%% active=%.0f%%",
        s.count, s.dur_ms / 1000, s.avg_ems, s.peak_ems, s.crit_pct * 100, s.active_pct * 100))
    end

    if svg then
      for _ = 1, 6 do
        local view = tostring(VerdantGraphWindowViewLabel._text or "view")
        local out = SIMLAB_ROOT .. "/test/simlab/out/" .. spec.name .. "_" .. view:lower() .. ".svg"
        svg.snapshot(H, VerdantGraphWindow, out)
        print("      svg -> " .. out)
        Verdant.Graph.next_view()
      end
    end
  end
end

os.exit(total_fail == 0 and 0 or 1)
