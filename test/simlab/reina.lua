SIMLAB_ROOT   = arg[1] or "."
HARNESS_ROOT  = SIMLAB_ROOT
HARNESS_DEBUG = true

dofile(SIMLAB_ROOT .. "/test/harness/mock_eso.lua")
local svg = dofile(SIMLAB_ROOT .. "/test/simlab/svg.lua")
svg.apply_xml(SIMLAB_ROOT .. "/ui/graph.xml")
dofile(SIMLAB_ROOT .. "/test/harness/loader.lua")
HARNESS.fire(EVENT_ADD_ON_LOADED, "Verdant")

local H           = HARNESS
local Prng        = dofile(SIMLAB_ROOT .. "/test/simlab/prng.lua")
local make_engine = dofile(SIMLAB_ROOT .. "/test/simlab/engine.lua")
local Engine      = make_engine(H, Prng)

Verdant.SavedVars.settings.session_autosave = true
Verdant.SavedVars.settings.group_death_markers = true

local spec = dofile(SIMLAB_ROOT .. "/test/simlab/scenarios/trial_boss.lua")
local sim = Engine.new({ seed = spec.seed })
sim:group(spec.group)
Verdant.Visibility.set("graph", true)
Verdant.Graph.on_record_click()
spec.build(sim, H)
sim:run(spec.duration)
Verdant.Graph.on_stop_click()

if Verdant.SessionStore.count() ~= 1 then
  print("FAIL reina: session not autosaved")
  os.exit(1)
end

local canvas = VerdantGraphWindowViewportCanvas
local VIEWS = { "EMS", "SKILL", "CRIT", "BUFFS", "TRIAGE" }
local function goto_view(name)
  local guard = 0
  while VerdantGraphWindowViewLabel._text ~= name and guard < 8 do
    Verdant.Graph.next_view()
    guard = guard + 1
  end
end

local live = {}
for _, v in ipairs(VIEWS) do
  goto_view(v)
  local path = SIMLAB_ROOT .. "/test/simlab/out/reina_live_" .. v:lower() .. ".svg"
  svg.snapshot(H, canvas, path)
  live[v] = path
end

Verdant.Graph.on_flush_click()
goto_view("EMS")

local sess = Verdant.SessionStore.get(1)
if not Verdant.Graph.load_session(sess) then
  print("FAIL reina: load_session refused")
  os.exit(1)
end

local total_fail = 0
for _, v in ipairs(VIEWS) do
  goto_view(v)
  local path = SIMLAB_ROOT .. "/test/simlab/out/reina_loaded_" .. v:lower() .. ".svg"
  svg.snapshot(H, canvas, path)

  local a, b = {}, {}
  for line in io.lines(live[v]) do a[#a + 1] = line end
  for line in io.lines(path) do b[#b + 1] = line end
  local diff = 0
  local n = math.max(#a, #b)
  for i = 1, n do
    if a[i] ~= b[i] then diff = diff + 1 end
  end
  local pct = (n > 0) and (diff / n * 100) or 0
  local verdict
  if v == "SKILL" then
    verdict = "SKIP (v1: sin shares por grupo)"
  elseif diff == 0 then
    verdict = "IDENTICAL"
  elseif pct <= 1.0 then
    verdict = string.format("OK (%d/%d lineas difieren, %.2f%%)", diff, n, pct)
  else
    verdict = string.format("FAIL (%d/%d lineas difieren, %.2f%%)", diff, n, pct)
    total_fail = total_fail + 1
  end
  print(string.format("reina %-7s live=%4d loaded=%4d lineas  %s", v, #a, #b, verdict))
end

os.exit(total_fail == 0 and 0 or 1)
