return {
  name = "dungeon_pull",
  seed = 4242,
  group = 4,
  duration = 90000,
  record = true,
  build = function(sim, H)
    sim:at(0, function(s) s:combat(true) end)

    local pull = 0
    while pull * 20000 < 80000 do
      local t0 = pull * 20000
      sim:every(t0 + 500, 400, t0 + 6000, function(s)
        local victim = s.rng:range(1, 4)
        s:hit(victim, s.rng:range(2000, 7000),
          s.rng:chance(0.2) and ACTION_RESULT_CRITICAL_DAMAGE or ACTION_RESULT_DAMAGE)
      end, 0.20)
      pull = pull + 1
    end

    sim:every(700, 800, 89000, function(s)
      local low = s:lowest(1)[1]
      if low then
        local m = s.members[low]
        if m.hp / m.hp_max < 0.85 then
          s:heal(low, math.floor(s.rng:jitter(4500, 0.30)),
            { crit = s.rng:chance(0.25), ability_id = 28385 })
        end
      end
    end)

    sim:every(1500, 1500, 89000, function(s)
      for _, i in ipairs(s:lowest(2)) do
        s:heal(i, math.floor(s.rng:jitter(1100, 0.15)),
          { hot = true, crit = s.rng:chance(0.25), ability_id = 28536 })
      end
    end)

    sim:at(30000, function(s) s:shield_on(3, 29224) end)
    sim:every(31000, 900, 36000, function(s)
      s:absorb(3, s.rng:range(600, 1600))
    end)

    sim:at(89500, function(s) s:combat(false) end)
  end,
}
