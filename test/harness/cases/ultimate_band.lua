return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()
  H.state.ult_cost = 250

  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end

  Verdant.Graph.on_record_click()
  local v = 0
  for _ = 1, 20 do
    v = v + 25
    H.ult_power(v)
    H.heal({ hit = 1000 })
    H.advance(1000)
  end
  H.ult_used()
  H.ult_power(0)
  for _ = 1, 5 do
    H.heal({ hit = 1000 })
    H.advance(1000)
  end
  Verdant.Graph.on_stop_click()

  local snap = Verdant.Ultimate.snapshot()
  ok(snap.cost == 250, "cost must come from the slotted ultimate, got " .. tostring(snap.cost))
  ok(snap.steps > 10, "power updates must build the charge curve, steps=" .. snap.steps)
  ok(snap.used == 1, "the cast must register exactly once, used=" .. snap.used)
  ok(Verdant.Diagnostics.get("ult.power_updates") >= 21, "diag counter must expose the update rate")

  ok(Verdant.Ultimate.pct_at(Verdant.Ultimate.steps() and select(1, Verdant.Ultimate.steps())[1] or 0) <= 0.2,
     "charge starts near zero")

  local gold, charging, tick = false, false, false
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VerdantGraphUlt") and not name:find("Top") then
      if c._h == 5 and c._r and c._r > 0.9 and c._g and c._g > 0.8 and c._b < 0.5 then gold = true end
      if c._h == 5 and c._r and c._r < 0.9 and c._g and c._g > 0.9 then charging = true end
      if c._h == 11 and c._w == 2 then tick = true end
    end
  end
  ok(charging, "charging segments must render in the brand green")
  ok(gold, "the available window must render gold")
  ok(tick, "the cast must render as a tick over the band")

  Verdant.Graph.on_flush_click()
  ok(not Verdant.Ultimate.has_data(), "flush must clear the ultimate session")
  Verdant.Visibility.set("graph", false)
  Verdant.Metrics.reset()
end
