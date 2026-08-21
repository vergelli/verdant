return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.TemporalBuffer.clear()

  Verdant.Graph.on_record_click()
  ok(Verdant.TemporalBuffer.is_recording(), "recording did not start")
  ok(H.update_registered("VerdantTemporalSample"), "sample tick not registered")

  for _ = 1, 4 do
    H.heal({ hit = 1000 })
    H.advance(1000)
  end

  ok(Verdant.TemporalBuffer.count() >= 3, "temporal buffer did not fill: " .. Verdant.TemporalBuffer.count())

  Verdant.Graph.on_stop_click()
  ok(not Verdant.TemporalBuffer.is_recording(), "recording did not stop")
  ok(not H.update_registered("VerdantTemporalSample"), "sample tick not unregistered")

  local frozen = Verdant.TemporalBuffer.count()
  H.advance(3000)
  ok(Verdant.TemporalBuffer.count() == frozen, "frozen session mutated after stop")

  local has_nonzero = false
  Verdant.TemporalBuffer.iterate(function(_, s)
    if s.eHPS > 0 then has_nonzero = true end
  end)
  ok(has_nonzero, "no sample captured a nonzero eHPS")

  Verdant.Graph.on_flush_click()
  ok(Verdant.TemporalBuffer.count() == 0, "flush did not clear the buffer")
  Verdant.Metrics.reset()
end
