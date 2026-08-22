return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local function eq(a, b, msg)
    if a ~= b then error(msg .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")", 2) end
  end

  Verdant.Metrics.reset()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()
  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end

  H.death(true)
  local _, n0 = Verdant.TemporalBuffer.markers()
  eq(n0, 0, "markers must not record outside a recording")

  Verdant.Graph.on_record_click()
  H.heal({ hit = 1000 })
  H.effect(EFFECT_RESULT_GAINED, 990, 600, 0)
  H.advance(2000)
  H.death(true)
  H.advance(2000)
  H.death(false)
  H.advance(1000)
  Verdant.Graph.on_stop_click()

  local ms, n = Verdant.TemporalBuffer.markers()
  eq(n, 2, "death and res markers recorded")
  ok(ms[1].death and not ms[2].death, "marker kinds must match events")

  local line1 = rawget(_G, "VerdantMarkerLine1")
  local icon1 = rawget(_G, "VerdantMarkerIcon1")
  ok(line1 and line1._hidden == false, "marker line must render on EMS view")
  ok(icon1 and icon1._hidden == false, "marker icon must render on EMS view")

  local guard = 0
  while view_label._text ~= "BUFFS" and guard < 6 do
    Verdant.Graph.next_view()
    guard = guard + 1
  end
  ok(line1._hidden == false, "markers must render on the BUFFS view too")

  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
  Verdant.Graph.on_flush_click()
  local _, n2 = Verdant.TemporalBuffer.markers()
  eq(n2, 0, "flush must clear markers")
  Verdant.Visibility.set("graph", false)
  Verdant.Metrics.reset()
end
