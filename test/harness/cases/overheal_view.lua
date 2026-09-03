return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()

  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end

  Verdant.Graph.on_record_click()
  for _ = 1, 6 do
    H.heal({ hit = 1000, overflow = 500, target_unit_id = 600 })
    H.advance(1000)
  end
  Verdant.Graph.on_stop_click()

  local has_o = false
  Verdant.TemporalBuffer.iterate(function(_, s)
    if (s.o or 0) > 0 then has_o = true end
  end)
  ok(has_o, "samples must carry the overheal rate")

  local sum = Verdant.TemporalBuffer.summary()
  ok(sum.total_overheal > 0, "summary must integrate the overheal channel")
  ok(math.abs(sum.wasted_pct - 1/3) < 0.02, "1000 eff + 500 over must be a third wasted, got " .. tostring(sum.wasted_pct))
  local chip = VerdantGraphSummaryLabel._text or ""
  ok(chip:find("WASTED") ~= nil, "summary chip must carry the wasted headline: " .. chip)
  ok(chip:find("33%%") ~= nil, "summary chip must read 33%% wasted: " .. chip)

  while view_label._text ~= "OHEAL" do Verdant.Graph.next_view() end

  local eff, wasted = false, false
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false then
      if name:find("^VerdantGraphFillEhps") then eff = true end
      if name:find("^VerdantGraphFillMps") and c._r and math.abs(c._r - 0.64) < 0.02
         and c._b and math.abs(c._b - 0.58) < 0.02 then
        wasted = true
      end
    end
  end
  ok(eff, "effective healing bars must render on OHEAL view")
  ok(wasted, "wasted band must stack on top in the overheal palette")
  ok(VerdantGraphOhLegend._hidden == false, "the OHEAL legend must show with data")
  ok((VerdantGraphOhLegend._text or ""):find("wasted") ~= nil, "legend must explain the grey band")

  local canvas = VerdantGraphWindowViewportCanvas
  local hit    = VerdantGraphHitMain
  H.state.mouse_x = canvas:GetLeft() + canvas:GetWidth() - 10
  H.state.mouse_y = canvas:GetTop() + 200
  hit._onOnMouseEnter(hit)
  H.advance(200)
  local stat = VerdantHoverCardStat._text or ""
  ok(stat:find("wasted") ~= nil, "moment card must show the wasted share: " .. stat)
  ok(stat:find("33%%") ~= nil, "1000 eff + 500 over must read 33%% wasted: " .. stat)
  hit._onOnMouseExit(hit)

  local session = Verdant.SessionStore.capture()
  ok(session and session.desc.series[7] and session.desc.series[7].name == "o",
     "session series must persist the overheal channel")
  ok(Verdant.Graph.load_session(session), "captured session must reload")
  local o_back = 0
  Verdant.TemporalBuffer.iterate(function(_, s) o_back = o_back + (s.o or 0) end)
  ok(o_back > 0, "reloaded session must keep overheal samples")
  ok((VerdantGraphSummaryLabel._text or ""):find("WASTED") ~= nil, "loaded session must show the wasted headline too")

  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  Verdant.Metrics.reset()
end
