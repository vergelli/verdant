HARNESS_ROOT  = arg[1] or "."
HARNESS_DEBUG = (arg[2] == "1")
local TICKS   = tonumber(arg[3]) or 40
local DETAIL  = arg[4]

dofile(HARNESS_ROOT .. "/test/harness/mock_eso.lua")
dofile(HARNESS_ROOT .. "/test/harness/loader.lua")

local H = HARNESS
H.fire(EVENT_ADD_ON_LOADED, "Verdant")

H.slotted = { [HOTBAR_CATEGORY_PRIMARY] = { [8] = 40223 } }
Verdant.Ultimate.refresh_cost()
Verdant.Visibility.set("graph", true)
Verdant.Graph.on_record_click()

local ult = 0
local function fight_tick()
  for i = 1, 8 do
    H.damage({ hit = 900 + i * 37, target_unit_id = 600 + i })
  end
  for i = 1, 4 do
    H.heal({ hit = 1800, overflow = 300, target_unit_id = 600 + i, ability_id = 61304 + (i % 3) })
  end
  H.heal({ hit = 900, overflow = 0, target_unit_id = 605, ability_id = 40058, result = ACTION_RESULT_HOT_TICK })
  H.shield({ hit = 500, target_unit_id = 601 })
  ult = (ult + 6) % 260
  H.ult_power(ult)
end

for _ = 1, 60 do
  fight_tick()
  H.advance(1000)
end

local VIEWS = { "EMS", "SKILL", "CRIT", "OHEAL", "BUFFS", "TRIAGE" }
local TRACK = { "SetAnchor", "ClearAnchors", "SetText", "SetColor", "SetHidden",
                "SetWidth", "SetHeight", "SetDimensions", "SetTexture" }

local view_label = VerdantGraphWindowViewLabel

local function measure(label)
  H.calls = {}
  local t0 = os.clock()
  for _ = 1, TICKS do
    fight_tick()
    H.advance(1000)
  end
  local ms = (os.clock() - t0) * 1000 / TICKS
  local c = H.calls
  H.calls = nil
  local bytes, by_fn = H.addon_alloc(function()
    for _ = 1, TICKS do
      fight_tick()
      H.advance(1000)
    end
  end)
  local total = 0
  for _, n in pairs(c) do total = total + n end
  local row = { label = label, ms = ms, bytes = bytes / TICKS, total = total / TICKS, by_fn = by_fn }
  for _, k in ipairs(TRACK) do row[k] = (c[k] or 0) / TICKS end
  return row
end

local rows = {}
for _, v in ipairs(VIEWS) do
  while view_label._text ~= v do Verdant.Graph.next_view() end
  rows[#rows + 1] = measure(v)
end
while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
Verdant.Visibility.set("graph", false)
rows[#rows + 1] = measure("hidden")

print(string.format("render budget per sample tick (DEBUG=%s, %d ticks, 60s window, 14 events/tick)",
  tostring(HARNESS_DEBUG), TICKS))
print(string.format("%-7s %8s %9s %7s  %6s %6s %6s %6s %6s %6s %6s %6s %6s",
  "view", "cpu", "alloc", "calls", "anch", "clr", "text", "color", "hide", "width", "height", "dims", "tex"))
for _, r in ipairs(rows) do
  print(string.format("%-7s %6.2fms %7.0fB %7.0f  %6.0f %6.0f %6.0f %6.0f %6.0f %6.0f %6.0f %6.0f %6.0f",
    r.label, r.ms, r.bytes, r.total,
    r.SetAnchor, r.ClearAnchors, r.SetText, r.SetColor, r.SetHidden,
    r.SetWidth, r.SetHeight, r.SetDimensions, r.SetTexture))
end

if DETAIL then
  for _, r in ipairs(rows) do
    if r.label == DETAIL then
      local list = {}
      for k, v in pairs(r.by_fn) do list[#list + 1] = { k = k, b = v * 1024 / TICKS } end
      table.sort(list, function(a, b) return a.b > b.b end)
      print("")
      print("addon-side allocation by function, bytes per tick, view " .. DETAIL)
      for i = 1, math.min(15, #list) do
        if list[i].b >= 1 then print(string.format("%8.0f  %s", list[i].b, list[i].k)) end
      end
    end
  end
end
