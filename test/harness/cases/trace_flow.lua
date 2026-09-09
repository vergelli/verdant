return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  if not Verdant.Constants.DEBUG then
    Verdant.Trace.start()
    Verdant.Trace.stop()
    local sv = {}
    Verdant.Trace.save(sv)
    ok(sv.trace == nil, "trace stub must not write savedvars when DEBUG=false")
    ok(Verdant.Trace.status_line():find("disabled"), "stub status must say disabled")
    return
  end

  local sv = {}
  Verdant.Trace.clear(sv)
  Verdant.Trace.start()

  H.combat_state(true)
  H.heal({ hit = 1234, overflow = 55, target_unit_id = 700 })
  H.effect(EFFECT_RESULT_GAINED, 999, 700, 0)
  H.death(true)
  H.death(false)
  for i = 1, 100 do
    H.heal({ hit = 1000 + i, target_unit_id = 700 + i })
  end
  H.combat_state(false)

  Verdant.Trace.stop()
  Verdant.Trace.save(sv)

  ok(sv.trace ~= nil, "trace not saved")
  ok(sv.trace.constants ~= nil, "trace must snapshot client constants")
  ok(sv.trace.constants.ACTION_RESULT_HEAL == ACTION_RESULT_HEAL,
     "constants snapshot must read live globals")
  ok(sv.trace.constants.API_VERSION == 101050, "api version missing from snapshot")
  ok(sv.trace.count >= 106, "expected at least 106 events, got " .. tostring(sv.trace.count))
  ok(#sv.trace.chunks >= 2, "big capture must split into several chunks")
  for i, c in ipairs(sv.trace.chunks) do
    ok(#c <= 2000, "chunk " .. i .. " exceeds the ZOS SavedVars 2000-char string limit: " .. #c)
  end

  local codec = dofile(HARNESS_ROOT .. "/test/simlab/tracecodec.lua")
  local events = codec.decode_chunks(sv.trace.chunks)
  ok(#events == sv.trace.count, "decode count mismatch: " .. #events .. " vs " .. sv.trace.count)
  ok(sv.traces and #sv.traces == 1 and sv.traces[1] == sv.trace, "a save lands in the ring and mirrors sv.trace")
  ok(sv.trace.zone ~= nil and sv.trace.ts ~= nil, "an entry carries zone and timestamp")
  ok(sv.trace.settings and sv.trace.settings.time_window_s and sv.trace.settings.sample_rate_ms,
     "an entry carries the window and rate it was recorded with")

  local SV = Verdant.SavedVars
  Verdant.Trace.clear(SV)
  ok(not Verdant.Trace.auto_enabled(SV), "auto-trace is off by default")
  Verdant.Graph.on_flush_click()
  Verdant.Graph.on_record_click()
  H.heal({ hit = 100 })
  H.advance(1000)
  Verdant.Graph.on_stop_click()
  ok(SV.traces == nil, "with auto-trace off a recording stages nothing")

  Verdant.Trace.set_auto(SV, true)
  ok(Verdant.Trace.auto_enabled(SV) and SV.debug.auto_trace == true, "auto-trace persists in the debug block")
  local counts = {}
  for round = 1, 4 do
    Verdant.Graph.on_flush_click()
    Verdant.Graph.on_record_click()
    for _ = 1, 10 * round do H.heal({ hit = 500 }) end
    H.advance(1000)
    Verdant.Graph.on_stop_click()
    counts[round] = SV.trace.count
  end
  ok(#SV.traces == 3, "the ring keeps three traces, got " .. tostring(#SV.traces))
  ok(SV.traces[3] == SV.trace, "the newest trace mirrors sv.trace")
  ok(SV.traces[1].count == counts[2] and SV.traces[3].count == counts[4], "the oldest trace is evicted first")
  ok(counts[4] > counts[1], "each recording stages only its own events")

  H.reloads = 0
  SLASH_COMMANDS["/verdant"]("flush")
  ok(H.reloads == 1, "flush reloads the UI so SavedVariables reach the disk")
  SLASH_COMMANDS["/verdant"]("trace auto")
  ok(not Verdant.Trace.auto_enabled(SV), "the auto subcommand toggles auto-trace off")
  Verdant.Trace.clear(SV)
  ok(SV.trace == nil and SV.traces == nil, "clear empties the ring too")
  Verdant.Graph.on_flush_click()

  local ce
  for _, e in ipairs(events) do
    if e.tag == "CE" then ce = e break end
  end
  ok(ce ~= nil, "no combat event captured")
  ok(ce.args[10] == 1234, "hit value lost in roundtrip: " .. tostring(ce.args[10]))
  ok(ce.args[17] == 55, "overflow lost in roundtrip: " .. tostring(ce.args[17]))
  ok(ce.args[15] == 700, "target unit id lost in roundtrip: " .. tostring(ce.args[15]))
  ok(ce.args[2] == false, "isError must decode as boolean false")

  local has_cs, has_de = false, false
  for _, e in ipairs(events) do
    if e.tag == "CS" then has_cs = true end
    if e.tag == "DE" then has_de = true end
  end
  ok(has_cs, "combat state not captured")
  ok(has_de, "death state not captured")

  Verdant.Trace.clear(sv)
  ok(sv.trace == nil, "clear must wipe savedvars trace")
end
