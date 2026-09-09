return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local view_label = VerdantGraphWindowViewLabel
  local hit = VerdantGraphHitMain

  local function visible_labels()
    local t = {}
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false and name:find("^VerdantBuffLbl") and c._text then t[#t + 1] = c._text end
    end
    return t
  end
  local function has(list, text)
    for _, v in ipairs(list) do if v == text then return true end end
    return false
  end
  local function find_prefix(list, prefix)
    for _, v in ipairs(list) do if v:sub(1, #prefix) == prefix then return v end end
    return nil
  end

  Verdant.Metrics.reset()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()
  local canvas = VerdantGraphWindowViewportCanvas
  local w0, h0 = VerdantGraphWindow:GetDimensions()
  local cw0, ch0 = canvas:GetDimensions()
  VerdantGraphWindow:SetDimensions(420, 312)
  canvas:SetDimensions(392, 160)
  Verdant.Graph.on_resize_stop()
  H.ability_names = {}
  for k = 1, 12 do H.ability_names[8000 + k] = string.format("Skill %02d", k) end

  Verdant.Graph.on_record_click()
  for _ = 1, 3 do
    for k = 1, 12 do H.heal({ hit = 100 * (13 - k), ability_id = 8000 + k }) end
    H.advance(1000)
  end
  Verdant.Graph.on_stop_click()
  while view_label._text ~= "CONTRIB" do Verdant.Graph.next_view() end

  local rows, n = Verdant.ContribView.rows()
  ok(n == 12, "twelve contributions, got " .. tostring(n))
  local labels = visible_labels()
  ok(has(labels, "Skill 01"), "the top row shows the biggest skill")
  ok(not has(labels, "Skill 12"), "the smallest skill does not fit at the default size")
  local off, max_off = Verdant.ContribView.scroll_state()
  ok(off == 0 and max_off > 0, "the list starts at the top with room to scroll, max " .. tostring(max_off))
  ok(find_prefix(labels, "+") ~= nil, "the overflow line reads +N more")

  hit._onOnMouseWheel(hit, -1)
  labels = visible_labels()
  off = Verdant.ContribView.scroll_state()
  ok(off == 1, "one wheel notch scrolls one row, got " .. tostring(off))
  ok(not has(labels, "Skill 01") and has(labels, "Skill 02"), "the first row scrolled out of view")
  ok(find_prefix(labels, "1 above") ~= nil, "the overflow line counts the rows above")

  for _ = 1, 30 do hit._onOnMouseWheel(hit, -1) end
  off = Verdant.ContribView.scroll_state()
  ok(off == max_off, "scrolling stops at the end")
  ok(has(visible_labels(), "Skill 12"), "the last row is reachable")
  for _ = 1, 30 do hit._onOnMouseWheel(hit, 1) end
  ok(Verdant.ContribView.scroll_state() == 0 and has(visible_labels(), "Skill 01"), "scrolling back returns to the top")

  hit._onOnMouseWheel(hit, -1)
  Verdant.Graph.next_view()
  Verdant.Graph.prev_view()
  ok(Verdant.ContribView.scroll_state() == 0, "leaving and returning resets the scroll")

  Verdant.Graph.on_flush_click()
  Verdant.Graph.on_record_click()
  H.heal({ hit = 500 })
  for k = 1, 14 do H.effect(EFFECT_RESULT_GAINED, 700 + k, 600, 0) end
  for k = 1, 14 do
    H.advance(300)
    H.effect(EFFECT_RESULT_FADED, 700 + k, 600, 0)
  end
  H.advance(4000)
  Verdant.Graph.on_stop_click()
  while view_label._text ~= "BUFFS" do Verdant.Graph.next_view() end
  labels = visible_labels()
  ok(has(labels, "Ability714"), "the longest buff leads the lanes")
  ok(not has(labels, "Ability701"), "the shortest buff does not fit")
  ok(find_prefix(labels, "0 above") ~= nil, "the buff overflow line reads 0 above at the top")
  hit._onOnMouseWheel(hit, -1)
  labels = visible_labels()
  ok(not has(labels, "Ability714") and has(labels, "Ability713"), "the wheel scrolls the buff lanes")
  ok(find_prefix(labels, "1 above") ~= nil, "the buff overflow line counts the rows above")
  for _ = 1, 30 do hit._onOnMouseWheel(hit, -1) end
  ok(has(visible_labels(), "Ability701"), "the shortest buff is reachable at the end")
  for _ = 1, 30 do hit._onOnMouseWheel(hit, 1) end
  ok(has(visible_labels(), "Ability714"), "and back to the top")

  Verdant.Graph.on_flush_click()
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end
  H.sounds = {}
  ok(Verdant.Graph.step_view(1) == true and view_label._text == "SKILL", "the next-view keybind steps forward")
  ok(H.sounds[#H.sounds] == ("sound:" .. Verdant.Sound.name("page")), "and turns a page")
  ok(Verdant.Graph.step_view(-1) == true and view_label._text == "EMS", "the previous-view keybind steps back")
  Verdant.Visibility.set("graph", false)
  H.sounds = {}
  ok(Verdant.Graph.step_view(1) == false and view_label._text == "EMS" and #H.sounds == 0, "with the graph hidden the keybind does nothing")
  Verdant.Visibility.set("graph", true)

  VerdantGraphWindow:SetDimensions(w0, h0)
  canvas:SetDimensions(cw0, ch0)
  Verdant.Graph.on_resize_stop()
  H.ability_names = nil
  Verdant.Metrics.reset()
end
