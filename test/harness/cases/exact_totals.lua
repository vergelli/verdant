return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local function close(a, b, msg)
    if math.abs(a - b) > 1e-6 then error(msg .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")", 2) end
  end
  local TB, MX, SS = Verdant.TemporalBuffer, Verdant.Metrics, Verdant.SessionStore
  local sv = Verdant.SavedVars
  sv.settings = sv.settings or {}
  local before_lib, before_auto = sv.library, sv.settings.session_autosave
  sv.library = { version = 1, sessions = {} }
  sv.settings.session_autosave = false
  SS.init()
  MX.reset()
  Verdant.ShieldRegistry.reset()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()
  H.state.grouped = false
  H.state.zone = "Rockgrove"

  Verdant.Graph.on_record_click()
  H.effect(EFFECT_RESULT_GAINED, 88, 600, 0)
  local heal_sum, shield_sum, oh_sum = 0, 0, 0
  for i = 1, 40 do
    H.heal({ hit = 1000 + i })
    heal_sum = heal_sum + 1000 + i
    if i % 5 == 0 then
      H.heal({ hit = 0, overflow = 300 })
      oh_sum = oh_sum + 300
    end
    if i > 25 then
      H.shield({ ability_id = 88, target_unit_id = 600, hit = 700 + i })
      shield_sum = shield_sum + 700 + i
    end
    H.advance(1000)
  end
  Verdant.Graph.on_stop_click()

  local s = TB.summary()
  ok(s.count >= 35, "the recording sampled the fight, got " .. s.count)
  ok(s.totals_from == "events", "a live recording takes its totals from the events, got " .. tostring(s.totals_from))
  close(s.total_heal, heal_sum, "the healing total is the sum of the heal events")
  close(s.total_shield, shield_sum, "the shield total is the sum of the absorbs")
  close(s.total_overheal, oh_sum, "the overheal total is the sum of the overflow")
  close(s.wasted_pct, oh_sum / (heal_sum + oh_sum), "wasted share is built on the exact totals")
  ok(s.integral_shield < shield_sum * 0.90,
     string.format("the window integral under-counts shields cast in the last window: integral=%.0f sum=%.0f", s.integral_shield, shield_sum))
  ok(s.integral_heal < heal_sum,
     string.format("the window integral under-counts the last seconds of healing: integral=%.0f sum=%.0f", s.integral_heal, heal_sum))

  local h, sh, oh = MX.totals()
  close(h, heal_sum, "Metrics.totals reports the heal sum")
  close(sh, shield_sum, "Metrics.totals reports the shield sum")
  close(oh, oh_sum, "Metrics.totals reports the overheal sum")

  ok(Verdant.Graph.on_save_click() == true, "the session saves")
  H.advance(400)
  ok(SS.count() == 1, "one session in the library")
  local sess = SS.get(1)
  close(sess.head.sum.total_shield, shield_sum, "the saved head carries the exact shield total")
  close(sess.head.sum.total_heal, heal_sum, "the saved head carries the exact heal total")
  close(sess.head.sum.total_overheal, oh_sum, "the saved head carries the exact overheal total")

  Verdant.Graph.on_flush_click()
  ok(TB.summary().count == 0, "flush empties the buffer")
  ok(Verdant.Graph.load_session(sess) == true, "the saved session loads back")
  local ls = TB.summary()
  ok(ls.totals_from == "saved", "a loaded session shows the totals it was saved with, got " .. tostring(ls.totals_from))
  close(ls.total_shield, shield_sum, "the loaded shield total matches the save")
  close(ls.total_heal, heal_sum, "the loaded heal total matches the save")
  close(ls.total_overheal, oh_sum, "the loaded overheal total matches the save")

  local series = {}
  TB.iterate(function(i, smp)
    series[i] = { t = smp.t, eHPS = smp.eHPS, MPS = smp.MPS, crit = smp.crit, noncrit = smp.noncrit, d = smp.d, o = smp.o }
  end)
  TB.load_session(series, {}, nil)
  local fs = TB.summary()
  ok(fs.totals_from == "integral", "a session saved without totals falls back to the window integral, got " .. tostring(fs.totals_from))
  close(fs.total_shield, fs.integral_shield, "the fallback total is the integral")
  close(fs.total_heal, fs.integral_heal, "the fallback heal total is the integral")

  Verdant.Graph.on_record_click()
  H.heal({ hit = 500 })
  H.advance(1000)
  Verdant.Graph.on_stop_click()
  local ns = TB.summary()
  ok(ns.totals_from == "events", "a new recording goes back to event totals")
  close(ns.total_heal, 500, "a new recording starts its totals from zero")
  close(ns.total_shield, 0, "no shields in the new recording")

  Verdant.Graph.on_flush_click()
  sv.library = before_lib
  sv.settings.session_autosave = before_auto
  SS.init()
  MX.reset()
  Verdant.ShieldRegistry.reset()
end
