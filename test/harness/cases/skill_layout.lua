return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.TemporalBuffer.clear()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()
  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "SKILL" do Verdant.Graph.next_view() end

  H.slotted = { [HOTBAR_CATEGORY_PRIMARY] = { [8] = 41001 } }
  Verdant.Graph.on_record_click()
  local v = 0
  for _ = 1, 40 do
    v = v + 25
    H.ult_power(v)
    H.heal({ hit = 1200, target_unit_id = 600 })
    H.advance(1000)
  end
  Verdant.Graph.on_stop_click()
  Verdant.SessionStore.finish_autosave()
  ok(Verdant.Ultimate.has_data(), "the session carries ultimate data")
  ok(VerdantGraphSummaryLabel._hidden == false, "the chip shows at the default size")

  local sa = VerdantGraphWindowViewportSkillArea
  local ec = VerdantGraphWindowViewportSkillAreaEhpsCanvas
  local mc = VerdantGraphWindowViewportSkillAreaMpsCanvas
  local w0, h0 = sa:GetDimensions()
  local chip_h = VerdantGraphSummaryBg._h + 8

  local function band_shown()
    for _, c in ipairs(H.controls) do
      local nm = c._name or ""
      if c._hidden == false and nm:find("^VerdantGraphUlt") and nm:find("Top") and not nm:find("Icon") then return true end
    end
    return false
  end

  local prev_top, prev_bot, prev_compact
  local saw_compact, saw_full = false, false
  for h = 100, 400, 2 do
    sa:SetDimensions(w0, h)
    Verdant.Graph.on_resize_stop()
    local compact = VerdantGraphSummaryLabel._hidden == true
    local inset = compact and 0 or (28 + chip_h)
    local top_plot = ec:GetHeight() - inset
    local bot_plot = mc:GetHeight() - 18
    ok(math.abs(top_plot - bot_plot) <= 1,
       string.format("both plots share the height at h=%d: top %d bot %d (compact=%s)", h, top_plot, bot_plot, tostring(compact)))
    local usable = h - 24 - 4
    if usable - 18 >= 48 then
      ok(top_plot >= 24 and bot_plot >= 24, string.format("plots keep the minimum at h=%d: top %d bot %d", h, top_plot, bot_plot))
    end
    if prev_top and prev_compact == compact then
      ok(top_plot >= prev_top and bot_plot >= prev_bot, string.format("plots grow with the window at h=%d", h))
    end
    ok(band_shown() ~= compact, string.format("the ultimate band steps aside only in compact mode at h=%d", h))
    if compact then saw_compact = true else saw_full = true end
    prev_top, prev_bot, prev_compact = top_plot, bot_plot, compact
  end
  ok(saw_compact and saw_full, "the sweep crossed both regimes")

  sa:SetDimensions(w0, 126)
  Verdant.Graph.on_resize_stop()
  local tall = 0
  for _, c in ipairs(H.controls) do
    local nm = c._name or ""
    if c._hidden == false and nm:find("^VerdantSkillFillTop") and (c._h or 0) > 0 then
      tall = tall + 1
    end
  end
  ok(tall > 0, "eHPS bars stay visible at the minimum height")

  sa:SetDimensions(w0, h0)
  Verdant.Graph.on_resize_stop()
  ok(VerdantGraphSummaryLabel._hidden == false and band_shown(), "chip and band return at the default size")

  Verdant.Graph.next_view()
  ok(VerdantGraphSummaryLabel._hidden == false, "other views keep the chip open")

  H.slotted = nil
  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  Verdant.Metrics.reset()
end
