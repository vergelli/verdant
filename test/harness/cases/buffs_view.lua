return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.TemporalBuffer.clear()

  Verdant.Graph.on_record_click()
  H.heal({ hit = 500 })
  H.effect(EFFECT_RESULT_GAINED, 111, 600, 0)
  H.advance(3000)
  H.effect(EFFECT_RESULT_GAINED, 111, 601, 0)
  H.advance(3000)
  H.effect(EFFECT_RESULT_FADED, 111, 600, 0)
  H.effect(EFFECT_RESULT_FADED, 111, 601, 0)
  H.advance(2000)
  Verdant.Graph.on_stop_click()

  local view_label = VerdantGraphWindowViewLabel
  local guard = 0
  while view_label._text ~= "BUFFS" and guard < 6 do
    Verdant.Graph.next_view()
    guard = guard + 1
  end
  ok(view_label._text == "BUFFS", "could not reach BUFFS view: " .. tostring(view_label._text))

  ok(VerdantGraphWindowViewportCanvas._hidden ~= true, "main canvas must be visible on BUFFS")
  ok(VerdantGraphWindowViewportSkillArea._hidden == true, "skill area must hide on BUFFS")

  local seg1 = rawget(_G, "VerdantBuffSeg1")
  ok(seg1 and seg1._hidden == false, "no gantt segment rendered")
  local icon1 = rawget(_G, "VerdantBuffIcon1")
  ok(icon1 and icon1._hidden == false, "no row icon rendered")
  local lbl1 = rawget(_G, "VerdantBuffLbl1")
  ok(lbl1 and lbl1._text == "Ability111", "row label wrong: " .. tostring(lbl1 and lbl1._text))

  local alphas = {}
  for i = 1, 10 do
    local seg = rawget(_G, "VerdantBuffSeg" .. i)
    if seg and seg._hidden == false and seg._a then alphas[string.format("%.2f", seg._a)] = true end
  end
  local distinct = 0
  for _ in pairs(alphas) do distinct = distinct + 1 end
  ok(distinct >= 2, "concurrency must modulate segment alpha (distinct=" .. distinct .. ")")

  Verdant.Graph.next_view()
  ok(seg1._hidden == true, "segments must release when leaving BUFFS view")

  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
  Verdant.Graph.on_flush_click()
  Verdant.Metrics.reset()
end
