return {
  name = "trial_boss",
  seed = 1337,
  group = 12,
  duration = 180000,
  record = true,
  build = function(sim, H)
    sim:at(0, function(s)
      Verdant.SavedVars.settings.group_death_markers = true
      s:combat(true)
      s:bosses({ { name = "Lord Warrior", in_combat = true } })
      s:shield_on(1, 41967)
      s:shield_on(2, 41967)
    end)

    sim:every(1000, 1000, 179000, function(s)
      for i = 1, #s.members do
        s:hit(i, s.rng:range(400, 1300), ACTION_RESULT_DAMAGE)
      end
    end, 0.10)

    sim:every(1500, 1500, 179000, function(s)
      s:hit(2, s.rng:range(3000, 7000), ACTION_RESULT_DAMAGE)
    end, 0.15)

    sim:every(800, 1000, 179500, function(s)
      for _, i in ipairs(s:lowest(3)) do
        s:heal(i, math.floor(s.rng:jitter(3200, 0.25)),
          { crit = s.rng:chance(0.30), ability_id = 61304 })
      end
    end, 0.10)

    sim:every(3000, 3000, 179000, function(s)
      for i = 1, #s.members do
        s:heal(i, math.floor(s.rng:jitter(1500, 0.20)),
          { crit = s.rng:chance(0.30), ability_id = 40058 })
      end
    end, 0.10)

    sim:every(1200, 1000, 179500, function(s)
      s:heal(2, math.floor(s.rng:jitter(1400, 0.15)),
        { hot = true, crit = s.rng:chance(0.30), ability_id = 61305 })
    end)

    sim:every(10000, 10000, 175000, function(s)
      s:shield_on(1, 41967)
      s:shield_on(2, 41967)
    end)

    sim:every(2000, 2000, 179000, function(s)
      s:absorb(2, s.rng:range(800, 2200))
    end)

    sim:at(60000, function(s)
      s:hit(7, 60000, ACTION_RESULT_CRITICAL_DAMAGE)
    end)
    sim:at(66000, function(s) s:res(7) end)

    sim:at(150000, function(s)
      s:hit(5, 60000, ACTION_RESULT_CRITICAL_DAMAGE)
    end)
    sim:at(157000, function(s) s:res(5) end)

    sim:at(155000, function(s)
      s:hit(1, 60000, ACTION_RESULT_CRITICAL_DAMAGE)
    end)
    sim:at(161000, function(s) s:res(1) end)

    sim:at(179800, function(s)
      s:combat(false)
      s:bosses({})
    end)
  end,
}
