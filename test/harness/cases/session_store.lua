return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local SS = Verdant.SessionStore
  local V = Verdant.lib.vsf
  local sv = Verdant.SavedVars

  sv.settings = sv.settings or {}
  sv.library = { version = 1, sessions = {} }
  H.state.grouped = true
  H.state.group_size = 4
  H.state.player_group_tag = "group1"
  H.state.zone = "Fungal Grotto"
  H.unit_names = { group1 = "Me1", group2 = "Ally2" }
  H.fire(EVENT_GROUP_UPDATE)

  sv.settings.session_autosave = false
  Verdant.Graph.on_record_click()
  H.heal({ hit = 700, target_name = "Ally2", target_unit_id = 602 })
  H.advance(1500)
  Verdant.Graph.on_stop_click()
  ok(SS.count() == 0, "autosave off must not store sessions")

  sv.settings.session_autosave = true
  Verdant.Graph.on_record_click()
  H.heal({ hit = 900, target_name = "Ally2", target_unit_id = 602 })
  H.effect(EFFECT_RESULT_GAINED, 111, 602, 0)
  H.advance(1200)
  H.power("group2", 15000, 40000)
  H.advance(400)
  H.heal({ hit = 3000, target_name = "Ally2", target_unit_id = 602 })
  H.power("group2", 25000, 40000)
  H.advance(2500)
  H.death(true, "group2")
  H.death(false, "group2")
  H.effect(EFFECT_RESULT_FADED, 111, 602, 0)
  H.advance(1500)
  Verdant.Graph.on_stop_click()

  ok(SS.count() == 1, "autosave on must store the session, got " .. SS.count())
  local s = SS.get(1)
  ok(s.head.zone == "Fungal Grotto", "zone wrong: " .. tostring(s.head.zone))
  ok(s.head.dur_ms > 4000, "duration wrong: " .. tostring(s.head.dur_ms))
  ok(s.head.sum.saves == 1, "summary must carry the save, got " .. s.head.sum.saves)
  ok(s.head.cfg.theta == 0.5, "theta snapshot wrong")
  ok(#s.roster == 2, "roster must have 2 named slots, got " .. #s.roster)

  local series = V.unpack(s.streams.series, s.desc.series)
  ok(series and #series == s.streams.series.n and #series > 3,
     "series must decode, n=" .. tostring(series and #series))
  local eps = V.unpack(s.streams.episodes, s.desc.episodes)
  ok(eps and #eps == 1, "one episode expected in stream")
  ok(eps[1].slot == 2 and eps[1].cls == Verdant.Triage.CLASS_S, "episode content wrong")
  ok(eps[1].rt == 400, "episode rt must survive packing, got " .. tostring(eps[1].rt))
  local mks = V.unpack(s.streams.markers, s.desc.markers)
  ok(mks and #mks == 0, "group death markers default off, got " .. tostring(mks and #mks))
  local steps = V.unpack(s.streams.steps, s.desc.steps)
  ok(steps and #steps >= 2, "buff steps must decode, got " .. tostring(steps and #steps))
  ok(#s.buffs >= 1 and s.buffs[1].name, "buff meta must carry names")

  for _, st in pairs(s.streams) do
    for i, c in ipairs(st.data) do
      ok(#c <= 1800, "stream chunk " .. i .. " over savedvars limit")
    end
  end

  for i = 1, 30 do
    SS.store({ head = { locked = false, zone = "Filler" .. i, dur_ms = 1,
                        group_size = 0, sum = { avg = 0, peak = 0, saves = 0, o = 0, l = 0, m = 0 } },
               streams = {} })
  end
  ok(SS.count() == 24, "ring must cap at 24, got " .. SS.count())

  SS.set_locked(1, true)
  local locked_zone = SS.get(1).head.zone
  for i = 1, 30 do
    SS.store({ head = { locked = false, zone = "More" .. i, dur_ms = 1,
                        group_size = 0, sum = { avg = 0, peak = 0, saves = 0, o = 0, l = 0, m = 0 } },
               streams = {} })
  end
  ok(SS.count() == 24, "ring must stay capped, got " .. SS.count())
  ok(SS.get(1).head.zone == locked_zone, "locked session must survive eviction")

  ok(SS.delete(2), "delete must work")
  ok(SS.count() == 23, "delete must shrink the ring")

  sv.settings.session_autosave = false
  sv.library = { version = 1, sessions = {} }
  H.state.grouped = false
  H.state.group_size = 1
  H.state.player_group_tag = nil
  Verdant.Graph.on_flush_click()
end
