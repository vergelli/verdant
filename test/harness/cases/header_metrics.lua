return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local function close(a, b, tol, msg)
    if math.abs(a - b) > tol then error(msg .. " (got " .. a .. ", want " .. b .. ")", 2) end
  end

  Verdant.Metrics.reset()
  Verdant.TemporalBuffer.clear()
  Verdant.Metrics.set_window(5000)

  Verdant.Graph.on_record_click()
  for i = 1, 6 do
    H.heal({ hit = 1000 })
    if i % 2 == 0 then H.heal({ hit = 1000, result = ACTION_RESULT_CRITICAL_HEAL }) end
    H.advance(1000)
  end
  Verdant.Graph.on_stop_click()

  local s = Verdant.TemporalBuffer.summary()
  ok(s.count >= 5, "too few samples: " .. s.count)
  ok(s.peak_ems > 0, "peak must be positive")
  ok(s.avg_ems > 0 and s.avg_ems <= s.peak_ems, "avg must be in (0, peak]")
  close(s.crit_pct, 1 / 3, 0.12, "crit share")
  ok(s.dur_ms >= 4000, "duration too short: " .. s.dur_ms)
  ok(s.active_pct > 0.5, "active share too low: " .. s.active_pct)

  local chip = VerdantGraphSummaryLabel
  ok(chip._hidden == false, "summary chip must be visible after stop")
  ok(chip._text and chip._text:find("AVG"), "chip text missing AVG: " .. tostring(chip._text))
  ok(chip._text:find("PEAK"), "chip text missing PEAK")
  ok(chip._text:find("CRIT"), "chip text missing CRIT")

  Verdant.Graph.on_record_click()
  ok(VerdantGraphSummaryLabel._hidden == true, "chip must hide when a new recording starts")
  Verdant.Graph.on_stop_click()
  Verdant.Graph.on_flush_click()
  ok(VerdantGraphSummaryLabel._hidden == true, "chip must hide after flush")
  ok(Verdant.TemporalBuffer.summary().count == 0, "summary must be empty after flush")

  Verdant.Metrics.reset()
end
