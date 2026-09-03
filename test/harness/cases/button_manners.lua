return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  local BUTTONS = {
    "VerdantGraphWindowRecordBtn", "VerdantGraphWindowStopBtn", "VerdantGraphWindowFlushBtn",
    "VerdantGraphWindowLibBtn", "VerdantGraphWindowPrevViewBtn", "VerdantGraphWindowNextViewBtn",
    "VerdantGraphWindowSettingsBtn", "VerdantGraphWindowBarBtn", "VerdantGraphWindowCloseBtn",
    "VerdantGraphWindowWelcomeOkBtn",
    "VerdantBarWindowPrevBtn", "VerdantBarWindowNextBtn", "VerdantBarWindowModeBtn",
    "VerdantBarWindowSettingsBtn", "VerdantBarWindowGraphBtn", "VerdantBarWindowCloseBtn",
    "VerdantLibraryOpenBtn", "VerdantLibraryLockBtn", "VerdantLibraryDeleteBtn", "VerdantLibraryCloseBtn",
    "VerdantSettingsPanelPSaveBtn", "VerdantSettingsPanelPDeleteBtn", "VerdantSettingsPanelAutoRecBtn",
    "VerdantSettingsPanelAutosaveBtn", "VerdantSettingsPanelLightBtn", "VerdantSettingsPanelShieldDirBtn",
    "VerdantSettingsPanelGdmBtn", "VerdantSettingsPanelUnknownBtn", "VerdantSettingsPanelLogoBtn",
    "VerdantSettingsPanelBarsBtn", "VerdantSettingsPanelResetBtn", "VerdantSettingsPanelCloseBtn",
    "VerdantAssignPanelAssignBtn", "VerdantAssignPanelCloseBtn", "VerdantAssignConfirmYesBtn", "VerdantAssignConfirmNoBtn",
    "VerdantAssignPanelNewCatCreateBtn", "VerdantAssignPanelNewCatCancelBtn",
  }
  for _, name in ipairs(BUTTONS) do
    local c = rawget(_G, name)
    ok(c ~= nil, name .. " must exist after init")
    ok(type(c._onOnMouseEnter) == "function", name .. " must explain itself on hover")
    ok(type(c._onOnMouseExit) == "function", name .. " must hide its tooltip on exit")
    H.last_tooltip = nil
    c._onOnMouseEnter(c)
    ok(type(H.last_tooltip) == "string" and #H.last_tooltip > 3, name .. " tooltip must carry text")
    c._onOnMouseExit(c)
  end

  local function last_sound() return H.sounds and H.sounds[#H.sounds] or nil end
  local function clear() H.sounds = {} end

  Verdant.Metrics.reset()
  Verdant.Visibility.set("graph", false)
  clear()
  Verdant.Graph.toggle()
  ok(last_sound() == "sound:ARMORY_OPEN", "opening the graph sounds like a window opening")
  clear()
  Verdant.Graph.on_record_click()
  ok(last_sound() == "sound:DIALOG_ACCEPT", "record confirms with the accept sound")
  H.heal({ hit = 1000 })
  H.advance(1000)
  clear()
  Verdant.Graph.on_stop_click()
  ok(last_sound() == "sound:DIALOG_ACCEPT", "stop confirms with the accept sound")
  clear()
  Verdant.Graph.on_flush_click()
  ok(last_sound() == "sound:DIALOG_DECLINE", "flush sounds like a decline")
  clear()
  Verdant.Graph.on_close_click()
  ok(last_sound() == "sound:ADVENTURE_ZONE_OVERVIEW_CLOSED", "closing the graph sounds like a window closing")

  clear()
  Verdant.Settings.toggle()
  ok(last_sound() == "sound:ARMORY_OPEN", "settings opens with the window sound")
  clear()
  Verdant.Settings.toggle()
  ok(last_sound() == "sound:ADVENTURE_ZONE_OVERVIEW_CLOSED", "settings closes with the window sound")

  clear()
  Verdant.Library.toggle()
  ok(last_sound() == "sound:ARMORY_OPEN", "library opens with the window sound")
  clear()
  Verdant.Library.toggle()
  ok(last_sound() == "sound:ADVENTURE_ZONE_OVERVIEW_CLOSED", "library closes with the window sound")
  clear()
  Verdant.Library.hide()
  ok(last_sound() == nil, "hiding an already hidden library stays silent")

  Verdant.Metrics.reset()
end
