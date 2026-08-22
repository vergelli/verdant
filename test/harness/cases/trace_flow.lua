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
  ok(sv.trace.count >= 106, "expected at least 106 events, got " .. tostring(sv.trace.count))
  ok(#sv.trace.chunks >= 2, "big capture must split into several chunks")
  for i, c in ipairs(sv.trace.chunks) do
    ok(#c <= 2000, "chunk " .. i .. " exceeds the ZOS SavedVars 2000-char string limit: " .. #c)
  end

  local codec = dofile(HARNESS_ROOT .. "/test/simlab/tracecodec.lua")
  local events = codec.decode_chunks(sv.trace.chunks)
  ok(#events == sv.trace.count, "decode count mismatch: " .. #events .. " vs " .. sv.trace.count)

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
