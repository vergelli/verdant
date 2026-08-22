return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local T = Verdant.Triage

  Verdant.Metrics.reset()
  Verdant.TemporalBuffer.clear()
  H.state.grouped = true
  H.state.group_size = 4
  H.state.player_group_tag = "group1"
  H.unit_names = H.unit_names or {}
  H.unit_names.group1 = "Me1"
  H.unit_names.group2 = "Ally2"
  H.unit_names.group3 = "Ally3"
  H.unit_names.group4 = "Ally4"
  H.fire(EVENT_GROUP_UPDATE)

  Verdant.Graph.on_record_click()
  ok(T.is_active(), "triage session did not start with recording")

  H.power("group2", 19000, 40000)
  H.power("group2", 21000, 40000)
  H.advance(500)
  H.heal({ hit = 2000, overflow = 0, target_name = "Ally2", target_unit_id = 602 })
  H.power("group2", 23000, 40000)

  H.power("group3", 15000, 40000)
  H.advance(1000)
  H.death(true, "group3")
  H.death(false, "group3")
  H.power("group3", 10000, 40000)
  local _, n_mid = T.episodes()
  ok(n_mid == 2, "grace period must suppress episode reopen, got " .. n_mid)

  H.power("group4", 0, 40000)
  H.death(true, "group4")
  H.death(false, "group4")

  H.advance(4000)
  H.power("group4", 18000, 40000)
  H.advance(600)
  H.heal({ hit = 1000, overflow = 0, target_name = "Ally4", target_unit_id = 604 })
  H.advance(300)
  H.death(true, "group4")

  H.power("group2", 15000, 40000)
  H.advance(3500)

  local s = T.summary()
  ok(s.counts.s == 1,       "expected S=1, got " .. s.counts.s)
  ok(s.counts.s_star == 1,  "expected S*=1, got " .. s.counts.s_star)
  ok(s.counts.m == 1,       "expected M=1, got " .. s.counts.m)
  ok(s.counts.oneshot == 1, "expected oneshot=1, got " .. s.counts.oneshot)
  ok(s.counts.l == 1,       "expected L=1, got " .. s.counts.l)
  ok(s.counts.x == 1,       "stale episode must censor as X, got " .. s.counts.x)
  ok(s.responded == 2,      "expected 2 responded, got " .. s.responded)
  ok(s.rt50 == 500,         "expected RT50=500, got " .. s.rt50)
  ok(s.rt95 == 600,         "expected RT95=600, got " .. s.rt95)

  H.power("group2", 10000, 40000)
  Verdant.Graph.on_stop_click()
  ok(not T.is_active(), "triage session must stop with recording")
  local s2 = T.summary()
  ok(s2.counts.x == 2, "open episode at stop must censor, got X=" .. s2.counts.x)

  H.power("group2", 5000, 40000)
  local _, n_after = T.episodes()
  ok(n_after == s2.episodes, "power updates after stop must not open episodes")

  Verdant.Graph.on_record_click()
  H.power("group2", 10000, 40000)
  H.advance(200)
  H.heal({ hit = 900, target_name = "Ally2^Fx", target_unit_id = 602 })
  H.heal({ hit = 900, target_name = "Koska^N", target_unit_id = 999, target_type = 0 })
  local ps = T.power_stats()
  ok(ps.matched == 1, "suffixed name must match its slot, matched=" .. ps.matched)
  ok(ps.unmatched == 0, "companion heal must not count as unmatched, got " .. ps.unmatched)
  H.power("group2", 39000, 40000)
  local s3 = T.summary()
  ok(s3.counts.s == 1 and s3.responded == 1, "suffixed heal must close the episode as save")

  H.power("group3", 15000, 40000)
  H.advance(300)
  H.heal({ hit = 800, target_name = "Ally3", target_unit_id = 603,
           result = ACTION_RESULT_HOT_TICK })
  H.power("group3", 23000, 40000)
  local s4 = T.summary()
  ok(s4.counts.s == 2, "hot-tick response must still attribute the save, S=" .. s4.counts.s)
  ok(s4.responded == 2, "hot-tick response must count as responded")
  ok(s4.rt_n == 1, "hot-only response must not measure RT, rt_n=" .. s4.rt_n)
  Verdant.Graph.on_stop_click()

  H.state.grouped = false
  H.state.group_size = 1
  H.state.player_group_tag = nil
  Verdant.Graph.on_flush_click()
end
