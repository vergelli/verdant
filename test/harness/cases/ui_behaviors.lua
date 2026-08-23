return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  local g = VerdantGraphWindow
  g._hidden = false
  g._w, g._h = 420, 312
  local p = VerdantSettingsPanel
  p._hidden = true

  Verdant.Settings.toggle()
  ok(p._hidden == false, "settings panel did not open")
  local gr = H.layout(g)
  local pr = H.layout(p)
  ok(pr.x == gr.x + gr.w + 8,
     string.format("panel must dock to graph right edge: panel.x=%d graph.right=%d", pr.x, gr.x + gr.w))
  ok(pr.y == gr.y, "panel must align with graph top")
  Verdant.Settings.toggle()

  g._hidden = true
  local b = VerdantBarWindow
  b._hidden = false
  Verdant.Settings.toggle()
  local br = H.layout(b)
  pr = H.layout(p)
  ok(pr.x == br.x + br.w + 8, "panel must dock to bar window when graph is hidden")
  Verdant.Settings.toggle()
  b._hidden = true

  p._hidden = true
  g._hidden = false
  Verdant.Settings.toggle()
  ok(VerdantSettingsPanelSecGraph._text == "GRAPH", "section headers must be titled")
  local track = VerdantSettingsPanelSliderTrackTriage
  H.state.mouse_x = track:GetLeft() + track:GetWidth() * 0.99
  Verdant.Settings.on_triage_track_click(track)
  H.state.mouse_x = 400
  local sv = Verdant.SavedVars
  ok(sv.settings.triage_theta == 0.75,
     "theta slider must persist 0.75, got " .. tostring(sv.settings.triage_theta))
  Verdant.Graph.on_record_click()
  ok(math.abs(Verdant.Triage.theta() - 0.75) < 1e-9, "triage must adopt theta at session start")
  Verdant.Graph.on_stop_click()
  Verdant.Settings.on_reset_click()
  ok(sv.settings.triage_theta == nil, "reset must clear the theta override")
  ok(VerdantSettingsPanelTriageLabel._text == "50%",
     "reset must show the default theta, got " .. tostring(VerdantSettingsPanelTriageLabel._text))
  Verdant.Settings.toggle()
  g._hidden = true

  g._hidden = false
  Verdant.Settings.toggle()
  Verdant.Library.show()
  ok(VerdantSettingsPanel._hidden == false and VerdantLibrary._hidden == false,
     "both aux windows open before the menu test")
  H.scene("inventory", SCENE_SHOWN)
  ok(VerdantSettingsPanel._hidden == true, "settings must hide when a game menu opens")
  ok(VerdantLibrary._hidden == true, "library must hide when a game menu opens")
  H.scene("hud", SCENE_SHOWN)
  ok(VerdantSettingsPanel._hidden == false, "settings must restore when returning to hud")
  ok(VerdantLibrary._hidden == false, "library must restore when returning to hud")
  H.scene("inventory", SCENE_SHOWN)
  H.scene("hud", SCENE_SHOWN)
  Verdant.Library.hide()
  Verdant.Settings.toggle()
  g._hidden = true

  local fb = VerdantAssignPanelFlyoutBg
  ok(fb._cr ~= nil and fb._ca and fb._ca > 0.9,
     "flyout backdrop must have a solid center color")
  ok(fb._center_file == nil, "flyout must not use the translucent tooltip center texture")
  local ff = VerdantAssignPanelFlyoutFill
  ok(ff ~= nil, "flyout must have a solid fill texture as its floor")
  ok(ff._tex ~= nil and ff._tex:find("attributeBar"),
     "flyout fill must use the opaque-strip fill texture (fileless renders NOTHING in game)")
  ok(ff._a and ff._a >= 0.95, "flyout fill must be near-opaque, got " .. tostring(ff._a))
  ok(ff._draw_layer == DL_OVERLAY, "flyout fill must live on the overlay layer")
  ok(VerdantAssignPanelFlyoutBg._draw_layer == DL_OVERLAY,
     "flyout border must live on the overlay layer")
  Verdant.Assign.show()
  local entry = rawget(_G, "VerdantAssignFlyoutE1")
  if entry then
    ok(entry._draw_layer == DL_OVERLAY and entry._draw_level == 103,
       "flyout entries must draw above the row pick buttons")
  end
  Verdant.Assign.hide()
  ok(VerdantAssignPanelFlyout._draw_level == 100, "flyout must draw above the rows")
  ok(VerdantAssignConfirm._draw_tier == DT_HIGH, "confirm dialog must sit on the high draw tier")
end
