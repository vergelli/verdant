return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()
  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end

  Verdant.Graph.on_record_click()
  for _ = 1, 6 do
    H.heal({ hit = 1000, overflow = 600, target_unit_id = 600 })
    H.heal({ hit = 500, overflow = 200, target_unit_id = 601, result = ACTION_RESULT_HOT_TICK })
    H.advance(1000)
  end
  Verdant.Graph.on_stop_click()

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
  ok(VerdantHoverCardDesc._hidden == false and (VerdantHoverCardDesc._text or ""):find("HoT overflow is normal") ~= nil, "report must explain the split")
  ok(VerdantReportDonut._hidden == false and VerdantReportDonutSlice1._cd_pct > 0.3, "report card must draw its donut")
  hit._onOnMouseExit(hit)

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
  ok((VerdantHoverCardDesc._text or ""):find("Nothing went to waste") ~= nil, "a clean recording says so")
  hit._onOnMouseExit(hit)

  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  Verdant.Metrics.reset()
end
