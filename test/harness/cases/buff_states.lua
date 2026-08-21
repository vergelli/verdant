return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local function eq(a, b, msg)
    if a ~= b then error(msg .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")", 2) end
  end

  local BT = Verdant.BuffTracker
  Verdant.Metrics.reset()
  Verdant.Graph.on_flush_click()

  H.passive_ids = { [700] = true }
  H.ability_names = { [700] = "Sacred Mock", [701] = "Crux Mock", [702] = "Item Proc Mock", [703] = "Group Buff Mock" }
  H.ability_descs = {}

  Verdant.Graph.on_record_click()
  H.effect(EFFECT_RESULT_GAINED, 700, 500, 0, nil, "player")
  H.effect(EFFECT_RESULT_GAINED, 701, 500, 0, nil, "player")
  H.effect(EFFECT_RESULT_GAINED, 176922, 500, 0, nil, "player")
  H.effect(EFFECT_RESULT_GAINED, 703, 600, 0, nil, "group1")
  H.advance(2000)
  ok(BT.count() == 3, "live view keeps self-state until stop (got " .. BT.count() .. ")")
  Verdant.Graph.on_stop_click()

  local names = {}
  BT.iterate(function(_, r) names[r.name] = true end)
  ok(not names["Sacred Mock"], "passive skills must be excluded at creation")
  ok(not names["Crux Mock"], "self-only descriptionless states must drop at stop")
  ok(names["Ability176922"], "item procs must survive even when self-only and descless")
  ok(names["Group Buff Mock"], "buffs reaching other units must survive")
  eq(BT.count(), 2, "final row count")

  local passive_line, state_line = false, false
  for _, l in ipairs(BT.report_lines()) do
    if l:find("passive skill") then passive_line = true end
    if l:find("self%-only state") then state_line = true end
  end
  ok(passive_line, "report must show the passive exclusion")
  ok(state_line, "report must show the self-only state exclusion")

  if Verdant.Constants.DEBUG then
    ok(Verdant.Diagnostics.get("buffs.skipped_passive") >= 1, "skipped_passive counter missing")
    ok(Verdant.Diagnostics.get("buffs.excluded_self_state") >= 1, "excluded_self_state counter missing")
  end

  Verdant.Graph.on_record_click()
  Verdant.Graph.on_stop_click()
  H.passive_ids = nil
  H.ability_names = nil
  H.ability_descs = nil
  Verdant.Graph.on_flush_click()
  Verdant.Metrics.reset()
end
