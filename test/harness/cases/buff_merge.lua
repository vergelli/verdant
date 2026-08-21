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

  H.unit_buffs = { group1 = { { id = 333, slot = 7 } } }
  H.slot_descs = { [7] = "Grants you a mock shield." }
  H.ability_descs_caster = { [444] = "Caster-scaled description." }

  Verdant.Graph.on_record_click()
  H.effect(EFFECT_RESULT_GAINED, 333, 700, 0)
  H.effect(EFFECT_RESULT_GAINED, 444, 700, 0)
  H.advance(1000)
  Verdant.Graph.on_stop_click()

  local by = {}
  Verdant.BuffTracker.iterate(function(_, r) by[r.id] = r end)
  eq(by[333].desc, "Grants you a mock shield.", "slot-scan fallback must capture the description")
  eq(by[444].desc, "Caster-scaled description.", "caster-tag description must win first")

  if Verdant.Constants.DEBUG then
    ok(Verdant.Diagnostics.get("buffs.desc_from_slot") >= 1, "desc_from_slot counter missing")
    ok(Verdant.Diagnostics.get("buffs.desc_from_caster") >= 1, "desc_from_caster counter missing")
  end

  Verdant.Graph.on_record_click()
  for _ = 1, 4 do
    H.effect(EFFECT_RESULT_GAINED, 555, 800, 0, nil, "")
    H.effect(EFFECT_RESULT_FADED, 555, 800, 0, nil, "")
  end
  H.unit_buffs.group1[2] = { id = 555, slot = 9 }
  H.slot_descs[9] = "Late but resolved."
  H.effect(EFFECT_RESULT_GAINED, 555, 800, 0)
  H.advance(1000)
  Verdant.Graph.on_stop_click()
  local rec555
  Verdant.BuffTracker.iterate(function(_, r) if r.id == 555 then rec555 = r end end)
  eq(rec555.desc, "Late but resolved.", "tagless gains must not burn description retries")

  Verdant.Graph.on_record_click()
  H.effect(EFFECT_RESULT_GAINED, 601, 900, 0, nil, nil, BUFF_EFFECT_TYPE_DEBUFF)
  H.effect(EFFECT_RESULT_GAINED, 602, 900, 0, nil, nil, BUFF_EFFECT_TYPE_BUFF, ABILITY_TYPE_HEAL)
  H.effect(EFFECT_RESULT_GAINED, 603, 900, 0)
  H.advance(1000)
  Verdant.Graph.on_stop_click()

  local seen = {}
  Verdant.BuffTracker.iterate(function(_, r) seen[r.id] = true end)
  ok(not seen[601], "debuffs must not be tracked as buffs")
  ok(not seen[602], "heal effects must not be tracked as buffs")
  ok(seen[603], "plain buffs must still be tracked")

  local excluded_line = false
  for _, l in ipairs(Verdant.BuffTracker.report_lines()) do
    if l:find("excluded as non") then excluded_line = true end
  end
  ok(excluded_line, "report must list excluded non-buffs")

  if Verdant.Constants.DEBUG then
    ok(Verdant.Diagnostics.get("buffs.skipped_not_buff") >= 1, "skipped_not_buff counter missing")
    ok(Verdant.Diagnostics.get("buffs.skipped_heal_effect") >= 1, "skipped_heal_effect counter missing")
  end

  H.unit_buffs = nil
  H.slot_descs = nil
  H.ability_descs_caster = nil
  H.ability_names = nil
  Verdant.Graph.on_flush_click()
  Verdant.Metrics.reset()
end
