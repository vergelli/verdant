return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local SS = Verdant.SessionStore
  local sv = Verdant.SavedVars

  sv.settings = sv.settings or {}
  sv.library = { version = 1, sessions = {} }
  sv.settings.session_autosave = true
  H.state.grouped = true
  H.state.group_size = 3
  H.state.player_group_tag = "group1"
  H.state.zone = "Direfrost Keep"
  H.unit_names = { group1 = "Me1", group2 = "Ally2", group3 = "Ally3" }
  H.fire(EVENT_GROUP_UPDATE)

  Verdant.Graph.on_record_click()
  H.heal({ hit = 900, target_name = "Ally2", target_unit_id = 602 })
  H.effect(EFFECT_RESULT_GAINED, 111, 602, 0)
  H.advance(1200)
  H.power("group2", 15000, 40000)
  H.advance(400)
  H.heal({ hit = 3000, target_name = "Ally2", target_unit_id = 602 })
  H.power("group2", 25000, 40000)
  H.advance(2600)
  H.effect(EFFECT_RESULT_FADED, 111, 602, 0)
  H.advance(1500)

  H.unit_names = {}
  H.state.grouped = false
  H.state.group_size = 0
  H.state.zone = "Elsweyr"
  H.fire(EVENT_GROUP_MEMBER_LEFT)
  H.advance(500)

  Verdant.Graph.on_stop_click()
  H.advance(400)
  ok(SS.count() == 1, "session must autosave")
  local saved = SS.get(1)
  ok(#saved.roster == 3, "roster must survive mid-session disband, got " .. #saved.roster)
  ok(saved.head.zone == "Direfrost Keep",
     "zone must be captured at session start, got " .. tostring(saved.head.zone))
  ok(saved.head.group_size >= 3, "group size must fall back to roster count")

  local live_tb  = Verdant.TemporalBuffer.summary()
  local live_tri = Verdant.Triage.summary()
  local live_bt  = Verdant.BuffTracker.count()

  Verdant.Graph.on_flush_click()
  ok(Verdant.TemporalBuffer.count() == 0, "flush must empty the buffer")

  Verdant.Library.show()
  ok(VerdantLibrary._hidden == false, "library window must show")
  ok(VerdantLibraryRow1Name._text == "Direfrost Keep",
     "row must show the zone, got " .. tostring(VerdantLibraryRow1Name._text))
  ok(saved.head.difficulty ~= nil, "session head must carry the dungeon difficulty")
  ok(VerdantLibraryRow1Vet._hidden == ((saved.head.difficulty or 0) ~= 2), "the veteran badge follows the difficulty")
  Verdant.Library.on_row_click(1)
  H.sounds = {}
  VerdantLibraryLabelBoxEdit:SetText("  Sunday HM run  ")
  Verdant.Library.on_label_save()
  ok(H.sounds[#H.sounds] == "sound:DIALOG_ACCEPT", "naming confirms with the accept sound")
  ok(SS.get(1).head.label == "Sunday HM run", "the label is trimmed and persisted on the session head")
  ok(VerdantLibraryRow1Name._text == "Sunday HM run", "the row shows the name instead of the zone")
  VerdantLibraryLabelBoxEdit:SetText("")
  Verdant.Library.on_label_save()
  ok(SS.get(1).head.label == nil and VerdantLibraryRow1Name._text == "Direfrost Keep", "an empty name goes back to the zone")
  ok(type(VerdantLibraryRow1._onOnMouseDoubleClick) == "function", "rows open on double click")
  VerdantLibraryRow1._onOnMouseDoubleClick(VerdantLibraryRow1)
  ok(VerdantLibrary._hidden == true, "library must hide after open")

  local tb2  = Verdant.TemporalBuffer.summary()
  local tri2 = Verdant.Triage.summary()
  ok(tb2.count == live_tb.count, "reloaded sample count differs")
  ok(math.abs(tb2.avg_ems - live_tb.avg_ems) < 1, "reloaded avg differs: "
     .. tb2.avg_ems .. " vs " .. live_tb.avg_ems)
  ok(math.abs(tb2.peak_ems - live_tb.peak_ems) < 1, "reloaded peak differs")
  ok(tri2.counts.s == live_tri.counts.s, "reloaded saves differ")
  ok(tri2.counts.s_star == live_tri.counts.s_star, "reloaded closed saves differ")
  ok(tri2.rt50 == live_tri.rt50, "reloaded RT50 differs: "
     .. tostring(tri2.rt50) .. " vs " .. tostring(live_tri.rt50))
  ok(Verdant.BuffTracker.count() == live_bt, "reloaded buff count differs")
  local shares_seen, abilities_seen, ability_id_ok = 0, 0, false
  Verdant.TemporalBuffer.iterate(function(_, s)
    shares_seen = shares_seen + ((s.ehps_groups and s.ehps_groups.count) or 0)
    local ea = s.ehps_abilities
    abilities_seen = abilities_seen + ((ea and ea.count) or 0)
    if ea and ea.count and ea.count > 0 and ea[1].id and ea[1].id > 0 then
      ability_id_ok = true
    end
  end)
  ok(shares_seen > 0, "reloaded samples must carry group shares for the SKILL view")
  ok(abilities_seen > 0, "reloaded samples must carry ability shares for the SKILL hover")
  ok(ability_id_ok, "reloaded ability entries must keep their ids")
  ok(Verdant.Triage.slot_name(2) == "Ally2", "reloaded roster name wrong")
  ok(VerdantGraphWindowStatusLabel._text:find("Direfrost", 1, true),
     "status banner must show the loaded zone")

  Verdant.Graph.on_record_click()
  ok(Verdant.Graph.load_session(SS.get(1)) == false,
     "loading while recording must be refused")
  Verdant.Graph.on_stop_click()
  H.advance(400)

  Verdant.Library.show()
  Verdant.Library.on_row_enter(1)
  ok(H.last_tooltip and H.last_tooltip:find("2026-09-03", 1, true) and H.last_tooltip:find("Direfrost Keep", 1, true)
     and H.last_tooltip:find("players", 1, true), "the row tooltip leads with date, place and group: " .. tostring(H.last_tooltip))
  ok(H.last_tooltip and H.last_tooltip:find("saved by you", 1, true),
     "row tooltip must explain the rescue counts")
  Verdant.Library.on_row_click(1)
  Verdant.Library.on_lock_click()
  ok(SS.get(SS.count()).head.locked == true or SS.get(1).head.locked == true,
     "lock must persist on the session")
  local before = SS.count()
  Verdant.Library.on_delete_click()
  Verdant.Library.on_delete_click()
  ok(SS.count() == before, "locked sessions must refuse deletion")
  ok(VerdantLibraryDeleteBtn._enabled == false, "delete button must disable on locked rows")
  Verdant.Library.on_lock_click()
  Verdant.Library.on_delete_click()
  ok(SS.count() == before, "first delete click must only arm")
  Verdant.Library.on_delete_click()
  ok(SS.count() == before - 1, "second delete click must delete after unlock")

  for i = 1, 14 do
    SS.store({ head = { locked = false, zone = "Scroll" .. i, ts = 1755900000,
                        dur_ms = 1000, group_size = 0,
                        sum = { avg = 0, peak = 0, saves = 0, o = 0, l = 0, m = 0 } },
               streams = {} })
  end
  Verdant.Library.show()
  ok(VerdantLibraryRow1Name._text == "Scroll14", "top row must be newest")
  ok(VerdantLibraryCountLabel._text:find("v4", 1, true),
     "count must show hidden-below indicator, got " .. tostring(VerdantLibraryCountLabel._text))
  Verdant.Library.on_scroll(-1)
  Verdant.Library.on_scroll(-1)
  ok(VerdantLibraryRow1Name._text == "Scroll12",
     "scrolling down must reveal older sessions, got " .. tostring(VerdantLibraryRow1Name._text))
  ok(VerdantLibraryCountLabel._text:find("^2", 1, true),
     "count must show hidden-above indicator, got " .. tostring(VerdantLibraryCountLabel._text))
  Verdant.Library.hide()

  sv.settings.session_autosave = false
  sv.library = { version = 1, sessions = {} }
  H.state.grouped = false
  H.state.group_size = 1
  H.state.player_group_tag = nil
  Verdant.Graph.on_flush_click()
end
