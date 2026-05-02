Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Metrics = {}

local M = Verdant.Metrics

local W_MS       = 5000
local W_SHIELD_MS = 30000   -- shields are sparse; wider window avoids permanent zero

local heal_buf, overheal_buf, shield_buf, damage_buf

local function in_M(entry)
  return Verdant.Coverage.is_in_M(entry.targetType)
end

function M.init()
  W_MS        = 5000
  W_SHIELD_MS = 30000
  heal_buf     = Verdant.Buffer.new(W_MS,        1024)
  overheal_buf = Verdant.Buffer.new(W_MS,        1024)
  shield_buf   = Verdant.Buffer.new(W_SHIELD_MS,  512)
  damage_buf   = Verdant.Buffer.new(W_MS,        2048)
end

function M.set_window(ms)
  W_MS = ms or 5000
  heal_buf.window_ms     = W_MS
  overheal_buf.window_ms = W_MS
  damage_buf.window_ms   = W_MS
  -- shield window is intentionally independent; use set_shield_window to change it
end

function M.set_shield_window(ms)
  W_SHIELD_MS = ms or 30000
  shield_buf.window_ms = W_SHIELD_MS
end

function M.window_seconds() return W_MS / 1000 end

function M.ingest_heal(t, hit, overflow, targetUnitId, targetType, abilityId)
  if hit and hit > 0 then
    heal_buf:push({ t = t, amount = hit, targetUnitId = targetUnitId, targetType = targetType, abilityId = abilityId })
  end
  if overflow and overflow > 0 then
    overheal_buf:push({ t = t, amount = overflow, targetUnitId = targetUnitId, targetType = targetType, abilityId = abilityId })
  end
end

function M.ingest_shield(t, absorbed, targetUnitId, targetType, abilityId)
  if not absorbed or absorbed <= 0 then return end
  shield_buf:push({ t = t, amount = absorbed, targetUnitId = targetUnitId, targetType = targetType, abilityId = abilityId })
end

function M.ingest_damage_group(t, hit, targetUnitId)
  if not hit or hit <= 0 then return end
  damage_buf:push({ t = t, amount = hit, targetUnitId = targetUnitId })
end

local function rate(buf, now_ms, predicate)
  return buf:sum(now_ms, "amount", predicate) / (W_MS / 1000)
end

function M.eHPS(now_ms)    return rate(heal_buf,     now_ms, in_M) end
function M.OHPS(now_ms)    return rate(overheal_buf, now_ms, in_M) end
function M.MPS(now_ms)     return shield_buf:sum(now_ms, "amount", in_M) / (W_SHIELD_MS / 1000) end
function M.D_group(now_ms) return rate(damage_buf,   now_ms, nil)  end

function M.EMS(now_ms)
  return M.eHPS(now_ms) + M.MPS(now_ms)
end

function M.O_self(now_ms)
  return M.eHPS(now_ms) + M.MPS(now_ms) + M.OHPS(now_ms)
end

function M.contribution(now_ms)
  local ems = M.EMS(now_ms)
  local heal_share, shield_share = 0, 0
  if ems > 0 then
    heal_share   = M.eHPS(now_ms) / ems
    shield_share = M.MPS(now_ms)  / ems
  end

  local c, mode_used
  if Verdant.Coverage.is_grouped() then
    local d = M.D_group(now_ms)
    mode_used = "group"
    if d <= 0 then
      c = 0
    else
      local ratio = ems / d
      c = ratio > 1 and 1 or ratio
    end
  else
    local o = M.O_self(now_ms)
    mode_used = "open"
    c = (o > 0) and (ems / o) or 0
  end

  return {
    mode    = mode_used,
    eHPS    = M.eHPS(now_ms),
    MPS     = M.MPS(now_ms),
    OHPS    = M.OHPS(now_ms),
    EMS     = ems,
    D_group = M.D_group(now_ms),
    O_self  = M.O_self(now_ms),
    C_self  = c,
    C_heal  = c * heal_share,
    C_shield = c * shield_share,
  }
end

function M.eHPS_by_group(now_ms)
  return Verdant.SkillColors.group_shares(heal_buf, now_ms, in_M)
end

function M.MPS_by_group(now_ms)
  return Verdant.SkillColors.group_shares(shield_buf, now_ms, in_M)
end

function M.reset()
  heal_buf:reset()
  overheal_buf:reset()
  shield_buf:reset()
  damage_buf:reset()
end

function M.size_snapshot()
  return {
    heal     = heal_buf:size(),
    overheal = overheal_buf:size(),
    shield   = shield_buf:size(),
    damage   = damage_buf:size(),
  }
end
