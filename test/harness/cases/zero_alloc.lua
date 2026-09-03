return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.TemporalBuffer.clear()
  Verdant.Visibility.set("graph", false)
  Verdant.Graph.on_record_click()

  for _ = 1, 10 do
    H.heal({ hit = 1000, overflow = 200 })
    H.shield({ hit = 400 })
    H.damage({ hit = 1500 })
    H.advance(1000)
  end

  collectgarbage("collect")
  collectgarbage("collect")
  collectgarbage("stop")
  local before = collectgarbage("count")
  local TICKS = 50
  for _ = 1, TICKS do
    H.advance(1000)
  end
  local after = collectgarbage("count")
  collectgarbage("restart")

  local budget = HARNESS_DEBUG and 700 or 400
  local per_tick = (after - before) * 1024 / TICKS
  ok(per_tick < budget,
     string.format("sample tick allocates %.0f bytes (budget %d)", per_tick, budget))

  Verdant.Graph.on_stop_click()
  Verdant.Graph.on_flush_click()
  Verdant.Metrics.reset()
end
