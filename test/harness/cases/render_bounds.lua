return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.TemporalBuffer.clear()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_record_click()
  H.heal({ hit = 500 })
  for _ = 1, 400 do
    H.effect(EFFECT_RESULT_GAINED, 77001, 700, 0)
    H.advance(120)
    H.effect(EFFECT_RESULT_FADED, 77001, 700, 0)
    H.advance(80)
  end
  H.heal({ hit = 400 })
  Verdant.Graph.on_stop_click()

  local rec = Verdant.BuffTracker.get(1)
  ok(rec and rec.n_steps >= 700, "stress curve too small: " .. tostring(rec and rec.n_steps))

  local view_label = VerdantGraphWindowViewLabel
  local guard = 0
  while view_label._text ~= "BUFFS" and guard < 8 do
    Verdant.Graph.next_view()
    guard = guard + 1
  end
  ok(view_label._text == "BUFFS", "could not reach BUFFS view")

  local segs = 0
  for _, c in ipairs(H.controls) do
    if c._hidden == false and c._tex == nil and c._h and c._h >= 10 and c._h <= 34
       and c._w and c._w >= 1 then
      segs = segs + 1
    end
  end
  ok(segs < 300,
     "BUFFS render must stay pixel-bounded regardless of fight length, got " .. segs)

  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
end
