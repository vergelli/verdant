return {
  name = "burst",
  seed = 777,
  group = 12,
  duration = 30000,
  record = true,
  build = function(sim, H)
    sim:at(0, function(s)
      s:combat(true)
      s:shield_on(1, 41967)
      s:shield_on(2, 41967)
      s:shield_on(3, 41967)
    end)

    sim:every(100, 100, 29500, function(s)
      for i = 1, #s.members do
        if s.rng:chance(0.8) then
          s:hit(i, s.rng:range(150, 500), ACTION_RESULT_DOT_TICK)
        end
      end
    end)

    sim:every(250, 250, 29500, function(s)
      for _, i in ipairs(s:lowest(4)) do
        s:heal(i, math.floor(s.rng:jitter(1800, 0.30)),
          { crit = s.rng:chance(0.35), hot = s.rng:chance(0.5), ability_id = 61304 })
      end
    end)

    sim:every(300, 300, 29500, function(s)
      s:absorb(s.rng:range(1, 3), s.rng:range(300, 900))
    end)

    sim:at(29800, function(s) s:combat(false) end)
  end,
}
