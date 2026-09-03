return function(H, Prng)
  local Sim = {}
  Sim.__index = Sim

  local E = {}

  function E.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Sim)
    self.rng = Prng.new(opts.seed or 42)
    self.queue = {}
    self.seq = 0
    self.members = {}
    self.player_unit_id = opts.player_unit_id or 500
    return self
  end

  function Sim:group(n, hp_max)
    hp_max = hp_max or 40000
    H.state.grouped = n > 1
    H.state.group_size = n
    H.state.player_group_tag = (n > 1) and "group1" or nil
    H.unit_names = H.unit_names or {}
    for i = 1, n do
      self.members[i] = {
        unit_id = (i == 1) and self.player_unit_id or (600 + i),
        hp_max = hp_max, hp = hp_max, alive = true,
        name = "Member" .. i,
      }
      H.unit_names["group" .. i] = "Member" .. i
    end
    H.fire(EVENT_GROUP_UPDATE)
  end

  function Sim:push_power(i)
    if #self.members <= 1 then return end
    local m = self.members[i]
    H.power("group" .. i, m.hp, m.hp_max)
  end

  function Sim:at(t, fn)
    self.seq = self.seq + 1
    self.queue[#self.queue + 1] = { t = t, seq = self.seq, fn = fn }
  end

  function Sim:every(t0, interval, until_t, fn, jitter_pct)
    local t = t0
    while t <= until_t do
      local fire_t = t
      if jitter_pct then
        fire_t = math.floor(t + (self.rng:next() * 2 - 1) * jitter_pct * interval)
        if fire_t < t0 then fire_t = t0 end
      end
      self:at(fire_t, fn)
      t = t + interval
    end
  end

  function Sim:ult(value)
    H.ult_power(value)
  end

  function Sim:ult_cast()
    H.ult_used()
    H.ult_power(0)
  end

  function Sim:hit(i, amount, result)
    local m = self.members[i]
    if not m or not m.alive then return end
    H.damage({ hit = amount, target_unit_id = m.unit_id, result = result })
    m.hp = m.hp - amount
    if m.hp <= 0 then
      m.hp = 0
      m.alive = false
      self:push_power(i)
      if i == 1 then H.death(true) end
      if #self.members > 1 then H.death(true, "group" .. i) end
    else
      self:push_power(i)
    end
  end

  function Sim:heal(i, amount, opts)
    local m = self.members[i]
    if not m or not m.alive then return end
    local eff = math.min(amount, m.hp_max - m.hp)
    local over = amount - eff
    if eff <= 0 and over <= 0 then return end
    m.hp = m.hp + eff
    local result = ACTION_RESULT_HEAL
    if opts and opts.crit then
      result = opts.hot and ACTION_RESULT_HOT_TICK_CRITICAL or ACTION_RESULT_CRITICAL_HEAL
    elseif opts and opts.hot then
      result = ACTION_RESULT_HOT_TICK
    end
    H.heal({
      hit = eff, overflow = over, result = result,
      source_unit_id = self.player_unit_id,
      target_unit_id = m.unit_id,
      target_name = m.name,
      target_type = (i == 1) and COMBAT_UNIT_TYPE_PLAYER or COMBAT_UNIT_TYPE_GROUP,
      ability_id = (opts and opts.ability_id) or 77,
    })
    if eff > 0 then self:push_power(i) end
  end

  function Sim:shield_on(i, ability_id)
    local m = self.members[i]
    if not m then return end
    m.shield_ability = ability_id
    H.effect(EFFECT_RESULT_GAINED, ability_id, m.unit_id, 0,
      COMBAT_UNIT_TYPE_PLAYER, (i == 1) and "player" or ("group" .. i))
  end

  function Sim:absorb(i, amount)
    local m = self.members[i]
    if not m or not m.shield_ability then return end
    H.shield({ hit = amount, target_unit_id = m.unit_id, ability_id = m.shield_ability })
  end

  function Sim:res(i)
    local m = self.members[i]
    if not m then return end
    m.alive = true
    m.hp = math.floor(m.hp_max / 2)
    if i == 1 then H.death(false) end
    if #self.members > 1 then H.death(false, "group" .. i) end
    self:push_power(i)
  end

  function Sim:combat(on)
    H.combat_state(on)
  end

  function Sim:bosses(list)
    H.set_bosses(list)
  end

  function Sim:lowest(k)
    local idx = {}
    for i, m in ipairs(self.members) do
      if m.alive then idx[#idx + 1] = i end
    end
    table.sort(idx, function(a, b)
      local ma, mb = self.members[a], self.members[b]
      local ra, rb = ma.hp / ma.hp_max, mb.hp / mb.hp_max
      if ra ~= rb then return ra < rb end
      return a < b
    end)
    local out = {}
    for i = 1, math.min(k, #idx) do out[i] = idx[i] end
    return out
  end

  function Sim:alive_count()
    local n = 0
    for _, m in ipairs(self.members) do
      if m.alive then n = n + 1 end
    end
    return n
  end

  function Sim:run(duration, opts)
    table.sort(self.queue, function(a, b)
      if a.t ~= b.t then return a.t < b.t end
      return a.seq < b.seq
    end)
    local check_every = (opts and opts.check_every) or 250
    local oracle = self.oracle
    local next_check = check_every
    local fired = 0

    local function checks_until(t)
      while oracle and next_check <= t do
        if next_check > H.now() then H.advance(next_check - H.now()) end
        oracle.check(H.now())
        next_check = next_check + check_every
      end
    end

    for _, a in ipairs(self.queue) do
      if a.t > duration then break end
      checks_until(a.t)
      if a.t > H.now() then H.advance(a.t - H.now()) end
      a.fn(self)
      fired = fired + 1
    end
    checks_until(duration)
    if duration > H.now() then H.advance(duration - H.now()) end

    return {
      actions = fired,
      duration = duration,
      checks = oracle and oracle.checks or 0,
      fails = oracle and oracle.fails or 0,
      max_rel_err = oracle and oracle.max_rel_err or 0,
      fail_lines = oracle and oracle.fail_lines or {},
      events = oracle and oracle.event_totals() or {},
    }
  end

  return E
end
