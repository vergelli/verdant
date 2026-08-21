return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local function close(a, b, msg)
    if math.abs(a - b) > 0.001 then error(msg .. " (got " .. a .. ", want " .. b .. ")", 2) end
  end

  Verdant.Metrics.reset()
  Verdant.Metrics.set_window(5000)

  H.heal({ hit = 1000 })
  H.heal({ hit = 1000, result = ACTION_RESULT_CRITICAL_HEAL })
  H.heal({ hit = 1000, overflow = 500 })

  local now = H.now()
  close(Verdant.Metrics.eHPS(now), 600, "eHPS")
  close(Verdant.Metrics.OHPS(now), 100, "OHPS")

  local crit, noncrit = Verdant.Metrics.eHPS_crit_split(now)
  close(crit, 200, "crit split")
  close(noncrit, 400, "noncrit split")

  H.advance(6000)
  close(Verdant.Metrics.eHPS(H.now()), 0, "eHPS after window expiry")

  Verdant.Metrics.reset()
  ok(Verdant.Metrics.pool_in_use() == 0, "pool leak after reset: " .. Verdant.Metrics.pool_in_use())
end
