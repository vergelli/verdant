return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()
  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end

  H.slotted = {
    [HOTBAR_CATEGORY_PRIMARY] = { [8] = 41001 },
    [HOTBAR_CATEGORY_BACKUP]  = { [8] = 41002 },
  }
  H.state.ult_costs = { [HOTBAR_CATEGORY_PRIMARY] = 250, [HOTBAR_CATEGORY_BACKUP] = 400 }
  H.ability_icons = H.ability_icons or {}
  H.ability_icons[41001] = "EsoUI/Art/Icons/ult_front.dds"
  H.ability_icons[41002] = "EsoUI/Art/Icons/ult_back.dds"
  H.state.active_bar = HOTBAR_CATEGORY_PRIMARY

  Verdant.Graph.on_record_click()
  local v = 0
  for _ = 1, 20 do
    v = v + 25
    H.ult_power(v)
    H.heal({ hit = 1000 })
    H.advance(1000)
  end
  H.state.active_bar = HOTBAR_CATEGORY_BACKUP
  H.fire(EVENT_ACTIVE_WEAPON_PAIR_CHANGED, 2, true)
  H.advance(1000)
  H.state.active_bar = HOTBAR_CATEGORY_PRIMARY
  H.fire(EVENT_ACTIVE_WEAPON_PAIR_CHANGED, 1, true)
  H.ult_used()
  H.ult_power(0)
  for _ = 1, 5 do
    H.heal({ hit = 1000 })
    H.advance(1000)
  end
  Verdant.Graph.on_stop_click()

  local snap = Verdant.Ultimate.snapshot()
  ok(snap.costs[1] == 250 and snap.costs[2] == 400, "both bars must carry their own ultimate cost, got " .. tostring(snap.costs[1]) .. "/" .. tostring(snap.costs[2]))
  ok(snap.bars[1] == 41001 and snap.bars[2] == 41002, "both bars must know their ultimate")
  ok(snap.steps > 10, "power updates must build the charge curve, steps=" .. snap.steps)
  ok(snap.used == 1, "the cast must register exactly once, used=" .. snap.used)
  ok(snap.abilities == 2, "one ability record per bar at session start, got " .. snap.abilities)
  local ut, ub = Verdant.Ultimate.used()
  ok(ub[1] == 1, "the cast must be attributed to the front bar")
  if HARNESS_DEBUG then
    ok(Verdant.Diagnostics.get("ult.power_updates") >= 21, "diag counter must expose the update rate")
  end
  local st = Verdant.Ultimate.steps()
  ok(Verdant.Ultimate.pct_at(st[1], 1) <= 0.2, "charge starts near zero")
  ok(Verdant.Ultimate.pct_at(st[1] + 19500, 1) >= 1, "front bar (cost 250) must be ready at 500 power")
  ok(Verdant.Ultimate.pct_at(st[1] + 14500, 2) < 1, "back bar (cost 400) must still be charging at 375 power")

  local rows, ready, charging, tick = {}, {}, false, false
  local icons = {}
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VerdantGraphUlt") and not name:find("Top") then
      if name:find("Icon") then
        icons[#icons + 1] = c._tex
      elseif c._h == 5 and c._r then
        local y = c._anchor_list and c._anchor_list[1].oy
        rows[y] = true
        if c._r > 0.95 and c._g > 0.85 and c._b < 0.5 then ready[y] = true end
        if c._r < 0.9 and c._g > 0.9 then charging = true end
      elseif c._h == 9 and c._w == 2 then
        tick = true
      end
    end
  end
  local n_rows = 0
  for _ in pairs(rows) do n_rows = n_rows + 1 end
  ok(n_rows == 2, "two ultimates must draw two rows, got " .. n_rows)
  ok(ready[3] == true, "the front bar row must show the bright ready state")
  ok(ready[13] == true, "the back bar reaches its cost too and must show ready")
  ok(charging, "charging segments must render in the viewport green")
  ok(tick, "the cast must render as a tick over its row")
  ok(#icons == 2 and icons[1] == "EsoUI/Art/Icons/ult_front.dds" and icons[2] == "EsoUI/Art/Icons/ult_back.dds",
     "each row must wear its own ultimate icon")

  local canvas = VerdantGraphWindowViewportCanvas
  local ch = canvas:GetHeight()
  local top_most = ch
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VerdantGraphFillEhps") and c._h and c._h > 0 then
      if ch - 18 - c._h < top_most then top_most = ch - 18 - c._h end
    end
  end
  ok(top_most >= 22, "bars must stay below the ultimate area, top at " .. tostring(top_most))

  local session = Verdant.SessionStore.capture()
  ok(session and session.streams.ult ~= nil and session.streams.ulta ~= nil, "session must persist the ultimate streams")
  ok(Verdant.Graph.load_session(session), "captured session must reload")
  local snap2 = Verdant.Ultimate.snapshot()
  ok(snap2.steps == snap.steps, "reloaded session must keep the charge curve")
  ok(snap2.used == 1, "reloaded session must keep the cast")
  ok(snap2.abilities == 2, "reloaded session must keep both bars")
  ok(Verdant.Ultimate.cost_at(2, st[1] + 1000) == 400, "reloaded session must keep the back bar cost")
  ok(Verdant.Ultimate.has_data(), "the band must render for the loaded session")
  local icons2 = 0
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VerdantGraphUltIcon") and not name:find("Top") then icons2 = icons2 + 1 end
  end
  ok(icons2 == 2, "loaded session must draw both icons again")

  Verdant.Graph.on_flush_click()
  ok(not Verdant.Ultimate.has_data(), "flush must clear the ultimate session")

  Verdant.Graph.on_record_click()
  for _ = 1, 3 do
    H.heal({ hit = 1000 })
    H.advance(1000)
  end
  local ghost = false
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VerdantGraphUlt") and not name:find("Top") then ghost = true end
  end
  ok(not ghost, "without a single power update the band must not draw at all")
  Verdant.Graph.on_stop_click()
  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  H.slotted = nil
  H.state.ult_costs = nil
  H.state.active_bar = nil
  Verdant.Metrics.reset()
end
