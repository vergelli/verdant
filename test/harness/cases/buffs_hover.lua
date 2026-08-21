return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.TemporalBuffer.clear()
  Verdant.Visibility.set("graph", true)

  Verdant.Graph.on_record_click()
  H.heal({ hit = 500 })
  H.effect(EFFECT_RESULT_GAINED, 111, 600, 0)
  H.advance(2000)
  H.effect(EFFECT_RESULT_GAINED, 111, 601, 0)
  H.advance(2000)
  H.effect(EFFECT_RESULT_FADED, 111, 601, 0)
  H.advance(2000)
  H.effect(EFFECT_RESULT_FADED, 111, 600, 0)
  H.effect(EFFECT_RESULT_GAINED, 222, 602, 0)
  H.advance(2000)
  H.effect(EFFECT_RESULT_FADED, 222, 602, 0)
  Verdant.Graph.on_stop_click()

  local view_label = VerdantGraphWindowViewLabel
  local guard = 0
  while view_label._text ~= "BUFFS" and guard < 6 do
    Verdant.Graph.next_view()
    guard = guard + 1
  end
  ok(view_label._text == "BUFFS", "could not reach BUFFS view")

  local canvas = VerdantGraphWindowViewportCanvas
  local hit    = VerdantGraphHitMain
  ok(hit._hidden == false, "hit surface must be active on frozen BUFFS view")

  H.state.mouse_x = canvas:GetLeft() + 300
  H.state.mouse_y = canvas:GetTop() + 5
  hit._onOnMouseEnter(hit)
  H.advance(200)

  local card_name = VerdantHoverCardName
  ok(card_name._text == "Ability111", "hover card name wrong: " .. tostring(card_name._text))
  ok(VerdantHoverCard._hidden == false, "hover card must be visible")

  local found_players, found_gap = false, false
  for i = 1, 5 do
    local rn = rawget(_G, "VerdantHoverCardRowName" .. i)
    if rn and rn._text == "Players reached" then
      found_players = true
      local rv = rawget(_G, "VerdantHoverCardRowVal" .. i)
      ok(rv._text == "2", "players reached wrong: " .. tostring(rv._text))
    end
    if rn and rn._text == "Longest gap" then found_gap = true end
  end
  ok(found_players, "card missing Players reached row")
  ok(found_gap, "card missing Longest gap row")

  local dimmed = false
  for i = 1, 12 do
    local seg = rawget(_G, "VerdantBuffSeg" .. i)
    if seg and seg._hidden == false and seg._a and seg._a <= 0.30 then dimmed = true end
  end
  ok(dimmed, "non-hovered rows must dim while hovering")

  H.state.mouse_y = canvas:GetTop() + canvas:GetHeight() + 50
  H.advance(200)
  ok(VerdantHoverCard._alpha == 0, "card must fade out when leaving canvas")

  hit._onOnMouseExit(hit)
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  Verdant.Metrics.reset()
end
