return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local T = Verdant.Triage

  Verdant.Metrics.reset()
  Verdant.TemporalBuffer.clear()
  H.state.grouped = true
  H.state.group_size = 4
  H.state.player_group_tag = "group1"
  H.unit_names = H.unit_names or {}
  H.unit_names.group1 = "Me1"
  H.unit_names.group2 = "Ally2"
  H.unit_names.group3 = "Ally3"
  H.unit_names.group4 = "Ally4"
  H.fire(EVENT_GROUP_UPDATE)

  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_record_click()
  H.heal({ hit = 500, target_name = "Ally2", target_unit_id = 602 })
  H.advance(1000)

  H.power("group2", 19000, 40000)
  H.advance(500)
  H.heal({ hit = 2000, target_name = "Ally2", target_unit_id = 602 })
  H.power("group2", 23000, 40000)

  H.power("group3", 15000, 40000)
  H.advance(1000)
  H.death(true, "group3")

  H.advance(1000)
  Verdant.Graph.on_stop_click()

  local view_label = VerdantGraphWindowViewLabel
  local guard = 0
  while view_label._text ~= "TRIAGE" and guard < 8 do
    Verdant.Graph.next_view()
    guard = guard + 1
  end
  ok(view_label._text == "TRIAGE", "could not reach TRIAGE view: " .. tostring(view_label._text))
  ok(VerdantGraphWindowViewportNoDataLabel._hidden == true, "no_data must hide with episodes present")

  local function visible_texts()
    local seen = {}
    for _, c in ipairs(H.controls) do
      if c._hidden == false and type(c._text) == "string" then seen[c._text] = c end
    end
    return seen
  end
  local function has(seen, needle)
    for t in pairs(seen) do
      if t:find(needle, 1, true) then return true end
    end
    return false
  end

  local seen = visible_texts()
  ok(has(seen, "Saves"), "view header must show the saves aggregate")
  ok(has(seen, "1|r saves"), "legend must count the save")
  ok(has(seen, "1|r missed"), "legend must count the missed episode")
  ok(has(seen, "your heal saved them"), "legend must explain what a save is")
  ok(seen["50%"] ~= nil, "donut centre must read 50%% saved (1 of 2)")
  ok(seen["saved"] ~= nil, "donut centre must carry the word saved")
  ok(seen["Ally2"] ~= nil, "saves list must show Ally2")
  ok(seen["Ally3"] == nil, "saves list must not show the missed Ally3")
  ok(has(seen, "SAVES"), "caption must name the active filter")

  local d1 = VerdantTriDonutSlice1
  ok(d1 and d1._hidden == false and d1._cd_pct and d1._cd_pct > 0.4, "donut must draw the save slice")
  ok(VerdantTriDonut._hidden == false, "donut must be visible on the TRIAGE view")

  local icon_seen = false
  for _, c in ipairs(H.controls) do
    if c._hidden == false and type(c._tex) == "string" and c._tex:find("class") then
      icon_seen = true
      break
    end
  end
  ok(icon_seen, "list rows must show the member class icon")

  local canvas = VerdantGraphWindowViewportCanvas
  local hit    = VerdantGraphHitMain
  local chip_h = (VerdantGraphSummaryBg._hidden == false) and (VerdantGraphSummaryBg._h + 8) or 0
  if canvas:GetHeight() - chip_h < 160 then chip_h = 0 end
  H.sounds = {}
  H.state.mouse_x = canvas:GetLeft() + 120
  H.state.mouse_y = canvas:GetTop() + chip_h + 44 + 3 * 14 + 7
  hit._onOnMouseUp(hit, nil, true)
  ok(H.sounds[#H.sounds] == "sound:DIALOG_ACCEPT", "switching the legend filter must confirm with a sound")
  seen = visible_texts()
  ok(seen["Ally3"] ~= nil, "missed list must show Ally3")
  ok(seen["Ally2"] == nil, "missed list must not show Ally2")
  ok(has(seen, "MISSED"), "caption must follow the filter")

  H.state.mouse_y = canvas:GetTop() + chip_h + 44 + 68 + 8 + 18 + 8
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VerdantHoverCardName._text == "Ally3", "hovering the row must name the ally, got " .. tostring(VerdantHoverCardName._text))
  ok(VerdantHoverCardStat._text and VerdantHoverCardStat._text:find("min HP", 1, true),
     "row hover must show min HP, got " .. tostring(VerdantHoverCardStat._text))
  ok(VerdantHoverCardDesc._hidden == false and VerdantHoverCardDesc._text
     and VerdantHoverCardDesc._text:find("without a single heal", 1, true),
     "row hover must explain the outcome, got " .. tostring(VerdantHoverCardDesc._text))
  hit._onOnMouseExit(hit)

  hit._onOnMouseWheel(hit, -1)
  hit._onOnMouseWheel(hit, 1)
  ok(visible_texts()["Ally3"] ~= nil, "wheel on a one-row list must not lose the row")

  H.state.mouse_y = canvas:GetTop() + chip_h + 44 + 7
  hit._onOnMouseUp(hit, nil, true)
  H.state.mouse_y = canvas:GetTop() + chip_h + 44 + 68 + 8 + 18 + 8
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VerdantHoverCardName._text == "Ally2", "back on saves the row must be Ally2, got " .. tostring(VerdantHoverCardName._text))
  ok(VerdantHoverCardStat._text:find("RT 0.5s", 1, true) ~= nil,
     "the responded row must show its measured RT, got " .. tostring(VerdantHoverCardStat._text))
  hit._onOnMouseExit(hit)
  H.state.mouse_x, H.state.mouse_y = 400, 300

  local chip = VerdantGraphSummaryLabel
  ok(chip._text and chip._text:find("RT"), "summary chip must include RT when episodes responded")

  Verdant.Graph.next_view()
  ok(VerdantTriDonut._hidden == true, "leaving the view must hide the donut")

  H.state.grouped = false
  H.state.group_size = 1
  H.state.player_group_tag = nil
  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
end
