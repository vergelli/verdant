SIMLAB_ROOT   = arg[1] or "."
HARNESS_ROOT  = SIMLAB_ROOT
HARNESS_DEBUG = true

dofile(SIMLAB_ROOT .. "/test/harness/mock_eso.lua")
local svg = dofile(SIMLAB_ROOT .. "/test/simlab/svg.lua")
svg.apply_xml(SIMLAB_ROOT .. "/ui/graph.xml")
svg.apply_xml(SIMLAB_ROOT .. "/ui/settings.xml")
svg.apply_xml(SIMLAB_ROOT .. "/ui/bar.xml")
svg.apply_xml(SIMLAB_ROOT .. "/ui/watch.xml")
svg.apply_xml(SIMLAB_ROOT .. "/ui/library.xml")
dofile(SIMLAB_ROOT .. "/test/harness/loader.lua")

local H = HARNESS
H.fire(EVENT_ADD_ON_LOADED, "Verdant")
local OUT = SIMLAB_ROOT .. "/test/simlab/out/"

Verdant.Settings.toggle()
print(svg.snapshot(H, VerdantSettingsPanel, OUT .. "settings_panel.svg"))
Verdant.Settings.toggle()

Verdant.Visibility.set("bar", true)
for _ = 1, 4 do
  H.heal({ hit = 1400 })
  H.shield({ hit = 500 })
  H.advance(1000)
end
print(svg.snapshot(H, VerdantBarWindow, OUT .. "bar_window.svg"))

H.ability_names = H.ability_names or {}
H.ability_names[9001] = "Major Courage"
H.ability_names[9002] = "Minor Berserk"
Verdant.BuffWatch.toggle("Major Courage", 9001)
Verdant.BuffWatch.toggle("Minor Berserk", 9002)
H.effect(EFFECT_RESULT_GAINED, 9001, 4242, (H.now() + 2500) / 1000, nil, "player")
H.effect(EFFECT_RESULT_GAINED, 9002, 4242, (H.now() + 1200) / 1000, nil, "player")
H.advance(500)
print(svg.snapshot(H, VerdantWatchOverlay, OUT .. "watch_overlay.svg"))
Verdant.BuffWatch.toggle("Major Courage", 9001)
Verdant.BuffWatch.toggle("Major Courage", 9001)
Verdant.BuffWatch.toggle("Minor Berserk", 9002)
Verdant.BuffWatch.toggle("Minor Berserk", 9002)

Verdant.SavedVars.settings.session_autosave = true
Verdant.Visibility.set("graph", true)
Verdant.Graph.on_record_click()
for _ = 1, 20 do
  H.heal({ hit = 1000, overflow = 300 })
  H.advance(1000)
end
Verdant.Graph.on_stop_click()
Verdant.Library.show()
print(svg.snapshot(H, VerdantLibrary, OUT .. "library_window.svg"))
Verdant.Library.hide()

local canvas = VerdantGraphWindowViewportCanvas
H.state.mouse_x = canvas:GetLeft() + canvas:GetWidth() - 30
H.state.mouse_y = canvas:GetTop() + 120
local hit = VerdantGraphHitMain
hit._onOnMouseEnter(hit)
H.advance(200)
print(svg.snapshot(H, VerdantGraphWindow, OUT .. "graph_hover.svg"))
hit._onOnMouseExit(hit)

H.state.mouse_x, H.state.mouse_y = 1900, 1000
Verdant.SavedVars.settings.light_mode = true
Verdant.Graph.on_record_click()
for _ = 1, 8 do
  H.heal({ hit = 1200, overflow = 200 })
  H.advance(1000)
end
print(svg.snapshot(H, VerdantGraphWindow, OUT .. "graph_light.svg"))
Verdant.Graph.on_stop_click()
Verdant.SavedVars.settings.light_mode = false
Verdant.Graph.on_flush_click()
