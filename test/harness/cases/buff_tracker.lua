return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local function eq(a, b, msg)
    if a ~= b then error(msg .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")", 2) end
  end

  local BT = Verdant.BuffTracker
  Verdant.Metrics.reset()
  Verdant.TemporalBuffer.clear()

  H.effect(EFFECT_RESULT_GAINED, 111, 600, 0)
  eq(BT.count(), 0, "must not track outside a recording")

  Verdant.Graph.on_record_click()
  local t0 = H.now()

  H.effect(EFFECT_RESULT_GAINED, 111, 600, 0)
  H.advance(2000)
  H.effect(EFFECT_RESULT_GAINED, 111, 601, 0)
  H.advance(2000)
  H.effect(EFFECT_RESULT_FADED, 111, 600, 0)
  H.advance(2000)
  H.effect(EFFECT_RESULT_FADED, 111, 601, 0)
  H.advance(1000)
  H.effect(EFFECT_RESULT_GAINED, 111, 600, 0)
  H.advance(1000)
  H.effect(EFFECT_RESULT_FADED, 111, 600, 0)

  H.effect(EFFECT_RESULT_GAINED, 222, 600, (H.now() + 2000) / 1000)
  H.advance(4000)

  Verdant.Graph.on_stop_click()

  eq(BT.count(), 2, "tracked ability count")

  local rec1
  BT.iterate(function(_, rec)
    if rec.id == 111 then rec1 = rec end
  end)
  ok(rec1, "ability 111 not tracked")
  eq(rec1.n_iv, 2, "union interval count for 111")
  eq(rec1.uptime_ms, 7000, "union uptime for 111")
  eq(rec1.applications, 3, "application count for 111")
  eq(rec1.unique_units, 2, "unique units for 111")
  eq(rec1.max_conc, 2, "max concurrency for 111")
  eq(BT.concurrency_at(rec1, t0 + 3000), 2, "concurrency at t0+3s")
  eq(BT.concurrency_at(rec1, t0 + 5000), 1, "concurrency at t0+5s")

  local rec2
  BT.iterate(function(_, rec)
    if rec.id == 222 then rec2 = rec end
  end)
  ok(rec2, "ability 222 not tracked")
  eq(rec2.n_iv, 1, "watchdog must have closed 222")
  ok(rec2.uptime_ms >= 1500 and rec2.uptime_ms <= 3000,
     "watchdog uptime for 222 out of range: " .. rec2.uptime_ms)

  if Verdant.Constants.DEBUG then
    ok(Verdant.Diagnostics.get("buffs.expired_watchdog") >= 1, "watchdog counter missing")
    local lines = BT.report_lines()
    ok(#lines >= 3, "report_lines too short")
  end

  Verdant.Graph.on_record_click()
  eq(BT.count(), 0, "new session must reset tracked buffs")
  ok(BT.is_recording(), "tracker must follow recording state")
  Verdant.Graph.on_stop_click()
  Verdant.Graph.on_flush_click()
  eq(BT.count(), 0, "flush must clear tracker")
  Verdant.Metrics.reset()
end
