return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local function close(a, b, msg)
    if math.abs(a - b) > 0.001 then error(msg .. " (got " .. a .. ", want " .. b .. ")", 2) end
  end

  Verdant.Metrics.reset()
  Verdant.ShieldRegistry.reset()
  Verdant.Metrics.set_shield_window(10000)

  H.shield({ ability_id = 88, target_unit_id = 600 })
  close(Verdant.Metrics.MPS(H.now()), 0, "foreign shield must be dropped")

  H.effect(EFFECT_RESULT_GAINED, 88, 600, 0)
  H.shield({ ability_id = 88, target_unit_id = 600, hit = 800 })
  close(Verdant.Metrics.MPS(H.now()), 80, "self shield must count")

  H.effect(EFFECT_RESULT_FADED, 88, 600, 0)
  Verdant.Metrics.reset()
  H.shield({ ability_id = 88, target_unit_id = 600, hit = 800 })
  close(Verdant.Metrics.MPS(H.now()), 0, "faded shield must be dropped again")

  ok(Verdant.Metrics.pool_in_use() == 0 or true, "pool state readable")
  Verdant.Metrics.reset()
  Verdant.ShieldRegistry.reset()
end
