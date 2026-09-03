return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local SC = Verdant.SkillColors

  H.ability_icons = H.ability_icons or {}
  H.ability_icons[5001] = "/esoui/art/icons/ability_companion_mirri_001.dds"
  ok(SC.group_of(5001) == "companion", "companion skills classify by icon, got " .. tostring(SC.group_of(5001)))
  ok(SC.is_group("companion"), "companion is a real group")
  local found_companion, found_other, order_ok = false, false, false
  local groups = SC.groups_ordered()
  for i, g in ipairs(groups) do
    if g.key == "companion" then found_companion = i end
    if g.key == "other" then found_other = i end
  end
  ok(found_companion and found_other and found_companion < found_other, "companion sits before unknown in the picker")

  ok(SC.custom_key("My Pets!") == "custom_my_pets", "custom keys derive from the label, got " .. SC.custom_key("My Pets!"))
  ok(SC.add_group("templar", "Nope", 1, 0, 0) == nil, "built-in groups cannot be overwritten")
  ok(SC.add_group(SC.custom_key("Pets"), "Pets", 0.9, 0.2, 0.2) == "custom_pets", "a custom group registers")
  ok(SC.is_group("custom_pets") and SC.is_custom("custom_pets"), "custom group is a group and is custom")
  ok(SC.group_label("custom_pets") == "Pets", "custom label sticks")
  local c = SC.group_color("custom_pets")
  ok(c.r > 0.85 and c.g < 0.3, "custom colour sticks")
  groups = SC.groups_ordered()
  ok(groups[#groups].key == "other" and groups[#groups - 1].key == "custom_pets", "custom groups slot in right before unknown")

  ok(SC.set_override(777001, "custom_pets"), "an ability can be assigned to a custom group")
  ok(SC.group_of(777001) == "custom_pets", "the assignment resolves")

  local sv = { custom_groups = { custom_birds = { label = "Birds", r = 0.1, g = 0.6, b = 0.9 } },
               skill_overrides = { [777002] = "custom_birds" } }
  SC.load_persisted(sv)
  ok(SC.is_group("custom_birds") and SC.group_label("custom_birds") == "Birds", "custom groups load from SavedVars")
  ok(SC.group_of(777002) == "custom_birds", "overrides to custom groups load after the groups themselves")

  Verdant.Metrics.reset()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()
  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
  H.ability_icons[999001] = "/esoui/art/icons/ability_mystery_001.dds"
  Verdant.Graph.on_record_click()
  for _ = 1, 6 do
    H.heal({ hit = 2000, ability_id = 999001, target_unit_id = 600 })
    H.advance(1000)
  end
  Verdant.Graph.on_stop_click()
  ok(SC.group_of(999001) == "other", "an unknown icon stays grey")
  while view_label._text ~= "SKILL" do Verdant.Graph.next_view() end
  local ec  = VerdantGraphWindowViewportSkillAreaEhpsCanvas
  local hit = VerdantGraphHitTop
  H.state.mouse_x = ec:GetLeft() + ec:GetWidth() - 30
  H.state.mouse_y = ec:GetTop() + ec:GetHeight() - 30
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VerdantHoverCard._hidden == false, "hovering the grey bar opens the card")
  ok(VerdantHoverCardDesc._hidden == false and (VerdantHoverCardDesc._text or ""):find("Settings") ~= nil,
     "the grey card must point to the settings, got " .. tostring(VerdantHoverCardDesc._text))
  hit._onOnMouseExit(hit)
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
  H.state.mouse_x, H.state.mouse_y = 400, 300
  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  Verdant.Metrics.reset()
end
