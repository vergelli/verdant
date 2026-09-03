return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local BW = Verdant.BuffWatch

  Verdant.Metrics.reset()
  H.combat_state(false)
  H.ability_names = H.ability_names or {}
  H.ability_names[9001] = "Major Courage"

  ok(BW.toggle("Major Courage", 9001) == 3, "first toggle must arm at 3s")
  ok(BW.thr("Major Courage") == 3, "threshold must read back")
  ok(Verdant.SavedVars.settings.buff_watch["Major Courage"] == 3, "watch must persist")
  ok(H.update_registered("VerdantBuffWatch"), "the scan tick must start with the first watch")
  ok(BW.toggle("Major Courage", 9001) == 5, "second toggle must cycle to 5s")

  local end_s = (H.now() + 10000) / 1000
  H.effect(EFFECT_RESULT_GAINED, 9001, 4242, end_s, nil, "player")
  H.advance(1000)
  ok(VerdantWatchOverlay:IsHidden(), "9s remaining sits above the 5s threshold")

  H.sounds = {}
  H.advance(5000)
  ok(not VerdantWatchOverlay:IsHidden(), "4s remaining must raise the banner")
  local soon = 0
  for _, snd in ipairs(H.sounds) do if snd == "sound:NEW_TIMED_NOTIFICATION" then soon = soon + 1 end end
  ok(soon == 1, "entering the warning window chimes exactly once, got " .. soon)
  H.sounds = {}
  H.advance(1000)
  ok(#H.sounds == 0, "staying in the warning window stays quiet")
  ok(VerdantWatchRowName1._text == "Major Courage",
     "banner must name the buff, got " .. tostring(VerdantWatchRowName1._text))
  ok((VerdantWatchRowTime1._text or ""):find("s") ~= nil, "banner must show the countdown")

  H.effect(EFFECT_RESULT_UPDATED, 9001, 4242, (H.now() + 30000) / 1000, nil, "player")
  H.advance(500)
  ok(VerdantWatchOverlay:IsHidden(), "a refresh must clear the banner")

  H.effect(EFFECT_RESULT_FADED, 9001, 4242, 0, nil, "player")
  H.advance(500)
  ok(VerdantWatchOverlay:IsHidden(), "a missing buff out of combat stays silent")

  H.combat_state(true)
  H.advance(500)
  ok(not VerdantWatchOverlay:IsHidden(), "a missing buff in combat must nag")
  ok(VerdantWatchRowTime1._text == "recast!",
     "missing state must read recast, got " .. tostring(VerdantWatchRowTime1._text))
  H.combat_state(false)
  H.advance(500)
  ok(VerdantWatchOverlay:IsHidden(), "leaving combat must drop the nag")

  H.effect(EFFECT_RESULT_GAINED, 9001, 999, (H.now() + 60000) / 1000, nil, "group2")
  H.advance(500)
  ok(VerdantWatchOverlay:IsHidden(), "someone else's aura must not feed the self watch")

  H.effect(EFFECT_RESULT_GAINED, 9002, 4242, end_s, nil, "player")

  ok(BW.toggle("Major Courage") == 8, "third toggle must cycle to 8s")
  ok(BW.toggle("Major Courage") == nil, "fourth toggle must disarm")
  ok(not H.update_registered("VerdantBuffWatch"), "the scan tick must stop with the last watch")
  ok(Verdant.SavedVars.settings.buff_watch["Major Courage"] == nil, "disarm must unpersist")

  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()
  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
  Verdant.Graph.on_record_click()
  H.effect(EFFECT_RESULT_GAINED, 9001, 700, 0, nil, "group1")
  H.heal({ hit = 500 })
  H.advance(2000)
  H.effect(EFFECT_RESULT_FADED, 9001, 700, 0, nil, "group1")
  H.advance(1000)
  Verdant.Graph.on_stop_click()
  while view_label._text ~= "BUFFS" do Verdant.Graph.next_view() end

  local function star_visible()
    for _, c in ipairs(H.controls) do
      if c._hidden == false and c._tex == "EsoUI/Art/Collections/Favorite_StarOnly.dds" then
        return true
      end
    end
    return false
  end
  ok(not star_visible(), "stars stay hidden until a row is armed or hovered")

  local canvas = VerdantGraphWindowViewportCanvas
  local chip_h = (VerdantGraphSummaryBg._hidden == false) and (VerdantGraphSummaryBg._h + 8) or 0
  H.state.mouse_x = canvas:GetLeft() + 5
  H.state.mouse_y = canvas:GetTop() + chip_h + 5
  local hit = VerdantGraphHitMain
  hit._onOnMouseUp(hit, 1, true)
  ok(BW.thr("Major Courage") == 3, "clicking the star gutter must arm the watch")
  ok(H.chat_contains("recast warning below") ~= nil, "arming must confirm in chat")

  ok(star_visible(), "armed rows must show the gold star")

  while BW.thr("Major Courage") do BW.toggle("Major Courage") end
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  Verdant.Metrics.reset()
end
