return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local function eq(a, b, msg)
    if a ~= b then error(msg .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")", 2) end
  end

  local BT = Verdant.BuffTracker
  Verdant.Metrics.reset()
  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", true)
  local view_label = VerdantGraphWindowViewLabel
  local guard = 0
  while view_label._text ~= "BUFFS" and guard < 6 do
    Verdant.Graph.next_view()
    guard = guard + 1
  end

  H.passive_ids = { [700] = true }
  H.ability_names = { [700] = "Sacred Mock", [701] = "Crux Mock", [702] = "Item Proc Mock", [703] = "Group Buff Mock" }
  H.ability_descs = {}

  Verdant.Graph.on_record_click()
  H.effect(EFFECT_RESULT_GAINED, 700, 500, 0, nil, "player")
  H.effect(EFFECT_RESULT_GAINED, 701, 500, 0, nil, "player")
  H.effect(EFFECT_RESULT_GAINED, 176922, 500, 0, nil, "player")
  H.effect(EFFECT_RESULT_GAINED, 703, 600, 0, nil, "group1")
  H.advance(2000)
  ok(BT.count() == 3, "tracker keeps self-state data live (got " .. BT.count() .. ")")
  local crux_visible = false
  for i = 1, 24 do
    local lbl = rawget(_G, "VerdantBuffLbl" .. i)
    if lbl and lbl._hidden == false and lbl._text == "Crux Mock" then crux_visible = true end
  end
  ok(not crux_visible, "self-only state must not render even while recording")
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

  H.skill_keys = { [810] = {1, 2, 3}, [40095] = {1, 2, 3},
                   [811] = {0, 0, 0}, [40096] = {0, 0, 0} }
  H.slotted = { [HOTBAR_CATEGORY_PRIMARY] = { [3] = 40095, [4] = 40096 } }
  H.ability_names[810]   = "Blockade of Mock"
  H.ability_names[40095] = "Elemental Mock"
  H.ability_names[820]   = "Racy Buff"
  H.ability_names[811]   = "Sentinel Buff"
  H.ability_names[40096] = "Scribed Thing"
  H.unit_buffs = { player = { { id = 820, slot = 11 } } }
  H.slot_descs = { [11] = "Tick resolved." }

  Verdant.Graph.on_record_click()
  H.effect(EFFECT_RESULT_GAINED, 810, 901, 0)
  H.effect(EFFECT_RESULT_GAINED, 811, 901, 0)
  H.effect(EFFECT_RESULT_GAINED, 820, 600, 0)
  H.advance(3000)
  Verdant.Graph.on_stop_click()

  local by_name = {}
  BT.iterate(function(_, r) by_name[r.name] = r end)
  ok(by_name["Blockade of Mock"] == nil, "renamed aura of a slotted skill must be excluded via skill keys")
  ok(by_name["Sentinel Buff"], "zero-key sentinel ids must NEVER match slotted keys")
  ok(by_name["Racy Buff"], "normal buff must remain")
  eq(by_name["Racy Buff"].desc, "Tick resolved.", "tick pass must resolve descriptions that raced the buff list")

  local morph_line = false
  for _, l in ipairs(BT.report_lines()) do
    if l:find("renamed aura") then morph_line = true end
  end
  ok(morph_line, "report must show the renamed-aura exclusion")

  if Verdant.Constants.DEBUG then
    ok(Verdant.Diagnostics.get("buffs.skipped_ability_morph") >= 1, "morph counter missing")
    ok(Verdant.Diagnostics.get("buffs.desc_resolved_tick") >= 1, "tick-resolve counter missing")
  end

  Verdant.Graph.on_record_click()
  Verdant.Graph.on_stop_click()
  H.ability_icons = { [860] = "/esoui/art/icons/ability_destructionstaff_012.dds" }
  H.ability_names[860] = "Frosty Proc"
  Verdant.Graph.on_record_click()
  H.effect(EFFECT_RESULT_GAINED, 860, 600, 0)
  H.effect(EFFECT_RESULT_GAINED, 860, 601, 0)
  H.advance(1000)
  Verdant.Graph.on_stop_click()
  local frosty
  BT.iterate(function(_, r) if r.name == "Frosty Proc" then frosty = r end end)
  ok(frosty == nil, "buffs whose icon classifies to a skill line must be excluded as procs")
  local proc_line = false
  for _, l in ipairs(BT.report_lines()) do
    if l:find("skill%-line proc") then proc_line = true end
  end
  ok(proc_line, "report must show the skill-line proc exclusion")
  H.ability_icons = nil

  H.skill_keys = nil
  H.slotted = nil
  H.unit_buffs = nil
  H.slot_descs = nil
  H.passive_ids = nil
  H.ability_names = nil
  H.ability_descs = nil
  H.ability_names = { [830] = "Swappy", [40097] = "Swappy",
                      [840] = "Crux Trial", [850] = "Passive Aura Mock" }
  H.skill_keys = { [850] = {4, 2, 7} }

  Verdant.Graph.on_record_click()
  H.effect(EFFECT_RESULT_GAINED, 840, 500, 0, nil, "player")
  H.effect(EFFECT_RESULT_GAINED, 840, 500, 0, nil, "group1")
  H.effect(EFFECT_RESULT_GAINED, 850, 500, 0, nil, "player")
  H.advance(1000)
  Verdant.Graph.on_stop_click()

  local trial_names = {}
  BT.iterate(function(_, r) trial_names[r.name] = true end)
  ok(not trial_names["Crux Trial"],
     "duplicate group-tag event for the SAME unit must not break only_self")
  ok(not trial_names["Passive Aura Mock"],
     "auras with valid skill keys must be excluded as skill auras")

  local aura_line = false
  for _, l in ipairs(BT.report_lines()) do
    if l:find("skill aura") then aura_line = true end
  end
  ok(aura_line, "report must show the skill-aura exclusion")

  H.skill_keys = { [217608] = {9, 1, 2} }
  H.ability_names[217608] = "Veto Buff"
  Verdant.Graph.on_record_click()
  H.effect(EFFECT_RESULT_GAINED, 217608, 600, 0)
  H.advance(1000)
  Verdant.Graph.on_stop_click()
  local vetoed
  BT.iterate(function(_, r) if r.name == "Veto Buff" then vetoed = r end end)
  ok(vetoed, "explicitly overridden ids must veto the skill-aura exclusion")
  if Verdant.Constants.DEBUG then
    ok(Verdant.Diagnostics.get("buffs.aura_vetoed_by_override") >= 1, "veto counter missing")
  end
  H.skill_keys = nil
  H.slotted = { [HOTBAR_CATEGORY_PRIMARY] = {} }
  Verdant.Graph.on_record_click()
  H.effect(EFFECT_RESULT_GAINED, 830, 500, 0)
  H.advance(1000)
  local found = false
  BT.iterate(function(_, r) if r.name == "Swappy" then found = true end end)
  ok(found, "buff must track before the bar swap")

  H.slotted[HOTBAR_CATEGORY_PRIMARY][5] = 40097
  H.fire(EVENT_ACTIVE_WEAPON_PAIR_CHANGED, 1, true)
  found = false
  BT.iterate(function(_, r) if r.name == "Swappy" then found = true end end)
  ok(not found, "bar-swap rescan must purge matching rows retroactively")

  H.effect(EFFECT_RESULT_GAINED, 830, 500, 0)
  found = false
  BT.iterate(function(_, r) if r.name == "Swappy" then found = true end end)
  ok(not found, "re-gained aura must stay excluded after the purge")

  local purge_line = false
  for _, l in ipairs(BT.report_lines()) do
    if l:find("bar swap rescan") then purge_line = true end
  end
  ok(purge_line, "report must show the bar-swap purge")
  Verdant.Graph.on_stop_click()

  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
  Verdant.Visibility.set("graph", false)
  Verdant.Graph.on_flush_click()
  Verdant.Metrics.reset()
end
