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

  local seen = {}
  for _, c in ipairs(H.controls) do
    if c._hidden == false and type(c._text) == "string" then
      if c._text == "Ally2" or c._text == "Ally3"
         or c._text == "save" or c._text == "missed" then
        seen[c._text] = true
      end
      if c._text:find("Saves", 1, true) then seen.header = true end
      if c._text:match("^%d:%d%d$") then seen.time = true end
    end
  end
  ok(seen["Ally2"], "ledger must show Ally2's row")
  ok(seen["Ally3"], "ledger must show Ally3's row")
  ok(seen["save"], "Ally2 episode must chip as save")
  ok(seen["missed"], "Ally3 episode must chip as missed")
  ok(seen.header, "view header must show the saves aggregate")
  ok(seen.time, "rows must show session timestamps")

  local icon_seen = false
  for _, c in ipairs(H.controls) do
    if c._hidden == false and type(c._tex) == "string" and c._tex:find("class") then
      icon_seen = true
      break
    end
  end
  ok(icon_seen, "ledger rows must show the member class icon")

  local canvas = VerdantGraphWindowViewportCanvas
  local hit    = VerdantGraphHitMain
  H.state.mouse_x = canvas:GetLeft() + 100
  H.state.mouse_y = canvas:GetTop() + 60
  hit._onOnMouseEnter(hit)
  H.advance(200)
  local card = VerdantHoverCardName
  ok(card._text == "Ally2" or card._text == "Ally3",
     "triage hover must name the ally, got " .. tostring(card._text))
  local stat = VerdantHoverCardStat
  ok(stat._text and stat._text:find("min HP", 1, true),
     "triage hover stat must show min HP, got " .. tostring(stat._text))
  local desc = VerdantHoverCardDesc
  ok(desc and desc._hidden == false and desc._text and
     (desc._text:find("brought them back", 1, true)
      or desc._text:find("without a single heal", 1, true)
      or desc._text:find("Got back up", 1, true)),
     "triage hover must explain the outcome, got " .. tostring(desc and desc._text))

  local names_seen = { [tostring(VerdantHoverCardName._text)] = true }
  local rt_seen = stat._text:find("RT 0.5s", 1, true) ~= nil
  H.state.mouse_y = canvas:GetTop() + 82
  H.advance(200)
  names_seen[tostring(VerdantHoverCardName._text)] = true
  rt_seen = rt_seen or (VerdantHoverCardStat._text:find("RT 0.5s", 1, true) ~= nil)
  ok(names_seen["Ally2"] and names_seen["Ally3"],
     "both episode rows must be hoverable")
  ok(rt_seen, "the responded row must show its measured RT, got "
     .. tostring(VerdantHoverCardStat._text))
  H.state.mouse_x, H.state.mouse_y = 400, 300

  local chip = VerdantGraphSummaryLabel
  ok(chip._text and chip._text:find("RT"), "summary chip must include RT when episodes responded")

  H.state.grouped = false
  H.state.group_size = 1
  H.state.player_group_tag = nil
  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
end
