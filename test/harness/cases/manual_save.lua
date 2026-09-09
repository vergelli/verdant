return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local SS = Verdant.SessionStore
  local sv = Verdant.SavedVars
  local btn = VerdantGraphWindowSaveBtn
  local status = VerdantGraphWindowStatusLabel

  sv.settings = sv.settings or {}
  local before_lib, before_auto = sv.library, sv.settings.session_autosave
  sv.library = { version = 1, sessions = {} }
  sv.settings.session_autosave = false
  SS.init()
  Verdant.Metrics.reset()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()
  H.state.zone = "Fungal Grotto"

  ok(btn ~= nil, "the save button must exist on the graph window")
  ok(type(btn._onOnMouseEnter) == "function", "the save button must explain itself on hover")
  ok(btn._enabled == false, "nothing to save on an empty graph")

  H.chat = {}
  H.sounds = {}
  ok(Verdant.Graph.on_save_click() == false, "saving an empty graph is refused")
  ok(H.sounds[#H.sounds] == ("sound:" .. Verdant.Sound.name("deny")), "refusal plays the negative click")
  ok(H.chat_contains("Nothing to save"), "refusal explains there is nothing to save")
  ok(SS.count() == 0, "no session stored for an empty graph")

  Verdant.Graph.on_record_click()
  H.heal({ hit = 1200 })
  H.advance(1000)
  H.heal({ hit = 1800 })
  H.advance(1000)
  ok(btn._enabled == false, "save is disabled while recording")
  H.chat = {}
  ok(Verdant.Graph.on_save_click() == false, "saving while recording is refused")
  ok(H.chat_contains("Stop the recording"), "refusal explains to stop first")
  ok(SS.count() == 0, "no session stored while recording")

  Verdant.Graph.on_stop_click()
  H.advance(400)
  ok(SS.count() == 0, "with autosave off, stopping stores nothing")
  ok(btn._enabled == true, "a stopped recording can be saved")
  ok(status._text and status._text:find("NOT SAVED", 1, true), "the status line reminds that the recording is not saved, got " .. tostring(status._text))

  H.chat = {}
  H.sounds = {}
  ok(Verdant.Graph.on_save_click() == true, "manual save accepted")
  H.advance(400)
  ok(SS.count() == 1, "manual save stores exactly one session")
  ok(SS.get(1).head.manual == true, "a manual save is marked as such")
  ok(SS.get(1).head.zone == "Fungal Grotto", "the stored session carries the zone")
  ok(H.chat_contains("saved to the library"), "the chat line confirms the save")
  local heard = false
  for _, s in ipairs(H.sounds) do if s == ("sound:" .. Verdant.Sound.name("save")) then heard = true end end
  ok(heard, "a manual save is confirmed with its own sound")
  ok(status._text and status._text:find("SAVED", 1, true) and status._text:find("Fungal Grotto", 1, true),
     "the status line reads SAVED with the zone, got " .. tostring(status._text))
  ok(btn._enabled == false, "the icon goes grey once the recording is saved")
  ok(H.update_registered("VerdantLibPulse"), "the library icon pulses when a session lands")
  H.advance(800)
  ok(not H.update_registered("VerdantLibPulse"), "the pulse ends on its own")
  ok((VerdantGraphWindowLibBtn._alpha or 1) == 1, "the library icon comes back to full alpha")

  H.chat = {}
  H.sounds = {}
  ok(Verdant.Graph.on_save_click() == false, "a second press does not save twice")
  ok(H.sounds[#H.sounds] == ("sound:" .. Verdant.Sound.name("deny")), "the second press plays the negative click")
  ok(H.chat_contains("already in the library"), "the second press explains the recording is already saved")
  ok(SS.count() == 1, "still one session")

  Verdant.Graph.on_record_click()
  H.heal({ hit = 900 })
  H.advance(1000)
  Verdant.Graph.on_stop_click()
  H.advance(400)
  ok(btn._enabled == true, "a new recording can be saved again")

  ok(Verdant.Graph.load_session(SS.get(1)) ~= false, "the saved session loads")
  ok(btn._enabled == false, "a library session cannot be saved again")
  H.chat = {}
  ok(Verdant.Graph.on_save_click() == false, "saving a loaded session is refused")
  ok(SS.count() == 1, "loading and pressing save never duplicates")

  Verdant.Graph.on_flush_click()
  ok(btn._enabled == false, "flushing disables the save icon")

  sv.settings.session_autosave = true
  Verdant.Graph.on_record_click()
  H.heal({ hit = 1500 })
  H.advance(1000)
  Verdant.Graph.on_stop_click()
  H.advance(400)
  ok(SS.count() == 2, "autosave stores the recording")
  ok(SS.get(2).head.manual == nil, "an autosaved session is not marked manual")
  ok(btn._enabled == false, "after autosave the icon is already grey")
  ok(Verdant.Graph.on_save_click() == false, "pressing save after autosave never duplicates")
  ok(SS.count() == 2, "still two sessions")

  Verdant.Library.show()
  ok(VerdantLibraryListEmpty._hidden == true, "the library lists the sessions")
  ok(VerdantLibraryRow1When._text:find("edit_save", 1, true) == nil, "the autosaved row carries no hand glyph")
  ok(VerdantLibraryRow2When._text:find("edit_save", 1, true) ~= nil, "the manual row carries the hand glyph")
  ok(VerdantLibraryRow2Sel._hidden == false, "opening the library lands on the manual session even after a later autosave")
  ok(VerdantLibraryRow1Sel._hidden == true, "an autosave never pre-selects a row")
  Verdant.Library.hide()

  sv.settings.session_autosave = false
  Verdant.Graph.on_flush_click()
  Verdant.Graph.on_record_click()
  H.heal({ hit = 700 })
  H.advance(1000)
  Verdant.Graph.on_stop_click()
  ok(Verdant.Graph.on_save_click() == true, "third manual save accepted")
  H.advance(400)
  ok(SS.count() == 3, "three sessions")
  Verdant.Library.show()
  ok(VerdantLibraryRow1Sel._hidden == false, "opening the library after a manual save lands on that session")
  ok(VerdantLibraryRow1When._text:find("edit_save", 1, true) ~= nil, "and it wears the hand glyph")
  Verdant.Library.on_row_click(2)
  H.state.zone = "Spindleclutch"
  Verdant.Graph.on_flush_click()
  Verdant.Graph.on_record_click()
  H.heal({ hit = 650 })
  H.advance(1000)
  Verdant.Graph.on_stop_click()
  ok(Verdant.Graph.on_save_click() == true, "manual save with the library open")
  H.advance(400)
  ok(SS.count() == 4, "four sessions")
  ok(VerdantLibraryRow1Name._text == "Spindleclutch", "the open library refreshes with the new session first")
  ok(VerdantLibraryRow1Sel._hidden == false, "and selects it, label box ready")
  Verdant.Library.hide()

  Verdant.Graph.on_flush_click()
  sv.library, sv.settings.session_autosave = before_lib, before_auto
  SS.init()
  H.state.zone = nil
  Verdant.Metrics.reset()
end
