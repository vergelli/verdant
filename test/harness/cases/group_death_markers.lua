return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local TB = Verdant.TemporalBuffer

  local sv = Verdant.SavedVars
  sv.settings = sv.settings or {}
  Verdant.Metrics.reset()
  TB.clear()
  H.state.player_group_tag = "group1"

  sv.settings.group_death_markers = false
  Verdant.Graph.on_record_click()
  H.heal({ hit = 800 })
  H.advance(500)
  H.death(true, "group3")
  local _, n0 = TB.markers()
  ok(n0 == 0, "toggle OFF must suppress group markers, got " .. n0)

  sv.settings.group_death_markers = true
  H.death(true, "group3")
  H.advance(1000)
  H.death(false, "group3")
  local ms, n1 = TB.markers()
  ok(n1 == 2, "expected 2 group markers, got " .. n1)
  ok(ms[1].who == "group3" and ms[1].death == true, "first marker must be group3 death")
  ok(ms[2].who == "group3" and ms[2].death == false, "second marker must be group3 res")

  H.death(true)
  H.death(true, "group1")
  local _, n2 = TB.markers()
  ok(n2 == 3, "player multi-tag death must add exactly one marker, got " .. (n2 - n1))
  ok(ms[3].who == nil, "player marker must have no who")

  for i = 1, 70 do
    H.death(true, "group4")
  end
  local _, n3 = TB.markers()
  ok(n3 == 3 + 58, "group quota must cap at 60, got " .. (n3 - 3) .. " extra group markers")
  H.death(false)
  local _, n4 = TB.markers()
  ok(n4 == n3 + 1, "player marker must still fit after group quota is full")

  H.heal({ hit = 600 })
  H.advance(2000)
  Verdant.Graph.on_stop_click()

  local big, small = 0, 0
  for _, c in ipairs(H.controls) do
    if c._tex and c._tex:find("Skull") and c._hidden == false then
      if c._w == 16 then big = big + 1 end
      if c._w == 11 then small = small + 1 end
    end
  end
  ok(big >= 1, "player skull at full size not rendered")
  ok(small >= 1, "group skull at reduced size not rendered")

  sv.settings.group_death_markers = false
  H.state.player_group_tag = nil
  TB.clear()
  Verdant.Graph.on_flush_click()
end
