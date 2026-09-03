return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()
  local sv = Verdant.SavedVars
  sv.settings = sv.settings or {}
  sv.settings.light_mode = true
  sv.settings.light_alpha_pct = 40

  H.state.mouse_x, H.state.mouse_y = 1900, 1000
  Verdant.Graph.on_record_click()
  ok(Verdant.Graph.is_light_active(), "recording with light mode on must enter light")
  ok(VerdantGraphWindowChromeTop._hidden == true, "chrome strips must hide")
  ok(VerdantGraphWindowBg._hidden == true, "outer border must hide")
  ok(VerdantGraphWindowRecordBtn._hidden == true, "record button must hide")
  ok(VerdantGraphWindowStopBtn._hidden == true, "minimal controls stay hidden until hover")
  ok(math.abs((VerdantGraphWindow._alpha or 1) - 0.4) < 0.01,
     "window must dim to the configured alpha, got " .. tostring(VerdantGraphWindow._alpha))

  local w = H.layout(VerdantGraphWindow)
  H.state.mouse_x, H.state.mouse_y = w.x + 10, w.y + 10
  H.advance(300)
  ok(VerdantGraphWindow._alpha == 1, "hover must go fully opaque")
  ok(VerdantGraphWindowStopBtn._hidden == false, "hover must reveal stop")
  ok(VerdantGraphWindowNextViewBtn._hidden == false, "hover must reveal view nav")
  ok(VerdantGraphWindowChromeTop._hidden == true, "chrome stays off even on hover")

  H.state.mouse_x, H.state.mouse_y = 1900, 1000
  H.advance(300)
  ok(math.abs((VerdantGraphWindow._alpha or 1) - 0.4) < 0.01, "leaving must dim again")
  ok(VerdantGraphWindowStopBtn._hidden == true, "leaving must tuck the minimal controls")

  Verdant.Graph.on_stop_click()
  ok(not Verdant.Graph.is_light_active(), "stop must exit light mode")
  ok(VerdantGraphWindowChromeTop._hidden == false, "chrome must restore on stop")
  ok(VerdantGraphWindow._alpha == 1, "alpha must restore on stop")
  ok(VerdantGraphWindowRecordBtn._hidden == false, "record button must restore")
  ok(not H.update_registered("VerdantLightPoll"), "the hover poll must unregister")

  sv.settings.light_mode = false
  Verdant.Graph.on_record_click()
  ok(not Verdant.Graph.is_light_active(), "light off means recording keeps the chrome")
  ok(VerdantGraphWindowChromeTop._hidden == false, "chrome untouched with light off")
  Verdant.Graph.on_stop_click()

  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  Verdant.Metrics.reset()
end
