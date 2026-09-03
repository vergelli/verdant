return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()
  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end

  H.ability_names = H.ability_names or {}
  H.ability_names[77] = "Breath of Life"
  H.ability_names[78] = "Healing Springs"
  Verdant.Graph.on_record_click()
  for _ = 1, 8 do
    H.heal({ hit = 3000, ability_id = 77, target_unit_id = 600 })
    H.heal({ hit = 1000, ability_id = 78, target_unit_id = 601 })
    H.advance(1000)
  end
  Verdant.Graph.on_stop_click()

  while view_label._text ~= "SKILL" do Verdant.Graph.next_view() end
  local ec  = VerdantGraphWindowViewportSkillAreaEhpsCanvas
  local hit = VerdantGraphHitTop
  H.state.mouse_x = ec:GetLeft() + ec:GetWidth() - 30
  H.state.mouse_y = ec:GetTop() + ec:GetHeight() - 30
  hit._onOnMouseEnter(hit)
  H.advance(200)

  local card = VerdantHoverCard
  ok(card._hidden == false, "hovering a skill bar must open the card")
  local names = {}
  for i = 1, 7 do
    local r = rawget(_G, "VerdantHoverCardRowName" .. i)
    if r and r._hidden == false and r._text then names[r._text] = true end
  end
  ok(names["Breath of Life"] and names["Healing Springs"], "card must list both abilities of the group")

  local dn = VerdantReportDonut
  ok(dn and dn._hidden == false, "the skill card must show the ability donut")
  local s1, s2 = VerdantReportDonutSlice1, VerdantReportDonutSlice2
  ok(s1 and s1._hidden == false and s2 and s2._hidden == false, "two abilities make two slices")
  ok(s1._cd_pct > 0.6 and s1._cd_pct < 0.85, "first slice is the big heal's share of the group, got " .. tostring(s1._cd_pct))
  ok(math.abs(s2._cd_pct - 1.0) < 0.02, "stacked second slice closes the ring, got " .. tostring(s2._cd_pct))
  ok(s1._fr and s2._fr and s1._fr > s2._fr, "slices shade from the group colour outward")
  hit._onOnMouseExit(hit)

  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
  local main = VerdantGraphHitMain
  local canvas = VerdantGraphWindowViewportCanvas
  H.state.mouse_x = canvas:GetLeft() + canvas:GetWidth() - 30
  H.state.mouse_y = canvas:GetTop() + canvas:GetHeight() - 40
  main._onOnMouseEnter(main)
  H.advance(200)
  ok(VerdantHoverCard._hidden == false, "EMS hover still opens the moment card")
  ok(VerdantReportDonut._hidden == true, "the moment card does not carry a donut")
  main._onOnMouseExit(main)

  H.state.mouse_x, H.state.mouse_y = 400, 300
  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  Verdant.Metrics.reset()
end
