return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.TemporalBuffer.clear()
  Verdant.Visibility.set("graph", false)
  Verdant.Graph.on_record_click()

  for _ = 1, 10 do
    H.heal({ hit = 1000, overflow = 200 })
    H.shield({ hit = 400 })
    H.damage({ hit = 1500 })
    H.advance(1000)
  end

  local TICKS = 50
  local per_tick = H.addon_alloc(function()
    for _ = 1, TICKS do H.advance(1000) end
  end) / TICKS
  local budget = HARNESS_DEBUG and 9000 or 200
  ok(per_tick < budget,
     string.format("sample tick allocates %.0f addon-side bytes (budget %d)", per_tick, budget))

  H.state.grouped = true
  H.state.group_size = 4
  H.state.player_group_tag = "group1"
  H.unit_names = { group1 = "Me", group2 = "Ally2", group3 = "Ally3", group4 = "Ally4" }
  H.fire(EVENT_GROUP_UPDATE)
  local tick_n = 0
  local function ticks()
    for _ = 1, 10 do
      tick_n = tick_n + 1
      local b = tick_n % 6
      H.heal({ hit = 1000, overflow = 200, target_unit_id = 600 + (b % 4) })
      H.effect(EFFECT_RESULT_GAINED, 61700 + b, 600 + (b % 4), (H.now() + 9000) / 1000, nil, "group" .. (1 + b % 4))
      if tick_n % 4 == 0 then H.power("group2", 12000, 40000) end
      if tick_n % 4 == 2 then H.power("group2", 30000, 40000) end
      H.advance(1000)
    end
  end
  local baseline = H.addon_alloc(ticks) / 10
  Verdant.Visibility.set("graph", true)
  local view_label = VerdantGraphWindowViewLabel
  for _, view in ipairs({ "EMS", "SKILL", "CRIT", "OHEAL", "BUFFS", "TRIAGE" }) do
    while view_label._text ~= view do Verdant.Graph.next_view() end
    H.advance(1000)
    local bytes = H.addon_alloc(ticks) / 10 - baseline
    ok(bytes < 400,
       string.format("%s render tick allocates %.0f addon-side bytes over the hidden baseline (budget 400)", view, bytes))
  end
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
  Verdant.Visibility.set("graph", false)

  Verdant.Visibility.set("bar", true)
  local bar_base = H.addon_alloc(ticks) / 10
  for mode = 1, 4 do
    local bytes = H.addon_alloc(ticks) / 10
    ok(bytes - baseline < 250,
       string.format("bar refresh mode %d allocates %.0f addon-side bytes over the hidden baseline (budget 250)", mode, bytes - baseline))
    Verdant.Bar.next_metric()
  end
  Verdant.Visibility.set("bar", false)
  H.state.grouped = false
  H.state.group_size = 1
  H.state.player_group_tag = nil
  H.unit_names = nil

  Verdant.Graph.on_stop_click()
  Verdant.Graph.on_flush_click()
  Verdant.Metrics.reset()
end
