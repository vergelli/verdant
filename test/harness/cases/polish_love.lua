return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local sv = Verdant.SavedVars
  sv.settings = sv.settings or {}
  local before_auto = sv.settings.session_autosave
  sv.settings.session_autosave = false

  Verdant.Metrics.reset()
  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  ok(VerdantGraphWindow._hidden == true, "graph starts hidden for the fade test")
  Verdant.Visibility.set("graph", true)
  ok(VerdantGraphWindow._hidden == false, "the graph shows")
  ok((VerdantGraphWindow._alpha or 1) == 1, "the fade lands on full alpha")
  Verdant.Visibility.set("graph", false)
  Verdant.Visibility.set("graph", true)
  ok((VerdantGraphWindow._alpha or 1) == 1, "a second open fades in again and lands on full alpha")

  ok(not Verdant.Logo.is_beating(), "the logo rests while nothing records")
  Verdant.Graph.on_record_click()
  H.heal({ hit = 800 })
  H.advance(1000)
  Verdant.Visibility.set("graph", false)
  ok(Verdant.Logo.is_beating(), "the logo breathes while a recording runs and the graph is closed")
  Verdant.Logo.on_enter()
  ok(not Verdant.Logo.is_beating(), "hovering the logo pauses the heartbeat")
  Verdant.Logo.on_exit()
  ok(Verdant.Logo.is_beating(), "leaving the logo resumes the heartbeat")
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_stop_click()
  ok(not Verdant.Logo.is_beating(), "Stop ends the heartbeat")
  local status = VerdantGraphWindowStatusLabel
  ok(status._text and status._text:find("NOT SAVED", 1, true), "status reads NOT SAVED")
  ok(status._r and status._r > 0.9 and status._b and status._b < 0.5, "NOT SAVED is amber")
  ok(H.update_registered("VerdantSavePulse"), "the save icon pulses once after an unsaved stop")
  H.advance(800)
  ok(not H.update_registered("VerdantSavePulse"), "the pulse ends on its own")
  ok((VerdantGraphWindowSaveBtn._alpha or 1) == 1, "the save icon comes back to full alpha")
  Verdant.Graph.on_save_click()
  H.advance(400)
  ok(status._r and status._r < 0.7, "SAVED goes back to the quiet grey")

  Verdant.Graph.on_flush_click()
  Verdant.Graph.on_record_click()
  ok(status._r and status._r < 0.7, "a new recording resets the status colour")
  H.ability_names = { [9901] = "Alpha Heal", [9902] = "Beta Heal" }
  for _ = 1, 4 do
    H.heal({ hit = 3000, ability_id = 9901 })
    H.heal({ hit = 1000, ability_id = 9902 })
    H.advance(1000)
  end
  Verdant.Graph.on_stop_click()
  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "CONTRIB" do Verdant.Graph.next_view() end
  local canvas = VerdantGraphWindowViewportCanvas
  local hit    = VerdantGraphHitMain
  local chip_h = (VerdantGraphSummaryBg._hidden == false) and (VerdantGraphSummaryBg._h + 8) or 0
  local function band_count()
    local n = 0
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false and name:find("^VerdantBuffSeg") and c._h == 26 and c._a and math.abs(c._a - 0.10) < 1e-6 then n = n + 1 end
    end
    return n
  end
  local function rim_count()
    local n = 0
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false and name:find("^VerdantBuffRim") and c._h == 7 then n = n + 1 end
    end
    return n
  end
  ok(band_count() == 0, "no hover band before hovering")
  ok(rim_count() == 2, "every contribution bar wears a rim, got " .. rim_count())
  H.state.mouse_x = canvas:GetLeft() + 60
  H.state.mouse_y = canvas:GetTop() + chip_h + 20 + 12
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(Verdant.ContribView.hovered() ~= nil and Verdant.ContribView.hovered().name == "Alpha Heal", "the hovered row is tracked")
  ok(band_count() == 1, "the hovered row wears a band")
  H.state.mouse_y = canvas:GetTop() + canvas:GetHeight() + 40
  H.advance(200)
  ok(Verdant.ContribView.hovered() == nil and band_count() == 0, "leaving the rows clears the band")
  hit._onOnMouseExit(hit)
  H.state.mouse_x, H.state.mouse_y = 400, 300

  Verdant.Graph.on_flush_click()
  Verdant.Graph.on_record_click()
  H.heal({ hit = 500 })
  H.effect(EFFECT_RESULT_GAINED, 111, 600, 0)
  H.advance(3000)
  H.effect(EFFECT_RESULT_FADED, 111, 600, 0)
  H.advance(1500)
  H.effect(EFFECT_RESULT_GAINED, 111, 600, 0)
  H.effect(EFFECT_RESULT_GAINED, 111, 601, 0)
  H.advance(3000)
  H.effect(EFFECT_RESULT_FADED, 111, 600, 0)
  H.effect(EFFECT_RESULT_FADED, 111, 601, 0)
  H.advance(1000)
  Verdant.Graph.on_stop_click()
  while view_label._text ~= "BUFFS" do Verdant.Graph.next_view() end
  local uptime_bars, levels = 0, {}
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VerdantBuffSeg") then
      if c._h == 3 then uptime_bars = uptime_bars + 1 end
      if c._a and (math.abs(c._a - 0.92) < 1e-6 or math.abs(c._a - 0.50) < 1e-6) then levels[string.format("%.2f", c._a)] = true end
    end
  end
  ok(uptime_bars >= 2, "each buff row draws an uptime track and fill, got " .. uptime_bars)
  ok(levels["0.92"] and levels["0.50"], "holder concurrency renders in two levels")

  ok(GetString(VERDANT_GRAPH_NO_DATA):find("rec.dds", 1, true), "the graph's empty state shows the Record glyph")
  ok(GetString(VERDANT_LIB_EMPTY):find("edit_save_up", 1, true), "the library's empty state shows the Save glyph")

  Verdant.Graph.on_flush_click()
  H.ability_names = nil
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
  sv.settings.session_autosave = before_auto
  Verdant.Metrics.reset()
end
