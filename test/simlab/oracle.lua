return function(H)
  local O = {
    heals = {}, overheals = {}, shields = {}, damage = {},
    own_heals = {}, power = {}, deaths = {},
    group_ids = {}, player_id = nil, self_cast = {},
    checks = 0, fails = 0, max_rel_err = 0, fail_lines = {},
    seq = 0,
  }

  local HEAL_RESULTS = {
    [ACTION_RESULT_HEAL] = true,
    [ACTION_RESULT_HOT_TICK] = true,
    [ACTION_RESULT_CRITICAL_HEAL] = true,
    [ACTION_RESULT_HOT_TICK_CRITICAL] = true,
  }
  local CRIT_RESULTS = {
    [ACTION_RESULT_CRITICAL_HEAL] = true,
    [ACTION_RESULT_HOT_TICK_CRITICAL] = true,
  }
  local DMG_RESULTS = {
    [ACTION_RESULT_DAMAGE] = true,
    [ACTION_RESULT_DOT_TICK] = true,
    [ACTION_RESULT_CRITICAL_DAMAGE] = true,
    [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
    [ACTION_RESULT_BLOCKED_DAMAGE] = true,
    [ACTION_RESULT_FALL_DAMAGE] = true,
  }
  local GAIN_RESULTS = {
    [EFFECT_RESULT_GAINED] = true,
    [EFFECT_RESULT_UPDATED] = true,
    [EFFECT_RESULT_FULL_REFRESH] = true,
    [EFFECT_RESULT_TRANSFER] = true,
  }

  function O.on_fire(code, ...)
    O.seq = O.seq + 1
    if code == EVENT_COMBAT_EVENT then
      local result, isError, _, _, _, _, sourceType, tname, targetType, hit,
            _, _, _, suid, tuid, aid, overflow = ...
      if isError then return end
      local t = H.now()
      if HEAL_RESULTS[result] and sourceType == COMBAT_UNIT_TYPE_PLAYER then
        if (hit or 0) > 0 or (overflow or 0) > 0 then
          O.own_heals[#O.own_heals + 1] = {
            t = t, seq = O.seq, name = tname, hit = hit or 0, over = overflow or 0,
          }
        end
        if suid and suid ~= 0 then O.player_id = suid end
        if targetType == COMBAT_UNIT_TYPE_GROUP and tuid and tuid ~= 0 then
          O.group_ids[tuid] = true
        end
        if (hit or 0) > 0 then
          O.heals[#O.heals + 1] = { t = t, amount = hit, crit = CRIT_RESULTS[result] or false, tt = targetType }
        end
        if (overflow or 0) > 0 then
          O.overheals[#O.overheals + 1] = { t = t, amount = overflow, tt = targetType }
        end
      elseif result == ACTION_RESULT_DAMAGE_SHIELDED then
        if (hit or 0) > 0 and O.self_cast[tostring(aid) .. ":" .. tostring(tuid)] then
          O.shields[#O.shields + 1] = { t = t, amount = hit, tt = targetType }
        end
      elseif DMG_RESULTS[result] then
        if (hit or 0) > 0 and (O.group_ids[tuid] or tuid == O.player_id) then
          O.damage[#O.damage + 1] = { t = t, amount = hit }
        end
      end
    elseif code == EVENT_POWER_UPDATE then
      local tag, _, ptype, value, _, effMax = ...
      if ptype == POWERTYPE_HEALTH and effMax and effMax > 0 then
        O.power[#O.power + 1] = {
          t = H.now(), seq = O.seq, tag = tag, rho = value / effMax,
        }
      end
    elseif code == EVENT_UNIT_DEATH_STATE_CHANGED then
      local tag, dead = ...
      if type(tag) == "string" and tag:sub(1, 5) == "group" then
        O.deaths[#O.deaths + 1] = { t = H.now(), seq = O.seq, tag = tag, dead = dead }
      end
    elseif code == EVENT_EFFECT_CHANGED then
      local changeType, _, _, unitTag = ...
      local unitId, abilityId, sourceType = select(14, ...)
      if sourceType == COMBAT_UNIT_TYPE_PLAYER
         and abilityId and abilityId ~= 0
         and unitId and unitId ~= 0 then
        local k = tostring(abilityId) .. ":" .. tostring(unitId)
        if GAIN_RESULTS[changeType] then
          O.self_cast[k] = true
          if unitTag == "player" then O.player_id = unitId end
        elseif changeType == EFFECT_RESULT_FADED then
          O.self_cast[k] = nil
        end
      end
    end
  end

  local function wsum(list, cap, W, now, pred)
    local lo = (#list > cap) and (#list - cap + 1) or 1
    local cutoff = now - W
    local s = 0
    for i = lo, #list do
      local e = list[i]
      if e.t > cutoff and (not pred or pred(e)) then
        s = s + e.amount
      end
    end
    return s
  end

  function O.expected(now)
    local grouped = H.state.grouped and (H.state.group_size or 0) > 1
    local function in_m(e)
      if not grouped then return true end
      return e.tt == COMBAT_UNIT_TYPE_PLAYER
          or e.tt == COMBAT_UNIT_TYPE_GROUP
          or e.tt == COMBAT_UNIT_TYPE_PLAYER_PET
    end
    local W  = Verdant.Metrics.window_seconds() * 1000
    local WS = Verdant.Metrics.shield_window_seconds() * 1000
    local ehps = wsum(O.heals,     1024, W,  now, in_m) / (W / 1000)
    local ohps = wsum(O.overheals, 1024, W,  now, in_m) / (W / 1000)
    local mps  = wsum(O.shields,    512, WS, now, in_m) / (WS / 1000)
    local dg   = wsum(O.damage,    2048, W,  now, nil)  / (W / 1000)
    local crit = wsum(O.heals,     1024, W,  now,
      function(e) return in_m(e) and e.crit end) / (W / 1000)
    return { eHPS = ehps, OHPS = ohps, MPS = mps, EMS = ehps + mps,
             D_group = dg, crit = crit, noncrit = ehps - crit }
  end

  local function cmp(label, got, want)
    local denom = (math.abs(want) > 1) and math.abs(want) or 1
    local rel = math.abs(got - want) / denom
    if rel > O.max_rel_err then O.max_rel_err = rel end
    O.checks = O.checks + 1
    if rel > 1e-6 then
      O.fails = O.fails + 1
      if #O.fail_lines < 20 then
        O.fail_lines[#O.fail_lines + 1] = string.format(
          "t=%d  %-8s got=%.4f  want=%.4f  rel=%.2e", H.now(), label, got, want, rel)
      end
    end
  end

  function O.check(now)
    local e = O.expected(now)
    local Mx = Verdant.Metrics
    cmp("eHPS",    Mx.eHPS(now),    e.eHPS)
    cmp("OHPS",    Mx.OHPS(now),    e.OHPS)
    cmp("MPS",     Mx.MPS(now),     e.MPS)
    cmp("EMS",     Mx.EMS(now),     e.EMS)
    cmp("D_group", Mx.D_group(now), e.D_group)
    local c, nc = Mx.eHPS_crit_split(now)
    cmp("crit",    c,  e.crit)
    cmp("noncrit", nc, e.noncrit)
  end

  function O.triage_expected(t_end)
    local THETA, TEXIT, DELTA, GRACE, SIGMA, MINEP = 0.50, 0.55, 1000, 3000, 2000, 400
    local name_tag = {}
    for tag, nm in pairs(H.unit_names or {}) do name_tag[nm] = tag end

    local per = {}
    local function bucket(tag)
      per[tag] = per[tag] or {}
      return per[tag]
    end
    for _, p in ipairs(O.power) do
      local l = bucket(p.tag)
      l[#l + 1] = { t = p.t, seq = p.seq, k = "pu", rho = p.rho }
    end
    for _, d in ipairs(O.deaths) do
      local l = bucket(d.tag)
      l[#l + 1] = { t = d.t, seq = d.seq, k = d.dead and "die" or "res" }
    end
    for _, h in ipairs(O.own_heals) do
      local tag = name_tag[h.name]
      if tag then
        local l = bucket(tag)
        l[#l + 1] = { t = h.t, seq = h.seq, k = "heal", hit = h.hit, over = h.over }
      end
    end

    local counts = { s = 0, s_star = 0, o = 0, l = 0, m = 0, x = 0, oneshot = 0 }
    local rts = {}

    for _, list in pairs(per) do
      table.sort(list, function(a, b)
        if a.t ~= b.t then return a.t < b.t end
        return a.seq < b.seq
      end)
      local open, dead = false, false
      local start, rt, responded, over, last_heal = 0, -1, false, false, -1
      local grace_until, last_pu = 0, 0

      local function close(t_close, kind)
        if kind == "rec" then
          if responded then
            counts.s = counts.s + 1
            if over or (last_heal >= 0 and (t_close - last_heal) <= DELTA) then
              counts.s_star = counts.s_star + 1
            end
          else
            counts.o = counts.o + 1
          end
        elseif kind == "die" then
          if responded then counts.l = counts.l + 1
          elseif (t_close - start) < MINEP then counts.oneshot = counts.oneshot + 1
          else counts.m = counts.m + 1 end
        else
          counts.x = counts.x + 1
        end
        if rt >= 0 then rts[#rts + 1] = rt end
        open = false
      end

      for _, e in ipairs(list) do
        if open and last_pu > 0 and (e.t - last_pu) > SIGMA then
          close(last_pu + SIGMA, "cens")
        end
        if e.k == "pu" then
          last_pu = e.t
          if not dead and e.t >= grace_until then
            if open then
              if e.rho >= TEXIT then close(e.t, "rec") end
            elseif e.rho < THETA then
              open, start = true, e.t
              rt, responded, over, last_heal = -1, false, false, -1
            end
          end
        elseif e.k == "heal" then
          if open then
            if e.hit > 0 then
              if rt < 0 then rt = e.t - start end
              responded, last_heal = true, e.t
            end
            if e.over > 0 then over = true end
          end
        elseif e.k == "die" then
          if open then close(e.t, "die") end
          dead = true
        elseif e.k == "res" then
          dead = false
          grace_until = e.t + GRACE
        end
      end
      if open then close(t_end, "cens") end
    end

    table.sort(rts)
    local rn = #rts
    local rt50, rt95 = -1, -1
    if rn > 0 then
      local i50 = math.floor(rn * 0.50 + 0.5)
      local i95 = math.floor(rn * 0.95 + 0.5)
      if i50 < 1 then i50 = 1 end
      if i95 < 1 then i95 = 1 end
      rt50, rt95 = rts[i50], rts[i95]
    end
    return { counts = counts, responded = rn, rt50 = rt50, rt95 = rt95 }
  end

  function O.triage_check(t_end)
    local got  = Verdant.Triage.summary()
    local want = O.triage_expected(t_end)
    local function eq(label, g, w)
      O.checks = O.checks + 1
      if g ~= w then
        O.fails = O.fails + 1
        if #O.fail_lines < 20 then
          O.fail_lines[#O.fail_lines + 1] = string.format(
            "triage %-8s got=%s  want=%s", label, tostring(g), tostring(w))
        end
      end
    end
    eq("S",        got.counts.s,       want.counts.s)
    eq("S*",       got.counts.s_star,  want.counts.s_star)
    eq("O",        got.counts.o,       want.counts.o)
    eq("L",        got.counts.l,       want.counts.l)
    eq("M",        got.counts.m,       want.counts.m)
    eq("X",        got.counts.x,       want.counts.x)
    eq("oneshot",  got.counts.oneshot, want.counts.oneshot)
    eq("resp",     got.responded,      want.responded)
    eq("rt50",     got.rt50,           want.rt50)
    eq("rt95",     got.rt95,           want.rt95)
    return got
  end

  function O.event_totals()
    return { heals = #O.heals, overheals = #O.overheals,
             shields = #O.shields, damage = #O.damage }
  end

  return O
end
