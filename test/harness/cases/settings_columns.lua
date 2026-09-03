return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  local svg = dofile(HARNESS_ROOT .. "/test/simlab/svg.lua")
  svg.apply_xml(HARNESS_ROOT .. "/ui/settings.xml")

  local panel = H.layout(VerdantSettingsPanel)
  ok(panel.w == 600 and panel.h == 432,
     string.format("panel must be 600x432, got %dx%d", panel.w, panel.h))

  local left_col = {
    VerdantSettingsPanelSliderTrack,
    VerdantSettingsPanelSliderTrackHeal,
    VerdantSettingsPanelSliderTrackShield,
    VerdantSettingsPanelAutoRecBtn,
    VerdantSettingsPanelAutosaveBtn,
  }
  local right_col = {
    VerdantSettingsPanelSliderTrackSample,
    VerdantSettingsPanelSliderTrackTWindow,
    VerdantSettingsPanelSliderTrackVPAlpha,
    VerdantSettingsPanelSliderTrackTriage,
    VerdantSettingsPanelShieldDirBtn,
    VerdantSettingsPanelGdmBtn,
    VerdantSettingsPanelLogoBtn,
    VerdantSettingsPanelBarsBtn,
  }

  for _, c in ipairs(left_col) do
    local r = H.layout(c)
    ok(r.x == panel.x + 14, (c._name or "?") .. " must sit in the left column, x=" .. r.x)
    ok(r.x + r.w <= panel.x + 290, (c._name or "?") .. " must not bleed into the right column")
  end
  for _, c in ipairs(right_col) do
    local r = H.layout(c)
    ok(r.x == panel.x + 314, (c._name or "?") .. " must sit in the right column, x=" .. r.x)
    ok(r.x + r.w <= panel.x + 590, (c._name or "?") .. " must stay inside the panel")
  end

  for _, c in ipairs(right_col) do
    local r = H.layout(c)
    ok(r.y + r.h <= panel.y + panel.h - 30, (c._name or "?") .. " must clear the reset row")
  end

  Verdant.Settings.toggle()
  ok(not VerdantSettingsPanel:IsHidden(), "panel must open")
  local lbl = VerdantSettingsPanelRateLabel._text
  ok(lbl ~= nil and lbl ~= "", "sliders must refresh with the new track geometry")
  Verdant.Settings.toggle()
end
