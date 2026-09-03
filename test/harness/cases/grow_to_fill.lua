return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.TemporalBuffer.clear()
  Verdant.Visibility.set("graph", true)
  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
  Verdant.Graph.on_record_click()

  for _ = 1, 10 do
    H.heal({ hit = 1000 })
    H.advance(1000)
  end
  ok(Verdant.TemporalBuffer.count() == 10,
     "expected 10 samples, got " .. Verdant.TemporalBuffer.count())

  local cw = H.layout(VerdantGraphWindowViewportCanvas).w
  local function max_fill_right()
    local right = 0
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false and name:find("^VerdantGraphFillEhps") and c._anchor_list then
        local edge = (c._anchor_list[1].ox or 0) + (c._w or 0)
        if edge > right then right = edge end
      end
    end
    return right
  end

  local right = max_fill_right()
  ok(right > cw * 0.25 and right < cw * 0.42,
     string.format("10/60 samples should fill ~1/3 of a 30-slot axis, right=%d cw=%d", right, cw))
  ok(VerdantGridEmsTR._text == "30s",
     "growing axis should label the ladder span, got " .. tostring(VerdantGridEmsTR._text))

  for _ = 1, 55 do
    H.heal({ hit = 1000 })
    H.advance(1000)
  end
  ok(Verdant.TemporalBuffer.count() == 60, "buffer should be full")
  right = max_fill_right()
  ok(right > cw * 0.95,
     string.format("full buffer must span the whole axis, right=%d cw=%d", right, cw))

  Verdant.Graph.on_stop_click()
  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
end
