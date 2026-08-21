return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local function eq(a, b, msg)
    if a ~= b then error(msg .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")", 2) end
  end

  local BT = Verdant.BuffTracker
  Verdant.Metrics.reset()
  Verdant.Graph.on_flush_click()

  H.ability_names = { [501] = "Twin Buff", [502] = "Twin Buff" }

  Verdant.Graph.on_record_click()
  H.effect(EFFECT_RESULT_GAINED, 501, 600, 0)
  H.advance(2000)
  H.effect(EFFECT_RESULT_GAINED, 502, 600, 0)
  H.effect(EFFECT_RESULT_FADED, 501, 600, 0)
  H.advance(2000)
  H.effect(EFFECT_RESULT_FADED, 502, 600, 0)
  H.advance(1000)
  H.effect(EFFECT_RESULT_GAINED, 501, 601, 0)
  H.advance(1000)
  H.effect(EFFECT_RESULT_FADED, 501, 601, 0)
  H.advance(1000)
  Verdant.Graph.on_stop_click()

  eq(BT.count(), 1, "same-name ids must merge into one row")
  local rec = BT.get(1)
  eq(rec.name, "Twin Buff", "merged row name")
  eq(rec.n_ids, 2, "merged id count")
  eq(rec.max_conc, 1, "same unit holding two ids must count as one holder")
  eq(rec.n_iv, 2, "interval count")
  eq(rec.uptime_ms, 5000, "union uptime across ids")
  eq(rec.unique_units, 2, "unique units")

  local lines = BT.report_lines()
  local found_ids = false
  for _, l in ipairs(lines) do
    if l:find("ids=501/502") or l:find("ids=502/501") then found_ids = true end
    if l:find("Twin Buff") then ok(l:find("grp="), "report row must include group") end
  end
  ok(found_ids, "report must list merged ids")

  local s = Verdant.TemporalBuffer.summary()
  ok(s.count > 0, "summary must have samples")
  eq(s.peak_ems, 0, "no healing this session")
  eq(s.peak_t_off, 0, "peak_t_off must be 0 when there is no peak")

  H.ability_names = nil
  Verdant.Graph.on_flush_click()
  Verdant.Metrics.reset()
end
