return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.Visibility.set("bar", true)
  H.heal({ hit = 1000 })
  H.advance(1000)

  local lbl = VerdantBarWindowMetricLabel
  local guard = 0
  while not (lbl._hidden == false and lbl._text == "EMS") and guard < 6 do
    Verdant.Bar.next_metric()
    H.advance(1000)
    guard = guard + 1
  end
  ok(lbl._text == "EMS", "the bar must be parked on EMS to start, got " .. tostring(lbl._text))
  ok(type(lbl._onOnMouseUp) == "function", "the metric name must be clickable")
  ok(type(lbl._onOnMouseEnter) == "function", "the metric name must explain itself on hover")
  local before = lbl._text
  H.sounds = {}
  lbl._onOnMouseUp(lbl, nil, true)
  ok(lbl._text ~= before, "clicking the metric name must advance the metric, still " .. tostring(lbl._text))
  ok(H.sounds[#H.sounds] == "sound:DIALOG_ACCEPT", "advancing confirms with the accept sound")
  local cycled = lbl._text
  lbl._onOnMouseUp(lbl, nil, false)
  ok(lbl._text == cycled, "releasing outside the label does nothing")

  local dot = VerdantBarWindowRecDot
  ok(dot._tex == "Verdant/assets/rec.dds", "the bar owns a recording dot")
  ok(dot._hidden == true, "no recording, no dot")
  Verdant.Graph.on_record_click()
  H.heal({ hit = 1000 })
  H.advance(1000)
  ok(dot._hidden == false, "recording shows the dot on the bar")
  Verdant.Graph.on_stop_click()
  H.advance(1000)
  ok(dot._hidden == true, "stopping hides the dot")

  Verdant.Graph.toggle_record()
  ok(Verdant.TemporalBuffer.is_recording(), "the record keybind starts a recording")
  H.heal({ hit = 1000 })
  H.advance(1000)
  Verdant.Graph.toggle_record()
  ok(not Verdant.TemporalBuffer.is_recording(), "the record keybind stops it")

  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("bar", false)
  Verdant.Metrics.reset()
end
