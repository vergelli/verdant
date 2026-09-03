return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()
  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end

  local names = { "EMS", "SKILL", "CRIT", "OHEAL", "BUFFS", "TRIAGE" }
  for v = 1, 6 do
    local lbl = rawget(_G, "VerdantGraphTab" .. v .. "Label")
    local hit = rawget(_G, "VerdantGraphTab" .. v)
    ok(lbl and lbl._text == names[v], "tab " .. v .. " must read " .. names[v])
    ok(hit and type(hit._onOnMouseEnter) == "function", "tab " .. v .. " must explain itself on hover")
    H.last_tooltip = nil
    hit._onOnMouseEnter(hit)
    ok(type(H.last_tooltip) == "string" and #H.last_tooltip > 5, "tab " .. v .. " tooltip must carry text")
    hit._onOnMouseExit(hit)
  end
  ok(VerdantGraphTab1Line._hidden == false and VerdantGraphTab3Line._hidden == true, "only the active tab wears the line")

  H.sounds = {}
  VerdantGraphTab3._onOnMouseUp(VerdantGraphTab3, nil, true)
  ok(view_label._text == "CRIT", "clicking a tab switches the view, got " .. tostring(view_label._text))
  ok(H.sounds[#H.sounds] == "sound:DIALOG_ACCEPT", "switching confirms with the accept sound")
  ok(VerdantGraphTab3Line._hidden == false and VerdantGraphTab1Line._hidden == true, "the line follows the active tab")

  H.sounds = {}
  VerdantGraphTab3._onOnMouseUp(VerdantGraphTab3, nil, true)
  ok(#H.sounds == 0, "clicking the active tab stays silent")

  VerdantGraphTab6._onOnMouseUp(VerdantGraphTab6, nil, true)
  ok(view_label._text == "TRIAGE", "the last tab reaches TRIAGE")
  Verdant.Graph.next_view()
  ok(view_label._text == "EMS" and VerdantGraphTab1Line._hidden == false, "arrow navigation still updates the tabs")

  local strip = VerdantGraphWindowTabs
  local w = strip:GetWidth()
  ok(w > 0, "the strip must have a width")
  local tw = math.floor(w / 6)
  ok(VerdantGraphTab1._w == tw and VerdantGraphTab6._w == tw, "tabs share the strip evenly")

  ok(VerdantGraphWindowPrevViewBtn._hidden ~= false, "the old arrows are not part of the chrome anymore")

  Verdant.SavedVars.settings.light_mode = true
  H.state.mouse_x, H.state.mouse_y = 1900, 1000
  Verdant.Graph.on_record_click()
  H.heal({ hit = 1000 })
  H.advance(1000)
  ok(strip._hidden == true, "light mode hides the tab strip")
  Verdant.Graph.on_stop_click()
  ok(strip._hidden == false, "stopping brings the tabs back")
  Verdant.SavedVars.settings.light_mode = false

  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  Verdant.Metrics.reset()
end
