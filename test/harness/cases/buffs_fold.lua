return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local sv = Verdant.SavedVars
  sv.settings = sv.settings or {}
  local before = sv.settings.buffs_unfolded
  sv.settings.buffs_unfolded = nil

  local function visible_texts()
    local t = {}
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false and name:find("^VerdantBuffLbl") and c._text then t[c._text] = (t[c._text] or 0) + 1 end
    end
    return t
  end
  local function visible_icons()
    local n = 0
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false and name:find("^VerdantBuffIcon") then n = n + 1 end
    end
    return n
  end
  local function goto_buffs()
    local view_label = VerdantGraphWindowViewLabel
    local guard = 0
    while view_label._text ~= "BUFFS" and guard < 8 do Verdant.Graph.next_view(); guard = guard + 1 end
    ok(view_label._text == "BUFFS", "could not reach BUFFS")
  end

  Verdant.Metrics.reset()
  Verdant.TemporalBuffer.clear()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()
  H.ability_names = { [301] = "Major Sorcery", [302] = "Minor Resolve", [303] = "Major Prophecy", [304] = "Short Burst" }

  Verdant.Graph.on_record_click()
  H.heal({ hit = 500 })
  H.effect(EFFECT_RESULT_GAINED, 301, 600, 0)
  H.effect(EFFECT_RESULT_GAINED, 302, 600, 0)
  H.effect(EFFECT_RESULT_GAINED, 303, 600, 0)
  H.advance(4000)
  H.effect(EFFECT_RESULT_GAINED, 304, 600, 0)
  H.advance(2000)
  H.effect(EFFECT_RESULT_FADED, 304, 600, 0)
  H.advance(4000)
  H.effect(EFFECT_RESULT_FADED, 301, 600, 0)
  H.effect(EFFECT_RESULT_FADED, 302, 600, 0)
  H.effect(EFFECT_RESULT_FADED, 303, 600, 0)
  Verdant.Graph.on_stop_click()

  goto_buffs()
  local SC = Verdant.SkillColors
  ok(SC.buff_family("Major Sorcery") == "offense" and SC.buff_family("Minor Resolve") == "defense"
     and SC.buff_family("Major Intellect") == "sustain" and SC.buff_family("Major Expedition") == "mobility",
     "named buffs map to their family")
  ok(SC.buff_family("Short Burst") == nil and SC.buff_family("") == nil and SC.buff_family(nil) == nil,
     "anything else has no family")
  local off = SC.buff_family_color("Major Sorcery")
  ok(off and off.r > 0.9 and off.b < 0.5, "offense wears the warm colour")
  local texts = visible_texts()
  ok(texts["[+] 3 always on"] == 1, "three permanent buffs fold into the strip, texts: " .. tostring(next(texts)))
  ok(texts["Short Burst"] == 1, "the situational buff keeps its lane")
  ok(texts["Major Sorcery"] == nil, "a folded buff has no lane label")
  ok(visible_icons() == 4, "three strip icons plus one lane icon, got " .. visible_icons())

  local canvas = VerdantGraphWindowViewportCanvas
  local hit    = VerdantGraphHitMain
  local chip_h = (VerdantGraphSummaryBg._hidden == false) and (VerdantGraphSummaryBg._h + 8) or 0
  H.state.mouse_x = canvas:GetLeft() + 176 + 9
  H.state.mouse_y = canvas:GetTop() + chip_h + 12
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VerdantHoverCardName._text == "Major Sorcery", "hovering a strip icon names the buff, got " .. tostring(VerdantHoverCardName._text))
  ok(VerdantHoverCardStat._text and VerdantHoverCardStat._text:find("100%%"), "the card shows its uptime, got " .. tostring(VerdantHoverCardStat._text))
  ok(VerdantHoverCardName._r and VerdantHoverCardName._r > 0.9, "the card name wears the family colour")
  local fam_row = false
  for _, c in ipairs(H.controls) do
    if c._hidden == false and c._text == "Offense: damage and healing done" then fam_row = true end
  end
  ok(fam_row, "the card names the family")

  H.state.mouse_x = canvas:GetLeft() + 40
  H.sounds = {}
  hit._onOnMouseUp(hit, nil, true)
  ok(sv.settings.buffs_unfolded == true, "clicking the strip unfolds and persists")
  ok(H.sounds[#H.sounds] == ("sound:" .. Verdant.Sound.name("on")), "unfolding confirms with a sound")
  texts = visible_texts()
  ok(texts["[-] 3 always on"] == 1, "the strip reads unfolded")
  ok(texts["Major Sorcery"] == 1 and texts["Minor Resolve"] == 1 and texts["Major Prophecy"] == 1, "unfolded buffs get their lanes back")
  ok(texts["Short Burst"] == 1, "the situational lane stays")

  hit._onOnMouseUp(hit, nil, true)
  ok(sv.settings.buffs_unfolded == false, "clicking again folds")
  ok(visible_texts()["[+] 3 always on"] == 1, "folded again")
  hit._onOnMouseExit(hit)
  H.state.mouse_x, H.state.mouse_y = 400, 300

  Verdant.Graph.on_flush_click()
  Verdant.Graph.on_record_click()
  H.heal({ hit = 500 })
  H.effect(EFFECT_RESULT_GAINED, 301, 600, 0)
  H.advance(5000)
  H.effect(EFFECT_RESULT_GAINED, 304, 600, 0)
  H.advance(1000)
  H.effect(EFFECT_RESULT_FADED, 304, 600, 0)
  H.effect(EFFECT_RESULT_FADED, 301, 600, 0)
  Verdant.Graph.on_stop_click()
  goto_buffs()
  texts = visible_texts()
  ok(texts["[+] 1 always on"] == nil and texts["Major Sorcery"] == 1, "a single permanent buff is not worth a strip")

  Verdant.Graph.on_flush_click()
  Verdant.Graph.on_record_click()
  H.heal({ hit = 500 })
  H.effect(EFFECT_RESULT_GAINED, 301, 600, 0)
  H.effect(EFFECT_RESULT_GAINED, 302, 600, 0)
  H.advance(3000)
  goto_buffs()
  ok(visible_texts()["[+] 2 always on"] == nil, "no strip while recording")
  Verdant.Graph.on_stop_click()
  Verdant.Graph.on_flush_click()

  sv.settings.buffs_unfolded = before
  H.ability_names = nil
  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
  Verdant.Metrics.reset()
end
