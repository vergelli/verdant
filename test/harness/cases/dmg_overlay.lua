return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  Verdant.Metrics.reset()
  Verdant.Visibility.set("graph", true)
  Verdant.Graph.on_flush_click()

  local view_label = VerdantGraphWindowViewLabel
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end

  Verdant.Graph.on_record_click()
  for _ = 1, 5 do
    H.heal({ hit = 1000, target_unit_id = 600 })
    H.damage({ hit = 3000, target_unit_id = 600 })
    H.advance(1000)
  end
  Verdant.Graph.on_stop_click()

  local has_d = false
  Verdant.TemporalBuffer.iterate(function(_, s)
    if (s.d or 0) > 0 then has_d = true end
  end)
  ok(has_d, "samples must carry group damage rate")

  local line1 = rawget(_G, "VerdantGraphLineDmg1")
  ok(line1 and line1._hidden == false, "damage overlay line must render on EMS view")
  local fill1 = rawget(_G, "VerdantGraphDmgFill1")
  ok(fill1 and fill1._hidden == false, "damage fill must render under the curve")

  local canvas = VerdantGraphWindowViewportCanvas
  local hit    = VerdantGraphHitMain
  H.state.mouse_x = canvas:GetLeft() + canvas:GetWidth() - 10
  H.state.mouse_y = canvas:GetTop() + 200
  hit._onOnMouseEnter(hit)
  H.advance(200)
  local stat = VerdantHoverCardStat._text or ""
  ok(stat:find("dmg") ~= nil, "moment card must include damage: " .. stat)
  hit._onOnMouseExit(hit)

  Verdant.Graph.next_view()
  ok(line1._hidden == true, "damage line must release when leaving EMS view")
  ok(rawget(_G, "VerdantGraphDmgFill1")._hidden == true, "damage fill must release too")
  while view_label._text ~= "EMS" do Verdant.Graph.next_view() end

  Verdant.Graph.on_flush_click()
  Verdant.Visibility.set("graph", false)
  Verdant.Metrics.reset()
end
