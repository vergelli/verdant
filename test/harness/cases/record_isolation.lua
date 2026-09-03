return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()

  Verdant.Graph.on_record_click()
  for _ = 1, 8 do
    H.heal({ hit = 2000, overflow = 800 })
    H.advance(1000)
  end
  Verdant.Graph.on_stop_click()
  H.advance(2000)

  Verdant.Graph.on_record_click()
  for _ = 1, 4 do H.advance(1000) end
  local TB = Verdant.TemporalBuffer
  local first = TB.at(1)
  ok(first and first.eHPS == 0 and (first.o or 0) == 0,
     string.format("a fresh recording must start from zero, got eHPS=%.0f OHPS=%.0f", first.eHPS, first.o or 0))
  local sum = TB.summary()
  ok(sum.peak_ems == 0 and sum.active_pct == 0,
     string.format("nothing healed means peak 0 and active 0%%, got peak=%.0f active=%.2f", sum.peak_ems, sum.active_pct))
  Verdant.Graph.on_stop_click()
  local chip = VerdantGraphSummaryLabel._text or ""
  ok(chip:find("PEAK|r |c%x%x%x%x%x%x0|r") ~= nil, "chip must not inherit the previous recording's peak: " .. chip)

  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  Verdant.Metrics.reset()
end
