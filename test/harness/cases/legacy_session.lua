return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local vsf = Verdant.lib.vsf

  Verdant.Metrics.reset()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()
  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end

  H.slotted = { [HOTBAR_CATEGORY_PRIMARY] = { [8] = 41001 } }
  Verdant.Graph.on_record_click()
  local v = 0
  for _ = 1, 12 do
    v = v + 40
    H.ult_power(v)
    H.heal({ hit = 1200, overflow = 300, target_unit_id = 600 })
    H.advance(1000)
  end
  H.ult_used()
  Verdant.Graph.on_stop_click()
  Verdant.SessionStore.finish_autosave()

  local fresh = Verdant.SessionStore.capture()
  ok(fresh ~= nil, "a session captures")

  local old_ult  = { { name = "t", width = 4 }, { name = "p", width = 1, scale = 100 } }
  local old_ultu = { { name = "t", width = 4 } }
  local steps = vsf.unpack(fresh.streams.ult, fresh.desc.ult)
  local recs = {}
  for i = 1, #steps do recs[i] = { t = steps[i].t, p = math.min(1, (steps[i].v or 0) / 500) } end
  local used = vsf.unpack(fresh.streams.ultu, fresh.desc.ultu)
  local urecs = {}
  for i = 1, #used do urecs[i] = { t = used[i].t } end

  local legacy = {
    v = fresh.v,
    head = {
      ts = fresh.head.ts, zone = "Old Keep", dur_ms = fresh.head.dur_ms,
      group_size = fresh.head.group_size, build = "2.4.0", api = fresh.head.api,
      locked = false, player_slot = fresh.head.player_slot,
      sum = {
        avg = fresh.head.sum.avg, peak = fresh.head.sum.peak, crit_pct = fresh.head.sum.crit_pct,
        active_pct = fresh.head.sum.active_pct, total_heal = fresh.head.sum.total_heal,
        total_shield = fresh.head.sum.total_shield,
        saves = 0, s_star = 0, o = 0, l = 0, m = 0, oneshot = 0, x = 0, eps = 0, rt50 = -1, rt95 = -1,
      },
      cfg = fresh.head.cfg,
    },
    roster = fresh.roster,
    buffs = fresh.buffs,
    gkeys = fresh.gkeys,
    desc = {
      series = fresh.desc.series, steps = fresh.desc.steps, episodes = fresh.desc.episodes,
      markers = fresh.desc.markers, shares = fresh.desc.shares, abilities = fresh.desc.abilities,
      ult = old_ult, ultu = old_ultu,
    },
    streams = {
      series = fresh.streams.series, steps = fresh.streams.steps, episodes = fresh.streams.episodes,
      markers = fresh.streams.markers, shares = fresh.streams.shares, abilities = fresh.streams.abilities,
      ult = vsf.pack(recs, old_ult), ultu = vsf.pack(urecs, old_ultu),
    },
  }

  Verdant.Graph.on_flush_click()
  ok(Verdant.Graph.load_session(legacy), "a 2.4-shaped session must load")
  ok(Verdant.Ultimate.has_data(), "the old ultimate stream still gives the band data")
  local snap = Verdant.Ultimate.snapshot()
  ok(snap.steps == #recs and snap.used == 1 and snap.abilities == 0, "steps and casts survive, no per-bar records exist")
  local band_drawn = false
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VerdantGraphUlt") and not name:find("Top") and not name:find("Icon") then band_drawn = true end
  end
  ok(band_drawn, "the band draws from the old stream")
  local chip = VerdantGraphSummaryLabel._text or ""
  ok(chip:find("AVG") ~= nil, "the chip works without the overheal fields")

  local hit = VerdantGraphSummaryHit
  hit._onOnMouseEnter(hit)
  ok(VerdantHoverCardName._text == "Healing report", "the report opens on a legacy session")
  ok(VerdantHoverCardRowVal1._text == "-" and VerdantHoverCardRowVal2._text == "-", "an unknown split reads as a dash, not as a number")
  hit._onOnMouseExit(hit)

  Verdant.SessionStore.store(legacy)
  Verdant.Library.show()
  local ring_hidden = true
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if name:find("^VerdantLibraryRow%d+Ring$") and c._hidden == false then
      local p = c._parent
      local nm = p and rawget(_G, (p._name or "") .. "Name")
      if nm and nm._text == "Old Keep" then ring_hidden = false end
    end
  end
  ok(ring_hidden, "a legacy row shows no ring rather than a wrong one")
  Verdant.Library.hide()

  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  H.slotted = nil
  Verdant.Metrics.reset()
end
