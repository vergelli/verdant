return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()
  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end

  H.slotted = { [HOTBAR_CATEGORY_PRIMARY] = { [8] = 41001 } }
  H.state.ult_cost = 200
  Verdant.Graph.on_record_click()
  local ult = 0
  for i = 1, 6 do
    H.heal({ hit = 1000, overflow = 600, target_unit_id = 600 })
    H.heal({ hit = 500, overflow = 200, target_unit_id = 601, result = ACTION_RESULT_HOT_TICK })
    ult = ult + 100
    H.ult_power(ult)
    H.advance(1000)
  end
  Verdant.Graph.on_stop_click()

  local us = Verdant.Ultimate.summary()
  ok(us.dur_ms > 0 and us.ready_pct > 0.5 and us.ready_pct < 0.9,
     string.format("ultimate sits ready for most of the tail: ready_pct=%.2f dur=%d", us.ready_pct, us.dur_ms))
  ok(us.casts == 0, "no cast in this recording")

  local hot, direct = Verdant.Metrics.overheal_split()
  ok(hot == 1200 and direct == 3600, "overflow must split by result: hot=" .. hot .. " direct=" .. direct)

  local hit = VerdantGraphSummaryHit
  ok(hit._hidden == false, "the chip hit-box must show with the chip")
  ok(VerdantGraphSummaryHelp._hidden == false, "the chip must wear its help icon")
  hit._onOnMouseEnter(hit)
  ok(VerdantHoverCardName._text == "Healing report", "hovering the chip must open the healing report, got " .. tostring(VerdantHoverCardName._text))
  local stat = VerdantHoverCardStat._text or ""
  ok(stat:find("landed") ~= nil and stat:find("overflow") ~= nil, "report stat must read landed vs overflow: " .. stat)
  ok(VerdantHoverCardRowName1._text == "HoT overflow" and VerdantHoverCardRowName1._hidden == false, "row 1 is the HoT overflow")
  ok(VerdantHoverCardRowName2._text == "Direct-heal overflow" and VerdantHoverCardRowName2._hidden == false, "row 2 is the direct overflow")
  local hp = tonumber((VerdantHoverCardRowVal1._text or ""):match("(%d+)%%"))
  local dp = tonumber((VerdantHoverCardRowVal2._text or ""):match("(%d+)%%"))
  ok(hp and dp and dp > hp, "direct overflow must outweigh HoT overflow here: " .. tostring(hp) .. " vs " .. tostring(dp))
  local landed = tonumber(stat:match("(%d+)%% landed"))
  ok(landed and math.abs(landed + hp + dp - 100) <= 2, "landed + hot + direct must add up to 100: " .. tostring(landed) .. "+" .. tostring(hp) .. "+" .. tostring(dp))
  ok(VerdantHoverCardDesc._hidden == true, "the report carries no explanation paragraph")
  ok(VerdantHoverCard._draw_tier == DT_HIGH and VerdantHoverCardBg._draw_layer == DL_OVERLAY, "the card draws above every label")
  ok(VerdantReportDonut._hidden == false and VerdantReportDonutSlice1._cd_pct > 0.3, "report card must draw its donut")
  ok(VerdantHoverCardRowName3._hidden == false and VerdantHoverCardRowName3._text == "Ultimate ready, unused",
     "row 3 is the unused ultimate time")
  local rp = tonumber((VerdantHoverCardRowVal3._text or ""):match("(%d+)%%"))
  ok(rp and rp > 50, "unused ultimate time must show as a percentage: " .. tostring(VerdantHoverCardRowVal3._text))
  ok(VerdantHoverCardRowName4._text == "Ultimate casts" and VerdantHoverCardRowVal4._text == "0", "row 4 counts the casts")
  ok(VerdantHoverCardRowName5._text == "Peak at" and (VerdantHoverCardRowVal5._text or ""):find("s") ~= nil, "row 5 says when the peak was")
  ok((VerdantHoverCardTime._text or ""):find("copy") ~= nil, "the card must tell the user the chip is clickable")
  hit._onOnMouseExit(hit)
  ok(VerdantHoverCard._hidden == true, "leaving the chip closes the report")

  local hr = H.layout(hit)
  H.state.mouse_x, H.state.mouse_y = hr.x + 4, hr.y + 4
  hit._onOnMouseEnter(hit)
  ok(H.update_registered("VerdantCardGuard"), "the open report watches the mouse")
  H.advance(300)
  ok(VerdantHoverCard._hidden == false, "the report stays while the mouse rests on the chip")
  H.state.mouse_x, H.state.mouse_y = hr.x - 200, hr.y - 200
  H.advance(300)
  ok(VerdantHoverCard._hidden == true, "the report closes on its own when the mouse leaves without an exit event")
  ok(not H.update_registered("VerdantCardGuard"), "the watch stops with the report")

  H.state.mouse_x, H.state.mouse_y = hr.x + 4, hr.y + 4
  hit._onOnMouseEnter(hit)
  ok(VerdantHoverCard._hidden == false, "the report reopens")
  Verdant.Graph.on_move_start()
  ok(VerdantHoverCard._hidden == true, "dragging the window closes the report at once")
  H.advance(200)
  ok(not H.update_registered("VerdantCardGuard"), "the watch stops once the card is gone")
  local xml = assert(io.open("ui/graph.xml")):read("*a")
  ok(xml:find("<OnMoveStart>Verdant.Graph.on_move_start()", 1, true) ~= nil, "the window wires OnMoveStart")
  ok(xml:find("<OnResizeStart>Verdant.Graph.on_move_start()", 1, true) ~= nil, "the window wires OnResizeStart")

  hit._onOnMouseEnter(hit)
  ok(VerdantHoverCard._hidden == false, "the report reopens for the watchdog check")
  local state = Verdant.Graph.card_state()
  ok(state:find("hidden=false", 1, true) and state:find("report=true", 1, true), "the card probe reads the open report: " .. state)
  H.state.hold_fade = true
  hit._onOnMouseExit(hit)
  ok(VerdantHoverCard._hidden == false, "a fade whose callback never fires leaves the card on screen")
  H.advance(300)
  ok(VerdantHoverCard._hidden == true and (VerdantHoverCard._alpha or 0) == 0, "the watchdog forces the stuck card off")
  ok(not H.update_registered("VerdantCardGuard"), "the watchdog stops once the card is hidden")
  H.state.hold_fade = nil
  H.state.mouse_x, H.state.mouse_y = nil, nil

  H.sounds = {}
  hit._onOnMouseUp(hit, nil, true)
  ok(H.sounds[#H.sounds] == "sound:DIALOG_ACCEPT", "clicking the chip must confirm with a sound")
  ok(Verdant.CopyBox.is_visible(), "clicking the chip must open the copy box")
  local eb = rawget(_G, "VerdantCopyBoxEdit")
  local txt = eb and eb._text or ""
  ok(txt:find("Healing report", 1, true) ~= nil and txt:find("landed", 1, true) ~= nil
     and txt:find("HoT overflow:", 1, true) ~= nil and txt:find("|c", 1, true) == nil,
     "copy text must carry the report in plain text: " .. txt)
  Verdant.CopyBox.hide()

  local session = Verdant.SessionStore.capture()
  ok(session.head.sum.oh_hot == 1200 and session.head.sum.oh_direct == 3600, "session head must persist the split")
  ok(Verdant.Graph.load_session(session), "captured session must reload")
  hit._onOnMouseEnter(hit)
  ok(VerdantHoverCardRowName2._hidden == false and tonumber((VerdantHoverCardRowVal2._text or ""):match("(%d+)%%")) == dp,
     "loaded session must show the same split")
  hit._onOnMouseExit(hit)

  Verdant.Graph.on_flush_click()
  ok(hit._hidden == true, "flush must hide the chip hit-box")

  Verdant.Metrics.reset()
  Verdant.Graph.on_record_click()
  for _ = 1, 4 do
    H.heal({ hit = 1000, overflow = 0, target_unit_id = 600 })
    H.advance(1000)
  end
  Verdant.Graph.on_stop_click()
  hit._onOnMouseEnter(hit)
  ok(VerdantHoverCardName._text == "Healing report", "a clean recording still opens the report")
  hit._onOnMouseExit(hit)

  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  H.slotted = nil
  H.state.ult_cost = nil
  Verdant.Metrics.reset()
end
