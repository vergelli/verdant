return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local S  = Verdant.Settings
  local SS = Verdant.SessionStore

  Verdant.Metrics.reset()
  Verdant.TemporalBuffer.clear()
  Verdant.Visibility.set("graph", true)
  local g = VerdantGraphWindow

  g:SetDimensions(520, 400)
  H.state.mouse_x, H.state.mouse_y = g:GetLeft() + 100, g:GetTop() + 80
  Verdant.Graph.on_title_double_click()
  ok(g:GetWidth() == 520, "a double click below the title bar leaves the size alone")
  H.state.mouse_y = g:GetTop() + 10
  Verdant.Graph.on_title_double_click()
  ok(g:GetWidth() == 420 and g:GetHeight() == 312, "a double click on the title bar restores the default size")
  ok(Verdant.SavedVars.temporal.graph_w == 420, "the restored size persists")
  local xml = assert(io.open("ui/graph.xml")):read("*a")
  ok(xml:find("<OnMouseDoubleClick>Verdant.Graph.on_title_double_click()", 1, true) ~= nil, "the graph window wires the double click")

  local lbl = VerdantGraphWindowViewLabel
  while lbl._text ~= "EMS" do Verdant.Graph.next_view() end
  ok(type(lbl._onOnMouseUp) == "function", "the view name is clickable")
  lbl._onOnMouseUp(lbl, MOUSE_BUTTON_INDEX_LEFT, true)
  ok(lbl._text ~= "EMS", "a left click on the view name moves to the next view: " .. tostring(lbl._text))
  lbl._onOnMouseUp(lbl, MOUSE_BUTTON_INDEX_RIGHT, true)
  ok(lbl._text == "EMS", "a right click on the view name moves back")
  lbl._onOnMouseUp(lbl, MOUSE_BUTTON_INDEX_LEFT, false)
  ok(lbl._text == "EMS", "a release outside the label does nothing")

  local p = VerdantSettingsPanel
  if p._hidden ~= false then S.toggle() end
  Verdant.Library.show()
  ok(p._hidden == false and VerdantLibrary._hidden == false, "settings and library open")
  H.escape()
  ok(p._hidden == true and VerdantLibrary._hidden == true, "Escape closes the aux windows through the scene manager")
  Verdant.Assign.show()
  ok(VerdantAssignPanel._hidden == false, "assign opens")
  H.escape()
  ok(VerdantAssignPanel._hidden == true, "Escape closes the assign window")

  S.toggle()
  ok(p._hidden == false, "settings reopen after Escape")
  S.on_reset_click()
  local ts = VerdantSettingsPanelSliderTrackTWindow
  local ss = VerdantSettingsPanelSliderTrackSample
  local fill_s = VerdantSettingsSampleFill
  local fill_t = VerdantSettingsTWindowFill
  local function heavy_tint() return fill_s._r > 0.8 and fill_t._r > 0.8 end

  H.state.mouse_x = ts:GetLeft() + ts:GetWidth() * 0.999
  S.on_twindow_track_click(ts)
  ok(S.snapshot().time_window_s == 1200, "the window slider reaches 20 minutes, got " .. tostring(S.snapshot().time_window_s))
  ok(not S.is_heavy_combo() and not heavy_tint(), "20 minutes at 1 Hz stays within the safe tint")
  ok(VerdantSettingsConfirm._hidden == true, "no question for a safe combination")

  H.state.mouse_x = ss:GetLeft() + ss:GetWidth() * 0.999
  S.on_sample_track_click(ss)
  ok(S.is_heavy_combo() and heavy_tint(), "5 Hz over 20 minutes tints the sliders red")
  ok(VerdantSettingsConfirm._hidden == false, "an experimental combination asks first")
  local msg = VerdantSettingsConfirmMsg._text or ""
  ok(msg:find("1 Hz", 1, true) and msg:find("6000", 1, true), "the question states the cost and the recommendation: " .. msg)
  S.on_confirm_no()
  ok(VerdantSettingsConfirm._hidden == true, "Go back closes the question")
  ok(S.snapshot().sample_rate_ms == 1000 and S.snapshot().time_window_s == 1200, "Go back restores the previous values")
  ok(not heavy_tint(), "the tint follows the restored values")

  S.on_sample_track_click(ss)
  S.on_confirm_yes()
  ok(S.snapshot().sample_rate_ms == 200 and heavy_tint(), "Keep it anyway leaves the combination in place, still red")
  ok(VerdantSettingsConfirm._hidden == true, "the question closes on Keep")

  H.state.mouse_x = ts:GetLeft() + ts:GetWidth() * 0.5
  S.on_twindow_track_click(ts)
  ok(VerdantSettingsConfirm._hidden == true, "shrinking a heavy window does not ask again")
  S.on_reset_click()
  ok(not S.is_heavy_combo() and not heavy_tint(), "reset returns to the safe tint")
  H.state.mouse_x = nil

  local sxml = assert(io.open("ui/settings.xml")):read("*a")
  ok(sxml:find("<OnEnter>Verdant.Settings.on_profile_save_click()", 1, true) ~= nil, "Enter saves the profile name")
  ok(sxml:find("Verdant.Settings.on_pname_focus(true)", 1, true) ~= nil, "the profile name box lights up on focus")
  S.on_pname_focus(true)
  S.on_pname_focus(false)
  S.toggle()

  Verdant.Library.show()
  local n0 = SS.count()
  for _, z in ipairs({ "KeyA", "KeyB", "KeyC" }) do
    SS.store({ head = { locked = false, zone = z, ts = 1755900000, dur_ms = 1000, group_size = 0,
                        sum = { avg = 0, peak = 0, saves = 0, o = 0, l = 0, m = 0 } }, streams = {} })
  end
  Verdant.Library.refresh()
  ok(Verdant.Library.on_key(KEY_DOWNARROW) == true, "Down selects when nothing is selected")
  ok(VerdantLibraryRow1Sel._hidden == false, "Down from nothing selects the top row")
  Verdant.Library.on_key(KEY_DOWNARROW)
  ok(VerdantLibraryRow2Sel._hidden == false and VerdantLibraryRow1Sel._hidden == true, "Down moves the selection one row")
  Verdant.Library.on_key(KEY_UPARROW)
  ok(VerdantLibraryRow1Sel._hidden == false, "Up moves it back")

  Verdant.Library.on_row_enter(2)
  ok(VerdantLibraryRow2Hov._hidden == false, "hovering a row highlights it")
  Verdant.Library.on_row_exit(2)
  ok(VerdantLibraryRow2Hov._hidden == true, "leaving a row clears the highlight")

  Verdant.Library.on_key(KEY_DELETE)
  ok(VerdantLibraryDeleteBtn._text == "Delete?", "Delete arms")
  H.advance(3500)
  ok(VerdantLibraryDeleteBtn._text == "Delete", "an armed Delete disarms on its own after a few seconds")
  ok(SS.count() == n0 + 3, "nothing was deleted by the timeout")

  Verdant.Graph.on_flush_click()
  Verdant.Library.on_row_click(1)
  ok(Verdant.Library.on_key(KEY_ENTER) == true, "Enter opens the selected session")
  Verdant.Library.on_key(KEY_ESCAPE)
  ok(VerdantLibrary._hidden == true, "Escape closes the library")

  for _ = 1, 3 do
    Verdant.Library.show()
    Verdant.Library.on_row_click(1)
    Verdant.Library.on_delete_click()
    Verdant.Library.on_delete_click()
  end
  ok(SS.count() == n0, "the key test sessions are gone")
  Verdant.Library.hide()
  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  Verdant.Metrics.reset()
end
