return function(H)
  local O = {
    heals = {}, overheals = {}, shields = {}, damage = {},
    group_ids = {}, player_id = nil, self_cast = {},
    checks = 0, fails = 0, max_rel_err = 0, fail_lines = {},
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
    if code == EVENT_COMBAT_EVENT then
      local result, isError, _, _, _, _, sourceType, _, targetType, hit,
            _, _, _, suid, tuid, aid, overflow = ...
      if isError then return end
      local t = H.now()
      if HEAL_RESULTS[result] and sourceType == COMBAT_UNIT_TYPE_PLAYER then
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

  function O.event_totals()
    return { heals = #O.heals, overheals = #O.overheals,
             shields = #O.shields, damage = #O.damage }
  end

  return O
end
