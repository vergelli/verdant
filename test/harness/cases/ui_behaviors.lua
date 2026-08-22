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

  local fb = VerdantAssignPanelFlyoutBg
  ok(fb._cr ~= nil and fb._ca and fb._ca > 0.9,
     "flyout backdrop must have a solid center color")
  ok(fb._center_file == nil, "flyout must not use the translucent tooltip center texture")
  ok(VerdantAssignPanelFlyout._draw_level == 100, "flyout must draw above the rows")
  ok(VerdantAssignConfirm._draw_tier == DT_HIGH, "confirm dialog must sit on the high draw tier")
end
